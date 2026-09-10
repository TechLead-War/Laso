#!/usr/bin/env python3
"""Regenerate AmplitudeEventReference.html from the tracking code.

The HTML is the source of truth for the Amplitude taxonomy, so it must never be
hand-edited: run this after ANY change to the tracking layer and commit the result.

    python3 scripts/gen_event_reference.py

Ground truth is every `logEvent(...)` call site in Core/Tracking/AppAnalytics.swift
plus the two provider-channel events that go straight to the SDK in
AmplitudeProvider.swift. A property whose value is an enum `.rawValue` also gets its
value space documented, read from the enum in AppAnalytics.swift or SectionTracker.swift.
Tier placement and the one-line purpose for each event live in this file (TIERS /
PURPOSES) because they are editorial, not derivable from code — everything else is
extracted. An event missing a purpose fails the run loudly rather than shipping a
blank card, as does a properties dictionary the extractor cannot resolve.

Output depends only on those source files, so re-running it on unchanged code
rewrites nothing: a non-empty diff means the reference was out of date.
"""
import html
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
FACADE = REPO / 'Core/Tracking/AppAnalytics.swift'
PROVIDER = REPO / 'Core/Tracking/AmplitudeProvider.swift'
SECTIONS = REPO / 'Core/Tracking/SectionTracker.swift'
OUT = REPO / 'AmplitudeEventReference.html'
PURPOSES_JSON = Path(__file__).resolve().parent / 'event_purposes.json'

# Matches a dictionary key only at an entry position, so the "yes" in a
# `flag ? "yes" : "no"` ternary is not mistaken for a property name.
KEY = re.compile(r'(?:^|[\[,])\s*"([a-z0-9_]+)"\s*:', re.M)
FUNC = re.compile(r'^    (?:@discardableResult\s*)?(?:private |fileprivate |static )*func ')
# A property whose value is `<name>.rawValue` is backed by an enum, and `<name>`
# is an argument of the enclosing func, so its type names the vocabulary.
RAWVALUE = re.compile(r'"([a-z0-9_]+)"\s*:\s*([A-Za-z_]\w*)(?:\.\w+)*\.rawValue')
ENUM_DECL = re.compile(r'^\s*(?:private |fileprivate |public )?enum (\w+): String\b')
ENUM_CASE = re.compile(r'^\s*case (\w+)(?:\s*=\s*"([^"]+)")?\s*(?://.*)?$')

# Sent straight to the SDK, so the 12 global properties are never attached.
BYPASS = {
    'app_error_recorded': ['error_code', 'error_context', 'error_domain', 'error_message', 'rate_limited'],
    'app_crash': ['crash_type', 'crashed_at_epoch', 'exception_name', 'exception_reason',
                  'signal_name', 'signal_number', 'stack_trace'],
}

TIERS = [
    ('t1', '1 · North Star — Activation &amp; First Value',
     'Does the user reach the aha moment? The single most predictive thing for everything downstream.'),
    ('t2', '2 · Monetization &amp; Conversion',
     'Who pays, where they drop, and what each paywall placement was worth.'),
    ('t3', '3 · Retention, Habit &amp; Churn',
     'Do they come back, does it become a ritual, and when are they about to leave?'),
    ('t4', '4 · Core Engagement &amp; Outcomes',
     'Sessions, screens, core actions, and whether the product actually delivered something new.'),
    ('t5', '5 · Feature &amp; Content Interaction',
     'Which surfaces get used: insights, correlations, charts, breathwork, journal, widgets.'),
    ('t6', '6 · Trust, Feedback &amp; Growth',
     'Explanations, privacy, the PMF survey, sharing, referrals, reviews.'),
    ('t7', '7 · Notification &amp; Live Activity Delivery',
     'The full push funnel: scheduled, presented, opened, converted, and every attrition path.'),
    ('t8', '8 · Reliability &amp; Diagnostics',
     'Sync health, errors, crashes, and the pipeline that keeps the data fresh.'),
]

GLOBALS = ['schema_version', 'environment', 'platform', 'build_number', 'app_version', 'session_id',
           'session_number', 'tab', 'screen', 'opened_from', 'hour_of_day', 'client_timestamp_utc',
           'pricing_cohort', 'has_free_access']
SUPERS = ['app_environment', 'is_debug', 'app_version', 'app_build', 'locale_language',
          'locale_country', 'timezone_id', 'ios_version']


def dict_block(lines, start):
    """Return the source text of the bracket-balanced literal starting at `start`."""
    buf, depth, started, j = '', 0, False, start
    while j < len(lines):
        buf += lines[j] + '\n'
        depth += lines[j].count('[') - lines[j].count(']')
        if '[' in lines[j]:
            started = True
        if started and depth <= 0:
            break
        j += 1
    return buf


def extract_enums():
    """Raw values of every String-backed enum in the tracking layer, keyed by type."""
    enums = {}
    for path in (FACADE, SECTIONS):
        lines = path.read_text().split('\n')
        for i, line in enumerate(lines):
            m = ENUM_DECL.match(line)
            if not m:
                continue
            values, depth = [], 0
            for l in lines[i:]:
                depth += l.count('{') - l.count('}')
                c = ENUM_CASE.match(l)
                if c:
                    values.append(c.group(2) or c.group(1))
                if depth <= 0:
                    break
            enums[m.group(1)] = sorted(values)
    return enums


def signature(lines, start):
    """The func declaration at `start`, which may wrap over several lines."""
    sig = ''
    for l in lines[start:]:
        sig += l
        if '{' in l:
            break
    return sig


def extract_events():
    lines = FACADE.read_text().split('\n')
    starts = [i for i, l in enumerate(lines) if FUNC.match(l)]
    spans = [(s, starts[n + 1] if n + 1 < len(starts) else len(lines)) for n, s in enumerate(starts)]

    enums = extract_enums()
    events, with_metadata, vocab = {}, set(), {}
    for i, line in enumerate(lines):
        m = re.search(r'logEvent\("([a-z0-9_]+)"(?:, parameters: (\[|[A-Za-z_]\w*))?', line)
        if not m:
            continue
        name, arg, keys, raws = m.group(1), m.group(2), set(), []
        if arg == '[':
            block = dict_block(lines, i)
            keys |= set(KEY.findall(block))
            raws += RAWVALUE.findall(block)
        span = next(((s, e) for s, e in spans if s <= i < e), None)
        if span:
            body = '\n'.join(lines[span[0]:span[1]])
            if arg and arg != '[':
                # The dictionary is built into a local before the logEvent call.
                # Reading the identifier that is actually passed, instead of assuming
                # one spelling, is what stops a renamed local from silently emptying
                # a card.
                built = ''
                for k in range(*span):
                    if re.search(rf'(?:let|var)\s+{arg}\s*:\s*\[String:\s*Any\]\s*=\s*\[', lines[k]):
                        built += dict_block(lines, k)
                assigned = re.findall(rf'{arg}\["([a-z0-9_]+)"\]\s*=[^=]', body)
                if not built and not assigned:
                    sys.exit(f'ERROR: {name} passes `{arg}` to logEvent, but no `[String: Any]` '
                             f'literal or `{arg}["key"] =` assignment for it exists in the same '
                             'func, so the card would silently claim the event has no properties.')
                keys |= set(KEY.findall(built))
                keys |= set(assigned)
                raws += RAWVALUE.findall(built)
                raws += re.findall(rf'{arg}\["([a-z0-9_]+)"\]\s*=\s*([A-Za-z_]\w*)(?:\.\w+)*\.rawValue', body)
            for prop, ident in raws:
                enum = re.search(rf'\b{ident}:\s*([A-Z]\w+)', signature(lines, span[0]))
                if enum and enum.group(1) in enums:
                    vocab.setdefault(name, {})[prop] = enum.group(1)
            if re.search(r'for \(\w+, \w+\) in metadata', body):
                with_metadata.add(name)
        events.setdefault(name, set()).update(keys)

    provider = PROVIDER.read_text()
    for name, props in BYPASS.items():
        if f'"{name}"' not in provider:
            sys.exit(f'ERROR: {name} is no longer emitted in AmplitudeProvider.swift — update BYPASS.')
        events[name] = set(props)

    return ({n: {'props': sorted(p), 'metadata': n in with_metadata, 'enums': vocab.get(n, {})}
             for n, p in sorted(events.items())}, enums)


def extract_user_properties():
    src = FACADE.read_text()
    props = set(re.findall(r'setUserProperty\("([a-z0-9_]+)"', src))
    for m in re.finditer(r'setUserProperties\(\[(.*?)\]\)', src, re.S):
        props |= set(KEY.findall(m.group(1)))
    for m in re.finditer(r'var props: \[String: Any\] = \[(.*?)\]', src, re.S):
        props |= set(KEY.findall(m.group(1)))
    props |= set(re.findall(r'props\["([a-z0-9_]+)"\]\s*=', src))
    return sorted(props)


def chips(values, empty='globals only'):
    if not values:
        return f'<span class="prop none">{empty}</span>'
    return ''.join(f'<span class="prop">{html.escape(v)}</span>' for v in values)


def main():
    events, enums = extract_events()
    meta = json.loads(PURPOSES_JSON.read_text())
    purposes, tiers_by_event = meta['purposes'], meta['tiers']

    missing = [n for n in events if n not in purposes]
    if missing:
        sys.exit('ERROR: no purpose for: ' + ', '.join(missing) +
                 f'\nAdd a one-line purpose and a tier to {PURPOSES_JSON.name}.')
    stale = [n for n in purposes if n not in events]

    by_tier = {t: [] for t, _, _ in TIERS}
    for name in events:
        by_tier[tiers_by_event.get(name, 't8')].append(name)

    cards = {}
    for name, data in events.items():
        props = data['props'] + (['(+metadata)'] if data['metadata'] else [])
        badge = ('<span class="badge warn" title="Sent straight to the SDK, so the 12 global '
                 'properties are not attached">bypasses globals</span>') if name in BYPASS else ''
        backed = ''.join(f'<span class="prop">{prop} &rarr; {enum}</span>'
                         for prop, enum in sorted(data['enums'].items()))
        cards[name] = (
            f'<div class="event" data-name="{name}" data-props="{html.escape(" ".join(props))}">'
            f'<div class="ev-head"><code class="ev-name">{name}</code>{badge}</div>'
            f'<div class="ev-purpose">{html.escape(purposes[name])}</div>'
            f'<div class="ev-props">{chips(props)}</div>'
            + (f'<div class="ev-props">{backed}</div>' if backed else '') + '</div>')

    sections = ''.join(
        f'<section class="tier" id="{tid}"><h2>{title} <span class="count">{len(by_tier[tid])}</span></h2>'
        f'<p class="tier-sub">{sub}</p><div class="grid">'
        + ''.join(cards[n] for n in by_tier[tid]) + '</div></section>'
        for tid, title, sub in TIERS)

    # Property values are a taxonomy of their own: without them a `block_type` chip
    # never reveals that chart_touch or metric_row exist.
    used = {}
    for name, data in events.items():
        for prop, enum in data['enums'].items():
            used.setdefault(enum, set()).add(f'{name}.{prop}')
    sections += (
        f'<section class="tier" id="vocab"><h2>Controlled vocabularies '
        f'<span class="count">{len(used)}</span></h2>'
        '<p class="tier-sub">Every value the enum-backed properties above can carry, read from the '
        'enum declarations. A value that is not listed here is a value the app never sends.</p>'
        '<div class="grid">' + ''.join(
            f'<div class="event" data-name="{enum}" data-props="{html.escape(" ".join(enums[enum]))}">'
            f'<div class="ev-head"><code class="ev-name">{enum}</code>'
            f'<span class="count">{len(enums[enum])} values</span></div>'
            f'<div class="ev-purpose">{html.escape(", ".join(sorted(used[enum])))}</div>'
            f'<div class="ev-props">{chips(enums[enum])}</div></div>'
            for enum in sorted(used)) + '</div></section>')

    schema = re.search(r'schemaVersion = "([^"]+)"', FACADE.read_text()).group(1)
    user_props = extract_user_properties()
    facade_count = len(events) - len(BYPASS)

    # The stylesheet and page chrome are stable; only the body is regenerated.
    shell = OUT.read_text()
    head = shell[:shell.find('<section class="tier"')]
    tail = shell[shell.rfind('</section>') + len('</section>'):]

    # No commit sha: it can only ever name the commit BEFORE the one carrying this
    # file, so it always read as stale, and it made two runs of the same code differ.
    head = re.sub(r'<p class="sub">.*?</p>',
                  '<p class="sub">Source of truth. Every event the app sends, extracted from '
                  '<code>Core/Tracking/AppAnalytics.swift</code>, <code>AmplitudeProvider.swift</code> '
                  'and <code>SectionTracker.swift</code>. Do not hand-edit: run '
                  '<code>python3 scripts/gen_event_reference.py</code> after any tracking change; '
                  'if the file changes, it was out of date.</p>',
                  head, flags=re.S)
    head = re.sub(r'<nav>.*?</nav>',
                  '<nav>' + ''.join(f'<a href="#{tid}">{title.split("·", 1)[1].strip()}</a>'
                                    for tid, title, _ in TIERS)
                  + '<a href="#vocab">Controlled vocabularies</a></nav>',
                  head, flags=re.S)
    head = re.sub(r'<div class="stats">.*?</div>',
                  f'<div class="stats"><span><b>{len(events)}</b> events</span>'
                  f'<span><b>{facade_count}</b> facade · <b>{len(BYPASS)}</b> provider</span>'
                  f'<span><b>{len(GLOBALS)}</b> global props</span><span><b>{len(SUPERS)}</b> super props</span>'
                  f'<span><b>{len(user_props)}</b> user properties</span>'
                  f'<span><b>{len(used)}</b> vocabularies</span>'
                  f'<span>schema <b>{schema}</b></span></div>',
                  head, flags=re.S)
    head = re.sub(r'<div class="banner">.*?</div>',
                  '<div class="banner"><b>How to read this.</b> Tier 1 matters most (activation and aha), '
                  f'Tier 8 least (diagnostics). Every facade event also carries the <b>{len(GLOBALS)} global</b> and '
                  f'<b>{len(SUPERS)} super</b> properties below plus the joinable user properties, so those are not '
                  'repeated on each card. <span style="color:var(--amber)">bypasses globals</span> = sent '
                  f'straight to the SDK without the {len(GLOBALS)} globals.</div>',
                  head, flags=re.S)
    head = re.sub(r'(<h3>Global properties[^<]*</h3>)<div class="ev-props">.*?</div>',
                  lambda m: m.group(1) + f'<div class="ev-props">{chips(GLOBALS)}</div>', head, flags=re.S)
    head = re.sub(r'(<h3>Super properties[^<]*</h3>)<div class="ev-props">.*?</div>',
                  lambda m: m.group(1) + f'<div class="ev-props">{chips(SUPERS)}</div>', head, flags=re.S)

    OUT.write_text(head + sections + tail)
    print(f'{OUT.name}: {len(events)} events ({facade_count} facade, {len(BYPASS)} provider), '
          f'{len(user_props)} user properties, {len(used)} controlled vocabularies')
    for tid, title, _ in TIERS:
        print(f'  {tid} {len(by_tier[tid]):>3}  {html.unescape(title)}')
    if stale:
        print('\nNOTE: these have a purpose but are no longer emitted — remove them from '
              f'{PURPOSES_JSON.name}: ' + ', '.join(stale))


if __name__ == '__main__':
    main()

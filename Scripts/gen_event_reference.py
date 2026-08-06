#!/usr/bin/env python3
"""Regenerate AmplitudeEventReference.html from the tracking code.

The HTML is the source of truth for the Amplitude taxonomy, so it must never be
hand-edited: run this after ANY change to the tracking layer and commit the result.

    python3 scripts/gen_event_reference.py

Ground truth is every `logEvent(...)` call site in Core/Tracking/AppAnalytics.swift
plus the two provider-channel events that go straight to the SDK in
AmplitudeProvider.swift. Tier placement and the one-line purpose for each event live
in this file (TIERS / PURPOSES) because they are editorial, not derivable from code —
everything else is extracted. An event missing a purpose fails the run loudly rather
than shipping a blank card.
"""
import html
import json
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
FACADE = REPO / 'Core/Tracking/AppAnalytics.swift'
PROVIDER = REPO / 'Core/Tracking/AmplitudeProvider.swift'
OUT = REPO / 'AmplitudeEventReference.html'
PURPOSES_JSON = Path(__file__).resolve().parent / 'event_purposes.json'

# Matches a dictionary key only at an entry position, so the "yes" in a
# `flag ? "yes" : "no"` ternary is not mistaken for a property name.
KEY = re.compile(r'(?:^|[\[,])\s*"([a-z0-9_]+)"\s*:', re.M)
FUNC = re.compile(r'^    (?:@discardableResult\s*)?(?:private |fileprivate |static )*func ')

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


def extract_events():
    lines = FACADE.read_text().split('\n')
    starts = [i for i, l in enumerate(lines) if FUNC.match(l)]
    spans = [(s, starts[n + 1] if n + 1 < len(starts) else len(lines)) for n, s in enumerate(starts)]

    events, with_metadata = {}, set()
    for i, line in enumerate(lines):
        m = re.search(r'logEvent\("([a-z0-9_]+)"', line)
        if not m:
            continue
        name, keys = m.group(1), set()
        if 'parameters: [' in line:
            keys |= set(KEY.findall(dict_block(lines, i)))
        span = next(((s, e) for s, e in spans if s <= i < e), None)
        if span:
            body = '\n'.join(lines[span[0]:span[1]])
            # `let params: [String: Any] = [...]` built before the logEvent call.
            for k in range(*span):
                if re.search(r'(?:let|var)\s+params\s*:\s*\[String:\s*Any\]\s*=\s*\[', lines[k]):
                    keys |= set(KEY.findall(dict_block(lines, k)))
            keys |= set(re.findall(r'params\["([a-z0-9_]+)"\]\s*=', body))
            if re.search(r'for \(\w+, \w+\) in metadata', body):
                with_metadata.add(name)
        events.setdefault(name, set()).update(keys)

    provider = PROVIDER.read_text()
    for name, props in BYPASS.items():
        if f'"{name}"' not in provider:
            sys.exit(f'ERROR: {name} is no longer emitted in AmplitudeProvider.swift — update BYPASS.')
        events[name] = set(props)

    return {n: {'props': sorted(p), 'metadata': n in with_metadata} for n, p in sorted(events.items())}


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
    events = extract_events()
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
        cards[name] = (
            f'<div class="event" data-name="{name}" data-props="{html.escape(" ".join(props))}">'
            f'<div class="ev-head"><code class="ev-name">{name}</code>{badge}</div>'
            f'<div class="ev-purpose">{html.escape(purposes[name])}</div>'
            f'<div class="ev-props">{chips(props)}</div></div>')

    sections = ''.join(
        f'<section class="tier" id="{tid}"><h2>{title} <span class="count">{len(by_tier[tid])}</span></h2>'
        f'<p class="tier-sub">{sub}</p><div class="grid">'
        + ''.join(cards[n] for n in by_tier[tid]) + '</div></section>'
        for tid, title, sub in TIERS)

    commit = subprocess.run(['git', '-C', str(REPO), 'rev-parse', '--short', 'HEAD'],
                            capture_output=True, text=True).stdout.strip() or 'unknown'
    schema = re.search(r'schemaVersion = "([^"]+)"', FACADE.read_text()).group(1)
    user_props = extract_user_properties()
    facade_count = len(events) - len(BYPASS)

    # The stylesheet and page chrome are stable; only the body is regenerated.
    shell = OUT.read_text()
    head = shell[:shell.find('<section class="tier"')]
    tail = shell[shell.rfind('</section>') + len('</section>'):]

    head = re.sub(r'<p class="sub">.*?</p>',
                  '<p class="sub">Source of truth. Every event the app sends, extracted from '
                  '<code>Core/Tracking/AppAnalytics.swift</code> and <code>AmplitudeProvider.swift</code> '
                  f'at commit <code>{commit}</code>. Do not hand-edit: run '
                  '<code>python3 scripts/gen_event_reference.py</code> after any tracking change.</p>',
                  head, flags=re.S)
    head = re.sub(r'<div class="stats">.*?</div>',
                  f'<div class="stats"><span><b>{len(events)}</b> events</span>'
                  f'<span><b>{facade_count}</b> facade · <b>{len(BYPASS)}</b> provider</span>'
                  f'<span><b>{len(GLOBALS)}</b> global props</span><span><b>{len(SUPERS)}</b> super props</span>'
                  f'<span><b>{len(user_props)}</b> user properties</span>'
                  f'<span>schema <b>{schema}</b></span><span>code <b>{commit}</b></span></div>',
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
          f'{len(user_props)} user properties, commit {commit}')
    for tid, title, _ in TIERS:
        print(f'  {tid} {len(by_tier[tid]):>3}  {html.unescape(title)}')
    if stale:
        print('\nNOTE: these have a purpose but are no longer emitted — remove them from '
              f'{PURPOSES_JSON.name}: ' + ', '.join(stale))


if __name__ == '__main__':
    main()

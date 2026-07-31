# Amplitude Audit — 2026-07-31

Four parallel auditors (taxonomy, call sites, pipeline, runtime capture) + hand verification of every
critical/high finding. 30 findings, 41 areas verified clean.

## Verdict

**Mostly trustworthy, with one systemic bug now fixed.** The biggest problem was double-counting:
five Explore surfaces, the forecast card and every tab switch on iOS 17-25 fired two `block_tapped`
events per tap — often under two different block types, so the duplicates were invisible in any
single chart. All fixed this build. The pipeline itself (event definitions, purposes file, generated
reference, buffering, rate limiting) is in good shape.

## Fixed in this build (hand-verified, each was read at its cited line)

| Fix | Was | File |
|---|---|---|
| Explore category taps double-fired under `explore_category_row` AND `category_row` with different metadata keys | 2x counts | ExploreCategoriesSection.swift (child emitter deleted) |
| Needs-attention metric + weak-category taps double-fired | 2x counts | ExploreNeedsAttentionSection.swift (both child emitters deleted) |
| Health-state link tap double-fired | 2x counts | ExploreHealthStateLinkSection.swift |
| Chainless declining-metric tap double-fired; expand tap kept (now with `action: expand/collapse`) | 2x counts | ExploreDecliningTrendsSection.swift |
| Forecast tap fired a phantom event stamped `screen: home` after the card moved to Explore | phantom Home taps | PersonalHealthForecastCard.swift |
| Tab switches double-fired on iOS 17-25 (CustomTabBar + ContentView.onChange) | 2x on legacy fleet | CustomTabBar.swift (ContentView is now the single emitter, covers both bars) |
| `activation_milestone` mapped only `newEvents.last` — `first_prediction` was permanently swallowed when it landed with `fullUnlock` in the same day-7 pass | near-dead milestone | DashboardViewModel.swift (loop over all events) |
| Renewal-reminder sheet fired `trackFeatureOpen(.paywall)` with no matching close — unbalanced pairs, lost dwell time | broken paywall funnel | RenewalReminderSheet.swift |

## Dashboards must be updated (deliberate changes, not bugs)

Annotate v3.33 (2026-07-31) in Amplitude; these step-change on that date:

- `block_tapped` `source: home_card` / `ask_your_data_card` → now `home_toolbar` (Ask moved to nav bar). Update saved queries.
- `block_tapped` `source: data_coverage` → now `hero_coverage_line`.
- `source: streak_milestone` share/dismiss → zero (card deleted).
- `completed_morning_checkin` + check-in funnel → watch-only volumes (phone card deleted). It still stamps `screen: home` — decide correct attribution.
- Activation banner tap events → zero (banner deleted); `activation_milestone` events unaffected (fire from ActivationSequenceManager).
- `explore_score_hero` / `explore_data_summary` section impressions → exactly 1 per tab open with full-tab dwell (sections pinned out of the lazy stack for scroll perf).
- Tab-switch and Explore tap counts DROP by roughly half on legacy iOS — that is the double-count disappearing, not an engagement drop.

## Open decisions (not fixed, need a call)

1. **`metric` vs `metric_id`**: `metric` is anonymized to category, `metric_id` carries raw values and bypasses anonymization (AppAnalytics.swift:3502-3574). Pick one contract.
2. **Morning check-in attribution**: watch-only now but stamped `screen: home` (MorningCheckInManager.swift:56). Either re-add a phone entry point or re-attribute to the watch source.
3. **Crashlytics vs Amplitude signal handlers fight** (observed live every launch): pick one owner for signal crashes (AmplitudeProvider installCrashHandlers vs Crashlytics).
4. **New surfaces fire nothing**: context-picker open and the collapsed done row have no events — add if the funnel matters.
5. **Dead taxonomy**: 7 unused AppSection cases + StreakMilestoneStore + orphaned copy strings — delete per no-dead-code rule.
6. **`session_quality`/`pre_churn_signal`/`ghost_session`** carry the ended session's id but the live session's `opened_from`/`tab` (AppAnalytics.swift:991-995 fixed only `session_ended`). Thread the ended identity through the siblings.

## Verified clean (highlights of 41)

Event/purposes/reference in sync (158 events, reference regenerates with only a commit-hash diff);
sanitizeEventName memo is correct and thread-safe; all four queue.sync→async conversions safe (no
caller read the result); SectionTracker impression buffer flushes on throttle tick, screen open and
app background (only a crash inside the 1s window loses data); pre-configure error buffer drains in
order; error events rate-limited by design with a visible marker; session_started fires exactly once
per cold launch (runtime-verified); property key sets for the 7 launch events match their builders
(runtime-verified).

## Runtime coverage

Launch-path events verified live from console capture (session lifecycle, screen_viewed, health
snapshot, notification_suppressed). NOT runtime-verified: tap funnels, scroll impressions, paywall
flows — simctl cannot tap; `--ui-test-mode` deliberately mutes analytics (good for data hygiene, but
it means analytics smoke tests need a console-only provider or an XCUITest pass).

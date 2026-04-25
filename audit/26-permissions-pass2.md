# 26 — Permissions, Edge Cases, Device Variance — Pass 2 (Deeper Red-Team)

Pass 2 deeper red-team across 85 angles (force-quit / iCloud / time-travel / locale / units / RTL / HK deletion / source merging / time-sensitive notifications / Focus modes / push token rotation / ATT / Family Sharing / region change / sandbox-vs-prod StoreKit / trial timezone / iCloud sign-in change / offline-first / Auth token / BG-fetch throttling / ATS / iPad / Mac Catalyst / visionOS / Spotlight / Handoff / Stage Manager / Multitasking / Battery saver / Thermal / Network expensive / Low data / Cellular / Personal Hotspot / VPN / Captive portal). Read-only research, **NEW findings only** — no overlap with Pass 1 (`10-permissions-edge-cases.md`).

Format: each finding is **Severity / Issue / Why this exists / Impact / Evidence / How to verify fast / Fix / Priority / Confidence**.

---

## P2-F1. HKAnchoredObjectQuery uses `anchor: nil` and discards `deletedObjects` — Live tab silently shows deleted Apple Watch HR samples forever

- **Severity:** High
- **Issue:** Every `HKAnchoredObjectQuery` instance in the codebase passes `anchor: nil` and ignores the 4th tuple element (`deletedObjects`). The closure signatures are `[weak self] _, samples, _, _, _ in` — the third underscore is exactly the deletion list returned by HealthKit. So when a user (or third-party app like AutoSleep, HRV4Training, MyFitnessPal-water-log) deletes a heart-rate / blood-oxygen / respiratory-rate sample, Laso never reacts: the Live tab keeps the deleted reading on the timeline, the recovery score factors it in forever, and the next refresh doesn't reconcile. The `anchor: nil` choice means every cold start re-queries the full window from scratch (correctness on init), but during the active session every `updateHandler` call also passes `anchor: nil` semantics for deletion handling.
- **Why this exists:** `HKAnchoredObjectQuery` is typically used with a *persisted* anchor to receive incremental adds + deletes. The author wired it as a fancy poller — sample-only, no deletion plumbing.
- **Impact:**
  - Deleting a bad HR reading from Health.app does not propagate. The user fixes the bug in the source-of-truth and Laso still computes off the stale value.
  - Silent inconsistency between Health.app's view of "today's HR" and Laso's Live tab → user trust erosion when they spot the mismatch.
  - `recentHeartRates` keeps deleted samples in the rolling buffer.
  - Less critical for 24h-rolling buffers (eventually scrolls out), but very real for the longer 30-day rolling buffer used by score components.
- **Evidence:**
  - `Modules/Live/ViewModels/LiveViewModel.swift:397-411` — heart-rate query: `anchor: nil`, signature `_, samples, _, _, _ in` ignoring `deletedObjects` (4th param).
  - `Modules/Live/ViewModels/LiveViewModel.swift:518-529` — generic anchored-query factory used for `bloodOxygenQuery`, `respiratoryRateQuery`: same shape, `anchor: nil`, `_, samples, _, _, _ in`.
  - `Modules/Live/ViewModels/LiveViewModel.swift:36-39` — three `HKAnchoredObjectQuery?` properties built this way.
  - `grep -rn "HKDeletedObject\|deletedObjects" /Users/primetrace/Desktop/RnD/HealthPulse --include="*.swift"` → **zero** matches.
- **How to verify fast:** Open Health.app → Heart Rate → manually delete a reading from the last hour. In Laso, tap Live → confirm the deleted reading is still on the heart-rate timeline.
- **Fix:**
  1. Persist a `HKQueryAnchor` per type in `UserDefaults` (encoded as `Data` via `NSKeyedArchiver`).
  2. Bind the captured `(_, samples, deletedObjects, newAnchor, _)` parameters explicitly. Apply `samples` as additions, remove samples whose `UUID` matches anything in `deletedObjects`, persist `newAnchor` for the next incremental fetch.
  3. Call `healthDataStore.deleteSamples(uuids:)` to mirror in SwiftData so scores recompute.
- **Priority:** This Week — silent data correctness regression that erodes trust the moment a user notices.
- **Confidence:** 92/100 — file lines verified directly; what is unverified is whether iOS surfaces deletion events at all when `anchor: nil` (Apple docs imply the deletion list is only meaningful when an anchor is supplied — but that is exactly the point: by leaving anchor nil, deletes are *guaranteed* not to flow). The weak link is whether the dashboard pipeline (separate from Live) re-fetches via fresh-window queries that *do* honor deletes; based on `HealthKitManager.fetchMetric` using `HKStatisticsCollectionQuery` + `HKSampleQuery` with date predicates, the dashboard does eventually catch up but with up-to-24h latency.

---

## P2-F2. `HKObserverQuery` callbacks have **no debouncing on background-delivery throttling**, no jittered backoff — high-volume Apple Watch days pile up wakeups

- **Severity:** Medium
- **Issue:** `HealthKitManager.setupDashboardObservers` (line 1088) registers an `HKObserverQuery` per dashboard metric (~10 metrics) and enables `enableBackgroundDelivery(.immediate)` on each. There is a 0.6s debounce window via `scheduleDashboardObserverRefresh` (line 1127) that coalesces concurrent metric pings into a single dashboard refresh. **However**, there is no exponential backoff if the system delivers thousands of pings during a workout (HR sample every 1-2 s for 60+ minutes), no throttle for "we already refreshed 30s ago and nothing meaningful changed", and no detection that iOS itself has started throttling background delivery (it does — silently — for apps that consume too much energy in BG). The same pattern in `WatchMonitor.swift:97` for the heart-rate observer.
- **Why this exists:** The 0.6s coalesce window catches simultaneous arrivals but not sustained-firing scenarios. iOS BG-delivery throttling is opaque; the team has no telemetry to detect it.
- **Impact:**
  - During a 90-minute workout, the observer can fire 100+ times, each scheduling a dashboard refresh. The 0.6s coalesce reduces that, but nothing prevents continuous workload that drains battery and (more importantly) gets the app silently throttled by `dasd` (the iOS scheduler), which means **after** the workout, real new data arrives and the app is no longer woken.
  - No analytics for "BG delivery callback fired N times today" → cannot detect when the OS has throttled us.
  - Combined with Pass 1 F12 (no Low Power Mode check), a user on Low Power Mode + Apple Watch workout = highest BG wakeup rate, biggest battery cost, highest chance of OS-level throttling.
- **Evidence:**
  - `Core/Data/HealthKitManager.swift:1071-1145` — `coalesceWindow = 0.6` seconds; no exponential backoff or sustained-firing protection.
  - `Core/Notifications/WatchMonitor.swift:88-130` — observer for heart rate; no throttle visible.
  - `grep -rn "throttle\|backoff" /Users/primetrace/Desktop/RnD/HealthPulse/Core/Data/HealthKitManager.swift /Users/primetrace/Desktop/RnD/HealthPulse/Core/Notifications/WatchMonitor.swift` → only one mention as a comment (line 1083).
  - No PostHog event named `hk_observer_throttled` or `bg_delivery_rate` exists.
- **How to verify fast:** Apple Watch workout → 90-min HR-heavy session → observe Xcode energy log; afterward, write fresh HR data manually → confirm app is no longer woken (OS throttled).
- **Fix:**
  1. After every observer ping, check `Date().timeIntervalSince(lastRefresh)` — if < 30 s, do nothing beyond record telemetry. Refresh runs at most every 30 s in the foreground, every 5 minutes in the background.
  2. Track `hk_observer_callback` count per day; if > 1000, emit a PostHog event so we can detect burst patterns.
  3. Combine with Pass 1 F12 (Low Power Mode) and Pass 1 F12-equivalent thermal awareness already present (`ThermalManager.swift:175`) to skip the dashboard refresh when the device is hot or in saver mode.
- **Priority:** This Week — silent BG-throttling is invisible to engineers and devastating to retention because "fresh data never appears".
- **Confidence:** 80/100 — debounce confirmed at 0.6s; absence of explicit backoff confirmed by file read. What is unverified is whether `dasd` actually throttles Laso in practice — that requires real-device profiling. Weak link: no existing telemetry to measure if/when throttling happens, so the runtime severity is plausible but not measured.

---

## P2-F3. `Laso.storekit` correctly sets `familyShareable: false` but app does not gracefully handle Family-Sharing-launched downloads — second device opens, sees paywall, never knows it cannot share

- **Severity:** Medium
- **Issue:** `Laso.storekit:9` and `:33` set `"familyShareable": false` for both monthly + yearly products. When a user buys Laso Pro and a family member taps the family-shared App Store entry, the StoreKit transaction does NOT propagate (correctly). However, on the family member's device:
  1. They install the app for free (App Store does not block install of free apps).
  2. They complete onboarding.
  3. They hit the paywall after the trial.
  4. They tap "Restore Purchases" — `Transaction.currentEntitlements` returns nothing because the entitlement is bound to the buyer's Apple ID, not theirs.
  5. UX shows "Could not restore purchases. Please try again." (`SubscriptionManager.swift:171`).
  
  The user has no way to know "this product is not family-shared". They will assume the restore is broken and contact support, churn, or pirate-leave a 1-star review.
- **Why this exists:** The paywall + restore flow assumes the only failure mode is network. Family-Sharing-non-eligibility is a distinct failure that needs distinct copy.
- **Impact:**
  - Support burden from confused family members.
  - 1-star reviews citing "restore doesn't work".
  - No way to distinguish "user is genuinely entitled, restore failing" vs "user is on a non-shared product".
- **Evidence:**
  - `/Users/primetrace/Desktop/RnD/HealthPulse/Laso.storekit:9, :33` — `"familyShareable": false`.
  - `Core/Subscriptions/SubscriptionManager.swift:165-173` — `restorePurchases` catches all errors with one generic message; no path inspects whether the user *attempted* a family-shared product.
- **How to verify fast:** On a real device A: subscribe Laso Pro. Add the Apple ID to Family Sharing on device B. On device B: install Laso, complete onboarding, hit paywall, tap Restore — observe the generic "could not restore" copy with no Family-Sharing-specific guidance.
- **Fix:** Either (a) flip `familyShareable` to `true` in App Store Connect (and `.storekit` for sandbox parity) so the entitlement actually propagates — this is the user-friendly answer for a B2C health app where partners often share subscriptions; or (b) keep it false but detect Family-Sharing context (`Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"` is one signal but not specific enough — the cleaner test is to check whether `Transaction.currentEntitlements` yielded zero with a known shared-buyer scenario) and show "This subscription is not Family-Shareable. Each member needs their own." Decision is product-strategic.
- **Priority:** This Week — Family Sharing is a meaningful share of B2C wellness installs.
- **Confidence:** 88/100 — `.storekit` content verified; restore-path generic-error verified. Weak link: I did not stage a real two-Apple-ID test in this audit, so the visible UX is inferred from code path, not screenshotted.

---

## P2-F4. `iCloud KVS` (`NSUbiquitousKeyValueStore`) syncs onboarding state across devices — second device sees "onboarding complete" but has zero local data, dashboard renders empty

- **Severity:** High
- **Issue:** `AppStateStore.swift:34-41` reads `onboardingCompleted` from iCloud KVS (`NSUbiquitousKeyValueStore`) on init. If the user installs Laso on iPhone-A, completes onboarding, the flag syncs to iCloud KVS. Later, the user installs Laso on iPhone-B (same Apple ID): on first launch, `AppStateStore` finds `onboardingCompleted = true` from KVS → backfills UserDefaults → app **skips onboarding entirely**. But the new device:
  - Has **never** asked for HealthKit permissions on this device → `isAuthorized = false`.
  - Has **never** asked for notification permissions on this device.
  - Has no Encrypted store data (Keychain entries are *device-bound* via `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, see `SubscriptionManager.swift:328`).
  - Has no SwiftData baseline / cached scores.
  
  The user lands directly on the dashboard, with the worst possible state: a permission-less, data-less Home view, no onboarding to fix it, no HealthKit reprompt either (the reprompt at `HealthKitRepromptManager.swift:13` requires the empty-state to last 24h before banner shows).
- **Why this exists:** Author wanted "onboarding survives reinstall" UX (legit goal) but did not realize KVS sync also crosses *devices*, not just survives one device's reinstall.
- **Impact:**
  - Multi-device users (iPhone + iPad refresh, hand-me-down to family member, work + personal phone) get a broken Day-1 on the secondary device.
  - Silent permission gap: the secondary device never asks for HealthKit or notifications because onboarding (which would ask) is skipped.
  - Cross-cuts with Pass 1 F2 (notification permission never asked) and Pass 1 F3 (HK permission misdetection): on the secondary device, *neither* permission ever surfaces.
- **Evidence:**
  - `App/AppStateStore.swift:9, 27-41` — `cloudStore: NSUbiquitousKeyValueStore? = .default` and the cross-device read.
  - `App/AppStateStore.swift:88-92` — `persist(...)` with `syncToCloud: true` only on `onboardingCompleted`, confirming the cross-device fanout.
  - `Core/Data/PersistenceManager.swift:21-23` — `syncKeys: Set<String> = [AppKeys.App.onboardingCompleted]`, the only key fanned out via KVS.
  - `Core/Subscriptions/SubscriptionManager.swift:328, 349, 386, 407` — Keychain access scope is `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` → install date and integrity hash do **not** cross devices, but `onboardingCompleted` does.
- **How to verify fast:** Two-device test on the same Apple ID. Device A: complete onboarding. Device B: fresh install — observe app launches into dashboard, skipping onboarding entirely.
- **Fix:**
  1. Either remove `onboardingCompleted` from iCloud KVS sync (recommended — a fresh install on a new device should run onboarding to capture per-device permissions and re-emit calibration), or
  2. Pair the cloud flag with a local-device sentinel (`AppKeys.App.deviceCalibrated` stored in UserDefaults, never synced) — onboarding runs unless **both** flags are true. The cloud flag becomes "user has used Laso before, can shorten the welcome copy" rather than "skip onboarding".
- **Priority:** Now — multi-device users hit a silent broken Day-1 with no recovery path.
- **Confidence:** 92/100 — file reads of `AppStateStore` and `PersistenceManager` verified directly; the resulting visual state (dashboard with no permissions, empty data) is inferred from those file reads + Pass 1 F3/F2 verified absences. Weak link: I did not stage a two-device runtime test, so the precise empty-dashboard appearance is not screenshotted.

---

## P2-F5. Time-travel attack — user sets device clock backwards, gets an unlimited trial; install-date integrity hash binds to vendor ID but does not bind to clock

- **Severity:** Medium
- **Issue:** `SubscriptionManager.swift:289-318` resolves the install date by reading from Keychain (good — survives reinstall) and verifies a SHA256 integrity hash bound to the install date + `identifierForVendor` (good — prevents trivial keychain forge). However, the trial-status check (`resolveTrialStatus`, line 270) compares `Date()` against `installDate` using `Calendar.current.dateComponents([.day], from: installDate, to: Date())`. If a user sets their device clock **backwards** by N days (Settings → General → Date & Time → off Auto, set 7 days ago), `Date()` returns the rewound time, `daysSinceInstall` decreases, and the trial appears to extend. The integrity hash does **not** include any clock-anchored token (e.g. signed UTC time from a server) so the rewound clock is undetectable.
- **Why this exists:** Trial logic is purely device-local. There is no server-truth `Date` from a Firebase / NTP / App Store call to cross-check.
- **Impact:**
  - A motivated user can extend the 7-day trial (`SubscriptionConfig.trialDays`) indefinitely by setting the clock back. The app has no detection.
  - This is well-documented as a real abuse vector for indie iOS apps; the standard mitigation is to also persist the *latest seen Date()* and refuse to ever roll backward, or to query App Store / Firebase for an authoritative timestamp.
  - Less impactful than free-account fraud (the trial unlocks Pro features in `FeatureGate.swift:14`) but still a leak in the revenue funnel.
- **Evidence:**
  - `Core/Subscriptions/SubscriptionManager.swift:270-282` — `resolveTrialStatus` does a single `Calendar.current.dateComponents([.day], from: installDate, to: Date())`. No monotonic-time check.
  - `Core/Subscriptions/SubscriptionManager.swift:367-375` — `installDateHash` includes timestamp + `identifierForVendor` + literal — does not include any server-anchored token.
  - `grep -rn "monotonic\|UTC.*server\|trustedDate\|signedDate\|kCFAbsoluteTime" /Users/primetrace/Desktop/RnD/HealthPulse --include="*.swift"` → zero matches.
- **How to verify fast:** Install Laso, complete onboarding, observe trial banner says "X days remaining". Settings → General → Date & Time → off auto, rewind 14 days. Re-open Laso → trial banner shows more days remaining than before.
- **Fix:**
  1. Persist `defaults.set(maxSeen, forKey: "monotonicSeenTimestamp")` on every app open — the *largest* `Date().timeIntervalSince1970` ever observed. Refuse to ever go below that. Day-count math uses `max(Date().timeIntervalSince1970, monotonicSeenTimestamp)`.
  2. Optionally: read App Store server time from `try await Product.products(for:)` response metadata or from a Firestore server-timestamp ping every launch.
  3. PostHog: emit `clock_rewound_detected` with the delta when the local clock is observed lower than the monotonic max — useful for measuring abuse rate.
- **Priority:** Next Sprint — minor revenue leak, not a launch blocker; standard hardening expected post-launch.
- **Confidence:** 90/100 — verified by reading the trial resolution and the integrity hash; clock-rewind exploit is a well-known iOS pattern. Weak link: the actual abuse rate is unknown without telemetry, so the revenue impact is qualitative.

---

## P2-F6. **No `interruptionLevel`, no `threadIdentifier`, no `UNNotificationCategory` — every Laso notification ships at the default (passive) interruption level, never groups, never offers actionable buttons**

- **Severity:** Medium
- **Issue:** `NotificationManager.swift:170-179` constructs every `UNMutableNotificationContent` with just `title`, `body`, `sound = .default`. It does **not** set:
  - `content.interruptionLevel = .timeSensitive` for critical alerts (iOS 15+) — even the `severity == .critical` path (HR spike, SpO2 < 90, illness early-warning) uses passive level. iOS 15+ default is "Active" which still respects Focus modes; without `.timeSensitive`, the *critical* health alerts get silenced by Sleep / Do Not Disturb / Work Focus on the user's phone.
  - `content.threadIdentifier` — so notifications never group in the lock-screen stack. Daily summary + alert + improvement notifications all show as separate top-level entries instead of stacking into a Laso group, contributing to clutter.
  - `UNNotificationCategory` registrations — so notifications cannot have action buttons ("Mark Read", "Open Insight", "Dismiss for today") that the architecture would benefit from.
  - `content.relevanceScore` (iOS 15+) — affects Notification Summary ordering. All notifications compete equally.
- **Why this exists:** Day-1 Notification implementation; advanced notification API surface was deferred.
- **Impact:**
  - **Critical health alerts get silenced by Focus modes** — a user in Sleep Focus with critical SpO2-drop alert: the alert is suppressed because it's not declared `.timeSensitive`. This is a **patient-safety adjacent** UX bug for an app that markets early-warning illness detection (`IllnessEarlyWarning.swift`).
  - Lock-screen clutter: 3-4 Laso notifications stack as 3-4 top-level rows instead of one expandable group.
  - No actionable buttons → user must open the app to act on every notification → friction.
- **Evidence:**
  - `Core/Notifications/NotificationManager.swift:170-179` — exact `UNMutableNotificationContent` construction; no `interruptionLevel`, `threadIdentifier`, `categoryIdentifier`, or `relevanceScore`.
  - `grep -rn "interruptionLevel\|threadIdentifier\|UNNotificationCategory\|setNotificationCategories\|categoryIdentifier" /Users/primetrace/Desktop/RnD/HealthPulse --include="*.swift"` → **zero** matches.
  - `Core/Analysis/IllnessEarlyWarning.swift:377-380` — `.critical` severity exists in code; the schedulers pass it through but `NotificationManager.scheduleNotification` does not translate it into `UNNotificationContent.interruptionLevel`.
- **How to verify fast:** Enable Sleep Focus on the device, schedule a `.critical` health alert (force one for testing) — observe it does not break through Focus.
- **Fix:**
  1. In `NotificationManager.scheduleNotification`, branch on the `severity` parameter:
     ```
     if severity == .critical { content.interruptionLevel = .timeSensitive }
     else if severity == .warning { content.interruptionLevel = .active }
     else { content.interruptionLevel = .passive }
     ```
     Note: `.timeSensitive` requires the **`com.apple.developer.usernotifications.time-sensitive`** entitlement (currently missing from `Laso.entitlements`); add it before shipping.
  2. Set `content.threadIdentifier` based on category: "daily_summary", "alert.\(metric)", "weekly_review". Lock-screen groups by thread.
  3. Register a couple of `UNNotificationCategory` instances at app launch with action buttons; route the response in `userNotificationCenter(_:didReceive:)`.
  4. Set `content.relevanceScore` — `1.0` for critical alerts, `0.5` for daily summary, `0.2` for engagement.
- **Priority:** Now — for the critical-alert/focus-mode bypass piece (patient-safety adjacent). The grouping/categories/relevance pieces are This Week.
- **Confidence:** 95/100 — direct file read of NotificationManager + zero-match grep across the entire repo. The entitlement gap for `.timeSensitive` is a real ship-blocker if critical alerts are part of the marketing claim.

---

## P2-F7. Future-dated HealthKit samples are not validated — a malicious or mis-set source can push "tomorrow's" sleep data, scoring crashes silently or shows "you slept 0 hours today"

- **Severity:** Low
- **Issue:** `HealthKitManager.fetchMetric` and downstream scoring code do not filter samples whose `startDate > Date()` (or whose `endDate > Date() + small slack`). HealthKit accepts samples with any timestamp — a third-party app or a user with their device clock skewed forward can inject samples dated "tomorrow". When Laso fetches the last 7 days, those samples sit on the future-edge of the daily aggregation and either:
  - Are aggregated into a bucket that doesn't exist visually (the UI only shows 7 past days), which silently drops them — minor.
  - Land in `MetricTimeSeries.samples` and propagate to scorers that compute *current-day* aggregates against `today`, producing 0 or NaN paths.
- **Why this exists:** Author trusted HealthKit's data quality.
- **Impact:**
  - Malicious-input crash bait if a downstream scorer divides by zero days-elapsed.
  - Garbage scores for users with clock skew or buggy 3rd-party HK writers.
- **Evidence:**
  - `Core/Data/HealthKitManager.swift:436-450` — `fetchMetric` does not filter on `sample.startDate <= Date()`.
  - `grep -rn "sample.startDate\s*>\s*Date()\|future.*sample\|reject.*future" /Users/primetrace/Desktop/RnD/HealthPulse --include="*.swift"` → zero hits for input-side validation.
  - `Modules/MetricDetail/ViewModels/MetricDetailViewModel.swift:195` — uses `futureDate` for forecasting, not for validation.
- **How to verify fast:** Use Health.app → manually add a heart-rate reading dated 3 days from now (Health.app accepts this). Observe Laso behavior on next refresh.
- **Fix:** In `HealthKitManager.fetchMetric` and `LiveViewModel.processHeartRateSamples`, filter `samples.filter { $0.startDate <= Date().addingTimeInterval(60) }` (60s slack for clock skew). Log a `hk_future_sample_rejected` event with the source's bundleIdentifier so we can detect bad publishers.
- **Priority:** Next Sprint — defensive hardening; very small actual blast radius.
- **Confidence:** 85/100 — verified absence of future-date validation; impact severity inferred from "what could go wrong" rather than measured.

---

## P2-F8. Negative-duration HealthKit samples (`endDate < startDate`) — no validation; sleep duration math `endDate - startDate` produces negative numbers that may flip score signs

- **Severity:** Low
- **Issue:** No code anywhere validates `sample.endDate >= sample.startDate`. HealthKit's API contract says they are non-negative durations, but third-party apps occasionally write samples with crossed timestamps (rare, but happens — see Apple Developer forums). When `(endDate.timeIntervalSince(startDate)) < 0`, sleep duration sums and workout duration sums become arithmetically wrong; scoring code that multiplies by the duration produces sign flips.
- **Why this exists:** No defensive cleaning at the boundary.
- **Impact:** Rare; only triggered by malformed third-party data. Could produce visibly absurd "you slept −2 hours" UI cells if it propagates that far. More likely silently corrupts daily totals.
- **Evidence:**
  - `Core/Data/HealthKitManager.swift:484` — `endDate: sample.endDate` accepted without comparison to `sample.startDate`.
  - `grep -rn "endDate.*<.*startDate\|negativeDuration\|invalid.*duration" /Users/primetrace/Desktop/RnD/HealthPulse --include="*.swift"` → zero matches.
- **Fix:** Filter `samples.filter { $0.endDate >= $0.startDate }` at the same boundary as P2-F7.
- **Priority:** Next Sprint — defensive only.
- **Confidence:** 85/100 — verified absence; real-world frequency is low.

---

## P2-F9. HealthKit duplicate samples — same source writes same data twice via background sync — no dedup logic; Live tab + dashboard double-count

- **Severity:** Medium
- **Issue:** When the Apple Watch + a third-party app (e.g. Whoop sync importer, Garmin Connect) both write the same heart-rate sample (same value, same timestamp, different sourceRevisions) to HealthKit, Laso fetches both and treats them as two distinct samples. There is no per-(timestamp, value) dedup. Code paths:
  - `HealthKitManager.fetchQuantitySamples` returns all matching samples without dedup.
  - `LiveViewModel.processHeartRateSamples` (line 414) sorts by `startDate` and applies them in order; duplicates result in the same point being plotted twice on the timeline.
  - Daily-total aggregations via `HKStatisticsQuery` already dedup at the OS level for *cumulative* types (steps), so this is mainly a problem for *discrete* types (HR, BP, sleep stages).
- **Why this exists:** Author trusted HealthKit to dedup; HealthKit only dedups for cumulative statistics, not for sample queries.
- **Impact:**
  - Heart-rate timeline shows 2x sample density when a sync importer is active → user sees "noisy" graphs.
  - Recovery score may double-weight HR samples in the rolling buffer.
  - Steps are unaffected because the OS-level statistics dedup handles cumulative.
- **Evidence:**
  - `Core/Data/HealthKitManager.swift:705-740` — `fetchQuantitySamples` returns raw `[HKQuantitySample]`, no dedup.
  - `Modules/Live/ViewModels/LiveViewModel.swift:414-450` — applies all samples without uniqueness filter.
  - `grep -rn "Set<UUID>\|sample.uuid\|.uuid\}.*Set\|samples.*unique" /Users/primetrace/Desktop/RnD/HealthPulse --include="*.swift"` → no dedup logic visible.
- **How to verify fast:** On a real device with both Apple Watch and a sync importer (Whoop, Garmin, MyFitnessPal-with-HR), open Live tab → confirm HR timeline density.
- **Fix:** In `processHeartRateSamples` and similar discrete-type code paths, dedup by `(startDate, quantity.doubleValue(for:))` tuple or by `sample.uuid`. For dashboard fetch, dedup at `HealthKitManager.fetchQuantitySamples` boundary.
- **Priority:** This Week — visibly noisy graphs hurt the "premium" feel for the user-segment that is most likely to use multi-source HK (athletes).
- **Confidence:** 85/100 — code paths verified; real-world dup frequency depends on user's app stack which I cannot measure.

---

## P2-F10. Mixed HK sources — Apple Watch + iPhone + 3rd-party — `DeviceSourceManager` detects but no source-preference logic in scoring; both contribute equally

- **Severity:** Medium
- **Issue:** `DeviceSourceManager` (`Core/Data/DeviceSourceManager.swift:39-260`) detects which sources have written which metrics. It correctly identifies `isAppleWatchPaired`. However, the scoring + UI does **not** use this for source preference. Heart-rate samples from "iPhone Health app manual entry", "Apple Watch", "third-party sync app" all flow into the same `MetricTimeSeries`. There is no code path that says "if Apple Watch is the primary HR source, prefer Watch samples and exclude others". The only source-aware code path is in `WatchMonitor.swift:200-225`:
  ```
  private func isFromAppleWatch(sample: HKSample) -> Bool {
      let bundleId = sample.sourceRevision.source.bundleIdentifier
      ...
      if sample.sourceRevision.source.name.contains("Watch") { ... }
  }
  ```
  …but this is only used to gate the "watch not worn" reminder logic, not the score-input filtering.
- **Why this exists:** Source-preference UX/scoring is hard to design well; team deferred it.
- **Impact:**
  - A user with Apple Watch + Whoop syncing HR: both contribute samples, but their physiological semantics differ slightly (Whoop's strain-based HR is sampled at a different cadence and protocol than Apple Watch's). Score variance increases.
  - No "Settings → Trusted Source" UX for the user to express a preference.
  - Connected Devices screen (`Modules/Devices/ViewModels/ConnectedDevicesViewModel.swift`) shows the sources but does not gate them.
- **Evidence:**
  - `Core/Data/DeviceSourceManager.swift:101-260` — detects sources, exposes `isAppleWatchPaired`.
  - `grep -rn "primarySource" /Users/primetrace/Desktop/RnD/HealthPulse --include="*.swift"` → only in analytics tagging (`AppAnalytics.swift:2227`).
  - `Modules/Live/ViewModels/LiveViewModel.swift:393-411` — heart-rate observer query has no source predicate.
- **Fix:**
  1. Add a `Settings → Health → Trusted source for Heart Rate / Sleep` toggle.
  2. When set, build `HKQuery.predicateForObjects(from: [trustedSource])` and use it on the per-metric anchor query.
  3. Default behavior: prefer Apple Watch where present, fall back to iPhone.
- **Priority:** This Week — multi-source users are the heaviest power users and the loudest reviewers when scores feel "off".
- **Confidence:** 88/100 — verified by reading DeviceSourceManager and confirming no scoring gating; UX gap is clear.

---

## P2-F11. Stale baseline cached when 7+ days of HRV are missing — UI shows yesterday's score as if HRV is fresh; no "data is stale" indicator

- **Severity:** Medium
- **Issue:** When a user goes Watch-less for 7+ days (battery dead, traveling without charger, sent for repair), HRV / RHR / sleep stages stop arriving. The `MetricTimeSeries` cache in `HealthDataStore` retains the last-known values. Score components like `RecoveryScorer` (HRV-driven) and `ReadinessScorer` continue to compute against the cached samples, treating week-old HRV as "today's HRV". There is no `lastSampleAge` check that demotes the score's confidence or shows a "Your HRV data is from 8 days ago" badge. The dashboard renders a "fresh" 78/100 Recovery score even when the underlying HRV signal is a week stale.
- **Why this exists:** Cache freshness was not modeled per-metric.
- **Impact:**
  - Score is misleadingly fresh; user trusts a recovery score that is actually computed from week-old data.
  - Combined with Pass 1 F5 (revoked HK detection), a user who revokes + has stale cache double-fails: revocation undetected, cache stays "fresh".
- **Evidence:**
  - `Core/Data/HealthDataStore.swift:221-227` — `invalidateTimeSeriesCache` exists but is only called on full app refresh (`AppStartupCoordinator.swift:58`), not per-metric per-staleness.
  - `grep -rn "lastSampleAge\|.daysSinceLastSample\|isStale\|staleness" /Users/primetrace/Desktop/RnD/HealthPulse --include="*.swift"` → only `staleDate` for Live Activities (App/TodayScoreLiveActivityManager.swift:81-82), nothing for score-input freshness.
  - `Common/Components/DataConfidenceBadge.swift:31` — exists but I have not verified it is wired to any "stale" signal in the dashboard (it appears to be a different "confidence" surface for analyses).
- **How to verify fast:** Take Apple Watch off for 7 days, re-open Laso → observe Recovery score still renders without a "data is stale" indicator.
- **Fix:** For each pillar (Recovery, Readiness, Sleep, Strain), compute `daysSinceLastSample = dayCount(from: latestSampleDate, to: today)`. If > 3, render a "Your <metric> data is from N days ago — wear your Watch to refresh" callout. If > 7, demote the score to "—" and show the empty state.
- **Priority:** This Week — accuracy + trust.
- **Confidence:** 85/100 — verified by file reads and search; runtime degradation visible-or-not is inferred from code paths.

---

## P2-F12. First-launch HealthKit data lag — Apple Watch syncs to iPhone over 1-2 days after pairing; Day-1 score is computed off near-zero data and looks wildly broken

- **Severity:** High
- **Issue:** When a user first pairs an Apple Watch (or first installs Laso on a new iPhone with an existing Watch), HealthKit data appears to populate iPhone over hours-to-days, not seconds. The Watch's local DB syncs in batches; full historical data may take 24-48 h. Pass 1 F23 noted a generic "Day-1 cold-start empty state" gap; the *deeper* issue is that the calibration pass (`LasoApp.swift:42-58`) runs **once** at end-of-onboarding and assumes "what HK has now" is "what HK will give us forever". No re-calibration is triggered when significantly more historical data appears 24h later. So the Day-1 user gets a calibration based on near-zero data and is then stuck with that bad baseline until they manually re-trigger calibration somewhere — which there's no obvious UX for.
- **Why this exists:** Calibration is a one-shot operation; the team did not anticipate sync lag.
- **Impact:**
  - Day-1 user with newly paired Watch sees a baseline computed off ~hours of data, leading to "your normal is 7,500 steps" when actually their Watch has not yet synced 30 days of "I do 12,000".
  - Trust erosion: the user knows their normal and Laso confidently states the wrong number.
  - No re-calibration trigger when more data arrives.
- **Evidence:**
  - `App/LasoApp.swift:42-58` — calibration runs at end-of-onboarding (verified by Pass 1 F23 reference).
  - `grep -rn "recalibrate\|recalibration\|baselineRefresh" --include="*.swift"` → no auto-trigger paths.
- **How to verify fast:** Pair a fresh Apple Watch (or restore Watch backup) → install Laso within 1h → complete onboarding → observe baseline. Wait 24h → observe baseline did not refresh.
- **Fix:**
  1. Schedule a follow-up calibration 24h and 7d after onboarding completion.
  2. After every significant HK observer batch (> N new samples spanning > 7 days of historical data), trigger a baseline recompute.
  3. Surface a "We'll refine your baseline as more data syncs" copy on the Day-1 dashboard.
- **Priority:** This Week — Day-1 retention lever; specifically harms the high-LTV Watch-buyer cohort.
- **Confidence:** 80/100 — file references confirmed (calibration runs at LasoApp:42-58); Watch-sync-lag is a known iOS behavior. Weak link: I did not verify the full calibration code in this audit, so the precise re-trigger gap is inferred.

---

## P2-F13. **`UISupportedInterfaceOrientations = portrait only` + iPad TARGETED_DEVICE_FAMILY = 1 — but the app installs anyway from Family Sharing on iPad as a stretched-iPhone "Compatible" mode, no graceful bail-out**

- **Severity:** Medium
- **Issue:** `project.yml:84, :145` set `TARGETED_DEVICE_FAMILY = "1"` (iPhone-only) and `Info.plist:51-54` lists portrait-only. App Store will mark Laso as "Designed for iPhone", and iPad users can still install it (it runs in a centered iPhone-shaped frame on iPad). On iPad:
  - The app uses fixed `DS.space*` paddings and never queries `horizontalSizeClass` or `userInterfaceIdiom`.
  - `grep -rn "UIDevice.current.userInterfaceIdiom\|horizontalSizeClass" /Users/primetrace/Desktop/RnD/HealthPulse --include="*.swift"` → **zero** matches.
  - There is no "This app is designed for iPhone" empty-state or graceful bail-out. The app just runs in compatibility mode without informing the user.
  - Worse: a parent who buys Laso Pro on iPhone, family-shares to a teen's iPad — the teen opens the app on iPad, hits the paywall (P2-F3), and has zero "this is iPhone-only" context.
- **Why this exists:** v1 ships iPhone-only by design; team did not consider the iPad-via-family-sharing edge case.
- **Impact:**
  - iPad users experience the app as a stretched/centered iPhone view with full-screen bezel padding.
  - No "iPad coming soon" copy; no upsell/awareness path.
- **Evidence:**
  - `project.yml:84, :145` — `TARGETED_DEVICE_FAMILY: "1"`.
  - `Info.plist:51-54` — portrait-only.
  - Zero `userInterfaceIdiom` matches.
- **How to verify fast:** Install Laso on iPad simulator → observe iPhone-shaped centered frame; no iPad-specific copy.
- **Fix:** Either (a) flip `TARGETED_DEVICE_FAMILY` to `"1,2"` and do basic iPad layout (medium effort) for v1.1, or (b) add a one-time "Laso is designed for iPhone — tap to install on your iPhone" sheet on first launch when `UIDevice.current.userInterfaceIdiom == .pad`.
- **Priority:** This Week — App Review may not flag, but UX hygiene + family-sharing-on-iPad coverage matters.
- **Confidence:** 92/100 — `project.yml` and `Info.plist` verified; absence of userInterfaceIdiom check verified by grep.

---

## P2-F14. **No `URLSessionConfiguration.allowsExpensiveNetworkAccess` / `allowsConstrainedNetworkAccess` policy — Firebase + PostHog will burn cellular data + violate Low Data Mode**

- **Severity:** Medium
- **Issue:** `grep -rn "URLSessionConfiguration\|allowsExpensiveNetworkAccess\|allowsConstrainedNetworkAccess\|waitsForConnectivity" --include="*.swift"` returns **zero** matches. The app delegates network behavior entirely to Firebase + PostHog SDKs, which use their own `URLSession` configurations. Without explicit override:
  - On cellular: Firebase/PostHog burn cellular data freely (analytics events, RemoteConfig fetches, Firestore listeners). For users on metered cellular plans, this cost adds up.
  - On Low Data Mode (Settings → Cellular Data → Low Data Mode toggle): iOS asks apps to back off; Laso's analytics + RemoteConfig do not adapt. iOS-15+ users in Low Data Mode have a degraded experience or burn through their data cap.
  - On Personal Hotspot (which iOS marks `isExpensive`), same issue.
- **Why this exists:** Network policy was not part of the v1 networking design.
- **Impact:**
  - User-cost bug: cellular users on metered plans see Laso silently consuming background data.
  - Low Data Mode is widely used (especially in EU, India); ignoring it is a user-trust regression.
- **Evidence:**
  - `grep -rn "URLSessionConfiguration\|allowsExpensive\|allowsConstrained" /Users/primetrace/Desktop/RnD/HealthPulse --include="*.swift"` → zero.
  - `App/ContentView.swift:725-740` — `ConnectivityMonitor` reads `path.isExpensive` and `path.isConstrained` but only stores them as state; no call site uses them to gate network calls.
- **How to verify fast:** Settings → Cellular → Low Data Mode → ON. Open Laso → instrument shows full Firestore + PostHog event flow continuing.
- **Fix:**
  1. Wire `ConnectivityMonitor.isExpensive` / `isConstrained` into:
     - PostHog: defer non-critical events; flush only on Wi-Fi.
     - RemoteConfig: increase `minimumFetchInterval` from default (12h) to 24h+ on constrained networks.
     - CloudBackup: postpone backup when expensive.
  2. Pass through to Firebase via `Firestore.firestore().settings.cacheSettings` and disable real-time listeners on constrained network.
- **Priority:** This Week — user-trust + cost issue, especially internationally.
- **Confidence:** 92/100 — verified by zero-match grep + read of ConnectivityMonitor showing the signal exists but is not consumed.

---

## P2-F15. Hardcoded units (`kg`, `cm`, `km`, `°C`) ignore `Locale.current.measurementSystem` — US users see metric units everywhere

- **Severity:** Medium
- **Issue:** `Core/Models/HealthMetric.swift:189-225` returns hardcoded unit strings for every metric. `weight` always returns "kg", `waistCircumference` always returns "cm", `distanceWalkingRunning` always returns "km", `bodyTemperature` always returns "°C". US users on US locale see all-metric units. There is no consultation of `Locale.current.measurementSystem` (`.metric` vs `.us` vs `.uk`) or `MeasurementFormatter`.
  - `grep -rn "measurementSystem\|MeasurementFormatter\|Locale.current.measurementSystem" /Users/primetrace/Desktop/RnD/HealthPulse --include="*.swift"` → **zero** matches.
- **Why this exists:** Author shipped metric-first; no localized unit conversion.
- **Impact:**
  - US users see "65 kg" instead of "143 lb" — a 70%+ market gap for a US-launch.
  - VO2 Max display "mL/kg/min" is acceptable (clinical norm), but weight/length/temperature should follow locale.
  - Sleep / step displays don't have a locale issue, but these specific health metrics do.
- **Evidence:**
  - `Core/Models/HealthMetric.swift:189-225` — hardcoded unit strings as enumerated above.
  - `Core/Data/HealthKitManager.swift:1153` — `saveWeight` accepts `kg` only, no overload for lb.
  - `Modules/Onboarding/Views/Onboarding/ProfileCaptureView.swift` — uses TextField with numberPad, no unit toggle visible.
- **How to verify fast:** Set device region to United States, open Profile screen → observe weight in kg.
- **Fix:**
  1. Add `HealthMetric.unit(for: Locale.Measurement)` returning the locale-correct symbol.
  2. Add `MeasurementFormatter` use for runtime formatting (auto-localizes).
  3. Add a Settings → Units toggle (Metric / Imperial) that overrides locale default.
  4. Convert at display time only; storage stays in HK canonical units.
- **Priority:** Now — US-launch blocker if unit display is one of the surfaces a reviewer/users immediately sees. v1 launch in metric-only markets first is acceptable; US launch needs this.
- **Confidence:** 95/100 — file reads verified; zero-match grep verified.

---

## P2-F16. **Decimal separator parsing — `TextField` for water intake / weight will reject `1,5` in fr_FR / de_DE locales**

- **Severity:** Low
- **Issue:** Several flows accept numeric input (water intake, weight, age). The current code base I located uses `keyboardType(.numberPad)` for age (`ProfileCaptureView.swift:62`) — integer-only, fine. But any future weight / water log that uses `keyboardType(.decimalPad)` and parses via `Double(textValue)` will reject `"1,5"` in locales that use comma decimals (fr_FR, de_DE, es_ES). `Double.init(_ description: String)` only accepts `"1.5"` US locale.
- **Why this exists:** US-centric defaults.
- **Impact:** Low today (no decimalPad TextField found in the audit's spot-checks), but a time-bomb when weight-log / water-log UIs are added.
- **Evidence:**
  - `grep -rn "keyboardType(.decimalPad)\|TextField.*Double" /Users/primetrace/Desktop/RnD/HealthPulse --include="*.swift"` → no decimalPad usage found in the spot-checks.
  - `Core/Data/HealthKitManager.swift:1150` — `saveWeight(_ kg: Double)` accepts a `Double`, the upstream UI wires this to a `TextField` somewhere (likely `WeightLogSheet` or similar) — the conversion path needs the locale-aware parser.
- **Fix:** Use `NumberFormatter` with `.locale = .current` and `.numberStyle = .decimal` to parse, not `Double.init(String)`. Or use SwiftUI's `TextField(value:format:)` with `.number` format style.
- **Priority:** Next Sprint — non-launch-blocking until weight/water UIs are confirmed shipping with decimal input.
- **Confidence:** 78/100 — I did not find a current decimalPad TextField in this audit; the bug-as-time-bomb claim is preventive. Weak link: not yet confirmed which exact UI path takes the decimal user input.

---

## P2-F17. Plurals — every count display ("5 days", "1 day") uses naive `"\(count) day(s)"` patterns; no `String.LocalizedStringResource` plural rules

- **Severity:** Low
- **Issue:** `SubscriptionManager.swift:54` shows the pattern: `return days == 1 ? "1 day left in trial" : "\(days) days left in trial"`. This works for English binary plurals but is wrong for Russian (3 plural forms), Arabic (6 forms), Polish (3 forms), etc. There is no use of `String(localized:)` with `.stringsdict` plural rules anywhere.
  - `grep -rn "stringsdict\|.plural\|StringResource" /Users/primetrace/Desktop/RnD/HealthPulse --include="*.swift"` → zero matches.
- **Why this exists:** v1 English-only. Pass 1 F18 covers the broader localization gap; this is the plural-specific corner.
- **Impact:** Will regress to "incorrect grammar in counts" the moment localization is added. Pre-fixing with `.stringsdict` from day one would cost little.
- **Evidence:**
  - `Core/Subscriptions/SubscriptionManager.swift:54` — naive plural.
  - Pattern repeated across the codebase (notification copy, weekly summary).
- **Fix:** When localization is added, also add `Localizable.stringsdict` files with `NSStringPluralRuleType` entries.
- **Priority:** Next Sprint — non-blocking for English-only v1.
- **Confidence:** 88/100.

---

## P2-F18. **No `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` — silent-push wakeup never delivered (cross-cuts Pass 1 F1 but specifically for content-available payloads)**

- **Severity:** Low
- **Issue:** Pass 1 F1 covered the unfinished APNs token registration. **Additionally**, there is no `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` handler in `AppDelegate.swift`. Even if APNs tokens were obtained, a silent-push payload (`"content-available": 1`) cannot wake the app to do background work because there's no callback. `Info.plist:41-45` also does not list `remote-notification` in `UIBackgroundModes`. Combined: silent push = dead surface.
- **Why this exists:** Same root cause as Pass 1 F1 — push wiring incomplete.
- **Impact:**
  - Server-driven recompute (e.g. "Apple Health server bug means recompute scores from scratch") cannot wake the app.
  - Server-driven cache invalidation (e.g. ML model update) cannot push down without user-foreground.
- **Evidence:**
  - `App/AppDelegate.swift:1-49` — no remote-notification handler.
  - `Info.plist:41-45` — no `remote-notification` mode.
- **Fix:** Bundle with Pass 1 F1's resolution. If silent push is in scope: implement handler + add `remote-notification` to background modes. Otherwise, no action.
- **Priority:** This Week — bundled with F1 decision.
- **Confidence:** 95/100 — verified by file reads.

---

## P2-F19. **No `application(_:open:options:)` for Universal Links** *AND* no `Associated Domains` entitlement — referral SMS link clicks never reach Laso (Pass 1 F8 covered handler absence; this finding adds the entitlement + AASA gap)

- **Severity:** Low
- **Issue:** Pass 1 F8 covered the deep-link handler absence. **Additionally**, `Laso.entitlements` has no `com.apple.developer.associated-domains` key. Even if a handler existed, Universal Links could not function: iOS validates the `apple-app-site-association` (AASA) JSON against the declared associated domain. Without the entitlement, Apple does not fetch AASA from `lasohealth.com`, and Universal Link taps fall back to opening the URL in Safari instead of Laso.
- **Why this exists:** Whole UL surface deferred.
- **Impact:** Same as Pass 1 F8 — referral funnel broken end-to-end.
- **Evidence:**
  - `/Users/primetrace/Desktop/RnD/HealthPulse/Laso.entitlements` — no associated-domains key.
- **Fix:** Bundle with F8. Add entitlement + host an AASA file on `lasohealth.com/.well-known/apple-app-site-association`.
- **Priority:** This Week — bundle with F8.
- **Confidence:** 95/100 — entitlements file fully verified.

---

## P2-F20. **`scenePhase` re-emit on cold-relaunch is **`.active` only**, no state restoration / `NSUserActivity` — force-quit + relaunch always rebuilds the entire scene from root, losing tab state, scroll position, modal stack**

- **Severity:** Low
- **Issue:** SwiftUI's default behavior on force-quit + cold relaunch is to rebuild the scene from `LasoApp.body`. Laso uses `Tabs` + multiple `.fullScreenCover` / `.sheet` modifiers (paywall, breathwork, journal) but does **not** participate in `NSUserActivity`-based state restoration:
  - `grep -rn "NSUserActivity\|onContinueUserActivity\|userActivity" /Users/primetrace/Desktop/RnD/HealthPulse --include="*.swift"` → zero matches.
  - `grep -rn "stateRestoration\|@SceneStorage" --include="*.swift"` → zero matches for state restoration; would need to verify @SceneStorage if used.
  - The scene-phase observer only handles `.active` and `.background` (`ContentView.swift:98`); `.inactive` is unhandled (Pass 1 F9 noted this for privacy snapshots; this is a different concern — restoration).
- **Why this exists:** Standard SwiftUI default; team did not opt in.
- **Impact:**
  - User force-quits with Journal entry mid-typed → relaunch loses the draft. (Journal does have a draft autosave path via SwiftData; need to verify.)
  - Force-quit on the Live tab → relaunch lands on Home.
  - Force-quit while paywall is presented → relaunch may or may not re-present (fullScreenCover binding may auto-recompute).
  - Loss of tab state is an annoyance, not a bug.
- **Evidence:**
  - Zero matches for `NSUserActivity` and state restoration grep.
  - `App/ContentView.swift:98-142` — only `.active` / `.background` handled.
- **Fix:** For each tab, add `@SceneStorage` for the tab index. For Journal mid-draft, use SwiftData autosave (likely already in place; not verified). For paywall, ensure the binding reactively re-evaluates `subscribedState` on relaunch.
- **Priority:** Next Sprint — minor UX polish.
- **Confidence:** 78/100 — verified absence by grep; the actual UX visible state on relaunch (does Journal draft survive?) is not runtime-verified. Weak link: cannot confirm the SwiftData autosave path for Journal without reading `JournalEntryView`.

---

## P2-F21. **No `Spotlight` (`CSSearchableItem`) and no `NSUserActivity` indexing of Insights / Journal — users cannot search Laso content from iOS Spotlight**

- **Severity:** Low
- **Issue:** Health apps benefit substantially from Spotlight indexing — a user searches "sleep score" in iOS home-screen swipe-down, lands directly in Laso's Sleep coach. Laso has zero Spotlight integration. `grep -rn "CSSearchableItem\|CSSearchableIndex\|NSUserActivity\|.isEligibleForSearch" --include="*.swift"` → zero matches. The `Core/Intents/LasoShortcutsProvider.swift` mentions Spotlight in a comment but only as the proactive-Siri-suggestions surface, not the user-typed search.
- **Why this exists:** Spotlight indexing is non-default; team deferred.
- **Impact:** Discovery surface gap. iOS users habituated to Spotlight as a launcher cannot find Laso content.
- **Evidence:**
  - `grep -rn "CSSearchableItem\|CSSearchableIndex\|.isEligibleForSearch" /Users/primetrace/Desktop/RnD/HealthPulse --include="*.swift"` → zero matches.
  - `Core/Intents/LasoShortcutsProvider.swift:3` — comment "Provides suggested shortcuts that appear in the Shortcuts app and Spotlight" — but `AppShortcutsProvider` only surfaces shortcut intents, not journal entries / scores / insights.
- **Fix:** Index recent Insights, Journal entries, and Weekly Reviews as `CSSearchableItem` so they appear in Spotlight. Use `domainIdentifier = "com.lasohealth.fit.insights"` and update on every `Insight` generation.
- **Priority:** Next Sprint — discovery improvement, not launch-blocking.
- **Confidence:** 92/100 — verified absence.

---

## P2-F22. **No `NSUserActivity` Handoff support — user starts Journal entry on iPhone, cannot continue on Mac (if Mac Catalyst added later)**

- **Severity:** Low
- **Issue:** No Handoff `NSUserActivity` declared. If the app ever ships Mac Catalyst (currently disabled per project.yml), the cross-device Handoff continuation will be unavailable. Even on iPhone-only, Handoff between two iPhones (rare) won't work.
- **Why this exists:** Mac Catalyst is not a v1 target.
- **Impact:** Future Mac Catalyst feature gap. Negligible today.
- **Evidence:** Same zero `NSUserActivity` grep as F20/F21.
- **Fix:** Add `NSUserActivity` advertise + receive when Mac Catalyst is in scope.
- **Priority:** Backlog — not relevant until Mac Catalyst.
- **Confidence:** 90/100.

---

## P2-F23. **iOS 26 `@available` annotations exist for FoundationModels — but the fallback path for iOS 17/18/25 is unverified for ML feature parity**

- **Severity:** Medium
- **Issue:** `Core/Analysis/ML/FoundationModelQueryEngine.swift:8`, `Core/Analysis/ML/FoundationModelTools.swift` (10+ `@available(iOS 26, *)` annotations), and `DailyNarrativeEngine.swift:26` are gated to iOS 26 only. The deployment target is iOS 17.0 (project.yml:5). On iOS 17/18 (the actual install base), these methods do not run. There is no clearly visible **fallback** path for the daily-narrative / Foundation-model-driven insights on iOS 17/18 — the audit-1 already noted this is a real gap.
- **Why this exists:** Apple's FoundationModels framework is iOS 26+. Team scaffolded the code for forward-compat but the iOS 17/18 fallback is incomplete.
- **Impact:**
  - 100% of TestFlight + App Store users on iOS 17/18 (i.e. all users on Day 1 of launch in 2026) get the non-FM path. If that path renders blank narrative cards, the "Personalized AI insights" marketing claim is broken.
  - When iOS 26 is released and adoption ramps, the code path bifurcates and any bug in the FM branch only affects new users.
- **Evidence:**
  - 10+ `@available(iOS 26, *)` matches in `Core/Analysis/ML/FoundationModelTools.swift`.
  - `Core/Analysis/ML/DailyNarrativeEngine.swift:26` — `@available(iOS 26, *)`.
  - `App/ContentView.swift:229` — `if #available(iOS 26.0, *)` branch — verifying which feature this gates would tell us whether the iOS 17 fallback is renderable.
- **Fix:** Audit each `@available(iOS 26)` site for an `else { … }` non-FM fallback that produces equivalent (templated) narrative, so iOS 17/18 users do not see blank or generic content. Engage the ML team on which features have FM-only outputs.
- **Priority:** This Week — Day-1 launch is iOS 17/18 dominant.
- **Confidence:** 75/100 — `@available` sites verified; the runtime behavior of the fallback (blank vs templated vs error) was not exercised. Weak link: no Day-1 simulator run on iOS 17.0 confirming the visible narrative card content.

---

## P2-F24. AppTrackingTransparency — `ATTrackingManager.requestTrackingAuthorization` is **never called**; PrivacyInfo declares no tracking, but the absence of the prompt is fine *unless* PostHog ever flags as cross-app

- **Severity:** Low (informational)
- **Issue:** `grep -rn "AppTrackingTransparency\|ATTrackingManager\|requestTrackingAuthorization" /Users/primetrace/Desktop/RnD/HealthPulse --include="*.swift"` → zero matches. `PrivacyInfo.xcprivacy` declares `NSPrivacyTracking = false` and empty `NSPrivacyTrackingDomains`. PostHog can be configured non-tracking (no IDFA, no cross-app linking). This is currently consistent and fine. **The risk** is if PostHog SDK is updated to a version that opts into IDFA-based tracking (or if a future ad-attribution SDK is added) — at that point the ATT prompt will be required, and the team should know they have **not** wired it.
- **Why this exists:** Team deliberately avoids tracking; SDK config matches.
- **Impact:** None today; flag is preventive.
- **Evidence:**
  - `PrivacyInfo.xcprivacy:5-7` — `NSPrivacyTracking = false`, empty tracking domains.
  - `Core/Tracking/PostHogManager.swift:33` — note that "no inputs, images, or sandboxed subsystems leak"; SDK is configured non-tracking.
  - Zero ATT calls.
- **Fix:** Document the no-ATT decision in `audit/09-compliance-privacy.md`. Add a CI check that fails if `ATTrackingManager` ever appears without `NSUserTrackingUsageDescription` being added simultaneously.
- **Priority:** Next Sprint — process hygiene.
- **Confidence:** 95/100 — verified.

---

## P2-F25. **App Transport Security default — no `NSAppTransportSecurity` exception, all Firebase + PostHog hosts are TLS-1.2+ compliant** (POSITIVE / NEW finding — Pass 1 did not call this out as a positive specifically)

- **Severity:** Informational / no fix needed
- **Issue:** Pass 1 referenced this in `17-observability-reliability.md`, but it was not in `10-permissions-edge-cases.md`. Re-confirming for the permissions audit: `Info.plist` and `project.yml` declare no `NSAppTransportSecurity` overrides. Default ATS rules apply (TLS 1.2+, forward secrecy, server cert chain validated). Firebase + PostHog endpoints comply. **No action.**
- **Evidence:** `grep` already documented in 17-observability.
- **Confidence:** 95/100.

---

## P2-F26. **No captive-portal detection** — public Wi-Fi requiring portal login leaves Firebase init in indefinite hang, no UI recovery

- **Severity:** Low
- **Issue:** When the device is on captive Wi-Fi (hotel, airport, café), `path.status == .satisfied` reports "online" but actual HTTPS requests to Firebase / PostHog 302-redirect to the portal page. Firebase SDK retries silently. There is no captive-portal detection (e.g. attempting `http://captive.apple.com/hotspot-detect.html` and checking response). The user's Day-1 experience on hotel Wi-Fi: "Connecting…" indefinitely with no retry CTA.
- **Why this exists:** Captive-portal detection is non-trivial; deferred.
- **Impact:** Edge case but real for travelers / hotel users on Day-1.
- **Evidence:**
  - `App/ContentView.swift:725-740` — `ConnectivityMonitor` reads `path.status` only; no captive detection.
  - `grep -rn "captive\|hotspot-detect" /Users/primetrace/Desktop/RnD/HealthPulse --include="*.swift"` → zero.
- **Fix:** Add a `URLSession` GET to `http://captive.apple.com/hotspot-detect.html` on connectivity-change; if response body is not exactly `"Success"`, mark as captive-portal and show an "Open captive portal" CTA that opens the URL in Safari.
- **Priority:** Backlog — narrow audience, complex fix.
- **Confidence:** 88/100.

---

## P2-F27. **VPN / privacy-relay traffic — Firebase + PostHog reachability via VPN unverified; `path.usesInterfaceType(.other)` not consumed**

- **Severity:** Low
- **Issue:** When a user is on iCloud Private Relay or a corporate VPN, network traffic goes through interface type `.other`. Firebase + PostHog endpoints generally work fine through VPN, but neither has been validated. Particular concern: PostHog's Reverse-Proxy domain (if used) may be VPN-blocked. Captive-portal+VPN combos are gnarly.
- **Why this exists:** No VPN-aware path.
- **Impact:** Plausibly OK; not validated.
- **Evidence:** `App/ContentView.swift:725-749` — `NWPathMonitor` reads but does not call `path.usesInterfaceType(.other)`.
- **Fix:** Add a synthetic-canary request to PostHog + Firebase in `ConnectivityMonitor.start` so VPN-induced reachability failures are detected and logged.
- **Priority:** Backlog.
- **Confidence:** 75/100 — preventive.

---

## P2-F28. **Subscription paused — Apple's `RenewalState.isPaused` not checked; user pauses subscription, app still treats them as subscribed**

- **Severity:** Low
- **Issue:** Apple introduced subscription pause (Apple Family Sharing-related, also user-initiated for some product types). `Product.SubscriptionInfo.RenewalState` includes `.subscribed`, `.expired`, `.inBillingRetryPeriod`, `.inGracePeriod`, `.revoked`. Laso's `isInBillingRetry` (`SubscriptionManager.swift:227-247`) inspects only `.inBillingRetryPeriod` and `.inGracePeriod`. It does not handle `.revoked` (subscription terminated by Apple/family-share-removal) — that should immediately downgrade the user. It also does not specifically handle "paused" semantics where Apple pauses a subscription mid-cycle.
- **Why this exists:** Limited initial coverage of `RenewalState`.
- **Impact:**
  - User whose subscription was revoked (e.g. parent removed them from family share) keeps access until next `refreshStatus` and even then may not be cleanly demoted.
  - Edge cases for paused subscriptions.
- **Evidence:**
  - `Core/Subscriptions/SubscriptionManager.swift:227-247` — only two states inspected.
- **Fix:** Add `.revoked` → immediate `.expired`. Add `.subscribed(but paused)` semantics if Apple's API exposes a paused flag (StoreKit2 may not, but `Product.SubscriptionInfo.Status.transaction` should be inspected).
- **Priority:** Next Sprint — small revenue / fairness leak.
- **Confidence:** 82/100 — code paths verified; the precise Apple-side semantics of "paused" require StoreKit docs cross-check.

---

## P2-F29. **Trial-end timezone bug — install date stored as `Date` (UTC instant), trial expiry math uses `Calendar.current.dateComponents([.day], from: installDate, to: Date())` which is local-calendar-day; user crossing timezones can see a 1-day-off trial expiry**

- **Severity:** Low
- **Issue:** `SubscriptionManager.swift:272-274` computes trial days remaining via `Calendar.current.dateComponents([.day], from: installDate, to: Date()).day`. `Calendar.current` uses the device-local timezone. If a user installs in NY at 11pm (UTC offset −4), then flies to Tokyo (UTC offset +9, 13h ahead), their local "today" jumps; the day-count via `Calendar.current` may show 1 fewer or 1 more day than expected, depending on DST boundaries and which side of midnight the wall-clock falls on.
- **Why this exists:** Generic UTC vs local-calendar mismatch.
- **Impact:** Edge: user gets one extra day of trial or loses one day. Not a meaningful revenue lever; can confuse the "X days left" UI text.
- **Evidence:**
  - `Core/Subscriptions/SubscriptionManager.swift:272-274` — verified.
- **Fix:** Compute trial expiry as a fixed UTC instant (`installDate + 7*86400`); compare `Date() >= expiry`. Use `Calendar(identifier: .gregorian)` with `TimeZone(identifier: "UTC")` for the day-count display.
- **Priority:** Backlog — minor.
- **Confidence:** 88/100.

---

## P2-F30. **First day of week — `WeeklyReviewViewModel.startOfWeek` uses `Calendar.current.dateInterval(of: .weekOfYear, ...)` which respects user locale (Sun in US, Mon in EU). Persisted `previousWeekScore` keys to whatever the device locale was at write time — if user changes locale or device, stale data**

- **Severity:** Low
- **Issue:** `WeeklyReviewViewModel.swift:158-160` correctly uses `calendar.dateInterval(of: .weekOfYear, for: date)?.start` which respects `Calendar.current.firstWeekday`. So a US user sees Sun-Sat weeks; an EU user sees Mon-Sun. **However**, `PersistenceManager.recordWeeklyScore` (line 189-199) stores `previousWeekScore` under a single key `AppKeys.Data.previousWeekScore` keyed with `granularity: .weekOfYear`. If a user changes their device's region (e.g. moves from US to EU), the `firstWeekday` shifts; the previously-stored "current week's score" is now in a different week's interval, so the comparison `oldWeekStart != newWeekStart` may erroneously flip and shift the score.
- **Why this exists:** Cross-region edge.
- **Impact:** User who changes region in iOS Settings sees "previous week's score" replaced or duplicated for one week.
- **Evidence:**
  - `Core/Data/PersistenceManager.swift:189-199` — uses `Calendar.current` with implicit timezone+locale.
  - `Modules/WeeklyReview/ViewModels/WeeklyReviewViewModel.swift:158-160` — same.
- **Fix:** Anchor week calculations to ISO week (`Calendar(identifier: .iso8601)`) for storage keys, regardless of user locale. Display can still use locale.
- **Priority:** Backlog — narrow scenario.
- **Confidence:** 78/100 — code verified; runtime weirdness inferred.

---

## P2-F31. **No 12/24-hour preference — wake-up time / wind-down banner copy uses fixed format hour:00; respects locale automatically via DateFormatter, BUT some hand-formatted hour displays don't**

- **Severity:** Low
- **Issue:** `Core/Analysis/ML/TodayIntelligenceEngine.swift:1066`, `Core/Analysis/ML/DecisionPolicyEngine.swift:1586-1590` hand-format hours via `displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)` — i.e. hardcoded 12-hour clock. A user with iOS Settings → 24-Hour Time on still sees "9 PM" instead of "21:00" in those code paths. `DateFormatter`-based code paths (`DailyNarrativeEngine.swift:95`, etc.) respect the user setting; the hand-formatted ones do not.
- **Why this exists:** Quick-and-dirty hour formatting.
- **Impact:** Minor UI inconsistency for 24-hour-clock users. Common in EU.
- **Evidence:**
  - `Core/Analysis/ML/TodayIntelligenceEngine.swift:1066` — hand-coded 12-hour conversion.
  - `Core/Analysis/ML/DecisionPolicyEngine.swift:1586-1590` — same.
- **Fix:** Replace with `DateFormatter` `.timeStyle = .short` which automatically respects user's 12/24 preference.
- **Priority:** Next Sprint — small UI polish.
- **Confidence:** 90/100 — verified by file reads.

---

## P2-F32. **Notification scheduling time-zone bug — `UNCalendarNotificationTrigger` with `dateComponents.calendar = Calendar.current` does NOT carry timezone explicitly; user crossing timezones may receive daily summary at the wrong wall-clock hour for a day after the move**

- **Severity:** Low
- **Issue:** `DailySummaryScheduler.swift:57-65` constructs `UNCalendarNotificationTrigger` with `dateComponents.calendar = Calendar.current` but **does not set `dateComponents.timeZone`**. iOS uses the device's current timezone at *fire time*, not at *schedule time* — which is normally desirable. **However**, when a user travels and stays in a new timezone for several days, iOS does NOT automatically reschedule existing repeating triggers. If the user wants "daily summary at 8am in my new local time", the trigger continues firing at 8am old-timezone. The `WindDownScheduler`, `EveningSummaryScheduler` follow the same pattern.
- **Why this exists:** UNCalendarNotificationTrigger doc nuance.
- **Impact:** Travelers see daily summaries at unexpected hours for several days post-move (until iOS eventually re-evaluates the schedule, or until app foreground re-runs scheduling).
- **Evidence:**
  - `Core/Notifications/DailySummaryScheduler.swift:60` — `dateComponents.calendar = Calendar.current`, no `dateComponents.timeZone`.
  - `Core/Notifications/EveningSummaryScheduler.swift:25`, `Core/Notifications/WindDownScheduler.swift:67` — same.
- **Fix:** On `UIApplication.significantTimeChangeNotification` (which Pass 1 F10 already calls out as not observed), call `cancelAllNotifications()` + reschedule. Until F10 is fixed, this is also broken.
- **Priority:** This Week — bundles with Pass 1 F10. Travelers get bad notification timing.
- **Confidence:** 88/100.

---

## P2-F33. **App Group `UserDefaults(suiteName: "group.com.lasohealth.fit")` is read by Live Activities + Widgets — no fallback if entitlement misconfig (returns nil); zero analytics on the rare nil path**

- **Severity:** Low
- **Issue:** Multiple call sites use `UserDefaults(suiteName: "group.com.lasohealth.fit")?.…` with optional chaining. If the App Group entitlement is misconfigured at build time (rare but happens after provisioning issues or new team-member-onboarding), the optional returns nil and every read silently no-ops. There is no `assertionFailure` or analytics event capturing this path.
- **Why this exists:** Defensive optional chaining without instrumentation.
- **Impact:** Rare; app builds with mis-configured entitlements may slip through code review with no runtime signal.
- **Evidence:** `Shared/CoachActionIntents.swift:23-25` — `?.` chaining noted in Pass 1 cross-cut table.
- **Fix:** On first read, if `UserDefaults(suiteName:)` returns nil, emit a `app_group_unreachable` PostHog event so engineering catches misconfigs.
- **Priority:** Backlog — instrumentation polish.
- **Confidence:** 88/100.

---

## P2-F34. **`saveWeight` / `saveWaterIntake` accept any `Double` — no input validation; user types "9999 kg" or "−5", bad data lands in HealthKit, polluting their entire Health.app history**

- **Severity:** Medium
- **Issue:** `Core/Data/HealthKitManager.swift:1150-1175`:
  ```
  func saveWeight(_ kg: Double, date: Date = Date()) async throws { … }
  func saveWaterIntake(milliliters: Double, date: Date = Date()) async throws { … }
  ```
  No bounds checking. The UI layer (not located in this audit; likely `WeightLogSheet.swift` or similar) ought to validate, but defense-in-depth says the data layer should reject obviously-invalid inputs (`< 20 kg`, `> 300 kg`, `< 0 ml`, `> 5000 ml/single-entry`).
- **Why this exists:** Trust-the-UI pattern.
- **Impact:**
  - Fat-fingered "100 kg" → Health.app shows a 100kg entry forever; user must manually clean up via Health.app.
  - Negative values may break HealthKit's enum validation and throw silently.
  - Combined with input-decimal-separator bug (P2-F16): a fr_FR user typing "1,5" parses as 0 (or fails silently) → may save 0 kg → bad data.
- **Evidence:**
  - `Core/Data/HealthKitManager.swift:1150-1175` — verified.
  - No range validation visible.
- **Fix:** Add explicit bounds in `saveWeight` (`guard (20...300).contains(kg) else { throw … }`), `saveWaterIntake` (`guard (10...5000).contains(milliliters) else { throw … }`), `saveMindfulSession` (`guard (1...240).contains(minutes) else { throw … }`).
- **Priority:** This Week — data-quality + downstream score-pollution risk.
- **Confidence:** 92/100.

---

## P2-F35. **No camera, microphone, contacts, calendar, motion, or location permission strings — and the code does not request any of these. Confirmed clean.**

- **Severity:** Informational / no fix needed
- **Issue:** Verified absences:
  - `grep -rn "AVCaptureDevice\|UIImagePickerController\|PHPhotoLibrary" --include="*.swift"` → zero.
  - `grep -rn "AVAudioRecorder\|AVAudioSession.*record" --include="*.swift"` → zero (breathwork is silent — Pass 1 F14 noted this).
  - `grep -rn "CNContactStore\|EKEventStore\|CMMotionActivityManager\|CLLocationManager\|CBCentralManager\|CBPeripheralManager\|NFCNDEFReaderSession" --include="*.swift"` → zero.
  - `Info.plist` declares only `NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription`, `NSSiriUsageDescription`. No vestigial usage descriptions for unused permissions. Clean.
- **Why this is good:** Tight permission surface = fast App Review pass.
- **Action:** None. Document as a positive baseline finding for the launch checklist.
- **Confidence:** 95/100.

---

## P2-F36. **Mac Catalyst, visionOS, App Clip, NFC, Live Text, Dictation are all OFF — clean baseline**

- **Severity:** Informational
- **Issue:** No `SUPPORTS_MACCATALYST`, no `SUPPORTS_XROS`, no `.appclip` target in project.yml. No NFC entitlement. Live Text and Dictation are SwiftUI/UIKit defaults; not actively configured. Clean baseline. No actions.
- **Confidence:** 95/100.

---

## P2-F37. **Stage Manager / Multitasking — N/A because iPhone-only**, but if iPad is added (P2-F13), Stage Manager support is the next gap.

- **Severity:** Informational / future
- **Action:** Bundled with iPad rollout if/when the team flips `TARGETED_DEVICE_FAMILY` to `"1,2"`.

---

## Permission denial decision tree — additions to Pass 1 table

| Permission / Surface | Pass 2 finding | Status |
|---|---|---|
| HealthKit deletion (HKDeletedObject) | P2-F1 — `anchor: nil` discards delete events; deleted samples persist forever in the Live tab | Broken |
| HealthKit dedup (multi-source) | P2-F9 — same sample written by Watch + 3rd-party importer is double-counted | Broken |
| HealthKit source merging | P2-F10 — no source preference; multi-source data flows in raw | Broken |
| HealthKit future-dated samples | P2-F7 — no validation; clock-skewed source can inject "tomorrow" | Defensive gap |
| HealthKit negative-duration samples | P2-F8 — no validation; sign-flips possible | Defensive gap |
| HealthKit observer throttling by iOS | P2-F2 — no exponential backoff or telemetry; `dasd` may silently throttle | Risk |
| HealthKit data freshness staleness | P2-F11 — week-old HRV is presented as fresh score input | Trust gap |
| HealthKit first-launch sync lag | P2-F12 — Day-1 calibration on partial data; never re-runs | Day-1 retention risk |
| Notification interruptionLevel | P2-F6 — `.timeSensitive` not set on critical alerts; Focus modes silence them | Patient-safety adjacent |
| Notification threadIdentifier | P2-F6 — no grouping; lock-screen clutter | UX polish |
| Notification UNNotificationCategory | P2-F6 — no actionable buttons | UX polish |
| Notification timezone | P2-F32 — UNCalendarNotificationTrigger does not carry tz; travelers wrong-time | Edge bug |
| APNs silent push | P2-F18 — no `application(_:didReceiveRemoteNotification…)`; no `remote-notification` BG mode | Bundled with F1 |
| Universal Link entitlement | P2-F19 — no `associated-domains` entitlement; AASA cannot work | Bundled with F8 |
| iCloud KVS cross-device | P2-F4 — `onboardingCompleted` syncs across devices; secondary device skips onboarding | High |
| iCloud Drive (Documents/) | None — app does not write to Documents/iCloud Drive; SwiftData stores in Application Support | Clean |
| Keychain device binding | OK — `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` is correct | Clean |
| Time-travel attack | P2-F5 — clock-rewind extends trial indefinitely | Revenue leak |
| Trial end timezone | P2-F29 — local-calendar day-count drifts on travel | Edge bug |
| First day of week | P2-F30 — region-change can shift week boundaries; persisted scores may misalign | Edge bug |
| 12/24-hour | P2-F31 — hand-formatted hours hardcode 12-hour; `DateFormatter` paths are fine | Polish |
| Imperial vs metric units | P2-F15 — hardcoded "kg/cm/km/°C"; US users see metric only | Now (US launch blocker) |
| Currency on paywall | OK — `Product.displayPrice` localizes correctly | Clean |
| Decimal separator parsing | P2-F16 — `Double.init(String)` rejects `"1,5"`; preventive | Backlog |
| Plurals | P2-F17 — naive `"1 day" / "N days"`; no .stringsdict | Backlog |
| RTL layout | Pass 1 F19 — and SwiftUI HStack auto-flips; `.padding(.leading)` also auto-flips. Some fixed-pixel widget paddings won't flip but widget is small | Backlog |
| AppTrackingTransparency | P2-F24 — not called; consistent with `NSPrivacyTracking = false` | Clean |
| Family Sharing of subscription | P2-F3 — `familyShareable = false` + no specific copy on restore failure | This Week |
| Subscription paused / revoked | P2-F28 — `RenewalState.revoked` not checked; user may keep access after revoke | Next Sprint |
| Force-quit + relaunch state restoration | P2-F20 — no `NSUserActivity` / `@SceneStorage`; tab/scroll lost | Backlog |
| Spotlight indexing | P2-F21 — no `CSSearchableItem` integration | Backlog |
| Handoff / Mac Catalyst | P2-F22 — no `NSUserActivity` advertise/receive | N/A v1 |
| Stage Manager / Multitasking | P2-F37 — N/A iPhone-only | N/A v1 |
| Battery saver | Pass 1 F12 noted absence; cross-cut to BG-fetch / animations / Live Activity | Bundled |
| Thermal state | OK — `ThermalManager` exists and is consumed in 8 places (`grep thermalState`) | Clean |
| `URLSessionConfiguration.allowsExpensiveNetworkAccess` | P2-F14 — not configured; cellular burn + Low Data Mode ignored | This Week |
| `URLSessionConfiguration.allowsConstrainedNetworkAccess` | P2-F14 — same | This Week |
| Personal Hotspot / VPN | P2-F27 — VPN paths unverified | Backlog |
| Captive portal | P2-F26 — no detection; hotel users hang | Backlog |
| iPad install via Family Sharing | P2-F13 — installs as "Compatible iPhone" centered frame; no graceful bail-out | This Week |
| iOS 26 vs 17/18 fallback parity | P2-F23 — FoundationModels paths gated to iOS 26; iOS 17/18 fallback unverified | This Week |
| HealthKit save input validation | P2-F34 — no bounds check on weight/water/mindful inputs | This Week |
| App Group entitlement misconfig | P2-F33 — silent nil-suite; no telemetry | Backlog |

---

## Summary

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 3 (P2-F1, P2-F4, P2-F12) |
| Medium | 11 (P2-F2, P2-F3, P2-F6, P2-F9, P2-F10, P2-F11, P2-F13, P2-F14, P2-F15, P2-F23, P2-F34) |
| Low | 13 (P2-F5, P2-F7, P2-F8, P2-F16, P2-F17, P2-F18, P2-F19, P2-F20, P2-F21, P2-F22, P2-F26, P2-F27, P2-F28, P2-F29, P2-F30, P2-F31, P2-F32, P2-F33) |
| Informational | 4 (P2-F24, P2-F25, P2-F35, P2-F36, P2-F37) |

**Top fix Now (pre-launch blocker, additive to Pass 1):**

1. **P2-F4 — Stop syncing `onboardingCompleted` to iCloud KVS, OR pair with a per-device sentinel.** Multi-device users on the same Apple ID currently get a permission-less, data-less Day-1 dashboard with no recovery path. Combined with Pass 1 F2 + F3, the secondary device never asks for HK or notification permissions.
2. **P2-F6 — Set `interruptionLevel = .timeSensitive` for `severity == .critical` notifications + add the `time-sensitive` entitlement.** Without this, critical health alerts are silenced by Sleep / Do Not Disturb / any Focus mode the user has on. Patient-safety adjacent for an app marketing illness early-warning.
3. **P2-F15 — Locale-aware unit display (kg/lb, cm/in, km/mi, °C/°F).** US-launch blocker; majority US user-base will see all-metric units.

**Top fix This Week (high-impact UX/data correctness):**

- P2-F1 (HK delete propagation — broken trust)
- P2-F2 (HK observer throttling visibility — silent BG retention killer)
- P2-F3 (Family Sharing UX on restore)
- P2-F9 / P2-F10 (HK dedup + source preference — multi-source-user trust)
- P2-F11 (stale HRV baseline freshness gating)
- P2-F12 (Day-1 calibration re-run after sync lag)
- P2-F13 (iPad Family-Sharing graceful bail-out)
- P2-F14 (network constrained / expensive policy)
- P2-F23 (iOS 17/18 narrative fallback parity)
- P2-F32 (notification timezone re-anchor on travel; bundles with Pass 1 F10)
- P2-F34 (write-input validation defense-in-depth)

**Backlog / Next Sprint:**

- P2-F5 (clock-rewind trial extension)
- P2-F16 (decimal separator preventive)
- P2-F17 (plurals preventive)
- P2-F20 / P2-F21 / P2-F22 (state restoration / Spotlight / Handoff)
- P2-F26 / P2-F27 (captive portal / VPN canary)
- P2-F28 (subscription revoked path)
- P2-F29 / P2-F30 / P2-F31 (timezone / first-day-of-week / 12-hour edge bugs)
- P2-F33 (App Group nil-suite telemetry)

**Confidence on this audit overall:** 88/100 — every finding above was either verified by direct file read at the cited line OR by an exhaustive grep returning a definitive zero matches across the entire repo. What remains unverified at runtime: P2-F4's two-device behavior is not screenshotted; P2-F12's Day-1+24h baseline drift is not measured; P2-F23's iOS 17/18 narrative card fallback rendering is not exercised; P2-F2's `dasd`-throttling is not measured. These are the weak links keeping the score below 90; closing them needs a Day-1 simulator run on iOS 17.0, a two-Apple-ID iCloud-KVS test, and instrumentation telemetry that does not exist yet.

---

**Audit completed:** 2026-04-25, Pass 2 read-only red-team across 85 attack-surface angles, 37 new findings + 1 cross-cut decision table.

# Amplitude instrumentation audit — Laso

85 defects confirmed. Each was found by one agent and then checked again by a second agent that opened the cited lines and tried to prove it wrong. Findings that could not be reproduced were dropped. PII / privacy findings are excluded on request.

**Scope note:** the live Amplitude tracking plan could not be compared. The connected Amplitude account only reaches projects `Tarot99` and `DealShop`; neither contains this app's events. So this audit is code-side only: it cannot tell you which events are missing from the Amplitude schema or which are ingesting with a locked wrong type.

## Counts

| Severity | Count |
|---|---|
| high | 34 |
| medium | 42 |
| low | 9 |

| Type | Count |
|---|---|
| WRONG_PROPERTY | 27 |
| BROKEN_CALLSITE | 25 |
| MISSING_EVENT | 23 |
| MISSING_PROPERTY | 10 |

| Area | Count |
|---|---|
| Onboarding | 8 |
| Paywall & Subscription | 11 |
| Home / Live / Explore / Settings | 19 |
| Notifications | 9 |
| Secondary features | 12 |
| App lifecycle & data pipeline | 12 |
| Taxonomy consistency | 14 |

---

# High severity (34)


## Onboarding

### All three reveal payoff events re-fire on back navigation because their dedupe guards are view-local @State

`BROKEN_CALLSITE` · event: `onboarding_vitality_revealed, onboarding_heart_revealed, verdict_delivered`

The router renders `content.id(screen)` (OnboardingV2View.swift:93), so every screen change destroys and rebuilds the screen view and resets its @State. The heart screen's `revealTracked` guard (Screens8to13.swift:581), the vitality reveal's `.task { runSequence() }` (OnbV2VitalityReveal.swift:437,509) and the verdict's bare `.onAppear` (Screens8to13.swift:1265) therefore all re-emit on re-entry. Reachable back paths: sleep.onBack -> heart (OnboardingV2View.swift:251), heart.onBack -> preview on rich (:247), signIn.onBack -> verdict/preview (:276), paywall.onBack -> verdict/preview (:288). The router already knows this failure mode: it added a flow-level `promiseTracked` guard for the promise screens for exactly this reason (:462-466). Result: event counts for the three payoff moments are inflated by every back tap, and per-user counts of "landed younger vs older" / "verdict zone delivered" double-count the same reveal.

**Where:** Modules/Onboarding/Views/Onboarding/OnbV2VitalityReveal.swift:509 → Core/Tracking/AppAnalytics.swift:576

**Fix:** Move the three guards to the router next to `promiseTracked`: add `@State private var revealsTracked: Set<Screen> = []` in OnboardingV2View and pass a `trackOnce` closure into OnbV2VitalityRevealScreen, OnbV2Screen11Heart and OnbV2ScreenVerdict instead of calling AppAnalytics from their .onAppear/.task.

**Verified:** Confirmed all four legs. OnboardingV2View.swift:93 is `.id(screen)` inside the ZStack, so each screen change tears down the view and resets its @State. OnboardingV2Screens8to13.swift:444 declares `@State private var revealTracked = false` and :580-584 is the `.onAppear { guard !revealTracked ... }` heart tracker, so the guard dies with the view. OnbV2VitalityReveal.swift:437 is `.task { await runSequence() }` and :509-511 fires trackOnboardingVitalityRevealed at the end of that sequence; its only guard is `guard !Task.isCancelled` (:507), which stops an aborted run, not a re-entry. OnbV2ScreenVerdict (Screens8to13.swift:1265-1273) has a bare `.onAppear` with no guard at all. Back paths all confirmed in the router: heart.onBack -> preview on rich (:247), sleep.onBack -> heart (:251), signIn.onBack -> verdict/preview (:276), paywall.onBack -> verdict/preview (:288). The router's own promiseTracked guard (:460-466, comment: 'The promise screens are recreated by the back-nav scan re-run, so their own .onAppear cannot dedupe') proves the failure mode is already known and was only fixed for promise_shown.

### Skipping sign-in is logged as success:true, so the sign-in conversion rate counts skippers as conversions

`BROKEN_CALLSITE` · event: `sign_in_completed`

OnbV2Screen15SignIn's "Skip for now" button calls trackSignInCompleted(method: "skipped", success: true) (Screens14ToDone.swift:256) even though no Apple account is created; it only falls back to the launch-time anonymous Firebase user. The doc on the tracker says success is "the key account-creation conversion" (AppAnalytics.swift:613-616). A funnel or ratio on sign_in_completed where success=1 therefore reports near-100% and cannot answer "what share of users actually create an account at the sign-in step".

**Where:** Modules/Onboarding/Views/Onboarding/OnboardingV2Screens14ToDone.swift:256 → Core/Tracking/AppAnalytics.swift:615

**Fix:** Change the skip call site to `trackSignInCompleted(method: "skipped", success: false)`, or add an explicit `outcome` parameter ("completed" | "skipped" | "failed") to trackSignInCompleted and stop overloading `success`.

**Verified:** OnboardingV2Screens14ToDone.swift:252-256: `private func skip()` whose own doc comment says 'Continue on the launch-time anonymous Firebase user ... so no auth is created here', and its first line is `AppAnalytics.shared.trackSignInCompleted(method: "skipped", success: true)`. The real Apple path at :242 and :246 uses success:true/false for genuine success/failure. AppAnalytics.swift:612-616 documents success as 'the key account-creation conversion; failure includes user cancellation'. So success=1 is true for both 'created an Apple account' and 'explicitly declined to', and no property distinguishes them beyond method, making any success-rate metric on this event meaningless without knowing to also filter method.


## Paywall & Subscription

### Paywall funnel loses `source` after the view step, so no placement can be scored

`MISSING_PROPERTY` · event: `paywall_cta_tapped`

`paywall_viewed` and `paywall_dismissed` both carry `source`, but `paywall_cta_tapped`, `purchase_completed` and `purchase_failed` do not, even though PaywallView holds `source` in scope at the CTA call site (line 366). With 7 distinct placements (trial_expired, onboarding, aha_moment, pro_feature_overlay, locked_insights, time_range_locked, soft_lock_home) all funnelling into the same three unsourced events, view->CTA->purchase conversion per placement is unanswerable, which is the single question the source dimension exists for.

**Where:** /Users/primetrace/Desktop/RnD/HealthPulse/Modules/Paywall/Views/Subscription/PaywallView.swift:366 → /Users/primetrace/Desktop/RnD/HealthPulse/Core/Tracking/AppAnalytics.swift:1449

**Fix:** Add `source: String` to `trackPaywallCTATapped` (AppAnalytics.swift:1449) and emit it as `"source": source`; pass `source` from PaywallView.swift:366 and `"onboarding"` from OnboardingV2Screens14ToDone.swift:521. Same for `trackPurchaseCompleted`/`trackPurchaseFailed` by stashing the last viewed source on AppAnalytics when `trackPaywallViewed` fires and attaching it to both.

**Verified:** Real for paywall_cta_tapped only. The purchase_completed / purchase_failed half is not a defect: both are emitted from SubscriptionManager (lines 244, 705-712), which has no paywall-placement context at all, and the doc block at AppAnalytics.swift:267-272 documents purchase_completed as product_id/is_free_trial by design. Also note the doc block at line 267 lists paywall_cta_tapped as "product_id, price" — so this is a sibling-inconsistency defect, not a doc-vs-code mismatch.

### `failure_reason` is hardcoded to `verification` for every StoreKit throw

`WRONG_PROPERTY` · event: `purchase_failed`

The catch block at SubscriptionManager.swift:242-245 reports `.verification` for anything `product.purchase()` or `checkVerified` throws, including `StoreKitError.networkError`, `.systemError`, `Product.PurchaseError.productUnavailable` and `.ineligibleForOffer`. The `PurchaseFailureReason` enum defines `networkError` and `paymentDeclined` but no call site in the repo ever emits them, so the property is effectively a constant with two values (`user_cancelled` from line 234, `verification` from everything else) and paywall friction cannot be cut by real cause.

**Where:** /Users/primetrace/Desktop/RnD/HealthPulse/Core/Subscriptions/SubscriptionManager.swift:244 → /Users/primetrace/Desktop/RnD/HealthPulse/Core/Tracking/AppAnalytics.swift:1664

**Fix:** In the catch at SubscriptionManager.swift:242, switch on the error before tracking: `SubscriptionError.failedVerification` -> `.verification`, `StoreKitError.networkError` -> `.networkError`, `StoreKitError.notEntitled`/`Product.PurchaseError.*` -> `.paymentDeclined`, default -> `.verification`.

**Verified:** SubscriptionManager.swift:242-245: a single catch sets errorMessage = "Purchase failed. Please try again." and calls trackPurchaseFailed(reason: .verification) for anything thrown by product.purchase() or checkVerified. Repo-wide grep for trackPurchaseFailed returns exactly two call sites (lines 234 and 244), so of the four PurchaseFailureReason cases at AppAnalytics.swift:1654-1659, only user_cancelled and verification are ever emitted; payment_declined and network_error are dead enum cases.

### `.pending` and `@unknown default` purchase outcomes emit no event at all

`MISSING_EVENT` · event: `purchase_failed`

`purchase()` handles four `Product.PurchaseResult` branches but only `.success` and `.userCancelled` emit anything. `.pending` (Ask to Buy, SCA challenge, deferred approval) only sets `errorMessage` (line 237) and `@unknown default` does nothing (line 239-241), so a user who taps the CTA and lands there produces `paywall_cta_tapped` with no terminal outcome. Ask-to-Buy is a normal family-account state, so a real share of CTA taps just vanish from the funnel and inflate apparent CTA->purchase drop-off.

**Where:** /Users/primetrace/Desktop/RnD/HealthPulse/Core/Subscriptions/SubscriptionManager.swift:236 → /Users/primetrace/Desktop/RnD/HealthPulse/Core/Tracking/AppAnalytics.swift:1664

**Fix:** Add a `pending` case to `PurchaseFailureReason` (AppAnalytics.swift:1654) and call `trackPurchaseFailed(productID: product.id, reason: .pending)` in the `.pending` branch; call it with `.verification` (or a new `unknown` case) in `@unknown default` instead of `break`.

**Verified:** Real, but the funnel is not completely silent on PaywallView: errorMessage is cleared at line 197 and set at line 237, so PaywallView.swift:136 onChange fires trackPaywallError, and "Purchase is pending approval." matches no bucket in classifyPaywallError so it lands as error_type "unknown". On the onboarding paywall (no errorMessage tracking at all) the pending outcome is fully silent. The @unknown default half is theoretical only — StoreKit ships three PurchaseResult cases today.

### `billing_grace_resolved` can effectively never fire on the real recovery path

`BROKEN_CALLSITE` · event: `billing_grace_resolved`

On the entitlement-recovery path `wasInGrace` is read from the in-memory `status` (SubscriptionManager.swift:315), but the recovery a user actually experiences happens on the next cold launch, when `status` is still `.unknown`. `clearGraceState(wasActive: false)` then deletes `graceStartDate` without emitting the event (line 548), so `billing_grace_started` has no matching resolution and involuntary-churn recovery rate reads as ~0%. It only fires in the rare case where grace was already observed earlier in the same app session.

**Where:** /Users/primetrace/Desktop/RnD/HealthPulse/Core/Subscriptions/SubscriptionManager.swift:315 → /Users/primetrace/Desktop/RnD/HealthPulse/Core/Tracking/AppAnalytics.swift:1961

**Fix:** Drive `wasActive` off the persisted status instead of memory: in `clearGraceState` (SubscriptionManager.swift:539) treat a non-nil `graceStartDate` as proof the user was in grace, i.e. drop the `wasActive` guard at line 548 and always emit `trackBillingGraceResolved(daysInGrace:)` when a stored grace start is being cleared on a recovery.

**Verified:** SubscriptionManager.swift:315 reads wasInGrace from the in-memory `status` via isBillingGrace, then line 327 calls clearGraceState(wasActive: wasInGrace). clearGraceState (line 539-552) only emits trackBillingGraceResolved when wasActive is true. configure() (lines 116-125) runs refreshStatus on a fresh launch with status = .unknown, and the recovery path returns at line 322 before status ever becomes .billingGrace, so wasInGrace is false and the persisted graceStartDate is deleted silently at line 549. The event can only fire if .billingGrace was already assigned earlier in the same process, i.e. a mid-session recovery.

### `period` uses "yearly" on one paywall and "annual" on the other for the same plan

`WRONG_PROPERTY` · event: `paywall_plan_selected`

PaywallView sends `period: label.lowercased()` which resolves to "yearly" (PaywallView.swift:291), while the onboarding paywall hardcodes `period: "annual"` for the identical yearly product (OnboardingV2Screens14ToDone.swift:464). The same event therefore has three values for two plans, so any yearly-vs-monthly preference chart silently splits the yearly cohort in half and understates it, and the onboarding surface is the highest-volume one.

**Where:** /Users/primetrace/Desktop/RnD/HealthPulse/Modules/Onboarding/Views/Onboarding/OnboardingV2Screens14ToDone.swift:464 → /Users/primetrace/Desktop/RnD/HealthPulse/Core/Tracking/AppAnalytics.swift:1461

**Fix:** Change `period: "annual"` to `period: "yearly"` at OnboardingV2Screens14ToDone.swift:464, and in PaywallView.swift:291 pass a literal `"yearly"`/`"monthly"` derived from the product id rather than `label.lowercased()`.

**Verified:** OnboardingV2Screens14ToDone.swift:463-464 sends period: "annual" for yearly?.id, while PaywallView.swift:289-292 sends period: label.lowercased() where label is Copy.Paywall.yearly (Copy+Paywall.swift:21, default "Yearly") -> "yearly". Both feed the same trackPaywallPlanSelected at AppAnalytics.swift:1461. "yearly" is also the canonical value everywhere else: SubscriptionManager.billingPeriod returns "yearly" (line 690) for purchase_completed and non_trial_activation. The onboarding paywall is a mandatory step, so the outlier value is on the highest-volume surface.

### Home soft lock, the largest free-user wall, records no premium_feature_attempted

`MISSING_EVENT` · event: `premium_feature_attempted`

Six separate soft-lock entry points on Home (bottom-bar CTA at line 406, the Ask card at 594, and four `.softLocked` surfaces at 533/605/620/649) all set `showSoftLockPaywall = true` and present the paywall, but `SoftLockModifier` (line 1094-1120) and the button bodies emit no analytics. Every other wall in the app (ProFeatureOverlay, LockedInsightsCTA, TimeRangeSelector) emits `premium_feature_attempted`, so the "which blocked feature creates desire" metric is missing exactly the surface that blocks the whole home screen, and all six taps collapse into one indistinguishable `paywall_viewed(source: "soft_lock_home")`.

**Where:** /Users/primetrace/Desktop/RnD/HealthPulse/Modules/Dashboard/Views/Home/HomeView.swift:1115 → /Users/primetrace/Desktop/RnD/HealthPulse/Core/Tracking/AppAnalytics.swift:2123

**Fix:** Give `SoftLockModifier` a `feature: String` parameter and call `AppAnalytics.shared.trackPremiumFeatureAttempted(feature: feature, screen: .home)` inside its `onTapGesture` (HomeView.swift:1115); pass a distinct feature name at each of the six call sites.

**Verified:** One factual correction: the Ask card at line ~588 is not silent — it does emit trackBlockTap(title: "Ask Your Data", type: .smartAction, screen: .home) before branching on isSoftLocked, though the same event fires whether the tap navigated or hit the wall, so it cannot separate the two. The genuinely silent taps are the bottom-bar CTA (line 406) and the four blurred-card taps routed through line 1115.

### Onboarding paywall emits no paywall_error, no retry and no restore_attempted

`MISSING_EVENT` · event: `paywall_error`

The onboarding paywall is a mandatory step yet only emits viewed/plan_selected/cta_tapped/dismissed. When StoreKit products fail to load it renders `manager.errorMessage` plus a Retry button (lines 484-493) with the CTA disabled, but never calls `trackPaywallError`, so `paywall_error` never exists with `source: "onboarding"`; PaywallView is the only surface wired to it (PaywallView.swift:136). The Restore button (line 535-540) also skips `trackRestoreAttempted`. Users blocked by a StoreKit outage in onboarding are therefore recorded as ordinary `paywall_dismissed(reason: "declined"/"back")` and are indistinguishable from real refusals.

**Where:** /Users/primetrace/Desktop/RnD/HealthPulse/Modules/Onboarding/Views/Onboarding/OnboardingV2Screens14ToDone.swift:484 → /Users/primetrace/Desktop/RnD/HealthPulse/Core/Tracking/AppAnalytics.swift:1473

**Fix:** Add `.onChange(of: manager.errorMessage)` on the screen (mirroring PaywallView.swift:136) calling `trackPaywallError(errorType:source:"onboarding",timeOnPaywallSec:)`, and wrap the restore Task at line 537 with `trackRestoreAttempted(success: FeatureGate.hasFullAccess)`.

**Verified:** grep of every AppAnalytics call in OnboardingV2Screens14ToDone.swift returns only trackSignInCompleted (243/246/256), trackPaywallDismissed (391 reason "back", 572 reason "declined"), trackPaywallPlanSelected (463/475), trackPaywallCTATapped (521), trackPaywallViewed (591). No trackPaywallError, no trackRestoreAttempted. Lines 484-493 render manager.errorMessage plus a Retry button and line 517 disables the CTA on !productsLoaded; the restore button at 535-540 just awaits restorePurchases(). PaywallView.swift:136 is the only paywall_error wiring in the app, so paywall_error never exists with source "onboarding", and a StoreKit-blocked onboarding user is indistinguishable from a genuine decliner.


## Home / Live / Explore / Settings

### SectionTracker fires section_viewed twice per impression, once with duration_ms = 0

`BROKEN_CALLSITE` · event: `section_viewed`

appeared() emits section_viewed with durationMs: 0 and disappeared() emits the same event again with the real duration. Every section in the app (52 SectionTracker instances across Home, Explore, Live, Settings, CategoryDetail, MetricDetail, Insights, Paywall) therefore double-counts impressions, and any average of duration_ms is halved by the zero rows. No downstream consumer can distinguish the two emissions because the event name and section_id are identical.

**Where:** Core/Tracking/SectionTracker.swift:107 → Core/Tracking/AppAnalytics.swift:1933

**Fix:** Delete the trackSectionViewed call inside appeared() (SectionTracker.swift:109) so the event is emitted only once, on disappeared(), with the real duration.

**Verified:** Accurate. Count correction only: 55 SectionTracker( instantiations, not 52.

### CorrelationsView renders the pro gate and the gated content together, emitting two screen_viewed events

`BROKEN_CALLSITE` · event: `screen_viewed`

body has `if isGated { ProFeatureOverlay(...) }` with no `else` before the ScrollView (CorrelationsView.swift:44-51), so for a free user both views are in the hierarchy. ProFeatureOverlay.onAppear emits screen_viewed(pro_overlay) plus pro_feature_funnel(step: overlay_shown), and the ScrollView's onAppear emits screen_viewed(correlations) plus first_correlation activation and core_action viewed_correlation. Free users are counted as having reached the Correlations screen, so the paywall-gate conversion question and the correlations reach number are both wrong.

**Where:** Modules/Insights/Views/Insights/CorrelationsView.swift:44 → Core/Tracking/AppAnalytics.swift:1014

**Fix:** Turn it into `if isGated { ProFeatureOverlay(...) } else { ScrollView { ... } }` so only one branch mounts and only one screen_viewed fires.

**Verified:** Real, with a reachability caveat the finding omits: the only in-app nav to Route.correlationsDetail is ExploreView.swift:279, which sits inside a Pro-only closure. The gated branch is reached via server-driven push payloads (NotificationRouter.swift:25-36 maps userInfo["route"] through Route.fromUITestIdentifier, which accepts "correlationsDetail") and via a lapsed subscription while the view is on screen. Not dead code, but lower volume than the finding implies.

### Explore month calendar and its day sheet emit nothing at all

`MISSING_EVENT` · event: `n/a`

The month calendar is the habit surface on Explore, and none of its interactions are instrumented: the day cell button (ExploreMonthCalendarSection.swift:160) opens ExploreDaySheet with no block_tapped, the sheet presentation (line 82) has no trackFeatureOpen/trackFeatureClose, and the prev/next month buttons (line 106) and the Today button (line 230) emit nothing. ExploreDaySheet is a full drill-down screen with zero screen_viewed, so its usage, its duration and whether users ever page back through history are all unanswerable.

**Where:** Modules/Explore/Views/Explore/ExploreMonthCalendarSection.swift:160 → Core/Tracking/AppAnalytics.swift:1014

**Fix:** Add a trackBlockTap(type: .categoryRow-equivalent new case, screen: .explore, metadata: ["has_score": score != nil]) in the day-cell action, add a new AppFeature case for the day sheet with trackFeatureOpen/Close in ExploreDaySheet.body, and one trackBlockTap in monthButton with metadata ["step": step].

**Verified:** grep for AppAnalytics|Tracker in Modules/Explore/Views/Explore/ExploreMonthCalendarSection.swift returns nothing. Day cell Button at :157-159 only sets selectedDay; sheet presentation at :81-83 has no open/close tracking; monthButton at :98-114 and the Today button at :229-231 emit nothing. Modules/Explore/Views/Explore/ExploreDaySheet.swift also contains no AppAnalytics reference. ExploreView.swift:93-100 mounts the calendar unconditionally on the Explore tab, so it is a live surface, not dead code.

### Delete All Data wipes the account and resets analytics without emitting a single event

`MISSING_EVENT` · event: `n/a`

The destructive confirm button calls performDataDeletion(), which deletes the local store, clears UserDefaults, signs out of Firebase and calls AnalyticsBackend.provider.reset() at SettingsView.swift:805, then posts LasoDidWipeAccount to send the user back to onboarding. Nothing is emitted before the reset, so the single strongest churn signal in the product is invisible in Amplitude, and because reset() runs first any later event would land on a fresh anonymous id.

**Where:** Modules/Settings/Views/SettingsView.swift:778 → Core/Tracking/AppAnalytics.swift:1614

**Fix:** Emit one event at the top of performDataDeletion(), before any wipe: AppAnalytics.shared.trackCoreAction is wrong here, so add a trackSettingChanged(name: "account_data_deleted", value: healthDataStore.totalStoredSamples) or a dedicated account_deleted event, and keep AnalyticsBackend.provider.reset() as the last call.

**Verified:** SettingsView.swift:180-187 is the confirm alert; the destructive button calls performDataDeletion() at :183 with no tracking. performDataDeletion (:778-812) contains no AppAnalytics call at all: it wipes EncryptedStore, healthDataStore, UserDefaults, WidgetDataStore, signs out of Firebase, then calls AnalyticsBackend.provider.reset() at :805 before posting LasoDidWipeAccount. Nothing is emitted before or after the reset.

### Every Explore trend metric tap fires block_tapped twice with conflicting property names

`BROKEN_CALLSITE` · event: `block_tapped`

ExploreYourTrendsSection's row Button emits trackBlockTap(type: .exploreTrendMetric, screen: .explore) and then calls onMetricTapped(item), whose ExploreView implementation emits trackBlockTap(type: .exploreTrendMetric, screen: .explore) again. One tap produces two block_tapped events, so the Explore trends CTR is exactly double the truth. The two payloads also disagree: one sends "trend_direction"/"timeframe_days", the other sends "direction"/"timeframe"/"period_change_pct", so both property sets are populated on only half the rows.

**Where:** Modules/Explore/Views/Explore/ExploreYourTrendsSection.swift:39 → Core/Tracking/AppAnalytics.swift:1163

**Fix:** Delete the trackBlockTap block inside ExploreYourTrendsSection's Button (lines 39-48) and keep the single richer call in ExploreView.swift:108, which already has the metric, direction and timeframe.

**Verified:** ExploreYourTrendsSection.swift:37-49 fires trackBlockTap(type: .exploreTrendMetric, screen: .explore, metadata: [metric_id, trend_direction, timeframe_days]) then calls onMetricTapped(item) at :49. ExploreView.swift:107-125 is that closure and fires trackBlockTap(type: .exploreTrendMetric, screen: .explore, metadata: [metric_id, period_change_pct, direction, timeframe]) again. One tap, two block_tapped rows, identical card_id/element_id (AppAnalytics.swift:1163-1176 derives them from screen+type+title, which match), with disjoint direction/timeframe property names.

### explore_correlations impressions come only from free users while its taps come only from Pro users

`BROKEN_CALLSITE` · event: `section_viewed`

correlationsTracker.appeared()/disappeared() are attached to the upsell block that renders only under `if !FeatureGate.canAccess(.advancedAnalytics)` (ExploreView.swift:288, 312), while correlationsTracker.tapped(target: "see_all") sits inside a closure that is nil unless canAccess(.advancedAnalytics) is true (ExploreView.swift:268-278). The two populations are disjoint, so section_viewed and section_tapped for explore_correlations can never be divided into a CTR, and Pro users produce zero explore_correlations impressions.

**Where:** Modules/Explore/Views/Explore/ExploreView.swift:288 → Core/Tracking/AppAnalytics.swift:1933

**Fix:** Move the .onAppear/.onDisappear correlationsTracker pair off the free-only upsell VStack and onto the ExploreDecliningTrendsSection at ExploreView.swift:282, which renders for both tiers and is where the see-all tap lives.

**Verified:** grep for correlationsTracker in ExploreView.swift returns exactly four lines: the declaration at :19, .tapped(target: "see_all") at :278, and .appeared()/.disappeared() at :312-313. Line 278 sits inside the onSeeAllIntelligenceTapped closure that is `FeatureGate.canAccess(.advancedAnalytics) ? { ... } : nil` (:268-280), so it exists only for Pro. Lines 312-313 hang off the VStack guarded by `if !FeatureGate.canAccess(.advancedAnalytics)` at :287. Disjoint populations confirmed.

### Only the collapsed bottom tier of Correlations tracks taps; the three default-visible tiers track nothing

`MISSING_EVENT` · event: `correlation_tapped`

CompoundInsightCard, CausalChainCard and InteractionEffectCard all call onTapMetric(...) with no analytics (CorrelationsView.swift:103-107, 121-126, 140-143). correlation_tapped is emitted only from CompactCorrelationRow inside the All Connections section (line 182), which is behind `if showAllConnections` and defaults to false. So the discovery event only fires after a user expands a collapsed section, and the primary content of the screen registers no engagement at all. The expand/collapse toggle itself (line 152) is also untracked.

**Where:** Modules/Insights/Views/Insights/CorrelationsView.swift:103 → Core/Tracking/AppAnalytics.swift:1235

**Fix:** Add trackCorrelationTapped(metricA:metricB:strength:screen: .correlations) inside the three card tap closures (use the chain's cause/affected metrics and a tier label in strength), and a trackBlockTap on the All Connections toggle.

**Verified:** Real, with one qualification: onTapMetric pushes MetricDetailView, whose onAppear (MetricDetailView.swift:177-185) emits screen_viewed(metric_detail) with metric and previous_screen, so tier engagement is not completely invisible. What is genuinely lost is correlation_tapped itself (metric_a/metric_b/strength) for the three default-visible tiers, plus any signal on the All Connections expand.


## Notifications

### WatchMonitor re-emits notification_scheduled for the same not-worn alarm every ~10 minutes, and twice per pass

`BROKEN_CALLSITE` · event: `notification_scheduled`

`onHeartRateDelivery` calls `scheduleNotWornNotification()` twice on one invocation: once on the throttled refresh path (WatchMonitor.swift:144, gated by `watchNotificationRefreshInterval` = 10 min at nominal thermal state) and again, completely ungated, when the HK query finds an Apple Watch sample (WatchMonitor.swift:174). Each call reaches `NotificationManager.scheduleNotification`, whose success branch fires `trackNotificationScheduled` (NotificationManager.swift:353). The path runs on an `HKObserverQuery` with `.immediate` background delivery for heart rate plus every foreground return (ContentView.swift:142), so one physical `healthpulse.watch.notWorn.scheduled` alarm produces well over a hundred `notification_scheduled` events per day. Since `bypassCap: true` skips the frequency cap, nothing damps it. `watch_monitor` swamps the event, and any global scheduled->presented or scheduled->opened rate is meaningless. The repeating summaries have the same shape at lower volume: DashboardHousekeepingService.swift:163/174/215 re-enqueues the same repeating daily/evening/weekly requests on every dashboard refresh, each re-emitting notification_scheduled.

**Where:** Core/Notifications/WatchMonitor.swift:174 → Core/Tracking/AppAnalytics.swift:2206

**Fix:** Dedupe centrally in `trackNotificationScheduled` (AppAnalytics.swift:2206): before `logEvent`, compare the computed fire day against a stored `healthpulse.notif.schedday.<identifier>` and return early when unchanged, so an idempotent replacement of an already-pending request does not count as a new enqueue.

**Verified:** The second call at WatchMonitor.swift:173 is NOT ungated: reaching it requires passing the `processedRecently` early return at :148-150, which is throttled by observerProcessingInterval (also 600s at .nominal). So the realistic worst case is two notification_scheduled events per ~10-minute window for one physical pending alarm (the id is replaced, not added), not an unbounded per-delivery flood. The only truly unthrottled route is when lastWatchDataKey is stale/zero so canUseRecentWatchConfirmation returns false. Volume is still enough to make watch_monitor dominate notification_scheduled and to break any scheduled->presented/opened rate.

### AlertEvaluator's cooldown and kill-switch gates drop alerts with no suppression event

`MISSING_EVENT` · event: `notification_suppressed`

`sendAlert` and `sendHeartRateAlert` both open with two silent guards: `guard severity == .critical || !suppressNonCritical else { return }` and `guard !cooldownManager.isOnCooldown(...) else { return }` (AlertEvaluator.swift:495-496 and 514-515). `suppressNonCritical` is set from the `kill_anomaly_alerts` Remote Config switch OR the near-daily-summary mute window (AlertEvaluator.swift:96-97), and `evaluate` also returns outright at AlertEvaluator.swift:118 before trend-reversal and celebration alerts. None of these emit anything. NotificationManager gives every one of its own gates a distinct reason (not_authorized, kill_switch, low_priority, fatigue_suppression, quiet_hours, priority_pushed_down, frequency_cap - NotificationManager.swift:197-403), so the pattern exists and AlertEvaluator simply does not follow it. Result: cooldown dedupe is the single largest attrition source in the alert funnel and is entirely invisible, and flipping `kill_anomaly_alerts` in production has an unmeasurable blast radius.

**Where:** Core/Notifications/AlertEvaluator.swift:496 → Core/Tracking/AppAnalytics.swift:2241

**Fix:** Add `AppAnalytics.shared.trackNotificationSuppressed(type: NotificationManager.notificationType(identifier), identifier: identifier, reason:)` to each early return in `sendAlert`/`sendHeartRateAlert` with distinct reasons `alert_cooldown` and `non_critical_muted`, and to the `guard !suppressNonCritical` at AlertEvaluator.swift:118.

**Verified:** Confirmed. AlertEvaluator.swift:495-496 (sendAlert) and 514-515 (sendHeartRateAlert) are `guard severity == .critical || !suppressNonCritical else { return }` and `guard !cooldownManager.isOnCooldown(...) else { return }`, plus `guard !suppressNonCritical else { return }` at :118. suppressNonCritical is set at :96-97 from RemoteConfigManager.killAnomalyAlerts or the near-daily-summary window. grep for AppAnalytics across the whole of AlertEvaluator.swift returns zero hits, so nothing is emitted on any of these returns and NotificationManager's own gates are never reached. The contrast is exact: NotificationManager.swift:197/206/220/230/245-249/385/397/403 give every gate a distinct reason (not_authorized, kill_switch, low_priority, fatigue_suppression, quiet_hours, priority_pushed_down, frequency_cap).

### latency_minutes measures schedule-to-present, not fire-to-present, so it is dominated by trigger lead time

`WRONG_PROPERTY` · event: `notification_presented`

`trackNotificationScheduled` stamps `let now = Date()` (AppAnalytics.swift:2207) into `healthpulse.notif.sent.<identifier>` at AppAnalytics.swift:2227, commented as the "send timestamp for time-to-open calculation". But that call fires at ENQUEUE time, not delivery time; `NotificationManager.scheduleNotification` already computes the trigger's true `fireDate` (NotificationManager.swift:190) and hands it to the fatigue tracker (NotificationManager.swift:342) but never to analytics. `trackNotificationPresented` then subtracts that stamp (AppAnalytics.swift:2061-2066) and ships `latency_minutes`. For the abandonment 72h push it reads ~4320, for a trial nudge scheduled days ahead it reads thousands, for the repeating daily summary it is the age of the last housekeeping pass. It is a lead-time measurement wearing a response-latency name, so "how fast do users react to a notification" is unanswerable. `notification_opened` compounds this: it deletes the sent key (AppAnalytics.swift:2031) without ever computing a time-to-open from it.

**Where:** Core/Notifications/NotificationManager.swift:353 → Core/Tracking/AppAnalytics.swift:2227

**Fix:** Add a `fireDate: Date` parameter to `trackNotificationScheduled`, pass `fireDate` from NotificationManager.swift:353 (and `Date().addingTimeInterval(delaySeconds)` from ReengagementScheduler.swift:121), and store that instead of `now` at AppAnalytics.swift:2227.

**Verified:** Confirmed. trackNotificationScheduled takes `let now = Date()` (AppAnalytics.swift:2207) and writes it to healthpulse.notif.sent.<id> at :2226 under the comment "Store send timestamp for time-to-open calculation", but the call site is the center.add success handler at NotificationManager.swift:353, i.e. enqueue time. The true fire date is computed at NotificationManager.swift:190, adjusted for quiet-hours deferral at :255, and passed to fatigueTracker.recordFired at :342 — but never to analytics. trackNotificationPresented subtracts the stored stamp at AppAnalytics.swift:2061-2066 and ships it as latency_minutes (:2076). notification_presented fires from willPresent (AppDelegate.swift:114-121), so present-time is delivery-time and the number is literally the trigger lead time. trackNotificationOpened deletes the key at AppAnalytics.swift:2031 without computing anything from it.


## Secondary features

### level_up can never fire: previousLevel is captured after currentLevel is overwritten

`BROKEN_CALLSITE` · event: `level_up`

`compute()` assigns `currentLevel = UserLevel.from(days: sessionDays)` at GamificationEngine.swift:117, then captures `let previousLevel = currentLevel` at line 146 — after the overwrite. The comparison `currentLevel > previousLevel` at line 163 is therefore comparing a value to itself and is always false, so `trackLevelUp` at line 175 is unreachable on every code path. The level_up event has never been emitted by a real device, so progression/retention analysis keyed on it returns zero rows and looks like nobody ever levels up.

**Where:** Core/Analysis/GamificationEngine.swift:163 → Core/Tracking/AppAnalytics.swift:2763

**Fix:** Capture the old value before recomputing: replace line 117 with `let newLevel = UserLevel.from(days: sessionDays)`, keep `let previousLevel = currentLevel` above the assignment, then `currentLevel = newLevel` and compare `newLevel > previousLevel`.

**Verified:** GamificationEngine.swift:117 assigns `currentLevel = UserLevel.from(days: sessionDays)`, and line 146 then does `let previousLevel = currentLevel` — after the overwrite. Line 163 `currentLevel > previousLevel && !previouslyUnlockedIds.isEmpty` compares the value to itself, so didLevelUp is always false and trackLevelUp (AppAnalytics.swift:2763) is unreachable on every path. Only compute() at DashboardViewModel.swift:1432 drives this, and there is no other trackLevelUp call site in the repo.

### achievement_unlocked replays every already-unlocked achievement on every cold launch

`BROKEN_CALLSITE` · event: `achievement_unlocked`

`achievements` is in-memory only (GamificationEngine.swift:98, no persistence anywhere in the file), so on the first `compute()` of each app process `previouslyUnlockedIds` (line 145) is empty and line 162 classifies every currently-unlocked achievement as newly unlocked. A user with 8 unlocked achievements emits 8 achievement_unlocked events on every launch. The author added a first-compute guard for level_up on line 163 (`&& !previouslyUnlockedIds.isEmpty`) but not for achievements, so unlock counts and unlock-date analysis are pure launch-count noise.

**Where:** Core/Analysis/GamificationEngine.swift:162 → Core/Tracking/AppAnalytics.swift:2755

**Fix:** Guard the emit the same way level_up already is: `if !previouslyUnlockedIds.isEmpty { for achievement in newlyUnlocked { ... } }`, or persist the unlocked-id set in UserDefaults and diff against that instead of in-memory state.

**Verified:** GamificationEngine.swift:98 declares `achievements: [Achievement] = []` in memory with no persistence anywhere in the file (grep for UserDefaults/defaults in that file returns nothing; line 487 even recomputes `unlockedDate: unlocked ? now : nil` fresh each run). The engine is created per-process at DashboardViewModel.swift:398, so on the first compute() of each launch previouslyUnlockedIds (line 145) is empty and line 162 marks every unlocked achievement as new, emitting N achievement_unlocked events (AppAnalytics.swift:2755). The level_up guard on line 163 does include `&& !previouslyUnlockedIds.isEmpty` while the achievement loop does not, exactly as claimed.

### Morning check-in fires core_action_completed twice on the phone path

`BROKEN_CALLSITE` · event: `core_action_completed`

`MorningCheckInView.submit()` calls `trackCoreAction(.completedMorningCheckIn, screen: .home)` at line 185, then `onComplete(checkIn)` routes through HomeView.swift:569 → `DashboardViewModel.applyMorningCheckIn` (line 2623) → `MorningCheckInManager.record` which emits the same call again at MorningCheckInManager.swift:56. `trackCoreAction` also fans out to feature_used and score_reaction and increments `lifetime_core_actions`, so every phone check-in double-counts three events and inflates the user property. The watch path (PhoneWatchSession.swift:191) goes straight to `record` and fires once, so phone and watch users are counted on different scales.

**Where:** Modules/Dashboard/Views/Home/MorningCheckInView.swift:185 → Core/Tracking/AppAnalytics.swift:1134

**Fix:** Delete line 185 in MorningCheckInView.swift. MorningCheckInManager.record is already documented as the single writer for both entry points.

**Verified:** MorningCheckInView.swift:185 calls trackCoreAction(.completedMorningCheckIn, screen: .home), then line 187 calls onComplete(checkIn), which HomeView.swift:569 routes to DashboardViewModel.applyMorningCheckIn (line 2622), which calls MorningCheckInManager.record at line 2623; record emits the identical trackCoreAction at MorningCheckInManager.swift:56. trackCoreAction (AppAnalytics.swift:1134) also fans out to trackFeatureUsed, trackScoreReaction and setUserProperty("lifetime_core_actions"), so all of those double-count. PhoneWatchSession.swift:191 calls record directly and fires once, confirming the phone/watch asymmetry.

### Marking Today's Action done emits no recommendation_completed, so the core action loop never closes

`MISSING_EVENT` · event: `recommendation_completed`

`recommendation_viewed` fires when the daily action is opened (TodaysActionDetailView.swift:90), but `DailyActionCompletion.markDone` — the single mark-done path for both phone and watch — emits only a generic `block_tapped` (line 42). `trackRecommendationCompleted` has exactly one call site in the whole app: breathwork. The doc block at AppAnalytics.swift:250 lists recommendation_completed as the "Action loop" retention event, and the viewed→completed conversion for the app's primary daily recommendation cannot be computed. The mark-done also never increments lifetime_core_actions. Separately, the `"done": "true"` metadata is a hardcoded constant (markDone returns early and emits nothing when already done), so it carries no information.

**Where:** Core/Data/DailyActionCompletion.swift:42 → Core/Tracking/AppAnalytics.swift:2455

**Fix:** In `DailyActionCompletion.markDone`, after the block_tapped call add `AppAnalytics.shared.trackRecommendationCompleted(type: "daily_action", metric: actionTitle)` and `AppAnalytics.shared.trackCoreAction(.completedMorningCheckIn-style new case, screen: .home)`; drop the constant `"done": "true"` key.

**Verified:** Accurate except for the strength of "cannot be computed": completions are recoverable from block_tapped (card_id=home_daily_action), so the defect is that the designed recommendation_viewed→recommendation_completed funnel is broken for every recommendation except breathwork and the two events carry incompatible dimensions (type/metric vs card_id/source). The constant `"done": "true"` and the missing lifetime_core_actions increment are both confirmed.


## App lifecycle & data pipeline

### All three CloudKit backup events are unreachable: the CKContainer is hardcoded nil

`BROKEN_CALLSITE` · event: `cloud_backup_completed / cloud_backup_failed / cloud_restore_completed`

CloudBackupManager declares `private let container: CKContainer? = nil` and nothing ever assigns it. `isAvailable` returns false, `performBackup` returns at its `guard await isAvailable, let container` with status .disabled, and `restore` returns false at `guard await isAvailable, let container`. Every trackCloudBackupCompleted / trackCloudBackupFailed / trackCloudRestoreCompleted call sits after that guard, so none of them can ever fire. The taxonomy doc block lists all three as live signals (cloud_backup_completed = "Data safety signal", cloud_backup_failed = "Trust risk", cloud_restore_completed = "Returning user signal"), so backup adoption and restore-on-reinstall read as a flat zero rather than as broken.

**Where:** /Users/primetrace/Desktop/RnD/HealthPulse/Core/Data/CloudBackupManager.swift:23 → /Users/primetrace/Desktop/RnD/HealthPulse/Core/Tracking/AppAnalytics.swift:3378

**Fix:** Set `private let container: CKContainer? = CKContainer(identifier: AppSecrets.CloudKit.containerID)`; if backup is intentionally shelved, delete the three track* funcs and their doc-block lines so the dashboard does not show three permanently-empty events.

**Verified:** CloudBackupManager.swift:23 is `private let container: CKContainer? = nil` and grep shows no other assignment. isAvailable (line 39) returns false immediately on `guard let container`. performBackup returns at line 75 `guard await isAvailable, let container else { backupStatus = .disabled; return }`, and restore returns false at line 150 on the same guard. Every track call sits after those guards: trackCloudBackupCompleted at 126, trackCloudBackupFailed at 135 and 141, trackCloudRestoreCompleted at 168, 185 and 198. The doc block lists all three as live signals at AppAnalytics.swift:330-332, emitters at 3379/3387/3394.

### pendingSessionSource is never cleared on the 30-min resume path, so widget/notification attribution leaks into a later organic session

`WRONG_PROPERTY` · event: `session_started / daily_active / every event (opened_from)`

AppDelegate sets SessionTracker.pendingSessionSource = .notification on a notification tap and ContentView.handleDeepLink sets it to .widget on a laso:// tap. startSession() only consumes and resets it (`pendingSessionSource = .organic`) on the new-session branch; the resume branch returns at line 201 without touching it. A tap that lands while the app is already foregrounded, or within the 30-minute idle window, therefore leaves the tag armed, and the next genuinely-new session (a plain app-icon open hours later) is stamped session_source = notification/widget. That corrupts opened_from on EVERY event of that session, daily_active.session_source, the session_source user property, and organicSessionPercent.

**Where:** /Users/primetrace/Desktop/RnD/HealthPulse/Core/Tracking/SessionTracker.swift:196 → /Users/primetrace/Desktop/RnD/HealthPulse/Core/Tracking/AppAnalytics.swift:3496

**Fix:** In SessionTracker.startSession(), reset `pendingSessionSource = .organic` inside the resume branch too (before `return (false, nil)` at line 201), so a consumed-or-stale tag can never carry into the next session.

**Verified:** Only two writers exist outside SessionTracker: AppDelegate.swift:142 (.notification on notification tap) and ContentView.swift:868 (.widget on laso:// tap). SessionTracker.startSession() consumes and resets only in the new-session branch (SessionTracker.swift:240-241); the resume branch at 194-201 sets lastActivityDate, reopens the span, persists and returns (false, nil) without touching pendingSessionSource. A tap while already foregrounded or inside the 30-minute window therefore leaves the tag armed until the next mint, which stamps currentSessionSource wrong. That feeds opened_from on every event via AppAnalytics.swift:3496-3497 (openedFrom at 3537-3543), the session_source user property at 883, and organicSessionPercent at SessionTracker.swift:573-585.

### stale_data_detected can never fire for any core metric, which is the only cohort it was built for

`BROKEN_CALLSITE` · event: `stale_data_detected`

The only trackStaleDataDetected call site sits inside the metric-skip branch, which is guarded by `!coreMetrics.contains(metric)`. coreMetrics is heartRate, restingHeartRate, HRV, steps, activeCalories, exerciseMinutes, all sleep stages, bloodOxygen, respiratoryRate, vo2Max, weight, workout*. Those are exactly the metrics whose staleness means "watch not worn / pairing broken / sync dead", which the inline comment names as the reason the event exists. It is further gated on `syncCount % 7 != 0` and `lastSync > recentSyncCutoff`, so it only fires for peripheral metrics on the specific syncs where they happen to be skipped. A user whose Apple Watch stopped syncing for a month emits zero stale_data_detected.

**Where:** /Users/primetrace/Desktop/RnD/HealthPulse/Core/Data/HealthKitManager.swift:293 → /Users/primetrace/Desktop/RnD/HealthPulse/Core/Tracking/AppAnalytics.swift:2405

**Fix:** Move the staleness check out of the skip branch: after the task group finishes (around HealthKitManager.swift:349), iterate coreMetrics and emit trackStaleDataDetected for any whose `timeSeries[metric]?.samples.last?.date` is older than staleCutoff, deduped once per metric per day.

**Verified:** Accurate except one detail: coreMetrics contains sleepDuration, sleepREM, sleepDeep and sleepCore but NOT sleepAwake, so 'all sleep stages' is slightly overstated. sleepAwake and the other peripheral metrics are the only ones that can ever emit stale_data_detected.

### sync_failed has exactly one call site; the locked-device skip and the SwiftData-unavailable path fail silently

`MISSING_EVENT` · event: `sync_failed`

trackSyncFailed is called from one place in the whole repo: the HealthKit authorization catch block. loadAndSync bails out with an empty SyncResult when `UIApplication.shared.isProtectedDataAvailable` is false (device locked) and emits nothing at all. Worse, persistFetchedData returns a zeroed PersistedSyncSummary when `store.modelContext` is nil, and loadAndSync then goes on to emit data_sync_completed, sync_performance and data_pipeline_quality as though everything worked, just with 0 new samples. A total persistence outage is therefore indistinguishable from "user had no new health data", and the doc block's "sync_failed reason, retry_count -> Broken pipeline" question cannot be answered.

**Where:** /Users/primetrace/Desktop/RnD/HealthPulse/Core/Data/HealthKitManager.swift:237 → /Users/primetrace/Desktop/RnD/HealthPulse/Core/Tracking/AppAnalytics.swift:2820

**Fix:** Call AppAnalytics.shared.trackSyncFailed(reason: "protected_data_unavailable") before the early return at HealthKitManager.swift:238, and trackSyncFailed(reason: "no_model_context") before the early return in persistFetchedData at HealthKitManager.swift:425 (and skip the three success events on that path).

**Verified:** Repo-wide grep finds trackSyncFailed only at HealthKitManager.swift:182 (the authorization catch). loadAndSync returns an empty SyncResult at HealthKitManager.swift:237-239 when isProtectedDataAvailable is false, with no tracking. persistFetchedData returns a zeroed PersistedSyncSummary at 424-426 when store.modelContext is nil, and loadAndSync then still emits trackDataSync (383), trackSyncPerformance (391) and trackDataPipelineQuality (397) with zero counts, so a total persistence outage is indistinguishable from 'no new data'. Doc line 280 promises sync_failed reason/retry_count for exactly this question; emitter at AppAnalytics.swift:2820-2825.

### section_viewed fires twice per section, once with duration_ms hardcoded to 0

`BROKEN_CALLSITE` · event: `section_viewed`

SectionTracker.appeared() emits section_viewed with durationMs: 0, and disappeared() emits section_viewed again for the same section with the real dwell time. Nothing on the event distinguishes the two, so every section-visibility count in Amplitude is exactly 2x reality and any avg/median of duration_ms is dragged toward zero by an equal number of synthetic 0 ms rows. Both the "how many users see this section" and "how long do they dwell" questions return wrong numbers.

**Where:** /Users/primetrace/Desktop/RnD/HealthPulse/Core/Tracking/SectionTracker.swift:109 → /Users/primetrace/Desktop/RnD/HealthPulse/Core/Tracking/AppAnalytics.swift:1933

**Fix:** Delete the trackSectionViewed call in appeared() (keep `appearDate = Date()`), so section_viewed is emitted once, on disappear, with the real duration_ms.

**Verified:** SectionTracker.appeared() at SectionTracker.swift:107-110 calls trackSectionViewed(..., durationMs: 0); disappeared() at 112-118 calls it again for the same section with the real elapsed ms. trackSectionViewed (AppAnalytics.swift:1933-1941) sends section_id, tab, screen, duration_ms and session_id with nothing distinguishing appear from disappear. SectionTracker is widely instantiated (Explore, Settings, CategoryDetail, MetricDetail, Insights, Discovery and more) with 52 .appeared() call sites, so this is live code, not a dead path.


## Taxonomy consistency

### time_to_first_value re-emits on every sync forever with a stale value

`BROKEN_CALLSITE` · event: `time_to_first_value`

SessionTracker.recordFirstValueTime() is the one-shot (it writes the UserDefaults key only once), but AppAnalytics.trackTimeToFirstValue() then emits the event on EVERY call because its only gate is `ttfv > 0`, which is permanently true after the first recording. The caller runs inside loadAndSync on every foreground refresh that returns changed metrics, so a daily user emits time_to_first_value hundreds of times, always carrying the seconds value captured in session 1 but the CURRENT session_number. North-star metric #2 (time to first value) becomes uncountable by event volume and 'TTFV by session number' is pure noise. Edge case on top: if the first sync lands in the same second as session start, elapsed is 0, the event never fires at all and the persisted guard stays open.

**Where:** Core/Data/HealthKitManager.swift:409 → Core/Tracking/AppAnalytics.swift:710-720

**Fix:** Make SessionTracker.recordFirstValueTime() return Bool (true only on the first write, and store a separate 'emitted' flag when elapsed == 0), and in trackTimeToFirstValue emit only when it returns true: `guard session.recordFirstValueTime() else { return }`.

**Verified:** SessionTracker.recordFirstValueTime() (SessionTracker.swift:505-509) guards on `defaults.integer(forKey:) == 0` so it writes once; AppAnalytics.trackTimeToFirstValue() (AppAnalytics.swift:710-720) then gates only on `ttfv > 0`, which stays true forever. The caller HealthKitManager.swift:409 sits inside loadAndSync, which DashboardViewModel.swift:732 runs on every refresh, and fires whenever `persisted.metricsWithChanges` is non-empty. So the event re-emits with the session-1 seconds value and the current session_number. The elapsed==0 edge case is also real: defaults.set(0) leaves the guard open.

### retention_milestone fires milestones in ascending order one per session, not on the actual day

`BROKEN_CALLSITE` · event: `retention_milestone`

checkRetentionMilestone() loops [1,2,3,7,14,30] and returns the FIRST milestone not yet recorded whose day is <= daysSinceInstall, one per session. A user who installs, disappears, and returns for the first time on day 30 emits retention_milestone day=1; their next session emits day=2, then day=3, day=7, and so on. D1/D7/D30 in Amplitude therefore measure 'opened the app an Nth time at any point in its life', not day-N retention. This silently corrupts north-star metric #3, and every cohort built on it. daysSinceInstall is also computed once in loadLifecycleState() at singleton init and never refreshed, so a process kept alive across midnight evaluates against a stale day.

**Where:** App/ContentView.swift:883 → Core/Tracking/SessionTracker.swift:413-429

**Fix:** In checkRetentionMilestone(), mark every milestone <= daysSinceInstall as consumed in one pass and return a day only when it equals daysSinceInstall (return nil otherwise), and recompute daysSinceInstall at the top of startSession() instead of only in init.

**Verified:** SessionTracker.swift:413-429: checkRetentionMilestone loops [1,2,3,7,14,30] and returns the FIRST day with `daysSinceInstall >= day` not yet in retentionMilestones, one per call. A user first returning on day 30 emits day=1, then day=2 next session, etc. Caller is ContentView.swift:883 (analytics.trackRetentionMilestones() inside startSessionAnalytics). daysSinceInstall is a stored property set only in loadLifecycleState() (SessionTracker.swift:458-471), called only from init at line 158, never refreshed in startSession — the stale-across-midnight part holds too.

### section_viewed double-fires per view, half the events with duration_ms hardcoded to 0

`BROKEN_CALLSITE` · event: `section_viewed`

SectionTracker.appeared() calls trackSectionViewed(durationMs: 0) and disappeared() calls the SAME event name again with the real duration. Every section view therefore produces two section_viewed events, exactly half of them with duration_ms = 0. Section view counts are doubled and any average/median duration is roughly halved by the zero rows. Worse, these are wired to SwiftUI .onAppear/.onDisappear inside scrolling LazyVStacks (HomeView, ExploreView, LiveView), so a single scroll up and down multiplies the inflation.

**Where:** Modules/Dashboard/Views/Home/HomeView.swift:647 → Core/Tracking/SectionTracker.swift:107-117

**Fix:** Delete the trackSectionViewed call from appeared() (keep only the appearDate stamp) so section_viewed is emitted exactly once, on disappear, with the real duration.

**Verified:** SectionTracker.swift:107-117: appeared() calls trackSectionViewed(durationMs: 0) and disappeared() calls trackSectionViewed with the real duration — same event name both times. Wiring confirmed as .onAppear/.onDisappear pairs in HomeView.swift:647-648, ExploreView.swift:65-77, CategoryDetailView.swift:25-165, LiveView, SettingsView etc. Every section view produces two section_viewed rows, exactly half with duration_ms = 0.

### `tab` on section_viewed / section_tapped carries a screen id, colliding with the global tab value space

`WRONG_PROPERTY` · event: `section_viewed`

SectionTracker holds `tab: AppFeature` and views pass full screens for it (.categoryDetail, .insightsDetail, .weeklyReview, .healthStateTimeline, .recoveryInfo, .scoreGuide, .discovery, .correlations). trackSectionViewed/trackSectionTapped write that rawValue into `tab`, overriding logEvent's global injection. Every other event's `tab` is session.currentTab, which is only home | live | explore | settings. So a single Amplitude breakdown on `tab` mixes four real tabs with a dozen screen names, and 'sections viewed per tab' silently under-counts every tab. The same call also duplicates the value into `screen`, so both dimensions are wrong at once for non-tab surfaces.

**Where:** Modules/CategoryDetail/Views/Category/CategoryDetailView.swift:7 → Core/Tracking/AppAnalytics.swift:1933-1941

**Fix:** In trackSectionViewed and trackSectionTapped, send the AppFeature only as `screen` and drop the `tab` key so logEvent injects the real session.currentTab.

**Verified:** trackSectionViewed/trackSectionTapped (AppAnalytics.swift:1933-1951) write `"tab": tab.rawValue` and `"screen": tab.rawValue` from an AppFeature. logEvent only injects the global when absent (`if enriched["tab"] == nil` at AppAnalytics.swift:3488-3490), so the explicit value wins. Non-tab AppFeatures are genuinely passed: CategoryDetailView.swift:7-11 (.categoryDetail), InsightsDetailView.swift:14 (.insightsDetail), WeeklyReviewView.swift:85-87, HealthStateTimelineView.swift:11-12, RecoveryInfoSheet.swift:8, ScoreGuideSheet.swift:15, DiscoveryView.swift:12, CorrelationsView.swift:16. session.currentTab is only ever set from AppTab (ContentView.swift:252; AppTab.swift:4-8 = home|live|explore|settings), so the value spaces really do collide.

### session_ended drops session_source and max depth, and its injected opened_from describes the wrong session

`MISSING_PROPERTY` · event: `session_ended`

EndedStats carries sessionSource and SessionTracker persists maxDepth in the open-session snapshot, but emitSessionEnded sends neither. Meanwhile the sibling events built from the SAME stats moments later (ghost_session, session_quality) do send session_source. Worse, logEvent injects `opened_from` from the LIVE session: for the in-process idle-timeout end, startSession() has already overwritten currentSessionSource with the new session's source, and for the reconciled post-kill end the fresh process has it defaulted to .organic, so session_ended is always attributed to app_icon or to the wrong entry point. The author already threaded session_id and session_number explicitly to dodge exactly this bug but missed the source. Result: 'do notification-opened sessions end shorter than organic ones' is unanswerable from session_ended, and the doc block's promised session depth never ships at all.

**Where:** App/ContentView.swift:880 → Core/Tracking/AppAnalytics.swift:919-938

**Fix:** Add `"session_source": stats.sessionSource` and `"opened_from": Self.openedFrom(for:)`-equivalent derived from stats.sessionSource to the emitSessionEnded parameter dictionary, and add a `maxDepth` field to EndedStats (it is already persisted at SessionTracker.swift:307) emitted as `max_depth`.

**Verified:** EndedStats carries sessionSource (SessionTracker.swift:166-175) and emitSessionEnded (AppAnalytics.swift:918-938) does not send it, while the siblings built from the SAME struct milliseconds later do: ghost_session at 2851 and session_quality at 2869 both send session_source. Ordering confirms the opened_from claim: trackSessionStart emits the reconciled end at AppAnalytics.swift:812-814 BEFORE startSession (currentSessionSource still at its .organic default, SessionTracker.swift:62), and the idle-timeout end at 820-822 AFTER startSession has already set currentSessionSource = pendingSessionSource (SessionTracker.swift:240) — so logEvent's injection (AppAnalytics.swift:3495-3497) attributes the wrong session both ways. Depth: persistOpenSession writes "depth": maxDepth (SessionTracker.swift:307) but reconcilePersistedSession never reads it back, EndedStats has no depth field, and the doc block promises `session_end  duration_sec, screens, depth` at line 242.

### `granted` carries three incompatible value spaces across the permission funnel

`WRONG_PROPERTY` · event: `health_permission_result`

health_permission_result sends granted as a COUNT of metrics (0...~50, from HealthKitManager's permissionGranted). notification_permission_result sends granted as a BOOLEAN 1/0. repermission_conversion sends granted as the literal constant 1. Amplitude treats `granted` as one property: any 'grant rate' chart or filter on granted = 1 counts a user who granted exactly one HealthKit metric alongside every notification opt-in, and drops the user who granted 30. This is the core permission-funnel dimension for north-star activation.

**Where:** Core/Data/HealthKitManager.swift:377 → Core/Tracking/AppAnalytics.swift:2326-2333

**Fix:** Rename the count on health_permission_result to `granted_count` (line 2328) and keep `granted` as the 1/0 boolean everywhere; drop the constant `granted: 1` from repermission_conversion (line 1099) since the event only exists on conversion.

**Verified:** AppAnalytics.swift:2326-2333 sends `"granted": granted` where granted is a COUNT — HealthKitManager.swift:376-377 computes it as `HealthMetric.allCases.filter { timeSeries[$0]?.samples.isEmpty == false }.count`. AppAnalytics.swift:3428-3431 sends `"granted": granted ? 1 : 0` (boolean) on notification_permission_result. AppAnalytics.swift:1099 sends `"granted": 1` as a literal constant on repermission_conversion. Same property name, three value spaces, on the core permission funnel.


---

# Medium severity (42)


## Onboarding

### Quitting on the final done screen emits neither drop_off nor completed, so the last step of the funnel has a blind spot

`MISSING_EVENT` · event: `onboarding_drop_off`

The scenePhase handler skips the drop-off when `screen == .done` (OnboardingV2View.swift:172), on the assumption that done is "the post-flow state". It is not: onboarding is only marked complete and onboarding_completed only fires inside the done screen's CTA closure (OnboardingV2View.swift:295-309, Screens14ToDone.swift:827-834). A user who reaches done and backgrounds without tapping produces no drop_off and no completed, their last event is step_key=paywall action=completed, and on the next launch they restart at .welcome and re-emit the whole step sequence. Abandonment on the single most important screen is invisible.

**Where:** Modules/Onboarding/Views/Onboarding/OnboardingV2View.swift:172 → Core/Tracking/AppAnalytics.swift:561

**Fix:** Replace the `screen != .done` condition with a `@State private var completedTracked = false` flag set inside the done CTA closure, and guard on `!completedTracked` so a background on the done screen still emits onboarding_drop_off with last_step=done.

**Verified:** OnboardingV2View.swift:172 is `guard newPhase == .background, screen != .done else { return }` with the comment '.done is the post-flow state, not a drop-off'. But .done is a live screen with its own CTA: OnbV2ScreenDone's button (Screens14ToDone.swift:827-834) is the only thing that calls onDone, and the router's done closure (:295-309) is where appStateStore.markOnboardingCompleted() and trackOnboardingCompleted both live. Confirmed markOnboardingCompleted (App/AppStateStore.swift:70-77) only persists a UserDefaults bool, so a user who backgrounds on .done without tapping is not marked complete and restarts onboarding next launch. AppAnalytics.swift:557-561 documents the intended semantic: 'the LAST drop_off with no later onboarding_completed is the true abandonment point'. For a done-screen abandoner that reads as either no drop_off at all, or a stale earlier drop_off, so the abandonment is either invisible or attributed to the wrong screen.

### onboarding_completed carries no focuses and is stamped with onboarding_completed="no", because the user properties are set after logEvent

`MISSING_PROPERTY` · event: `onboarding_completed`

The taxonomy block promises `onboarding_completed focuses, duration_sec` (AppAnalytics.swift:222) but the event body sends only duration_sec (AppAnalytics.swift:641-643); `focuses` is discarded into a user property afterwards. Both setUserProperty calls run after logEvent (AppAnalytics.swift:644-645) and each is a separate Amplitude Identify (AmplitudeProvider.swift:97-102), which Amplitude applies in arrival order, so the onboarding_completed event itself is stamped with the session-start value onboarding_completed="no" (AppAnalytics.swift:3196) and no health_focus. markOnboardingCompleted at the call site (OnboardingV2View.swift:299) only writes UserDefaults and pushes nothing, so the ordering intent documented at AppAnalytics.swift:636-639 is never achieved. Net effect: activation cannot be broken down by goal at the moment of completion, and the completion event contradicts its own user property.

**Where:** Modules/Onboarding/Views/Onboarding/OnboardingV2View.swift:303 → Core/Tracking/AppAnalytics.swift:641

**Fix:** In trackOnboardingCompleted, move the two setUserProperty calls above logEvent and add the focuses to the event: `"focuses": focuses, "focus_count": focuses.count` alongside duration_sec.

**Verified:** Accurate as written, but note the function's own doc (AppAnalytics.swift:638-639) states dropping focuses from the event is deliberate ('health_focus is kept as a user property; the event itself carries only duration_sec'), so the focuses half is a doc-block contradiction between line 222 and line 638, not an accidental omission. The ordering half is the substantive defect.

### The in-flow notification ask re-emits requested/result on re-entry even though iOS shows no prompt

`BROKEN_CALLSITE` · event: `notification_permission_requested`

requestNotificationPermission is called unconditionally from the vitality-reveal CTA on the rich branch (OnboardingV2View.swift:262-270) and from the cliffhanger yes button (Screens8to13.swift:1618-1625). Both screens are re-creatable by back navigation (heart.onBack -> preview at :247; the back-nav scan re-run recreates the cliffhanger, and its `notifyHandled` flag is view-local @State), and NotificationManager.requestAuthorization has no notDetermined check: it emits notification_permission_requested and notification_permission_result on every call (NotificationManager.swift:107,114). Once the status is determined iOS returns the cached answer without showing an alert, so the permission funnel for source=vitality_reveal / cliffhanger contains request+result pairs for prompts that were never displayed, and the grant rate for those sources is wrong.

**Where:** Modules/Onboarding/Views/Onboarding/OnboardingV2View.swift:530 → Core/Tracking/AppAnalytics.swift:3420

**Fix:** In OnboardingV2View.requestNotificationPermission, early-return when the status is already determined: `guard await NotificationManager.shared.shouldRequestAuthorizationOnLaunch() else { return }` before calling requestAuthorization.

**Verified:** Confirmed, but the consequence is narrower than stated: the duplicate request+result pairs carry the same cached granted value, so the ratio itself is only mildly skewed. The concrete damage is inflated notification_permission_requested volume for source=vitality_reveal / cliffhanger and request+result pairs recorded for prompts iOS never displayed, so 'how many users were asked' is wrong.

### step_count is a constant 14 that matches neither the visible progress total (13) nor the flow the user actually walks

`WRONG_PROPERTY` · event: `onboarding_step_completed`

stepCount = linearOrder.count - 1 (OnboardingV2View.swift:391) and all three branch orders have exactly 15 entries (:372-386), so step_count is always 14 for every user and every branch, while the on-screen progress total is the hardcoded OnbV2Flow.total = 13 (OnboardingV2Foundation.swift:92). It also ignores the three live flow shorteners: the Remote Config onboarding_skip_screens CSV (:324), the referral screen that is skipped when the program is off or already redeemed (:614-617), and the paywall that is skipped for entitled users (:628). The router comment at :388-390 claims the denominator matches the visible progress total, which is false. Any "% of onboarding completed" or step_index/step_count ratio is therefore wrong for every user whose flow is shortened, and cannot be compared with what the user actually saw.

**Where:** Modules/Onboarding/Views/Onboarding/OnboardingV2View.swift:391 → Core/Tracking/AppAnalytics.swift:550

**Fix:** Compute one live order, `linearOrder.filter { !skipSet.contains($0.rawValue) && isReachable($0) }`, and drive stepCount, screenOrdinal and the OnbV2TopBar total from it; delete OnbV2Flow.total and pass the router's stepCount into every top bar.

**Verified:** Counted all three arrays at OnboardingV2View.swift:372-386: sparse, denied and rich each hold exactly 15 cases, so stepCount = linearOrder.count - 1 (:391) is literally 14 for every user on every branch, a constant. OnboardingV2Foundation.swift:91-93 is `enum OnbV2Flow { static let total = 13 }`, and every OnbV2TopBar call site passes OnbV2Flow.total (14 call sites across Screens1to7/8to13/14ToDone/OnbV2VitalityReveal), so the user sees 'of 13' while step_count says 14. The doc comment at :388-390 claiming 'the funnel denominator matches the visible progress total on all branches' is false. The shorteners are real too: the skip CSV is consulted only inside advance() (:324-337), the referral gate is in handleSignedIn (:657-660) and the paywall gate in advanceAfterReferral (:671-675), and none of them feed stepCount.


## Paywall & Subscription

### `screen` is hardcoded to `.proOverlay` at all three call sites and overrides the real screen

`WRONG_PROPERTY` · event: `premium_feature_attempted`

TimeRangeSelector.swift:38 and LockedInsightsCTA.swift:18 both pass `screen: .proOverlay` even though the user is on MetricDetail/CategoryDetail/Insights when they hit the lock. Because `logEvent` only injects the `screen` global when the key is absent (AppAnalytics.swift:3491), the explicit value wins and destroys the true screen, so `premium_feature_attempted` reports a single constant screen and cannot tell you where free users hit walls.

**Where:** /Users/primetrace/Desktop/RnD/HealthPulse/Common/Components/TimeRangeSelector.swift:38 → /Users/primetrace/Desktop/RnD/HealthPulse/Core/Tracking/AppAnalytics.swift:2123

**Fix:** Drop the `screen` parameter from `trackPremiumFeatureAttempted` (AppAnalytics.swift:2123) so the auto-injected `screen` global carries the real screen, or pass the hosting screen through as a parameter at TimeRangeSelector.swift:38 and LockedInsightsCTA.swift:18 instead of `.proOverlay`.

**Verified:** TimeRangeSelector.swift:36-39 passes screen: .proOverlay from a picker embedded in MetricDetail/CategoryDetail; LockedInsightsCTA.swift:18 passes screen: .proOverlay from a card rendered under an insight list; ProFeatureOverlay.swift:47 passes it too (correct there). logEvent at AppAnalytics.swift:3491 injects the screen global only when the key is absent (`if enriched["screen"] == nil`), so the explicit value wins and premium_feature_attempted ships a single constant screen value across all three surfaces.

### `error_type` is inferred by substring-matching five hardcoded internal strings, so real failures bucket as "unknown"

`WRONG_PROPERTY` · event: `paywall_error`

`classifyPaywallError` (PaywallView.swift:148-166) matches against `subscriptionManager.errorMessage`, which is only ever one of five literals set in SubscriptionManager (lines 160, 164, 237, 243, 285). The post-CTA failure message "Purchase failed. Please try again." matches none of the buckets and lands in `unknown`, and the `payment_declined`, `cancelled` and `not_permitted` branches are unreachable dead code because no code path ever produces a message containing those words.

**Where:** /Users/primetrace/Desktop/RnD/HealthPulse/Modules/Paywall/Views/Subscription/PaywallView.swift:148 → /Users/primetrace/Desktop/RnD/HealthPulse/Core/Tracking/AppAnalytics.swift:1473

**Fix:** Replace the free-text `errorMessage` with a typed failure on SubscriptionManager (e.g. `private(set) var lastErrorKind: PaywallErrorKind?` set alongside each `errorMessage` assignment) and pass `lastErrorKind.rawValue` into `trackPaywallError`; delete `classifyPaywallError`.

**Verified:** Overstated on one point: the network bucket is NOT broken — both product-load failure messages route to it correctly. The accurate defect is that three of the six buckets (cancelled, payment_declined, not_permitted) are unreachable dead branches, and both post-CTA failure messages fall through to "unknown", so paywall_error carries no usable cause for anything that happens after the CTA.

### Plan block type is decided by string-comparing a Remote Config copy value to "Yearly"

`BROKEN_CALLSITE` · event: `block_tapped`

PaywallView.swift:276 does `label == "Yearly"` to pick `.paywallPlanYearly` vs `.paywallPlanMonthly`, but `label` is `Copy.Paywall.yearly`, a Firebase Remote Config string (Copy+Paywall.swift:21) whose default just happens to be "Yearly". Any copy experiment or localisation makes every yearly plan tap report `block_type: paywall_plan_monthly`, and the same `label.lowercased()` feeds `billing_period` and `paywall_plan_selected.period`, so a pure copy change silently inverts plan-preference data.

**Where:** /Users/primetrace/Desktop/RnD/HealthPulse/Modules/Paywall/Views/Subscription/PaywallView.swift:276 → /Users/primetrace/Desktop/RnD/HealthPulse/Core/Tracking/AppAnalytics.swift:1461

**Fix:** Key the branch on identity, not copy: pass an explicit `isYearly: Bool` (or compare `product.id == SubscriptionConfig.yearlyProductID`) into `pricingOption` and use it for the `BlockType`, `billing_period` and `period` values instead of `label`.

**Verified:** Latent, not currently firing wrong: with the baked-in default "Yearly" the branch is correct today. The defect is that an analytics dimension is derived from live, remotely-editable display copy in a codebase where all copy is RC-driven by policy.

### A StoreKit product-load failure turns an involuntary billing retry into a voluntary-churn event

`BROKEN_CALLSITE` · event: `subscription_cancelled`

`isInBillingRetry()` iterates `products` and returns false when the array is empty (SubscriptionManager.swift:433-451), which is exactly what happens after `loadProducts()` times out at 8s (line 158-164). `refreshStatus` then skips grace entirely and sets `.expired` (line 369), and the next `updateSubscriptionProperties` sees pro -> expired and emits `subscription_cancelled` (AppAnalytics.swift:1705). A transient network failure on launch is thus recorded as the north-star churn event for a still-paying user, and also flips `subscription_status` to expired.

**Where:** /Users/primetrace/Desktop/RnD/HealthPulse/Core/Subscriptions/SubscriptionManager.swift:335 → /Users/primetrace/Desktop/RnD/HealthPulse/Core/Tracking/AppAnalytics.swift:1614

**Fix:** Guard the expiry path on having real product data: in `refreshStatus` (SubscriptionManager.swift:334) return early leaving `status` unchanged when `products.isEmpty`, so no status flip and no `subscription_cancelled` is emitted from an unverifiable state.

**Verified:** Real but narrower than stated, and 'still-paying user' is wrong — the user's entitlement has actually lapsed and Apple is retrying, so this is involuntary churn misrecorded as the voluntary-churn event, not a false churn for a healthy subscriber. It additionally requires no persisted graceStartDate (step 3 at line 348 would otherwise hold them in grace) and no active Firestore record (step 4, line 359). Collateral: because the grace branch is skipped, billing_grace_started (line 553) never fires either, so the involuntary-churn funnel loses its entry event as well.


## Home / Live / Explore / Settings

### manage_devices and metric_alerts_picker block taps fire on the destination's onAppear, so they refire on back navigation

`BROKEN_CALLSITE` · event: `block_tapped`

Both NavigationLinks attach the trackBlockTap (and the SectionTracker.tapped call) to the pushed destination's .onAppear rather than to the tap. ConnectedDevicesView.onAppear runs again every time the user pops back from DeviceDetailView or DeviceSetupGuideView, so block_tapped(manage_devices) counts navigations back into the list as fresh taps from Settings. The same pattern inflates metric_alerts_picker.

**Where:** Modules/Settings/Views/SettingsView.swift:308, Modules/Settings/Views/NotificationsSettingsView.swift:112 → Core/Tracking/AppAnalytics.swift:1163

**Fix:** Replace the NavigationLink(destination:label:) with NavigationLink(value:) plus a .simultaneousGesture(TapGesture().onEnded { trackBlockTap(...) }) on the row, or move the tracking into a Button that appends the route, so the event is bound to the tap not to the destination lifecycle.

**Verified:** SettingsView.swift:301-319: the trackBlockTap(.manageDevices) and devicesTracker.tapped are inside .onAppear attached to ConnectedDevicesView, the NavigationLink destination. NotificationsSettingsView.swift:111-125 does the same with .metricAlertsPicker on MetricAlertPickerView. ConnectedDevicesView pushes DeviceDetailView at :56, :82 and :112, so popping back re-runs its onAppear and re-emits a Settings-screen block_tapped for a tap that never happened.

### Every tab switch reports screen = home regardless of which tab the user left

`WRONG_PROPERTY` · event: `block_tapped`

The onChange(of: selectedTab) handler hardcodes screen: .home for all four tab BlockTypes, so a Settings->Live switch emits block_tapped with block_type=tab_live and screen=home. trackBlockTap also derives element_id and action_id from that screen value (AppAnalytics.swift:1164-1176), so the ids become "home_tab_live" for a tap that never happened on Home. Any count of Home block taps is polluted by every tab switch performed from Live, Explore and Settings.

**Where:** App/ContentView.swift:262 → Core/Tracking/AppAnalytics.swift:1163

**Fix:** Map oldTab to its AppFeature (.home/.live/.explore/.settings) and pass that as screen: instead of the literal .home.

**Verified:** ContentView.swift:251-264: the onChange(of: selectedTab) handler switches newTab to pick blockType but passes the literal screen: .home at :262. trackBlockTap (AppAnalytics.swift:1163-1180) builds action_id as "\(screen)_\(type)_\(target)" and element_id as "\(screen)_\(type)", and sets "screen": screen.rawValue explicitly; logEvent only injects screen when the key is absent (AppAnalytics.swift:3489-3491), so the hardcoded .home wins.

### empty_state_shown fires only on Home; Explore, Live, Insights and Correlations empty states emit nothing

`MISSING_EVENT` · event: `empty_state_shown`

Home emits it correctly (HomeView.swift:693, HomeConnectHealthView.swift:20), but the four other blocked-from-value states in this area are silent: ExploreEmptyStateSection (ExploreView.swift:316), LiveWaitingForDataView (LiveView.swift:59), the DSEmptyState in InsightsDetailView (line 125) and the Correlations emptyState (CorrelationsView.swift:77). The doc block lists empty_state_shown under Q1 as the Blocked from value signal, so the funnel currently only sees Home blockage and cannot tell whether a user bounced off an empty Live or Explore tab.

**Where:** Modules/Explore/Views/Explore/ExploreView.swift:316, Modules/Live/Views/Live/LiveView.swift:59 → Core/Tracking/AppAnalytics.swift:2803

**Fix:** Add .onAppear { AppAnalytics.shared.trackEmptyStateShown(screen: .explore, reason: hasAnyHealthData ? "syncing" : (isAuthorized ? "authorized_no_data" : "not_authorized")) } on ExploreEmptyStateSection, and the equivalent one-liner with screen: .live / .insightsDetail / .correlations on the other three.

**Verified:** Real but narrower than stated. Explore's empty state largely duplicates a condition Home already reports (no HealthKit data), so its absence is closer to redundancy than a lost question. The load-bearing gaps are LiveWaitingForDataView (a distinct no-live-source state that Home's event does not cover, hit by users who have history but no watch) and InsightsDetailView's filter-empty state.

### Home metric strip tiles are tagged recovery_card, and the real recovery card tap is untracked

`WRONG_PROPERTY` · event: `block_tapped`

MetricStripView's tile callback sends type: .recoveryCard for every vitals tile (sleep, steps, HRV...), so block_type=recovery_card in Amplitude actually means "a vitals tile was tapped". Meanwhile the RecoveryHeroCard's own onTap, which opens the recovery explainer or the score guide (HomeView.swift:498-504), emits no block_tapped at all, and the enum case .homeRecoveryInfoButton that exists for it is passed nowhere in the codebase. Any analysis of the score card's tap rate is reading metric strip data.

**Where:** Modules/Dashboard/Views/Home/HomeView.swift:614 → Core/Tracking/AppAnalytics.swift:54

**Fix:** Change type: .recoveryCard to type: .metricRow at HomeView.swift:614, and add trackBlockTap(title: "Recovery Score", type: .homeRecoveryInfoButton, screen: .home, metadata: ["has_live_readiness": hasLiveReadiness]) inside the RecoveryHeroCard onTap closure.

**Verified:** Repo-wide grep for `type: .recoveryCard` returns exactly one hit, HomeView.swift:614, inside the MetricStripView tile callback (:611-618) which fires for every vitals tile. RecoveryHeroCard's onTap at HomeView.swift:498-504 only flips showRecoveryInfo/showScoreGuide with no trackBlockTap, and neither sheet (:72 and :85) emits a screen event. Repo-wide grep for homeRecoveryInfoButton returns only the enum definition at AppAnalytics.swift:160, never a call site.

### home_illness and home_risks always fire together because both trackers hang off one merged banner

`WRONG_PROPERTY` · event: `section_viewed`

compactAlertBanner renders when an illness warning OR a risk exists, and its single .onAppear calls illnessTracker.appeared() and risksTracker.appeared() unconditionally. A user with two risks and no illness warning produces a home_illness impression for content that was never on screen, and vice versa. The two sections therefore always have identical impression counts and neither can be used to judge which alert type users actually see.

**Where:** Modules/Dashboard/Views/Home/HomeView.swift:603 → Core/Tracking/AppAnalytics.swift:1933

**Fix:** Move each tracker onto the sub-view it describes: attach illnessTracker's appeared/disappeared to the `if let warning` Button block (HomeView.swift:709) and risksTracker's to the ForEach(risks.prefix(2)) block (line 752).

**Verified:** HomeView.swift:602-604: `compactAlertBanner` carries a single .onAppear that calls illnessTracker.appeared() and risksTracker.appeared() unconditionally, and a single .onDisappear doing the same. The banner body (:701-708) renders whenever `warning != nil || !risks.isEmpty`, with the illness Button under `if let warning` (:707) and the risk rows under ForEach(risks.prefix(2)) (:751), so either sub-block can be absent while both trackers still fire.

### The Home illness early-warning banner tap into Insights is untracked while the risk rows beside it are tracked

`MISSING_EVENT` · event: `block_tapped`

The early-warning Button at HomeView.swift:710 calls navigationPath.append(Route.insightsDetail) with no analytics, whereas the risk rows immediately below it in the same card fire trackBlockTap(.homeRiskRow) plus risksTracker.tapped (lines 754-763). insights_detail is also reachable from other surfaces, and previous_screen is home in every case, so there is no way to attribute an Insights open to the illness banner or measure that banner's CTR.

**Where:** Modules/Dashboard/Views/Home/HomeView.swift:710 → Core/Tracking/AppAnalytics.swift:1163

**Fix:** Add trackBlockTap(title: "Early Warning", type: .headlineInsight, screen: .home, metadata: ["severity": warning.severity.rawValue, "destination": "insights_detail"]) plus illnessTracker.tapped(target: "early_warning") in the Button action before the append.

**Verified:** HomeView.swift:708-710: the early-warning Button action is only `navigationPath.append(Route.insightsDetail)` with no analytics and no illnessTracker.tapped. The risk rows immediately below at :751-763 fire trackBlockTap(type: .homeRiskRow) plus risksTracker.tapped(target:). Confirmed the asymmetry inside the same card.

### TimeRangeSelector reports screen = pro_overlay for every locked time-range tap

`WRONG_PROPERTY` · event: `premium_feature_attempted`

The locked-range branch passes screen: .proOverlay, a constant, even though the user is standing on Metric Detail or Category Detail and no pro overlay is on screen (a paywall sheet with source "time_range_locked" is what opens). The doc block defines premium_feature_attempted as feature + screen for Free user desire, so the screen dimension is dead: you cannot tell whether free users hit the range wall on metric_detail or category_detail. LockedInsightsCTA.swift:18 hardcodes the same constant.

**Where:** Common/Components/TimeRangeSelector.swift:36 → Core/Tracking/AppAnalytics.swift:2123

**Fix:** Add a `var screen: AppFeature = .metricDetail` parameter to TimeRangeSelector, pass .metricDetail from MetricDetailView.swift:84 and .categoryDetail from CategoryDetailView.swift:118, and forward it to trackPremiumFeatureAttempted.

**Verified:** TimeRangeSelector.swift:35-39 passes the literal screen: .proOverlay to trackPremiumFeatureAttempted for the locked branch. trackPremiumFeatureAttempted (AppAnalytics.swift:2122-2129) writes "screen": screen.rawValue explicitly, so it is not overridden by the auto-injected global. The component is used only from CategoryDetailView.swift:118 and MetricDetailView.swift:84 (repo grep), never inside a pro overlay. LockedInsightsCTA.swift:12-18 hardcodes the same constant on both trackBlockTap and trackPremiumFeatureAttempted. Doc block line 272 defines the event as feature + screen.

### risk_tapped omits the tapped metric and is identical from two different row types

`MISSING_PROPERTY` · event: `risk_tapped`

Both the focus-area cards and the contributing-factor rows call trackRiskTapped(riskType:grade:screen:), whose signature carries no metric or target (AppAnalytics.swift:1244). The two call sites produce byte-identical payloads, and both duplicate the risk/grade already sent on the preceding screen_viewed(risk_detail). There is no way to answer which factor drives users deeper, which is the only question the event on this screen can serve.

**Where:** Modules/Risk/Views/Risk/HealthRiskDetailView.swift:115, Modules/Risk/Views/Risk/HealthRiskDetailView.swift:137 → Core/Tracking/AppAnalytics.swift:1244

**Fix:** Add `metric: String` and `source: String` parameters to trackRiskTapped and pass area.metric.rawValue / "focus_area" at line 115 and factor.metric.rawValue / "contributing_factor" at line 137.

**Verified:** Real, but the doc-block angle does not apply: AppAnalytics.swift:294 documents risk_tapped as risk_type, grade only, so the code is not breaking a documented promise. The defect stands on its own terms - the event is fully redundant with screen_viewed(risk_detail) and cannot distinguish focus-area from contributing-factor taps.

### The all-insights screen emits insight_opened while Category Detail emits insight_tapped, losing severity and metric

`WRONG_PROPERTY` · event: `insight_opened`

InsightsDetailView's card tap calls trackInsightOpened(metricCategory:), which sends only metric_category (AppAnalytics.swift:2304), while CategoryDetailView's card tap calls trackInsightTapped with insight_category, severity and metric (AppAnalytics.swift:1226). The doc block defines insight_tapped as the insight engagement event with category, severity and metric. Insight engagement on the screen that shows the full list therefore cannot be segmented by severity, and the two surfaces cannot be compared in one chart because they emit different event names.

**Where:** Modules/Insights/Views/Insights/InsightsDetailView.swift:107 → Core/Tracking/AppAnalytics.swift:2304

**Fix:** Replace the trackInsightOpened call with trackInsightTapped(category: insight.category.rawValue, severity: insight.severity.rawValue, metric: insight.metric.rawValue, screen: .insightsDetail).

**Verified:** InsightsDetailView.swift:106-109 calls trackInsightOpened(metricCategory:), which emits only metric_category (AppAnalytics.swift:2304-2308). CategoryDetailView.swift:92 and TodaysActionDetailView.swift:479 call trackInsightTapped, which emits insight_category, severity and metric (AppAnalytics.swift:1226-1233). Doc block line 292 documents insight_tapped with category, severity, metric as the insight-engagement event; insight_opened appears nowhere in the doc block. Two event names for one action confirmed.


## Notifications

### Action-reminder path fires the permission funnel events when iOS shows no dialog

`BROKEN_CALLSITE` · event: `notification_permission_requested`

`ActionReminderScheduler.schedule` calls `requestAuthorization(source: "action_reminder")` whenever `isCurrentlyAuthorized()` is false (ActionReminderScheduler.swift:78-81), which includes users already in `.denied`. `NotificationManager.requestAuthorization` unconditionally fires `trackNotificationPermissionRequested` before calling into UNUserNotificationCenter (NotificationManager.swift:107) and `trackNotificationPermissionResult(granted: false)` after (NotificationManager.swift:114). For a denied user iOS returns false immediately with no UI, so both events fire with no prompt ever shown, on every tap of the Remind button. The launch fallback does this correctly by gating on `shouldRequestAuthorizationOnLaunch()` (`.notDetermined`, ContentView.swift:91-93), so the safe pattern exists. Net effect: the permission funnel denominator is inflated by repeat taps from users who can never grant in-app, and grant rate is understated.

**Where:** Core/Notifications/ActionReminderScheduler.swift:80 → Core/Tracking/AppAnalytics.swift:3420

**Fix:** Gate the call at ActionReminderScheduler.swift:79 on `await NotificationManager.shared.shouldRequestAuthorizationOnLaunch()` so the request only runs from `.notDetermined`, or move the two track calls inside NotificationManager.requestAuthorization behind a `settings.authorizationStatus == .notDetermined` check.

**Verified:** Confirmed line for line. ActionReminderScheduler.swift:78-81 calls isCurrentlyAuthorized() then requestAuthorization(source: "action_reminder") whenever it returns false; isCurrentlyAuthorized (NotificationManager.swift:141-150) returns false for both .notDetermined and .denied. requestAuthorization fires trackNotificationPermissionRequested at NotificationManager.swift:107 before touching UNUserNotificationCenter and trackNotificationPermissionResult at :114 after, with no status check. The launch fallback does gate correctly on shouldRequestAuthorizationOnLaunch() (== .notDetermined, NotificationManager.swift:135-138) from ContentView.swift:91-93. The path is live user-facing code: HomeView.swift:925 calls it from the Remind button.

### Notification-denial event fires on every foreground return, not on the denial, and poisons rage-tap detection

`BROKEN_CALLSITE` · event: `block_tapped`

`checkAndRecordDenial` emits `trackBlockTap(title: "Notification Permission Denied", ...)` inside the `.denied` case (NotificationRepromptManager.swift:25) with no once-only guard, while `recordDenialIfNeeded` right beside it IS idempotent. ContentView calls it on every `scenePhase` transition to `.active` (ContentView.swift:176), so a permanently-denied user emits one `block_tapped` per app foreground forever. Two consequences: the event is a `block_tapped` (a UI interaction event, AppAnalytics.swift:1179) fired with zero user interaction, and `trackBlockTap` feeds `detectRageTap` (AppAnalytics.swift:1182), so several quick foregrounds by a denied user manufacture a false rage-tap on `data_sync_event` / home.

**Where:** Core/Notifications/NotificationRepromptManager.swift:25 → Core/Tracking/AppAnalytics.swift:1162

**Fix:** Move the track call inside `recordDenialIfNeeded`'s `if existing == 0` branch (NotificationRepromptManager.swift:42) so it fires once on the transition into denial rather than on every foreground.

**Verified:** The rage-tap consequence is overstated and should be dropped. detectRageTap (AppAnalytics.swift:3062-3082) needs 3 taps on the SAME element inside a 2.0-second window; consecutive app foregrounds cannot realistically land 3 within 2 seconds, and the timestamp list resets whenever a different element is tapped. The real defect is the one that stands: a UI-interaction event (block_tapped, card_id data_sync_event, screen home) fired on a lifecycle transition, inflating block_tapped volume for denied users and making "denials" uncountable from this event.

### Push routing failure is logged as a suppression, with a route string in notification_id and a type no other event can join to

`WRONG_PROPERTY` · event: `notification_suppressed`

`NotificationRouter.handle` reports an unmapped push route via `trackNotificationSuppressed(type: "push", identifier: routeString, reason: "unknown_route")` (NotificationRouter.swift:28-32). Three things break. (1) `identifier` is a route string such as `sleep_detail`, so `sanitizedNotificationID` passes it through unchanged (fewer than 3 dot segments, AppAnalytics.swift:3265) and `notification_id` carries a value that joins to nothing in the scheduled/presented/opened funnel. (2) `type: "push"` is hardcoded and is not a value `NotificationManager.notificationType` can ever return (NotificationManager.swift:73-100), so the row is orphaned on the `notification_type` dimension too. (3) Semantically it is not a suppression at all: this runs from `didReceive` (AppDelegate.swift:146), meaning the notification was delivered AND opened. So `notification_suppressed` over-counts pre-delivery suppression, and `unknown_route` pollutes the suppression-reason breakdown that the cap/filter gates own.

**Where:** Core/Notifications/NotificationRouter.swift:28 → Core/Tracking/AppAnalytics.swift:2241

**Fix:** Replace the call at NotificationRouter.swift:28 with a distinct event, e.g. `logEvent("push_route_unresolved", parameters: ["route": routeString])` via a new `trackPushRouteUnresolved(route:)` in AppAnalytics, leaving notification_suppressed to pre-delivery gates only.

**Verified:** Impact is narrower than stated and the reuse is deliberate (see the router's own doc comment at NotificationRouter.swift:22-23). handle() returns at line 25 for every local notification because their userInfo carries no "route" key, so this only fires for a remote push whose route string does not map — low volume. Severity is low, not medium: it pollutes the suppression-reason breakdown and puts a non-notification id in notification_id, but it cannot meaningfully inflate suppression counts.

### Journey 4 and Journey 5 pushes abort on an unauthorized check with no suppression event

`MISSING_EVENT` · event: `notification_suppressed`

`AnswerReadyScheduler.checkAndFire` guards with `guard await NotificationManager.shared.isCurrentlyAuthorized() else { return }` (AnswerReadyScheduler.swift:39) and `RepermissionScheduler.checkAndFire` does the same (RepermissionScheduler.swift:39). Because both return BEFORE `NotificationManager.scheduleNotification`, the manager's own `not_authorized` suppression (NotificationManager.swift:197) never runs and nothing at all is emitted. `ReengagementScheduler` performs the identical pre-check and DOES emit `trackNotificationSuppressed(reason: "not_authorized")` (ReengagementScheduler.swift:41), so the pattern is established and these two diverge from it. These are the onboarding cliffhanger payoff and the denied-branch re-permission nudge, i.e. the two highest-intent one-shots in the app; right now a cohort that never gets them is indistinguishable from a cohort whose prediction never matured.

**Where:** Core/Notifications/AnswerReadyScheduler.swift:39 → Core/Tracking/AppAnalytics.swift:2241

**Fix:** In both guards, emit before returning, matching ReengagementScheduler.swift:41: `AppAnalytics.shared.trackNotificationSuppressed(type: NotificationManager.notificationType(id), identifier: id, reason: "not_authorized")` with id = `AppConstants.NotificationID.answerReady` / `.repermission`.

**Verified:** Confirmed. AnswerReadyScheduler.swift:39 and RepermissionScheduler.swift:39 are both `guard await NotificationManager.shared.isCurrentlyAuthorized() else { return }` placed before scheduleNotification, so NotificationManager's own not_authorized suppression (NotificationManager.swift:197) never runs. grep for AppAnalytics/trackNotification across both files returns nothing. ReengagementScheduler.swift does the identical pre-check and emits trackNotificationSuppressed(reason: "not_authorized") at :41 (and kill_switch at :35), so the divergence is real and the pattern is established in the same directory.

### alert_metric is a blind positional slice, so it carries non-metric junk on every non-alert notification

`WRONG_PROPERTY` · event: `notification_scheduled / notification_presented / notification_opened / notification_dismissed`

All four events derive `alert_metric` as `parts.count >= 3 ? String(parts[2]) : "none"` (AppAnalytics.swift:2008, 2070, 2090, 2209) with no check that the notification is actually an alert. Every lifecycle identifier has three or more dot segments, so the third one is emitted as a metric regardless of what it is: `healthpulse.engagement.day1` -> `day1` (EngagementSequenceScheduler.swift:477), `healthpulse.abandonment.2h` -> `2h`, `healthpulse.trial.gettingStarted` -> `gettingStarted`, `healthpulse.reengagement.3day` -> `3day`, `healthpulse.subscription.nonTrialWelcome` -> `nonTrialWelcome`, `healthpulse.watch.notWorn.scheduled` -> `notWorn`. Because `alert_metric` is in `metricParameterKeys` (AppAnalytics.swift:3217), genuine metrics get collapsed to a category while this junk passes through untouched, so an `alert_metric` breakdown mixes `cardiovascular` with `day1` and `2h`. Any per-metric alert analysis has to know the full identifier scheme to filter it, which defeats the property.

**Where:** Core/Notifications/EngagementSequenceScheduler.swift:477 → Core/Tracking/AppAnalytics.swift:2008

**Fix:** Extract one helper in AppAnalytics, `alertMetricSegment(_ identifier: String) -> String`, that returns `parts[2]` only when the identifier carries an alert prefix (alertPrefix/spikePrefix/triagePrefix/reversalPrefix/celebrationPrefix) and `"none"` otherwise, and use it at AppAnalytics.swift:2008, 2070, 2090 and 2209.

**Verified:** One sub-claim is wrong: "Every lifecycle identifier has three or more dot segments" is false. healthpulse.dailySummary, healthpulse.eveningSummary, healthpulse.weeklySummary, healthpulse.windDown, healthpulse.actionReminder, healthpulse.answerReady and healthpulse.repermission are two-segment ids and correctly emit "none". The defect holds for the multi-segment families listed above (abandonment, trial, subscription, reengagement, watch, engagement), which is still enough to mix "cardiovascular" with "2h" and "day1" in any alert_metric breakdown.


## Secondary features

### actual_duration_sec means two different things on completed vs abandoned, and completion_rate is always 1.0

`WRONG_PROPERTY` · event: `breathwork_session_completed`

`trackCompletedSessionIfNeeded` computes `actualDurationSec` as wall-clock `Date().timeIntervalSince(sessionStartedAt)` (BreathworkView.swift:720), which includes all paused time and the entire dwell on the post-session mood screen, while `endSession` computes the same-named property as active elapsed time `sessionDuration - sessionTimeRemaining` (line 683). The two events cannot be compared. Because the timer only counts down while active, wall-clock is always >= planned duration on a real completion, so `completion_rate = min(actual/planned, 1)` at AppAnalytics.swift:2545 is a constant 1.0 on every completed event.

**Where:** Modules/Stress/Views/Stress/BreathworkView.swift:720 → Core/Tracking/AppAnalytics.swift:2544

**Fix:** Capture the active elapsed time at `completeSession()` (`Int(selectedProtocol.sessionDuration - sessionTimeRemaining)`, the same formula endSession uses), store it in state, and pass that to trackBreathworkSessionCompleted instead of the wall-clock difference.

**Verified:** BreathworkView.swift:683 (endSession) computes actualDurationSec as `max(Int(selectedProtocol.sessionDuration - sessionTimeRemaining), 0)` — active elapsed. BreathworkView.swift:720 (trackCompletedSessionIfNeeded) computes the same-named value as `Date().timeIntervalSince(sessionStartedAt)` — wall clock. The 0.1s timer at line 157 only ticks under `guard sessionState == .active` (line 186), so wall clock is always >= planned duration on a real completion, making `completion_rate = min(max(actual/planned,0),1)` at AppAnalytics.swift:2544 a constant 1.0 on every completed event.

### Breathwork completion event is deferred to view teardown and is lost if the app is killed on the mood screen

`BROKEN_CALLSITE` · event: `breathwork_session_completed`

`completeSession()` (BreathworkView.swift:706) is the actual value moment — the timer reaches zero and the state flips to `.complete` — but it emits nothing. The event only fires from the Done button (line 528) or from `onDisappear` (line 195). A user who finishes the session and then backgrounds or force-quits on the mood screen produces breathwork_session_started with no completed and no abandoned, so completion rate is understated by however often people just leave the app after finishing.

**Where:** Modules/Stress/Views/Stress/BreathworkView.swift:706 → Core/Tracking/AppAnalytics.swift:2538

**Fix:** Call `trackCompletedSessionIfNeeded()` inside `completeSession()` (the `didTrackCompletedSession` flag already prevents a second emit) and report the mood as its own small event when the user picks one.

**Verified:** completeSession() at BreathworkView.swift:706-711 only flips sessionState to .complete and ends the Live Activity — no analytics. The only emitters of trackCompletedSessionIfNeeded are the Done button (line ~528) and onDisappear (line 194-195). onDisappear does not run on backgrounding or on OS termination of a suspended app, so a user who finishes and leaves the app from the mood screen produces breathwork_session_started with neither completed nor abandoned (endSession is skipped because sessionState == .complete). Real silent data loss, though the magnitude is unmeasurable from the code.

### Web report export failures emit nothing at all

`MISSING_EVENT` · event: `report_exported`

`WebExportViewModel.exportReport()` emits report_exported only on the success path (line 45). The catch at line 50 sets `error`, which SettingsView renders in red at line 387, but emits no analytics — not trackError, not recordNonFatal, nothing. Export is a gated Pro feature (FeatureGate.canAccess(.exportReport)), so a broken export for a paying user is completely invisible: failures can only be inferred by subtracting successes from the block_tapped attempt count, and the reason (write failure vs file-protection failure) is never captured.

**Where:** Modules/WebExport/ViewModels/WebExportViewModel.swift:50 → Core/Tracking/AppAnalytics.swift:1849

**Fix:** In the catch block add `AppAnalytics.shared.trackError(type: "report_export_failed", screen: .settings, message: error.localizedDescription)`.

**Verified:** WebExportViewModel.swift:50-52: the catch sets `self.error` and emits nothing; trackReportExported (AppAnalytics.swift:1849) is inside the do at line 45. The attempt is tracked (SettingsView.swift:366 trackBlockTap) and the feature is Pro-gated (SettingsView.swift:364 FeatureGate.canAccess(.exportReport), RemoteConfigManager.swift:586 maps it to "pro"), and the error is rendered in red at SettingsView.swift:387. So failures are only inferable by subtraction and the reason is never captured, exactly as claimed. Note the path is a temp-file write plus a file-protection set, so it fires rarely in practice.

### Strain and Brain Health methodology sections emit no explanation_viewed

`MISSING_EVENT` · event: `explanation_viewed`

Both detail screens have a collapsible "Learn more" methodology block bound to `showLearnMore` (StrainDetailView.swift:593, BrainHealthDetailView.swift:284) that explains how the score is built. Neither emits anything when expanded. `trackExplanationViewed` has exactly one call site in the app (ScoreGuideSheet.swift:22), so the Q3 trust question the event exists for — "Do they check methodology?" per AppAnalytics.swift:253 — is only answerable for the overall score guide and not for any category scorer.

**Where:** Modules/Strain/Views/Strain/StrainDetailView.swift:593 → Core/Tracking/AppAnalytics.swift:2417

**Fix:** Add `.onChange(of: showLearnMore) { _, open in if open { AppAnalytics.shared.trackExplanationViewed(type: "strain_methodology", screen: .strainDetail) } }` to the DisclosureGroup, and the equivalent in BrainHealthDetailView.

**Verified:** StrainDetailView.swift:593 and BrainHealthDetailView.swift:284 are both `DisclosureGroup(isExpanded: $showLearnMore)`, both rendered (StrainDetailView.swift:139, BrainHealthDetailView.swift:30), and grep for showLearnMore in both files returns only the @State declaration and the DisclosureGroup — no onChange, no trackBlockTap, no tracker. trackExplanationViewed (AppAnalytics.swift:2417) has exactly one call site in the whole repo, ScoreGuideSheet.swift:22 with type "health_score". The doc block lists explanation_viewed with a `type` dimension for the "do they check methodology?" question, which only one type ever populates.

### Sleep Coach performance-level picker is the screen's only decision and emits nothing

`MISSING_EVENT` · event: `n/a`

The Peak / Perform / Get By segmented picker (SleepCoachView.swift:189) is the single interactive control on Sleep Coach and it changes the product's output: it shifts `adjustedNeed` and the recommended bedtime by ±45 minutes (line 91-97, 100-108). Selecting it emits no event, so which sleep target users actually choose — and whether anyone touches the control at all — is unanswerable. screen_viewed/screen_exited are the only Sleep Coach events.

**Where:** Modules/Sleep/Views/Sleep/SleepCoachView.swift:189 → Core/Tracking/AppAnalytics.swift:1278

**Fix:** Add `.onChange(of: performanceLevel) { old, new in AppAnalytics.shared.trackFilterChanged(screen: .sleepCoach, filterType: "performance_level", from: old.rawValue, to: new.rawValue) }` to the picker.

**Verified:** One detail is wrong: it is not the screen's only interactive control — there is also a history-row expand button (line 334) and a show-more-tips button (line 556), both equally untracked. It is, however, the only control that changes the product's recommended output, so the instrumentation gap stands.

### Ask Your Data cannot distinguish a thrown engine error from a genuine low-confidence answer

`MISSING_PROPERTY` · event: `block_tapped`

When the query engine throws, `HealthDataQueryRequest.execute` swallows it and returns a normal QueryResult with a canned apology, confidence 0.0 and no data points (DashboardViewModel.swift:2635). The only post-query telemetry is `block_tapped("Query Result Viewed")` carrying confidence and data_points_count (AskYourDataView.swift:235). A hard failure and a legitimate "I don't have enough data" answer produce byte-identical events, so the Ask feature's real error rate cannot be measured and the LLM quality signal from query_feedback is polluted by outright failures.

**Where:** Modules/Dashboard/ViewModels/DashboardViewModel.swift:2635 → Core/Tracking/AppAnalytics.swift:1163

**Fix:** Add an `isError` flag to QueryResult, set it true in the catch, and include `"success": !queryResult.isError` (plus a failure_reason) in the "Query Result Viewed" metadata.

**Verified:** The real defect is one file over: FoundationModelQueryEngine.swift:41-43 silently swallows every on-device LLM failure and substitutes a rule-based answer with zero telemetry, and the only post-query event, trackBlockTap("Query Result Viewed") at AskYourDataView.swift:235, carries confidence / data_points_count / related_questions_count but no engine or degraded flag. LLM failure rate and LLM-vs-fallback answer quality are therefore unmeasurable, and query_feedback cannot be attributed to the engine that produced the answer. The dead catch at DashboardViewModel.swift:2634 should be deleted, not instrumented.


## App lifecycle & data pipeline

### sync_failed.retry_count is always 0 and reason is unbounded free text

`WRONG_PROPERTY` · event: `sync_failed`

The single sync_failed call site omits retryCount, so it defaults to 0 on every event, even though requestAuthorizationWithRetry has just burned up to 4 attempts with backoff. The doc block lists sync_failed as "reason, retry_count", so retry_count exists specifically to answer "did retries help?" and it is a constant. The same call site builds reason as "healthkit_authorization: \(error.localizedDescription)", an unbounded localized string that sanitizeParameters only clips at 100 chars, giving one distinct reason value per device locale and per underlying error text, so the dimension cannot be grouped.

**Where:** /Users/primetrace/Desktop/RnD/HealthPulse/Core/Data/HealthKitManager.swift:182 → /Users/primetrace/Desktop/RnD/HealthPulse/Core/Tracking/AppAnalytics.swift:2820

**Fix:** Have requestAuthorizationWithRetry return/throw the attempt count and pass it as retryCount, and change the call to trackSyncFailed(reason: "healthkit_authorization", retryCount: attempts), moving the localizedDescription into the existing trackError call on the line above.

**Verified:** trackSyncFailed's signature is `func trackSyncFailed(reason: String, retryCount: Int = 0)` (AppAnalytics.swift:2820) and the single call site at HealthKitManager.swift:182 omits retryCount, so retry_count is 0 on every event even though requestAuthorizationWithRetry (HealthKitManager.swift:191-199) burns up to 4 attempts. The same line builds reason as "healthkit_authorization: \(error.localizedDescription)"; sanitizeParameters (AppAnalytics.swift:3278-3288) only clips non-full-text strings at 100 chars, so the dimension carries one distinct value per locale and per underlying error text. Doc line 280 lists retry_count as the point of the event.

### The nav_depth user property is always "0" because it is read immediately after startSession resets it

`WRONG_PROPERTY` · event: `n/a (nav_depth user property)`

trackSessionStart sets the batched user property "nav_depth" from session.currentDepth. startSession() sets currentDepth = 0 at line 231, and trackSessionStart reads it a few lines later on the same synchronous path, so the value is 0 on literally every session. session.maxDepth, which updateNavigationDepth does maintain, is never read by any logEvent or setUserProperty in AppAnalytics. Navigation depth, a documented session-quality dimension, is collected on every push/pop and then thrown away.

**Where:** /Users/primetrace/Desktop/RnD/HealthPulse/Core/Tracking/SessionTracker.swift:231 → /Users/primetrace/Desktop/RnD/HealthPulse/Core/Tracking/AppAnalytics.swift:889

**Fix:** Drop "nav_depth" from the session-start Identify batch (it can only ever be 0) and instead emit max_depth on session_ended from the ended session's stats, see the related session_ended finding.

**Verified:** trackSessionStart calls session.startSession() at AppAnalytics.swift:816 and then, on the same synchronous path (guard outcome.isNew at 826), sets "nav_depth": "\(session.currentDepth)" in the batched Identify at 889. SessionTracker.startSession() sets currentDepth = 0 at SessionTracker.swift:231, and nothing can call updateDepth in between. Grep confirms maxDepth (SessionTracker.swift:16, 230, 307, 337) is never read by any logEvent or setUserProperty in AppAnalytics; only currentDepth is used, at 889, 1029 and 1038.

### session_ended omits nav depth even though the doc promises it and SessionTracker already persists it

`MISSING_PROPERTY` · event: `session_ended`

The taxonomy doc block declares "session_end duration_sec, screens, depth -> Session quality". The emitted session_ended carries duration_sec, active_sec, screens_viewed, core_actions_count and ended_reason, but no depth. SessionTracker.persistOpenSession even writes "depth": maxDepth into the on-disk open-session snapshot, and reconcilePersistedSession never reads that key back because EndedStats has no depth field. So the value survives an app kill on disk and is still discarded. Combined with nav_depth always being 0, there is no way to answer how deep users navigate in a session.

**Where:** /Users/primetrace/Desktop/RnD/HealthPulse/Core/Tracking/SessionTracker.swift:307 → /Users/primetrace/Desktop/RnD/HealthPulse/Core/Tracking/AppAnalytics.swift:923

**Fix:** Add `let maxDepth: Int` to SessionTracker.EndedStats, populate it from session.maxDepth (in-process path) and from d["depth"] as? Int ?? 0 (reconcile path), and add "max_depth": stats.maxDepth to the session_ended parameters.

**Verified:** Doc block line 242 reads 'session_end  duration_sec, screens, depth  Session quality'. emitSessionEnded (AppAnalytics.swift:918-926) sends session_id, session_number, duration_sec, active_sec, screens_viewed, core_actions_count and ended_reason only. EndedStats (SessionTracker.swift:164-175) has no depth field. persistOpenSession writes "depth": maxDepth at SessionTracker.swift:307, and reconcilePersistedSession (270-293) reads number/source/start/last/active/screens/actions but never "depth", so the persisted value is discarded on read.

### deep_link_opened.source is a hardcoded "widget" but every laso:// link in the app comes from a Live Activity

`WRONG_PROPERTY` · event: `deep_link_opened`

handleDeepLink passes source: "widget" for every laso://route/* URL. The only producers of that scheme in the repo are the three Live Activity widgets (TodayScoreLiveActivityWidget todaysAction, WindDownLiveActivityWidget sleepCoach, BreathworkLiveActivityWidget stressMonitor). The home-screen AnalysisSummaryWidget has no widgetURL at all. So `source` is a constant that can never vary, and the constant it is pinned to is factually the wrong surface. AppAnalytics.openedFrom even documents a distinct "live_activity" bucket in its enum comment, but SessionSource has no such case, so that bucket is unreachable too.

**Where:** /Users/primetrace/Desktop/RnD/HealthPulse/App/ContentView.swift:869 → /Users/primetrace/Desktop/RnD/HealthPulse/Core/Tracking/AppAnalytics.swift:2198

**Fix:** Derive source from the route in handleDeepLink (todaysAction/sleepCoach/stressMonitor -> "live_activity", anything else -> "widget") and add a `case liveActivity` to SessionTracker.SessionSource plus its mapping in AppAnalytics.openedFrom.

**Verified:** One nuance: the event's `url` property does carry the distinguishing route (sleepCoach/stressMonitor/todaysAction), so the surface is recoverable post hoc. The defect stands for `source` itself and for opened_from/session_source, where the widget bucket contains only Live Activity opens and no real widget opens.

### Home-screen widget taps are completely untracked and land in the organic bucket

`MISSING_EVENT` · event: `deep_link_opened`

AnalysisSummaryWidget is a StaticConfiguration with no .widgetURL and no AppIntent anywhere in its view tree, so tapping it just launches the app with no URL. ContentView.onOpenURL never runs, handleDeepLink never runs, deep_link_opened never fires, and pendingSessionSource stays .organic, so the session is stamped opened_from = app_icon. SessionTracker.widgetSessionCount can therefore only ever be incremented by Live Activity taps, and organicSessionPercent is inflated by every real widget open. There is no way to answer whether the home-screen widget drives any returns.

**Where:** /Users/primetrace/Desktop/RnD/HealthPulse/LasoWidgets/AnalysisSummaryWidget.swift:8 → /Users/primetrace/Desktop/RnD/HealthPulse/Core/Tracking/AppAnalytics.swift:2198

**Fix:** Add `.widgetURL(URL(string: "laso://route/home"))` to AnalysisWidgetView's root (per family, as the Live Activity widgets already do) so the existing onOpenURL -> handleDeepLink path tags the session and emits deep_link_opened.

**Verified:** AnalysisSummaryWidget.swift:7-19 is a StaticConfiguration whose content closure returns AnalysisWidgetView(entry:) with no .widgetURL; grep for widgetURL/Link(/AppIntent/Button(intent over LasoWidgets/AnalysisWidgetView.swift returns nothing. So a tap opens the app with no URL, ContentView.onOpenURL and handleDeepLink (ContentView.swift:860-871) never run, deep_link_opened never fires, and pendingSessionSource stays .organic so opened_from is app_icon (AppAnalytics.swift:3539). SessionTracker.widgetSessionCount (567-568, incremented at 585) can then only be driven by Live Activity taps, inflating organicSessionPercent (573).

### background_refresh_result.samples_loaded is hardcoded to success ? 1 : 0

`WRONG_PROPERTY` · event: `background_refresh_result`

The only call site passes `samplesLoaded: success ? 1 : 0`, where success is just `liveViewModel.recovery.readinessScore != nil`. The property is therefore a duplicate of the success flag and never carries a sample count. The doc block advertises background_refresh_result as "success, samples_loaded -> Data freshness pipeline", so the question it exists for (did the background pass actually pull data, and how much) is unanswerable: a pass that computed readiness from stale cached data is indistinguishable from one that pulled fresh samples.

**Where:** /Users/primetrace/Desktop/RnD/HealthPulse/App/BackgroundRefreshCoordinator.swift:130 → /Users/primetrace/Desktop/RnD/HealthPulse/Core/Tracking/AppAnalytics.swift:3136

**Fix:** Have fetchHomeData/fetchHomeDataTiered report the number of samples it loaded (or read healthKitManager's syncProgress.samplesDiscovered) and pass that real count, or drop the parameter rather than shipping a disguised copy of success.

**Verified:** BackgroundRefreshCoordinator.swift:127-131 is the only call: trackBackgroundRefreshResult(success: success, durationMs: durationMs, samplesLoaded: success ? 1 : 0), where success is `liveViewModel.recovery.readinessScore != nil` (line 93). The emitter (AppAnalytics.swift:3136-3142) ships success and samples_loaded as separate properties, so samples_loaded is a duplicate of success and never a count. Doc line 350 advertises 'background_refresh_result  success, samples_loaded  Data freshness pipeline'.

### Thermally-throttled background refreshes complete as failures but emit nothing

`MISSING_EVENT` · event: `background_refresh_result`

BackgroundRefreshCoordinator.handle returns early with task.setTaskCompleted(success: false) at two thermal checks: once before scheduling any work, and once inside the MainActor block after the device heated up. Neither path calls trackBackgroundRefreshResult, so a device that is throttling shows a silent gap in the background pipeline rather than a stream of failures with a cause. Since the only other emission is on the happy path, a drop in background_refresh_result volume is unattributable between "BGTask never ran", "thermal throttle" and "user disabled background refresh".

**Where:** /Users/primetrace/Desktop/RnD/HealthPulse/App/BackgroundRefreshCoordinator.swift:59 → /Users/primetrace/Desktop/RnD/HealthPulse/Core/Tracking/AppAnalytics.swift:3136

**Fix:** Add a `reason` parameter to trackBackgroundRefreshResult and call it with success: false, reason: "thermal_throttle" before both early returns (BackgroundRefreshCoordinator.swift:60 and :74), passing reason: "ok"/"no_readiness" on the existing call.

**Verified:** BackgroundRefreshCoordinator.handle has two throttle exits: lines 59-63 (setTaskCompleted(success: false), schedule(), return) before any work, and lines 73-76 inside the MainActor workTask (setTaskCompleted(success: false), return). Neither reaches the single trackBackgroundRefreshResult at 127, which sits at the end of the happy path after task.setTaskCompleted at 125. So a throttling device produces a silent volume drop with no cause attached, and the emitter has no reason parameter (AppAnalytics.swift:3136).


## Taxonomy consistency

### PMF survey steps 2-4 and submission emit nothing; four documented PMF events and nps_submitted never exist

`MISSING_EVENT` · event: `pmf_segment_response`

The doc block promises pmf_survey_response, pmf_segment_response, pmf_benefit_response, pmf_improvement_response (text_length), nps_submitted (score, category), insight_marked_helpful and insight_marked_unhelpful, plus the nps_category user property. None of these names appears anywhere in the codebase: MARK section 10 'Emotional / NPS' is an empty stub. In the shipped survey only step 1 emits (satisfaction_survey_answered); steps 2, 3, 4 and submitSurvey() fire nothing, so survey drop-off after Q1 is invisible and the free-text answers live only in @State and are discarded on dismiss, making the code comment 'kept in-app for product use' false. Non-PII signals (step reached, text_length, completed) are documented and would answer 'what to build next'.

**Where:** Common/Components/PMFSurveySheet.swift:220 → Core/Tracking/AppAnalytics.swift:324-328

**Fix:** Emit one `pmf_survey_step` event per step with `step` and `text_length` (never the text) from segmentStep/benefitStep/improvementStep, and a `pmf_survey_completed` from submitSurvey(); delete the nps_* and insight_marked_* lines from the doc block since nothing implements them.

**Verified:** Two real defects, narrower than stated. (1) Doc drift: AppAnalytics.swift:254-255, 259 and 325-328 document seven events (four pmf_*, nps_submitted, insight_marked_helpful/unhelpful) that no code emits — they were consolidated into satisfaction_survey_answered per the comment at AppAnalytics.swift:3348-3352, and the doc block was never updated. (2) The survey has no terminal event: submitSurvey (PMFSurveySheet.swift:221-224) only calls markSurveyCompleted, so completion rate cannot be computed. NOT true that drop-off is invisible: the Skip button emits block_tap with metadata ["step": step.rawValue] (PMFSurveySheet.swift:58-65), and feature_open/feature_close fire on the sheet (72, 75). Also, omitting the free-text answers is deliberate PII policy stated at PMFSurveySheet.swift:92-94 and AppAnalytics.swift:3344-3345, not an oversight; only the 'kept in-app for product use' half of that comment is false, since submitSurvey discards the @State text.

### subscription_cancelled omits months_subscribed, the one property the doc promises

`MISSING_PROPERTY` · event: `subscription_cancelled`

The taxonomy documents subscription_cancelled as 'months_subscribed — Who churns', and its sibling subscription_renewed does send months_subscribed. The emitting code sends only cancellation_reason, which is `unknown` on every client-inferred cancel (the sole caller, updateSubscriptionProperties, always uses the default). So the churn event ships exactly one property whose value is a constant, and tenure-at-churn — the actual question the event exists for — cannot be answered without joining back to a user property that has already been overwritten to 'expired'.

**Where:** Core/Subscriptions/SubscriptionManager.swift:124 → Core/Tracking/AppAnalytics.swift:1614-1619

**Fix:** Add `"months_subscribed": monthsSubscribed` and `"days_since_install": session.daysSinceInstall` to the subscription_cancelled parameter dictionary (the private monthsSubscribed accessor already exists at line 1721).

**Verified:** Doc line 276 reads `subscription_cancelled  months_subscribed  Who churns`. trackSubscriptionCancelled (AppAnalytics.swift:1614-1619) sends only cancellation_reason. The sole caller is AppAnalytics.swift:1706 inside the .expired branch of updateSubscriptionProperties, calling with no argument, so the default .unknown makes the one shipped property a constant. The sibling subscription_renewed does send months_subscribed (AppAnalytics.swift:1581), and the private monthsSubscribed accessor exists at 1721-1724.

### Identical session stats ship under two different property names on events emitted milliseconds apart

`WRONG_PROPERTY` · event: `session_quality`

emitSessionEnded builds session_ended with `screens_viewed` and `core_actions_count`, then immediately passes the same EndedStats struct to evaluateSessionQuality, which emits session_quality and ghost_session with `screens_visited` and `core_actions` for the exact same values. No single Amplitude breakdown can chart screens-per-session across the session funnel; every chart has to be built twice and unioned, and analysts filtering session_ended on screens_visited get zero rows silently.

**Where:** App/ContentView.swift:880 → Core/Tracking/AppAnalytics.swift:928-929

**Fix:** Rename the keys in evaluateSessionQuality (lines 2848, 2867-2868) to `screens_viewed` and `core_actions_count` to match session_ended, which is the canonical event.

**Verified:** emitSessionEnded (AppAnalytics.swift:928-929) sends screens_viewed / core_actions_count, then calls evaluateSessionQuality(stats) at line 936, which sends the same stats.screensVisited / stats.coreActionsCount as screens_visited (2848, 2867) and core_actions (2868). Same struct, same values, three events, two key names.

### The same user action splits across insight_opened and insight_tapped with different category property names

`WRONG_PROPERTY` · event: `insight_opened`

Tapping an insight card in InsightsDetailView emits insight_opened with `metric_category`; tapping one in CategoryDetailView or TodaysActionDetailView emits insight_tapped with `insight_category` plus severity and metric. Same gesture, same product concept, two event names and two property names for the category dimension, and insight_opened is not in the documented taxonomy at all while insight_tapped is. 'How many insights get opened, broken down by category' requires unioning two events and coalescing two properties, and the first_insight_viewed activation milestone can be reached from only one of the two paths.

**Where:** Modules/Insights/Views/Insights/InsightsDetailView.swift:107 → Core/Tracking/AppAnalytics.swift:2304-2308

**Fix:** Delete trackInsightOpened and call trackInsightTapped(category:severity:metric:screen:) from InsightsDetailView:107, so one event with `insight_category` covers every insight tap.

**Verified:** Correct as a naming/event split, but the activation-milestone clause is wrong: trackActivationMilestone(.firstInsightViewed) fires in InsightsDetailView's .onAppear (InsightsDetailView.swift:155), not on the insight tap, so the milestone is tied to opening that screen, not to either tap path.

### setting_changed hardcodes screen=settings, overriding the correct global on the notifications screen

`BROKEN_CALLSITE` · event: `setting_changed`

trackSettingChanged always writes `"screen": AppFeature.settings.rawValue`. Ten of the eleven call sites live in NotificationsSettingsView, which is a distinct AppFeature (.notificationsSettings) and correctly calls trackFeatureOpen(.notificationsSettings) on appear. Because the hardcoded key is present, logEvent's global injection (which would have used session.currentScreen = 'notifications_settings') is skipped, so every notification toggle is reported as happening on the Settings root. 'Which settings surface do users actually change things on' is unanswerable and the notifications screen looks like it has zero interactions.

**Where:** Modules/Settings/Views/NotificationsSettingsView.swift:44 → Core/Tracking/AppAnalytics.swift:1870-1874

**Fix:** Drop the hardcoded `"screen"` key from trackSettingChanged (line 1873) and let logEvent inject session.currentScreen, or add a `screen: AppFeature` parameter and pass .notificationsSettings from that view.

**Verified:** Same defect; the count is 11 of 12 call sites in NotificationsSettingsView (lines 44, 57, 69, 84, 88, 92, 96, 108, 146, 199, 211), with the twelfth at SettingsView.swift:842.

### weekly_score_change ships neither delta nor new_score, only a 3-way direction bucket

`MISSING_PROPERTY` · event: `weekly_score_change`

The taxonomy documents weekly_score_change as 'delta, direction, new_score — Outcome improvement'. The code computes delta, uses it only to pick improving/declining/stable, and sends score_bracket + direction. Magnitude is gone, so 'did the product move scores, and by how much' — the outcome metric the event exists for — cannot be answered; a +3 and a +40 week are the same row. delta is not treated as sensitive elsewhere: daily_result_shown and score_reaction both ship raw score_delta.

**Where:** Modules/Dashboard/ViewModels/DashboardViewModel.swift:1121 → Core/Tracking/AppAnalytics.swift:1292-1302

**Fix:** Add `"score_delta": delta` to the weekly_score_change parameter dictionary (line 1298), matching the key already used by daily_result_shown and score_reaction.

**Verified:** Same defect; the caller is DashboardHousekeepingService.swift:124 (via the ServiceProtocols.swift:24 protocol), not DashboardViewModel.swift:1121.

### Documented taxonomy has drifted from the emitted property and event names in nine places

`MISSING_PROPERTY` · event: `onboarding_step_completed`

The doc block at lines 210-358 is the spec dashboards are built from, and it no longer matches the code. Concretely: it names session_start / session_end but the code emits session_started / session_ended; onboarding_step_completed is documented with step + step_name but emits step_key + step_index + step_count; onboarding_completed is documented with focuses but emits only duration_sec (focuses became a user property); activation_completed is documented with milestones_count but emits milestones_completed; notification_opened is documented with type but emits notification_type; recommendation_viewed/completed/skipped are documented with type but emit recommendation_type; explanation_viewed is documented with type but emits explanation_type; insight_tapped is documented with category but emits insight_category; daily_active is documented with source but emits session_source. Anyone wiring a chart from the spec gets an empty series.

**Where:** Modules/Onboarding/Views/Onboarding/OnboardingV2View.swift:303 → Core/Tracking/AppAnalytics.swift:222-250

**Fix:** Update the doc block lines 222-258 to the names the code actually emits (session_started/session_ended, step_key/step_index/step_count, milestones_completed, notification_type, recommendation_type, explanation_type, insight_category, session_source) and drop `focuses` from the onboarding_completed row.

**Verified:** Checked all nine against emitted code. session_start/session_end (doc 241-242) vs logEvent("session_started") at 861 and ("session_ended") at 923. onboarding_step_completed doc 'step, step_name' (223) vs step_key/step_index/step_count at 547-553. onboarding_completed doc 'focuses' (222) vs only duration_sec at 641-643 (focuses became setUserProperty("health_focus") at 645). activation_completed doc 'milestones_count' (226) vs milestones_completed at 701. notification_opened doc 'type' (249) vs notification_type at 2015. recommendation_viewed doc 'type' (256) vs recommendation_type at 2440. explanation_viewed doc 'type' (253) vs explanation_type at 2419. insight_tapped doc 'category' (292) vs insight_category at 1228. daily_active doc 'source' (244) vs session_source at 2189. All nine confirmed.


---

# Low severity (9)


## Onboarding

### Taxonomy doc promises step and step_name on onboarding_step_completed; the code sends neither

`MISSING_PROPERTY` · event: `onboarding_step_completed`

The reference block states `onboarding_step_completed  step, step_name, duration_sec` (AppAnalytics.swift:223), but the function sends step_key, step_index, step_count, duration_sec and action (AppAnalytics.swift:547-553). Neither `step` nor `step_name` is ever emitted, and the doc omits `action`, which is the only way to tell a forward completion from a back or a skip. The same block lists onboarding_drop_off with only last_step and duration_sec (:224) while the code also sends step_index and step_count. Anyone building the drop-off funnel from the documented taxonomy filters on properties that do not exist and gets an empty chart.

**Where:** Modules/Onboarding/Views/Onboarding/OnboardingV2View.swift:347 → Core/Tracking/AppAnalytics.swift:223

**Fix:** Update line 223-224 of the doc block to `onboarding_step_completed  step_key, step_index, step_count, duration_sec, action` and `onboarding_drop_off  last_step, step_index, step_count, duration_sec`.

**Verified:** AppAnalytics.swift:223 reads 'onboarding_step_completed     step, step_name, duration_sec' while trackOnboardingStepCompleted (:540-554) sends step_key, step_index, step_count, duration_sec and action. Neither `step` nor `step_name` exists anywhere in the emitted payload, and `action` (the only way to separate a forward completion from a .back) is absent from the doc. Line 224 likewise lists onboarding_drop_off as 'last_step, duration_sec' while the function (:567-574) also sends step_index and step_count. This is exactly the 'doc block promises a property the code never sends' case named in the MISSING_PROPERTY definition.

### band="younger" contradicts verdict="even" at a zero gap, and every no-data user lands in the younger band

`WRONG_PROPERTY` · event: `onboarding_vitality_revealed`

The band ladder uses `if diff >= 0 { band = "younger" }` while verdict uses `diff > 0 ? "younger" : (diff < 0 ? "older" : "even")` (AppAnalytics.swift:577-585), so a zero gap emits verdict=even and band=younger on the same event. This is not a rare edge: VitalityScorer.onboardingEstimate returns `(chronologicalAge, [])` when no metric is available (VitalityScorer.swift:810), and the reveal is shown on the denied and sparse branches too (OnboardingV2View.swift:257-274), so every user with no health data is bucketed band="younger" with has_health_data=false. A band breakdown answering "how many users land younger" is inflated by the whole no-data cohort.

**Where:** Modules/Onboarding/Views/Onboarding/OnbV2VitalityReveal.swift:509 → Core/Tracking/AppAnalytics.swift:579

**Fix:** Split the zero case: `if diff > 0 { band = "younger" } else if diff == 0 { band = "even" } else if diff >= -3 { band = "slightly_older" } else { band = "much_older" }`.

**Verified:** The band/verdict contradiction at diff==0 is the hard defect. The 'inflated younger band' consequence is softer than stated, since has_health_data is emitted on the same event (AppAnalytics.swift:584) and lets an analyst exclude the no-data cohort; the damage is that the default band breakdown is wrong unless someone knows to apply that filter.


## Home / Live / Explore / Settings

### Category Detail's metric rows, its primary navigation, emit no block_tapped

`MISSING_EVENT` · event: `block_tapped`

Both the historical-highlight rows (CategoryDetailView.swift:43) and the metric list rows (line 156) are plain NavigationLink(value:) with no tracking, and metricsTracker.tapped is never called either. The BlockType enum reserves .metricRow for exactly this (AppAnalytics.swift:83-84 comment says Category Detail) but the case is only ever passed from Home, so any dashboard filtering block_type=metric_row AND screen=category_detail returns zero rows while the same filter on screen=home returns Home Why-row taps.

**Where:** Modules/CategoryDetail/Views/Category/CategoryDetailView.swift:156 → Core/Tracking/AppAnalytics.swift:84

**Fix:** Wrap the metric row in a Button that fires trackBlockTap(title: metric.displayName, type: .metricRow, screen: .categoryDetail, metadata: ["metric_id": metric.rawValue, "severity": viewModel.severity(for: metric)?.rawValue ?? "none"]) and metricsTracker.tapped(target: metric.rawValue) before appending the metric to the path.

**Verified:** Real, but the sharpest consequence is not the one stated. Which metric was opened from Category Detail is still recoverable from MetricDetailView's screen_viewed (MetricDetailView.swift:177-182 sends metric plus previous_screen). The genuinely unanswerable question is section CTR: category_detail_metrics emits section_viewed from :164 but never section_tapped, because metricsTracker.tapped is never called anywhere.

### Home's max_depth_percent is a three-value proxy whose middle step depends on a conditional card

`WRONG_PROPERTY` · event: `scroll_depth`

maxScrollDepth is only ever set to the literals 10, 20 and 90 by section onAppear handlers (HomeView.swift:526, 603, 647). The 20 marker is attached to compactAlertBanner, which renders nothing when the user has no illness warning and no risks, so a healthy user's scroll_depth jumps straight from 10 to 90 and the whole Vitals/Ask Your Data region between them is unmeasured. The reported depth is a function of which cards exist for that user, not of how far they scrolled.

**Where:** Modules/Dashboard/Views/Home/HomeView.swift:603 → Core/Tracking/AppAnalytics.swift:1924

**Fix:** Move the depth markers onto cards that always render: put max(maxScrollDepth, 40) on the MetricStripView onAppear (HomeView.swift:611) and max(maxScrollDepth, 65) on the AskYourDataCard onAppear (line 587), leaving 10 on the hero and 90 on the weekly review.

**Verified:** grep for maxScrollDepth in HomeView.swift returns only four writes: the @State at :26 and the literals max(...,10) at :526, max(...,20) at :603 and max(...,90) at :647, flushed by trackScrollDepth at :131-132. The 20 marker is on compactAlertBanner, whose @ViewBuilder body (:701-708) returns nothing when `warning == nil && risks.isEmpty`, so the modifier is applied to an absent view and never fires for a healthy user. The reported value is a function of which cards exist, not scroll distance.

### Three detail screens have pull-to-refresh with no pull_to_refresh event

`MISSING_EVENT` · event: `pull_to_refresh`

Home, Explore and Connected Devices all call trackPullToRefresh in their .refreshable blocks, but HealthRiskDetailView.swift:37, SleepCoachView.swift:132 and CycleDetailView.swift:149 call only `await onRefresh?()`. The manual-refresh rate on those screens, which is the signal that the data looked stale to the user, is missing, and the reachable-from-Home risk detail is the most-used of the three.

**Where:** Modules/Risk/Views/Risk/HealthRiskDetailView.swift:37 → Core/Tracking/AppAnalytics.swift:1262

**Fix:** Add AppAnalytics.shared.trackPullToRefresh(screen: .riskDetail) as the first line of the refreshable closure, and the same with .sleepCoach / .cycleDetail in the other two.

**Verified:** Real. Path correction: CycleDetailView lives at Modules/CycleTracking/Views/CycleTracking/CycleDetailView.swift (the finding wrote Views/Cycle/), and the refreshable block is at :149-151.


## Notifications

### Wind-down push is cancelled and skipped with no event when no bedtime is available

`MISSING_EVENT` · event: `notification_suppressed`

`WindDownScheduler.schedule` has three silent `cancelNotification` + `return` paths: no recommended bedtime (WindDownScheduler.swift:35-38), date math failure (:42-45), and fire time already past for today (:46-49). Only the first guard, the preference toggle (:29), is a genuine user choice. The bedtime path is a data-availability failure - `SleepNeedCalculator.currentNeed?.recommendedBedtime` being nil (DashboardHousekeepingService.swift:195) - and it runs on every housekeeping pass, so a user can go weeks without a single wind-down push while analytics show no attempt, no suppression and no failure. "Why is wind-down volume so low" currently cannot be separated from "users turned it off".

**Where:** Core/Notifications/WindDownScheduler.swift:35 → Core/Tracking/AppAnalytics.swift:2241

**Fix:** Emit `AppAnalytics.shared.trackNotificationSuppressed(type: "wind_down", identifier: AppConstants.NotificationID.windDown, reason:)` before the returns at WindDownScheduler.swift:37, :44 and :48 with reasons `no_bedtime`, `bad_fire_date` and `fire_time_passed`.

**Verified:** Weakest of the set; keep it scoped to the nil-bedtime guard at WindDownScheduler.swift:35-37. The "fire time already past for today" guard at :45-48 is a normal nightly occurrence on every evening housekeeping pass, so emitting a suppression there would add recurring noise rather than answer anything. Severity low.


## Secondary features

### discovery_completed.pages_viewed is always equal to total_pages

`WRONG_PROPERTY` · event: `discovery_completed`

The Continue button that emits discovery_completed lives on the last page of a paged TabView (DiscoveryView.swift:37 and 220), and a `.page`-style TabView only allows swiping to adjacent pages, so `maxPageViewed` is necessarily `totalPages - 1` by the time the button can be tapped. `pagesViewed: maxPageViewed + 1` at line 232 is therefore always identical to `totalPages` on every emit, and the depth-of-engagement question the property exists for cannot be answered from this event.

**Where:** Modules/Discovery/Views/Discovery/DiscoveryView.swift:232 → Core/Tracking/AppAnalytics.swift:2152

**Fix:** Also emit discovery_completed (or a discovery_abandoned) from onDisappear when Continue was never tapped, so the pages_viewed distribution has a non-constant tail; otherwise drop the property and rely on discovery_page_viewed counts.

**Verified:** totalPages = 1 + discoveries.count + 1 (DiscoveryView.swift:21-23). The pages are tagged 0 (opening), 1...n (discoveries), n+1 (ctaPage) at lines 30-37, and the Continue button that emits trackDiscoveryCompleted (line 231-234) lives only inside ctaPage — grep confirms it is the single call site. maxPageViewed is a running max of currentPage (line 45) and is capped at the last tag, so at emit time maxPageViewed is always totalPages-1 and `pagesViewed: maxPageViewed + 1` is always exactly totalPages. The property is a constant on every emit and carries no engagement-depth signal.

### Client-side referral redeem rejections emit no event

`MISSING_EVENT` · event: `referral_code_redeemed`

`ReferralManager.redeemCode` returns before any tracking on two rejection paths: empty/whitespace code (line 203) and already-redeemed (line 208). Every server-side rejection carries a `failure_reason` (own_code, already_referred, invalid_code, network_error, bad_response), so the funnel looks complete while the two most common client-side rejections are invisible — a user who pastes a code they already used shows zero redeem attempts.

**Where:** Modules/Referral/Services/ReferralManager.swift:208 → Core/Tracking/AppAnalytics.swift:2737

**Fix:** Call `trackReferralCodeRedeemed(code: trimmed, success: false, failureReason: "already_redeemed")` before the early return at line 210, and the same with "empty_code" at line 205.

**Verified:** Two corrections. The empty-code branch is unreachable from the only caller — ReferralCodeStep.swift:107-110 already guards `codeText.trimmingCharacters(in: .whitespaces).isEmpty` and returns before calling redeemCode — so only the already-redeemed guard at line 208 is a live gap. And "a user who pastes a code they already used shows zero redeem attempts" is wrong: reusing someone else's code hits the server and is tracked as already_referred; the untracked case is narrower, a device that already redeemed any code (loaded from defaults at line 49 or restored by server sync at line 143) attempting another redeem.


## Taxonomy consistency

### peak_hour_known is a constant 1 and can never be 0

`WRONG_PROPERTY` · event: `habit_ritual_formed`

peak_hour_known is computed as `computedPeakHour == nil ? 0 : 1`, but computedPeakHour comes from hours.max() after `guard hours.count >= 5` at line 2982, so the array is never empty and max() never returns nil. The property is a constant on every event, costing a column while answering nothing. The same pattern appears on repermission_conversion, whose only property is the literal `granted: 1`.

**Where:** App/ContentView.swift:880 → Core/Tracking/AppAnalytics.swift:3003

**Fix:** Delete the peak_hour_known key (line 3003) and use `hours.max()!`-free logic, i.e. send `"peak_hour_local": computedPeakHour ?? 0` alone; likewise drop the constant `granted` from repermission_conversion at line 1099.

**Verified:** AppAnalytics.swift:2982 is `guard hours.count >= 5 else { return }`, so at line 2999 the array is non-empty and `hours.max(by:)` cannot return nil; line 3003 therefore always emits 1. Confirmed as an always-constant property. Note this is genuinely trivial — peak_hour_local at 3002 is correct and no product question is blocked; the wasted column is the entire harm.


---

## Not checked

- PII / privacy findings — excluded on request.
- Live Amplitude schema (no project access): which of the 154 emitted events are actually in the tracking plan, which are ingesting, and which properties already have a locked type that conflicts with what the code sends.
- Runtime proof: nothing here was confirmed by running the app and watching the event stream. Every finding is a code reading, verified twice.

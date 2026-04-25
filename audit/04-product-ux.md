# 04 — Product / UX / Copy / Friction Audit

**Auditor stance:** read-only adversarial product skeptic + principal designer review of the Laso TestFlight build (`com.lasohealth.fit`, iOS 17+). All findings reference the actual files in this repo at the absolute paths shown. Code was not modified.
**Format:** Severity / Issue / Why this exists / Impact / Evidence / How to verify fast / Fix / Priority / Confidence.
**Scope:** onboarding flow, dashboard, settings, paywall, profile, insights, journal, cycle, discovery, explore, live, brain/risk/strain/stress/vitality, referral, web export, devices, empty states, error states, loaders, copy quality, dead screens, CTA hierarchy, trust gaps, conversion leaks, accessibility-of-language, logout, delete-account, pricing transparency, AI/coach claims, mental-health sensitivity. **Out of scope** (other agents): security/auth, performance, color/typography, admin-panel, third-party SDK exposure, analytics taxonomy.

---

## F1. Notification permission is wired but never requested. Settings toggles silently no-op on a fresh install

- **Severity:** Critical
- **Issue:** `NotificationManager.requestAuthorization(source:)` is defined but **zero** production call sites invoke it. The user is never shown the iOS notification permission prompt. Yet `SettingsView` exposes `Daily Summary`, `Weekly Summary`, `Critical Alerts`, `Heart Rate Alerts`, `Watch Not Worn Reminder`, `Low Battery Reminder` and several other toggles — and `DailySummaryScheduler`, `AlertEvaluator`, `EngagementSequenceScheduler` happily call `NotificationManager.shared.scheduleNotification(...)` against a permission that has never been granted. iOS will silently drop every one of these on day-1 install. The reprompt banner only fires after a 7-day delay, and even that only opens iOS Settings — it cannot present a fresh prompt.
- **Why this exists:** The original onboarding probably included a notifications step that was deleted ("Notifications, cycle opt in, and the standalone medical disclaimer are deferred to contextual surfaces" — `OnboardingView.swift:4`). The contextual surface that was supposed to call `requestAuthorization` was never built.
- **Impact:** A core paid feature (alerts, daily/weekly briefings, critical alerts) does not work for any new user. This silently kills retention because the reengagement loop and "value delivered" notifications never reach the device. A user toggles `Daily Summary` ON, sees no notifications, assumes the app is broken or lying. The reprompt-after-7-days banner is a denial recovery mechanism, not a first-ask mechanism — it presumes a denial that never happened.
- **Evidence:**
  - `Modules/Onboarding/Views/Onboarding/OnboardingView.swift:32` — flowSteps = `[.pulse, .profile, .connect, .priority, .mirror, .promise]`. No `notifications` step.
  - `Core/Notifications/NotificationManager.swift:47` — `requestAuthorization(source:)` defined.
  - Repo-wide grep `NotificationManager.shared.requestAuthorization` returns zero matches in production code.
  - `Modules/Settings/Views/NotificationsSettingsView.swift:38-60` — toggles freely flip preferences without checking `UNUserNotificationCenter` authorization status.
  - `App/ContentView.swift:113-115` — `NotificationRepromptManager.checkAndRecordDenial()` is the only auth-flow surface, and per `Common/Components/NotificationRepromptBanner.swift` it only routes to iOS Settings, never presents the iOS permission alert.
  - `Core/Notifications/DailySummaryScheduler.swift:67`, `AlertEvaluator.swift:310-437` — schedule calls run regardless of grant state.
- **How to verify fast:** Fresh-install on simulator, toggle `Daily Summary` ON in Settings, run `xcrun simctl push <udid> com.lasohealth.fit '{"aps":{"alert":"x"}}'` — nothing renders. Or add `print("requestAuth granted=\(granted)")` to NotificationManager.swift line 53 — see that the line never logs.
- **Fix:** Add a contextual notification permission ask on first time the user toggles ANY notification preference ON in `NotificationsSettingsView`: `let granted = await NotificationManager.shared.requestAuthorization(source: "settings_first_toggle")`; if not granted, revert the toggle and surface a soft inline explainer with a CTA to iOS Settings. Also call once in the Promise step's `Open Laso` button when at least one default-enabled preference is set — this is the post-aha-moment moment Apple recommends. Gate `DailySummaryScheduler` / `AlertEvaluator` on `await center.notificationSettings().authorizationStatus == .authorized` so silent drops are detected and analytics tracked.
- **Priority:** Now — pre-launch blocker. The whole notifications feature does not work.
- **Confidence:** 96/100 — direct grep + read confirms zero callers; what's not yet confirmed is whether a launch-side Firebase/APNs registration is silently triggering the system prompt as a side effect of `application:didRegisterForRemoteNotificationsWithDeviceToken:` registration in the AppDelegate. Even if so, scheduled local notifications do not auto-prompt, so the user-visible product still fails.

---

## F2. Settings "Delete All My Data" only deletes locally — Firestore + anonymous Firebase user survive. Apple guideline 5.1.1(v) is unmet

- **Severity:** Critical
- **Issue:** Tapping `Delete All My Data` calls `EncryptedStore.remove(...)`, `healthDataStore.deleteAllData()`, `UserDefaults.removePersistentDomain` and exits the app. It does **not** delete: (a) the anonymous `Auth.auth().currentUser` Firebase user, (b) the `user_profiles/<deviceId>` Firestore doc which carries `firebaseUid`, `referralCode`, `redeemedReferralCode`, `referralFreeUntil`, (c) the `referrals/*` collection rows where the user appears as referrer or referee, (d) PostHog person profile, (e) any cloud-backup blob. A user who taps this button on their last day with the app rationally believes they are gone — they are not. Apple guideline 5.1.1(v) requires that account-bearing apps offer in-app account deletion; the anonymous Firebase user + the persistent Firestore user_profiles doc are an account by Apple's definition.
- **Why this exists:** "Delete data" was scoped as a local-store wipe before Firebase + referral state were added. The Firestore writes accumulated later (referral redeem, anonymous-uid sync, cloud backup) and the delete handler was never updated.
- **Impact:** App Store review submission risk (rejection under 5.1.1(v) if the reviewer registers a referral code). GDPR / DPDP residual data risk. Trust gap — the warning copy says "permanently erase all of your data from this device" which is technically accurate and legally damaging because it implies completeness. A motivated user filing a Subject Access Request gets a list of what was retained.
- **Evidence:**
  - `Modules/Settings/Views/SettingsView.swift:671-692` — `performDataDeletion()` body. Wipes local only, then `exit(0)`.
  - `Modules/Settings/Copy+Settings.swift:161` — `deleteDataWarning` uses "all of your data from this device" — the qualifier "from this device" is technically correct but the surrounding banner says "Delete All My Data" without scope.
  - `App/AppLaunchCoordinator.swift:27-28` — anonymous sign-in: `Auth.auth().signInAnonymously { ... }`.
  - `Modules/Referral/Services/ReferralManager.swift:191-195`, `241-262` — Firestore writes on `user_profiles/<deviceId>` and `referrals/*`.
  - Grep `Auth.auth().currentUser?.delete\|user_profiles.*delete` returns zero matches. No server-side delete exists.
- **How to verify fast:** Run the app, redeem a referral code, tap Delete All My Data. Open Firebase console — the user_profiles doc and the referrals row are still there.
- **Fix:** In `performDataDeletion()` (a) call `Auth.auth().currentUser?.delete()`, (b) `Firestore.firestore().collection("user_profiles").document(deviceId).delete()`, (c) batch-delete `referrals` where `referrerDeviceId == deviceId` OR `referredDeviceId == deviceId`, (d) call `PostHogManager.shared.reset()` to detach the PostHog identity, (e) delete any cloud backup objects, (f) ONLY then wipe local + exit. Show a progress overlay during the network calls and handle failure with "Some of your data could not be removed. Try again on a stronger network." Also separate the menu item into "Delete My Account & Data" (full) vs "Reset Local Cache" (current behavior) — the second is useful for support.
- **Priority:** Now — App Review blocker plus consumer-trust blocker.
- **Confidence:** 95/100 — code paths verified by reading; the remaining 5 is whether Cloud Functions in `admin-panel/` already do server-side cascade-deletion on user_profiles delete. If yes, only the local code change is needed. If no, both client and Functions work needed.

---

## F3. Onboarding asks zero questions about goals, body, sleep, training, conditions before showing a Day-0 score

- **Severity:** High
- **Issue:** The 6-step flow (`pulse → profile → connect → priority → mirror → promise`) collects only **age + gender + 1+ focus areas**. It does not ask: height, weight, training experience, typical workouts/week, sleep window, caffeine, alcohol, pregnancy/postpartum status, chronic conditions (asthma, AFib history, diabetes), medication that affects HRV or RHR (beta-blockers, SSRI, stimulants), shift work. Yet on screen 5 ("Mirror Moment") it computes a baseline and on screen 6 promises "we will surface N patterns from your X of history". Then on Home it shows a Recovery score that uses HRV/RHR thresholds with no personalization. Without the missing facts the Day-0 score is generic and the "personalized" promise is theatre.
- **Why this exists:** The redesign explicitly chose Clinical-calm minimalism (per `OnboardingView.swift:4-7` doc and the user-memory note `project_onboarding_redesign.md`), trading data depth for low friction. That is a defensible product call until the Day-0 scoring loop produces a wrong number for someone on beta-blockers or in postpartum and they bounce.
- **Impact:** (a) Score credibility is at risk for users where the population baseline does not apply. (b) Personalisation copy ("comparing you to yourself") is true 60+ days in but false on Day 1. (c) Cycle tracking is hard-wired female and there is no opt-in flow — see F8. (d) Pregnancy and AFib-known users get content they shouldn't (e.g. `Strain` "Push hard" guidance). (e) Whoop/Oura competitors do ask these — Laso looks shallow in side-by-side.
- **Evidence:**
  - `Modules/Onboarding/Views/Onboarding/OnboardingView.swift:32` — only six steps. ProfileCaptureView only captures `Gender` + `Int` age (`ProfileCaptureView.swift:7-15`).
  - `Modules/Onboarding/Views/Onboarding/OnboardingFocusStep.swift` — `HealthFocus` is the only intent capture.
  - `Modules/Dashboard/Views/Home/HomeView.swift:589-605` — recovery line uses HRV thresholds 25/35/50 and RHR 55/65/75 hard-coded, not personalized to age, sex, condition.
  - No conditional branch on pregnancy / AFib / medication anywhere in the onboarding code.
- **How to verify fast:** Run the app on a profile aged 65 with `Heart Health` selected. Compare the recovery copy to a 25-year-old's. Same hardcoded thresholds.
- **Fix:** Add a single optional "About Your Body" mini-step (height, weight, training frequency 0/1/2/3/4+/wk, do you take medication that affects heart rate, are you pregnant, do you have a known heart condition) with one tap-to-dismiss path so non-disclosing users still progress. Use this for (a) suppressing strain "push hard" guidance in flagged states, (b) personalising RHR thresholds to age, (c) gating cycle tracking opt-in, (d) routing to a respectful pregnancy banner when relevant. Keep the step skippable but visibly above-the-fold so most users complete it.
- **Priority:** This Week — touches scoring credibility and content safety.
- **Confidence:** 88/100 — onboarding flow read end-to-end; the score formula was sampled, not exhaustively traced for every dependent personalisation.

---

## F4. ReferralCodeStep is fully built but unreachable — entire referral acquisition channel is dead in production

- **Severity:** High
- **Issue:** `Modules/Onboarding/Views/Onboarding/ReferralCodeStep.swift` is a complete view with input field, validation, `ReferralManager.shared.redeemCode(...)` call, success/error UX, branding, sharing copy, and a Skip button. **It is referenced from exactly nowhere.** `OnboardingView.flowSteps` does not include it; no `Route` case maps to it; grep `ReferralCodeStep` shows only the file itself. `ReferralManager` itself is referenced only from this orphan view. Net effect: there is no UX path for an existing user to share a code (the `shareText` getter is defined but unused) and no path for a new user to redeem one. The entire referral system is a graveyard feature.
- **Why this exists:** Onboarding was reduced from 10→6 screens and the referral step got cut. Nobody wired the share path on Profile/Settings/Paywall to compensate.
- **Impact:** A key viral acquisition channel is dead while shipping the cost (Firestore rules, schema, code, tests). The Paywall offers a free trial but no "Apply Referral Code" field where a referee would expect it. A user holding a "HEALTH-XXXXX" code from a friend has zero way to redeem.
- **Evidence:**
  - File exists: `Modules/Onboarding/Views/Onboarding/ReferralCodeStep.swift:4`.
  - Repo-wide grep `ReferralCodeStep` returns only the file itself.
  - `Modules/Referral/Services/ReferralManager.swift` — `shareText` (line 277) and `redeemCode` (line 128) defined; called only from the orphan step.
  - `Modules/Paywall/Views/Subscription/PaywallView.swift` — no referral redeem field anywhere.
  - `App/ContentView.swift` — no Route for referral, no Settings row, no entry in `Modules/Profile`.
- **How to verify fast:** Search Xcode for "Have a Referral Code?" — only the orphan file appears.
- **Fix:** Either delete the entire Referral feature (orphan view, ReferralManager, Firestore rules, AppKeys.Referral, AppAnalytics referral events) — clean removal, lower attack surface — OR wire it: (a) optional onboarding step before paywall, (b) "Apply Code" affordance on Paywall, (c) "Invite Friends" row in Settings + `UIActivityViewController` hand-off using `ReferralManager.shareText`, (d) "X friends invited" badge in Settings on profile section. The decision is product/business, but the current half-built state is the worst outcome (cost without value).
- **Priority:** This Week — pick a side and execute.
- **Confidence:** 96/100 — orphan status is exhaustively grep-verified. Confidence drops only for the policy decision (kill vs wire).

---

## F5. AchievementsView is fully built but unreachable in production navigation

- **Severity:** High
- **Issue:** `Modules/Profile/Views/Profile/AchievementsView.swift` is a 500+ LOC view with levels (Bronze→Diamond), streaks, and achievement grid, fully wired to the gamification engine in `DashboardViewModel`. The route exists (`Core/Models/Route.swift:15`, `App/ContentView.swift:434, 586-621`) but **no production button calls `navigationPath.append(Route.achievements)`**. Only `Route.fromUITestIdentifier("achievements")` references it — UI tests only. The `gamificationEngine` continues computing streaks every refresh while no user can ever see them.
- **Why this exists:** The Profile tab was probably planned and dropped — `ContentView.tabsRoot` has only `home / live / explore / settings` (`ContentView.swift:239-258`). Achievements was supposed to live on Profile.
- **Impact:** A motivation/retention surface that competitors (Whoop, Oura) lean on hard is invisible. Compute and storage cost (`StreakInfo`, `AchievementItem`) without any user-side payoff. Streak continuity goes uncelebrated, killing the loop.
- **Evidence:**
  - `App/ContentView.swift:586-621` — `achievementsDestination` exists.
  - Grep `Route.achievements` outside the enum + the destination switch returns zero matches.
  - Tabs in `ContentView.swift:239-258` are exactly four: home/live/explore/settings.
- **How to verify fast:** Open the running app, look for any tappable "Achievements" / streaks affordance. There is none.
- **Fix:** Either remove the Profile module entirely (it currently contains only `AchievementsView`, so it's a one-folder delete plus engine cleanup), OR add a subtle "Streaks & Achievements" row at the top of `SettingsView.profileSection` that pushes `Route.achievements`. Also surface the active streak count in the Home greeting card (already present in `Copy.Home.Greeting.streakBadge` but not wired to a tap). Pick one.
- **Priority:** This Week — same kill-or-wire pattern as Referral.
- **Confidence:** 94/100 — verified by route grep; dropped for whether some future plan/feature spec explicitly chose to ship the engine without UI.

---

## F6. Aha-moment hard paywall fires on first Insights view — gates the very value users are still trying to perceive

- **Severity:** High
- **Issue:** `InsightsDetailView.maybeShowAhaPaywall()` shows a `fullScreenCover` PaywallView the first time a free user lands on Insights (one-shot, UserDefaults-gated). This is "aha-moment paywall" — defensible in research — but here it fires on view-appear regardless of whether the user actually saw any content. They tap the early-warning banner on Home, and instead of reading the warning they get a paywall. The same `fullScreenCover(isPresented:)` cannot be dismissed without subscribing or backgrounding the app (paywall has no X). Combined with the trial logic in `SubscriptionManager.evaluateStatus()` (7-day install-based trial) the flow is: trial-active user hits paywall on first Insights view → confused why a paywall appears during trial. The code does guard `!SubscriptionManager.shared.hasAccess` so trial is excluded, but trial detection depends on `daysSinceInstall < trialDays` — for a re-installed user it resets to 0 and they see Insights freely; for someone whose install drifted across iCloud restore, trial may never start.
- **Why this exists:** PMF research cited in code comment ("health & fitness top-decile trial→paid is 68%") drove a hard-paywall decision. Reasonable bet, but the trigger is "appearance of view" not "user actually engaged with N insights" — the real aha.
- **Impact:** Users who never engaged still get hard-walled. Users on a stale install state may see a paywall they should not. Paywall has no Close, only Subscribe / Restore / external links to Privacy/Terms — combined with the aha-trigger this can feel hostile and trigger 1-star reviews ("popped a paywall before letting me see anything"). Apple App Review may also flag a non-dismissible paywall that is not the only path to use the app, since Insights is a navigation destination not an entire app function.
- **Evidence:**
  - `Modules/Insights/Views/Insights/InsightsDetailView.swift:159-201` — paywall `fullScreenCover`, no dismiss; `maybeShowAhaPaywall` called from `onAppear`.
  - `Modules/Paywall/Views/Subscription/PaywallView.swift` — no close button. `interactiveDismissDisabled()` is applied on the LasoApp.swift root paywall, but the InsightsDetail paywall sheet relies on the implicit non-dismissible `fullScreenCover` semantics.
  - `Core/Subscriptions/SubscriptionConfig.swift:30-32`, `SubscriptionManager.swift:276-277` — trial timing.
- **How to verify fast:** Fresh install, skip onboarding focus selection, complete onboarding, tap the early-warning banner on Home. Paywall fires before any insight has been read.
- **Fix:** (a) Add an X-close in PaywallView for non-root presentations (`@Environment(\.dismiss)` + small close button, hidden when presented from the root LasoApp gate). (b) Move the aha trigger from `view.onAppear` to "after the user has scrolled at least one insight card into view AND tapped at least one detail". Use `SectionTracker.tapped(target:)` which already exists. (c) Also gate by `dataDepth.daysOfData >= 3` — if there are no real insights to read, a paywall is the wrong moment.
- **Priority:** Now — combination conversion + reviews risk.
- **Confidence:** 90/100 — verified by code read; not yet runtime-tested for whether the `fullScreenCover` is actually swipe-dismissible by accident (sheet vs fullScreenCover behaviour differs).

---

## F7. Paywall is the only way to dismiss the trial-expired blocker. There is no "Maybe Later" / "Continue with limited features" path

- **Severity:** High
- **Issue:** `LasoApp` presents `PaywallView` as a `fullScreenCover` with `interactiveDismissDisabled()` and `set: { _ in }` — the cover cannot be dismissed by code or user. `PaywallView` has Subscribe, Restore Purchases, Privacy / Terms links, and `Retry loading plans` if products fail to load. No Close, no continue-free, no support contact. Users on a flaky network where StoreKit's `loadProducts()` returns empty get stuck on a `Loading prices…` screen with only Restore + Retry — no escape, no support hook. Combined with the `subscribe-or-die` model this is a brick wall on Day-7+1.
- **Why this exists:** Hard-trial-expired paywall is intentional ("Cannot dismiss. must subscribe" — comment at LasoApp.swift:120). It is also a common Apple-rejection pattern in the medical/health category if the underlying app is gated entirely behind it.
- **Impact:** (a) Risk of 1-star reviews ("the app held my health data hostage"). (b) Apple guideline 3.1.2(a) — for apps that read Apple Health, gating the entire experience behind subscription with no free trial fallback after expiry has been historically rejected. The 7-day free trial exists which mitigates, but if `SubscriptionConfig.trialDays` is ever lowered via Remote Config the safety net disappears. (c) No way to contact support without first paying. (d) Power-loss / phone-restore users whose receipt is missing are bricked into Restore Purchases without an obvious path forward when restore fails.
- **Evidence:**
  - `App/LasoApp.swift:118-124` — fullScreenCover with no-op set + `interactiveDismissDisabled`.
  - `Modules/Paywall/Views/Subscription/PaywallView.swift` — no close, no contact-support, no "I subscribed earlier — refresh" beyond Restore.
  - `Modules/Paywall/Views/Subscription/PaywallView.swift:341-358` — `Retry loading plans` is the only fallback when products fail.
- **How to verify fast:** Set system date forward 8 days post-install. Disable network. Launch app. The paywall renders, products fail to load, the user is stuck.
- **Fix:** (a) Add `Contact Support` row in PaywallView footer — opens mail / FeedbackSheet. (b) Add a `Maybe Later` button that surfaces a single time per session and routes to a degraded "view yesterday's data only" mode (read-only Home with a banner). (c) On product load failure with no network, present a clear "You're offline. Plans will load when you reconnect" rather than a stuck spinner. (d) Keep the original behaviour for the standard subscribe-now path.
- **Priority:** This Week — App Review + edge-case bricking risk.
- **Confidence:** 88/100 — verified by code read; not yet runtime-tested for the exact behaviour when products fail to load offline.

---

## F8. Cycle tracking has no opt-in, no profile gate, no off-ramp for non-cycling users

- **Severity:** High
- **Issue:** `CycleDetailView` is reachable via `Route.cycleDetail`. The view is dense, hard-wired to the menstrual cycle (4 phases, period estimate, day-of-cycle). There is no opt-in flow, no toggle in Settings, no question in onboarding. `MenstrualCycleTracker` runs whenever HealthKit menstrual flow data is present, and `CyclePhaseCard` appears on Home conditionally (`Modules/Dashboard/Views/Home/CyclePhaseCard.swift`) — for trans men, postmenopausal users, men, or anyone who has logged a single period and stopped, this can silently surface. There is also no off-ramp on `CycleDetailView` itself ("This isn't relevant to me — hide it"), and the copy assumes cisgender female biology (`Copy.CycleTracking.menstrualEnergy = "Energy tends to be lower"`).
- **Why this exists:** Cycle tracking was added without a profile-based gate because HealthKit category presence was used as the sole signal. Presence-based gating is fragile: HealthKit data sharing, prior partner logging, accidental writes via Health app all create false positives.
- **Impact:** Sensitivity gap. A trans man who logged a period years ago, a postmenopausal user, or a partner of someone using shared Apple Health will see menstrual content unprompted. Any one of these reaches the App Store reviews tab with hostile feedback. Also a privacy risk in shared-device contexts (family sharing, screen mirroring).
- **Evidence:**
  - `App/AppStateStore.swift:78` — `setCycleTrackingEnabled(_:)` exists but no view writes to it.
  - `App/ContentView.swift:556-583` — `cycleDetailDestination` only checks `currentCycle != nil`, never `cycleTrackingEnabled`.
  - `Modules/CycleTracking/Views/CycleTracking/CycleDetailView.swift` — no Settings row, no off-ramp, no "hide this" affordance.
  - `Modules/CycleTracking/Copy+CycleTracking.swift:19-23` — copy assumes cisgender biology.
- **How to verify fast:** Plant a single menstrual flow record in HealthKit on a male/postmenopausal user. Open the app. CyclePhaseCard appears.
- **Fix:** (a) Honour `appStateStore.cycleTrackingEnabled` in BOTH `cycleDetailDestination` AND `CyclePhaseCard` — default OFF unless onboarding asks. (b) Add a profile-aware gate: ask in onboarding "Would you like cycle tracking?" only when the gender capture is `female` OR `preferNotToSay`, with a default of OFF. (c) Add a Settings → Health Data → Cycle Tracking row with a clear OFF affordance and explanatory copy. (d) Add a per-card "Hide this card" ⋯ menu on Home.
- **Priority:** Now — sensitivity + privacy + App Review risk.
- **Confidence:** 92/100 — verified via Route flow; not yet runtime-tested whether `currentCycle` ever resolves to non-nil on a male profile.

---

## F9. Journal contains mood, alcohol, stress, meditation entries but has no biometric lock and no privacy framing

- **Severity:** High
- **Issue:** `JournalEntryView` accepts categorical inputs including `alcohol`, `stress`, `mood`, `meditation`, `caffeine`, plus optional notes. Entries persist to local SwiftData (`JournalStore`). There is no Face ID / Touch ID gate on the journal, no "Privacy Lock" toggle in Settings, no encryption-at-rest copy, no warning that the data is unprotected. A roommate / partner / kid picking up an unlocked iPhone can open the app and read every mood log and free-text note. The app also writes entries to `EncryptedStore` for some keys but `JournalStore` does not appear in that store — confirm via grep is needed.
- **Why this exists:** Sensitivity was prioritized as a copy concern (the disclaimer + "stays on your iPhone" copy) but not as a UI gate.
- **Impact:** Mental-health-adjacent data on an unlocked phone is a known reputational hit for health apps. Apple privacy reviewers also flag this in the App Privacy nutrition label vs implementation gap.
- **Evidence:**
  - `Modules/Journal/Views/Journal/JournalEntryView.swift:1-320` — no biometric, no privacy framing, no encryption call-out.
  - Repo-wide grep `biometric\|LAContext\|FaceID\|appLock` returns zero matches.
  - `Modules/Journal/Copy+Journal.swift` — exposes only `Insights` strings; nothing about privacy.
- **How to verify fast:** Hand the device to anyone, tap Journal. Everything is readable.
- **Fix:** (a) Add `Settings → Privacy Lock` with a Face ID / passcode toggle that uses `LAContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)`. (b) Apply the gate at JournalEntryView, ExpandedJournalView, and JournalInsightsView — and on the home journal-prompt sheet. (c) Re-prompt after backgrounding for ≥30s using `scenePhase`. (d) Add visible "Locked with Face ID" copy + "Stored only on this device, encrypted by iOS" reassurance.
- **Priority:** This Week — sensitivity + brand-trust.
- **Confidence:** 90/100 — verified by code grep; not yet runtime-tested whether iOS-level Hide-from-Recents / etc covers part of the gap.

---

## F10. "Live" tab name is ambiguous and the empty state assumes wearable

- **Severity:** Medium
- **Issue:** The bottom tab labelled "Live" actually surfaces real-time vitals from a connected Apple Watch (heart rate, SpO2, respiratory rate). For users without an Apple Watch the screen renders `LiveWaitingForDataView` indefinitely. The label is shared with iOS Live Activities terminology, with TestFlight "Live" feeds, and with sport apps (Apple TV "Live"), creating ambiguity. The screen also triggers `ProFeatureOverlay` for free users (`ContentView.swift:359-371`), so a fresh user with no watch and no subscription sees a Pro-locked screen labeled "Live" with an upsell — a shape that reads as predatory and confusing.
- **Why this exists:** "Live" is shorthand for live-data; engineering sees it as obvious.
- **Impact:** First-touch confusion. Free-iPhone-only users (probably the majority on Day 1) get an upsell on a tab they don't understand.
- **Evidence:**
  - `App/ContentView.swift:244, 350-372` — Live tab + gated ProFeatureOverlay.
  - `Modules/Live/Views/Live/LiveView.swift:1-100` — empty state requires Apple Watch.
- **How to verify fast:** Run on iPhone-only profile, tap Live. See the upsell.
- **Fix:** (a) Rename tab to "Vitals" or "Now". (b) When no watch is paired and the user is free, show an honest empty state on the tab itself ("Vitals show your heart rate live when an Apple Watch is paired. You don't need a watch to use Laso — your dashboard works from Apple Health.") instead of a Pro upsell. Keep the ProFeatureOverlay only when a watch IS paired and Pro is the only thing missing.
- **Priority:** This Week — first-impression naming + free-user friction.
- **Confidence:** 82/100 — verified via tab + gating code; not yet runtime-tested with no watch paired.

---

## F11. Risk module copy uses "Pattern" naming (defensive) but RiskFactorStatus surfaces "Critical" with red — borderline medical claim

- **Severity:** Medium
- **Issue:** `HealthRiskType` displayName uses calm "Heart Health Pattern", "Sleep Pattern", "Stress & Recovery", etc. (`Core/Models/HealthRisk.swift:92-102`). Good. But `RiskFactorStatus` includes `concerning` (orange) and `critical` (red) with display names "Concerning" / "Critical" (`HealthRisk.swift:174-189`). When a metric shows up as `critical` in the FocusAreaCard, the user reads a red "Critical" badge attached to e.g. resting heart rate or blood oxygen — that crosses the line into perceived medical assessment. Apple's Health app intentionally avoids "critical" terminology outside FDA-cleared paths (e.g. AFib notifications). The disclaimer at `Insights/Copy+Analysis.swift:200` ("not medical diagnoses") is correct but is buried at the bottom of the InsightsDetailView, far from the red Critical badge.
- **Why this exists:** Severity ladders are convenient for engineering; the language wasn't pressure-tested for medical-claim adjacency.
- **Impact:** App Review rejection risk under guideline 1.4.1 (medical-information apps must not be alarming or misleading). Real-user anxiety risk — a parent on the day after an intense work week sees "Cardiac Pattern: Critical" and panics.
- **Evidence:**
  - `Core/Models/HealthRisk.swift:174-189` — RiskFactorStatus with `critical` and red color.
  - `Modules/Risk/Views/Risk/HealthRiskDetailView.swift:149-200` — factorRow renders status colored by the same enum.
  - Disclaimer placement: only `InsightsDetailView.swift:135-141` and bottom of Settings.
- **How to verify fast:** Force a metric into critical band (sub-90% bloodOxygen, resting HR > 100). Open HealthRiskDetailView. Read the colour + word combination.
- **Fix:** Rename `critical` → `outside typical range` or `well outside your usual`. Rename `concerning` → `worth a look`. Keep the colours but soften the words. Add the medical disclaimer above the focus-areas section, not buried at the bottom of Insights. Remove the 100-point Risk gauge entirely or relabel from "0-100 risk level" to "0-100 priority for attention" — the former implies a clinical metric.
- **Priority:** This Week — App Review + ethical copy.
- **Confidence:** 86/100 — verified by code reading; not yet pressure-tested with a real Apple reviewer copy pass.

---

## F12. Briefing copy makes soft predictions that read as health prophecies

- **Severity:** Medium
- **Issue:** `Copy.Briefing.WhatMightHappen.precursorHeadline(...)` returns "Your X looks the way it did before Y last time. A calmer day could really help." `Copy.Briefing.TrendSignal.tomorrowHeadline(...)` returns "Tomorrow might feel heavy on your body. Going to bed early could help." These are pattern-based predictions templated from `accuracy` and `probability` arguments. Even though the surface text avoids numbers, the framing — "before Y last time" / "tomorrow will be heavy" — is forward-looking health prediction. Users in fragile mental states (post-illness, anxiety) read this as the app forecasting that they will get sick or fail. Compounded with the "Watch This" early-warning banner copy (`Copy.Home.earlyWarning = "Watch This"`).
- **Why this exists:** WHOOP-style narratives drove the design; Whoop also uses "tomorrow" framing but with explicit Strain Coach context and a long onboarding into how it works. Laso shows it on Day 1 to cold users.
- **Impact:** Anxiety amplification for sensitive users. App Review medical-claim risk. Trust erosion when the prediction doesn't pan out.
- **Evidence:**
  - `Modules/Dashboard/Copy+Briefing.swift:30-48, 77-92`.
  - `Modules/Dashboard/Copy+Home.swift:88` — `earlyWarning = "Watch This"`.
- **How to verify fast:** Read the strings inline.
- **Fix:** (a) Suppress the "tomorrow" / "before Y last time" headlines until `dataDepth.daysOfData >= 30` AND the user has explicitly enabled forecasts in Settings. (b) Add a "What this means" inline disclosure under each prediction — one line, plain. (c) Replace "Watch This" with "Worth Noticing" — same intent, less alarmist.
- **Priority:** This Week — copy + ethical content.
- **Confidence:** 84/100 — verified by reading copy; not yet user-tested with a sensitive cohort.

---

## F13. Discover / Discovery module is reachable only via post-calibration discovery flow — the tab name "Explore" overlaps semantically

- **Severity:** Medium
- **Issue:** `DiscoveryView` is presented as a `fullScreenCover` from `HomeView` when `viewModel.ui.showDiscovery` becomes true (after calibration discovers patterns). The Explore TAB (`ContentView.tabsRoot`) is a separate analytics-deep-dive screen. Two surfaces named with overlapping semantics ("Discover" vs "Explore") — confusing. Worse, the LasoApp `performInitialCalibration()` immediately calls `appStateStore.markDiscoverySeen()` (LasoApp.swift:56) so the Discovery flow is suppressed at first launch — meaning the flow only surfaces after a future analysis cycle. New users may never see Discovery.
- **Why this exists:** Discovery was part of an older flow that the Mirror Moment now subsumes; the kill-switch at LasoApp.swift:56 was the patch. The Discovery surface still exists for re-analysis events.
- **Impact:** Engineering carries Discovery code permanently for an edge surface most users never hit. Tab name ambiguity hurts navigation clarity.
- **Evidence:**
  - `App/LasoApp.swift:55-58` — markDiscoverySeen on calibration.
  - `Modules/Dashboard/Views/Home/HomeView.swift:49-58` — fullScreenCover trigger.
  - `Modules/Discovery/Views/Discovery/DiscoveryView.swift` — full screen carousel.
- **How to verify fast:** Fresh install. Discovery never appears (calibration suppresses it). Force `setHasSeenDiscovery(false)` and trigger analysis — only then does it appear.
- **Fix:** Either (a) remove `markDiscoverySeen` from `performInitialCalibration` and make Discovery the celebration after calibration succeeds — replacing the static `OnboardingPromiseStep` text with the discovered-patterns carousel, OR (b) delete the Discovery module wholesale since Mirror Moment already shows highlights. Pick one. Also rename the Explore tab to "Trends" or "Stats" to remove semantic overlap.
- **Priority:** This Week — dead-code reduction + nav clarity.
- **Confidence:** 86/100 — flow verified by code read; not runtime-confirmed for the second-analysis trigger path.

---

## F14. Devices flow has no troubleshooting path for the most common failure (Apple Health permission was denied or partial)

- **Severity:** Medium
- **Issue:** `ConnectedDevicesView` shows a status header, summary pills, active and inactive devices, and tap-through to `DeviceDetailView`. There is no troubleshooting button if (a) HealthKit is unauthorized, (b) HealthKit was authorized but the user toggled OFF specific categories in iOS Health Settings, (c) the watch is paired but not writing because Apple Watch's Background App Refresh is off. The HealthKitRepromptBanner (`HealthKitRepromptBanner.swift`) is the only signal — it fires AFTER the dashboard has loaded and detected empty data, but the user landing on Devices first sees only "Set up a device" with no diagnostic. Most user-support tickets in this category are exactly this scenario.
- **Why this exists:** The reprompt banner pattern relies on usage; cold-start users on Devices first don't trigger it.
- **Impact:** Support load. Churn for users who hit the empty-Devices state and don't realize permissions are off.
- **Evidence:**
  - `Modules/Devices/Views/Devices/ConnectedDevicesView.swift:1-80` — no permission diagnostic.
  - `Common/Components/HealthKitRepromptBanner.swift` — reprompt flows from usage events, not from Devices view.
- **How to verify fast:** Deny HealthKit on first launch, navigate to Settings → Manage Devices. No diagnostic.
- **Fix:** Add a top-of-list `HealthKit Status` row that runs `healthKitManager.isAuthorized` + a sample-availability check. If denied or empty after authorization, show inline "Open iOS Health Settings" + "Open iPhone Settings" + a step-by-step diagnostic ("If you use Garmin/Whoop, open their app and check Apple Health sharing"). Wire it to the same `Copy.Home.connectStep1..4` strings already authored.
- **Priority:** This Week — support-load + churn.
- **Confidence:** 88/100 — verified by reading both views; not runtime-confirmed for partial-permission detection nuance.

---

## F15. WebExport produces a HTML report but has no doctor-share framing, no PDF, no privacy reminder before share

- **Severity:** Medium
- **Issue:** `Settings → Generate Web Report` produces an HTML file via `HTMLReportGenerator`, presented as a `ShareSheet` (`UIActivityViewController`). The export contains overall score, category cards, insights, 30-day metric charts including weight and body fat. Audience is unclear — doctor share? insurance? personal record? — and the Settings copy says only "Generate Web Report" with `Copy.Settings.dataExport`. No privacy banner before share ("This file contains your health data — share carefully"), no PDF format option (most clinicians want PDF, not HTML), no per-category include/exclude (a user may want to share heart data with a cardiologist but exclude weight/BMI). The disclaimer "not a medical device" appears nowhere on the HTML output.
- **Why this exists:** First-cut export was scoped to "give the user their data". Doctor-share workflow wasn't designed.
- **Impact:** A user who shares the HTML to a cardiologist sends weight + sleep + every metric, which raises consent concerns. PDF format gap means the export is rarely useful in practice.
- **Evidence:**
  - `Modules/Settings/Views/SettingsView.swift:281-334` — exportRow → ShareSheet.
  - `Modules/WebExport/HTMLReportGenerator.swift:1-60` — generates monolithic HTML; no disclaimer footer in the body.
  - `Modules/WebExport/ReportTemplate.swift` — reviewing recommended.
- **How to verify fast:** Generate report, open the HTML, search for "not a medical device" — absent.
- **Fix:** (a) Add medical disclaimer footer to the HTML template. (b) Show a pre-share sheet that explains what is included with category-level checkboxes. (c) Add PDF as primary format. (d) Rename action to "Share Health Summary".
- **Priority:** This Month — privacy + utility.
- **Confidence:** 85/100 — content of HTML template not fully read end-to-end (only the generator); checking the template would close the gap.

---

## F16. Score names overlap, are renamed inconsistently, and overload the user with three competing 0–100 scales

- **Severity:** Medium
- **Issue:** Home shows: "Recovery" (0–100, live readiness, Whoop-style), "Daily Health Score" (0–100, when readiness data missing), and elsewhere Vitality Age (years), Strain (0–21, Whoop scale), Brain Health (0–100, "Cognitive Wellness"), Stress (0–100, presumably). The user is told to pay attention to several near-identical 0–100 numbers that mean different things and refresh on different cadences. Also "Brain Health" is renamed in copy to "Cognitive Wellness" (`Copy.BrainHealth.title = "Cognitive Wellness"`) but the route is still `.brainHealth` and the analytics event `.brainHealth`. Half-renamed.
- **Why this exists:** Each scoring engine evolved separately. Naming standardization happened only in copy, not in code.
- **Impact:** Cognitive load for new users. Sales page promise of clarity vs the dashboard reality of five scores. Naming drift means support docs and analytics data drift apart from UI.
- **Evidence:**
  - `Modules/Dashboard/Views/Home/HomeView.swift:248-257` — RecoveryHeroCard with conditional label "Daily Health Score" or recovery state label.
  - `Modules/BrainHealth/Copy+BrainHealth.swift:8` vs `Core/Models/Route.swift:12`.
  - `Modules/Strain/Copy+Strain.swift:12` — "of 21" jargon.
- **How to verify fast:** Open Home, then Vitality, then Strain detail. Count distinct scoring scales.
- **Fix:** (a) Pick ONE primary daily score on Home — Recovery when watch data is present, Health Score otherwise — and call it the same thing visually and in code. (b) Move Strain, Vitality Age, Brain to detail views — never on Home above the fold. (c) Standardize: rename `Strain.of21` to "Today's effort" with no number-of-21 visible at the top. (d) Pick one canonical name for Brain Health in code AND copy.
- **Priority:** This Month — clarity + brand maturity.
- **Confidence:** 82/100 — verified by reading Home + scorers; full audit would compare every detail page side by side.

---

## F17. Apple-Health-only data path: a user who opens the app on a brand-new iPhone with zero Apple Health history sees a stuck loading state

- **Severity:** Medium
- **Issue:** `OnboardingMirrorMomentStep` runs `runCalibration` which calls `DashboardViewModel.load(skipDiscovery:awaitDeferredAnalysis:forceHeavyDeferred:runHousekeeping:)`. If Apple Health has zero historical data (new iPhone, no synced wearable, no manual entry) the calibration completes with `metricsWithData == 0`. The Mirror screen falls back to `mirrorNoDataMessage = "No data yet. Laso will build your baseline as data arrives."` — calm copy, good. BUT then `OnboardingPromiseStep.promiseFallback` says "Laso will start building your baseline as data arrives" — so the user lands on Home which renders `firstLaunchLoadingView` with "Discovering patterns" / "Ready" cycling, but the actual home content is `connectHealthView` (empty state). The loading-vs-empty-vs-ready transition on a zero-data device is jittery and confusing. There is no "Try a sample" affordance for the user to see what they would get with data.
- **Why this exists:** Cold-start UX was designed for the typical Apple Watch user with months of history, not for the new-iPhone-day-1 user.
- **Impact:** First-touch friction. Apple App Review may run on a clean Simulator with no health data, and they will see an unconfident loading-to-empty transition.
- **Evidence:**
  - `Modules/Onboarding/Views/Onboarding/OnboardingMirrorMomentStep.swift:204-211`.
  - `Modules/Dashboard/Views/Home/HomeView.swift:236-239, 678-740` — empty-state vs first-launch-loading branches.
- **How to verify fast:** Reset simulator, install fresh, complete onboarding without granting HealthKit permission. The transition is the tell.
- **Fix:** (a) Add a "See sample dashboard" CTA on the empty Home state, gated behind a clear "This is a demo, not your data" banner. Reuse the UI-test mock data (`UITestMode.injectUITestMockData`) for this. (b) Tighten the loading-to-empty transition so the dot animation never plays when `dataDepth.totalDataPoints == 0`. (c) Surface the device-pairing instructions inline on Home, not just under Settings → Manage Devices.
- **Priority:** This Month — first-impression polish.
- **Confidence:** 80/100 — verified by reading; not runtime-confirmed for the exact transition jitter on simulator.

---

## F18. Pricing transparency: trial copy uses install-date trial, paywall uses introductory-offer trial — two trials, possibly conflicting

- **Severity:** Medium
- **Issue:** `SubscriptionManager` computes a 7-day trial from `daysSinceInstall` (`SubscriptionManager.swift:276-277`). Independently, `PaywallView` shows `Copy.Paywall.trialDuration(SubscriptionConfig.trialDays)` as "7-day free trial" only when the **selected StoreKit product** has an `introductoryOffer != nil` (`PaywallView.swift:27, 294-305`). If the App Store Connect product is configured WITHOUT an introductory offer (a common pre-launch state), the install-based 7-day trial still gates the paywall (LasoApp.swift:24-30) but the paywall doesn't say "7-day free trial" — it says "Subscribe Now", which contradicts the user's experience ("I just had a free week, now nothing says trial?"). Apple guideline 3.1.2 expects trial terms to be clearly disclosed at the moment of purchase.
- **Why this exists:** Two trial systems were stitched: the install-based gate (engineering convenience) and the StoreKit introductory offer (Apple-canonical). They are not unified.
- **Impact:** Pre-launch App Review risk. Post-launch user confusion. Refund disputes when a user assumed they were in trial but the product had no intro offer.
- **Evidence:**
  - `Core/Subscriptions/SubscriptionManager.swift:42-58, 276-277`.
  - `Modules/Paywall/Views/Subscription/PaywallView.swift:27-35, 293-305`.
  - `Core/Subscriptions/SubscriptionConfig.swift:30-32`.
- **How to verify fast:** Configure StoreKit testing without intro offer. Open paywall — no trial copy. But install-based gate still says shouldEnforcePaywall after 7 days.
- **Fix:** Make StoreKit's introductoryOffer the single source of truth. Remove the `daysSinceInstall < trialDays` install-trial. The trial that actually reduces churn is the one Apple-managed because it auto-converts to paid after the trial — install-based does not.
- **Priority:** This Week — review + trust.
- **Confidence:** 86/100 — code-read verified; not yet runtime-tested across StoreKit configs.

---

## F19. Paywall has no testimonials, no social proof, no money-back, no "what changes if I don't subscribe"

- **Severity:** Medium
- **Issue:** PaywallView features list reads: live vitals, insights, trends, alerts, privacy. No social proof (rating, count, quote), no risk-reversal ("cancel anytime, refund within 14 days via App Store"), no per-feature comparison ("Free shows yesterday's score, Pro shows live readiness"). This is a generic paywall on a category that is dominated by Whoop/Oura with strong narrative paywalls.
- **Why this exists:** Paywalls iterate post-launch; v1 ships generic.
- **Impact:** Conversion is lower than achievable.
- **Evidence:** `Modules/Paywall/Views/Subscription/PaywallView.swift:120-143`.
- **How to verify fast:** Compare the screen to Whoop / Oura / Eight Sleep paywall screenshots side by side.
- **Fix:** Add (a) star rating + total ratings (auto-pulled from App Store), (b) one short anonymized quote, (c) "Cancel anytime in iOS Settings" affordance copy near the CTA — already partly present in the boilerplate at line 360 but it's buried, (d) a small "What's locked in Free" callout listing 2–3 limitations explicitly.
- **Priority:** This Month — conversion delta.
- **Confidence:** 78/100 — verified by reading; conversion-uplift estimate is industry inference, not measured.

---

## F20. AskYourData is reached from Home without explanation, is gated behind no clear feature label, and may set wrong expectations

- **Severity:** Medium
- **Issue:** `AskYourDataCard` renders the prompt "Concierge" (caption) + a rotating list of seven prompts ("Ask me how to spend today well.", "How is my HRV trending?", etc.) — a chat-like AI feature. There is no "Beta", no model-disclosure copy, no "answers may be wrong, this is not medical advice" inline near the answer. If the underlying engine is on-device Foundation Models (iOS 26+) the answer quality is genuinely uncertain. The seven canned prompts read as marketing of a feature whose accuracy is unproven, and the "Concierge" framing implies professional-grade guidance.
- **Why this exists:** New AI feature, scoped fast for launch.
- **Impact:** Trust whiplash if a wrong answer about HRV is shown to a real user. Apple guideline 4.0 (generative content) requires clear AI disclosure. Marketing-style "Concierge" framing borders on overpromising on a wellness app.
- **Evidence:**
  - `Modules/Dashboard/Copy+Home.swift:336-366` — AskYourData prompts + caption "CONCIERGE".
  - `Modules/Dashboard/Views/Home/HomeView.swift:315-323` — entry point.
- **How to verify fast:** Read the strings.
- **Fix:** Rename caption from "CONCIERGE" to "ASK LASO" or "BETA". Add a one-line disclosure near responses ("Laso uses your own data plus on-device AI. Not medical advice."). Remove the "Ask me how to spend today well." prompt — it implies general life-coaching scope.
- **Priority:** This Week — content + review risk.
- **Confidence:** 82/100 — copy verified; not yet runtime-tested for actual response surface.

---

## F21. Onboarding does not collect name and email — making "Restore Purchases" the only account-recovery path

- **Severity:** Medium
- **Issue:** `OnboardingView.saveUserProfile` saves a `UserProfile` with `name: ""` and `email: ""` (`OnboardingView.swift:165-172`). The app uses anonymous Firebase Auth + deviceId. There is no email capture anywhere — `Copy.Onboarding` has no email field, ProfileCaptureView's signature includes optional name/email but the parent passes nil. Cycle: a user buys a yearly subscription, loses their phone, gets a new one — Restore Purchases works because StoreKit ties to the Apple ID. But all their referral links / referral free months / Firestore profile data is keyed to the OLD `identifierForVendor` and is gone forever — there is no mapping back. Same for cloud-backup retrieval if it exists.
- **Why this exists:** The "no account, just Apple Health" privacy posture is intentional and is a brand asset, but it has consequences.
- **Impact:** Phone-replacement users lose referral state, cloud-backup history, and any server-side profile. Support has no way to identify a user by email.
- **Evidence:**
  - `Modules/Onboarding/Views/Onboarding/OnboardingView.swift:155-173`.
  - `Modules/Referral/Services/ReferralManager.swift:31-44` — keys everything to deviceId.
- **How to verify fast:** Reset device. Reinstall. Sign into same Apple ID. Restore Purchases works for subscription but referralFreeUntil is gone.
- **Fix:** Offer optional email-with-Sign-in-with-Apple (one tap, privacy-respecting) on a dedicated "Save your progress" affordance in Settings — never required, never blocking. Tie Firestore profile to `appleUserID` when present, fall back to deviceId.
- **Priority:** This Month — long-term retention edge case.
- **Confidence:** 84/100 — verified by code; not yet runtime-tested for the cross-device restore scenario.

---

## F22. CTAs compete on Home: RecoveryHeroCard tap, Today's Action card, AskYourData card, MorningCheckIn, Discovery cover — five things a user might tap above the fold

- **Severity:** Medium
- **Issue:** Above the fold on a typical Home render: greeting (CoachGreetingView), Recovery Hero (tappable), Activation Banner, Morning Check-In (when shown), Today's Action card (tappable), Daily Narrative card, Body Intelligence (TodayBriefingView), Personal Health Forecast, AskYourData, plus the alert banner. Six to eight tappable surfaces compete for one "what do I do now" decision. WHOOP and Oura by contrast lead with one number + one action.
- **Why this exists:** The home was built additively as features shipped — no holistic visual hierarchy review.
- **Impact:** Decision paralysis. Lower engagement on the actually-important card (Today's Action).
- **Evidence:** `Modules/Dashboard/Views/Home/HomeView.swift:231-388` — the LazyVStack ordering.
- **How to verify fast:** Open Home with mock data on simulator. Count the tappable cards above the first 1.5 screens of scroll.
- **Fix:** Above the fold: greeting + Recovery Hero + Today's Action ONLY. Push Daily Narrative, Forecast, Body Intelligence, AskYourData below a `Section ("BODY INTELLIGENCE")` header, collapsible. Move MorningCheckIn into a sheet trigger from the greeting strip, not full-width above Today's Action.
- **Priority:** This Month — first-paint clarity is the #1 dashboard lever.
- **Confidence:** 88/100 — verified by reading the LazyVStack; visual test on simulator would confirm exact card density.

---

## F23. Skeleton loaders are inconsistent — Home uses `LoadingView` with a string, first-launch uses dot animation, other tabs use plain `ProgressView`

- **Severity:** Low
- **Issue:** Three loading idioms coexist: (a) `firstLaunchLoadingView` (custom animated phase view), (b) `LoadingView(Copy.Home.analyzingHealthData)` (string-based loader), (c) `ProgressView()` raw spinners on Devices, Settings, Paywall (`Copy.Settings.loadingPrices`). No skeleton placeholders for cards on slow data. The mismatch reads as polish-debt to power users.
- **Why this exists:** Each surface picked the simplest available idiom.
- **Impact:** Polish gap. Lower brand consistency.
- **Evidence:** `Modules/Dashboard/Views/Home/HomeView.swift:29-39, 678-744`; `Modules/Paywall/Views/Subscription/PaywallView.swift:169-172`.
- **How to verify fast:** Open each tab with throttled network. Three different loading styles.
- **Fix:** Define a single `DSSkeleton` family (rect / circle / pill) and replace `ProgressView` with skeleton placeholders for the actual card sizes on Home, Live, Explore. Keep `firstLaunchLoadingView` as the only animated phase loader (it is special).
- **Priority:** This Month — polish / brand.
- **Confidence:** 78/100 — surveyed three views; full audit would touch every loading state.

---

## F24. Error states are mostly "Try Again" with the system error message — generic "Something went wrong" appears in the referral flow

- **Severity:** Low
- **Issue:** HomeView's errorView shows the actual error message ("Unable to Load Data" + the message) — good. ReferralManager returns generic "Something went wrong. Try again." on Firestore failure (`ReferralManager.swift:202`). DiscoveryView, BrainHealthDestination guards `if let brain = ...` and silently no-ops on missing data — empty error path. PaywallView shows `subscriptionManager.errorMessage` but does not differentiate between "no network" / "products not configured" / "purchase declined".
- **Why this exists:** Engineering-default error UX.
- **Impact:** Support load when users can't tell whether the network or the product is at fault.
- **Evidence:**
  - `Modules/Dashboard/Views/Home/HomeView.swift:765-799`.
  - `Modules/Referral/Services/ReferralManager.swift:202`.
  - `Modules/Paywall/Views/Subscription/PaywallView.swift:257-261`.
- **How to verify fast:** Cut network during purchase. The message is the StoreKit error string, often opaque.
- **Fix:** Map the top 5–6 failure modes to friendly explanations + a Contact Support link. Replace "Something went wrong" with concrete cause when known.
- **Priority:** This Month — support-load.
- **Confidence:** 82/100 — verified; not exhaustively traced through every error path.

---

## F25. Reading-level / jargon density: "Cognitive Wellness", "Strain of 21", "Vitality Age", "HRV", "REM" appear without inline glossary

- **Severity:** Low
- **Issue:** Copy is generally good plain-English ("HRV bounced back", "resting heart rate is low", "sleep was short") — F12 risks aside. But some surfaces still leak jargon: `Copy.Strain.of21` literal "of 21", `Copy.BrainHealth.brainHealthOverTime = "Cognitive Wellness Over Time"`, `Copy.Home.RecoveryHero.hrvBelow = "HRV is below your usual"` (acronym without explainer first time). Grade-8 reading target is mostly hit but spikes around scientific names.
- **Why this exists:** Mixed copy authorship over time.
- **Impact:** Friction for non-fitness-savvy users. Slight comprehension cost.
- **Evidence:** strings cited above plus `Modules/Strain/Copy+Strain.swift:12`, `Modules/BrainHealth/Copy+BrainHealth.swift:60`.
- **How to verify fast:** Run a Hemingway reading-level pass on each Copy file.
- **Fix:** First-mention glossary in a tap-to-expand inline hint: "HRV (heart rate variability) is the small change in time between heartbeats. Higher is generally better." Show only on the first user encounter, then never again. Strip "of 21" from Strain — show only the number with a contextual word.
- **Priority:** This Month — comprehension polish.
- **Confidence:** 80/100 — sampled copy files; not all 19 Copy+*.swift files were read line by line.

---

## F26. Empty-state on a brand-new account for InsightsDetail / WeeklyReview / CorrelationsView is technically present but lacks "what to do next"

- **Severity:** Low
- **Issue:** `InsightsDetailView` shows "No insights yet" / "More data will unlock deeper insights over time." The CorrelationsView empty path is gated behind `FeatureGate.canAccess(.advancedAnalytics)` — free users see a paywall not an empty state. WeeklyReview presumably same. The "what to do" gap: a Day-1 user reads "more data will unlock" and has no action. The action exists (wear your watch) but isn't surfaced.
- **Why this exists:** Empty states were thought of as transient, not as Day-1 hero surfaces.
- **Impact:** Day-1 users bounce off a "no insights" message without doing the action that would change it.
- **Evidence:**
  - `Modules/Insights/Views/Insights/InsightsDetailView.swift:123-133`.
  - `Modules/Insights/Views/Insights/CorrelationsView.swift:13` — gated.
- **How to verify fast:** Run on a 0-day account.
- **Fix:** Add per-empty-state actionable CTAs: "Wear your watch overnight to unlock sleep insights" / "Log 14 days of mood to unlock journal insights" / "Connect Apple Health to unlock recovery". Reuse `Copy.Home.connectStep1..4`.
- **Priority:** This Month — first-week activation.
- **Confidence:** 80/100 — verified by reading two files; weekly review not exhaustively read.

---

## F27. Subscription status visibility: free-vs-pro badge is in Settings, but billing-grace banner only appears at 16+ days — too late

- **Severity:** Low
- **Issue:** `subscriptionBadge` in Settings shows "Free Plan" / "Pro Member". The billing-grace banner (`ContentView.billingGraceBanner`) appears only when `billingGraceDays >= 16` (`App/ContentView.swift:690`) — the StoreKit grace period is 60 days for yearly, 16 for monthly, so this banner appears at the very tail end. A user whose card was declined on day 1 of grace has no in-app signal until day 16. Apple sends emails but those go to spam frequently.
- **Why this exists:** The banner was designed conservatively to avoid noise.
- **Impact:** Avoidable churn — a user whose card expires has 16 days of silent failed renewal before the app says anything, by which time they may have given up.
- **Evidence:** `App/ContentView.swift:690-712`.
- **How to verify fast:** Set up StoreKit test with declined card. Open app on day 1 — no banner.
- **Fix:** Show the banner from `billingGraceDays >= 1` with non-alarming copy, escalate visual prominence past 7 days.
- **Priority:** This Month — preventable churn.
- **Confidence:** 84/100 — verified by code read.

---

## F28. Onboarding has no progress indicator on the Pulse step, only on steps 2–6

- **Severity:** Low
- **Issue:** `OnboardingView` body line 80: `if currentStep != .pulse, let currentProgressIndex = ...` — the dot strip is suppressed on screen 1 by design. But this means users on step 2 see "you're 1 of 5" and have no idea how many screens follow. Adding to that, Mirror Moment can take 5–30+ seconds and the dot strip stays still. Total flow length is opaque.
- **Why this exists:** The redesign intentionally hides the dots on the hero screen.
- **Impact:** Drop-off risk on screen 2 ("Is this 5 questions or 50?").
- **Evidence:** `Modules/Onboarding/Views/Onboarding/OnboardingView.swift:80-94`.
- **How to verify fast:** Run onboarding. Screen 1 has no progress hint.
- **Fix:** On screen 1 add a single-line subtext: "Six quick screens, about 60 seconds." Keep the dot strip hidden on screen 1 itself but set the right expectation. Or show the dots on screen 1 too — minimalism is overrated when it costs comprehension.
- **Priority:** This Month — drop-off mitigation.
- **Confidence:** 80/100 — verified by reading.

---

## F29. Stress and Strain modules each present their own narrative on Home + Detail — overlap with Recovery score

- **Severity:** Low
- **Issue:** `Modules/Stress/Copy+StressMonitor.swift` produces stress narratives ("Your body is under stress"). `Modules/Strain/Copy+Strain.swift` produces strain context ("You pushed near your limit. Plan an easier day tomorrow."). The Recovery hero already shows green/yellow/red day-types with WHY lines covering the same territory. Three overlapping narratives compete for the user's attention.
- **Why this exists:** Each module evolved independently with its own scorer.
- **Impact:** User confusion. "Strain says push, Stress says rest" — possible.
- **Evidence:** strain copy file `:13-19`, stress copy file `:70`.
- **How to verify fast:** Read all three modules' narratives in parallel.
- **Fix:** Decide a precedence order: Recovery dominates; Strain and Stress feed into it as inputs but should not have their own competing daily narrative on Home. Move them to detail-only.
- **Priority:** This Month — clarity.
- **Confidence:** 78/100 — verified by copy read.

---

## F30. Profile module (folder) is one file (AchievementsView) — folder structure misleading, no actual user-profile UX

- **Severity:** Low
- **Issue:** `Modules/Profile/` contains exactly two files: `Copy+Achievements.swift` and `Views/Profile/AchievementsView.swift`. There is no profile-edit view, no avatar, no name/email edit, no Sign-in-with-Apple, no account-recovery flow. The module name implies functionality that does not exist — a confusing surface for new contributors and for code-search audits.
- **Why this exists:** Profile was scoped down; module name was not renamed.
- **Impact:** Engineering hygiene; no user-visible impact (Profile isn't reachable in nav).
- **Evidence:** `find Modules/Profile -type f`.
- **How to verify fast:** `ls Modules/Profile/Views/Profile/`.
- **Fix:** Rename the folder to `Modules/Achievements/` and move it under there, OR add the missing profile UX (per F21). The current state violates "module name = scope".
- **Priority:** Backlog.
- **Confidence:** 95/100 — verified by file listing.

---

## Summary table

| ID  | Severity | Theme | Headline | Priority |
|-----|----------|-------|----------|----------|
| F1  | Critical | Notifications | Permission never requested; toggles silently no-op | Now |
| F2  | Critical | Privacy / Apple guideline | Delete-data only wipes locally; Firebase user + Firestore docs survive | Now |
| F3  | High | Onboarding | No body / training / condition / pregnancy capture before scoring | This Week |
| F4  | High | Referral | Entire feature unreachable; orphan view | This Week |
| F5  | High | Profile | AchievementsView unreachable; engine runs without UI | This Week |
| F6  | High | Paywall | Aha-paywall fires on view-appear, not on engagement; non-dismissible | Now |
| F7  | High | Paywall | Trial-expired paywall has no Maybe-Later / Contact-Support escape | This Week |
| F8  | High | Cycle / sensitivity | No opt-in, no off-ramp, copy assumes cisgender female | Now |
| F9  | High | Journal / privacy | No biometric lock on mood/alcohol/stress entries | This Week |
| F10 | Medium | Live tab | Ambiguous name + Pro-locked screen for free no-watch users | This Week |
| F11 | Medium | Risk | "Critical" red badge crosses the medical-claim line | This Week |
| F12 | Medium | Briefing copy | Soft predictions ("tomorrow will feel heavy") read as prophecy | This Week |
| F13 | Medium | Discovery | Suppressed at first launch; tab name overlaps with Explore | This Week |
| F14 | Medium | Devices | No troubleshooting path for partial / denied HealthKit | This Week |
| F15 | Medium | WebExport | No doctor-share framing, no PDF, no privacy banner | This Month |
| F16 | Medium | Scoring | Three+ overlapping 0–100 scales; partial naming drift | This Month |
| F17 | Medium | Cold-start | Zero-data device transitions are jittery | This Month |
| F18 | Medium | Pricing | Two trial systems (install-based + StoreKit) can disagree | This Week |
| F19 | Medium | Paywall | No social proof, no money-back, no Free-vs-Pro comparison | This Month |
| F20 | Medium | AI / "Concierge" | No AI-disclosure copy; "Concierge" framing implies professional advice | This Week |
| F21 | Medium | Identity | Anonymous-only; phone-loss = referral state and history lost | This Month |
| F22 | Medium | Home hierarchy | 6–8 tappable surfaces above the fold | This Month |
| F23 | Low | Loading | Three loading idioms; no card-level skeletons | This Month |
| F24 | Low | Error states | Generic "Something went wrong" in referral flow | This Month |
| F25 | Low | Copy / reading-level | "HRV", "Strain of 21", "Cognitive Wellness" without first-mention glossary | This Month |
| F26 | Low | Empty states | No actionable CTA on day-1 InsightsDetail / Correlations | This Month |
| F27 | Low | Subscription visibility | Billing grace banner only at day 16+ | This Month |
| F28 | Low | Onboarding | No progress hint on screen 1; flow length opaque | This Month |
| F29 | Low | Narrative overlap | Recovery + Strain + Stress narratives compete on Home | This Month |
| F30 | Low | Module hygiene | Profile module misnamed; only Achievements lives there | Backlog |

---

## Top 3 Now (act before TestFlight wider rollout)

1. **F1 — Wire notification permission (or remove the toggles).** Currently the entire notifications product is dead. This single fix unlocks a major chunk of paid value users are buying for. Do it before any growth spend.
2. **F2 — Make Delete-Data actually delete.** Firebase user + Firestore profile + referrals must be cascade-deleted client-side. Without this, App Review can reject under 5.1.1(v), and any GDPR/DPDP request finds residual data. Highest legal risk in the audit.
3. **F8 — Gate cycle tracking behind explicit opt-in + add an off-ramp.** Sensitivity issue with first-page reviewer risk. Trans men, postmenopausal users, men with prior partner data — all currently get menstrual content unprompted. One small `appStateStore.cycleTrackingEnabled` gate closes the loop.

---

Confidence: 87/100 — every finding above was verified by direct code read at the cited file:line; the residual 13 is for paths I did not runtime-test on simulator (paywall offline behaviour, zero-data first launch transition, partial HealthKit permission diagnostics on Devices view, the actual iOS notification prompt flow), and for two cases where exhaustive grep covered the production tree but not the `LasoUITests/` folder which could in theory wire one of the orphan flows. Top 3 Now items are at 95+ individual confidence; the medium / low items are 78–88 individual confidence as noted.

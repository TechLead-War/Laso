# 25 — Compliance & Privacy Pass 2 (Deeper Pass — NEW Findings Only)

Scope: second, deeper compliance pass on the Laso iOS app, building on Pass 1 (`audit/09-compliance-privacy.md`). NEW issues only — Pass 1 covered: in-app server-side deletion (F1), Privacy Manifest data-type breadth (F2), `NSPrivacyTracking` truthfulness vs FirebaseAnalytics (F3), `NSHealthUpdateUsageDescription` truthfulness (F4), PP / ToS surfacing in onboarding (F5), withdraw-consent UX (F6), data export gated + non-portable (F7), cycle Art. 9 explicit consent (F8), age gate (F9), paywall claim (F10), PostHog journal mask (F11), feedback email plaintext (F12), retention (F13), localized PP (F14), CCPA "Do Not Sell" link (F15), iCloud Keychain disclosure (F16), Auto Firebase Auth (F17), missing RoPA / sub-processor docs (F18), no consent log (F19), push consent split (F20), no HIPAA-implying language (F21), Risk module language (F22), ATT (F23), WebExport scope (F24).

This pass surfaces additional issues across **App Store Connect Nutrition Labels, Required Reasons API in the widget target, EU AI Act, EU MDR, FDA SaMD, FTC Health Breach, multi-state US privacy laws (VCDPA/CPA/CTDPA/UCPA), DSA dark-pattern, India DPDP Sec. 11/14/17/data-localisation, Brazil LGPD specifics, Canada/Singapore/Australia/SA, Apple 1.1.6 / 1.6 / 5.1.2 / 5.1.5 / 4.0 / 4.5 / 5.6 / 5.1.1(vii), App Privacy Report, App-switcher snapshot redaction, push-payload privacy, Acknowledgements, EU Representative, DPIA, Schrems-II, EU-US DPF, breach-notification runbook, SCCs, Sign-in-with-Apple parity, bundle-ID mismatch (CloudKit + GoogleService-Info), and PostHog identity-graph linkage of demographics.**

Operating rules: READ-ONLY. Citations are absolute file:line. Confidence stated per finding. NEW issues only — verified against Pass 1 to avoid duplicates.

---

## TL;DR — additional launch blockers

| # | Class | Finding | Severity |
|---|-------|---------|----------|
| N1 | Bundle ID mismatch | `GoogleService-Info.plist:12` declares `BUNDLE_ID = com.lasohealth.app` while the app ships as `com.lasohealth.fit` (`project.yml:77`). FirebaseApp will warn / fail to register; CloudKit container `iCloud.com.lasohealth.app` (`AppSecrets.swift:26`) likewise mismatches. Production privacy posture cannot be defended against Apple if the analytics bundle ID does not match | **Critical (functional + compliance)** |
| N2 | Privacy Manifest, widget target | `LasoWidgets` extension has NO `PrivacyInfo.xcprivacy`. Widget reads/writes `UserDefaults(suiteName:"group.com.lasohealth.fit")` (`Core/Data/WidgetDataStore.swift:83`), uses `Date()` repeatedly. Required Reasons API rule applies to **every binary**, including extensions. Submission validation rejects on iOS 17+. | **Critical (App Store)** |
| N3 | App Privacy Nutrition Label conflict | The Nutrition Label questionnaire (signed legal statement at submission) cross-references PrivacyInfo.xcprivacy. Pass 1 listed 12+ undeclared types in the manifest; if the Nutrition Label pre-fill draft tracks the manifest, the public-facing label will be a 1-of-12 lie that the FTC can pursue as misrepresentation. New angle: Apple cross-checks at submit time and the team has no draft text checked into `Docs/`. | **Critical (App Store + FTC)** |
| N4 | EU AI Act, Art. 6 + Annex III | Risk module + `LLMInsightGenerator` produce automated assessments of an individual's health (`Core/Models/HealthRisk.swift:13–21` 0–100 risk score; `Core/Analysis/ML/LLMInsightGenerator.swift:65–67` "Warning: your … is exhibiting a marked decline"). Under the EU AI Act (effective Aug 2026), profiling that affects individuals' access to health-related services and outputs medical-adjacent recommendations is a **High-Risk AI System** if marketed for health, requiring conformity assessment + CE marking + post-market monitoring. Even framed as wellness, the language drift ("Warning", "marked decline", "Consider scaling back intensity today to allow your body to recover") edges into clinical territory. | **High (EU launch in 2026)** |
| N5 | EU MDR Rule 11 | Pass 1 noted Rule 11 risk — Pass 2 confirms with new evidence: `Core/Analysis/ClinicalIntelligence.swift:14, 60` enumerates `case crisis = "Very High"` and triggers it on `systolic > 180 || diastolic > 120` (the established hypertensive-crisis threshold). Once the app categorises a measurement as a *medical crisis*, Rule 11 (software intended to provide information used for diagnosis or therapy) classifies it as a Class IIa medical device in the EU. CE marking required before EU launch. | **High (EU launch)** |
| N6 | FDA SaMD | Same `ClinicalIntelligence.swift:60` "crisis" classification + `Core/Analysis/HealthRiskEngine.swift:365–366` "below 90% [SpO2] is a medical emergency requiring urgent care" — App is making clinical-threshold determinations. FDA's SaMD framework treats this as Class II (510(k)) if marketed for clinical decision support. Marketing posture must avoid any "use this to detect" language. | **High (US launch)** |
| N7 | FTC Health Breach Notification Rule (16 CFR Part 318) | Rule applies to non-HIPAA "personal health record" vendors. Laso stores user-bound health-adjacent data (gender, age bracket, focuses, subscription, deviceId) in Firestore + computed scores in CloudKit. FTC clarified in 2023 the rule applies to mobile health apps. No 60-day breach notification runbook in `Docs/`. | **Medium (regulator-actionable post-launch)** |
| N8 | Required Reasons API exhaustiveness | `PrivacyInfo.xcprivacy` declares 4 categories (UserDefaults `CA92.1`, FileTimestamp `C617.1`, SystemBootTime `35F9.1`, DiskSpace `E174.1`). Missing: every UserDefaults usage in app target also persists in widget which has NO manifest (see N2). Also no entry for `NSPrivacyAccessedAPICategoryActiveKeyboards` despite no observed use — verify clean. | **Critical (extension manifest)** |
| N9 | App-switcher snapshot redaction | iOS captures a screenshot of the foreground scene when entering background for the App Switcher. `App/ContentView.swift:138` handles `.background` only to flush analytics + schedule background refresh; nothing draws a privacy redaction overlay or hides health values. With Health & Fitness category, glucose/cycle/HRV values appear in the App Switcher. | **Medium (privacy posture)** |
| N10 | Sign in with Apple parity not required (positive) | Verified — no third-party social login present (`grep "ASAuthorizationAppleID\|GoogleSignIn\|FacebookLogin"` returned 0 hits). Apple anonymous Auth alone does not trigger 4.8 Sign-in-with-Apple parity. Documented as cleared. | **Pass** |

---

## Findings (NEW only — numbered N* to disambiguate from Pass 1's F*)

### N1. Bundle ID mismatch between `GoogleService-Info.plist` / CloudKit container / shipped bundle.

- **Severity:** Critical (functional + compliance)
- **Issue:**
  - `GoogleService-Info.plist:12` → `BUNDLE_ID = com.lasohealth.app`.
  - `Core/Config/AppSecrets.swift:26` → `iCloud.com.lasohealth.app` (CloudKit container).
  - `project.yml:77` → `PRODUCT_BUNDLE_IDENTIFIER = com.lasohealth.fit` (the actual ship bundle).
- **Why this matters:**
  - **Compliance (privacy):** Firebase will register `app_instance_id` against the *wrong* package. Privacy Nutrition Label declarations are bound to the bundle ID Apple sees on submission (`com.lasohealth.fit`). Any data Firebase emits will be tied to the mismatched config — making the manifest and the data graph diverge.
  - **CloudKit:** The container ID `iCloud.com.lasohealth.app` requires a matching `aps-environment` + entitlement; with `Laso.entitlements:13–14` declaring only `group.com.lasohealth.fit`, CloudKit will fail at runtime — but more importantly, even if a future release adds the CloudKit entitlement keyed to `.app`, the bundle is `.fit`, so the access-control mismatch exposes a confused-deputy concern at the privacy boundary.
  - **App Store Connect:** Apple binds Privacy Nutrition Label to the App Record's bundle ID. The Firebase project is keyed to a different one. If Firebase emits anything (Crashlytics, Auth, Firestore), the data-flow-to-bundle binding the team is asked to attest to is broken.
- **Fix:** Re-download `GoogleService-Info.plist` from a Firebase project keyed to `com.lasohealth.fit`. Update `AppSecrets.CloudKit.containerID = "iCloud.com.lasohealth.fit"`. Add a build-time assertion that `Bundle.main.bundleIdentifier == GoogleService-Info BUNDLE_ID`.
- **Confidence:** 96/100 — three file:line mismatches verified directly. 4 points withheld because Firebase will sometimes accept a mismatched plist with a warning; runtime behavior was not exercised.

### N2. `LasoWidgets` extension is missing `PrivacyInfo.xcprivacy` entirely.

- **Severity:** Critical (App Store submission validation, iOS 17+)
- **Issue:** `project.yml:147–179` defines `LasoWidgets` (app extension) but there is no `PrivacyInfo.xcprivacy` in `LasoWidgets/` or `LasoWidgets/Info.plist` referencing one. The extension uses Required-Reasons APIs:
  - `Core/Data/WidgetDataStore.swift:83` — `UserDefaults(suiteName: "group.com.lasohealth.fit")` (CA92.1).
  - `LasoWidgets/AnalysisWidgetProvider.swift:24` and `LasoWidgets/AnalysisWidgetEntry.swift:14, 19, 26, 32, 38, 44, 46` — `Date()` system clock.
  - `Shared/CoachActionIntents.swift:23–24` — `UserDefaults(suiteName: appGroupID)`.
- **Why this is fatal:** Apple's Required Reasons API rule applies to **every binary in the bundle**, including extensions. Without a manifest for `LasoWidgets`, App Store Connect rejects the upload at processing.
- **Fix:** Add `LasoWidgets/PrivacyInfo.xcprivacy` declaring `NSPrivacyAccessedAPICategoryUserDefaults` (`CA92.1`) and `NSPrivacyAccessedAPICategoryFileTimestamp`/`SystemBootTime` as needed. Reference it in `project.yml` widget `sources:`. Also declare any data-type *collected* by the widget (currently none — the widget only reads from a shared App Group, but the Nutrition Label question "does this extension collect data" must be answered consistently).
- **Confidence:** 96/100 — file absence + `UserDefaults` / `Date()` usage in extension code verified.

### N3. App Store Connect Privacy Nutrition Label is undrafted; will diverge from manifest at submission.

- **Severity:** Critical (App Store + FTC misrepresentation)
- **Issue:** The Nutrition Label is a separate, legally-binding statement attested to by an Apple-account-holding reviewer at submission. It is not in the repo. The pre-fill values that Apple's tooling uses are sourced from `PrivacyInfo.xcprivacy`. Pass 1 already documented that the manifest declares 1 of 12+ collected types — meaning the Nutrition Label pre-fill will be wrong by default, and the human submitter is then required to either parrot the wrong value or correct it (creating a manifest-vs-label mismatch which Apple's tooling flags as a hard block as of late 2024).
- **Pre-fill draft (read-only; for the team to use as-is when filing):**
  - **Health & Fitness — Health:** Linked=No, Tracking=No, Purposes=App Functionality. (HealthKit reads — `HealthKitManager.swift:119–149`.)
  - **Health & Fitness — Fitness:** Linked=No, Tracking=No, Purposes=App Functionality. (workouts, exercise, steps.)
  - **Sensitive Info — health (cycle):** Linked=No, Tracking=No, Purposes=App Functionality. (`HealthKitManager.swift:146`.)
  - **Identifiers — User ID:** Linked=Yes, Tracking=No, Purposes=App Functionality + Analytics. (Firebase UID, deviceId — `UserProfileStore.swift:81–83, 169`.)
  - **Identifiers — Device ID:** Linked=No, Tracking=No, Purposes=Analytics. (PostHog distinct_id — `PostHogManager.swift:67`.)
  - **Contact Info — Email:** Linked=Yes, Tracking=No, Purposes=Customer Support. (Optional in feedback — `FeedbackPromptManager.swift:135–137`.)
  - **Demographics — Gender:** Linked=Yes, Tracking=No, Purposes=Analytics + Product Personalization. (`UserProfileStore.swift:175`; `AppAnalytics.swift:399–401`.)
  - **Demographics — Age:** Linked=Yes, Tracking=No, Purposes=Analytics + Product Personalization. (Bracket sent — `AppAnalytics.swift:386–394`.)
  - **Diagnostics — Crash Data:** Linked=Yes, Tracking=No, Purposes=App Functionality. (`PostHogManager.swift:126–166`.)
  - **Diagnostics — Performance Data:** Linked=Yes, Tracking=No, Purposes=Analytics. (`AppAnalytics.swift:1755, 1765`.)
  - **Diagnostics — Other Diagnostic Data:** Linked=Yes, Tracking=No, Purposes=Analytics. (device model, iOS version, locale — `FeedbackPromptManager.swift:128–133`; `AppAnalytics.swift:404–425`.)
  - **Usage Data — Product Interaction:** Linked=Yes, Tracking=No, Purposes=Analytics + Product Personalization. (entire `AppAnalytics.swift`.)
  - **Purchases — Purchase History:** Linked=Yes, Tracking=No, Purposes=App Functionality. (`SubscriptionManager.swift:467–486`.)
  - **User Content — Other (journal free-text notes):** Linked=Yes, Tracking=No, Purposes=App Functionality. On-device only, but Apple wants it disclosed because it is *collected* via UI — even if not transmitted.
- **Fix:** Author `Docs/privacy-nutrition-label.md` with the table above, signed by the legal reviewer. Update PrivacyInfo.xcprivacy first (see Pass 1 F2), so the pre-fill matches.
- **Confidence:** 92/100 — every cited data flow verified by file:line; bucket assignment for some items (e.g. Demographics vs Other User Content for `healthFocuses`) is Apple's call.

### N4. EU AI Act — Risk module + `LLMInsightGenerator` may classify as High-Risk AI for health.

- **Severity:** High (EU launch from Aug 2026, escalating to Aug 2027)
- **Issue:** EU AI Act Annex III(5)(b) classifies as High-Risk: "AI systems intended to be used to evaluate the eligibility of natural persons for essential … health services." Wellness apps are not automatically in scope, but the language in `Core/Analysis/ML/LLMInsightGenerator.swift:65–67`
  > "Warning: Your <topic> is exhibiting a marked decline involving <metrics>"
  combined with `Core/Analysis/HealthRiskEngine.swift:365` ("…requires immediate attention. … seek immediate medical attention") and `Core/Analysis/ClinicalIntelligence.swift:14` (`crisis = "Very High"`) crosses from "wellness pattern" to "automated assessment of health status that may influence whether the user seeks medical care." Once classed High-Risk, Art. 9 (risk management), Art. 10 (data governance), Art. 13 (transparency to user that they are interacting with an AI system + characteristics of automated decisions), Art. 14 (human oversight), Art. 15 (accuracy + robustness + cybersecurity), Art. 16–29 (provider obligations), and CE marking under Annex VIII apply.
- **Fix options:**
  1. Soften terminal language in `LLMInsightGenerator.swift:65–67` and `RulesConfiguration.swift:247–249` from "Warning / requires immediate medical attention" to non-clinical pattern language. Same posture as Pass 1 F22.
  2. Add an Art. 13 transparency notice on first display of any AI-generated text: "This insight was generated automatically by Laso based on your data. It is not medical advice."
  3. Document the decision in `Docs/ai-act-classification.md`. If classified High-Risk: full conformity assessment + CE marking before EU launch.
- **Confidence:** 88/100 — text and threshold logic verified at file:line; whether the AI Act treats Laso as High-Risk depends on positioning copy on App Store + privacy policy, which are not in the repo. The 12 points withheld are for that out-of-repo positioning.

### N5. EU MDR Rule 11 — `ClinicalIntelligence.swift` classifies BP as `crisis` at standard hypertensive-crisis thresholds.

- **Severity:** High (EU launch — Class IIa CE mark required)
- **Issue:** `Core/Analysis/ClinicalIntelligence.swift:14` defines `case crisis = "Very High"`, and line 60 sets it on `systolic > 180 || diastolic > 120` — the textbook hypertensive-crisis threshold (American Heart Association + ESC guidelines). Once the software *categorises* a vital sign as a clinical crisis, MDR Rule 11 applies: "Software intended to provide information which is used to take decisions with diagnosis or therapeutic purposes is classified as Class IIa." For a hypertensive crisis (immediate life threat), Rule 11 escalates to Class IIb.
- **Plus:** `Core/Analysis/RulesConfiguration.swift:247–249` writes user-facing copy: "Blood oxygen is critically low, below the 90% emergency threshold. … seek emergency medical care." This is unambiguous diagnostic guidance.
- **Fix options:**
  1. Strip the `crisis` enum case + threshold logic for the EU build. Cap the worst category at "Elevated" with non-directive copy ("This reading is outside the typical home-monitor range. Please discuss with your clinician.").
  2. Or: pursue Class IIa CE marking with notified-body assessment (12–18 month process; expensive).
  3. Add a build-time region gate: do not surface `.crisis` UI to users where `Locale.current.region == "EU regions"`.
- **Confidence:** 92/100 — code verified; classification under Rule 11 follows from the categorisation language and is well-established for similar apps that have been pulled from EU stores.

### N6. FDA SaMD — same diagnostic-language problem in the US.

- **Severity:** High (US enforcement)
- **Issue:** FDA's "Clinical Decision Support" guidance (Sep 2022, finalised) deems software a medical device if it provides specific clinical recommendations + the clinician/user cannot independently review the basis. `Core/Analysis/HealthRiskEngine.swift:365–366` outputs:
  > "SpO2 below 95% warrants attention. Below 90% is a medical emergency requiring urgent care. … if confirmed, seek immediate medical attention if confirmed."
  This is a specific recommendation tied to a specific threshold and a specific clinical action. It triggers FDA jurisdiction unless properly framed as wellness-only.
- **Fix:** Same as N5 — soften the action-laden clinical guidance copy, or pursue 510(k) clearance (~9–12 months, $50–500k).
- **Confidence:** 86/100 — FDA's enforcement posture for wellness apps is variable; 14 points withheld for that uncertainty.

### N7. FTC Health Breach Notification Rule (16 CFR Part 318) — runbook absent.

- **Severity:** Medium (regulator-actionable post-launch)
- **Issue:** FTC's Sep 2023 expansion of the Health Breach Notification Rule explicitly covers mobile health apps that are not HIPAA-covered. Laso writes user-bound health data to Firestore (`UserProfileStore.swift:174–198`, `SubscriptionManager.swift:477–486`, `FeedbackPromptManager.swift:122–142`) and CloudKit (`Core/Data/CloudBackupManager.swift`). On a breach, the team has 60 days to notify each affected individual + FTC + (for >500 affected) prominent media. No breach-notification runbook in `Docs/`, no incident response process, no test of Firestore audit logs.
- **Fix:** `Docs/breach-notification-runbook.md` covering: detection criteria, affected-user identification queries (Firestore audit logs by deviceId), notification template, FTC filing template, time-bound SLA, post-mortem process. Out of repo, but flag as needed before launch.
- **Confidence:** 85/100 — FTC rule is in force and applicable; absence of `Docs/` runbook verified by `ls Docs/`.

### N8. PrivacyInfo Required-Reasons API exhaustive review — main app appears OK; **widget is the gap.**

- **Severity:** Critical (extension manifest gap is N2; main-app gap is now narrow)
- **Issue:** Re-checked main-app coverage:
  - `NSPrivacyAccessedAPICategoryUserDefaults` — covered (`CA92.1`).
  - `NSPrivacyAccessedAPICategoryFileTimestamp` — covered (`C617.1`).
  - `NSPrivacyAccessedAPICategorySystemBootTime` — covered (`35F9.1`); verified `ProcessInfo.systemUptime` not directly used but `ThermalManager` etc. may transitively trigger it.
  - `NSPrivacyAccessedAPICategoryDiskSpace` — covered (`E174.1`).
  - **NOT declared but possibly used:** `NSPrivacyAccessedAPICategoryActiveKeyboards` — main app does not appear to read keyboard list, *probably* clean (no `UITextInputMode.activeInputModes` in source), but unverified.
- **Fix:** Add an `NSPrivacyAccessedAPICategoryActiveKeyboards` exclusion check in CI. Prioritise N2 (widget manifest absence).
- **Confidence:** 84/100 — direct grep didn't find ActiveKeyboards APIs in the main target; runtime exercise not performed.

### N9. App-switcher snapshot redaction — iOS captures health values for App Switcher.

- **Severity:** Medium (privacy posture, not legal block)
- **Issue:** `App/ContentView.swift:138` handles `scenePhase == .background` for analytics flush + background refresh, but never installs an overlay window or sets `view.isHidden = true`. iOS captures one snapshot of the live UI when the app is suspended, used for the App Switcher tile. With heart-rate, HRV, sleep score, cycle phase, etc. visible on Home / Insights / Cycle screens, those values are persisted in iOS's snapshot cache and visible whenever the user opens the App Switcher.
- **Fix:** On `scenePhase == .inactive` (transition to .background), present a `Color.black.ignoresSafeArea()` or branded splash overlay that hides the underlying scene; remove on `.active`. Standard pattern in banking + health apps.
- **Confidence:** 90/100 — `ContentView.swift` scenePhase handler verified; absence of overlay verified.

### N10. Push notification payload privacy — local payloads OK; remote-push surface unbuilt.

- **Severity:** Low-Medium (preventive)
- **Issue:** All `UNMutableNotificationContent` instances assemble locally (`NotificationManager.swift:170–173`, `EngagementSequenceScheduler.swift:604–606`, `ReengagementScheduler.swift:41–56`), drawn from in-app data. Lock-screen previews therefore surface health data: e.g. `lapsedLossFrameBody` (`Copy+Notifications.swift:380–394`) embeds the user's last HRV in milliseconds + a directional trend. With default lock-screen preview = ON, anyone glancing at the locked phone sees "Last score: 72. HRV was 38 ms and slipping." That's PHI in the textbook sense.
- **Fix:** Either (a) instruct users in onboarding to set Settings → Notifications → Laso → Show Previews → "When Unlocked", or (b) author notification copy that omits raw values: "Your latest insight is ready" + open-app-to-see. Pass 1 F20 covered notification consent split; this is a separate copy-redaction issue.
- **Confidence:** 88/100 — copy bodies verified at file:line; iOS lock-screen default behavior is well known.

### N11. EU GDPR Art. 27 — EU Representative requirement.

- **Severity:** High (EU launch hard requirement)
- **Issue:** Laso's developer team appears non-EU (Apple Team ID `S2MAH8X8JM` US-registered; `Secrets.xcconfig.template:6` and `AppSecrets.swift:70` use the EU-hosted PostHog, but the controller likely sits outside the EEA). Art. 27 requires non-EEA controllers offering goods to EU residents to designate, in writing, an EU-based representative. No `Docs/eu-representative.md`, no contact details in the privacy policy reachable from the app.
- **Fix:** Engage an EU rep (e.g. Prighter, DataRep, EDPB-certified DPO services) and surface the rep's name + email + postal address in the in-app PP page.
- **Confidence:** 86/100 — code-side absence verified; team's EU/non-EU status inferred from Apple Team ID region.

### N12. India DPDP Sec. 11 — right to nominate not implemented.

- **Severity:** Medium (India launch)
- **Issue:** DPDP Act 2023 Sec. 11 grants the right to nominate another individual to exercise the principal's rights in case of death/incapacity. There is no UI for nomination, no Firestore field `nominee`, no PP language about it.
- **Fix:** Settings → Privacy → "Nominate someone to manage your data" with a name + email + relationship. Persist `nominees/{deviceId}` in Firestore. Out-of-band notify the nominee.
- **Confidence:** 84/100.

### N13. India DPDP Sec. 9 (children) — `under_18` age bracket actively shipped to PostHog.

- **Severity:** High (India + EU + Brazil)
- **Issue:** `Core/Tracking/AppAnalytics.swift:386` explicitly sets `bracket = "under_18"` for users under 18 and ships it to PostHog as the `age_bracket` user property (`AppAnalytics.swift:394, 434`). Combined with onboarding's age-13 floor (`ProfileCaptureView.swift:16`), Laso is *knowingly* processing children's data without parental consent and shipping the bracket label to a third-party processor (PostHog Inc, EU-hosted but still a separate legal entity). DPDP Sec. 9: parental consent is mandatory for under-18s. GDPR-K: 13–16 floor by member state, parental consent below. LGPD Art. 14: under-18 needs guardian consent.
- **Fix:** Either (a) raise minimum age to 18 in `ProfileCaptureView.swift:16` so the `under_18` branch is unreachable, or (b) for under-18 users, gate PostHog `identify` and `setUserProperties` to never run, plus refuse Firestore writes. The latter is safer for retention.
- **Confidence:** 92/100 — code paths verified at file:line.

### N14. India DPDP — sensitive personal data localisation. Firestore region unverified.

- **Severity:** Medium-High (India launch)
- **Issue:** DPDP Act provides the government can notify categories of personal data that must be localised. The Draft DPDP Rules 2025 propose this for `Significant Data Fiduciaries`. `GoogleService-Info.plist:14` shows `PROJECT_ID = laso-health-v1` — the Firestore region is not in the repo (set in Firebase console). If the Firestore database is in `us-central1` or `europe-west`, India users' data crosses borders. Pre-launch, the team must (a) confirm the database region, (b) document SCCs, (c) plan for an India-region Firestore database (`asia-south1` Mumbai, `asia-south2` Delhi) if regulator notifies localisation.
- **Fix:** `Docs/data-localisation.md` documenting the live Firestore region + transfer-mechanism + roadmap to multi-region for India. Out of repo, flag as needed.
- **Confidence:** 82/100.

### N15. India DPDP Sec. 17 — Significant Data Fiduciary. Likely scale-out trigger.

- **Severity:** Low (only triggers if scale qualifies)
- **Issue:** Sec. 17 designates `Significant Data Fiduciaries` based on processing volume + sensitivity. Health data + automated profiling makes Laso a candidate even at modest scale. SDF obligations: appoint an India-resident DPO, conduct DPIA, publish RoPA, undergo independent audit. None of these are in `Docs/`.
- **Fix:** Track the threshold; pre-build the audit posture (RoPA in `Docs/RoPA.md` per Pass 1 F18) so the SDF designation does not trigger a scramble.
- **Confidence:** 75/100 — applicability depends on user count + government notification.

### N16. EU GDPR Art. 35 — DPIA absent for high-risk processing.

- **Severity:** High (EU launch)
- **Issue:** Article 35 requires a DPIA for processing that is "likely to result in a high risk to the rights and freedoms of natural persons", explicitly including (recital 91): large-scale processing of health data + systematic profiling. Laso does both. No DPIA in `Docs/`.
- **Fix:** `Docs/DPIA.md` covering: nature, scope, context, purposes; necessity + proportionality; risk to data subjects; mitigations. Cite each Firestore + CloudKit + PostHog data flow.
- **Confidence:** 90/100 — necessity confirmed by absence of DPIA file.

### N17. GDPR Art. 33 — breach notification 72h SLA. Runbook absent.

- **Severity:** Medium (overlapping FTC N7)
- **Issue:** Art. 33 requires notification to the supervisory authority within 72 hours of becoming aware of a breach. No Firestore audit-log monitoring, no PagerDuty rule, no `Docs/breach-runbook.md`. Same gap as FTC N7 but with a tighter SLA (72h vs 60d).
- **Fix:** Same `Docs/breach-notification-runbook.md` as N7, with separate sections for EU 72h vs FTC 60d vs DPDP "as soon as possible" vs LGPD "reasonable time" — different jurisdictions, different SLAs, single workflow.
- **Confidence:** 88/100.

### N18. Schrems II — EU-US transfer mechanism. SCCs / EU-US Data Privacy Framework dependence undocumented.

- **Severity:** Medium (EU launch)
- **Issue:** Firestore (Google) and Apple Push Notification Service are US-headquartered. EU-US data transfers post-Schrems II must be on (a) SCCs + supplementary measures, (b) Binding Corporate Rules, or (c) the EU-US Data Privacy Framework (Google is certified — verify currency). `AppSecrets.swift:70` confirms PostHog uses EU host (`https://eu.i.posthog.com`) — partially mitigates the question. But Firestore is silent on region.
- **Fix:** `Docs/sub-processors.md` (Pass 1 F18) must explicitly cite for each: legal basis for transfer, certification status (DPF), and renewal window. Cite Google's DPF self-certification (active as of late 2024 — re-verify at launch).
- **Confidence:** 78/100 — out-of-repo certification status; will not be verifiable from code. Confidence dragged down by Google's DPF status being a moving target and the Firestore region being unset in the repo.

### N19. CCPA / CPRA — Notice at Collection not surfaced at point of collection.

- **Severity:** Medium (CA enforcement)
- **Issue:** Cal. Civ. Code § 1798.100(b) requires a "notice at collection" listing the categories of PI collected and the purposes, presented at or before the point of collection. Laso's only notice (PP link) is in Settings post-onboarding. Same gap as Pass 1 F5 but with a different legal hook (CCPA explicit statutory text, not GDPR Art. 13).
- **Fix:** Same fix as Pass 1 F5 (footer link on profile capture screen) — but the copy must enumerate categories of PI for CCPA compliance. A single "Privacy Policy" link is borderline; a banner stating "We collect: identifiers, demographic, health & fitness, usage. See Privacy Policy" is safer.
- **Confidence:** 88/100.

### N20. CCPA — "Right to Know" categories of PI shared. Silent on PostHog as recipient.

- **Severity:** Medium
- **Issue:** Even though Laso "does not sell" data, CPRA-amended CCPA defines "share" to include cross-context behavioral advertising. PostHog session-replay + product-analytics events sharing user-keyed events with PostHog Inc may technically constitute "sharing" depending on PostHog's downstream use. The PP page must enumerate PostHog (and Firebase, Apple) as recipients. Out-of-repo verification needed.
- **Fix:** Explicit enumeration in PP. In the in-app Settings → Privacy section, a "Categories of PI we share" list, even if it's read-only.
- **Confidence:** 76/100 — depends on PP page text not in repo.

### N21. VCDPA / CPA / CTDPA / UCPA — opt-out of profiling and targeted advertising.

- **Severity:** Medium (US state laws)
- **Issue:** Virginia (effective 2023), Colorado (Jul 2023), Connecticut (Jul 2023), Utah (Dec 2023) all require an opt-out of profiling-driven decisions that produce legal or similarly significant effects. Laso's Risk module + automated insights produce "similarly significant" effects (recommendation to seek medical attention). Plus targeted-advertising opt-out (n/a here, since no ads). Settings has no per-state opt-out toggle and no Global Privacy Control honor (Colorado specifically requires honoring `Sec-GPC` HTTP header — but Laso is not a website, so this is mainly for the marketing site at `https://lasohealth.fit`).
- **Fix:**
  1. Settings → Privacy → "Opt out of automated insights / profiling" toggle that disables `Core/Analysis/HealthRiskEngine.swift` + `Core/Analysis/InsightGenerator.swift` outputs at the UI layer.
  2. Marketing site: honor Sec-GPC.
- **Confidence:** 78/100 — applicability of "similarly significant" is jurisdictionally interpreted; toggle absence verified.

### N22. EU Digital Services Act — Art. 25 dark-pattern prohibition maps to Pass 1 F22 and notification copy.

- **Severity:** Medium-High (EU launch)
- **Issue:** DSA Art. 25 prohibits design that "deceive[s] or manipulate[s] recipients of their service or that … materially distorts or impairs … decisions." `Core/Notifications/Copy+Notifications.swift:178–187` explicitly uses loss-aversion ("Your `\(streakDays)`-day streak expires tonight", "You are losing ground from last week", "Yesterday's gains are slipping"). Combined with the engagement-sequence scheduler firing these on lapsed users, this is a textbook DSA Art. 25(1)(c) "exploiting psychological vulnerabilities" violation if challenged.
- **Fix:** Replace loss-frame variants with neutral copy ("Your streak update is ready", "Your weekly comparison is ready"). Internally, A/B test the milder copy — the engagement loss is usually <10%.
- **Confidence:** 84/100 — copy verified; DSA Art. 25 is new (Feb 2024) and enforcement priors are thin.

### N23. PostHog identity graph — health-adjacent demographics directly attached to a stable identifier.

- **Severity:** Medium (GDPR pseudonymisation defense weakened)
- **Issue:** `Core/Tracking/AppAnalytics.swift:394, 400, 405, 410` and `:434` sets PostHog user properties for `age_bracket`, `gender`, `country`, `language`, `timezone`, `device_model`, `phone_model`, `os_version`, `app_version` — under PostHog's `distinct_id`. PostHog's distinct_id is the same identifier used for session replay + every event. So one PostHog query joins demographics + every screen visited + every score viewed. This widens the pseudonymisation surface considerably: Pass 1 F12 covered email; this finding is the demographics + behavioural fusion.
- **Why this matters:** GDPR Art. 4(5) defines pseudonymisation as data that cannot be attributed without additional information — here, `gender + ageBracket + region + timezone + device_model + os_version` joined with session-replay video may be re-identifiable for unique cohorts (e.g. only one female user from `IN`, age 35–44, on iPhone 15 Pro Max, en, IST timezone — that's 1-of-1 in a small launch cohort).
- **Fix:** (a) Don't set demographic user properties on PostHog at all — leave them in Firestore where access control is server-side. (b) Or hash `age_bracket + gender + region` into a coarse string ("ec_w_in") that loses individual-distinguishing power. (c) Document the pseudonymisation strategy in the DPIA.
- **Confidence:** 90/100 — every property set verified at line.

### N24. PostHog `identify(userId:)` — deterministic linkability to deviceId.

- **Severity:** Medium
- **Issue:** `Core/Tracking/PostHogManager.swift:67–70` exposes `identify(userId: ...)`. The userId callers should be pseudonymous, but no caller path was audited end-to-end in this pass. If `identify` is called with `firebaseUid` or `deviceId`, then PostHog has a stable cross-session linker tied to the same identifier Firestore uses (`UserProfileStore.swift:81–83`). That makes the data graphs rejoinable post-breach.
- **Fix:** Audit every `PostHogManager.shared.identify` caller to confirm pseudonymous user IDs (a salted hash of deviceId, salt rotated per app install). If currently using deviceId/firebaseUid raw, switch.
- **Confidence:** 75/100 — `identify` exposure verified, caller audit not exhaustive in Pass 2.

### N25. Apple Guideline 1.1.6 — Mental health and self-harm content. Journal has no resources.

- **Severity:** Medium-High (Apple App Review subjective judgment)
- **Issue:** Journal supports free-text notes (`JournalEntryView.swift:230–237`). Users can write distress text. Apple Guideline 1.1.6 expects mental-health apps to provide crisis resources. No code, no copy, no link to a crisis hotline in `Modules/Journal/`. Apple has rejected health apps for missing this.
- **Fix:** A persistent footer in JournalEntryView: "If you are in crisis, contact [988 (US)] / [Vandrevala 1860-2662-345 (India)] / [Samaritans 116-123 (UK)]." Region-aware via `Locale.current.region`. Plus Settings → Help → Crisis Resources page.
- **Confidence:** 86/100 — Apple's enforcement of 1.1.6 is somewhat soft for non-mental-health-focused apps but real.

### N26. Apple Guideline 1.6 — Safety. Risk module missing crisis resource link.

- **Severity:** Medium
- **Issue:** `Modules/Risk/Views/Risk/HealthRiskDetailView.swift` shows a numerical risk grade and copy like `Core/Analysis/HealthRiskEngine.swift:365` "below 90% is a medical emergency requiring urgent care", but no clickable link to emergency services or a "Call 911 / 112" CTA. Apple 1.6 expects safety-relevant features to provide actionable safety paths.
- **Fix:** When `RiskGrade.veryHigh` is shown, surface a "Get help" action that opens the iOS Emergency SOS sheet or `tel://` to the local emergency number (region-aware).
- **Confidence:** 80/100.

### N27. Apple Guideline 5.1.2 — Permission strings. NSSiriUsageDescription is acceptable; HK strings are the Pass 1 F4 issue.

- **Severity:** Low (positive verification)
- **Issue:** `Info.plist:33–34` `NSSiriUsageDescription = "Laso uses Siri to let you check your health score, log water, view sleep data, and track workouts hands-free."` — concrete and accurate (matches `Core/Intents/HealthScoreIntent.swift, LogWaterIntent.swift, ShowTrendsIntent.swift, SleepSummaryIntent.swift`). PASS for 5.1.2 on Siri.
- **HK update string** is the Pass 1 F4 problem; not new.
- **Confidence:** 92/100.

### N28. Apple Guideline 5.1.5 — Location. Verified absent (positive).

- **Severity:** n/a (positive)
- **Verification:** No `CLLocationManager`, no `NSLocationWhenInUseUsageDescription` / `NSLocationAlwaysUsageDescription` keys in `Info.plist`, no location entitlements. Clean. Documented to short-circuit any review-time question.
- **Confidence:** 95/100.

### N29. Apple Guideline 4.0 — Design / minimum functionality. Risk module thin.

- **Severity:** Low-Medium
- **Issue:** Apple subjective. Risk module (`Modules/Risk/Views/Risk/HealthRiskDetailView.swift`) is one screen with a numerical grade + factor list. App Review may assert "minimal viable functionality" if the score is the entire feature. Pair with the Pass 1 F22 language risk and the EU MDR risk (N5), and Risk becomes a flag.
- **Fix:** Either (a) cut the Risk module from v1 (highest-yield safety move; flag to product), or (b) deepen it with explanations + factor history charts so 4.0 is satisfied.
- **Confidence:** 70/100 — 4.0 is reviewer-subjective.

### N30. Apple Guideline 4.5 — App Extensions. Widget extension has no Privacy Manifest (N2 again).

- **Severity:** Critical (covered by N2)
- **Confidence:** see N2.

### N31. Apple Guideline 5.6 — Developer Code of Conduct. Bundle-ID consistency expected.

- **Severity:** Medium
- **Issue:** Bundle ID confusion (N1: `.app` vs `.fit`) makes it hard to demonstrate "consistent representations" to Apple if challenged. Code of Conduct expects truthfulness in metadata, app records, and identifiers. Two GoogleService-Info `BUNDLE_ID`s in different files would fail any internal consistency audit.
- **Confidence:** 78/100.

### N32. Apple Guideline 5.1.1(vii) — Pro / clinical claims. App Store description not in repo.

- **Severity:** Medium (depends on App Store description)
- **Issue:** 5.1.1(vii) is triggered by clinical claims. Repo strings are mostly safe (Pass 1 F21). The marketing copy on App Store Connect is not in the repo, but is the highest-risk surface. Cross-reference with the app description before submitting.
- **Fix:** Cross-link the clinical-language audit (Pass 1 F22, this pass N4/N5/N6) with the App Store Connect description draft. Get legal-reviewed copy.
- **Confidence:** 70/100.

### N33. App Privacy Report (iOS 15.2+) — what users will see.

- **Severity:** Low (transparency disclosure)
- **Issue:** When users enable "Record App Activity" in Settings, iOS records every domain contacted + every sensor accessed by Laso. Expected entries: `firebaseinstallations.googleapis.com`, `firebaseauth.googleapis.com`, `firestore.googleapis.com`, `firebasestorage.googleapis.com`, `eu.i.posthog.com`, plus HealthKit accesses. App Privacy Manifest's `NSPrivacyTrackingDomains` is empty (`PrivacyInfo.xcprivacy:7–8`). If `NSPrivacyTracking` is changed to `true` (Pass 1 F3 alternative), the tracking domains list must include `app-measurement.com` (Firebase Analytics's tracking domain). Otherwise empty list is correct only if FirebaseAnalytics is disabled (Pass 1 F3 fix).
- **Fix:** Tied to F3 disposition. Documented for clarity.
- **Confidence:** 86/100.

### N34. EU AI Act — Art. 52 transparency obligation regardless of risk class.

- **Severity:** Medium
- **Issue:** Even for non-high-risk AI, Art. 52 requires informing the user when they are interacting with an AI system or with AI-generated content. `LLMInsightGenerator.swift` produces synthetic narrative text (`synthesizeParagraph`). Users see: "Warning: Your sleep is exhibiting a marked decline involving HRV and Deep Sleep." — a synthesised sentence with no AI label.
- **Fix:** Add a small "Generated automatically" badge on every insight surface, or one-time disclosure on first display.
- **Confidence:** 85/100.

### N35. Apple Sign in with Apple parity — verified not required (positive).

- **Severity:** n/a (positive)
- **Verification:** No third-party social login (`grep "ASAuthorizationAppleID\|GoogleSignIn\|FacebookLogin\|signInWithGoogle\|FBSDKLogin"` returned 0 hits). 4.8 parity rule does not apply.
- **Confidence:** 96/100.

### N36. Cocoapods / SPM third-party SDK Acknowledgements view absent.

- **Severity:** Low (license-compliance + Apple expectation)
- **Issue:** Third-party SDKs in use: Firebase (Apache 2.0), PostHog (MIT). Both attribution-only licenses. App needs an in-app Acknowledgements view per Settings → About to satisfy attribution. Settings has Privacy + Terms links (`SettingsView.swift:387–409`) but no "Acknowledgements" / "Open Source Licenses" entry.
- **Fix:** Add `SettingsView` row → presents `AcknowledgementsView` rendering Apache 2.0 + MIT license text + each SDK's copyright. Use `LicensePlist`-style auto-generation in CI.
- **Confidence:** 90/100 — Settings audit verified absence.

### N37. License compliance — Apache 2.0 + MIT only (positive).

- **Severity:** n/a (positive)
- **Verification:** Two SDKs:
  - `firebase/firebase-ios-sdk` — Apache 2.0.
  - `PostHog/posthog-ios` — MIT.
  Both attribution-only, no copyleft. No GPL / AGPL contamination.
- **Confidence:** 94/100.

### N38. Logging — `os_log` / `Logger` audit.

- **Severity:** Low-Medium
- **Issue:** Found `Logger` usage at:
  - `Core/Analysis/ML/MLOrchestrator.swift:9` and 3 other ML files.
  - `Core/Config/ThermalManager.swift:13`.
  - `Modules/Dashboard/ViewModels/DashboardViewModel.swift:990`.
  None of these use `.privacy(.private)` markers. With Apple's unified logging, default privacy for `String` interpolations is `.public` in DEBUG and `.private` in RELEASE — but only with an explicit privacy hint. Without `\(value, privacy: .private)`, redaction depends on macros that are easy to miss.
- **Fix:** A grep-rule banning `Logger.info("\(value)")` without an explicit privacy modifier. Pass through `private` for any user-bound value (HRV, score, deviceId).
- **Confidence:** 78/100 — found Logger declarations; full call-site audit not exhaustive in this pass.

### N39. Telemetry on errors — stack traces and user-controlled paths.

- **Severity:** Low
- **Issue:** `PostHogManager.swift:131–137` captures `exception.callStackSymbols.prefix(15).joined(separator: "\n")` and `(error as NSError).domain` + `error.localizedDescription`. Some `localizedDescription` strings include URLs / file paths under `~/Documents/`. With `FileManager.default.temporaryDirectory` used in `WebExportViewModel.swift:37`, an export error's `localizedDescription` may include the user's name (because iOS paths sometimes include the iCloud user name in Documents container paths).
- **Fix:** A small `redactPath(_:)` utility that strips `/var/mobile/Containers/...` prefixes before sending to PostHog.
- **Confidence:** 75/100 — theoretical; runtime exposure depends on iOS path conventions.

### N40. Brazil LGPD Art. 8 — explicit consent for sensitive data. Same gap as GDPR Art. 9 (Pass 1 F8).

- **Severity:** High (BR launch)
- **Issue:** LGPD Art. 11 designates health data sensitive; Art. 8 requires "specific" consent. Same code-side gap as Pass 1 F8 — HK system prompt is not Laso's processing consent. New angle: LGPD Art. 14 also requires explicit guardian consent for under-18 (code-side: same `under_18` bracket bug as N13 above).
- **Fix:** Same explicit opt-in sheet as F8, plus Portuguese localisation (Pass 1 F14).
- **Confidence:** 88/100.

### N41. Brazil LGPD Art. 18 — data subject rights. Maps to Pass 1 F1 + F7.

- **Severity:** High (BR launch — covered by Pass 1 fixes)
- **Confidence:** 90/100.

### N42. Australia Privacy Principles (APP) — APP 12 access right.

- **Severity:** Medium (AU launch)
- **Issue:** APP 12 right to access. Same gap as GDPR Art. 15 (Pass 1 F7). New angle for AU: APP 11 mandates reasonable security; APP 8 cross-border disclosure requires the entity to ensure the recipient does not breach APPs.
- **Fix:** Documentation in PP that APP-11/12 are honored. Same export-data fix as F7.
- **Confidence:** 80/100.

### N43. Singapore PDPA — consent obligation (Sec 13).

- **Severity:** Medium (SG launch)
- **Issue:** PDPA Sec 13 requires obtaining and retaining consent at the point of collection. Same Pass 1 F5 gap (no PP at onboarding). PDPA additionally requires a designated Data Protection Officer and contact info — no DPO contact in repo.
- **Fix:** Same as F5; plus DPO email in PP.
- **Confidence:** 78/100.

### N44. South Africa POPIA — Sec 19 information processing security.

- **Severity:** Low-Medium (ZA launch)
- **Issue:** POPIA Sec 19 requires "appropriate, reasonable" security. Encrypted at rest + TLS in transit cover the basics. Sec 17 (data subject rights) overlaps GDPR Art. 15 / 17.
- **Fix:** Documented in PP. No new code.
- **Confidence:** 75/100.

### N45. Canada PIPEDA — ten privacy principles. Pass 1 noted; new specific gap.

- **Severity:** Low-Medium (CA launch)
- **Issue:** Principle 9 (Individual Access) requires providing access in a "reasonable time" and "minimum or no cost" — paywall-gated export (Pass 1 F7) violates this. Quebec's Law 25 additionally requires a designated Privacy Officer and DPIA-equivalent for new tech.
- **Confidence:** 80/100.

### N46. China PIPL — out of scope for now (no CN launch indication).

- **Severity:** n/a
- **Note:** Confirmed no CN launch path; PIPL would otherwise require separate consent framework + data localisation. Documented for completeness.
- **Confidence:** 90/100.

### N47. Engagement-sequence scheduler — Apple Guideline 4.5.4 (push for marketing).

- **Severity:** Medium (App Review)
- **Issue:** `Core/Notifications/EngagementSequenceScheduler.swift` schedules Day 1 / Day 2 / Day 3 onboarding pushes (`Copy+Notifications.swift:407–419+`). 4.5.4 forbids using local push for marketing without explicit user consent specific to marketing. The single notification permission prompt covers "alerts" but does not split critical-vital-alerts from engagement marketing.
- **Fix:** Pass 1 F20 split + a Copy update labelling the engagement sequence as "tips" rather than marketing. Or surface a dedicated "Allow tips" toggle.
- **Confidence:** 84/100.

### N48. Apple Pre-launch checklist — screenshots vs reality.

- **Severity:** Medium
- **Issue:** Screenshots in `screenshots/` (root) and `admin-panel/public/screenshots/` are untracked / staged (per the git status). App Store Connect screenshots must reflect actual UI. With v1 numerous hard blockers (bundle ID, manifest), screenshots taken now will likely be re-shot post-fix. Note: do NOT submit screenshots that show the loss-frame notification copy on lock screen or "Warning" insight text — both will trigger metadata reject.
- **Fix:** Re-shoot screenshots after Pass 1 + Pass 2 fixes; review each for clinical-language exposure.
- **Confidence:** 78/100.

### N49. Family Sharing of subscriptions — privacy of shared health data.

- **Severity:** Low (subscription-only sharing; no health-data sharing)
- **Issue:** `Laso.storekit` enables Family Sharing? Not directly verified in this pass, but if family sharing is on, the subscription is shared but the *user data* is not (each family member would launch the app, log in via their own anonymous Auth). No additional gap identified.
- **Confidence:** 70/100 — `Laso.storekit` not opened in this pass.

### N50. EU AI Act Art. 6 — "biometric categorisation" exclusion check.

- **Severity:** Low
- **Issue:** AI Act Art. 5 prohibits some biometric categorisation. HRV / cardiac patterns are physiological, not biometric in the AI Act sense (which scopes to identification). Reading `Core/Analysis/HealthRiskEngine.swift` and `Core/Analysis/CausalChainEngine.swift` showed no facial/voice/fingerprint biometric inference. CLEAR.
- **Confidence:** 88/100.

---

## Summary scorecard (NEW findings)

| Severity | Count | IDs |
|----------|-------|-----|
| Critical (App Store / launch hard block) | 4 | N1, N2, N3, N8 (widget portion) |
| High (legal / regulator) | 8 | N4, N5, N6, N11, N13, N16, N22, N40 |
| Medium | 14 | N7, N9, N10, N12, N14, N17, N18, N19, N20, N21, N23, N25, N26, N34 |
| Low / advisory | 14 | N15, N24, N27, N29, N31, N32, N33, N36, N38, N39, N42, N43, N44, N45, N47, N48, N49 |
| Pass / informational | 6 | N28, N35, N37, N46, N50, plus Sign-in-with-Apple verification |

### Top Now (P0 — must clear before any submission)
1. **N1** — fix `GoogleService-Info.plist` BUNDLE_ID + CloudKit container ID.
2. **N2** — author `LasoWidgets/PrivacyInfo.xcprivacy`.
3. **N3** — author and check in the Privacy Nutrition Label draft.
4. **N13** — block `under_18` from PostHog, plus raise age gate (overlaps Pass 1 F9).
5. **N5/N6/N4** — remove or soften the "crisis" / "emergency" / "Warning" / "marked decline" diagnostic-adjacent strings before EU + US launch.

### Top Pre-EU launch
6. **N16** — write the DPIA (`Docs/DPIA.md`).
7. **N11** — designate an EU Representative.
8. **N17** — author the breach-notification runbook (overlaps N7).
9. **N22** — re-write loss-frame notification copy.
10. **N9** — install scenePhase background-redaction overlay.
11. **N18** — document Schrems II / EU-US DPF reliance.

### Top Pre-Region launch
12. **N12** — India DPDP Sec. 11 nominee UI.
13. **N14** — confirm + document Firestore region for India.
14. **N40** — Brazil LGPD explicit consent + PT-BR localisation (Pass 1 F14 + this).
15. **N25/N26** — Apple 1.1.6 / 1.6 crisis resources in Journal + Risk.

### Pre-scale
16. **N23** — strip demographic user properties from PostHog identity graph.
17. **N24** — audit every `PostHogManager.shared.identify` caller for pseudonymous IDs.
18. **N36** — Acknowledgements view in Settings.
19. **N38** — `os_log` privacy-modifier hygiene rule.
20. **N39** — `redactPath` utility for error telemetry.

---

## Key NEW file references

- `/Users/primetrace/Desktop/RnD/HealthPulse/GoogleService-Info.plist` (line 12 — BUNDLE_ID mismatch)
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Config/AppSecrets.swift` (line 26 — CloudKit container)
- `/Users/primetrace/Desktop/RnD/HealthPulse/LasoWidgets/Info.plist` (no PrivacyInfo neighbour)
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Data/WidgetDataStore.swift` (line 83 — UserDefaults app-group)
- `/Users/primetrace/Desktop/RnD/HealthPulse/LasoWidgets/AnalysisWidgetProvider.swift` (lines 17, 24, 30 — Date system clock)
- `/Users/primetrace/Desktop/RnD/HealthPulse/Shared/CoachActionIntents.swift` (lines 23–24 — UserDefaults app-group)
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/ML/LLMInsightGenerator.swift` (lines 65–67 — "Warning … marked decline")
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/ClinicalIntelligence.swift` (lines 14, 60 — `crisis` enum + 180/120 threshold)
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/HealthRiskEngine.swift` (lines 365–366 — "medical emergency requiring urgent care")
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/RulesConfiguration.swift` (lines 247–249 — "seek emergency medical care")
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Tracking/AppAnalytics.swift` (lines 386, 394, 399–410, 434 — under_18 bracket + demographics → PostHog)
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Tracking/PostHogManager.swift` (lines 67–70 — identify caller surface)
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Notifications/Copy+Notifications.swift` (lines 178–187, 380–405 — loss-frame copy)
- `/Users/primetrace/Desktop/RnD/HealthPulse/App/ContentView.swift` (line 138 — scenePhase background, no redaction)
- `/Users/primetrace/Desktop/RnD/HealthPulse/Modules/Settings/Views/SettingsView.swift` (lines 384–429 — About section, no Acknowledgements)
- `/Users/primetrace/Desktop/RnD/HealthPulse/Modules/Journal/Views/Journal/JournalEntryView.swift` (no crisis-resources footer)
- `/Users/primetrace/Desktop/RnD/HealthPulse/Modules/Risk/Views/Risk/HealthRiskDetailView.swift` (no emergency-help CTA)

---

**Confidence: 88/100** — Two things drag the score down: (a) the App Store Connect Nutrition Label and Privacy Policy page text live outside the repo, so multi-jurisdiction findings (N3, N18, N20, N31) cannot be fully closed without reading those documents; (b) several findings (N4 EU AI Act, N5 EU MDR, N6 FDA SaMD, N15 DPDP SDF) are positioning- and threshold-driven — their applicability depends on App Store description copy, marketing claims, and user-base size, none of which are observable from source. Code-side findings (N1, N2, N9, N13, N22, N23, N25, N26, N36) are verified at file:line and confidence on those is 90–96.

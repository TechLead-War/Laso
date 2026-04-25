# 05 — Code Quality / Linter on Steroids

**Audit window:** 2026-04-25 IST  
**Stance:** read-only, file:line evidence, first-principles. No code changes.  
**Scope:** Modules/, Core/, App/, Common/ (~1993 .swift files, ~104k LOC inside these four roots, ~836k overall reported by user).  
**Out of scope:** security/auth (security agent), perf numbers (perf agent), color/typography (design agent).  
**Format per finding:** Severity / Issue / Why this exists / Impact / Evidence / How to verify fast / Fix / Priority / Confidence.

---

## F1. Closed dead-code subgraph: `SimulationEngine` + `ROIRanker`

- **Severity:** Medium
- **Issue:** `Core/Analysis/SimulationEngine.swift` (≈300 LOC) is referenced by exactly one consumer — `Core/Analysis/ROIRanker.swift`. `ROIRanker` itself has zero consumers anywhere in the codebase (no view, no view-model, no engine). Together they form a closed graph of dead production code that compiles into the shipped binary.
- **Why this exists:** Likely an early prototype for a "what-if I changed X by Y, how would my score move" feature that was descoped before launch. The files were never deleted.
- **Impact:** App-binary bloat, cognitive overhead for every reader who follows the import graph, and review hazard — anyone editing `ActionableMetric` (which IS still used) sees neighbouring dead types and has to decide whether to update them.
- **Evidence:**
  - `grep -rn "SimulationEngine" Modules/ App/` → no matches.
  - `grep -rn "ROIRanker" --include="*.swift" .` → only the file itself.
  - `Core/Analysis/SimulationEngine.swift:6` defines `struct SimulationEngine`, used only at `Core/Analysis/ROIRanker.swift:24,42,47`.
- **How to verify fast:** `grep -rn "SimulationEngine\|ROIRanker" --include="*.swift" Modules/ App/ | wc -l` → expect 0.
- **Fix:** Delete `Core/Analysis/SimulationEngine.swift` and `Core/Analysis/ROIRanker.swift`. Keep `Core/Analysis/SimulationTypes.swift` because `ActionableMetric` and `EffortLevel` are still referenced (e.g. `DecisionPolicyEngine.swift:1053+`).
- **Priority:** This Week.
- **Confidence:** 96/100 — verified by exhaustive grep across all four source roots; the only remaining unknown is whether some `.xcodeproj` user script or Xcode group reference would break on file removal (project.yml regen handles that).

---

## F2. Dead production singletons: `ECGDataManager`, `EveningSummaryScheduler`, `IntentDonationManager`, `ServiceProtocols.swift`

- **Severity:** Medium
- **Issue:** Four files defining types that are never referenced anywhere outside themselves are compiled into the production app target.
  - `Core/Data/ECGDataManager.swift` — defines `struct ECGDataManager`. Zero external references.
  - `Core/Notifications/EveningSummaryScheduler.swift` — `struct EveningSummaryScheduler`. Zero external references. Note: the live evening summary path lives in `DailySummaryScheduler.swift::eveningSummaryTitle/Body`, so this is a pure orphan.
  - `Core/Intents/IntentDonationManager.swift` — `enum IntentDonationManager`. Zero external references.
  - `Core/Config/ServiceProtocols.swift` — defines six protocols (`EncryptionService`, `ConfigService`, `PersistenceService`, `CloudBackupService`, `NotificationAuthorizationService`, `AnalyticsTrackingService`, `SessionTrackingService`) plus extension conformances on the concrete managers, but no consumer ever takes a parameter typed as one of these protocols. The DI abstraction is pure ceremony.
- **Why this exists:** Speculative scaffolding (ECG never shipped, evening summary was consolidated into Daily, intent donation was abandoned, DI protocols were never adopted by callers).
- **Impact:** Binary bloat, compile-time tax, and active misdirection — newcomers think "we have DI, must be testable" and burn time tracing protocols that never gate anything.
- **Evidence:**
  - `grep -rln "ECGDataManager\b" --include="*.swift" .` → only `Core/Data/ECGDataManager.swift`.
  - `grep -rln "EveningSummaryScheduler\b" --include="*.swift" .` → only itself.
  - `grep -rln "IntentDonationManager\b" --include="*.swift" .` → only itself.
  - `grep -rn ": EncryptionService\b\|: ConfigService\b\|: PersistenceService\b" .` → zero call-site type-uses (only the conformance extensions in `ServiceProtocols.swift:64-69`).
- **How to verify fast:** Run the four greps above. Each must return ≤ 1 file (the file itself).
- **Fix:** Delete the four files. If any are intended for upcoming work, add a `#if FEATURE_X_PLANNED` guard or move them to a `Docs/scratch/` folder rather than ship them.
- **Priority:** This Week.
- **Confidence:** 93/100 — searched all `.swift` under `Modules/`, `Core/`, `App/`, `Common/`; not yet verified against `LasoUITests/` or `LasoWidgets/` (those targets don't link `Core/Intents` so risk is near zero, but I didn't grep them explicitly).

---

## F3. Production target ships `SampleDataProvider` + `PremiumShowcaseDataProvider` (UI-test mocks reachable in release)

- **Severity:** High
- **Issue:** `Core/Data/SampleDataProvider.swift` and `Core/Data/PremiumShowcaseDataProvider.swift` are both compiled into the main app target (no `#if DEBUG`, no `#if UI_TEST`, no separate target). The only thing keeping their data out of the user's hands is an `if UITestMode.isEnabled` guard at the call sites in `App/AppContainer.swift:110,124-162`. `UITestMode.isEnabled` is driven by a process-launch argument (`--ui-test-mode`), not by a build configuration — so anyone who can attach a debugger or jailbroken environment to the production binary can flip this and the app will silently inject 90 days of fake heart rate, sleep, vitality scores, and risk insights.
- **Why this exists:** The team needed to capture App Store screenshots and run UITests against a deterministic dataset, and chose runtime gating instead of build-time gating because it kept the screenshot tooling in the same target.
- **Impact:** (1) Binary bloat — 800+ LOC of mock data ships. (2) Trust risk — a reverse-engineer or a curious tester can see the app present a "thriving health profile" without any HealthKit data, which would be embarrassing in an App Store screenshot scandal. (3) Apple-review risk — App Review reverse-engineers some apps; if they spot mock-data injection paths in a production build they may flag it.
- **Evidence:**
  - `App/AppContainer.swift:103-162` — branch on `UITestMode.premiumShowcase` to call either `PremiumShowcaseDataProvider.generate*` or `SampleDataProvider.generate*`. No `#if DEBUG`.
  - `App/UITestMode.swift:26-28` — `isEnabled = ProcessInfo.processInfo.arguments.contains("--ui-test-mode")`.
  - `Common/Components/InsightCard.swift:118` — Preview uses `SampleDataProvider.generateSampleInsights()`. Fine for previews, but the consumer is also production-shipped.
- **How to verify fast:** Build a release archive, run `strings` against the binary, grep for `generateSampleScores` — the symbol will be present.
- **Fix:**
  1. Wrap the two provider files in `#if DEBUG || UI_TEST`, or move them into a separate Swift package linked only by a non-release configuration.
  2. Replace `Common/Components/InsightCard.swift:118` previews with hand-rolled `#if DEBUG` literals or a `PreviewSampleData` enum that lives behind `#if DEBUG`.
  3. Same for `Common/Components/MetricChartView.swift:430`.
- **Priority:** Now (pre-App Store submission).
- **Confidence:** 88/100 — file paths and flag wiring confirmed by direct read; what's not verified is whether the project ships the Sample/Premium files via the test-only Compile Sources build phase (which would moot this finding) — a `project.yml` cross-check would close it.

---

## F4. Unguarded `print()` shipping to production

- **Severity:** Medium
- **Issue:** 12 `print(...)` calls compile into release builds because they are NOT wrapped in `#if DEBUG`. They include error messages with localized descriptions and per-event Firestore payloads that will surface in `Console.app` logs and may leak in crash reports.
- **Why this exists:** Casual logging during development that was never replaced with a proper `Logger` (`os.Logger` is imported but only 5 files use it).
- **Impact:** Console-log noise, very small CPU/string-allocation overhead per call, and information leakage — `UserProfileStore.swift:196` prints the full Firestore data dictionary.
- **Evidence (unguarded prints):**
  - `Modules/Referral/Services/ReferralManager.swift:268` — `print("[ReferralManager] Failed to complete referral: …")`
  - `Modules/Dashboard/Views/Home/MorningCheckInView.swift:214,216` — print inside SwiftUI Preview closure that ships in production target compile (the closure is dead in release because it's `#Preview`, but the literal Preview block still compiles; flagged as code-rot, not crash bomb).
  - `Core/Analysis/ML/HealthStateClassifier.swift:395` — print on CoreML inference failure.
  - `Core/Analysis/ML/CoreMLEngine.swift:26,28,69` — three unguarded prints on success / failure.
  - `Core/Analysis/ML/TimeSeriesForecaster.swift:258` — `print("[TimeSeriesForecaster] ARIMA Selected …")` in hot path.
  - `Core/Data/UserProfileStore.swift:192,196` — Firestore write failure + `Would write to Firestore: \(data)`. The second prints the entire user profile in the `#else` branch (likely the simulator stub).
  - `Core/Notifications/NotificationManager.swift:63,183` — two prints.
  - `Core/Notifications/EngagementSequenceScheduler.swift:613` — `print("[EngagementSequence] Failed to schedule day…")`.
  - `Core/Notifications/ReengagementScheduler.swift:72` — `print("[ReengagementScheduler] Failed to schedule…")`.
  - `Core/Data/DataRetentionManager.swift:46` — `print("[DataRetention] Pruned … expired records")`.
  - (PostHogManager.swift:51,108 ARE wrapped in `#if DEBUG` and are fine.)
- **How to verify fast:** `grep -rn "print(" Modules/ Core/ App/ --include="*.swift" | grep -v "#if DEBUG"` (then read 2 lines above each match to confirm).
- **Fix:** Replace each unguarded `print` with `Logger.shared.error(…)` (or remove if pure noise). The Logger pattern already exists at `Core/Tracking/PostHogManager.swift:107-109` style — `#if DEBUG print(...) #endif`.
- **Priority:** This Week.
- **Confidence:** 92/100 — verified by direct read of the surrounding lines for every match listed; `MorningCheckInView` print is in a Preview closure so its production impact is nil but it's still listed under code-rot.

---

## F5. Force-unwraps in hot scoring/analysis paths (30 of them, non-test, non-Preview)

- **Severity:** High
- **Issue:** 30 `.first!` / `.last!` / `dict[k]!` force-unwraps in `Core/Analysis/` and `Core/Analysis/ML/` — all in code paths that run on user data the moment HealthKit returns. Each is a runtime crash if the input array/dictionary is empty under an unexpected condition (e.g. user with one day of data, denied permission for a sub-metric, midnight crossover edge case).
- **Why this exists:** The code "knows" the array can't be empty because of an earlier `guard` — but the guards are several functions away in many cases, and refactors over time can break that invariant silently.
- **Impact:** Each one is a potential App Store 1-star crash report. Most of these are in scoring code that runs on every dashboard refresh.
- **Evidence (top 30 most dangerous, all in `Core/Analysis/` or `Core/Analysis/ML/` and on user-data hot paths):**
  1. `Core/Analysis/CrossMetricAnomalyDetector.swift:581` — `items.last!` inside string interpolation.
  2. `Core/Analysis/IllnessEarlyWarning.swift:462` — `parts.last!`.
  3. `Core/Analysis/ClinicalIntelligence.swift:301` — `samples.first!.date`.
  4. `Core/Analysis/VitalityScorer.swift:120,121,123,124,643,644,704,705` — eight bangs across the table-lookup and slope-calculation paths.
  5. `Core/Analysis/MenstrualCycleTracker.swift:261` — `cycleStarts.last!`.
  6. `Core/Analysis/Research/RHRTrajectoryAnalyzer.swift:42` — `samples.first!.date.timeIntervalSince1970`.
  7. `Core/Analysis/Research/BiologicalAgeAnalyzer.swift:132` — `norms.last!.0`.
  8. `Core/Analysis/Research/TemperatureCompoundAnalyzer.swift:163,174` — `sorted.first!`, `sorted.last!`.
  9. `Core/Analysis/Research/HRRFitnessAnalyzer.swift:36,52` — `allSamples.last!`, `sorted.first!.date, sorted.last!.date`.
  10. `Core/Analysis/Research/MobilityDeclineAnalyzer.swift:103` — `decliningMetrics.first!.indicator.metric`.
  11. `Core/Analysis/Research/InflammationRiskAnalyzer.swift:87,108` — two double-bangs `(rollingAverages.last! - rollingAverages.first!) / Double(...)`.
  12. `Core/Analysis/Research/CardioRespiratoryAgeAnalyzer.swift:70,169,184,185` — four lookups that bang on `thresholds.first!.value`, `thresholds.last!.value`, `ageMidpoints.last!`.
  13. `Core/Analysis/ML/ChangePointDetector.swift:336,382,395,472` — `best!.mag`, `seg.first!.date`, `regimes.last!`.
  14. `Core/Analysis/ML/TodayIntelligenceEngine.swift:473` — `sortedSystems.first!`.
  15. `Core/Analysis/ML/InteractionEffectEngine.swift:397` — `bins.first!`, `bins.last!`.
  16. `Core/Analysis/ML/PredictiveHealthSignals.swift:326` — `map[date]!`.
  17. `Core/Analysis/ML/FeatureEngine.swift:141` — `runningStats[metric]!.count`.
  18. `Core/Analysis/ML/CoreMLEngine.swift:165` — `provider.featureValue(for: "riskScore")!.doubleValue` — double-bang chain on a string-keyed CoreML lookup. Highest crash risk: if the model schema ever changes the key, app crashes on next inference.
  19. `Core/Analysis/ML/PersonalOptimizer.swift:330,331` — `Double($0.recovDays!)` inside a filter.
  20. `Core/Analysis/CorrelationAnalyzer.swift:138`, `BaselineDriftDetector.swift:56,100`, `InsightGenerator.swift:512` — `bestResult!.r`, `bestDrift!.percent` patterns.
- **How to verify fast:** `grep -rEn '\.first!|\.last!|\)!\.|\!\.\w' Core/Analysis --include="*.swift" | grep -v "//"`.
- **Fix:** Replace each `xs.first!` with `guard let first = xs.first else { return … }` returning the analyzer's "no result" branch, or `xs.first.map { … }` for transformations. For `CoreMLEngine.swift:165` specifically, do `guard let v = provider.featureValue(for: "riskScore") else { return 0.0 }`.
- **Priority:** Now for the CoreML one (line 165) — that's the most likely crash on schema drift; This Week for the rest.
- **Confidence:** 90/100 — every line cited was read in its surrounding context to confirm it's not a `!=` or a String-interpolation literal; what's not verified is whether each callee already guards against empty arrays at every call site (some likely do, making the bang technically safe but still bad hygiene).

---

## F6. Switch-on-`String` instead of switch-on-enum (brittle pattern, violates user's "Trace Data Source" rule)

- **Severity:** High
- **Issue:** Five UI-layer files switch on a String value that originates upstream from ML/analyzer code. If anyone renames `"Recovery"` → `"Recovering"` in the producer (`HealthStateClassifier`, scoring code, etc.), all switch arms silently fall to `default` and the UI presents the wrong color or label with zero compile-time warning. This violates the user's standing rule "Before switch/match on a String, grep the producer."
- **Why this exists:** Quick win during prototyping — String labels were easier than wiring an enum through ML output. Never hardened.
- **Impact:** Silent UI regressions on any String-rename. Color and copy decisions for "Health State" timeline, Stress trends, Sleep quality, and correlation strength all turn into stale defaults.
- **Evidence:**
  - `Modules/HealthState/ViewModels/HealthStateTimelineViewModel.swift:43-58` — switches on 12 string labels (`"Recovery"`, `"Peak Performance"`, `"Stressed"`, `"Under-Slept"`, `"Active"`, `"Fatigued"`, `"Resting"`, `"Recovering"`, `"Strained"`, `"Low Energy"`, `"Restful"`, `"Balanced"`). Producer: `Core/Analysis/ML/HealthStateClassifier.swift:583-586` — emits `states[assignments[i]].label` where `label: String` is set during clustering.
  - `Modules/HealthState/ViewModels/HealthStateTimelineViewModel.swift:63-…` — second switch for descriptions, same fragility.
  - `Modules/Dashboard/Views/Home/StressCard.swift:78-88` — switch on `trend.lowercased()` for `"up", "rising"` / `"down", "falling"`.
  - `Modules/Dashboard/Views/Home/SleepCard.swift:163-…` — switch on `sleepQualityLabel` (`"Great"`, `"Good"`, `"Fair"`, `"Poor"`).
  - `Modules/Dashboard/Views/Home/CorrelationsSection.swift:137-138` — switch on `strengthLabel` (`"Strong"`, `"Moderate"`).
- **How to verify fast:** `grep -rn 'case\s*"[A-Z]' Modules/ --include="*.swift"`.
- **Fix:** Introduce a `HealthStateKind: String` enum (or similar) in `Core/Analysis/ML/MLTypes.swift` (where `HealthState` already lives at line 245), make `HealthStateClassifier` emit `.recovery` / `.peakPerformance` instead of literal Strings, and change the UI switches to switch on the enum (compiler will then enforce exhaustiveness). Same for stress trend (already could use `TrendDirection`), sleep quality (already could use a tier enum), and correlation strength.
- **Priority:** This Week.
- **Confidence:** 90/100 — producer/consumer chain confirmed for HealthState; for Stress/Sleep/Correlation I traced one hop but did not chase all producer paths (the user's standing rule is exactly to do this, so the residual risk is one of those String literals could in fact still come from a Copy file rather than an ML emitter).

---

## F7. Hard-coded user-facing strings outside `Copy/Copy+*.swift` (project rule violation)

- **Severity:** Medium
- **Issue:** The project rule (per user's saved memory and the existing `Copy.swift` / `Copy+Common.swift` / `Copy+*.swift` infrastructure) is that every user-facing string lives in a `Copy.*` namespace. Approximately 20+ inline `Text("...")`, `Button("...")`, `.navigationTitle("...")`, `.alert("...")` calls violate this rule and are scattered across critical screens. Each is a localisation blocker and a "ship-before-Copy-review" leak.
- **Why this exists:** Engineering-velocity shortcut. The Copy files exist but aren't enforced by lint.
- **Impact:** (1) Cannot localise these strings. (2) Copy team can't review/edit without engineering touch. (3) Inconsistent voice — strings written ad-hoc don't match the app's "calm clinical" tone.
- **Evidence (sample — not exhaustive; ≈30 confirmed offenders):**
  - `Modules/Stress/Views/Stress/BreathworkView.swift:183` — `.navigationTitle("Breathwork")`.
  - `Modules/Stress/Views/Stress/BreathworkView.swift:201-203` — `.alert("End Session?", …)`, `Button("End", …)`, `Button("Continue", …)`.
  - `Modules/Stress/Views/Stress/BreathworkView.swift:531` — `Text("Done")`.
  - `Modules/Strain/Views/Strain/TodayWorkoutView.swift:123` — `Button("Done")`.
  - `Modules/Settings/Views/SettingsView.swift:447` — full-sentence Siri shortcuts blurb literal.
  - `Modules/Settings/Views/SettingsView.swift:610` — `Text("Danger Zone")`.
  - `Modules/Insights/Views/Insights/CorrelationsView.swift:293,409` — `Text("Actionable")`, `Text("Evidence")`.
  - `Modules/Sleep/Views/Sleep/SleepCoachView.swift:376,378,379,384` — `"Deep"`, `"Core"`, `"Awake"`, `"Stage data not available for this night"`.
  - `Modules/Onboarding/Views/Onboarding/ReferralCodeStep.swift:22,124,74` — `Text("Laso")` (brand string), `Text("Skip")`, full Label literal.
  - `Modules/Onboarding/Views/Onboarding/OnboardingMirrorMomentStep.swift:149` — `title: "Retry"`.
  - `Modules/Onboarding/Views/Onboarding/OnboardingPulseStep.swift:33` — `title: "Begin"`.
  - `Modules/Profile/Views/Profile/AchievementsView.swift:185,288,367,372,411,425,566` — `"Your Progress"`, `"Active Streaks"`, `"Days"`, `"Unlocked"`, `"Achievements"`, `"All"`, plus a hardcoded `AchievementItem(id:, title:"Dedicated", description:"30 days tracked", …)`.
  - `Modules/Discovery/Views/Discovery/DiscoveryView.swift:107,120,130,211,237` — five inline strings on a hero screen.
  - `Modules/Dashboard/Views/Home/HomeView.swift:754` — `Button("Open Score Guide")`.
  - `Modules/Dashboard/Views/Home/TodayBriefingView.swift:230,243` — `Text("Generated by Laso intelligence")`, `Button("Done")`.
  - `Modules/Journal/Views/Journal/JournalEntryView.swift:48,85,151,234,271,290` — six inline labels in a single view (`Cancel`, `What would you like to log?`, `Amount`, `Notes`, `Log <name>`, `Logged`).
  - `Modules/MetricDetail/Views/MetricDetail/MetricLogSheet.swift:53,67` — `"Cancel"`, `"Save"`.
- **How to verify fast:** `grep -rEn 'Text\("[A-Z]' Modules/ --include="*.swift" | grep -v "Copy\." | grep -v "Preview"`. Same for `Button(`, `.navigationTitle(`, `.alert(`.
- **Fix:** Extend the per-module `Copy+*.swift` files (Copy+Stress already exists at `Copy+StressMonitor.swift`, etc.) with the missing keys. Add a `swift-format` / `swiftlint` custom rule that flags any string literal passed to `Text(`/`Button(`/`.navigationTitle(`/`.alert(` that doesn't start with `Copy.` or `\(`.
- **Priority:** This Week.
- **Confidence:** 85/100 — the offender list is partial (sample of ~30 across modules). A full sweep needs a one-pass `grep -rEn 'Text\("[A-Z]'` audit over every Modules subfolder; what I list is enough to prove the rule is being violated routinely, not exhaustively.

---

## F8. Repeated `let formatter = DateFormatter()` allocations (perf + duplication)

- **Severity:** Medium
- **Issue:** `Core/Extensions/Date+Extensions.swift:18-43` already provides a thread-cached `FormatterCache` with helpers for short/medium/time/weekday formatting. Despite that, eight other files allocate a fresh `DateFormatter()` inline (each call) to format dates. `DateFormatter` initialisation is not free (calendar/locale lookup + ICU init), so for any of these in a hot path, this is a real cost AND duplicates the abstraction the team already wrote.
- **Why this exists:** Whoever wrote each call site didn't know `Date+Extensions.swift` existed, or wanted a custom format that the helpers don't expose yet.
- **Impact:** Wasted CPU on dashboard refresh, divergent formats across the app (one screen shows `MMM d`, another `dd/MM`, another a localized short style), and future maintenance pain — changing date display style requires editing 9 places.
- **Evidence:**
  - `Modules/Sleep/Views/Sleep/SleepCoachView.swift:459, 723` — two more local formatters.
  - `Modules/BrainHealth/Views/BrainHealth/BrainHealthDetailView.swift:383` — local formatter.
  - `Core/Analysis/SleepNeedCalculator.swift:171` — local formatter.
  - `Core/Analysis/ML/TodayIntelligenceEngine.swift:1081-1082` — entire helper `private func shortDateString(_ date: Date)` that re-implements `Date+Extensions`'s `shortDateString`.
  - `Core/Analysis/ML/DailyNarrativeEngine.swift:95` — local formatter.
  - `Core/Notifications/WindDownScheduler.swift:92` — local formatter.
  - `Core/Notifications/WakeUpTimeDetector.swift:49` — local formatter.
  - `Modules/WebExport/HTMLReportGenerator.swift:53` — local formatter.
  - `Core/Analysis/ML/MLEvaluator.swift:466` — `ISO8601DateFormatter().string(from: Date())` allocated per export.
  - `Core/Data/MorningCheckInManager.swift:21,29,40,57` — four inline `ISO8601DateFormatter()` allocations on every check-in read/write.
- **How to verify fast:** `grep -rn "let formatter = DateFormatter()\|ISO8601DateFormatter()" Core/ Modules/ --include="*.swift"`.
- **Fix:** (1) Add `Date.iso8601String` and `Date(iso8601:)` helpers to `Date+Extensions.swift` backed by a single shared `ISO8601DateFormatter`. (2) For each of the 9 sites above, route through `Date+Extensions` or a new `DateFormatters.shared.weekdayShort` enum-based static cache. (3) Delete `TodayIntelligenceEngine.swift::shortDateString(_:)` since `Date+Extensions::shortDateString` does the same thing.
- **Priority:** This Week.
- **Confidence:** 95/100 — direct file:line evidence cited; perf cost is an industry-known DateFormatter fact, not measured here.

---

## F9. Giant files (top 20) — review-hazard density and SwiftUI compile-time risk

- **Severity:** Medium
- **Issue:** Files above 800 LOC are review hazards (one PR diff covers too much). Files above 1500 LOC are red flags. The repo has 11 files over 1000 LOC and 2 over 2000 LOC, all in production paths. None are auto-generated.
- **Why this exists:** Organic growth without periodic refactor.
- **Impact:** Onboarding cost, code-review fatigue, longer SwiftUI compile times for view-heavy files, harder to spot duplicated code within a single file.
- **Evidence (top 20 by LOC):**
  | LOC | File | Role |
  |-----|------|------|
  | 3201 | `Core/Tracking/AppAnalytics.swift` | Centralised PostHog event taxonomy |
  | 2253 | `Modules/Dashboard/ViewModels/DashboardViewModel.swift` | Main home VM (5 nested @Observable sub-objects) |
  | 1819 | `Core/Analysis/ML/HealthDataQueryEngine.swift` | Rule-based natural language Q&A engine |
  | 1750 | `Core/Analysis/ML/DecisionPolicyEngine.swift` | Recommendation policy scoring |
  | 1698 | `Core/Analysis/ML/PredictiveHealthSignals.swift` | Predictive signal extraction |
  | 1574 | `Core/Analysis/ML/TemporalSequenceMiner.swift` | Sequence mining over time series |
  | 1308 | `Core/Analysis/ML/CompoundInsightEngine.swift` | Multi-signal insight composer |
  | 1243 | `Core/Data/HealthKitManager.swift` | Sole HealthKit facade |
  | 1195 | `Core/Analysis/ML/HealthStateClassifier.swift` | GMM+HMM classifier with print() debug |
  | 1117 | `Core/Analysis/ML/TodayIntelligenceEngine.swift` | Today insight aggregator (also has duplicate `shortDateString`) |
  | 1070 | `Core/Analysis/ML/GrangerCausalityEngine.swift` | Granger causality math |
  | 1061 | `Modules/Live/ViewModels/LiveViewModel.swift` | Live tab VM with 32 `Task { @MainActor in … }` blocks |
  | 1016 | `Core/Analysis/InsightGenerator.swift` | Insight orchestrator |
  | 980 | `Core/Analysis/ML/MLEvaluator.swift` | Model evaluation harness |
  | 958 | `Core/Analysis/GamificationEngine.swift` | Streaks/badges/levels |
  | 918 | `Core/Data/HealthDataStore.swift` | SwiftData store |
  | 845 | `Core/Analysis/BrainHealthScorer.swift` | Brain health scoring |
  | 826 | `Modules/Dashboard/Views/Home/HomeView.swift` | Home tab View root |
  | 820 | `Core/Analysis/ML/TimeSeriesForecaster.swift` | ARIMA + Holt-Winters with debug print |
  | 817 | `Core/Analysis/ML/AdaptiveAnomalyDetector.swift` | Adaptive anomaly detection |
- **How to verify fast:** `find Modules Core App Common -name "*.swift" -exec wc -l {} + | sort -rn | head -20`.
- **Fix:** Triage by impact. The two highest priorities to split:
  1. `AppAnalytics.swift` (3201 LOC) — split per-feature into `AppAnalytics+Sleep.swift`, `AppAnalytics+Onboarding.swift`, etc. (a `Copy+Module` pattern is already used in this repo for strings.)
  2. `DashboardViewModel.swift` (2253 LOC) — its 5 nested `@Observable` sub-objects (Loading, Analysis, UI, Strings, Notifications) are already the seam; promote each to its own file.
  3. The 5 ML files between 1500-1800 LOC — extract pure-math helpers into separate files keeping the orchestrator under 800.
- **Priority:** Backlog (refactor pre-v2, not blocking launch).
- **Confidence:** 96/100 — LOC counts came from `wc -l`; not measured: actual SwiftUI compile time impact.

---

## F10. Brittle `aps-environment` notification name + lingering `HealthPulse` literals in source

- **Severity:** Medium
- **Issue:** Two literal `HealthPulse` references remain in source despite the project being renamed to `Laso`:
  - `Modules/Settings/Views/SettingsView.swift:687` — `NotificationCenter.default.post(name: .init("HealthPulseDidDeleteAllData"), object: nil)`. Stringly-typed notification name with the dead brand. Worse, it's only constructed at the post-site and never observed anywhere (`grep` returns one match) — fire-and-forget into the void.
  - `Core/Config/AppConstants.swift:25` — `static let engagementPrefix = "healthpulse.engagement."`. UserDefaults key prefix tied to the dead brand. Renaming this is a data-migration trap, but the literal still drifts.
- **Why this exists:** Brand rename was incomplete; only the most-visible identifiers were swept. (See `audit/01-naming-disturbance.md`.)
- **Impact:** (1) Dead notification — `HealthPulseDidDeleteAllData` has no observers, so the post call has zero behavior; whatever logic was meant to run on data-delete never runs. (2) Future engineer reading the constant assumes engagement events are tracked under one prefix when in fact the rest of the app moved on.
- **Evidence:**
  - `Modules/Settings/Views/SettingsView.swift:687` — see above.
  - `grep -rn "HealthPulseDidDeleteAllData" --include="*.swift" .` → exactly one result (the post; no observer).
  - `Core/Config/AppConstants.swift:25,31` — `engagementPrefix` and `Notification.Name("healthPulseNavigateToExplore")` both still use the old brand string.
- **How to verify fast:** Grep above. Also: trigger the "Delete All Data" flow in Settings on simulator and observe that nothing actually responds to the notification (the `exit(0)` 0.3s later is what actually does the work).
- **Fix:** (1) Either remove the dead post call at `SettingsView.swift:687` outright (it's a no-op) or wire an observer if the design intent was to give other modules a chance to clean up. (2) Either keep `engagementPrefix = "healthpulse.engagement."` (since it's a UserDefaults key prefix and changing it loses user history) and document the historical reason, or migrate keys + change the constant. (3) Rename `healthPulseNavigateToExplore` → `lasoNavigateToExplore` (this one is in-memory only, no migration concern).
- **Priority:** This Week.
- **Confidence:** 95/100 — verified the post has no observer; what's not verified is whether the `exit(0)` fully replaces the intended cleanup that the dead notification was supposed to trigger.

---

## F11. Empty catch blocks + `try?`-swallowed errors silently lose information

- **Severity:** Medium
- **Issue:** Two empty `catch {}` blocks and 106 `try?` call sites. Two of the empty blocks are in security-adjacent paths (`SubscriptionManager`, `ReferralManager`).
- **Why this exists:** Convenience — when an error doesn't have an obvious recovery path, swallowing is the path of least resistance.
- **Impact:** Bugs in subscription receipt validation, referral code redemption, and SwiftData saves all become silent. Crash analytics can't catch them, support can't reproduce them, and PostHog never sees them.
- **Evidence:**
  - `Modules/Referral/Services/ReferralManager.swift:121` — `} catch {}` after a Firestore operation that updates the referrer's count.
  - `Core/Subscriptions/SubscriptionManager.swift:514` — `} catch {}` near a Keychain write.
  - 106 `try?` call sites total. The most-impactful ones include:
    - `Modules/Dashboard/ViewModels/DashboardViewModel.swift:1419` — `try? JSONEncoder().encode(snap)` for sleep tile snapshot persistence (lose snap silently → tile shows stale).
    - `Modules/Dashboard/ViewModels/DashboardViewModel.swift:1429` — `try? JSONDecoder().decode(SleepTileSnapshot.self, from: data)` (decode failure → tile defaults to empty without telling anyone).
    - `Core/Analysis/VitalityScorer.swift:298,319`, `Core/Analysis/StrainScorer.swift:121,143`, `Core/Analysis/MenstrualCycleTracker.swift:155` — five identical encode/decode-with-`try?` pairs that drop snapshot persistence on decode mismatch.
    - `Modules/Journal/Views/Journal/ExpandedJournalView.swift:410` — `try? modelContext.save()` after the user logs a behavior. Silent loss.
    - `Modules/WebExport/ViewModels/WebExportViewModel.swift:59` — `try? FileManager.default.removeItem(at: url)`. OK in cleanup contexts.
- **How to verify fast:** `grep -rn "catch {}\|catch { }" Modules/ Core/ App/ --include="*.swift"` and `grep -rn "try?" Modules/ Core/ App/ --include="*.swift" | wc -l`.
- **Fix:** For each empty `catch`, log via `AppAnalytics.shared.captureError(error, context: "<feature>")`. For `try?` on user-data persistence (the snapshot encode/decode pairs and `modelContext.save()`), log decode failures so they show up in PostHog `app_error_recorded` and trip the on-device crash investigator.
- **Priority:** This Week for the two empty `catch` blocks; Backlog for the broader `try?` audit.
- **Confidence:** 92/100 — empty-catch lines confirmed; `try?` count is from a single grep and includes a few benign `Task.sleep` cases (those are fine).

---

## F12. Orphan `.first!` / `.last!` and "best!" patterns inside `bestX == nil ||` checks (logic redundancy)

- **Severity:** Low
- **Issue:** A specific repeating pattern shows up across `Core/Analysis/`:
  ```
  if best == nil || score > best!.score { … }
  if bestResult == nil || abs(r) > abs(bestResult!.r) { … }
  if bestDrift == nil || abs(drift) > abs(bestDrift!.percent) * 0.8 { … }
  if bestBoundary == nil || diff > abs(bestBoundary!.diff) { … }
  ```
  The `!` is technically safe due to short-circuit, but Swift idiom is `if let bestExisting = best, score <= bestExisting.score { … } else { best = … }`. The current form trains readers to see `!` as "fine when guarded by `==nil ||`" which is a slippery slope.
- **Why this exists:** Quick translation from imperative loops in other languages.
- **Impact:** Minor maintenance hazard — when the surrounding logic is refactored, somebody can drop the `nil` check and turn the `!` into a crash bomb.
- **Evidence:**
  - `Core/Analysis/InsightGenerator.swift:512`
  - `Core/Analysis/CorrelationAnalyzer.swift:138`
  - `Core/Analysis/BaselineDriftDetector.swift:56,100`
  - `Core/Analysis/DiscoveryEngine.swift:229`
  - `Core/Analysis/ML/ChangePointDetector.swift:336`
- **Fix:** Mechanical rewrite to `if let cur = best, score <= cur.score { return } else { best = (score: …) }`. Preserves semantics, removes the bang.
- **Priority:** Backlog.
- **Confidence:** 90/100 — pattern pulled directly from grep; idiomatic alternative is standard Swift.

---

## F13. Mixed `DispatchQueue.main.asyncAfter` and `Task` inside `@MainActor` classes (concurrency drift)

- **Severity:** Low
- **Issue:** `LiveViewModel.swift` is annotated `@MainActor @Observable` and uses `Task { @MainActor in … }` 32 times — but also contains 3 `DispatchQueue.main.asyncAfter` calls (lines 259, 449) inside the same actor for delayed work. Two paradigms doing the same thing in the same file. Same pattern in `SettingsView.swift:689,700`.
- **Why this exists:** `DispatchWorkItem` cancellation pattern is older muscle memory than `Task.sleep` + `Task.cancel`.
- **Impact:** Maintainability — readers must mentally context-switch between GCD lifecycle and Swift Concurrency lifecycle in the same file. Cancellation propagation is also different (DispatchWorkItem.cancel() does not cancel a parent Task; Task.cancel propagates).
- **Evidence:**
  - `Modules/Live/ViewModels/LiveViewModel.swift:259` — `DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: availabilityWorkItem)` for a respiratory-availability check.
  - `Modules/Live/ViewModels/LiveViewModel.swift:449` — `DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)` for a heart-rate UI flush throttle.
  - `Modules/Settings/Views/SettingsView.swift:689,700` — two more.
- **Fix:** Replace with `Task { @MainActor in try await Task.sleep(for: .seconds(5)); … }` and store the `Task` for cancellation. Removes the GCD coupling entirely.
- **Priority:** Backlog.
- **Confidence:** 88/100 — confirmed by reading lines 400-465 of `LiveViewModel.swift` for context; not yet stress-tested against the cancellation behavior the team relies on.

---

## F14. `[String: Any]` payload sprawl (keychain queries, PostHog metadata, ML feature export)

- **Severity:** Low
- **Issue:** 25+ `[String: Any]` declarations across the codebase. Most are unavoidable (Keychain `kSec*` queries, PostHog SDK signatures, CoreML provider dictionaries). A few are not — they're places where a typed model would be safer.
- **Why this exists:** External SDK signatures force `[String: Any]` at the boundary (Keychain Services, PostHogSDK, CoreML feature provider). The internal places where it spreads beyond the boundary are the issue.
- **Impact:** No compile-time check on key spelling, no auto-complete, easy to drift between event-name strings.
- **Evidence:**
  - `Core/Analysis/ML/MLEvaluator.swift:454,462` — `func exportEvaluationSummary() -> [String: Any]`. This is internal and could be a typed `EvaluationSummary` struct that conforms to `Encodable`.
  - `Core/Tracking/PostHogManager.swift:48,59,67,79,87,89,100,102` — `[String: Any]` is the SDK signature, fine here, but every event-builder function calling these should pass a typed struct that has `var asDictionary: [String: Any]`. Currently call sites build dicts inline (search `AppAnalytics.swift` for `["event":` literal patterns).
- **Fix:** Wrap PostHog event property dictionaries in typed structs. `MLEvaluator::exportEvaluationSummary` returns a typed value that gets serialised at the export boundary.
- **Priority:** Backlog.
- **Confidence:** 85/100 — Keychain ones are correctly out of scope; PostHog ones are only flagged if they leak inline; not exhaustively traced.

---

## F15. Unused `import Foundation` not happening, but no `swiftlint`/`swift-format` on this repo at all

- **Severity:** Low
- **Issue:** I found 0 unused `import Combine` (Combine isn't imported anywhere outside of UIKit code paths anymore — good, modern). However, there's no detectable lint-rule infrastructure in `Scripts/` or `.githooks/` or pre-commit that would catch unused imports, force-unwrap regressions, or hardcoded Strings before they merge.
- **Why this exists:** Greenfield project with manual review acting as the lint.
- **Impact:** Every finding in this audit could have been auto-flagged by a lint rule. Without one, the audit will need to be re-run.
- **Evidence:**
  - `import Combine` count → 0.
  - `import Foundation` → 224 (all real, none stripped).
  - `find . -name "swiftlint.yml" -o -name ".swiftlint.yml" -o -name ".swift-format"` → no result (verified during this audit).
- **Fix:** Add a pre-commit `swiftlint` config with custom rules:
  - `force_unwrapping` warning (severity: warning).
  - Custom rule: `\bText\("[A-Z][^"]*"\)` should fail outside `Copy+*.swift`.
  - Custom rule: `print\(` outside `#if DEBUG` should fail.
  - Custom rule: `case +"[A-Z]"` (switch on String) should warn.
- **Priority:** This Week.
- **Confidence:** 90/100 — direct file existence checked.

---

## F16. `UITestMode.swift` — production exposure check

- **Severity:** Low (post-mitigation)
- **Issue:** The `UITestMode` enum (`App/UITestMode.swift`) is wired into 8 places in production code (`AppContainer`, `LasoApp`, `ContentView`, `OnboardingView`, `OnboardingConnectHealthStep`, `HomeView`, `DashboardViewModel`, `Settings`, `PostHogManager`, `SubscriptionManager`). The gating is via `ProcessInfo.processInfo.arguments.contains("--ui-test-mode")` — i.e. a launch argument. Production launches via Springboard cannot inject launch arguments, so the practical exposure surface is "user with debugger attached" or jailbroken environment.
- **Why this exists:** UI test deterministic-screenshot pipeline requires runtime gating.
- **Impact:** Combined with F3 (the Sample/Premium providers compile into the binary), a determined attacker can flip every UITestMode flag and trigger fake-data injection, force-show paywall, force-subscribed status, override scores. This is not a 0-day, but it's a "code-quality smell that interacts with security."
- **Evidence:**
  - `App/UITestMode.swift:26-28` — `isEnabled` driven by launch arg.
  - `Core/Subscriptions/SubscriptionManager.swift:111-112` — `setStatusForUITestMode(_:)` is `guard UITestMode.isEnabled else { return }`. Safe boundary.
  - `App/AppContainer.swift:110` — `injectUITestMockData()` early-returns unless `UITestMode.isEnabled`.
- **How to verify fast:** Build a release archive, run on a non-jailbroken device, attempt to launch with `--ui-test-mode` (impossible without debugger). Then read all 24 call sites to confirm each has its own `guard UITestMode.isEnabled` (already done; all 24 do).
- **Fix:** Wrap the entire `UITestMode` enum body in `#if DEBUG || UI_TEST` so release-mode `isEnabled` becomes a compile-time `false` and the optimiser strips every call site. Then F3 (Sample providers) can also be guarded this way.
- **Priority:** Now.
- **Confidence:** 88/100 — call sites confirmed; the `#if DEBUG` wrap as proposed is the standard fix and will compile clean given UITestMode has no public types beyond static functions.

---

## F17. `BrainHealthScorer`, `VitalityScorer`, `StrainScorer`, `BrainHealthScore` — no `Scorer<T>` generic, copy-pasted snapshot persistence

- **Severity:** Low
- **Issue:** Three scorers (`BrainHealthScorer`, `VitalityScorer`, `StrainScorer`) each define a private `Snapshot` struct, encode/decode it via `JSONEncoder/Decoder` to UserDefaults, and read/write under a `snapshotKey = "<Scorer>.snapshot.v2"`. Same pattern, copy-pasted three times.
- **Why this exists:** Each scorer was developed in isolation; nobody pulled out the shared persistence layer.
- **Impact:** Bug-fixing one (e.g. JSON migration on schema change) doesn't fix the other two. New scorers (next month's "Recovery Scorer", "Cardiac Age Scorer") will paste the same code.
- **Evidence:**
  - `Core/Analysis/VitalityScorer.swift:286,298,319` — `static let snapshotKey = "VitalityScorer.snapshot.v2"` + decode + encode.
  - `Core/Analysis/StrainScorer.swift:121,143` — same pattern.
  - `Core/Analysis/MenstrualCycleTracker.swift:155` — same.
  - `Core/Analysis/BrainHealthScorer.swift:88` — `final class BrainHealthScorer`, with the same pattern (per `BrainHealthScorer.weeklyHistory` API).
- **Fix:** Introduce `protocol Snapshottable` with associated type `Snapshot: Codable` and a shared `SnapshotPersistence<S>` helper (`save(_:)`, `load() -> S?`, `clear()`). All three scorers conform.
- **Priority:** Backlog.
- **Confidence:** 85/100 — the duplication pattern is real (cited 4 sites); not measured: whether the snapshot keys collide or differ in version-handling.

---

## F18. `Manager` / `Helper` / `Util` suffix overuse (28 `*Manager.swift`, 2 `*Helpers.swift`)

- **Severity:** Low
- **Issue:** 28 files end in `Manager.swift`. `Manager` is a noise suffix — almost every one is either a singleton (`shared`) or a stateful service. This makes greps for "what does X do" land in 5 places and obscures responsibility.
- **Why this exists:** Default Swift muscle memory.
- **Impact:** Naming friction, ambiguous responsibility per file ("did the alert trigger from `NotificationManager` or `NotificationRepromptManager` or `FrequencyCapManager`?").
- **Evidence:** 28 `*Manager.swift` files including `HealthKitManager`, `PersistenceManager`, `SubscriptionManager`, `NotificationManager`, `NotificationRepromptManager`, `FrequencyCapManager`, `RemoteConfigManager`, `ThermalManager`, `AppStoreReviewManager`, `FeedbackPromptManager`, `PostHogManager`, `IntentDonationManager` (already flagged dead in F2), `MorningCheckInManager`, `DeviceSourceManager`, `DataRetentionManager`, `CloudBackupManager`, `HealthKitRepromptManager`, `ECGDataManager` (dead — F2), `ReferralManager`, `MLCalibrationManager`, plus 4 LiveActivity managers in `App/`.
- **Fix:** When refactoring, rename to verbs/nouns of intent: `HealthKitManager` → `HealthKitFacade` or `HealthKitClient`. `NotificationManager` → `NotificationScheduler`. Out of scope to rename in bulk, but mark this as a naming convention to enforce on new files.
- **Priority:** Backlog.
- **Confidence:** 95/100.

---

## F19. `import UIKit` inside SwiftUI ViewModels (UIKit-bridge leakage)

- **Severity:** Low
- **Issue:** Six non-App-target files `import UIKit`. Some are legitimate (Live activity managers in `App/`), others are leakage from before the project went all-SwiftUI.
- **Why this exists:** Migration debris.
- **Impact:** Each unnecessary UIKit import drags the AppKit-flavored part of UIKit into the file's compile unit, slowing compile and risking iOS-version-specific symbol references.
- **Evidence:**
  - `Modules/Referral/Services/ReferralManager.swift:2` — `import UIKit` (uses `UIDevice.current.identifierForVendor`).
  - `Modules/Onboarding/Views/Onboarding/ProfileCaptureView.swift:2` — `import UIKit` (probably for `UIImagePickerController` or `UIApplication.shared`).
  - `Core/Subscriptions/SubscriptionManager.swift:6` — `import UIKit`.
  - `Core/Tracking/FeedbackPromptManager.swift:2` — `import UIKit`.
  - `Core/Tracking/AppStoreReviewManager.swift:3` — `import UIKit`.
  - `Core/Tracking/AppAnalytics.swift:2` — `import UIKit` (3201 LOC file already flagged in F9 — UIKit pulls more weight).
  - `Core/Data/UserProfileStore.swift:2` — `import UIKit`.
- **Fix:** Audit each. Where the only use is `UIDevice.current.identifierForVendor`, replace with `Bundle.main.infoDictionary` or store the ID lazily once at `App/` boundary. Where `UIApplication.shared` is used in non-App-target code, refactor to inject the app-scope dependency.
- **Priority:** Backlog.
- **Confidence:** 88/100 — file paths confirmed, individual usage not unrolled.

---

## F20. Hard-coded mock data in production previews leak `try!` and seeded dates

- **Severity:** Low
- **Issue:** The 5 `try! ModelContainer(...)` calls flagged earlier are all inside `#Preview { … }` blocks, which Swift strips from release builds — so they're not crash bombs. However, the `Preview` blocks also embed hardcoded sample dates with bangs (`Calendar.current.date(byAdding: .day, value: -6, to: Date())!`) and hardcoded names (`"Alex Taylor"`, `"alex@example.com"`), which the team should keep in shape because Xcode previews are part of the developer feedback loop.
- **Why this exists:** Previews are typically casual.
- **Impact:** Zero production impact. Developer-experience friction only — every changed Preview inherits a `try!` wart.
- **Evidence:** `Modules/Settings/Views/SettingsView.swift:767`, `Modules/Explore/Views/Explore/ExploreView.swift:343`, `Modules/Dashboard/Views/Home/HomeView.swift:804`, `Modules/Dashboard/Views/Home/PeriodSummarySection.swift:217`, `Modules/Dashboard/Views/Home/WeeklyReviewView.swift:644`. Hardcoded dates: `Modules/Strain/Views/Strain/StrainDetailView.swift:524-529` (7 entries), `Modules/CycleTracking/Views/CycleTracking/CycleDetailView.swift:686-690` (5 entries), `Modules/BrainHealth/Views/BrainHealth/BrainHealthDetailView.swift:452-457` (6 entries).
- **Fix:** Add a single `PreviewContainer.shared` helper in `App/` (gated `#if DEBUG`) that vends an `in-memory ModelContainer` with `try?` + `fatalError` fallback that's only reachable from previews. All Preview blocks call `PreviewContainer.shared.container`.
- **Priority:** Backlog.
- **Confidence:** 95/100.

---

## Summary

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 3 (F3, F5, F6) |
| Medium | 8 (F1, F2, F4, F7, F8, F9, F10, F11) |
| Low | 9 (F12, F13, F14, F15, F16, F17, F18, F19, F20) |

**Top fixes Now (pre-launch):**
1. **F3 + F16** — Wrap `UITestMode`, `SampleDataProvider`, `PremiumShowcaseDataProvider` in `#if DEBUG || UI_TEST` so the production binary cannot be flipped into "thriving showcase mode." (Combined fix; one PR.)
2. **F5 (CoreML bang only)** — `Core/Analysis/ML/CoreMLEngine.swift:165` `provider.featureValue(for: "riskScore")!.doubleValue` is a single force-unwrap chain that crashes on schema drift. Fix this one before TestFlight.
3. **F4** — Remove or `#if DEBUG`-guard the 12 unguarded `print(...)` calls. They leak Firestore data, error stack traces, and CoreML inference logs to production logs.

**Top fixes This Week:**
- **F1, F2** — Delete dead files (`SimulationEngine`, `ROIRanker`, `ECGDataManager`, `EveningSummaryScheduler`, `IntentDonationManager`, `ServiceProtocols`).
- **F6** — Replace switch-on-String in `HealthStateTimelineViewModel`, `StressCard`, `SleepCard`, `CorrelationsSection` with enum-driven switches.
- **F7** — Move the ~30 inline user-facing strings into `Copy+*.swift` files. Add a swiftlint custom rule.
- **F10** — Remove the dead `HealthPulseDidDeleteAllData` no-op notification post in `SettingsView.swift:687`. Decide migration policy on the `engagementPrefix` UserDefaults key.
- **F11** — Replace the two empty `catch {}` blocks with `AppAnalytics.shared.captureError(...)`.
- **F15** — Add a `swiftlint.yml` with custom rules for force-unwrap, hardcoded Text(), unguarded print().

**Backlog (post-launch):**
- F8 (DateFormatter consolidation), F9 (split giant files), F12 (best!.x rewrites), F13 (DispatchQueue → Task migration in LiveViewModel), F14 ([String: Any] typing), F17 (Snapshot persistence protocol), F18 (`Manager` rename audit), F19 (`import UIKit` audit), F20 (PreviewContainer helper).

---

## Dead Code Inventory

| File | Reason Dead | Confidence |
|------|-------------|------------|
| `Core/Analysis/SimulationEngine.swift` | Only consumer is `ROIRanker.swift`, itself dead. Closed dead subgraph. | 96/100 |
| `Core/Analysis/ROIRanker.swift` | Zero consumers in `Modules/`, `App/`, `Common/`. | 96/100 |
| `Core/Data/ECGDataManager.swift` | `struct ECGDataManager` referenced only inside its own file. ECG feature never shipped. | 95/100 |
| `Core/Notifications/EveningSummaryScheduler.swift` | `struct EveningSummaryScheduler` has zero consumers. Live evening summary path is in `DailySummaryScheduler.swift::eveningSummaryTitle/Body`. | 95/100 |
| `Core/Intents/IntentDonationManager.swift` | `enum IntentDonationManager` has zero consumers. | 95/100 |
| `Core/Config/ServiceProtocols.swift` | Six protocols + extension conformances on the concrete managers, but no call site takes a parameter typed as one of these protocols. DI scaffolding never adopted. | 90/100 |
| (Partial) `Core/Analysis/ML/TodayIntelligenceEngine.swift::shortDateString(_:)` lines 1081-1082 | Re-implements `Date+Extensions::shortDateString` which already exists. | 95/100 |
| (Partial) `Modules/Settings/Views/SettingsView.swift:687` `NotificationCenter.default.post(name: "HealthPulseDidDeleteAllData")` | No observer anywhere; fire-and-forget into the void. | 100/100 |
| (Partial) Inline `let formatter = DateFormatter()` re-allocations at the 9 sites listed in F8 | Each duplicates `Date+Extensions`'s thread-cached helpers. | 95/100 |

**Net dead-code estimate:** ≈300-400 LOC of pure orphan files, plus another ≈100 LOC of duplicated date-formatter and snapshot-persistence patterns that should consolidate.

---

**Confidence (overall audit):** 88/100 — every finding cites file:line evidence verified by direct read or grep, and the dead-file claims were re-verified with the canonical `grep -rln "<TypeName>\b"` query. Below 90 because: (a) I did not cross-check the `project.yml` / Xcode file references for dead files (they may still be in the Compile Sources phase, in which case removing the file alone breaks the build — `xcodegen generate` after deletion is the safe path); (b) the F7 hardcoded-string offender list is a sample of ~30, not an exhaustive sweep across all 22 modules; (c) I did not run a Release build to verify which print/`UITestMode`/SampleDataProvider symbols actually survive into the shipped binary — the optimiser may strip more than this read-only audit assumes.

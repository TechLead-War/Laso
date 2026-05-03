# HealthPulse iOS — Code Violations Audit

Scope: `App/`, `Core/`, `Common/` (excluding `Common/Copy/`), `Modules/` (excluding `Copy+*.swift`), `Shared/`, `LasoWidgets/`. Worktrees, build, Pods, Tests, UITests excluded. ~802 Swift files scanned.

## Summary counts
- Bucket 1 duplicate-helper groups: 8 (total duplicate definitions: ~28 across helpers + ~115 inline `Calendar.current.startOfDay` calls bypassing the central `Date.startOfDay` extension)
- Bucket 2 inline user strings: 280+ (across 35+ files; analyzers alone have ~469 user-facing return strings, plus 68 inline `Text()`/`Button()` literals in Modules and 30+ inline `.accessibilityLabel`/`.navigationTitle`)
- Bucket 3 useless comments: 67+ (61 `Pass <N>` markers, 5 `Performance Pass 2` markers, plus several stale "norms / research" attributions without source links and a handful of obvious restate-the-line comments)
- Bucket 4 magic-number scoring ladders: 12 functions across 9 files (BiologicalAgeAnalyzer.computeRHRAge / computeHRVAge / computeMobilityAge / computeActivityRhythmAge, CardioRespiratoryAgeAnalyzer.findFitnessAge / computePercentile, ReadinessScorer.sleepDurationScore / sleepStageScore / workoutRecoveryScore / hrvScore / rhrScore / stressLevel, SleepNeedCalculator.calculateNeed, StrainCoach.computeZoneAndRange, StrainScorer.computeNormalizedLoad + zoneMultipliers, WorkoutRecoveryBand.init)

---

## Bucket 1 — Duplicate utility code

### Group: `firstIndex(onOrAfter:)` / `firstIndex(after:)` binary-search helpers
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Models/MetricTimeSeries.swift:181` — `private func firstIndex(onOrAfter date: Date) -> Int` — binary search of sorted samples for first index whose date is >= cutoff
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Models/MetricTimeSeries.swift:195` — `private func firstIndex(after date: Date) -> Int` — variant that uses strict `<=` (first index strictly after the date)
- `/Users/primetrace/Desktop/RnD/HealthPulse/Common/Components/MetricChartView.swift:444` — `private static func firstIndex(onOrAfter date: Date, in samples: [MetricSample]) -> Int` — same algorithm copied into the chart view to find the selection insertion index
- Suggested home: `Core/Extensions/Array+BinarySearch.swift` (or a `MetricSample`-typed extension on `Array<MetricSample>`)

### Group: `clamp(_:min:max:)` / `clamp01(_:)`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/WeeklyPatternAnalyzer.swift:608` — `private static func clamp(_ value: Int, min: Int, max: Int) -> Int`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/ReadinessScorer.swift:263` — `private static func clamp(_ value: Double, min lower: Double, max upper: Double) -> Double`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/ML/PredictiveHealthSignals.swift:358` — `private static func clamp01(_ value: Double) -> Double`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/ML/PersonalizationBlender.swift:696` — `private static func clamp01(_ value: Double) -> Double`
- Suggested home: `Core/Extensions/Math+Clamp.swift` with generic `func clamp<T: Comparable>(_:to:)` and `Double.clamped01`

### Group: `sigmoid(_:)`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/ML/AccelerateHelpers.swift:169` — `static func sigmoid(_ values: [Double]) -> [Double]` (vDSP path)
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/ML/AccelerateHelpers.swift:191` — `static func sigmoid(_ x: Double) -> Double`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/ML/PredictiveScorer.swift:459` — `private func sigmoid(_ x: Double) -> Double` (with sigmoidClamp guard)
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/ML/PersonalizationBlender.swift:691` — `sigmoidWeight(days:rampCenter:rampScale:)` — sigmoid form for blend weights
- Suggested home: extend `AccelerateHelpers.sigmoid` to accept an optional clamp; delete the local copies

### Group: Z-score helpers
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/BrainHealthScorer.swift:642` — `private func zScore(current:baseline:) -> Double`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/ML/FeatureEngine.swift:98` — `func zScore(for value: Double) -> Double` (instance on a Welford accumulator)
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/ML/PredictiveHealthSignals.swift:334` — `private static func sigmaDeviation(value:baseline:) -> Double` (functionally a z-score)
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/ML/AccelerateHelpers.swift:10` — `static func zScoreNormalize(_:) -> (normalized:, mean:, stdDev:)` (vDSP path)
- Suggested home: extend `Collection+Statistics.swift` with `func zScore(of value: Double, baselineMean:, baselineSD:)`

### Group: Linear regression / slope
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Extensions/Collection+Statistics.swift:58` — `var linearRegression: (slope:, intercept:)` on `[Double]` (the canonical version)
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/ClinicalIntelligence.swift:360` — `private static func linearRegressionSlope(samples: [MetricSample]) -> Double`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/Research/RHRTrajectoryAnalyzer.swift:128` — `private static func linearRegression(x:y:) -> (slope:, intercept:)`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/ML/TemporalSequenceMiner.swift:1337` — `private func linearRegressionFit(x:y:) -> (slope:, intercept:)`
- Suggested home: keep `Collection+Statistics.linearRegression`, add an `(x: [Double], y: [Double])` static; delete the rest

### Group: EMA / exponential smoothing
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Extensions/Collection+Statistics.swift:103` — `func exponentialSmoothing(alpha:) -> [Double]` on `[Double]`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/ML/PredictiveHealthSignals.swift:295` — `private static func ema(_ values: [Double], alpha: Double) -> [Double]` (identical body)
- Suggested home: keep `exponentialSmoothing` in `Collection+Statistics`; delete `ema`

### Group: Mean / median helpers
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Extensions/Collection+Statistics.swift:7` — `var mean: Double` on `[Double]` (canonical)
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Extensions/Collection+Statistics.swift:31` — `var median: Double` (canonical)
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/ML/AccelerateHelpers.swift:75` — `static func mean(_ values: [Double]) -> Double` (vDSP path; valid as perf alternative)
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/WeeklyPatternAnalyzer.swift:591` — `private static func mean(on dates: [Date], from map: [Date: Double]) -> Double?` (gather-then-mean wrapper, can call `.mean`)
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/WeeklyPatternAnalyzer.swift:602` — `private static func median(_ values: [Int]) -> Int?` (Int variant; central `median` is `Double` only)
- Suggested home: add `extension Array where Element == Int { var median: Int? }` next to existing helpers

### Group: `gradeFor(score:)` → `A/B/C/D/F`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Models/HealthScore.swift:16` — `var grade: String { switch score: 90...100 → "A" ... default → "F" }` (canonical)
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Notifications/DailySummaryScheduler.swift:147` — `private static func gradeFor(score: Int) -> String` (identical bucketing)
- `/Users/primetrace/Desktop/RnD/HealthPulse/App/BackgroundRefreshCoordinator.swift:57` — `private static func gradeForScore(_ score: Int) -> String` (slightly different bucketing: 90+ → "A+")
- `/Users/primetrace/Desktop/RnD/HealthPulse/Modules/Explore/Views/Explore/ExploreView.swift:319` — `private var grade: String` (identical to `HealthScore.grade`)
- Suggested home: use `HealthScore.grade` everywhere; reconcile the `A+` variant on a single source

### Group: Inline `Calendar.current` allocations bypassing `Date.startOfDay` / `Date+Extensions`
- 223 `Calendar.current` references across 113 files; central singleton already exists at `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Extensions/Date+Extensions.swift:7` (`private static let cal: Calendar = Calendar.current`) but is private. Sample sites that re-allocate per call:
  - `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/StrainCoach.swift:286` — `Calendar.current.date(byAdding: .day, value: -withinDays, to: Date())`
  - `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/ScoreTrajectoryAnalyzer.swift:33` — `Calendar.current.date(byAdding: .day, value: -days, to: Date())`
  - `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/RecoveryAnalyzer.swift:190` — `Calendar.current.date(byAdding: .day, value: dayAfter, to: workoutDay)`
  - `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/Research/SleepRegularityAnalyzer.swift:148` — `Calendar.current.dateComponents([.day], from:, to:)`
  - `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/Research/CircadianDisruptionAnalyzer.swift:124` — same
  - `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/Research/WellbeingTrendAnalyzer.swift:162` — same
  - `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/Research/InflammationRiskAnalyzer.swift:139` — same
  - `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/Research/HRRFitnessAnalyzer.swift:54` — same
  - `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/Research/CardioRespiratoryAgeAnalyzer.swift:71` — same
  - `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/Research/TemperatureCompoundAnalyzer.swift:173` — same
  - `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/HealthScorer.swift:298` — `Calendar.current.dateComponents([.day], from: baseline.lastUpdated, to: now)`
  - `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/ML/PredictiveHealthSignals.swift:316-318` — `Calendar.current` × 3 in one method (`recentDailyValues`)
  - `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/ML/AdaptiveAnomalyDetector.swift:324` — `Calendar.current.isDate(_:inSameDayAs:)`
  - `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/ML/ReceptivityEstimator.swift:75` — `Calendar.current.component(.hour, from: Date())`
  - `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/ML/DailyNarrativeEngine.swift:78` — same
  - `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Subscriptions/SubscriptionManager.swift:272, 321, 332` — `Calendar.current.dateComponents([.day], …)` × 3
  - `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Tracking/AppAnalytics.swift:390` — `Calendar.current.dateComponents([.year], …)`
- Suggested home: promote `Date.cal` to `internal` (or expose as `Calendar.shared`) in `Core/Extensions/Date+Extensions.swift`; replace the inline allocations. Also note the existing local re-cache pattern (`private static let cal: Calendar = Calendar.current` annotated "Pass 11/12") in 14+ files (StrainScorer, VitalityScorer, MenstrualCycleTracker, MorningCheckInManager, WeeklyPatternAnalyzer, HistoricalAnalyzer, DecisionPolicyEngine, MLEvaluator, AdherenceRecord, SessionTracker, ConnectedDeviceInfo, FeedbackPromptManager, AppStoreReviewManager, JournalStore, EngagementSequenceScheduler, DailySummaryScheduler, FrequencyCapManager, DataRetentionManager, NotificationOptimizer, WindDownScheduler, HealthDataStore, MetricTimeSeries, CalibrationDiscovery, ExpandedJournalView, NotificationsSettingsView, CategoryDetailViewModel, HealthStateTimelineView, DashboardViewModel/HomeJournalPromptCard/ActivationProgressBanner, MetricDetailViewModel, LiveViewModel, LiveActivitySection) — every one of these is a duplicate of the central cache.

### Group: Inline `DateFormatter()` / `ISO8601DateFormatter()` allocations
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/WeeklyPatternAnalyzer.swift:10` — `DateFormatter().weekdaySymbols`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/GamificationEngine.swift:266, 275` — `let f = DateFormatter()` × 2
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/ML/ChangePointDetector.swift:488` — `let f = DateFormatter()`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/ML/DailyNarrativeEngine.swift:97` — `let f = DateFormatter()`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/ML/MLEvaluator.swift:470` — `ISO8601DateFormatter().string(from: Date())`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Notifications/WakeUpTimeDetector.swift:21` — `let f = DateFormatter()`
- `/Users/primetrace/Desktop/RnD/HealthPulse/App/ActivationSequenceManager.swift:250` — `ISO8601DateFormatter().date(from: dateStr)`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Modules/WebExport/HTMLReportGenerator.swift:53` — `let dateFormatter = DateFormatter()`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Modules/Sleep/Views/Sleep/SleepCoachView.swift:469, 733` — `let formatter = DateFormatter()` × 2
- `/Users/primetrace/Desktop/RnD/HealthPulse/Modules/BrainHealth/Views/BrainHealth/BrainHealthDetailView.swift:405` — `let formatter = DateFormatter()`
- Note: `Date+Extensions.swift` already has a per-thread `FormatterCache`. Suggested home: expose a `Date.formatter(format:)` factory using that cache so callers don't allocate.

### Group: `Array(x.suffix(n)).map(\.value).mean` pattern
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/Research/RHRTrajectoryAnalyzer.swift:55, 119`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/Research/MobilityDeclineAnalyzer.swift:58`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/Research/HRRFitnessAnalyzer.swift:47`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/Research/CardioRespiratoryAgeAnalyzer.swift:47, 66`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/Research/BiologicalAgeAnalyzer.swift:124, 159, 225, 239, 254`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/ML/PredictiveHealthSignals.swift:848, 871, 1069`
- Suggested home: add `extension Array where Element == MetricSample { func tailMean(_ n: Int) -> Double }` (or use existing `Sequence.mean(of:)` directly: `samples.suffix(n).mean(of: \.value)`)

---

## Bucket 2 — Inline user strings

This list spans the most representative files. The full count of inline returned strings inside `Core/Analysis/**` is **469** (excluding `Copy+Analysis.swift`); inline `title:` keys alone are **200**. Below is a representative enumeration grouped by file. Treat each as a Copy candidate.

### Notification scheduler bodies / titles outside `Copy+Notifications.swift`

| File:Line | Snippet | Suggested Copy+ home |
|---|---|---|
| `Core/Notifications/EngagementSequenceScheduler.swift:363` | `("Your Health Update", "Tap to see your latest health insights.")` | `Copy+Notifications.swift` |
| `Core/Notifications/EngagementSequenceScheduler.swift:399` | `"Your morning health briefing"` | `Copy+Notifications.swift` |
| `Core/Notifications/EngagementSequenceScheduler.swift:417-419` | `let direction = change > 0 ? "up" : "down"` and `"Your \(metricName) is trending \(direction) \(...)% over the last few nights."` | `Copy+Notifications.swift` |
| `Core/Notifications/EngagementSequenceScheduler.swift:506` | `direction: change > 0 ? "improving" : "declining"` | `Copy+Notifications.swift` |
| `Core/Notifications/EngagementSequenceScheduler.swift:536, 544` | `"Your morning health briefing"`, `("Your Health Update", "Tap to see your latest health insights.")` | `Copy+Notifications.swift` |
| `Core/Notifications/EngagementSequenceScheduler.swift:630-638` | All five `insightForScore(_:)` returns ("You are well recovered today." … "Take it easy. Your body needs rest.") | `Copy+Notifications.swift` (new `recoveryInsightCopy(score:)`) |
| `Core/Notifications/WindDownScheduler.swift:57` | `"Your HRV (\(lastHRV) ms) suggests an early night."` | `Copy+Notifications.swift` (new `windDownHRVHint(...)`) |
| `Core/Notifications/WeeklySummaryScheduler.swift:42` | `"\(trend.metric) \(trend.direction)\(sign)\(...)%"` (mover row builder) | `Copy+Notifications.swift` |

### Analyzer / scorer commentary outside `Copy+Analysis.swift`

These are user-visible insight texts (`summary`, `recommendation`, `narrative`, `headline`) embedded in analyzer files.

| File:Line | Snippet | Suggested Copy+ home |
|---|---|---|
| `Core/Analysis/MenstrualCycleTracker.swift:21-104` | All four phase `displayName`s (`"Menstrual"`, `"Follicular"`, `"Ovulation"`, `"Luteal"`) and 12+ multi-sentence phase descriptions / training / sleep / nutrition guidance strings (lines 49, 51, 53, 55, 72, 74, 76, 78, 85, 87, 89, 91, 98, 100, 102, 104) | `Modules/CycleTracking/Copy+CycleTracking.swift` |
| `Core/Analysis/MenstrualCycleTracker.swift:201, 205, 207, 209, 211` | Five recovery-impact sentences ("No cycle data available…", "Recovery is slower during menstruation…", etc.) | `Copy+CycleTracking.swift` |
| `Core/Analysis/MenstrualCycleTracker.swift:196-198` | `VitalityPersonalizationStatus` raw values "Building your profile" / "Early estimate" / "Personalized" (these are display labels) | `Copy+Vitality.swift` |
| `Core/Analysis/CrossMetricAnomalyDetector.swift:30-31` | `"normally inverse"`, `"both elevated"` (model field comments encode user-visible relationship descriptions) | central enum / `Copy+Analysis.swift` |
| `Core/Analysis/CrossMetricAnomalyDetector.swift:614, 618, 645, 649, 655, 659, 662` | Anomaly narrative builders ("This combination of metric values…", "Unusual pattern across N categories…", "Unusual but mild pattern in…", etc.) | `Copy+Analysis.swift` |
| `Core/Analysis/MultiMetricClusterAnalyzer.swift:72, 74, 136-152` | Per-cluster narrative templates ("Multiple heart metrics declining simultaneously — N metrics affected: X", repeated across heart, sleep, activity, body composition, respiratory, mindfulness, mobility, nutrition, hearing — 9 inlined templates) | `Copy+Analysis.swift` |
| `Core/Analysis/CausalChainEngine.swift:602, 626, 643, 645` | Causal-chain narrative pieces ("Monitor your X over the next few days.", "Focus on improving your Y. Consider consistent bedtimes…", "Your Z increase may be affecting downstream metrics…") | `Modules/Insights/Copy+Causation.swift` |
| `Core/Analysis/StrainCoach.swift:240, 248, 251, 253, 257, 259, 263, 265, 268` | All 9 guidance returns inside `buildGuidance(...)` ("Limited data — this target is estimated…", "Your body needs recovery…", "Active recovery day…", "Moderate training day…", "Functional overreach zone…", etc.) | `Modules/Strain/Copy+Strain.swift` |
| `Core/Analysis/WeeklyPatternAnalyzer.swift:223, 249-268` | `"Unknown"` weekday fallback + 8 cycle-phase / training-readiness sentences | `Modules/CycleTracking/Copy+CycleTracking.swift` |
| `Core/Analysis/WeeklyPatternAnalyzer.swift:389` | `"\(signal.label) \(direction) \(...)%"` mover template | `Copy+Analysis.swift` |
| `Core/Analysis/CognitiveEnergyAnalyzer.swift:67, 85, 104, 138` | Inline qualifiers ("down N% from baseline", "N% below baseline", "N hrs below your baseline") | `Modules/Insights/Copy+Analysis.swift` |
| `Core/Analysis/CognitiveEnergyAnalyzer.swift:200, 203, 205, 251-252, 311-313, 380-382, 449-450, 495-497` | Multi-sentence summaries / recommendations embedded around the `Copy.Analysis.CognitiveEnergy.*` titles | same |
| `Core/Analysis/InsightGenerator.swift:686-692` | 7 trend×severity title cases ("Critically Low", "Needs Attention", "Declining", "Improving", "Outside Safe Range", "Elevated", "Stable") interpolated with metric names | `Modules/Insights/Copy+Insights.swift` |
| `Core/Analysis/InsightGenerator.swift:589, 936-940` | `"Priority today: …"`, three baseline-deviation summary templates | `Copy+Insights.swift` |
| `Core/Analysis/JournalCorrelationAnalyzer.swift:24-26` | `"Strong"`, `"Moderate"`, `"Mild"` correlation labels | `Modules/Journal/Copy+Journal.swift` |
| `Core/Analysis/JournalCorrelationAnalyzer.swift:281-317` | 11 correlation narrative templates (caffeine, alcohol, stress, meditation, screen time, late-meals, hydration, mood, supplements) | `Copy+Journal.swift` |
| `Core/Analysis/BrainHealthScorer.swift:14-17, 32-35, 252-267` | State display labels "Sharp" / "Focused" / "Baseline" / "Low energy" + SF Symbol names + `brainHealthTrend` returning `"stable"` / `"improving"` / `"declining"` | `Modules/BrainHealth/Copy+BrainHealth.swift` |
| `Core/Analysis/StressScorer.swift:13-17, 192, 199, 206, 211, 216, 219-221` | Stress level display names + `stressDescription` four multi-sentence cases | `Modules/Stress/Copy+StressMonitor.swift` |
| `Core/Analysis/StrainScorer.swift:28-33` | Six `StrainLevel.displayName` strings ("Low", "Light", "Moderate", "High", "Peak", "All Out") | `Modules/Strain/Copy+Strain.swift` |
| `Core/Analysis/SleepDebtTracker.swift:103, 107-110` | `"—"` placeholder + `"0h"` / `"\(m)m"` / `"\(h)h"` / `"\(h)h \(m)m"` formatting | `Common/Components` formatter helper or `Copy+Common.swift` |
| `Core/Analysis/HealthRiskEngine.swift:231, 246` | `"\(low)–\(high) \(unit)"`, `"\(name) is \(formatted) \(unit), within the healthy range."` | `Copy+Insights.swift` |
| `Core/Analysis/DiscoveryEngine.swift:531` | `"Average \(effect): \(above) \(unit) (with) vs \(below) \(unit) (without)."` | `Modules/Discovery/Copy+Discovery.swift` |
| `Core/Analysis/Research/HRRFitnessAnalyzer.swift:64-66, 84-86, 100-102, 116-118` | All 4 insight title/summary/recommendation triples ("Heart Rate Recovery Below Clinical Threshold", "Excellent Heart Rate Recovery", "Heart Recovery Improving Over X Months", "Heart Recovery Declining") | `Modules/Insights/Copy+Analysis.swift` |
| `Core/Analysis/Research/CardioRespiratoryAgeAnalyzer.swift:84-86, 105-107, 117-119, 137-138` | 4 insight triples (Cardio Fitness Age, VO2max Improving, VO2max Declining, VO2max Below Typical Threshold) | `Copy+Analysis.swift` |
| `Core/Analysis/Research/BiologicalAgeAnalyzer.swift:82-84, 100-102` | 2 insight title/summary/recommendation triples ("Fitness Age Estimate: ~X", "Age Component Imbalance") + inline `componentBreakdown` and `youngestComponent.component` strings ("Cardio Fitness", "Resting Heart Rate", "Activity Rhythm", "Mobility", "Autonomic Nervous System") | `Copy+Analysis.swift` |
| `Core/Analysis/Research/SleepRegularityAnalyzer.swift:60-62, 79-81, 94-96, 109-111` | 4 insight triples (Irregular Sleep Pattern, Sleep Regularity Needs Attention, Excellent Sleep Regularity, Social Jet Lag) | `Modules/Sleep/Copy+SleepCoach.swift` |
| `Core/Analysis/Research/InflammationRiskAnalyzer.swift:75-77, 96-98, 119-121` | 3 insight triples ("Body Stress Signal", "Elevated Body Stress", "Strong Recovery Tone") | `Copy+Analysis.swift` |
| `Core/Analysis/Research/MobilityDeclineAnalyzer.swift:28-34` (label dictionary), `104-106, 128-130, 147-149, 168-170` | Indicator labels ("walking speed", "step length", "double support time", …) + 4 insight triples | `Modules/HealthState/Copy+HealthState.swift` or `Copy+Analysis.swift` |
| `Core/Analysis/Research/RHRTrajectoryAnalyzer.swift` | Insight title/summary strings inline (titles built from `"\(...) Resting Heart Rate"`) | `Copy+Analysis.swift` |
| `Core/Analysis/Research/WellbeingTrendAnalyzer.swift`, `SleepCoherenceAnalyzer.swift`, `CircadianDisruptionAnalyzer.swift`, `TemperatureCompoundAnalyzer.swift` | Each holds 2-4 insight triples inline | `Copy+Analysis.swift` |
| `Core/Analysis/ML/HealthDataQueryEngine.swift:1466-1469, 1474-1475, 1479, 1483-1486, 1494, 1499-1501` (and ~50 other lines in the file) | `scorePhrase` cases ("You're doing great…", "Your health score is X…"), tracking note, hello/answer scaffolding, related-question seeds | `Modules/Insights/Copy+Analysis.swift` |
| `Core/Analysis/ML/HealthStateClassifier.swift:541-578, 1090` | 14 state name returns ("Recovery", "Peak Performance", "Stressed", "Under-Slept", "Active", "Fatigued", "Resting", "Balanced", "Recovering", "Strained", "Low Energy", "Restful") + transition narrative | `Modules/HealthState/Copy+HealthState.swift` |
| `Core/Analysis/ML/CompoundInsightEngine.swift:311, 347, 372, 463, 505, 538, 718, 751, 820, 864, 936` | 11 insight titles (e.g. "Your Health Is Building Momentum", "Multiple Metrics Declining Together", "New Health Phase: …", "Tomorrow's Risk: X%", "Your Best-Day Formula", "Recovery Underway") | `Copy+Insights.swift` |
| `Core/Analysis/ML/MLResultAggregator.swift:175, 199, 232, 288, 307, 352, 371, 564-572, 578, 610-620` | 7 insight titles + 5 pattern-period narratives + characteristics summary + 6 state-name narratives | `Copy+Insights.swift` |
| `Core/Analysis/ML/DecisionPolicyEngine.swift` | 21 user-visible return strings (counted by `return "[a-z]+[a-z]+"` heuristic) | `Copy+Analysis.swift` |
| `Core/Analysis/ML/FoundationModelTools.swift` | 15 user-visible return strings | `Copy+Analysis.swift` |
| `Core/Analysis/ML/TodayIntelligenceEngine.swift` | 13 user-visible return strings | `Copy+Insights.swift` |
| `Core/Analysis/ML/MLTypes.swift` | 9 inline display strings (likely enum `displayName`) | `Copy+Analysis.swift` |
| `Core/Analysis/RulesConfiguration.swift:298-403+` | All `cardioRecommendation`, `sleepRecommendation`, `activityRecommendation`, etc. return inline templates ("\(...)Sleep duration is \(...)below your baseline.", etc.) — counted as 50 user-visible templates by heuristic | `Copy+Analysis.swift` |

### Inline `Text(...)`, `Button(...)`, `.navigationTitle(...)`, `.accessibilityLabel(...)` in views (representative; full count 68 + 30+):

| File:Line | Snippet | Suggested Copy+ home |
|---|---|---|
| `App/ContentView.swift:619` | `.navigationTitle("Sleep Coach")` | `Copy+SleepCoach.swift` |
| `Common/Components/MaintenanceView.swift:45` | `.accessibilityLabel("Continue anyway")` | `Copy+Common.swift` |
| `Common/Components/FeedbackSheet.swift:209` | `.accessibilityLabel("Sending feedback")` | `Copy+Common.swift` |
| `Common/Components/PMFSurveySheet.swift:56` | `.navigationTitle("Quick question")` | `Copy+Common.swift` |
| `Common/Components/LockedInsightsCTA.swift:49` | `.accessibilityLabel("Unlock \(hiddenCount) more insights with Pro")` | `Copy+Paywall.swift` |
| `Common/Components/ShareButton.swift:20` | `.accessibilityLabel("Share health card")` | `Copy+Common.swift` |
| `Common/Components/DataConfidenceBadge.swift:36` | `.accessibilityLabel("Data confidence: \(tier.name) tier")` | `Copy+Common.swift` |
| `Common/Components/ProFeatureOverlay.swift:61` | `.accessibilityLabel("Upgrade to Pro")` | `Copy+Paywall.swift` |
| `Modules/Journal/Views/Journal/ExpandedJournalView.swift:51, 55, 284, 313, 343, 365, 375, 395` | `.navigationTitle("Daily Check-in")`, `Button("Cancel")`, `Text("Log N Behavior(s)")`, `Text("Logged N behavior(s)")`, four `.accessibilityLabel("...")` interpolated | `Modules/Journal/Copy+Journal.swift` |
| `Modules/Journal/Views/Journal/JournalEntryView.swift:43, 48, 85, 151, 183, 206, 221, 241, 278, 297` | `.navigationTitle("Log Entry")`, `Button("Cancel")`, `Text("What would you like to log?")`, `Text("Amount")`, three a11y labels, `Text("Notes")`, `Text("Log \(displayName)")`, `Text("Logged")` | `Copy+Journal.swift` |
| `Modules/Discovery/Views/Discovery/DiscoveryView.swift:107, 120, 130, 211, 214, 237, 240` | `Text("We analyzed your health history")`, `Text("Here is what we found")`, `Text("Swipe to explore")`, `Text("Your Dashboard is Ready")`, `Text("Track these patterns and more...")`, `Text("Continue")`, `.accessibilityLabel("Continue to dashboard")` | `Modules/Discovery/Copy+Discovery.swift` |
| `Modules/Settings/Views/SettingsView.swift:525, 688` | `Text("Add Laso shortcuts to Siri…")`, `Text("Danger Zone")` | `Modules/Settings/Copy+Settings.swift` |
| `Modules/Strain/Views/Strain/StrainDetailView.swift:233, 236, 275, 310` | `Text("No workout data yet")`, `Text("Log a workout in Apple Health…")`, two a11y labels | `Modules/Strain/Copy+Strain.swift` |
| `Modules/Profile/Views/Profile/AchievementsView.swift:262, 288, 411` | `Text("Highest level achieved")`, `Text("Active Streaks")`, `Text("Achievements")` | `Modules/Profile/Copy+Achievements.swift` |
| `Modules/Live/Views/Live/Live*Section.swift` (all files) | `Text("Activity Rings")`, `Text("No activity yet")`, `Text("Your rings will fill...")`, `Text("Last Known Readings")`, `Text("Blood Pressure")`, `Text("Temperature")`, `Text("Live")`, `Text("Syncing")`, `Text("Last Reading")`, `Text("Last Workout")`, `Text("No data")`, `Text("Last signal \(date) ago")`, `Text("Today: \(min)–\(max) bpm")` (~14 sites across Live*) | `Modules/Live/Copy+Live.swift` |
| `Modules/HealthState/Views/HealthState/HealthStateTimelineView.swift:285, 319, 363` | `Text("Distribution")`, `Text("Common Transitions")`, `Text("State Guide")` | `Modules/HealthState/Copy+HealthState.swift` |
| `Modules/BrainHealth/Views/BrainHealth/BrainHealthDetailView.swift:86, 94` | `Text("Building accuracy · \(N)%")`, `Text("We need more nights of sleep + HRV data…")` | `Modules/BrainHealth/Copy+BrainHealth.swift` |
| `Modules/Paywall/Views/Subscription/PaywallView.swift:458` | `Text("Payment will be charged…")` (legal disclaimer) | `Modules/Paywall/Copy+Paywall.swift` |
| `Modules/Onboarding/Views/Onboarding/OnboardingV2Screens14ToDone.swift:94, 357` | `Text("DAY \(day.day)")`, `Text("Retry")` | `Modules/Onboarding/Copy+Onboarding.swift` |
| `Modules/Onboarding/Views/Onboarding/OnboardingV2Screens8to13.swift:393, 565, 585, 732, 751` | `Text("Resting HR")`, `Text("Last 7 nights")`, `Text("No nights recorded yet")`, `Text("HRV · weekly average")`, `Text("Not enough HRV samples across the week")` | `Copy+Onboarding.swift` |
| `Modules/Stress/Views/Stress/StressMonitorView.swift:67, 70` | `Text("Building your stress baseline")`, `Text("We need about 14 days of overnight HRV data…")` | `Modules/Stress/Copy+StressMonitor.swift` |
| `Modules/Devices/Views/Devices/DeviceDetailView.swift:68, 84, 95, 106, 117, 129, 166, 169, 175, 190, 206` | 11 inline `Text("...")` section labels + interpolated rows | `Modules/Devices/Copy+Devices.swift` |
| `Modules/Devices/Views/Devices/ConnectedDevicesView.swift:102, 104, 182` | `Text("Connected But Inactive")`, `Text("These sources were detected before...")`, `Text("Detected")` | `Copy+Devices.swift` |
| `Modules/Insights/Views/Insights/CorrelationsView.swift:437, 532` | a11y labels with metric names interpolated | `Copy+Insights.swift` |
| `Modules/Settings/Views/NotificationsSettingsView.swift:106` | `.accessibilityLabel("Maximum notifications per day")` | `Copy+Settings.swift` |
| `Modules/Settings/Views/AcknowledgementsView.swift:122` | `.accessibilityLabel("\(library.name), \(library.license)")` | `Copy+Settings.swift` |
| `Modules/Sleep/Views/Sleep/SleepCoachView.swift:335` | `.accessibilityLabel("\(dayLabel) sleep: \(...) in bed")` | `Copy+SleepCoach.swift` |
| `Modules/CategoryDetail/Views/Category/CategoryDetailView.swift:252, 304` | a11y labels with category/metric names interpolated | `Copy+CategoryDetail.swift` |
| `Modules/Discovery/Views/Discovery/DiscoveryView.swift:240` | `.accessibilityLabel("Continue to dashboard")` | `Copy+Discovery.swift` |
| `Modules/Explore/Views/Explore/Explore*Section.swift` | 4 a11y labels with category/metric names interpolated | `Modules/Explore/Copy+Explore.swift` |
| `Modules/Dashboard/Views/Home/TodayBriefingView.swift:243` | `Button("Done") { dismiss() }` | `Copy+Home.swift` |
| `Modules/Dashboard/Views/Home/HomeView.swift:763` | `Button("Open Score Guide") { showScoreGuide = true }` | `Copy+Home.swift` |

### Ambiguous (likely user-facing but confirm)

- `Core/Analysis/MenstrualCycleTracker.swift:135` — `private static let snapshotKey = "MenstrualCycleTracker.snapshot.v1"` — UserDefaults key, not user-visible. **Not a violation.** (Listed only because the regex caught it.)
- `Core/Notifications/NotificationManager.swift:33-42` — string returns like `"daily_summary"`, `"evening_summary"`, `"alert"`, etc. — these are analytics type tags, not user-visible. **Not a violation.**
- `Core/Analysis/TrendAnalyzer.swift:85-88` — `"stable"`, `"gradually"`, `"noticeably"`, `"rapidly"` — interpolated into other Copy strings; should still go in Copy as intensity adverbs.
- `Core/Analysis/CrossMetricAnomalyDetector.swift:30-31` — `expectedRelationship: String` and `actualBehavior: String` carry display values like `"normally inverse"` / `"both elevated"` set by inline call sites — verify; treated as user-visible.

---

## Bucket 3 — Useless / misleading comments

### `Pass <N>` markers (61 hits — sample list; all are stale audit-pass identifiers that mean nothing to a future reader)

| File:Line | Comment | Action |
|---|---|---|
| `Core/Analysis/SleepPerformanceAnalyzer.swift:6` | `/// Pass 12 BE perf: cached current calendar. Quality-vs-performance comparison` | rewrite without "Pass 12 BE perf:" prefix; keep the substantive note |
| `Core/Analysis/CrossMetricAnomalyDetector.swift:52` | `/// Pass 12 BE perf: cached current calendar. \`detect(...)\` calls` | same |
| `Core/Analysis/WeeklyPatternAnalyzer.swift:231` | `/// Pass 11 AF: cached calendar — \`assignPhases\` walks day-by-day across a` | strip prefix |
| `Core/Analysis/SleepNeedCalculator.swift:64` | `// Pass 8 Y: bedtime is rendered on the Sleep tile, so it must follow the` | strip prefix |
| `Core/Analysis/SleepNeedCalculator.swift:177` | `// Pass 8 Y: locale-aware. Picks 24h vs 12h from \`Locale.current\`.` | strip prefix |
| `Core/Analysis/HistoricalAnalyzer.swift:9` | `/// Pass 12 BE perf: cached current calendar. Insight builders below call` | strip prefix |
| `Core/Analysis/ML/TodayIntelligenceEngine.swift:1080` | `// Pass 8 Y: short date appears inside a user-visible IntelligenceCard` | strip prefix |
| `Core/Analysis/ML/DecisionPolicyEngine.swift:39` | `/// Pass 11 AF: cached calendar — exposure-window math runs \`dateByAdding\`` | strip prefix |
| `Core/Analysis/ML/DecisionPolicyEngine.swift:44` | `/// Pass 11 AF: cached decimal NumberFormatter — \`formatted(_:)\` is called` | strip prefix |
| `Core/Analysis/ML/MLEvaluator.swift:21` | `/// Pass 12 BE perf: cached current calendar.` | strip prefix |
| `Core/Models/AdherenceRecord.swift:18` | `/// Pass 12 BE perf: cached current calendar.` | strip prefix |
| `Core/Models/MetricTimeSeries.swift:13` | `/// Pass 11 AF: cached calendar — \`init\`'s distinct-day pass and the` | strip prefix |
| `Core/Tracking/SessionTracker.swift:60` | `/// Pass 12 BE perf: cached current calendar.` | strip prefix |
| `Core/Models/ConnectedDeviceInfo.swift:14` | `/// Pass 11 AF: cached calendar — \`isActive\` and \`lastSyncText\` render in` | strip prefix |
| `Core/Models/CalibrationDiscovery.swift:98` | `/// Pass 11 AF: cached step formatter — \`formatSteps\` runs once per priority` | strip prefix |
| `Core/Tracking/FeedbackPromptManager.swift:18` | `/// Pass 12 BE perf: cached current calendar.` | strip prefix |
| `Core/Data/HealthDataStore.swift:168` | `/// Pass 11 AF: cached calendar — \`saveAnalysisSnapshot\`, \`saveDailyStrain\`,` | strip prefix |
| `Core/Tracking/AppStoreReviewManager.swift:14` | `/// Pass 12 BE perf: cached current calendar.` | strip prefix |
| `Core/Data/JournalStore.swift:126` | `/// Pass 11 AF: cached calendar — every journal write/read path normalises to` | strip prefix |
| `Core/Notifications/EngagementSequenceScheduler.swift:38` | `/// Pass 11 AF: cached calendar` | strip prefix |
| `Core/Notifications/DailySummaryScheduler.swift:9` | `/// Pass 12 BE perf: cached current calendar.` | strip prefix |
| `Core/Notifications/FrequencyCapManager.swift:8` | `/// Pass 11 AF: cached calendar` | strip prefix |
| `Core/Data/DataRetentionManager.swift:8` | `/// Pass 11 AF: cached calendar — \`pruneIfNeeded\` runs at every launch and` | strip prefix |
| `Core/Notifications/WindDownScheduler.swift:15` | `/// Pass 12 BE perf: cached current calendar.` | strip prefix |
| `Core/Notifications/WindDownScheduler.swift:95` | `// Pass 8 Y: bedtime is shown inside a user-visible notification body,` | strip prefix |
| `Core/Notifications/NotificationOptimizer.swift:6` | `/// Pass 12 BE perf: cached current calendar.` | strip prefix |
| `Common/Components/ShareableCard.swift:132` | `// Pass 8 Y: locale-aware. \`.dateTime.day().month().year()\` resolves the` | strip prefix |
| `Common/Components/ShareableCard.swift:259` | `// Pass 8 Y: locale-aware (see notes on the score-card formatter above).` | strip prefix |
| `Common/Components/MetricChartView.swift:101` | `// Pass 8 P2-F17: per-mark VoiceOver labels` | strip prefix |
| `Common/Components/MetricChartView.swift:290` | `// Pass 8 P2-F17: chart-level summary so VoiceOver announces` | strip prefix |
| `Modules/Journal/Views/Journal/ExpandedJournalView.swift:23` | `/// Pass 12 BE perf: cached current calendar.` | strip prefix |
| `Modules/Settings/Views/NotificationsSettingsView.swift:14` | `/// Pass 12 BE perf: cached current calendar. The DatePicker get/set` | strip prefix |
| `Modules/Insights/Views/Insights/InsightsDetailView.swift:9` | `/// Pass 8 V (F45): timestamp of the parent dashboard's most recent refresh.` | strip prefix |
| `Modules/Vitality/Views/Vitality/VitalityDetailView.swift:5` | `/// Pass 8 V (F45): freshness timestamp from the parent dashboard refresh.` | strip prefix |
| `Modules/Strain/Views/Strain/StrainDetailView.swift:69` | `/// Pass 8 V (F45): freshness timestamp from the parent dashboard refresh.` | strip prefix |
| `Modules/Strain/Views/Strain/StrainDetailView.swift:273` | `// Pass 8 P2-F17: per-bar VoiceOver readout for the 7-day strain history.` | strip prefix |
| `Modules/Strain/Views/Strain/StrainDetailView.swift:308` | `// Pass 8 P2-F17: chart-level VoiceOver summary for the strain history.` | strip prefix |
| `Modules/CycleTracking/Views/CycleTracking/CycleDetailView.swift:133, 135` | `/// Pass 11 AK (F45): freshness timestamp…`, `/// Pass 11 AK (F31): pull-to-refresh hook…` | strip prefix |
| `Modules/Vitality/Views/Vitality/VitalityDetailHelpers.swift:86` | `// Pass 8 Y: walking speed is the only Vitality component whose canonical` | strip prefix |
| `Modules/Sleep/Views/Sleep/SleepCoachView.swift:12, 15` | `/// Pass 11 AK (F45): freshness timestamp…`, `/// Pass 11 AK (F31): pull-to-refresh hook…` | strip prefix |
| `Modules/CategoryDetail/ViewModels/CategoryDetailViewModel.swift:7` | `/// Pass 12 BE perf: cached current calendar.` | strip prefix |
| `Modules/Vitality/Views/Vitality/VitalityTrendSection.swift:45, 82` | `// Pass 8 P2-F17: per-mark VoiceOver readout`, `// Pass 8 P2-F17: chart-level VoiceOver summary.` | strip prefix |
| `Modules/Dashboard/Views/Home/HomeJournalPromptCard.swift:4` | `/// Pass 12 BE perf: cached current calendar.` | strip prefix |
| `Modules/Live/ViewModels/LiveViewModel.swift:43` | `/// Pass 12 BE perf: cached current calendar` | strip prefix |
| `Modules/Dashboard/Views/Home/ActivationProgressBanner.swift:160` | `/// Pass 12 BE perf: cached current calendar.` | strip prefix |
| `Modules/WeeklyReview/ViewModels/WeeklyReviewViewModel.swift:16` | `/// Pass 8 V (F45): timestamp of the most recent successful \`load()\`.` | strip prefix |
| `Modules/Live/Views/Live/LiveHeartRateSection.swift:252` | `// Pass 8 P2-F17: per-point VoiceOver readout.` | strip prefix |
| `Modules/Live/Views/Live/LiveBloodPressureTempSection.swift:87` | `// Pass 8 Y: body temperature is stored canonically` | strip prefix |
| `Modules/Live/Views/Live/LiveBloodPressureTempSection.swift:119` | `// Pass 8 Y: convert the canonical Celsius value into the user's` | strip prefix |
| `Modules/HealthState/Views/HealthState/HealthStateTimelineView.swift:9` | `/// Pass 12 BE perf: cached current calendar.` | strip prefix |
| `Modules/Risk/Views/Risk/HealthRiskDetailView.swift:7, 9` | `/// Pass 11 AK (F45): freshness…`, `/// Pass 11 AK (F31): pull-to-refresh…` | strip prefix |
| `Modules/BrainHealth/Views/BrainHealth/BrainHealthDetailView.swift:11` | `/// Pass 8 V (F45): freshness timestamp…` | strip prefix |
| `Modules/Live/Views/Live/LiveActivitySection.swift:9` | `/// Pass 12 BE perf: cached current calendar.` | strip prefix |
| `Modules/Onboarding/Views/Onboarding/ReferralCodeStep.swift:87` | `// Pass 11 AK: pair the spinner with a caption so the user knows` | strip prefix |
| `Modules/Onboarding/Views/Onboarding/OnboardingMirrorMomentStep.swift:139` | `// Pass 11 AK: pre-progress fallback gets a label so the spinner has context.` | strip prefix |
| `Modules/Stress/Views/Stress/StressMonitorView.swift:13` | `/// Pass 8 V (F45): freshness timestamp…` | strip prefix |
| `Modules/MetricDetail/ViewModels/MetricDetailViewModel.swift:7` | `/// Pass 12 BE perf: cached current calendar.` | strip prefix |
| `Modules/Strain/Copy+Strain.swift:77, 101` | `// MARK: - Today's Workout (Pass 8 Q)`, `// MARK: - Strain Detail (Pass 8 Q)` | strip "(Pass 8 Q)" suffix from MARK |
| `Modules/Sleep/Copy+SleepCoach.swift:89, 97` | `// MARK: - Stages (Pass 8 Q)`, `// MARK: - Tips Disclosure (Pass 8 Q)` | same |
| `Modules/Stress/Copy+StressMonitor.swift:114` | `// MARK: - Stop Confirmation (Pass 8 Q)` | same |

### `Performance Pass 2` markers

| File:Line | Comment | Action |
|---|---|---|
| `Core/Analysis/VitalityScorer.swift:283` | `// Performance Pass 2 hot-path caches: avoid per-call allocations for the` | strip prefix |
| `Core/Analysis/StrainScorer.swift:103` | `// Performance Pass 2 hot-path caches: avoid per-compute allocations.` | strip prefix |
| `Core/Analysis/MenstrualCycleTracker.swift:141` | `// Performance Pass 2 hot-path caches: the cycle compute path runs every` | strip prefix |
| `Core/Extensions/Date+Extensions.swift:5` | `/// Performance Pass 2 flagged 263 \`Calendar.current\` allocations across the app;` | strip "Performance Pass 2 flagged 263 …" — replace with timeless rationale |
| `Core/Data/MorningCheckInManager.swift:11` | `// Performance Pass 2 hot-path caches: avoid per-call allocations on every` | strip prefix |

### "Norms" / "research" / "population" claims with no source URL

These cite study names but no DOI / PubMed / archive link. They should either link the paper or drop the citation.

| File:Line | Comment | Action |
|---|---|---|
| `Core/Analysis/CircadianHealthAnalyzer.swift:6` | `/// Based on chronomedicine research (Diagnostics 2025): activity amplitude,` | add DOI or rewrite as implementation note |
| `Core/Analysis/Research/WellbeingTrendAnalyzer.swift:3` | `/// Research: JMIR (Feb 2026) + systematic reviews on digital phenotyping.` | add DOI |
| `Core/Analysis/Research/HRRFitnessAnalyzer.swift:3, 14` | `/// Research: Apple Heart & Movement Study (2026)…` and `/// Abnormal HRR: <12 bpm drop in 1 minute (NEJM standard)` | add DOI for both |
| `Core/Analysis/Research/CardioRespiratoryAgeAnalyzer.swift:3, 6, 13` | `/// Research: Apple Heart & Movement Study (2026)…`, `/// Age/sex percentile tables now available from large populations.`, `// Approximated from published averages…` | add DOI |
| `Core/Analysis/Research/TemperatureCompoundAnalyzer.swift:3` | `/// Research: Multiple 2025 studies on wrist temperature…` | name studies + DOI |
| `Core/Analysis/Research/SleepRegularityAnalyzer.swift:3, 15` | `/// Research: Circulation Research (2025) + systematic review (2025)`, `/// SRI thresholds from literature` | add DOI |
| `Core/Analysis/Research/InflammationRiskAnalyzer.swift:3` | `/// Research: Diagnostics systematic review (Feb 2026) + Nature Scientific Reports (2025)` | add DOI |
| `Core/Analysis/Research/BiologicalAgeAnalyzer.swift:3, 8, 16, 161, 256` | `/// Research: npj Digital Medicine (2024). CosinorAge`, `/// Also: Apple Heart & Movement Study (2026). VO2max age percentiles.`, `// MARK: - VO2max Age/Sex Norms (from Apple Heart & Movement Study 2026)`, `// Population norms: RHR increases with poor cardiovascular health`, `// HRV population norms (SDNN): 20s: ~60-80ms…` | add DOI for each cited study |
| `Core/Analysis/Research/CircadianDisruptionAnalyzer.swift:3` | `/// Research: npj Digital Medicine (2024) + Chronobiology in Medicine (2025)` | add DOI |
| `Core/Analysis/Research/SleepCoherenceAnalyzer.swift:3` | `/// Research: Stanford SleepFM (Nature Medicine, Jan 2026)` | add DOI |
| `Core/Analysis/Research/MobilityDeclineAnalyzer.swift:3` | `/// Research: Google Research (2025) + npj Parkinson's Disease (2025)` | add DOI |
| `Core/Analysis/ML/ReceptivityEstimator.swift:6` | `/// Based on JITAI research (Frontiers in Digital Health 2025): effective interventions` | add DOI |
| `Core/Tracking/AppAnalytics.swift:1336` | `/// Weighted per Supportbench / Cerebral Ops "customer health score" research:` | add URL or drop attribution |
| `App/ActivationSequenceManager.swift:6` | `/// Based on retention research (npj Digital Medicine 2023): 67.6% retention` | add DOI |
| `Modules/Insights/Views/Insights/InsightsDetailView.swift:193` | `/// research: health & fitness top-decile trial→paid is 68%, and 80–90% of` | add citation or rewrite as engineering note |
| `Modules/Dashboard/Views/Home/PersonalHealthForecastCard.swift:6` | `/// Based on conformal prediction research (Communications Engineering 2025):` | add DOI |
| `Modules/Dashboard/Views/Home/AskYourDataView.swift:6` | `/// Based on Google's PHIA research (Nature Communications 2025):` | add DOI |
| `Modules/Dashboard/Views/Home/MorningCheckInView.swift:6` | `/// Based on HRV research (Sensors MDPI 2025): combining physiological signals` | add DOI |
| `Core/Analysis/VitalityScorer.swift:6-7, 12, 20, 28, 36, 44, 52, 60, 68, 80` | "Sourced from ACSM, AHA, and WHO population studies." plus 8 per-table `Sources: <author year>, <description>` lines (Nunan 2010, Bohannon & Andrews 2011, Tudor-Locke 2011, Jackson & Pollock, Ohayon 2004, Redline et al, ACE) | add DOIs / canonical URLs for each cited dataset |
| `Core/Analysis/Research/RHRTrajectoryAnalyzer.swift:3, 19` | `/// Based on population wellness studies (AHA, Nature, Lancet).`, `/// Population norms: RHR should gently decline with regular activity over years` | add DOIs |
| `Core/Analysis/SleepDebtTracker.swift:122` | `/// accumulate debt against a science-backed target (NSF guidelines: 7-9h).` | add NSF URL |
| `Core/Analysis/StrainScorer.swift:53-54, 87-89` | `/// Inspired by WHOOP's strain model: combines calorie expenditure,…`, `/// Calibrated so that an elite-level training day (~1200 kcal active, 90 min zone 4-5)` | document calibration source |

### Restate-the-line / stale comments

| File:Line | Comment | Action |
|---|---|---|
| `Core/Analysis/CrossMetricAnomalyDetector.swift:339` | `// Build the metric deviations list` (above an obvious `var deviations: [...]`) | delete |
| `Core/Analysis/PersonalRecordAnalyzer.swift:134` | `// Calculate how long the previous record stood` | delete |
| `Core/Analysis/CausalChainEngine.swift:319` | `// Build the explanation for this link` | delete |
| `Core/Analysis/ML/CompoundInsightEngine.swift:1104` | `// Compare to prior window` | delete |
| `Modules/Dashboard/ViewModels/DashboardViewModel.swift:567` | `// Build the initial metric tiles synchronously from whatever the` | keep only if it explains a non-obvious "synchronously" choice; else delete |
| `Modules/Dashboard/Views/Home/HomeView.swift:646` | `// Build the line based on recovery state` | delete |
| `Core/Analysis/HealthScorer.swift:4` | `/// Supports both equal weighting (legacy) and adaptive weighting (WHOOP 5.0-style).` | "(legacy)" implies dead code path; verify and delete legacy path or rewrite |
| `Core/Analysis/ML/AdaptiveAnomalyDetector.swift:63, 183, 526, 539` | Repeated references to `legacyContextualZScore` "fallback" path | confirm whether the legacy path is still needed; if not, delete |
| `Core/Tracking/FeedbackPromptManager.swift:67` | `// Submitted flag set but no date (legacy). reset and re-ask` | confirm whether legacy migration path is still hit; otherwise delete |

---

## Bucket 4 — Magic-number scoring ladders

### `computeRHRAge(context:)` in `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/Research/BiologicalAgeAnalyzer.swift`
- Lines 154-176
- Constants found: `55`, `65`, `75`, `20`, `40`, `60`, `2.0`, `1.5`, `90`, `0.20` (component weight)
- Suggested config home: `Core/Analysis/Config/BiologicalAgeConfig.swift` (struct `RHRAgeBrackets`)
- Source citation status: NONE (only the comment "Population norms: RHR increases with poor cardiovascular health… Young fit adult: ~55-65 bpm…")

### `computeHRVAge(context:)` in `BiologicalAgeAnalyzer.swift`
- Lines 249-265
- Constants found: `70`, `50`, `35`, `20`, `22`, `40`, `55`, `75`, `18`, `15`, `15`, `20`, `10`, `10`, `90`, `0.10` (component weight)
- Suggested config home: `Config/BiologicalAgeConfig.swift` (struct `HRVAgeBrackets`)
- Source citation status: NONE (comment "HRV population norms (SDNN): 20s: ~60-80ms, 40s: ~40-60ms, 60s: ~25-40ms" — no source link)

### `computeMobilityAge(context:)` in `BiologicalAgeAnalyzer.swift`
- Lines 218-247
- Constants found: walking speed `1.4`, `1.2`, `1.0`, `0.8`, age anchors `25`, `40`, `55`, `15`, `20`, `85`; double support `20`, `3`, `0.15` (weight)
- Suggested config home: `Config/BiologicalAgeConfig.swift` (struct `MobilityAgeBrackets`)
- Source citation status: NONE

### `computeActivityRhythmAge(context:)` in `BiologicalAgeAnalyzer.swift`
- Lines 178-216
- Constants found: rhythm bands `0.55`, `0.35`, `0.5`, `0.5`, age anchors `25`, `50`, `0.20`, `0.20`, `25`, `25`, `90`, weight `0.20`
- Suggested config home: `Config/BiologicalAgeConfig.swift`
- Source citation status: NONE (CosinorAge is cited at file header but the bracket cutoffs are unsourced)

### `findFitnessAge(vo2max:)` and `computePercentile(vo2max:bracket:)` in `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/Research/CardioRespiratoryAgeAnalyzer.swift`
- Lines 27-35 (bracket table) and 153-199
- Constants found: 7 brackets × 6 percentiles each (28, 32, 35, 40, 45, 50; 26, 30, 33, 37, 42, 47; …); ageMidpoints `[24, 35, 45, 55, 65, 75, 85]`; magic numbers `5`, `10`, `25`, `50`, `75`, `90`, `95`, `97`
- Suggested config home: `Config/CardioRespiratoryAgeConfig.swift`
- Source citation status: header cites Apple Heart & Movement Study but no DOI; "Approximated from published averages + population distributions" is hand-wavy

### `WorkoutRecoveryBand.init(score:)` and `recoveryScoreSeed` in `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/WorkoutProgrammer.swift`
- Lines 88-107
- Constants found: thresholds `75`, `50`; seed scores `35`, `65`, `82`
- Suggested config home: `Config/WorkoutBandsConfig.swift`
- Source citation status: NONE

### `sleepDurationScore`, `sleepStageScore`, `workoutRecoveryScore`, `hrvScore`, `rhrScore`, `stressLevel`, `stressLabel`, `stressColorName` in `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/ReadinessScorer.swift`
- Lines 163-242 (and lines 99, 108, 115 in `assess` for the score-blend constants)
- Constants found: `60`, `40`, `50`, `30`, `7.5` (target hours), `13`, `4`, `7`, `2`, `0.16`, `0.24`, `1.8` (tanh divisor), `55`, `35`, `15`, `85`, `40` (RHR), `75`, `0.40`, `0.35`, `0.15`, `0.06`, `0.04` (signal weights), `21.0` (baseline confidence cap), `0.55` (default baseline confidence), `48 * 3600`, `72 * 3600`, `36.0`, `24.0`, `12.0`, `0.5` (recency penalty), `0.65`, `0.35` (freshness floor/ceiling), `35`, `25` (workout penalties)
- Suggested config home: `Config/ReadinessScorerConfig.swift`
- Source citation status: NONE; constants documented as `defaultSmoothingAlpha`, `defaultMinimumSampleCount` only at type level

### `calculateNeed(...)` in `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/SleepNeedCalculator.swift`
- Lines 100-143
- Constants found: age cutoffs `26`, `64`; recovery cutoffs `40`, `60`, `80`; strain cutoffs `15`, `10`; adjustments `0.25`, `0.5`, `-0.25`; debt/quality flat `0.25`
- Suggested config home: `Config/SleepNeedConfig.swift`
- Source citation status: comment "(NSF)" but no link

### `computeZoneAndRange(...)` in `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/StrainCoach.swift`
- Lines 199-228 (plus the `strainRange(for:)` switch at lines 47-67)
- Constants found: 12 ranges (0...9, 10...14, 14...18, 18...21, 0...7, 8...12, 0...0, 0...5, …) + targets `(12.0, 10.0, 14.0)`, `(16.0, 14.0, 18.0)`, `(15.5, 14.0, 17.0)`, `(7.0, 5.0, 9.0)`, `(11.5, 10.0, 13.0)`, `(5.0, 0.0, 5.0)`, plus `consecutiveHighThreshold = 3`, `highStrainValue = 14.0`, `restDayThreshold = 5.0`, ratio cutoffs `0.7` / `1.3`
- Suggested config home: `Config/StrainCoachConfig.swift`
- Source citation status: NONE

### `computeNormalizedLoad(...)` and `zoneMultipliers` in `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/StrainScorer.swift`
- Lines 95-101 (zoneMultipliers `[1: 1.0, 2: 2.0, 3: 4.0, 4: 8.0, 5: 14.0]`) and 360-393 (load weights `150.0`, `10.0`, `30.0`, `15.0`, `20.0`, `2.0`, `0.5`); plus `maxExpectedLoad = 800.0`, `minimumDaysForBaseline = 7`, fallback `400.0`, fallback RHR `65.0`, ladder for HR zone classification (0.5, 0.6, 0.7, 0.8, 0.4)
- Suggested config home: `Config/StrainScorerConfig.swift`
- Source citation status: comment "Inspired by WHOOP's strain model" but no spec link; "Calibrated so that an elite-level training day (~1200 kcal active, 90 min zone 4-5) maps to approximately strain 20-21" is internal calibration, not external

### `StrainLevel.init(strain:)` in `StrainScorer.swift`
- Lines 15-24
- Constants found: thresholds `6`, `10`, `14`, `18`, `20` (strain bucket boundaries 0-21)
- Suggested config home: `Config/StrainScorerConfig.swift`
- Source citation status: NONE

### `applyCoverageAdjustment(...)`, `adaptiveCategoryWeights(...)`, `adaptiveMetricWeights(...)` in `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/HealthScorer.swift`
- Lines 200-470
- Constants found: floor `0.05`, neutral `75.0`, power `0.6`, CV-volatility `0.5 + cv * 5.0` capped at `2.0`, focus boost `1.2`, freshness ramp `1.0 → 0.7 (7d) → 0.3 (30d)` with multipliers `0.05` and `0.017`, anomaly density `0.5 + 1.5 * density`, richness `0.3 + 0.7 * coverage`
- Suggested config home: `Config/HealthScorerConfig.swift`
- Source citation status: NONE; only doc-comment heuristics

### Sub-bucket: Notification + grade buckets (smaller, but still inline)
- `Core/Notifications/DailySummaryScheduler.swift:147-155` — `gradeFor(score:)`: `90...100 → "A"` etc. — duplicated from `HealthScore.grade`
- `App/BackgroundRefreshCoordinator.swift:57-65` — `gradeForScore(_:)` slightly different: `90...100 → "A+"`, no `"F"`
- `Core/Notifications/EngagementSequenceScheduler.swift:443-459` — Day 5 personalization `percent`/`daysRemaining` ladder by `daysSinceInstall` (`0...2`, `3...13`, `14...20`, `21...29`, `default`); constants `20, 28, 40, 21, 60, 30, 80, 30, 100`
- `Core/Notifications/EngagementSequenceScheduler.swift:629-639` — `insightForScore(_:)` ladder (`85...100`, `70..<85`, `55..<70`, `40..<55`, `default`)
- `Core/Tracking/AppAnalytics.swift:1365-1367, 1819` — `"healthy"`/`"watching"`/`"at_risk"` ladder by overall score; another `case 85...100` switch at 1819
- Suggested config home: bucket constants into `Config/ScoreBucketsConfig.swift` and reuse `HealthScore.grade`

---

## Notes / Context

- The codebase already has excellent centralization in some places (`Core/Extensions/Date+Extensions.swift` formatter cache, `Core/Extensions/Collection+Statistics.swift` mean/median/percentile/regression, `Core/Analysis/AccelerateHelpers.swift` vDSP fast-paths, `BrainHealthScorer` and `StressScorer` named-constant catalogs at the top of each class, `IllnessEarlyWarning.swift` with explicit named thresholds, `RulesConfiguration.swift` for normal ranges and critical thresholds). Bucket 4 violations cluster in the `Research/` analyzers (BiologicalAgeAnalyzer, CardioRespiratoryAgeAnalyzer) and the WHOOP-style scorers (StrainScorer, StrainCoach, ReadinessScorer, SleepNeedCalculator) where the threshold ladders are inlined.
- Bucket 2 is dominated by analyzer commentary (titles + summaries + recommendations passed into `InsightFactory.make/observation/medicalAdvice`). These are real product copy rendered to the dashboard. The volume (469 returns across analyzers) is large because every Research analyzer inlines 2-4 insight triples. Migrating these to per-module `Copy+Analysis.swift` (already present at `Modules/Insights/Copy+Analysis.swift`) is the unblocker.
- Bucket 3 is dominated by the `Pass <N>` audit-trail comments (61 hits). They are not actively misleading, just noise. The `Research:` headers also routinely cite a year-stamped study but never a DOI; that pattern is consistent enough to deserve a project rule.
- Bucket 1's biggest cleanup is the `Calendar.current` allocation pattern: 14+ files have copy-pasted the `private static let cal: Calendar = Calendar.current` cache (each tagged `Pass 11 AF`/`Pass 12 BE perf`), and another 113 files still call `Calendar.current` inline. The intended fix (a single `Date.cal`) already exists but is `private`.

Confidence: 82/100 — file paths and line numbers verified by reading every file cited in Buckets 1, 3, and 4 and a representative sample (~20 files) for Bucket 2; the 469-string total in Bucket 2 is a regex-derived estimate (`return "[A-Z][^,]+"` heuristic, not hand-counted), so the per-file numbers in the table are high-confidence but the rolled-up total may include 5-10% false positives (debug strings, enum raw values intermixed with display strings, Foundation symbol names like `"figure.walk"`). Magic-number lists in Bucket 4 are read-from-source. Did not run a build.

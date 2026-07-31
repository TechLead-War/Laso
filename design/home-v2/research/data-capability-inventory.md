# Laso Data + Signal Capability Inventory

Reference for the Home Screen v2 redesign. Everything below was read out of the
code in this repo, not assumed. Where a claim comes from platform behaviour
rather than this codebase it is marked **[platform]**.

Read date: 2026-07-29. Branch `main` @ `cbb674f` (v3.26).

**Scale note used throughout:** the stored series unit is whatever
`HealthMetric.unit` advertises. Sleep is stored in **hours**, not seconds.
Percent metrics are stored on a **0 to 100** scale (the registry multiplies the
HealthKit 0-1 fraction by 100). Several bugs below come from code that forgot
one of those two facts.

---

## 1. Raw HealthKit metrics ingested

Source of truth: `Core/Models/HealthMetric.swift` (enum, 71 cases) and
`Core/Data/HealthKitMetricRegistry.swift` (HK type, unit, query strategy).

Sync: `Core/Data/HealthKitManager.swift:236 loadAndSync`. First sync pulls **10
years** of history per metric. Later syncs are incremental from `lastSync - 1
day`. Non-core metrics whose newest sample is >7 days old are skipped unless it
is every 7th sync. Core metrics are always fetched:
`heartRate, restingHeartRate, heartRateVariability, steps, activeCalories,
exerciseMinutes, sleepDuration, sleepREM, sleepDeep, sleepCore, bloodOxygen,
respiratoryRate, vo2Max, weight, workoutCount, workoutDuration`.

Storage: one row per metric per local day (`StoredDailySample`), so **the
persisted layer is daily-resolution only**. Intraday granularity exists only in
three special queries: `fetchTodayRawHeartRateSamples()`, `fetchHourlySamples()`
(24 hourly bins, needs >=12 hours with data, used by the circadian analyzer), and
the Live tab's anchored streams.

| # | Metric | Unit stored | HK type | Aggregation | Source needed |
|---|---|---|---|---|---|
| 1 | Heart Rate | bpm | heartRate | daily avg | Watch **[platform]** |
| 2 | Resting Heart Rate | bpm | restingHeartRate | daily avg | Watch |
| 3 | HRV (SDNN) | ms | heartRateVariabilitySDNN | daily avg | Watch |
| 4 | Walking Heart Rate | bpm | walkingHeartRateAverage | daily avg | Watch |
| 5 | Heart Rate Bounce-Back | bpm | heartRateRecoveryOneMinute | daily avg | Watch, after a workout |
| 6 | Irregular Heartbeat (AFib burden) | % | atrialFibrillationBurden | daily avg | Watch + AFib History enabled |
| 7 | Blood Flow (perfusion index) | % (x100) | peripheralPerfusionIndex | daily avg | Watch |
| 8 | Blood Oxygen | % (x100) | oxygenSaturation | daily avg | Watch **— see bug B1, currently discarded** |
| 9 | Sleep Duration | hrs | sleepAnalysis | sum per wake-day | Watch or 3rd-party sleep tracker |
| 10 | Dream Sleep (REM) | hrs | sleepAnalysis | sum per wake-day | Watch |
| 11 | Deep Sleep | hrs | sleepAnalysis | sum per wake-day | Watch |
| 12 | Light Sleep (core) | hrs | sleepAnalysis | sum per wake-day | Watch |
| 13 | Awake Time | hrs | sleepAnalysis | sum per wake-day | Watch |
| 14 | Breathing Trouble | events/hr | appleSleepingBreathingDisturbances (iOS 18+) | per-sample avg | Watch S9+/Ultra2 |
| 15 | Steps | steps | stepCount | daily sum | **iPhone alone works** |
| 16 | Active Calories | kcal | activeEnergyBurned | daily sum | Watch (iPhone gives partial) |
| 17 | Resting Calories | kcal | basalEnergyBurned | daily sum | Watch |
| 18 | Exercise Minutes | min | appleExerciseTime | daily sum | Watch |
| 19 | Stand Hours | hrs | appleStandTime | daily sum | Watch |
| 20 | Distance (walk/run) | km | distanceWalkingRunning | daily sum | **iPhone alone works** |
| 21 | Flights Climbed | flights | flightsClimbed | daily sum | **iPhone alone works** |
| 22 | Cycling Distance | km | distanceCycling | daily sum | Watch or phone workout |
| 23 | Swimming Distance | km | distanceSwimming | daily sum | Watch |
| 24 | Swimming Strokes | strokes | swimmingStrokeCount | daily sum | Watch |
| 25 | Move Time | min | appleMoveTime | daily sum | Watch |
| 26 | Running Power | W | runningPower | daily avg | Watch S8+/Ultra |
| 27 | Ground Contact Time | ms | runningGroundContactTime | daily avg | Watch S8+/Ultra |
| 28 | Bounce While Running | cm | runningVerticalOscillation | daily avg | Watch S8+/Ultra |
| 29 | Running Stride | m | runningStrideLength | daily avg | Watch S8+/Ultra |
| 30 | Dive Depth | m | underwaterDepth | per-sample avg | Watch Ultra |
| 31 | Water Temperature | °C | waterTemperature | per-sample avg | Watch Ultra |
| 32 | Weight | kg | bodyMass | daily avg | Manual or smart scale |
| 33 | BMI | – | bodyMassIndex | daily avg | Manual or smart scale |
| 34 | Body Fat % | % (x100) | bodyFatPercentage | daily avg | Smart scale |
| 35 | Blood Pressure (top) | mmHg | bloodPressureSystolic | per-sample avg | External cuff |
| 36 | Blood Pressure (bottom) | mmHg | bloodPressureDiastolic | per-sample avg | External cuff |
| 37 | Breathing Rate | br/min | respiratoryRate | daily avg | Watch (overnight) |
| 38 | Body Temperature | °C | bodyTemperature | daily avg | External thermometer |
| 39 | Wrist Temperature | °C | appleSleepingWristTemperature | daily avg | Watch S8+/Ultra, worn asleep |
| 40 | Lean Body Mass | kg | leanBodyMass | daily avg | Smart scale |
| 41 | Waist Size | cm | waistCircumference | daily avg | Manual |
| 42 | Cardio Fitness (VO2max) | mL/kg/min | vo2Max | daily avg | Watch, outdoor walk/run |
| 43 | Breathing Speed | L/min | peakExpiratoryFlowRate | daily avg | External spirometer |
| 44 | Lung Capacity | L | forcedVitalCapacity | daily avg | External spirometer |
| 45 | 1-Second Breath Out | L | forcedExpiratoryVolume1 | daily avg | External spirometer |
| 46 | Mindful Minutes | min | mindfulSession | daily sum | Watch or any mindfulness app |
| 47 | Time in Daylight | min | timeInDaylight | daily sum | Watch S8+ |
| 48 | Skin Response (EDA) | µS | electrodermalActivity | daily avg | 3rd-party only, no Apple sensor |
| 49-57 | Walking Speed, Step Length, Uneven Walking, Both Feet Down %, Stairs Up/Down Speed, 6-Min Walk, Walking Steadiness, Falls Detected | km/h, cm, %, %, m/s, m, %, count | mobility family | daily avg / sum | **iPhone alone works** (carried in pocket) |
| 58-66 | Water, Caffeine, Protein, Fiber, Sugar, Sodium, Calories eaten, Carbs, Fat | mL, mg, g… | dietary* | daily sum | 3rd-party food logger, or manual |
| 67 | Blood Sugar | mg/dL | bloodGlucose | daily avg | CGM / manual |
| 68 | Insulin Delivery | IU | insulinDelivery | daily sum | Pump / manual |
| 69 | Workout Count | count | HKWorkout | daily count | Watch or phone workout |
| 70 | Workout Duration | min | HKWorkout | daily sum | Watch or phone workout |
| 71 | Headphone Audio / Surrounding Sound | dB | audioExposure | daily avg | iPhone / AirPods / Watch |

Also read but **not** part of the 71-metric enum:
- `menstrualFlow` category samples — `fetchMenstrualFlowSamples(days: 365)`.
- `HKElectrocardiogramType` — requested in authorization, features stored in
  `StoredECGFeatures`.
- Date of birth (`dateOfBirthComponents`) — gates Strain, Vitality, Sleep Need.
  If no DOB anywhere, those three engines **do not run at all**
  (`DashboardViewModel.resolveChronologicalAge` returns nil, no fake default).

### Sleep day rule (matters for any "last night" copy)
`HealthKitManager.sleepDay(for:)` books a whole session on the day the user
**woke up**. The sample's date is the wake time of that day's longest session, so
reading `timeSeries[.sleepDuration].last` gives last night, and its `.date` is
the wake timestamp.

---

## 2. Derived scores and states

| Score | Range | Driven by | Refresh | Ready after | Confidence handling |
|---|---|---|---|---|---|
| **Daily Health Score** (`AnalysisEngine.overallScore`) | 0-100 | Per-metric anomaly z-scores + trend direction → category scores → adaptive category weights (volatility, coverage, anomaly density, user focus) → coverage shrinkage toward 75 | Every refresh; one `StoredAnalysisSnapshot` per day | Any metric with a 7-day baseline | `applyCoverageAdjustment` pulls sparse users toward **75**. `scoreExplanation` gives per-category contribution + top 3 factors |
| **Recovery / Readiness** (`ReadinessScorer`, `LiveViewModel`) | 0-100 | Weighted, confidence-scaled blend of HRV vs 60-day baseline, RHR vs baseline, sleep duration, sleep-stage ratio, recent workout load; EMA smoothed (alpha 0.7) | **Locked once each morning** per calendar day (`ReadinessStore.saveMorningLock`), then drained live by active calories (`kcalPerStrainPoint`) | Needs last-night sleep AND HRV+RHR fresher than `morningLockFreshnessHours` | Publishes `confidence` (0-100) and `uncertainty` (points the centre-pull moved the raw reading). Killable via Firebase RC `killReadinessScorer` |
| **Strain** (`StrainScorer`) | 0-21 log scale | Active calories vs 28-day baseline + HR zone minutes (Karvonen reserve) + exercise/workout duration (sqrt) + steps/distance NEAT | Every refresh; persisted per day (`StoredDailyStrain`) | Needs DOB; personal calorie baseline at 7 days, else population 400 kcal | `isReady`. Falls back to 65 bpm RHR and 400 kcal baseline when data is thin |
| **Stress** (`StressScorer`) | 0-100 | HRV below 14-day baseline (60%) + RHR above baseline (40%); ceiling anchored at a 50% HRV drop | Every refresh; 90-day daily history rebuilt | **3 days** of HRV | No explicit confidence. History days without a trailing baseline are dropped |
| **Brain Health** (`BrainHealthScorer`) | 0-100 | Cognitive readiness .30 (HRV/deep/REM/duration), memory recovery .25 (REM+deep), stress-cognition .20, neurovascular .15 (VO2max/RHR/steps), circadian alignment .10 (sleep-timing CV) | Every refresh; 90-day history | **7 days** of HRV | Explicit `confidence` 0-1 built from which signals are present + HRV stability |
| **Vitality Age** (`VitalityScorer`) | years (18-95) | 9 weighted metric-ages vs age norm tables: VO2max .25, HRV .20, RHR .15, walking speed .10, sleep efficiency .08, deep sleep % .07, steps .05, exercise min .05, body comp .05 | Every refresh; recorded onto the day's snapshot (`vitalityAge`) | Needs DOB. Held at chronological age for first **7 days**, ramps to full personalization at **30 days** | `personalizationProgress` 0-1 and a 3-state label: Building your profile / Early estimate / Personalized. Norm tables are explicitly documented as heuristic, no DOIs |
| **Pace of Aging** | ~1.0 | Slope of recorded vitality-age history | With Vitality | `hasPaceEstimate` false until enough recorded days (window 90, min 7) | Refuses to quote a pace off a short window |
| **Sleep Debt** (`SleepDebtTracker`) | hours | 14-day rolling deficit vs max(30-day avg, 7.5h floor) | Every refresh | **7 of the last 14 nights** recorded | `nightsRecorded` exposed. Surfaces only above `actionableDebtHours = 2.0` |
| **Sleep Need** (`SleepNeedCalculator`) | hours + bedtime | Strain, sleep debt, target wake time, age, recovery score | Every refresh | 7 days of sleep | `isReady` |
| **Cycle phase** (`MenstrualCycleTracker`) | day + phase (menstrual/follicular/ovulation/luteal) | 365 days of `menstrualFlow` samples → cycle starts → average length | Every refresh, gated on female profile + tracking preference | Needs at least one recorded bleed start | Snapshot expires after `snapshotMaxAge` |
| **Health State** (`HealthStateClassifier`) | discrete labels + transition matrix | GMM over daily feature vectors | ML phase | **14 days** | `isReady` |
| **Level / Streaks / Achievements** (`GamificationEngine`) | level enum, `masterStreak` int | Session days, score history, time series | Every refresh | Day 1 | — |

Three-band recovery colour lives in one place: `DS.recoveryTier` →
`RecoveryState(green/yellow/red)`.

---

## 3. Insight / risk / anomaly / correlation types the engine can emit

### 3a. Insight categories (`InsightCategory`, 26 cases)
`anomaly, trend, correlation, recovery, workoutEffectiveness, sleepPerformance,
weeklyPattern, personalRecord, scoreTrajectory, baselineDrift,
multiMetricCluster, watchSignal, causalChain, crossMetricAnomaly,
cognitiveEnergy, brainHealth, cyclePhase, mlPattern, mlState, mlPrediction,
simulation, adherenceFeedback, circadian, clinicalTrajectory, ecgIntelligence,
nutritionCorrelation`

Every `Insight` carries: metric, title, summary, recommendation, severity
(info/warning/critical), trend, baselineValue, deviationPercent, category,
`directive` (rest / reduceIntensity / increaseActivity / pushHarder / sleepMore /
sleepBetter / seekMedical / maintain / informational), and optional
`InsightContext` (slope, projected days to threshold, percentile, seasonal
deviation, YoY change, correlated factors, root-cause metric, confidence level,
data point count). `InsightCoordinator.coordinate` resolves conflicting
directives.

### 3b. Health risks (`HealthRiskEngine`, 7 profiles)
`cardiac, sleepDeficit, overtraining, respiratory, metabolic, stress,
mobilityDecline`. Each returns level 0-100 → grade
`low / moderate / elevated / high / veryHigh`, a list of `RiskFactor`
(contribution, status `optimal|borderline|concerning|critical|unmeasured`,
current value, optimal range, explanation) and ranked `FocusArea`s.
Home shows only grades above `.low`, max 2 rows.

Real strings: `"Heart Health Pattern"`, `"Training Load Pattern"`,
`"Worth a look"`, `"Outside your usual"`, `"Not Measured"`.

### 3c. Body-stress early warning (`IllnessEarlyWarning`)
Watches 5 signals simultaneously: RHR up, HRV down, sleep down, steps down,
respiratory rate up. Needs **14 days** of baseline (days 4-17 back), a >=1.0
sigma deviation, **>=2 metrics** signalling for **>=2 consecutive days**.
Suppressed entirely if active calories on any signal day exceeded 1.5x baseline
(exercise-recovery guard). Sleep duration alone can never trigger it.

Emitted narrative is assembled, e.g.:
> "Your resting heart rate has trended 8% above baseline for 3 days (64 vs 59
> bpm), while your heart rate variability dropped 14% below baseline over 3 days
> (41 vs 48 ms). …"

Severity ladder: 2 metrics/2 days = info, 3+/2 days = warning, 3+/3 days =
critical. Confidence 0-100 from metric count + streak + magnitude.

### 3d. Correlations (`CorrelationAnalyzer`)
**35 hand-picked physiologically plausible pairs** with automatic lag discovery
(lags 0-3). Requires **>=14 aligned days**. Examples in the registry: sleep
duration → next-day RHR, deep sleep → next-day HRV, exercise minutes → next-day
HRV, mindful minutes → HRV, steps → sleep duration, respiratory rate → deep
sleep, VO2max → RHR.

ML side adds `CorrelationDiscovery` (min 7 common days), `GrangerCausalityEngine`,
and `InteractionEffectEngine` (interaction effects + dose-response curves).

### 3e. Causal chains (`CausalChainEngine`)
Chains of up to 3 links, min |r| 0.3, min z 1.5 or 5% WoW change, with a
`trivialPairs` blocklist (steps↔calories, weight↔BMI, sleep↔sleep stages, etc.).
Real assembled copy from `Copy+Causation.swift`:
> "%@ Shifted, %@ Is Why"
> "Your data shows a moderate link (r 0.42). Effects appear about a day later."
> "At this rate, your heart rate variability could reach warning level in about 12 days."

### 3f. Intelligence briefing cards (`TodayIntelligenceEngine`, 10 types)
`predictiveRisk, regimeShift, cascadeForecast, hiddenDriver, bodyClockStatus,
allostaticLoad, autonomicBalance, recoveryDebt, systemCoherence,
rhythmDeviation`. Severity `info/notable/warning/critical`.

Real copy defaults from `Copy+Briefing.swift`:
> "There is about a 62% chance tomorrow feels tougher than usual. An earlier bedtime tonight could help."
> "Your resting heart rate has been rising since 12 June. That is a real shift worth noticing."
> "Your deep sleep lifts your heart rate variability about a day later. This pattern keeps showing up for you."
> "Your body feels strongest for exercise between 4 PM and 7 PM."
> "Your body is carrying more than usual right now. Your nervous system feels the most tired, so a slower day would help."
> "Tiredness has been building up over the last few days. Extra sleep tonight would help."

### 3g. Other emitters
- `CrossMetricAnomalyDetector` — multi-metric simultaneous anomalies.
- `AdaptiveAnomalyDetector` — isolation-forest, min **14 days**.
- `ChangePointDetector`, `TemporalSequenceMiner` (sequences + precursors),
  `CompoundInsightEngine`, `PersonalOptimizer` (optimal profile, ideal day,
  score sensitivities), `PredictiveHealthSignals` (health signal report),
  `CircadianAnalyzer` (profile + timing recommendations), `WeeklyPatternAnalyzer`,
  `PersonalRecordAnalyzer`, `ScoreTrajectoryAnalyzer`, `BaselineDriftDetector`
  (compares today vs 30/90/180/365 days ago), `NutritionCorrelationAnalyzer`,
  `CognitiveEnergyAnalyzer`, `ClinicalIntelligence`, and the Research folder
  (biological age, sleep coherence, sleep regularity min 14d, circadian
  disruption min 21d, temperature compound min 21d, inflammation risk min 30d,
  wellbeing trend).

---

## 4. What "Today's Action" can actually recommend

`DashboardSmartActionAdvisor.recommend` is a strict priority ladder. Cached once
per calendar day, invalidated on analysis refresh or a life-context toggle.
Rotation logic pushes an action down if it has led 2 consecutive days.

| Priority | Source tag | Fires when | Example title |
|---|---|---|---|
| 0 | `life_context` | User toggled a rest context (`injured`, `unwell`, others with `requiresRest`) | context rest title (overrides everything, including a strong recovery score) |
| 0b | `sleep_bank` | Debt >= 2.0h **and** trending up (last 3 nights worse than the 3 before) | "Pay back your sleep" |
| 1 | `policy_engine` | `PolicyDecision` exists with `decisionConfidence >= 0.3` | one of the 17 action types below |
| 2 | `insight_driven` | Top insight severity >= warning or priority > 3.0 | "Ease off. Deep Sleep needs attention" |
| 3 | rule | stress >= 60 / sleep < 5.5h / readiness < 40 | "Take a breathing break", "Prioritise sleep tonight" |
| 4 | `insight_driven` | Any insight at all | as row 2 |
| 5 | focus rules | User focus = sleep/fitness/heartHealth/recovery and the matching gap exists | "Get to bed 30 min earlier", "You're 12 min from your goal", "Your resting heart rate is trending up", "Focus on recovery today" |
| 6 | activity | Exercise goal met, or readiness >= 60 and minutes remain | "Goal hit", "12 minutes to go" |
| 7 | wind-down | Local hour >= 20 | wind-down title |
| 8 | fallback | Nothing else fired | default "take a walk" copy |

**The 17 policy-engine action types** (`InterventionCandidate.ActionType`):
`sleepEarlier, sleepLater, extendSleep, reduceScreenTime, reduceEvening,
activeRecovery, intensifyExercise, reduceExercise, shiftCaffeineTiming,
reduceCaffeine, breathingSession, meditation, adjustMealTiming, hydration,
increaseSteps, reduceSteps, napRecommendation`.

Policy candidates come from 8 sources: `predictiveModel, causalDiscovery,
circadianTiming, stateTransition, anomalyResponse, trendReversal,
baselineRecovery, counterfactual`. Utility = uplift x confidence x adherence x
novelty x (1 - effort), boosted 1.3x for focus-area metrics, with a 14-day
exposure/fatigue suppressor.

Only the policy engine produces `expectedBenefit`; every rule-based branch leaves
it empty (Home only renders the benefit chip when non-empty — honest).

Real policy copy defaults:
> "Your risk for tomorrow is higher than usual (68% sure). The biggest cause is your deep sleep, and this step fixes it directly."
> "Your data shows a strong link: changes in exercise minutes lead to health changes 2 days later. This isn't just a coincidence, it's a real cause."
> "You're 9 ms below your usual. Your body feels best near 48 ms, so closing this gap gives you the biggest win right now."
> "Last time you did this, your heart rate variability went up by 6 ms across 5 days."

Action is closable: `DailyActionCompletion.markDone`, `ActionReminderScheduler`
one-off reminder, and `DailyActionResultStore` surfaces the next morning whether
the score moved.

---

## 5. What the app knows about yesterday / today / 7 / 30 days

| Question | Available? | Where |
|---|---|---|
| Yesterday's overall score | Yes | `computeYesterdayScore()` — reads `StoredAnalysisSnapshot`. Stored 0 is treated as "never scored", not as a real zero |
| Score delta vs yesterday | Yes, two flavours | `scoreChangeFromYesterday` (folds 0 into nil, for push/analytics) and `scoreDeltaFromYesterday` (keeps explicit 0, for the Home chip) |
| Yesterday's baselines as they were then | Yes | `analysisSnapshot(on:)` returns the day's score plus the baseline dict in force that day |
| Yesterday's strain | Yes | `StoredDailyStrain` per day, with the level word assigned at the time |
| Full day-by-day explanation of any past day | Yes | `DashboardViewModel.dayDetail(for:)` — HRV, RHR, sleep vs that day's baseline, plus strain, plus which signals were missing. Nothing is back-filled |
| Today's live values | Yes | `LiveViewModel` — anchored HR/SpO2/respiratory streams, observer queries for steps/calories/exercise/stand/distance/flights, plus last-night sleep and latest workout |
| Rolling 7-day | Yes | `periodSummary(for:)` improved/declined/stable per metric, `computeTrendMetrics(days:7)`, `computeHistoricalHighlights()` week-over-week |
| Rolling 30 / 90 | Yes | `TrendState.cachedTrendMetricsByTimeframe` holds exactly 7, 30, 90 |
| Longer periods | Yes | `TimePeriod` enum supports 7D/30D/3M/6M/1Y/All (All = 3650 days) |
| Score calendar | Yes | `cachedDailyScoresByDay` for **366** days, `cachedContextsByDay` for the same window |
| Weekly smoothed score | Yes | EWMA lambda 0.2 over **14 completed days**, plus EWMA-vs-EWMA-7-days-ago delta |
| Improving streak | Yes | `computeImprovingDays()` counts consecutive day-over-day improvements in the last 7 |
| Behaviour log | Yes | `StoredJournalEntry` with 9 categories: caffeine, alcohol, stress, supplements, meditation, screen time, meal timing, water, mood |
| Life context per day | Yes | `LifeContextStore` — `injured, unwell, travelling, poorSleepWeek`, stored as date ranges, so toggling one rewrites past days |
| Whether advice worked | Yes | `StoredRecommendation` with 24h and 7d lift evaluation, surfaced as `RecommendationEvaluator.buildActionProof` |

**Retention** (`DataRetentionManager`, RC defaults):
daily samples **never pruned** (0), analysis snapshots 365d, daily strain 365d,
recommendations 90d, notification events 90d, adherence 90d, ECG features 730d,
journal 365d, model evaluations 180d.

**Backfill**: on a fresh install `backfillScoreHistoryIfNeeded()` replays
`AnalysisEngine.replay(asOf:)` over the last 14 days so the EWMA weekly score has
real history immediately instead of needing two weeks of app usage. The replay
deliberately omits trends (anomaly-only scoring) — so backfilled days are not
identical to lived days.

---

## 6. What the app can forecast, and how much to trust it

`TimeSeriesForecaster` — Holt-Winters with damped trend and optional double
seasonality, grid-searched, persisted between launches, incrementally updated
daily.
- Minimum **7 days** per metric.
- Horizons produced: **1, 3, 7 days**, each with `ciLower` / `ciUpper` from a
  1.96 z-score on residual SD.
- `detectAnomalies` turns large normalized residuals into extra anomalies that
  merge into the main anomaly list.

`ForecastBuilder.buildForecasts` picks up to 3 from
`heartRateVariability, restingHeartRate, sleepDuration, steps, vo2Max,
activeCalories, sleepDeep` and renders `PersonalHealthForecastCard`.
`confidence = clamp(1 - ciWidth / (2*|value|), 0.5, 0.95)` — this is a **display
heuristic derived from interval width, not a calibrated coverage probability**.
The card labels it "conf 82%", which reads as calibrated and is not.

Other forward-looking outputs:
- `tomorrowRiskPrediction` (`PredictiveScorer`, gradient-boosted trees, min
  **14 days**, Platt-scaled).
- `PredictiveHealthSignals.healthSignalReport` — named signals with a horizon.
- `TemporalSequenceMiner.precursorPatterns` — "this sequence has preceded X".
- `PersonalOptimizer.idealDay` / `scoreSensitivities` — what-if.
- `Copy.Causation.projection`: "At this rate, your X could reach warning level in
  about N days" — a linear slope extrapolation, no interval.

**Trust summary:** the forecast machinery is real and on-device, the intervals
are real, but nothing in the app back-tests forecast accuracy and surfaces it to
the user. `MLEvaluator` / `StoredModelEvaluation` exist but are not shown on any
screen. Treat a Home forecast as directional at best.

---

## 7. iPhone-only vs Watch-required

The app's own heuristic (`DeviceSourceManager.identifyDevice`) treats
`heartRate, bloodOxygen, sleepDuration` as watch-only markers.
`isAppleWatchPaired` = a Watch source delivered data in the last 7 days.

**Works with iPhone alone:** steps, distance walking/running, flights climbed,
the whole mobility family (walking speed, step length, asymmetry, double support,
stair speeds, steadiness, falls, 6-min walk), headphone/environmental audio, and
anything a third-party app or manual entry writes (weight, BP, nutrition,
glucose, mindful minutes, sleep from a non-Apple tracker).

**Needs a Watch (or equivalent wearable):** heart rate, resting HR, HRV, walking
HR, HR recovery, AFib burden, perfusion index, blood oxygen, respiratory rate,
sleeping wrist temperature, all sleep stages, exercise minutes, stand hours, move
time, active/resting calories at any useful fidelity, VO2max, time in daylight,
all running-form metrics, swimming, dive depth, breathing disturbances.

**Consequence for Home:** with iPhone only, these are all unavailable —
Recovery/Readiness (no HRV/RHR/sleep), Stress (HRV), Brain Health (HRV), Sleep
Debt, Sleep Need, the sleep tile, Strain HR zones (falls back to a calories +
steps estimate), and 4 of the 5 rows in the "Why" list. Vitality still runs but
loses VO2max (.25), HRV (.20) and RHR (.15) — 60% of its weight — leaving walking
speed, steps, exercise minutes and body composition.

A Home Screen that promises "Recovery" as its hero number cannot deliver that
promise to an iPhone-only user. What it *can* promise on iPhone alone: steps and
distance today, week-over-week movement trends, mobility trend, the Daily Health
Score (coverage-shrunk), journal, life context, weekly review.

---

## 8. Time-to-first-value per signal

Important nuance: **first sync pulls 10 years of HealthKit history**. A "new
user" who has worn a Watch for a year is *not* data-poor on day 1. These are days
of *recorded wearable history*, not days since install.

| Signal | Days of history needed | Constant |
|---|---|---|
| Steps / calories / today's activity | 0 (same day) | live queries |
| Any baseline at all | **7** | `BaselineCalculator.compute` guard `count >= 7` |
| Personal band | 14 | `PersonalBand.minimumDays` |
| Trend direction | 3 samples | `TrendAnalyzer.analyze` |
| Anomaly detection (rule) | 7 (needs a baseline) | `AnomalyDetector` z-scores off `UserBaseline` |
| Readiness morning lock | 1 night + fresh HRV/RHR; baseline quality ramps to full at 10 samples (60-day window) | `ReadinessScorer.defaultMinimumSampleCount = 10` |
| Strain | same day, but personal calorie baseline at **7** (else 400 kcal default) | `StrainScorerConfig.minimumDaysForBaseline` |
| Stress | **3** | `StressScorer.minimumDaysRequired` |
| Sleep debt | **7 of last 14 nights** | `SleepDebtTracker` guard |
| Sleep need | **7** | `SleepNeedConfig.minimumDaysRequired` |
| Brain health | **7** | `BrainHealthScorer.minimumDaysRequired` |
| Circadian biomarkers | **7** | `CircadianHealthAnalyzer.minimumDays` |
| Vitality (starts) | 1, but pinned to chronological age for **7**, fully personalized at **30** | `VitalityScorer` |
| Vitality trend chart | **7 recorded days**, window 90 | `minimumTrendDays` |
| Forecasts | **7** per metric | `TimeSeriesForecaster.minimumDays` |
| ML correlations | **7** common days | `CorrelationDiscovery.minimumDays` |
| Rule correlations | **14** aligned days | `CorrelationAnalyzer` guard |
| Illness early warning | **14** baseline days + 2-day streak | `IllnessEarlyWarning.minimumDataDays` |
| Health state classifier | **14** | `HealthStateClassifier.minimumDays` |
| Adaptive anomaly (isolation forest) | **14** | `AdaptiveAnomalyDetector.minimumDays` |
| Tomorrow risk prediction | **14** | `PredictiveScorer.minimumDays` |
| Sleep regularity | 14 | Research analyzer |
| Discovery (day-0 wow moment) | **30**, and needs >=3 discoveries or it silently skips | `DiscoveryEngine.minimumDaysRequired` |
| Circadian disruption / temperature compound | 21 | Research analyzers |
| Inflammation risk | 30 | Research analyzer |
| Weekly EWMA score | 14 completed days (back-filled on install) | `WeeklyScoreSmoothing.windowDays` |
| Baseline drift | 30 snapshots minimum | `loadAllBaselineHistory(minCount: 30)` |

**Practical bands for Home v2:**
- Day 1 with no wearable history: steps, distance, journal, life context, Daily
  Health Score shrunk hard toward 75. Nothing else is honest.
- Day 1 with 1+ year of Watch history: everything except Vitality's full
  personalization (7-day hold) and the 30-day discovery reveal.
- Days 1-7 of genuinely new wearable data: Stress (day 3), then the 7-day wall
  opens baselines, Brain Health, Sleep Debt, Sleep Need, forecasts, circadian.
- Days 14-30: illness warning, correlations, ML state, tomorrow risk, then
  Vitality personalization and discoveries.

---

## 9. Computed today but never shown on Home (buried value)

Ranked by how much a Home slot would gain.

1. **Intelligence briefing** (`intelligenceBriefing`, 10 card types) — computed
   every refresh, rendered only on **Explore** (`TodayBriefingView`) and pushed
   to the widget. This is the app's best "non-obvious finding" copy and Home
   never shows it.
2. **Personal health forecast** (`healthForecasts`) — computed on Home's view
   model, rendered only on Explore. (See bug B2 before promoting it.)
3. **Circadian biomarkers** (`circadianBiomarkers`) — computed on every refresh
   in `refreshCircadianBiomarkers()` and **rendered nowhere in the app**. Dead
   output today.
4. **Dose-response curves** (`doseResponseCurves`) — stored on
   `AnalysisState`, rendered nowhere.
5. **Cross-metric anomalies** (`crossMetricAnomalies`) — stored on
   `AnalysisState`, rendered nowhere.
6. **Morning check-in adjustment** (`subjectiveReadinessAdjustment`) — Home
   *collects* it (`MorningCheckInView`) and assigns it, but **nothing ever reads
   it back into the readiness score**. The user answers three questions that
   change nothing.
7. **Score explanation** (`scores.scoreExplanation`) — per-category weighted
   contributions and the top 3 named factors with point impacts. Rendered on
   Explore (`ExploreNeedsAttentionSection`) only. Home builds its own separate
   5-row "Why" list and never uses the real attribution.
8. **Recommendation proof** (`RecommendationEvaluator.buildActionProof` with 24h
   and 7d lift per past recommendation) — computed into `SmartAction.proofSummary`
   but only surfaced on the Today's Action *detail* screen, not the Home card.
9. **Strain coach target** (`strainCoach.currentTarget.zone`, `strainBalance`) —
   a "what today should look like" day type plus an under/optimal/overreaching
   verdict. Reaches the Strain detail screen, the widget and the watch, never
   Home.
10. **Historical highlights** (`cachedHistoricalHighlights`, top 5 week-over-week
    moves with a recommendation each) — Explore only.
11. **Top correlations / causal chains / compound insights / interaction
    effects** — Explore and Insights only.
12. **Vitality pace of aging**, `personalizationStatus`, and per-component metric
    ages — Vitality detail only; Home's tile shows just the number and a badge.
13. **Data depth** (metrics tracked, total data points, days of data) — used only
    in the first-launch loading copy and Discovery.
14. **Signal coverage detail** — Home's `DataCoverageCard` only renders when
    something is *missing*; the "you have 13 of 14 days of HRV" positive state is
    computed and thrown away.

---

## 10. What Home shows today that the data cannot honestly support

**B1. Blood Oxygen is ingested and then 100% discarded — verified bug.**
`HealthKitMetricRegistry` applies `valueScale: 100` to `oxygenSaturation`, so
samples reach `MetricTimeSeries.init` as ~95-100. The outlier filter in
`Core/Models/MetricTimeSeries.swift:23-24` is:
```swift
case .bloodOxygen:
    return sample.value >= 0.5 && sample.value <= 1.0
```
Every real sample fails. The series ends up empty, `loadAndSync` skips storing
it, and each sync fires a `metric_time_series_outlier_dropped` analytics error.
Consequences on Home: `signalCoverage()` lists `.bloodOxygen` as one of the five
readiness signals, so **`DataCoverageCard` permanently tells every Watch user
"Blood Oxygen: none", and tells them to open Health settings**. The correct bound
is 50-100 (`RulesConfiguration` already uses `NormalRange(low: 95, high: 100)`).
Blood-oxygen correlations, the respiratory risk profile and the SpO2 half of the
Live tab's history are all silently dead too.

**B2. Sleep forecast renders as ~0.0h — verified bug.**
`MetricForecast.formatMetricValue` divides sleep values by 3600, assuming
seconds. The series is stored in **hours**. A 7.5h forecast prints "0.0h" with an
"Expected: 0.0h – 0.0h" range. Currently only on Explore. Do not move
`PersonalHealthForecastCard` to Home before fixing this.

**B3. The hero ring silently swaps two different scores.**
`HomeView.liveReadinessScore = liveViewModel.recovery.readinessScore ?? viewModel.overallScore.score`.
When no readiness exists the ring shows the **Daily Health Score** — an
anomaly/trend composite over up to 71 metrics — while `readinessSummary(score:)`
narrates it in recovery language ("your body is ready"). Those are different
quantities with different meanings. `hasLiveReadiness` is tracked and only
changes which explainer sheet opens; the number and the sentence do not change.

**B4. A sparse user's score is mostly a constant.**
`applyCoverageAdjustment` blends the raw score toward **75** with
`effectiveCoverage = pow(weightedCoverage, 0.6)`. A day-1 iPhone-only user with
two metrics gets a number dominated by the 75 prior. The ring presents it with
the same visual confidence as a fully covered user's score. Nothing on Home says
"this is a placeholder".

**B5. The "Energy" Why row explains the score with the score.**
In `recoveryWhyReasons`, the energy row's value is `liveVM.recovery.readinessScore
?? overallScore.score` — the same number the ring is showing — and its displayed
value is a fixed word ("Good"/"Low"), not a measurement. It is circular, and it
competes for the top slot via `dev = |score - 70| / 70`, so on an extreme day the
score explains itself before sleep or HRV get a row.

**B6. Sleep goal is hardcoded at 7.5h in one place and personal elsewhere.**
`todayRecoverySignals` passes `sleepHoursGoal: 7.5` flat, while
`SleepNeedCalculator` computes a real personal need from strain, debt, age and
wake time. The Why row's "Sleep was short" verdict therefore ignores the
personalized target the app already has.

**B7. Steps goal is hardcoded at 10,000 for the Live Activity.**
`pushTodayScoreLiveActivity` passes `stepsGoal: 10000` regardless of the user.

**B8. Recovery debt trend words are arithmetic on a threshold, not a trend.**
`writeWidgetSnapshots` sets trend to `"stable"` if <1h, `"worsening"` if >3h,
else `"improving"` — a size test labelled as a direction. The real direction
(`sleepDebtTracker.debtTrend`) exists and is used correctly by the SmartAction
ladder, but not here.

**B9. Widget and Home can show different numbers by design.**
The widget prefers the morning lock; the watch and Home hero prefer the live
drained score. Comments acknowledge it. Any Home v2 that adds a second surface
needs to pick one.

**B10. Weekly review "wins" are unfiltered percentage moves.**
`periodSummary` calls anything past +/-2% improved or declined, with no
significance test and no minimum sample count beyond "both windows non-empty".
A metric with two readings can become a headline win.

**B11. Vitality norm tables are heuristic.**
The file says so explicitly: "values approximate widely used population norms but
no specific source DOIs are linked; treat outputs as informational signals only".
The Home tile prints "3y younger" as a flat fact.

---

## Quick answers for Home v2 design decisions

- **Safe hero for everyone, every day:** the Daily Health Score is always
  computable but is a shrunk prior when coverage is low. The honest hero is
  Recovery *when the morning lock exists*, with an explicit different state (not a
  silent substitution) when it does not.
- **The one thing the app does better than the data alone:** the SmartAction
  ladder plus `proofSummary` — a single ranked action with 24h/7d evidence that it
  moved the user's own score. That is currently buried one tap deep.
- **The biggest cheap win:** surface the intelligence briefing on Home. It is
  already computed on every refresh and only Explore sees it.
- **Fix before promoting anything:** B1 (blood oxygen) and B2 (sleep forecast).
  Both are one-line fixes that today make Home actively lie.

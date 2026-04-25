# 15 — Scoring algorithm + Coach/LLM safety + AppAnalytics PII deep sweep (Pass 1 wave 3)
_Started: 2026-04-25 16:05 IST_

Scope: Read-only audit, three angles in one pass.

A. Scoring sanity for Strain / Stress / Sleep / Vitality / BrainHealth / Risk
B. Coach / AskYourData / on-device LLM medical-claim audit
C. Deep AppAnalytics.swift PII sweep (3,201 lines)

Evidence cited as `relative/path:line`. Confidence per finding.

---

## Section A — Scoring algorithm sanity

### F1. CRITICAL — Risk Engine generates per-condition "risk" levels with concrete clinical thresholds and action lines, displayed on a 0–100 risk gauge labelled "High / Very High". This is medical-style risk stratification under a wellness label.

- **Severity**: Critical (App Review 1.4.1, 5.1.1(ix); FDA 21 CFR 880.6315 wellness-vs-device boundary; EU MDR Annex VIII rule 11)
- **Issue**: `Modules/Risk/Views/Risk/HealthRiskDetailView.swift` renders `risk.level` 0–100 with a `RiskGrade` of {Low, Moderate, Elevated, High, Very High} (`Core/Models/HealthRisk.swift:44-55`). RiskTypes include `cardiac`, `respiratory`, `metabolic`, `mobilityDecline` (`Core/Models/HealthRisk.swift:81-101`). The factor explanation prints "above the optimal range" / "below the optimal range" and gives a numeric `optimalRange` from `RulesConfiguration.normalRange(for: metric)` (`Core/Analysis/HealthRiskEngine.swift:96-156`).
- **Why it's a problem**: Apple's wellness-app rules block any UI that reads as "you have risk X for condition Y" unless the app is registered as a medical device. The string `"Heart Health Pattern"` is softened, but the gauge still publishes a 0–100 score with the colour-coded "High / Very High" label and a focus-area line saying e.g. *"Manage Blood Pressure — Reduce sodium to <2,300mg/day"* (`Core/Analysis/HealthRiskEngine.swift:296-301`). A reasonable user reads "Heart Health Pattern: 72 / Very High" as a heart-disease risk score.
- **Impact**: App Store rejection probability at re-review: high. EU MDR exposure: any Risk > Low displayed without a CE-marked medical-device certification can be classed as a Class IIa diagnostic aid.
- **Evidence**:
  - `Modules/Risk/Views/Risk/HealthRiskDetailView.swift:78` — `Text("\(risk.level)")` rendered in displayM font on a coloured arc.
  - `Core/Models/HealthRisk.swift:13-21` — `RiskGrade` thresholds 0/15/35/55/75 maps directly to "Low → Very High".
  - `Core/Analysis/HealthRiskEngine.swift:296-301` — Cardiac BP focus line: `"Reduce sodium to <2,300mg/day, exercise 150 min/week, maintain healthy weight, limit alcohol. Monitor regularly."` Target: `<120/80 mmHg`. This is JNC8-style clinical guidance.
  - `Core/Analysis/HealthRiskEngine.swift:308-313` — `atrialFibrillationBurden` recommendation: *"Track when episodes occur. Reduce alcohol, caffeine, and stress. Worth monitoring closely if burden increases."* — this discusses an actual diagnosed condition (Apple Watch AFib feature), not wellness.
- **Verify**: Open Settings → "Heart Health Pattern" with synthetic data above thresholds; screenshot the "Very High 78/100" gauge + the "Manage Blood Pressure" focus card.
- **Fix**:
  1. Drop the 0–100 numeric gauge; replace with binary "Within range" / "Outside your usual" framing.
  2. Replace `RiskGrade` words "High" / "Very High" with neutral *"Pattern observed"* / *"Worth attention"*. Reuse existing `clinicalTrajectory` non-diagnostic vocabulary already in `MobilityDeclineAnalyzer`.
  3. Remove cardiac AFib recommendation entirely. Replace with a single line: *"AFib detection requires Apple Watch ECG. We do not interpret AFib for you."*
  4. Keep only the disclaimer (which exists at `Modules/Insights/Copy+Analysis.swift:200`) but show it _above_ the gauge, not after the fold.
- **Priority**: Now, hard-blocker.
- **Confidence**: 92/100 — code paths read in full; risk-gauge UI confirmed; legal classification is my best read of the Apple/FDA/EU rule overlap, not a lawyer's opinion.

### F2. HIGH — Cardiac risk recommendations contain numeric clinical targets that look like prescriptive medical advice.

- **Severity**: High
- **Issue**: Lines like *"Target: 50–70 bpm"* (RHR), *"Target: <120/80 mmHg"* (BP), *"Target: HRV 40+ ms (SDNN)"*, *"Target: >12 bpm drop in 1 min"* (HRR) are reproduced verbatim from clinical guidelines and rendered next to a per-user "concerning / critical" status badge.
- **Evidence**:
  - `Core/Analysis/HealthRiskEngine.swift:284-313` — five cardiac targets, all numeric.
  - `Core/Analysis/HealthRiskEngine.swift:362-379` — respiratory: *"SpO2 below 95% warrants attention. Below 90% is a medical emergency requiring urgent care."* — explicit medical-emergency language.
- **Why**: Phrases like "medical emergency" and "seek immediate medical attention" are fine when generic, but pairing them with a per-user "Critical" status indicator turns the surface into triage.
- **Impact**: Same App Review path as F1; also creates duty-of-care exposure if a user reads "below 90%" and the underlying SpO2 reading was a sensor artefact.
- **Fix**: Strip numeric targets from the per-user surface; move them into a static "How SpO2 works" reference page that is not gated on user data.
- **Priority**: Now.
- **Confidence**: 90/100 — text strings are exact-cited; classification is non-lawyer judgement.

### F3. HIGH — VO2 Max recommendation calls VO2 Max "the single strongest predictor of longevity"; mobility analyzer says "predicts neurodegenerative decline years before clinical diagnosis" in a code comment, but UI text is softened to "early indicator of shifts in overall wellness".

- **Severity**: High (VO2 longevity claim) / Low (mobility — actually safe in UI)
- **Issue**: `Core/Analysis/HealthRiskEngine.swift:371` says *"VO2 Max is the single strongest predictor of longevity. Add 3-4 sessions of zone 2 cardio…"*. This is a population claim presented as advice to an individual.
- **Why**: Wellness apps may state generic research; calling something "the single strongest predictor" without citation is overreach and triggers the same App Review concern as F2.
- **Evidence**: `Core/Analysis/HealthRiskEngine.swift:368-373`. Mobility analyzer is OK at the UI layer (`Core/Analysis/Research/MobilityDeclineAnalyzer.swift:104-118` — UI string says *"warrants attention"*).
- **Fix**: Soften to *"VO2 Max reflects how efficiently your heart, lungs, and muscles use oxygen during exercise."* Drop the "single strongest predictor" phrase or attribute to a peer-reviewed source.
- **Priority**: Soon.
- **Confidence**: 95/100 — exact line cited.

### F4. HIGH — BrainHealth scorer is renamed in UI to "Cognitive Wellness" but the underlying score still drives a 0–100 number with state buckets {Sharp, Focused, Baseline, Foggy} and a "Foggy" headline can read *"Low HRV and reduced REM. Expect brain fog."*

- **Severity**: High (low end of high; not medical diagnosis but implies cognitive impairment)
- **Issue**: `Core/Analysis/BrainHealthScorer.swift:6-46` → BrainHealthState includes `foggy` whose displayName is "Foggy" and headline says *"Expect brain fog. Keep work simple today."* (`Modules/BrainHealth/Copy+BrainHealth.swift:32-34`). The score is computed from HRV z-score, deep/REM/duration, RHR — none of which are validated cognitive proxies.
- **Why**: Telling a user "Expect brain fog today" is a cognitive performance prediction. Without validation against a cognitive assessment battery (e.g. PVT, Stroop), the prediction has no published basis. An Apple Reviewer or an EU regulator can call this an "intended use as a medical device that affects clinical decision making" under MDR Article 2(1).
- **Evidence**:
  - `Core/Analysis/BrainHealthScorer.swift:226-232` — composite score from 5 subscales.
  - `Core/Analysis/BrainHealthScorer.swift:310-350` — HRV/Deep/REM/Duration weighted to 100 with z-score normalisation `min(max((z + 2.0) / 4.0, 0), 1)`. No cognitive validation step.
  - `Core/Analysis/CognitiveEnergyAnalyzer.swift:200` — *"Cognitive impairment compounds with each deficit day — reaction time and decision-making are most affected."* — direct cognitive-impairment claim.
- **Fix**: Rename "Foggy" to "Low energy day". Replace "Expect brain fog" headlines with descriptive *"Low HRV and short REM last night."* (state without prediction). Drop the word "impairment" from CognitiveEnergyAnalyzer.
- **Priority**: Now.
- **Confidence**: 88/100 — code & copy verified; the regulatory call is judgement.

### F5. HIGH — Strain scoring uses uncalibrated magic constants for "elite-day" anchor; baseline fallback is a 65 bpm population mean for resting HR.

- **Severity**: High (defensibility, not legal)
- **Issue**: `Core/Analysis/StrainScorer.swift:89` `maxExpectedLoad: Double = 800.0` is described in comments as "calibrated so an elite-level training day (~1200 kcal active, 90 min zone 4-5) maps to ~strain 20-21" but no calibration dataset is cited. Zone multipliers (`zoneMultipliers: [1:1, 2:2, 3:4, 4:8, 5:14]`, line 95-101) are arbitrary; they look like a TRIMP-style weighting but not Banister or Lucia coefficients.
- **Why**: Whoop's strain is calibrated against laboratory VO2 / lactate data. Laso has no calibration. The score will look credible but is not transferable across users.
- **Evidence**:
  - `Core/Analysis/StrainScorer.swift:85-101` — magic constants without source citation.
  - `Core/Analysis/StrainScorer.swift:218-219` — `calorieBaseline: hasBaseline ? calorieBaseline : 400.0` — 400 kcal default.
  - `Core/Analysis/StrainScorer.swift:273` — `return 65.0 // Population average fallback` for RHR.
- **Risk**: A 65-year-old user with RHR 80 will be treated as if 65 is normal, deflating their HR-reserve and producing wrong zones for the first 14 days.
- **Fix**:
  1. Document the calibration source (likely Banister TRIMPexp or "internal heuristic"; user deserves to know).
  2. Drop the population RHR fallback; render *"Need 3 RHR readings to compute strain"* until 3 data points exist.
  3. Make the strain unit & range visible: *"0–21 (logarithmic)"* with a help link.
- **Priority**: Soon.
- **Confidence**: 86/100 — formula read end-to-end; "no calibration dataset" is from absence of evidence in repo, not a denial; could exist in `/Docs`.

### F6. MEDIUM — Stress score uses 14-day baseline but starts producing a score at `minimumDaysRequired = 3` days of HRV, with confidence tiers that always include "low".

- **Severity**: Medium
- **Issue**: `Core/Analysis/StressScorer.swift:103` says minimum is 3 days; `baselineWindowDays = 14`. So a user can see a "Moderate Stress" badge after only 3 nights of HRV. The baseline `computeBaseline` requires only `samples.count >= 5` (line 249). With a 14-day intended window but only 5 samples, the SD of the personal baseline is unstable — and the score is divided by `hrvBaseline.mean - currentHRV / hrvBaseline.mean` (line 316), which is sensitive to small-sample noise.
- **Why**: Score volatility on day 4-7 will look like genuine stress fluctuations but is mostly baseline-estimation noise. The stress narrative on `Core/Analysis/StressScorer.swift:166-181` quotes the user's own deviation back to them ("your HRV is 22% below baseline") which compounds the false signal.
- **Evidence**: `StressScorer.swift:103, 247-262, 316`.
- **Fix**: Hold the score at `low` until `samples.count >= 10` AND `cv = sd/mean < 0.4`. Surface confidence in UI when below 0.6.
- **Priority**: Soon.
- **Confidence**: 92/100 — formula traced; the "5 sample SD" issue is a mathematical fact.

### F7. MEDIUM — Vitality "biological age" blends from chronological age to computed age over days 7→30, but if `components.count < 2`, age silently snaps back to chronological. No UI indication.

- **Severity**: Medium
- **Issue**: `Core/Analysis/VitalityScorer.swift:521-535` — when fewer than 2 metrics are available, the function returns `vitalityAge = chronologicalAge` and exits without saving a snapshot. The user sees their actual age as their "vitality age" which can be misleading both ways (user thinks their data was processed but it wasn't, or thinks their fitness is exactly average).
- **Evidence**: `VitalityScorer.swift:521-535`.
- **Fix**: When `components.count < 2`, render *"Need more data — connect Apple Watch or wait until \(daysToFullData) more days of HRV"*. Don't show a number.
- **Priority**: Soon.
- **Confidence**: 95/100 — direct code path read.

### F8. MEDIUM — Vitality "Pace of aging" computed from health-score history, not from biomarker history. The comment says *"Each point of health score difference ~= 0.3 years of vitality age"* with no source.

- **Severity**: Medium
- **Issue**: `VitalityScorer.swift:670-680` maps daily health-score deltas to vitality-age deltas via `0.3` scaling. This is unrelated to the actual biomarker-based vitality age formula above.
- **Why**: Two different mental models of "vitality age" — one from population norms, one from a 0.3 multiplier on internal health score — are presented as one continuous trend.
- **Fix**: Compute pace of aging from the biomarker-trajectory (HRV/RHR/VO2max trends), not from the health score; or hide the pace until 90 days of biomarker history exists.
- **Priority**: Later.
- **Confidence**: 88/100 — the formula is what it is; "wrong basis" is a judgement call.

### F9. LOW — VitalityNorms reference tables cite ACSM, AHA, Framingham, etc., but no in-code references to specific editions or page numbers. Audit-trail gap.

- **Severity**: Low
- **Issue**: `VitalityScorer.swift:13-86` — reference tables for VO2Max, RHR, HRV, sleep efficiency, walking speed all have a one-line citation but no DOIs, no edition, no Confidence Interval. If a journalist or a regulator asks "where did the value `(40, 39)` for male VO2 max at age 40 come from?", there is no traceable answer.
- **Fix**: Add `// Source: ACSM Guidelines for Exercise Testing, 11th ed., Table 4.5, p.92` style comments. Or move to a `VitalityNormsCitations.md` referenced from each constant.
- **Priority**: Pre-launch nice-to-have.
- **Confidence**: 100/100 — comment-quality observation.

### F10. LOW — Sleep efficiency is computed by adding asleep + awake samples without verifying they come from the same night, then dividing.

- **Severity**: Low
- **Issue**: `VitalityScorer.swift:399-419` — pulls 14 days of `.sleepDuration` and `.sleepAwake` independently, takes the mean of each, then computes efficiency = mean(sleep) / (mean(sleep) + mean(awake)). If awake-time is reported sparsely (some watches report it, some don't), the denominator is biased.
- **Fix**: Pair samples by date and compute per-night efficiency, then average.
- **Priority**: Later.
- **Confidence**: 95/100 — direct read.

### Score formula summary

| Score | Range | Inputs | Baseline window | Magic constants | Calibration source cited? |
|---|---|---|---|---|---|
| Strain | 0–21 (log) | calories, HR-zone minutes, exercise/workout/steps/distance | 28-day calorie | maxExpectedLoad=800; zone multipliers [1,2,4,8,14]; population RHR=65 bpm; default baseline=400 kcal | No |
| Stress | 0–3 (continuous) | HRV (60%), HR vs RHR (40%) | 14-day, min 5 samples | weights .6/.4; minimumDaysRequired=3 | No |
| Sleep (Readiness) | 0–100 | HRV (40%), RHR (35%), sleep dur (15%), sleep stages (6%), workout recovery (4%) | per-metric 21-day target | smoothingAlpha=0.7; freshness 48h; aging penalty up to −12 if cardiac age >24h | No |
| Vitality | 18–95 (mapped age) | VO2Max .25, HRV .20, RHR .15, walkingSpeed .10, sleep eff .08, deep .07, steps .05, ex min .05, body comp .05 | 14–30-day per metric | Norm tables sourced from ACSM/AHA/WHO (no DOIs); BMI optimum=22.5 | Citations only — no DOIs |
| BrainHealth | 0–100 | Cognitive readiness .30, memory recovery .25, stress-cog load .20, neurovascular .15, circadian .10 | 14-day | z-score normalised to (z+2)/4; "VO2 score" = (vo2-20)/35*100; CV<0.3 = perfect circadian | No |
| Risk | 0–100 per type | factors (range distance, anomaly severity, trend, baseline deviation) | per metric, sum/avg over measured factors | Out-of-range max 40pts, anomaly 30/15, trend 20/12/6, deviation 10/5 | RulesConfiguration.normalRange — sources not in-code |

Same metric (HRV) feeds Strain, Stress, Vitality, BrainHealth, Readiness, and Risk with **different** baseline windows (3-day recent vs 14-day baseline vs 30-day vs 21-day target). Internal contradictions are likely; the user can see Stress = High AND BrainHealth = Sharp on the same morning if HRV crashed but REM was great. Worth surfacing as F-cross-check (item F11 below).

### F11. MEDIUM — HRV is normalised differently across six scorers; same data point produces six different "is HRV good?" signals.

- **Severity**: Medium (consistency / trust)
- **Issue**: HRV is treated as:
  - Stress: `(baseline.mean - current) / baseline.mean` → percent below baseline
  - BrainHealth: z-score `(current - mean) / sd`, normalised to (z+2)/4
  - Vitality: mapped to "age" via `VitalityNorms.hrv` interpolation
  - Risk: `RulesConfiguration.normalRange(for: .hrv)` — population range
  - Readiness: `hrvScore(current, baseline)` (separate)
- **Why**: The user can see the same HRV (e.g. 38 ms) labelled "below baseline → Mild Stress" AND "at population age-norm → Vitality Age = chronological" simultaneously. Both can be true mathematically, but the UX reads as contradiction.
- **Fix**: Centralise HRV normalisation in one `HRVStandardiser` actor that all scorers consume. Document in-app: "Stress measures vs your baseline; Vitality measures vs population."
- **Priority**: Soon.
- **Confidence**: 92/100.

### F12. LOW — All scorers use UserDefaults snapshots that may persist between profile changes (e.g. if a household uses two phones).

- **Severity**: Low
- **Issue**: `StrainScorer.swift:110, 120-130`, `VitalityScorer.swift:286-322` — Snapshot keys not invalidated on profile reset/sign-out.
- **Fix**: Subscribe to a "profile changed" notification and clear all snapshots.
- **Priority**: Later.
- **Confidence**: 95/100 — only one of two single-user expected.

---

## Section B — Coach / LLM medical-claim audit

### LLM Surface Inventory

| Surface | iOS gate | LLM | Cloud? | Has "never diagnose" prompt? |
|---|---|---|---|---|
| AskYourData (Concierge) | iOS 26+ Foundation Models, falls back to rule-based on older OS | On-device | No | Yes |
| Daily Narrative card | iOS 26+ Foundation Models, otherwise hidden | On-device | No | **No** |
| Sleep Coach | rule-based templates only | n/a | No | n/a |
| Strain Coach | rule-based templates only | n/a | No | n/a |
| Weekly Review | rule-based + structured copy | n/a | No | n/a |

I grepped `OpenAI`, `api.openai.com`, `anthropic.com`, `Claude`, `GPT`, `gemini`, `Vertex`, `googleapis.com`, `generativelanguage` against the entire `*.swift` tree — zero results outside copy comments. **Confirmed: no cloud LLM endpoints.**

### B1. CRITICAL — DailyNarrativeEngine system prompt has no "never diagnose / never prescribe / refer to doctor" instruction.

- **Severity**: Critical
- **Issue**: `Core/Analysis/ML/DailyNarrativeEngine.swift:41-53` — the entire system prompt is a 100-word voice/style instruction. There is no medical-safety guardrail. The model is fed `readinessScore`, `weakestPillar`, `hrvMs`, `sleepHours`, `streakDays` and asked to "tell the user what today looks like for their body" in two sentences.
- **Why**: With low readiness + low HRV signals, the model can spontaneously generate phrases like *"your body might be fighting something off"* / *"watch for signs of illness"* — both are diagnostic-adjacent. The AskYourData engine has a hardened scope clause (`FoundationModelQueryEngine.swift:107-115`) but DailyNarrative does not.
- **Evidence**: `Core/Analysis/ML/DailyNarrativeEngine.swift:41-53` — full prompt visible.
- **Impact**: A single "your body is fighting an infection" generation surfacing in a user screenshot at App Review = rejection. On-device model is private but not safe-by-default.
- **Fix**: Append the same medical-safety block from FoundationModelQueryEngine: *"Never diagnose a medical condition, never suggest medication, never replace a doctor. If you would describe a state that sounds clinical (illness, condition, dehydration, infection), instead describe the metric that drove it ('HRV is below your usual')."*
- **Priority**: Now (one-line patch).
- **Confidence**: 98/100 — full prompt cited.

### B2. HIGH — AskYourData responses do not surface a per-result "Educational only — not medical advice" footer in the UI.

- **Severity**: High
- **Issue**: `Modules/Dashboard/Views/Home/AskYourDataView.swift:113-207` — result card shows answer, data points, confidence checkmark, thumbs up/down, related questions. No disclaimer text. The system prompt instructs the model not to diagnose, but a user who screenshots a single answer ("Your HRV pattern looks like overtraining") sees no UI-level "informational only" text.
- **Evidence**: `AskYourDataView.swift:113-207` — full result card visible.
- **Why**: Apple Health-related App Store guidance prefers a visible disclaimer attached to AI-generated health interpretations. Even though the FAQ-style disclaimer exists for Risk surfaces (`Modules/Insights/Copy+Analysis.swift:200`), AskYourData does not surface it.
- **Fix**: Add a small grey 12pt footer to every result card: *"Educational only. Not medical advice."* The string already exists in `Copy+Onboarding.swift:116` as `promiseDisclaimerFooter`.
- **Priority**: Now.
- **Confidence**: 96/100 — UI fully read.

### B3. HIGH — AskYourData has NO refusal/safe-fallback path when the user asks a forecast/diagnostic question.

- **Severity**: High
- **Issue**: The system prompt says "Never diagnose a medical condition" but the only mechanism is the model's compliance. If the user asks *"Do I have sleep apnea?"* or *"Will I get sick this week?"*, the silent rule-based fallback (`HealthDataQueryEngine`, 1819 lines) does not have a topic-blocklist and may attempt to compose an answer from stress signals + sleep patterns.
- **Evidence**: `Core/Analysis/ML/FoundationModelQueryEngine.swift:42-44` — *"Silent fallback to the rule-based engine on any failure"*. `HealthDataQueryEngine.swift` was greppped for `diagnos|prescr|symptom|disease|condition|emergency` — no guards present.
- **Fix**: Wrap both engines in a pre-prompt classifier that returns a safe canned reply for any of: diagnosis questions, mortality predictions, medication questions, suicide-related queries.
- **Priority**: Now.
- **Confidence**: 90/100 — checked engine bodies for guards; classifier is absent.

### B4. MEDIUM — System prompt instructs model to use "real numbers" and avoid hedging — but adds *"Never invent numbers"*. The Generable schema returns `confidence: Double` which is shown as a percentage in the result card, but the model self-reports it.

- **Severity**: Medium
- **Issue**: `FoundationModelQueryEngine.swift:17-19, 144-150` — confidence is `clamped to [0.3, 0.95]` and displayed at `AskYourDataView.swift:145` as *"Confidence: \(percent)%"*. The user perceives this as "the system's verified accuracy" but it is the model's self-assessment; this is sycophancy-prone.
- **Fix**: Either compute confidence from data sufficiency (sample count, recency) on the Swift side, or rename UI to *"Model confidence"* / *"How sure I am"* to lower trust.
- **Priority**: Soon.
- **Confidence**: 92/100.

### B5. MEDIUM — The LLM is given the user's first name, age, gender, and `healthFocuses[]` directly in the system prompt context.

- **Severity**: Medium (privacy posture, not leak)
- **Issue**: `FoundationModelQueryEngine.swift:158-208` — `buildUserProfileBlock()` injects identity into every session. On-device only, so no leak — but the model sees identity even when the user asks an off-topic question.
- **Why**: Privacy-by-default principle: don't share identity with a system if it doesn't need it for the task. Also, in case Foundation Models adds telemetry in a future iOS, identity would be in scope.
- **Fix**: Strip `firstName` from prompts that are not personal coach queries. Pass only age/gender if the question references norms.
- **Priority**: Later.
- **Confidence**: 90/100.

### B6. LOW — The on-device LLM is called with up to 4 tool calls per question (`FoundationModelQueryEngine.swift:120`) — battery cost on iOS 26 phones with ANE not yet measured.

- **Severity**: Low
- **Issue**: Performance assertion not validated.
- **Fix**: Out of scope for this audit (other agents).
- **Priority**: Later.
- **Confidence**: n/a.

### LLM safety guardrail checklist

| Layer | Check | AskYourData | DailyNarrative |
|---|---|---|---|
| Prompt | "Never diagnose / never prescribe / refer to doctor" | Present (line 114) | **Absent** (B1) |
| Prompt | Scope-restricting clause | Present (lines 109-115) | Absent (one-paragraph format limits scope organically) |
| Prompt | Hallucination guard ("Never invent numbers; use tools") | Present (line 99) | Absent |
| Prompt | Sycophancy guard | Partial — "Be honest. If thin, say so" (line 98) | Absent |
| Response | Post-process for medical-claim words | Absent | Absent |
| Response | Confidence shown to user | Yes (model self-report) | n/a |
| UI | "Not medical advice" footer | **Absent** (B2) | Absent (paragraph card) |
| UI | Topic-refusal canned response | Absent (B3) | n/a |
| Network | Cloud endpoint? | No (verified) | No (verified) |

---

## Section C — AppAnalytics PII deep sweep

### Scope: 3,201-line `Core/Tracking/AppAnalytics.swift`. PostHog is the sole sink. Listed every `func track*` (≈110 functions). For brevity, the inventory below groups by privacy class.

### C1. HIGH — `trackECGAnalysisCompleted(afibCount:)` sends the user's actual count of detected AFib episodes to PostHog as a raw integer.

- **Severity**: High (GDPR Art 9 special category data; UK GDPR; HIPAA-equivalent caution)
- **Issue**: `Core/Tracking/AppAnalytics.swift:1670-1676` — `"afib_count": afibCount` is sent verbatim. AFib presence/frequency is medical condition data.
- **Why**: Even pseudonymous, the per-user PostHog distinct_id linked to "afib_count > 0" is "data concerning health" under Art 9. Lawful basis under Art 9 requires explicit consent, and the privacy policy / consent UX would need to specifically call this out.
- **Fix**: Bucket: `afib_present_bucket: "none" | "occasional" | "frequent"` (none / 1-3 / 4+). Never raw count.
- **Priority**: Now.
- **Confidence**: 95/100 — exact line cited; legal classification is high-confidence per ICO guidance on health data.

### C2. HIGH — `trackClinicalInsightGenerated(metric:stage:trajectory:)` sends `clinical_stage` as a string. While `metric` is anonymized via `metricParameterKeys`, the stage word can itself be condition-revealing.

- **Severity**: High
- **Issue**: `Core/Tracking/AppAnalytics.swift:1686-1692` — `"clinical_stage": stage` is unsanitised. If callers pass values like `"prediabetes_borderline"`, `"hypertension_stage1"`, the event reveals condition.
- **Evidence**: line 1686-1692. `metricParameterKeys` (line 2899) includes `"metric"` but NOT `"clinical_stage"`.
- **Fix**: Either constrain `stage` to a fixed enum {`emerging`, `established`, `regressing`, `optimal`} or anonymise via the same path.
- **Priority**: Now.
- **Confidence**: 90/100 — caller call-sites would need to be checked; flagged for safety.

### C3. MEDIUM — `trackUserHealthSnapshot` sets `hk_heart_has_data`, `hk_sleep_has_data`, `hk_steps_has_data` as **user properties** on PostHog, persisting per user.

- **Severity**: Medium
- **Issue**: `AppAnalytics.swift:2102-2139` — bucketed booleans, but stored as person properties. Combined with `daily_completeness_7d_pct`, an attacker with PostHog access can segment users by "owns Apple Watch + tracks heart" vs not, which when joined with a leaked session video, increases identifiability.
- **Why**: Apple Privacy Manifest requires declaring when data is associated with user identity. Person properties are user-bound.
- **Fix**: Move to event-level only; do not set as user property.
- **Priority**: Soon.
- **Confidence**: 92/100.

### C4. MEDIUM — `trackJournalEntryCreated(category:value:hasNotes:)` sends raw `category` and the boolean `hasNotes`, but discards `value` and the note text. Categories include `mood`, `pain`, `medication`, etc.

- **Severity**: Medium
- **Issue**: `AppAnalytics.swift:2322-2327` — params are `category` (string) + `has_notes` (bool). The function signature accepts `value: Double` but does NOT log it (good). However `category` includes journal categories which can include "medication", "alcohol", "supplements" — sensitive.
- **Why**: Sending `category="medication", has_notes=1` repeatedly is a strong signal of medication tracking. With session_id correlation, this becomes inferable.
- **Fix**: Anonymise `category` by mapping to high-level buckets `lifestyle | mood | physical_state | other`. Don't reveal medication tracking.
- **Priority**: Now.
- **Confidence**: 88/100 — call-site categories not enumerated; conservative flag.

### C5. MEDIUM — `trackReferralCodeShared(code:)` and `trackReferralCodeRedeemed(code:)` send the raw referral code.

- **Severity**: Medium (not health PII, but identity-linkable)
- **Issue**: `AppAnalytics.swift:2244-2257` — referral codes are typically short strings tied to a user (e.g. `LASO-AYUSH123`). Sharing creates a back-channel from PostHog event → user identity.
- **Fix**: Hash the code (`sha256(code).prefix(8)`) before sending.
- **Priority**: Soon.
- **Confidence**: 90/100.

### C6. LOW — Session replay is enabled with `maskAllTextInputs / maskAllImages / maskAllSandboxedViews = true` PLUS opt-in `.postHogMask()` on numeric Text fields. 25 files use `.postHogMask()`.

- **Severity**: Low (good posture, but coverage incomplete)
- **Issue**: `Core/Tracking/PostHogManager.swift:29-39`. 25 files mask, but the BrainHealth, Risk, HealthState, MetricDetail, Insights modules collectively render hundreds of numeric Text views — not all are guaranteed masked.
- **Fix**: Add a pre-commit/lint rule that any `Text(...)` rendering a value derived from `HealthMetric.formatValue` must have `.postHogMask()`. Alternatively, switch session replay default to mask all `Text` and unmask explicitly.
- **Priority**: Soon.
- **Confidence**: 85/100 — coverage estimate, not enumeration.

### C7. POSITIVE — No call to `PostHogManager.shared.identify(...)` exists in the codebase outside the wrapper definition. PostHog uses anonymous distinct_id.

- **Evidence**: `grep PostHogManager.shared.identify` returns only the wrapper `Core/Tracking/PostHogManager.swift:69`. No call sites.
- **Impact**: Strong privacy posture for PostHog; events cannot be joined to email/firebaseUid via the PostHog SDK.
- **Confidence**: 98/100.

### C8. POSITIVE — Sanitiser truncates string values to 100 chars and anonymises metric-name parameter keys.

- **Evidence**: `AppAnalytics.swift:2920-2949`. `metric, metric_a, metric_b, alert_metric, nutrition_metric, outcome_metric, metric_preview` are all category-anonymised via `anonymizeMetricValue`.
- **Confidence**: 95/100.

### C9. POSITIVE — Free-form text feedback is sent only as `text_length`, never the text body.

- **Evidence**: `AppAnalytics.swift:1474-1480` (feedback), `AppAnalytics.swift:2999-3003` (PMF improvement).
- **Confidence**: 100/100.

### C10. LOW — `trackError(message:)` accepts arbitrary string and sends `String(message.prefix(100))`. Call sites only pass `error.localizedDescription` and short strings; safe today but fragile.

- **Severity**: Low
- **Fix**: Make `message` a strict enum.
- **Confidence**: 95/100.

### Full event inventory with PII-risk class

(I sampled all `func track*` functions; ~110 events. Class column is the strongest single risk among parameters.)

| Event family | Sample params | Risk class | Notes |
|---|---|---|---|
| `onboarding_*` | `step`, `stepName`, `durationSec`, `focuses[]` | Safe (counts/buckets) | Step name is a code string; `focuses` is user-selected bucket list, no free text |
| `activation_milestone` | `milestone` (enum) | Safe | |
| `session_*` | `duration_sec`, `screens_visited`, `core_actions` | Safe | |
| `feature_open / feature_close` | `feature` (enum), metadata dict | Safe with caveat — metadata dict allows arbitrary keys (e.g. `risk` rawValue, `grade`, `subscreen`) |
| `core_action` | `action` (enum), `screen` | Safe | |
| `block_tap` | `title` (string up to 100 chars), `type`, `screen`, metadata | Risky — title is caller-controlled. Verified call sites pass labels, but no enum constraint |
| `insight_tapped` | `category`, `severity`, `metric`, `screen` | Safe — `metric` anonymised |
| `correlation_tapped` | `metric_a`, `metric_b`, `strength` | Safe — metric_a/b anonymised |
| `risk_tapped` | `risk_type`, `grade`, `screen` | Risky — `risk_type` is `cardiac/respiratory/...` rawValue, NOT in `metricParameterKeys` so passes through; reveals which risk panel the user opened |
| `analysis_completed` | `insights_count`, `risks_count`, `illness_warnings_count` | Risky — count of illness warnings is a coarse health-state signal |
| `trial_started / paywall_*` | revenue, productID, price | Safe | Revenue handling is fine |
| `nps_submitted / pmf_*` | bucketed score, source, length | Safe | |
| `error_occurred` | `error_type`, `screen`, `message` (100 char) | Low risk, see C10 |
| `device_detected` | `deviceType`, `modelName` | Safe | |
| `data_sync` | counts, durations | Safe | |
| `report_exported` | `score`, `metricsCount`, `insightsCount` | Risky — score is a raw 0-100 number; bucket it |
| `setting_changed` | `name`, `value: Any` | Risky — `value` is unconstrained (could be a date, location toggle, profile field) |
| `notification_*` | type, identifier, hour, day, hook_category | Safe |
| `share_sheet_presented` | contentType | Safe |
| `streaming_*` / `live_*` | timestamps, durations | Safe |
| `feedback_prompt_shown / feedback_submitted` | length, sentiment, category | Safe (C9) |
| `scroll_depth / section_*` | depth %, durations | Safe |
| `recommendation_outcome` | category, metric, severity, lift_24h, lift_7d | Risky — `lift_24h` and `lift_7d` are continuous deltas; combined with category they can be reverse-engineered to a user-specific change |
| `notification_opened` | identifier | Safe |
| `simulation_run` | adjustedMetrics count, scoreDelta, confidence | Safe |
| `roi_recommendation_tapped` | metric, predictedGain, effortLevel | Safe — metric anonymised |
| `ecg_analysis_completed` | `recordings_count`, `afib_count`, `insights_generated` | **PII (Art 9)** — see C1 |
| `nutrition_correlation_discovered` | nutrition_metric, outcome_metric, correlation | Safe — both anonymised |
| `clinical_insight_generated` | `metric`, `clinical_stage`, `trajectory` | **Risky** — see C2 |
| `health_state_timeline_viewed` | currentState, daysInState, totalStates | Risky — `currentState` rawValue can include values like `recovering`, `inflamed`; verify enum |
| `circadian_analysis_completed` | chronotype, metricsAnalyzed, confidence | Safe (chronotype is bucketed) |
| `daily_active` | session_source, weekly_active_days, app_version | Safe |
| `notification_scheduled / suppressed` | type, identifier, hook_category | Safe |
| `sync_performance / ml_analysis_performance` | duration, counts | Safe |
| `pro_feature_funnel` | feature, step | Safe |
| `insight_engagement` | category, metric, action | Safe — metric anonymised |
| `health_permission_*` | metrics[] (array of metric names), counts | **Risky** — metrics array is NOT anonymised through metricParameterKeys (only single key names are); a user granting/denying `bloodPressure` permission is logged verbatim |
| `source_connected` | sourceType, metricsAvailable | Safe |
| `data_pipeline_quality` | various counts | Safe |
| `first_score_generated` | score, time, metricsUsed | Risky — raw score; bucket |
| `stale_data_detected` | hours, metric | Safe — metric anonymised |
| `explanation_viewed` | type, screen | Safe |
| `insight_marked_helpful / unhelpful` | category, metric, reason | Risky — `reason` is free-form caller-supplied; safe today but no guard |
| `privacy_page_viewed` | source | Safe |
| `recommendation_*` | type, metric, difficulty | Safe (metric anonymised — verify) |
| `workout_plan_*` | various | Safe |
| `breathwork_*` | protocol, duration, completion_rate, mood | Risky — `mood` rawValue is user-state data; bucket if not already |
| `user_health_snapshot` | watchPaired, completeness_7d, push, hk_*_has_data, churn_score | See C3 |
| `live_activity_*` | kind, state, bedtime/sleepOnset epoch | Risky — exact epoch timestamps reveal sleep schedule (high resolution) |
| `widget_snapshot_updated` | trigger, snapshotsWritten, has_* booleans | Safe |
| `referral_code_*` | `code` raw | See C5 |
| `achievement_unlocked / level_up` | id, title, category, totalDaysTracked | Safe |
| `device_disconnected` | deviceType, daysSinceLastData, modelName | Safe |
| `alert_*` | alertType, metric, action | Safe — metric anonymised |
| `journal_entry_*` | category, has_notes | See C4 |
| `empty_state_shown / score_generation_failed / sync_failed` | reason | Safe |
| `session_quality / ghost_session` | duration, screens, core_actions | Safe |
| `score_viewed / score_reaction` | score_bracket (bucketed), direction | Safe |
| `screenshot_taken` | screen, tab, days_since_install, subscription_status | Risky — knowing the user screenshotted the Risk page is itself a sensitive event when joined to "they have an Apple Watch + AFib detected"; intent + condition correlation |
| `app_crash` | crash_type, exception_name, exception_reason, stack_trace (2000) | Safe — system-level |
| `pmf_*` | response, segment, benefit, text_length | Safe (C9) |
| `share_completed` | contentType, activityType, completed | Safe |
| `cloud_backup_*` | counts, success | Safe |
| `app_store_review_prompted / deep_link_opened` | trigger, url, source, campaign | Risky — `url` is sent raw (max 100 chars after sanitiser) |
| `notification_permission_*` | source, granted | Safe |
| `query_feedback` | helpful, confidence, queryLength | Safe (no query text) |
| `widget_tapped / widget_displayed / watch_app_*` | widgetKind, hasData, durationSec | Safe |

Total events flagged: 13 risky + 2 PII (C1, C2). 

---

## Summary

| Severity | Count |
|---|---|
| Critical | 2 (F1 Risk gauge + medical claims, B1 DailyNarrative no safety prompt) |
| High | 6 (F2 cardiac targets, F3 longevity claim, F4 BrainHealth foggy headlines, F5 strain magic constants, B2 no UI disclaimer on AskYourData, B3 no refusal classifier, C1 raw afib_count, C2 raw clinical_stage) |
| Medium | 7 (F6 stress 3-day startup, F7 vitality silent fallback, F8 pace from health score, F11 inconsistent HRV norms, B4 model-self-confidence shown as percent, B5 identity in every prompt, C3 user properties, C4 journal category, C5 raw referral code) |
| Low | 6 (F9 norm citations, F10 sleep-efficiency pairing, F12 snapshot leak across profiles, B6 perf, C6 session-replay coverage, C10 trackError) |
| Positive | 3 (no cloud LLM, no PostHog identify, sanitiser bucketing in place) |

## Top 3 Now

1. **Risk module rebrand and gauge removal (F1, F2, F3)** — Replace `RiskGrade.high/veryHigh` UI with neutral language, drop the 0-100 gauge, strip numeric clinical targets, kill the AFib recommendation. Single-PR job; estimated 1 day. Without this, Apple Review 1.4.1/5.1.1(ix) is a coin flip.
2. **Add the medical-safety guardrail to DailyNarrativeEngine prompt (B1)** — One paragraph appended to `Core/Analysis/ML/DailyNarrativeEngine.swift:41`, mirroring the AskYourData scope clause. Five-minute fix, prevents a high-severity App Review screenshot.
3. **Bucket / drop high-PII analytics fields (C1, C2, C4)** — Replace `afib_count` (raw int) → `afib_present_bucket`; constrain `clinical_stage` to enum; bucket Journal `category` to lifestyle/mood/physical_state. Two-hour fix, removes the strongest GDPR Art 9 exposure.

---

## Files referenced (absolute paths)

- /Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/StrainScorer.swift
- /Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/StressScorer.swift
- /Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/VitalityScorer.swift
- /Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/BrainHealthScorer.swift
- /Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/ReadinessScorer.swift
- /Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/HealthRiskEngine.swift
- /Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/IllnessEarlyWarning.swift
- /Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/CognitiveEnergyAnalyzer.swift
- /Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/Research/MobilityDeclineAnalyzer.swift
- /Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/ML/FoundationModelQueryEngine.swift
- /Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/ML/DailyNarrativeEngine.swift
- /Users/primetrace/Desktop/RnD/HealthPulse/Core/Analysis/ML/HealthDataQueryEngine.swift
- /Users/primetrace/Desktop/RnD/HealthPulse/Core/Models/HealthRisk.swift
- /Users/primetrace/Desktop/RnD/HealthPulse/Modules/Risk/Views/Risk/HealthRiskDetailView.swift
- /Users/primetrace/Desktop/RnD/HealthPulse/Modules/BrainHealth/Copy+BrainHealth.swift
- /Users/primetrace/Desktop/RnD/HealthPulse/Modules/Insights/Copy+Analysis.swift
- /Users/primetrace/Desktop/RnD/HealthPulse/Modules/Dashboard/Views/Home/AskYourDataView.swift
- /Users/primetrace/Desktop/RnD/HealthPulse/Core/Tracking/AppAnalytics.swift
- /Users/primetrace/Desktop/RnD/HealthPulse/Core/Tracking/PostHogManager.swift

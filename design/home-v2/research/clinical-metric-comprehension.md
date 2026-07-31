# Clinical Metric Comprehension: What Ordinary People Actually Understand

Research brief for the Home Screen v2 redesign.
Date: 2026-07-29. All claims below trace to a source that was fetched or searched in this session. Claims I could not verify to a primary source are marked **[UNVERIFIED]** or **[SECONDARY]**.

---

## 0. Headline

The metrics people understand are the ones that map to a physical action they already know how to take (steps, minutes walked, bedtime). Everything derived from heart rate variability — recovery, readiness, stress, body battery — is simultaneously the least understood, the least validated, and the noisiest thing on the screen, and there is controlled experimental evidence that showing a bad number *causes* people to feel worse and perform worse the same day, independent of their actual physiology.

---

## 1. Heart rate variability

### 1.1 What HRV actually measures

HRV is the variation in time between consecutive heartbeats. It is an indirect window on autonomic balance: vagal (parasympathetic) activity raises it, sympathetic activity lowers it. It is not a measure of "health", "energy", or "recovery" — those are inferences layered on top.

### 1.2 RMSSD vs SDNN

- **RMSSD** (root mean square of successive differences) captures beat-to-beat change, and is the metric that mathematically isolates high-frequency vagal activity. It is time-invariant, so a 1-minute and a 5-minute window give comparable results.
- **SDNN** is the standard deviation of all NN intervals. It captures deviation from the mean over the whole window, mixing sympathetic and parasympathetic influence plus circadian and respiratory components. It is **not** time-invariant — a 5-minute SDNN and a 24-hour SDNN are different quantities and cannot be compared.
- Consequence: RMSSD and SDNN are not interchangeable and must never be shown under one label "HRV".
  Sources: [Ultrahuman blog](https://www.ultrahuman.com/blog/rmssd-vs-sdnn-hrv-metrics-explained/), [Altini, "HRV numbers: what do they mean?"](https://marcoaltini.substack.com/p/heart-rate-variability-hrv-numbers), [Terra blog](https://tryterra.co/blog/measuring-hrv-sdnn-and-rmssd-3a9b962f7314). (Vendor/practitioner sources — the RMSSD time-invariance claim is well established in the HRV literature but the specific framing here is **[SECONDARY]**.)

### 1.3 Why absolute HRV is meaningless between people

Normative meta-analytic values for short-term (5-minute) recordings in healthy adults (Nunan et al., pooled n = 21,438, reported in Shaffer & Ginsberg 2017):

| Metric | Mean (SD) | Reported range |
|---|---|---|
| SDNN | 50 (16) ms | 32–93 ms |
| RMSSD | 42 (15) ms | 19–75 ms |

Source: [Shaffer & Ginsberg, *An Overview of Heart Rate Variability Metrics and Norms*, Front Public Health 2017 (PMC5624990)](https://pmc.ncbi.nlm.nih.gov/articles/PMC5624990/) — fetched.

The healthy range spans roughly a **4x spread** (19–75 ms RMSSD). HRV declines with age — the sharpest drop is between the second and third decades — and women show lower SDNN than men in 24-hour recordings despite higher mean heart rate. Almeida-Santos et al. (n = 1,743, age 40–100) found SDNN declines linearly with age while RMSSD follows a U-shape, falling from 40 to 60 then rising again after 70. Same source.

So a 30 ms RMSSD is normal for one person and a red flag for another. **Any cross-person comparison, leaderboard, percentile-vs-population, or "your HRV is low" absolute judgement is scientifically indefensible.** Only within-person deviation from that person's own baseline carries signal.

### 1.4 Night vs morning measurement

Both are used, and at group level they agree: one study found heart rate and RMSSD taken during nocturnal sleep and on waking "did not differ" [SECONDARY — via search summary of [Morning versus Nocturnal HRV Responses to Intensified Training, PMC11541970](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11541970/)].

But they answer different questions:
- **Overnight average** is heavily contaminated by the previous 24 hours: late training, a large meal, and especially alcohol suppress it for hours into the sleep period. It is also confounded by sleep architecture — HRV is high in deep sleep and volatile in REM, so a shift in stage proportions moves the nightly average with no change in "recovery" [SECONDARY — [Morpheus support article](https://support.trainwithmorpheus.com/support/solutions/articles/4000226296-overnight-hrv-vs-morning-hrv-why-measurement-method-matters), [Altini on timing](https://medium.com/@altini_marco/thoughts-on-heart-rate-variability-hrv-measurement-timing-morning-or-night-b92bd5495bc8)].
- **Morning measurement** is a short (1–5 min) controlled reading in a consistent posture before caffeine or food. Lower ecological contamination, higher compliance cost.

Design consequence: if the app reports overnight HRV, the honest caption is "what your body did last night", not "how ready you are today".

### 1.5 How much day-to-day noise is normal

Two separate noise sources stack:

**Device error.** A 5-device validation against reference ECG (n = 13, 536 nights):

| Device | RHR MAE | HRV (RMSSD) MAE | HRV MAPE | HRV limits of agreement |
|---|---|---|---|---|
| Oura Gen 4 | 1.08 bpm | 3.93 ms | 5.96% | −11.78, +9.85 ms |
| Oura Gen 3 | 0.98 bpm | 3.91 ms | 7.15% | −11.43, +6.43 ms |
| WHOOP 4.0 | 1.78 bpm | 4.17 ms | 8.17% | −12.50, +10.94 ms |
| Garmin Fenix 6 | (excluded) | 5.29 ms | 10.52% | −15.22, +11.60 ms |
| Polar Grit X Pro | 1.72 bpm | 7.27 ms | 16.32% | −14.30, +23.60 ms |

Source: [Dial et al., *Validation of nocturnal resting heart rate and heart rate variability in consumer wearables*, Physiological Reports 2025 (PMC12367097)](https://pmc.ncbi.nlm.nih.gov/articles/PMC12367097/) — fetched.

Read the limits of agreement column, not the MAE column. On a typical night a consumer wearable's RMSSD can be **±10–20 ms away from truth**. Against a healthy population SD of 15 ms, single-night device error is the same size as real between-person variation.

**Biological day-to-day variation.** Coefficient of variation of daily HRV is commonly cited around 0.37, with individuals ranging 0.14–0.71, i.e. many people swing 30–40% around their own mean day to day [**UNVERIFIED** — this figure appeared in a search summary attributed to HRV-practitioner literature; I could not fetch a primary source in this session. Treat the direction as real, the exact number as unconfirmed].

Combined: **a one-night HRV delta is mostly noise.** This is the single most important finding in this document.

### 1.6 Does day-to-day HRV track how people feel?

A 14-day prospective observational study, n = 41, 424 daily observations:

| Outcome | Association with higher morning RMSSD |
|---|---|
| Sleep quality | β = 0.510, 95% HDI [0.239, 0.779] |
| Fatigue (lower) | β = 0.281, 95% HDI [0.020, 0.562] |
| Stress (lower) | β = 0.353, 95% HDI [0.059, 0.606] |
| Body soreness | β = 0.172, HDI [−0.051, 0.396] — **no credible association** |
| Alcohol → sleep quality | β = −0.994, HDI [−1.634, −0.355] |

Authors' own conclusion: effect sizes were "modest" and "single-day HRV readings offer limited insight, whereas multi-day trajectories ... provide a more robust signal."

Source: [*Associations Between Daily Heart Rate Variability and Self-Reported Wellness: A 14-Day Observational Study in Healthy Adults* (PMC12300306)](https://pmc.ncbi.nlm.nih.gov/articles/PMC12300306/) — fetched.

Note what alcohol does: its effect on reported sleep quality (β ≈ −1.0) is roughly **twice** the size of HRV's own association with sleep quality. The behaviour is a bigger lever than the metric.

### 1.7 Published evidence that consumers do not understand HRV

The strongest direct evidence is a 2025 review in *Interacting with Computers* (van den Berg et al., "Why we should stress about stress scores"), which synthesises the HCI literature. Relevant findings it reports:
- Interview participants conceptualised stress as **mental pressure**, and could not reconcile that with a physiological HRV-derived score (citing Ding et al. 2021).
- Office workers worried the tracker would **replace their own interoception** (citing Kerr et al. 2023).
- Field workers experienced anxiety **comparing stress graphs with colleagues**, despite the response being highly individual (citing Xue et al. 2022).

Source: [van den Berg et al., *Why we should stress about stress scores*, Interacting with Computers 38(1), 2025](https://academic.oup.com/iwc/article/38/1/1/8214201) — fetched.

Secondary but useful: a qualitative study of 17 regular exercisers using Whoop or Oura for ≥3 months found three themes, the third being explicit recognition that devices "can't really capture the complexities of a human"; participants **prioritised personal judgement over the score** when deciding how to train. Source: [*Exploring Regular Exercisers' Experiences with Readiness/Recovery Scores*, PubMed 38668986](https://pubmed.ncbi.nlm.nih.gov/38668986/) — fetched.

---

## 2. Resting heart rate

### 2.1 Reliability

RHR is the most reliable thing a consumer wearable measures. Nocturnal RHR MAE is **0.98–1.78 bpm** across Oura Gen 3/4, Polar and WHOOP, with concordance correlation coefficients 0.86–0.98 ([Dial et al. 2025](https://pmc.ncbi.nlm.nih.gov/articles/PMC12367097/) — fetched). PPG is well validated at rest and during sleep; accuracy degrades during daily activity and exercise.

### 2.2 Meaningfulness

Population evidence is strong and linear. Per 10 bpm higher resting heart rate:
- All-cause mortality RR **1.09** (95% CI 1.07–1.12), 46 studies, 1,246,203 participants ([CMAJ meta-analysis](https://www.cmaj.ca/content/188/3/E53)) [SECONDARY — search summary]
- All-cause mortality RR **1.17** (1.14–1.19), 48 studies (Aune et al., dose–response meta-analysis) [SECONDARY — search summary]

### 2.3 What a 3–5 bpm elevation means

The commonly cited clinical threshold is that a deviation of **5–7 bpm or ~10% from personal baseline** is clinically meaningful — a figure quoted directly inside the Dial et al. validation paper as the benchmark their device errors are compared against (fetched). Since device MAE is ~1–2 bpm, a 5 bpm shift is genuinely detectable above noise.

A 3–5 bpm elevation above baseline is widely used as an early illness signal, often 1–3 days before symptoms, especially when combined with a skin temperature rise and an HRV drop [**[SECONDARY]** — this specific 3–5 bpm illness figure came from a search summary of commercial/blog sources, not a fetched primary study. The 5–7 bpm clinical-relevance threshold is the better-sourced number].

The safe design rule, well supported by the trend-based framing in the validation literature: **one elevated night means almost nothing; three or four consecutive elevated nights is a real signal.** RHR is also non-specific — it cannot distinguish infection from overtraining from alcohol from stress.

---

## 3. Sleep

### 3.1 Sleep vs wake detection: good. Sleep staging: not good.

Meta-analysis of 24 studies, 798 participants, wrist-worn consumer devices vs polysomnography:

| Parameter | Bias vs PSG |
|---|---|
| Total sleep time | −16.9 min (95% CI −26.3 to −7.4) |
| Sleep efficiency | −4.7% (−7.1 to −2.3) |
| Sleep onset latency | +2.6 min (0.6 to 4.5) |
| WASO | +13.3 min (4.5 to 22.0) |

Non-Fitbit devices overestimated WASO by ~24.1 min. The authors explicitly note staging performance was **not** assessed.
Source: [*Performance of consumer wrist-worn sleep tracking devices compared to polysomnography: a meta-analysis*, J Clin Sleep Med (PMC11874098)](https://pmc.ncbi.nlm.nih.gov/articles/PMC11874098/) — fetched.

Four-stage classification, 6 devices vs PSG, n = 62, ~16,560 epochs each:

| Device | Cohen's κ | Wake sens. | Light | Deep | REM |
|---|---|---|---|---|---|
| Apple Watch S8 | 0.53 | 52.2% | 83.3% | 50.7% | 68.6% |
| Fitbit Sense | 0.42 | 48.8% | 73.3% | 50.9% | 61.3% |
| Fitbit Charge 5 | 0.41 | 47.7% | 72.4% | 51.5% | 60.0% |
| Whoop 4.0 | 0.37 | 40.1% | 62.0% | 69.6% | 62.0% |
| Withings Scanwatch | 0.22 | — | — | — | — |
| Garmin Vivosmart 4 | 0.21 | — | — | — | — |

All devices exceeded 90% sensitivity for *sleep*, but specificity for *wake* was 29–52%.
Source: [*A performance validation of six commercial wrist-worn wearable sleep-tracking devices for sleep stage scoring compared to polysomnography*, SLEEP Advances 2025 (PMC12038347)](https://pmc.ncbi.nlm.nih.gov/articles/PMC12038347/) — fetched.

Ring form factor does better but not dramatically: reported κ of 0.65 (Oura) vs 0.60 (Apple Watch) vs 0.55 (Fitbit) in a Brigham and Women's study, with Oura deep-sleep sensitivity 79.5% vs Fitbit 61.7% vs Apple 50.5% [**[SECONDARY]** — via [Sleep Review](https://sleepreviewmag.com/sleep-diagnostics/consumer-sleep-tracking/wearable-sleep-trackers/oura-ring-apple-watch-fitbit-face-off-sleep-accuracy-study/) and [Oura's own blog](https://ouraring.com/blog/2024-sensors-oura-ring-validation-study/); primary not fetched, and one of the two sources is the vendor].

**Bottom line: a wrist device is right about whether you were asleep. It is a coin flip about whether you were in deep sleep.** κ = 0.2–0.5 is "fair to moderate" agreement. A nightly "you got 42 minutes of deep sleep" figure has an error bar wide enough to swallow the number.

### 3.2 Sleep debt / sleep bank

The concept has partial evidence in both directions.

**Debt is real and repayment is slow.** Weekend catch-up does not fully restore lost sleep or neurobehavioural function, and does not protect against re-exposure to restriction. A week of recovery opportunity after 10 nights of restriction was insufficient to restore brain function; ~2 weeks of recovery were needed after 3 weeks of restriction. Carrying partial debt makes you *more* sensitive to the next short night, not less. Source: [*Dynamics of recovery sleep from chronic sleep restriction*, SLEEP Advances (PMC10108639)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10108639/) [SECONDARY — search summary, abstract-level].

**Banking ahead works, modestly.** Rupp et al. (SLEEP 2009;32(3):311) found that extending sleep to 10 h in bed for one week before a week of restriction reduced PVT lapses and sped recovery. But there were **no group differences in subjective sleepiness** — the benefit was objective only, and invisible to the person. Source: [Rupp et al., *Banking Sleep*, SLEEP](https://academic.oup.com/sleep/article-abstract/32/3/311/3741695) [SECONDARY — search summary].

Design consequence: a "sleep bank" balance in hours is defensible as a *directional* nudge but is not a physiologically calibrated ledger. Nobody has established an exchange rate between an hour lost and an hour repaid. Do not imply that repaying N hours restores N hours of function — the literature explicitly says it does not.

### 3.3 Sleep regularity beats duration

The strongest sleep finding of the last three years.

Windred et al., UK Biobank, **n = 60,977**, >10 million hours of accelerometry, mean age 62.8, 7.8-year follow-up. Sleep Regularity Index (SRI) = average concordance of sleep/wake state between all epoch pairs 24 hours apart; 100 = perfectly regular, 0 = random. Observed median SRI 81.0 (IQR 73.8–86.3), full range 2.5–98.5.

Fully adjusted all-cause mortality HRs vs the least-regular quintile:

| SRI percentile | HR (95% CI) |
|---|---|
| 20–40th | 0.80 (0.69–0.93) |
| 40–60th | 0.75 (0.64–0.88) |
| 60–80th | 0.72 (0.61–0.84) |
| 80–100th | 0.70 (0.59–0.83) |

Cancer mortality top vs bottom quintile HR 0.76 (0.61–0.94). Cardiometabolic mortality HR 0.62 (0.42–0.91). Model comparison showed **sleep regularity was a stronger predictor of all-cause mortality than sleep duration**.

Source: [Windred et al., *Sleep regularity is a stronger predictor of mortality risk than sleep duration*, SLEEP 47(1) 2024 (PMC10782501)](https://pmc.ncbi.nlm.nih.gov/articles/PMC10782501/) — fetched. Accompanying editorial: [*Consistency is key* (PMC10782489)](https://pmc.ncbi.nlm.nih.gov/articles/PMC10782489/).

This matters enormously for design, because regularity is (a) measurable with just bedtime and waketime, which wearables get right, (b) not dependent on the staging algorithms that are unreliable, and (c) expressible as a concrete behaviour ("go to bed within the same 30-minute window") rather than a score.

### 3.4 Sleep feedback changes how people feel — even when it is fake

Two controlled experiments, both directly relevant:

- **Gavriloff et al. 2018, J Sleep Res.** 63 adults meeting DSM-5 insomnia criteria received *sham* sleep-efficiency feedback on an actigraphy-diary watch at their habitual rise time. The negative-feedback group (n = 32) showed impaired daytime function by evening — decreased alert cognition, increased sleepiness/fatigue — versus positive feedback (n = 31). The feedback was fabricated; only the number differed. Source: [Gavriloff et al., *Sham sleep feedback delivered via actigraphy biases daytime symptom reports in people with insomnia: Implications for insomnia disorder and wearable devices*](https://onlinelibrary.wiley.com/doi/abs/10.1111/jsr.12726) [SECONDARY — abstract-level via search; the title itself states the wearable implication].
- **Draganich & Erdal 2014, J Exp Psychol LMC.** 164 participants told they had spent 28.7% vs 16.2% of the night in REM (fabricated). Those told "below average" performed **worse on memory and attention tests**. Source: [APA PDF](https://www.apa.org/pubs/journals/features/xlm-a0035546.pdf) [SECONDARY — search summary + APA-hosted PDF link].

### 3.5 Orthosomnia

Cross-sectional study, n = 523 adults. Prevalence of orthosomnia depending on the sleep-anxiety cutoff used: **3.0% (strict), 8.6% (moderate), 14.0% (lenient)**. Cases had significantly higher Athens Insomnia Scale scores at every threshold (median AIS 9 vs 4 at the strict cutoff, p < 0.001).
Source: [*Prevalence of Orthosomnia in a General Population Sample*, Brain Sciences 2024 (PMC11592250)](https://pmc.ncbi.nlm.nih.gov/articles/PMC11592250/) — fetched.

So somewhere between 1-in-33 and 1-in-7 trackers users are actively harmed by their own sleep score. That is not a rounding error in a consumer app.

---

## 4. Recovery / readiness scores

### 4.1 How they are actually computed

| Product | Stated inputs |
|---|---|
| **WHOOP Recovery** | HRV, RHR, respiratory rate, sleep performance → 0–100% ([WHOOP 101](https://developer.whoop.com/docs/whoop-101/)) |
| **Oura Readiness** | Seven daily "contributors": sleep, sleep balance, previous day activity, activity balance, body temperature, resting heart rate, HRV balance, recovery index ([Oura support](https://support.ouraring.com/hc/en-us/articles/360057791533-Readiness-Contributors)) |
| **Garmin Body Battery** | Firstbeat algorithm; HRV + all-day stress + activity + sleep, compared against personal baseline; drains and recharges 0–100 ([Garmin/Firstbeat](https://www.garmin.com/en-SG/blog/firstbeat-analytics-the-strong-partner-that-joined-garmin/)) |
| **Ultrahuman Dynamic Recovery** | Five factors: sleep, stress rhythm score, temperature, RHR, HRV; 0–100%, updates through the day ([Ultrahuman blog](https://www.ultrahuman.com/blog/ultrahuman-ring-recovery-score-guide/)) |

All four use overlapping inputs with undisclosed weights.

### 4.2 The validation situation

The definitive source is a 2025 review in *Translational Exercise and Biomedicine* (Doherty, Baldwin, Lambe, Burke, Altini) cataloguing **14 composite health scores across 10 manufacturers** — Fitbit Daily Readiness, Garmin Body Battery and Training Readiness, Oura Readiness and Resilience, WHOOP Strain/Recovery/Stress Monitor, Polar Nightly Recharge, Samsung Energy Score, Suunto Body Resources, Ultrahuman Dynamic Recovery, Coros.

Input frequency across the 14 scores: HRV **86%**, resting heart rate **79%**, physical activity **71%**, sleep **71%**, body temperature **29%**, respiratory rate **14%**.

Key finding, quoted: "no manufacturer disclosed how they are algorithmically weighted, nor were any CHS validated against clinical outcomes." Manufacturers offer "theoretical white papers" rather than full validation studies. The review's own recommendation is that these should be treated as **motivational** tools, not clinical instruments.

Source: [de Gruyter listing](https://www.degruyterbrill.com/document/doi/10.1515/teb-2025-0001/html?lang=en), [DOAJ record](https://doaj.org/article/e06b2cf2d8a0402d9af92b0a4c3cb1f9). Publisher pages returned 403/405 to fetch; the numbers and quotes above were extracted from a [secondary summary](https://www.biosourcesoftware.com/post/5-second-science-wearable-composite-health-scores-require-validation) that I did fetch. **[SECONDARY]** on the exact percentages; the "none validated" conclusion is corroborated independently across three sources.

### 4.3 Direct evidence a recovery score fails to track recovery

A study of 23 NCAA Division 1 swimmers (ages 18–22) in a heavy training block compared WHOOP metrics against resting metabolic rate, serum T3, a 200-yard time trial, RESTQ-52 Sport and the Perceived Stress Scale. **WHOOP's Recovery score was not consistently associated with perceived recovery, stress or resting metabolic rate — even though the raw HRV WHOOP measured was.**

Source: [Penn State ETDA thesis record](https://etda.libraries.psu.edu/catalog/18210eal259), summarised by [CTS](https://trainright.com/new-study-reveals-holes-in-wearable-device-scores/) [SECONDARY — search summary; primary is a thesis, not a peer-reviewed journal article].

That is the important shape of the problem: **the composite is worse than its own inputs.** Aggregation with hidden weights destroys signal that was present in the raw metric.

---

## 5. Stress scores

### 5.1 What they are

Almost all consumer "stress" scores are HRV-derived, sometimes with EDA (Fitbit Sense) or skin temperature.

### 5.2 The five documented failure modes

From van den Berg et al. 2025 (fetched):

1. **Conceptualisation** — the device labels a physiological measurement "stress"; users mean psychological pressure. The two words do not refer to the same thing.
2. **Measurement** — HRV-based systems cannot distinguish a stress response from exercise, illness, or digestion.
3. **Transparency** — proprietary black-box algorithms leave users unable to check or contest the number.
4. **Interpretation** — red/green colour coding imposes a negative framing even on **eustress**. An orange spike caused by excitement reads as distress.
5. **Responsibility** — the framing implies personal control over stress and ignores structural causes.

Their design recommendations, verbatim in intent: use **seamful design** that exposes limitation rather than hiding it; use **neutral terminology** ("bodily strain" rather than "stress"); increase user agency so "individuals should be actively involved in data sense making" rather than getting "judgmental interfaces that dictate interpretations".

### 5.3 Known false positives

Confirmed confounds that raise a stress score without psychological stress: hard exercise, fever/illness, alcohol, caffeine, dehydration, cold hands, loose strap, digestion, and **positive arousal** (excitement, focus). EDA specifically responds to ambient temperature and physical activity as well as emotion. Sources: [van den Berg et al. 2025](https://academic.oup.com/iwc/article/38/1/1/8214201) (fetched); corroborating detail from search summaries of [Sensors 2026 wellbeing/HRV disconnection study](https://www.mdpi.com/1424-8220/26/4/1325) which reported **self-reported stress and nervousness had no association with HRV** [SECONDARY].

One quantitative marker of the difficulty: in a study classifying stress type from wearable signals, recall for psychological stress was **50.0%** and for psychological recovery **54.2%**, with frequent misclassification as rest [SECONDARY — search summary of [arXiv 2604.12671](https://arxiv.org/pdf/2604.12671)].

A stress score that is 50% accurate on psychological stress is a coin flip presented in red.

---

## 6. Strain / training load

### 6.1 TRIMP

Banister's Training Impulse weights heart-rate reserve by session duration using a coefficient from the HR–lactate relationship. Known weakness: it does not discriminate work from rest, collapsing both into one mean intensity, which underestimates interval sessions. Session-RPE — a subjective 0–10 rating times minutes — correlates strongly with TRIMP variants (r = 0.79–0.86 across ballet, karate and basketball studies) and outperforms TRIMP for high-intensity functional training.
Sources: [Session-RPE Method for Training Load Monitoring: Validity, Ecological Usefulness, and Influencing Factors, Front Neurosci 2017](https://www.frontiersin.org/journals/neuroscience/articles/10.3389/fnins.2017.00612/full), [ballet study PMC7240108](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7240108/), [karate study PMC9536392](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9536392/), [HIFT study PMC7435063](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7435063/) [SECONDARY — search summaries].

Design implication worth noting: **a one-question subjective rating performs about as well as the sensor-derived metric.** That is a very cheap input.

### 6.2 WHOOP Strain

0–21, logarithmic, Borg RPE-inspired (Borg runs 6–20; WHOOP extends to 21). Built from per-second heart rate weighted by time in personalised HR zones, so two people doing the same workout get different Strain. Source: [WHOOP](https://www.whoop.com/us/en/thelocker/how-does-whoop-strain-work-101/).

The logarithmic scale is a real comprehension hazard: the interval from 18 to 19 is not the same amount of work as 8 to 9, but the UI presents them as equal steps.

### 6.3 Acute:chronic workload ratio — the criticism

Impellizzeri, Tenan et al., *Acute:Chronic Workload Ratio: Conceptual Issues and Fundamental Pitfalls*, Int J Sports Physiol Perform 2020;15(6):907–913. Core criticisms:
- ACWR suffers **severe mathematical coupling** (the acute load appears in both numerator and denominator of the chronic window), which manufactures spurious associations.
- The ratio has statistical properties that make it an inaccurate metric and complicate interpretation.
- No study has estimated a **causal** effect, so recommending athletes manipulate ACWR to reduce injury is "conjecture and overinterpretation".
- There is no rationale for the specific 7-day / 28-day windows.
- The famous "sweet spot" injury figure was the subject of a formal request for retraction or correction to BJSM.

Sources: [Human Kinetics listing](https://journals.humankinetics.com/view/journals/ijspp/15/6/article-p907.xml) (403 on fetch), [Semantic Scholar record](https://www.semanticscholar.org/paper/Acute:Chronic-Workload-Ratio:-Conceptual-Issues-and-Impellizzeri-Tenan/ede5743a426fd6429d28f8505500a3f771dbcf8b), ["The ACWR-injury figure and its 'sweet spot' are flawed"](https://www.researchgate.net/publication/333589357_The_acute-chronic_workload_ratio-injury_figure_and_its_'sweet_spot'_are_flawed) [SECONDARY — all via search; publisher blocked direct fetch].

**Do not ship an ACWR-derived "injury risk" number.** The field's own methodologists have asked for the founding paper to be retracted.

---

## 7. Circadian rhythm, chronotype, light

- Bright light (roughly 1,000–10,000 lux) for 15 min to several hours shifts circadian phase by 30 min to 3 hours depending on **timing**, per the phase response curve. Largest advances come from light around 04:00–05:00. Morning light advances the clock; evening light delays it. Sources: [Systematic review of light exposure impact on human circadian rhythm, Chronobiol Int 2018](https://www.tandfonline.com/doi/full/10.1080/07420528.2018.1527773), [MDPI phase-advance study](https://www.mdpi.com/2624-5175/5/4/41) [SECONDARY — search summaries].
- The PRC is **individual**: evening types respond more to evening light, morning types to morning light. So blanket "get morning light" advice is right in direction but not personalised.
- Social jetlag — the gap between biological and socially imposed sleep timing — accumulates sleep debt and impairs cognition. Bright morning light is used therapeutically for delayed sleep–wake phase and for social jetlag. Source: [Nature Sci Rep 2023, daily rhythms/light/social jetlag nationally representative survey](https://www.nature.com/articles/s41598-023-39011-x) [SECONDARY].
- A 301-adult study of light-exposure behaviours found daytime and pre-sleep light behaviours predicted chronotype, sleep quality and mood, with ~72.7% predictive power. Source: [*Light exposure behaviors predict mood, memory and sleep quality*, Sci Rep 13:12425 (2023) (PMC10394000)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10394000/) [SECONDARY — search summary; direct fetch blocked by publisher auth redirect].

**Actionable subset:** get outdoor light shortly after waking; dim/avoid bright light 2–3 h before bed; keep wake time consistent. These are three behaviours, not a score. Chronotype itself is stable and therefore not something to display daily.

---

## 8. Fatigue and overtraining detection

The ECSS/ACSM joint consensus statement (Meeusen et al., Eur J Sport Sci 2013) is the authoritative position: **there is no single blood test or biomarker that reliably diagnoses overtraining syndrome.** Distinguishing non-functional overreaching from overtraining syndrome is "very difficult" and depends on clinical outcome and diagnosis by exclusion.
Source: [Tandfonline listing](https://www.tandfonline.com/doi/abs/10.1080/17461391.2012.730061) [SECONDARY — search summary].

HRV-guided training exists as an RCT literature but the detection problem is unsolved; one protocol critique notes that post-exercise HRV responses to overreaching were assessed after maximal exercise, which is exactly what you must not ask a possibly-overtrained athlete to do. Source: [PMC7820717](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7820717/) [SECONDARY].

**Consequence: no consumer app can honestly claim to detect overtraining or burnout.** Sports medicine cannot do it with blood work.

---

## 9. Biological age / pace of aging

### 9.1 Epigenetic clocks

Shalev (Penn State) and Apsley (UIUC), May 2026:
- Dozens of clocks exist for different purposes; they **disagree with each other on the same person**.
- DNA methylation is dynamic — diet, environment, illness and **time of day** shift results, so the same person tests differently depending on when.
- There is **no gold-standard method** across labs; saliva vs blood "can yield substantially different results for the same person".
- Reducing aging to one number is misleading since there is no agreed definition of aging.
- Equity risk: clocks reflect trauma, discrimination and early-life adversity, so marginalised groups read as "accelerated", inviting discrimination.
- Their verdict is in the title: useful for researchers, **not for consumers**.

Source: [The Conversation, 4 May 2026](https://theconversation.com/biological-age-tests-reveal-what-slows-or-hastens-aging-but-theyre-useful-only-for-researchers-not-consumers-275974) — fetched.

First- and second-generation clocks have shown technical replicate deviations approaching **a decade**; PC-based clocks and DunedinPACE were built specifically to fix that reproducibility problem. Sources: [bioRxiv 2025.10.13.682176](https://www.biorxiv.org/content/10.1101/2025.10.13.682176.full.pdf), [Epistemic uncertainty challenges aging clock reliability, PMC11561706](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11561706/) [SECONDARY — search summaries].

### 9.2 VO2max-derived "fitness age"

Garmin Fitness Age derives from the estimated VO2max. Firstbeat's own validation reports MAE ≈ 3.5 mL/kg/min under controlled outdoor conditions with a chest strap, which maps to roughly a **3–5 year swing in displayed Fitness Age**. Independent validations put wrist-based VO2max MAE at 3–5 mL/kg/min with 95% limits of agreement reaching ±7 mL/kg/min in some subgroups; error is largest at the tails of the fitness distribution. A fēnix 6 study reported MAPE 7.05% and Lin's CCC 0.73 for the 30-second averaged comparison. Sources: [the5krunner fitness age analysis](https://the5krunner.com/garmin-features/physiology/fitness-age/), [Validation of Aerobic Capacity (VO2max) and Pulse Oximetry in Wearable Technology, PMC11723475](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11723475/), [Apple Watch S7 VO2max validation, JMIR Biomed Eng 2024](https://biomedeng.jmir.org/2024/1/e59459) [SECONDARY — search summaries].

So "your fitness age is 34" carries a ±3–5 year error bar minimum. Displaying it to one-year precision, or animating it changing week to week, is fabricating resolution that does not exist.

### 9.3 The "age" framing itself — does it work?

This is the one place where there is a real controlled answer, from the heart-age literature. Systematic review, 16 studies: 5 randomised web experiments (5,514 participants), 5 RCTs (9,582 patients).

| Outcome | Heart age vs absolute risk |
|---|---|
| Emotional response | Increased (4/5 studies) |
| Risk perception | Increased (4/5) — but **not more accurate**; "low-risk people may think they are high risk" |
| Recall | Improved (4/4); one study 32% vs 16% correct recall at 2 weeks |
| Lifestyle intentions | **No effect** (4/5) |
| Actual behaviour | No differences in self-reported behaviour in web studies |

Authors' conclusion: "little evidence that heart age motivates lifestyle behavior change more than absolute risk", and they warn reviewed conclusions were "sometimes biased in favor of heart age with insufficient supporting evidence".

Source: [*Interventions Using Heart Age for Cardiovascular Disease Risk Communication: Systematic Review*, JMIR Cardio 2021 (PMC8663444)](https://pmc.ncbi.nlm.nih.gov/articles/PMC8663444/) — fetched.

**Age framing is memorable and emotionally potent but does not change behaviour, and it degrades risk accuracy.** That is a precise verdict: it is an engagement metric dressed as a health metric.

---

## 10. Cardiovascular health

### 10.1 VO2max is the strongest predictor available

Mandsager et al., JAMA Network Open 2018;1(7):e183605. **n = 122,007** adults undergoing treadmill testing, median 8.4-year follow-up, 1.1 million person-years.

| Comparison | Adjusted HR |
|---|---|
| Elite vs low fitness (mortality) | **0.20** (95% CI 0.16–0.24), p < .001 |
| Low vs elite fitness | 5.04 |
| Smoking | 1.41 |
| Diabetes | 1.40 |
| Coronary artery disease | 1.29 |

Conclusion: "Cardiorespiratory fitness is inversely associated with long-term mortality with no observed upper limit of benefit."
Source: [JAMA Network Open](https://jamanetwork.com/journals/jamanetworkopen/fullarticle/2707428) — fetched.

The risk carried by low fitness (HR 5.04) is larger than smoking, diabetes and CAD **combined in magnitude terms**. Nothing else on a consumer health screen predicts death that strongly.

Caveat that must be respected in the UI: this is measured VO2max from a graded treadmill test. Wearable-estimated VO2max carries the ±3–5 mL/kg/min error described in §9.2, which is enough to move someone a whole fitness category.

### 10.2 Steps: the 7,000 finding

Ding et al., *Daily steps and health outcomes in adults: a systematic review and dose-response meta-analysis*, Lancet Public Health 2025. 57 studies, 2014–2025, 10+ countries.

- 7,000 vs 2,000 steps/day: all-cause mortality **HR 0.53 (95% CI 0.46–0.60)**, 14 studies, I² = 36.3%
- 7,000 vs 2,000 steps/day: CVD mortality **HR 0.53 (0.37–0.77)**, 3 studies, I² = 78.2%
- Inverse non-linear dose–response with **inflection around 5,000–7,000 steps/day** for all-cause mortality, CVD incidence, dementia and falls
- Authors: 10,000 remains viable for the more active, but 7,000 "is associated with clinically meaningful improvements ... and might be a more realistic and achievable target"

Source: [Lancet Public Health](https://www.thelancet.com/journals/lanpub/article/PIIS2468-2667(25)00164-1/fulltext) (403 on direct fetch), [PubMed 40713949](https://pubmed.ncbi.nlm.nih.gov/40713949/), [Science Media Centre expert reaction](https://www.sciencemediacentre.org/expert-reaction-to-systematic-review-and-meta-analysis-of-daily-step-count-and-risk-of-chronic-diseases-cognitive-decline-and-death/) (fetched). Earlier: [Paluch et al., Lancet Public Health 2022, 15-cohort meta-analysis](https://www.thelancet.com/journals/lanpub/article/PIIS2468-2667(21)00302-9/fulltext).

Expert caveats from the SMC reaction (fetched): many findings rest on a small number of studies; the review lacks mechanistic insight; step count does not capture intensity and misrepresents cycling, swimming and rowing.

### 10.3 Do trackers actually change behaviour?

Umbrella review of systematic reviews and meta-analyses: activity trackers produce roughly **+1,800 steps/day**, **+40 min/day walking**, and **~1 kg** weight reduction. Wearable interventions significantly increased daily steps and weekly MVPA but had **no effect on light activity or sedentary behaviour**. The behaviour change techniques doing the work are goal setting, self-monitoring, feedback on behaviour, and discrepancy-between-current-behaviour-and-goal; self-monitoring is the single most effective.
Sources: [Ferguson et al., Lancet Digital Health 2022 umbrella review](https://www.sciencedirect.com/science/article/pii/S258975002200111X), [Behavior Change Techniques in Wrist-Worn Wearables, PMC7714647](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7714647/) [SECONDARY — search summaries].

Note the shape: **the metrics with proven behaviour change are steps and active minutes.** There is no equivalent evidence base for HRV, recovery scores, or sleep scores changing behaviour — and there *is* evidence (§3.4, §3.5) that sleep scores can cause harm.

---

## 11. Health literacy and numeracy

The population you are designing for:

| Finding | Figure | Source |
|---|---|---|
| Correctly identify "1 in 1000" = 0.1% | **25%** of the general population | Gigerenzer et al., via [BMJ/PMC3310025](https://pmc.ncbi.nlm.nih.gov/articles/PMC3310025/) — fetched |
| Same question, well-educated adults | **21%** | ibid — fetched |
| Correctly state a person's 10-year risk when told it is double someone else's 1-in-100 risk | **57%** | [PMC4041683 / graphical breast cancer risk study](https://ncbi.nlm.nih.gov/pmc/articles/PMC4041683) [SECONDARY] |
| US adults with inadequate graph literacy | **~40%** | [Graph literacy overview, PMC11129894](https://pmc.ncbi.nlm.nih.gov/articles/PMC11129894/) [SECONDARY] |
| US adults in the lowest numeracy band | **~29%** | ibid [SECONDARY] |
| Adults with both low graph literacy and low numeracy (US and Germany) | **~1 in 3** | [Galesic & Garcia-Retamero, Med Decis Making 2011](https://journals.sagepub.com/doi/abs/10.1177/0272989x10373805); US n = 492, Germany n = 495; mean score ~9.3/13 [SECONDARY] |
| US adults with basic or below-basic health literacy | **36%** | 2003 NAAL, via [PMC11129894](https://pmc.ncbi.nlm.nih.gov/articles/PMC11129894/) [SECONDARY] |
| Gynaecologists who misunderstood a 25% mammography risk reduction | **~1 in 3** of 150 | [PMC3310025](https://pmc.ncbi.nlm.nih.gov/articles/PMC3310025/) — fetched |

Correlations: education↔graph interpretation r = 0.42; numeracy↔graph interpretation r = 0.65 [SECONDARY].

What demonstrably improves comprehension: **natural frequencies instead of conditional probabilities**, and **absolute risk instead of relative risk** ([PMC3310025](https://pmc.ncbi.nlm.nih.gov/articles/PMC3310025/) — fetched).

Framing effects are large: the same benefit presented as relative risk reduction gets accepted most, as number-needed-to-treat gets accepted least. Which means **your choice of framing is a behavioural intervention whether you intend it or not.**

Wearable-specific: 87% of patients using devices requiring manual entry had recorded inaccurate data at some point; 54% blamed unclear instructions, 31% a confusing interface [SECONDARY — [TechTarget](https://www.techtarget.com/virtualhealthcare/feature/Challenges-of-using-healthcare-wearable-technology)]. Wearable use itself skews younger, higher-educated and higher-income (German nationwide survey, 24% usage) [SECONDARY — [PMC12206174](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12206174/)].

---

## A. Which metrics do ordinary users genuinely understand without training?

Ranked by comprehension confidence:

1. **Step count.** Universally understood, dose–response evidence is strong (§10.2), tracker interventions demonstrably move it (§10.3). Everyone knows what "walk more" means.
2. **Time asleep / bedtime / wake time.** Clock times need no interpretation. Devices measure sleep-vs-wake at >90% sensitivity (§3.1).
3. **Sleep regularity, expressed as "how close to your usual bedtime".** Understood as consistency, needs no scale, and it is the strongest sleep-mortality predictor (§3.3).
4. **Active minutes / workout duration.** Duration is a unit people live in.
5. **Resting heart rate — as a trend, in bpm.** Reliable (MAE ~1 bpm), a familiar unit, and people already have an intuition that a racing heart means something is up.
6. **Body weight.** Familiar unit, though loaded.
7. **"Did you drink alcohol last night?"** Not a sensor metric, but it explains more variance in reported sleep quality than HRV does (§1.6) and requires zero interpretation.

## B. Which metrics reliably confuse them?

1. **HRV in milliseconds.** Requires knowing (a) it is a within-person-only quantity, (b) which of RMSSD/SDNN it is, (c) that higher is usually better but not always, (d) that the healthy range spans 4x. Documented in the HCI literature that users cannot reconcile it with their felt experience (§1.7).
2. **Stress scores.** The word means something different to the device than to the user. Excitement reads as distress. Red/green imposes a moral frame on a physiological measurement (§5.2).
3. **Sleep stage percentages (deep/REM/light).** The device is near coin-flip accurate (κ 0.21–0.53), while users treat the number as measurement (§3.1). This is the worst accuracy-vs-perceived-authority gap on the screen.
4. **Recovery/readiness percentages.** Hidden weights, no validation, and users report the score contradicting how they feel (§4).
5. **Body Battery / energy metaphors.** The metaphor is intuitive but implies a conserved, measurable quantity that does not exist.
6. **Any logarithmic scale, e.g. WHOOP Strain 0–21.** Equal visual steps, unequal real steps.
7. **Percentages and percentiles generally.** Only 25% of adults can convert 1-in-1000 to 0.1%; ~40% have inadequate graph literacy (§11).
8. **Biological age / fitness age.** Memorable, emotionally potent, and — per the heart-age review — makes risk perception *less* accurate (§9.3).

## C. Which metrics actually change behaviour when displayed?

**Proven:**
- **Steps, with a goal and self-monitoring.** +1,800 steps/day, +40 min walking, ~1 kg (§10.3). This is the only wearable metric with an umbrella-review-level behaviour change effect.
- **Active minutes / MVPA.** Same evidence base; increased alongside steps.
- **Goal + progress + discrepancy feedback as a mechanism.** Goal setting, self-monitoring, feedback on behaviour and current-vs-goal discrepancy are the identified active ingredients — the *mechanism* matters more than the *metric* (§10.3).

**Changes feeling and belief but not behaviour:**
- **Age framings (heart age, fitness age, biological age).** Increase emotion, risk perception and recall; no effect on lifestyle intentions or behaviour (§9.3).
- **Sleep scores.** Change self-reported daytime function and cognitive performance the same day — even when the score is fabricated (§3.4). This is an effect on the person, not on their behaviour, and it runs in the harmful direction as often as the helpful one.

**No evidence of behaviour change:**
- HRV, recovery/readiness, stress scores, strain, body battery. No wearable-behaviour-change literature supports these. Notably, wearable interventions increased steps and MVPA but had **no effect on sedentary behaviour or light activity** — so even the proven metrics have a bounded reach.

## D. Which are expert-only vanity metrics that belong buried or removed?

**Remove:**
- **ACWR / injury-risk ratio.** The methodologists behind the critique formally requested retraction of the founding figure; severe mathematical coupling; no causal estimate (§6.3).
- **Consumer "biological age" from any epigenetic-clock-like claim.** Clocks disagree on the same person, technical replicates have deviated by ~a decade, and the researchers who build them say it is not for consumers (§9.1).
- **Overtraining / burnout "detection".** Sports medicine's own consensus says no reliable biomarker exists (§8).
- **Any cross-person HRV comparison, percentile or leaderboard.** Physiologically meaningless (§1.3).

**Bury (keep for the minority who want it, never on Home):**
- Raw HRV in ms, and the RMSSD/SDNN distinction.
- Sleep stage minutes and percentages.
- SDNN, LF/HF ratio, respiratory rate.
- Strain 0–21, TRIMP, EPOC, training load.
- VO2max as a precise number (surface the category, bury the decimal).
- Sleep latency and WASO in minutes (device bias is +2.6 and +13.3 min respectively, §3.1).

## E. Which numbers are noisy enough that a daily delta is actively misleading?

Do **not** show a day-over-day change for:

1. **HRV.** Device limits of agreement ±10–24 ms against a population SD of 15 ms; plus real biological day-to-day swings. The study authors' own words: "single-day HRV readings offer limited insight" (§1.5, §1.6). Minimum honest window: **7 days**, ideally with a variability band.
2. **Sleep stage minutes/percentages.** κ 0.21–0.53. A 3-percentage-point change in deep sleep is indistinguishable from algorithm noise (§3.1).
3. **Recovery / readiness / body battery.** Inherits every input's error and adds undisclosed weighting on top; the composite underperformed its own raw HRV input in the swimmer study (§4.3).
4. **Stress score.** ~50% recall on psychological stress; confounded by caffeine, exercise, illness, excitement (§5.3).
5. **VO2max / fitness age.** MAE 3–5 mL/kg/min, LoA up to ±7; that is ±3–5 years of "fitness age". Weekly movement is noise (§9.2).
6. **Sleep score.** Not because of measurement noise alone, but because of the causal harm demonstrated by sham-feedback experiments — a bad number degrades same-day function independent of actual sleep (§3.4).

Safe to show as a daily number:
- **Steps** (a direct count, no inference).
- **Time asleep and bedtime/waketime** (>90% sleep sensitivity).
- **Resting heart rate**, but only flagged when it clears the ~5 bpm / 10% threshold for **3+ consecutive nights** (§2.3).

---

## Design implications for the Home Screen

Current Home surfaces (from `Modules/Dashboard/Views/Home/`): a Recovery hero card, a metric strip of Brain / Sleep / Strain / Stress / Vitality, a Sleep Bank card, and a Personal Health Forecast. Mapping the evidence onto that:

1. **The Recovery hero is the least validated element on the screen.** Composite scores have no disclosed weights and no clinical validation across 14 products from 10 manufacturers, and at least one study found the composite tracked perceived recovery *worse* than its own raw HRV input. If it stays, it must not be the largest number, must not show a daily delta, and must be labelled as a directional summary, not a measurement.

2. **Replace the daily HRV delta with a 7-day band.** Show where today sits inside the person's own recent range, not "▲ 6 ms". Anything narrower than a week is reporting device error.

3. **Never show HRV against a population norm, cohort, or age group.** The healthy range is 19–75 ms RMSSD. There is no defensible "your HRV is low for your age" statement.

4. **Add sleep regularity as a first-class metric and give it real estate.** It is the best-evidenced sleep number (n = 60,977, HR 0.70), it uses only bedtime and waketime — the parts wearables get right — and it expresses as a behaviour ("same 30-minute window") rather than a score.

5. **Demote sleep stages below the fold.** κ 0.21–0.53 does not earn a hero position. If shown, show them without minute-level precision and without a night-over-night comparison.

6. **Re-examine the Sleep Bank card's implied ledger.** Debt is real, but repayment is not 1:1 and full recovery takes weeks. Frame it as "you're running short" rather than an hours-owed balance that implies a payable debt.

7. **Never lead with a bad number.** Sham-feedback experiments show a fabricated poor-sleep number causes worse same-day cognition and worse self-reported daytime function. Between 3% and 14% of tracker users already meet an orthosomnia definition. Negative framing on the Home Screen is not neutral information delivery; it is an intervention with a measured harmful effect.

8. **Rename "Stress".** The word promises psychology and delivers physiology. The HCI review's recommendation is neutral terminology such as "bodily strain". A stress score that fires on caffeine, a hard workout and genuine excitement should not be presented in red.

9. **Make steps and active minutes the behavioural spine of the screen.** They are the only metrics with umbrella-review evidence of changing behaviour, and 7,000 steps is a defensible, achievable, evidence-backed target (HR 0.53 vs 2,000). Pair with goal + progress + discrepancy, the identified active ingredients.

10. **Use absolute numbers and natural frequencies, never percentiles or relative-risk language.** Only ~25% of adults convert 1-in-1000 to 0.1%; ~40% have inadequate graph literacy. "You walked 4,200 steps; 7,000 is the point where the benefit curve flattens" beats "62nd percentile".

11. **Drop or bury any biological-age or fitness-age display.** It is memorable and emotional but makes risk perception less accurate and does not change behaviour. If cardiorespiratory fitness is shown, show a broad category, not a number to the decimal, and state the error range.

12. **Prefer one subjective question over a derived score where possible.** Session-RPE matches TRIMP at r = 0.79–0.86; a single "how do you feel?" reading is cheap, transparent, unfalsifiable by sensor error, and users already say they trust their own judgement over the device.

13. **Adopt seamful design for every derived number.** Show the inputs, show the uncertainty, let the user disagree. The reviewed literature's explicit recommendation is that people be "actively involved in data sense making" rather than handed "judgmental interfaces that dictate interpretations".

14. **Gate alerts on persistence, not on a single reading.** RHR: 5 bpm or 10% above baseline, sustained 3+ nights. HRV: a sustained multi-day trend outside the personal band. Never fire on one night.

15. **Do not ship injury risk, overtraining detection, or burnout detection.** Neither exists as a validated capability, and the ACWR literature's own authors have asked for the founding paper to be corrected or retracted.

---

## Source list

Fetched directly this session:
- https://pmc.ncbi.nlm.nih.gov/articles/PMC10782501/ — Windred et al., sleep regularity vs duration, SLEEP 2024
- https://pmc.ncbi.nlm.nih.gov/articles/PMC11874098/ — consumer sleep tracker meta-analysis vs PSG
- https://pmc.ncbi.nlm.nih.gov/articles/PMC12038347/ — six-device sleep staging validation
- https://pmc.ncbi.nlm.nih.gov/articles/PMC11592250/ — orthosomnia prevalence
- https://pmc.ncbi.nlm.nih.gov/articles/PMC12300306/ — daily HRV vs self-reported wellness, 14 days
- https://pmc.ncbi.nlm.nih.gov/articles/PMC12367097/ — Dial et al., nocturnal RHR/HRV wearable validation
- https://pmc.ncbi.nlm.nih.gov/articles/PMC5624990/ — Shaffer & Ginsberg, HRV metrics and norms
- https://academic.oup.com/iwc/article/38/1/1/8214201 — van den Berg et al., stress scores
- https://pubmed.ncbi.nlm.nih.gov/38668986/ — exercisers' experience of readiness/recovery scores
- https://jamanetwork.com/journals/jamanetworkopen/fullarticle/2707428 — Mandsager et al., CRF and mortality
- https://pmc.ncbi.nlm.nih.gov/articles/PMC8663444/ — heart age risk communication systematic review
- https://pmc.ncbi.nlm.nih.gov/articles/PMC3310025/ — communicating risk to patients and the public
- https://theconversation.com/biological-age-tests-reveal-what-slows-or-hastens-aging-but-theyre-useful-only-for-researchers-not-consumers-275974
- https://www.biosourcesoftware.com/post/5-second-science-wearable-composite-health-scores-require-validation
- https://www.sciencemediacentre.org/expert-reaction-to-systematic-review-and-meta-analysis-of-daily-step-count-and-risk-of-chronic-diseases-cognitive-decline-and-death/
- https://marcoaltini.substack.com/p/heart-rate-variability-hrv-numbers

Searched and cited (primary blocked or abstract-level only):
- https://www.thelancet.com/journals/lanpub/article/PIIS2468-2667(25)00164-1/fulltext — Ding et al. 2025 daily steps meta-analysis (403)
- https://www.degruyterbrill.com/document/doi/10.1515/teb-2025-0001/html?lang=en — composite health scores review (405/403)
- https://journals.humankinetics.com/view/journals/ijspp/15/6/article-p907.xml — Impellizzeri ACWR pitfalls (403)
- https://onlinelibrary.wiley.com/doi/abs/10.1111/jsr.12726 — Gavriloff sham sleep feedback
- https://www.apa.org/pubs/journals/features/xlm-a0035546.pdf — Draganich & Erdal placebo sleep
- https://www.tandfonline.com/doi/abs/10.1080/17461391.2012.730061 — ECSS/ACSM overtraining consensus
- https://academic.oup.com/sleep/article-abstract/32/3/311/3741695 — Rupp et al., banking sleep
- https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10108639/ — recovery from chronic sleep restriction
- https://www.cmaj.ca/content/188/3/E53 — RHR and mortality meta-analysis
- https://www.sciencedirect.com/science/article/pii/S258975002200111X — activity tracker umbrella review
- https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7714647/ — behaviour change techniques in wearables
- https://journals.sagepub.com/doi/abs/10.1177/0272989x10373805 — Galesic & Garcia-Retamero graph literacy
- https://pmc.ncbi.nlm.nih.gov/articles/PMC11129894/ — health/graph/numeracy literacy overview
- https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10394000/ — light exposure behaviours and mood/sleep
- https://www.nature.com/articles/s41598-023-39011-x — daily rhythms, light, social jetlag
- https://www.tandfonline.com/doi/full/10.1080/07420528.2018.1527773 — light and circadian rhythm systematic review
- https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11723475/ — wearable VO2max validation
- https://biomedeng.jmir.org/2024/1/e59459 — Apple Watch VO2max validation
- https://www.frontiersin.org/journals/neuroscience/articles/10.3389/fnins.2017.00612/full — session-RPE validity
- https://www.mdpi.com/1424-8220/26/4/1325 — self-reported wellbeing vs wearable HRV disconnection
- https://etda.libraries.psu.edu/catalog/18210eal259 — WHOOP in D1 swimmers
- Vendor documentation: https://developer.whoop.com/docs/whoop-101/ , https://www.whoop.com/us/en/thelocker/how-does-whoop-strain-work-101/ , https://support.ouraring.com/hc/en-us/articles/360057791533-Readiness-Contributors , https://www.garmin.com/en-SG/blog/firstbeat-analytics-the-strong-partner-that-joined-garmin/ , https://www.ultrahuman.com/blog/ultrahuman-ring-recovery-score-guide/

## Explicitly unverified

- The "HRV coefficient of variation averages 0.37, range 0.14–0.71" figure. Direction is consistent with the literature; the exact number came from a search summary I could not trace to a fetchable primary.
- The "3–5 bpm RHR elevation predicts illness 1–3 days early" figure specifically. The better-sourced adjacent claim is the 5–7 bpm / 10% clinical-relevance threshold, which appears inside the fetched Dial et al. paper.
- Per-device Oura/Apple/Fitbit sleep-staging kappas (0.65/0.60/0.55). One of the two supporting sources is Oura's own marketing.
- The 1,800 steps/day tracker effect. Umbrella-review-level and widely repeated, but I read it in a search summary, not the fetched paper.

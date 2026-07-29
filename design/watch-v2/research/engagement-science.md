# Engagement Science — Glance, Habit, Retention Evidence

# Watch-App Glance & Habit Evidence Pack
Research for Laso Apple Watch redesign. Every claim below traces to a page I fetched this session unless explicitly marked "snippet only" (search-result text, full page not retrievable).

---

## 1. Smartwatch glance behaviour — hard field data

### 1.1 Visuri et al., CHI 2017 — largest in-the-wild smartwatch dataset (307 users)
[strong: peer-reviewed, ACM CHI] — full paper read [source: https://www.kostakos.org/papers/chi17.pdf]

| Fact | Value |
|---|---|
| Dataset | 307 Android Wear users, 1 Jan – 15 Jul 2016 |
| Raw volume | 2,801,082 notifications, 800,119 screen events → 798,423 analysed sessions |
| **Median session length** | **exactly 5.0 seconds** |
| Mass point at 5 s | 22.1% of all sessions are exactly 5 s (N=72,786), mean 8.63 s |
| "Peek" (≤5 s) | N=517,989 |
| "Interaction" (>5 s) | N=280,434 |
| Abstract wording | "half the sessions lasting less than 5 seconds" |
| **Sessions per day** | **142.1 smartwatch sessions/day** (users with ≥7 days data; 5,107 days, 725,548 sessions) |
| Smartphone comparison | 60.08 sessions/day, mean session 229.34 s (3 min 52 s) |
| Watch mean session length | user-initiated **7.94 s**; notification-initiated **10.67 s** (t=55, p<.05; KS D=.176) |
| **Proactive vs reactive** | **82.3% user-initiated (657,250) vs 17.7% notification-initiated (141,173)** |
| Time concentration | 8am–10pm; 2pm–10pm skews toward brief peeks over longer interactions (χ²(hour)=1192.9, p<.05) |
| Session isolation | 81.1% of sessions have no follow-up session within 45 s; 10.9% two consecutive; 9% three or more |

**Design-critical implication of the 82/18 split:** on a watch, the overwhelming majority of screen-ons are *self-initiated glances*, not notification responses. A watch app that only exists behind a push notification is fighting for the 17.7% slice.

### 1.2 Notification economics on the wrist (same paper)
[strong: peer-reviewed]
- Only **9.4% of all notifications** result in a potential interaction session.
- **12.1%** of notifications were observed promptly (within 60 s); **87.9%** were delayed/ignored (N=2.4M).
- 19.7% of notifications arrive while the device is already in use or charging (wasted).
- When a notification *is* acted on: mean delay 23 s (median 20 s); resulting mean interaction session 17.89 s.
- Notification source mix: Tools 38.5%, Travel & Local 21.9%, Other 11.6%, Communication 9%, **Health & Fitness 6%**.

### 1.3 Blascheck et al. (Inria/Microsoft Research), TVCG/InfoVis 2018 — how fast a chart can be read on a watch
[strong: peer-reviewed, controlled psychophysics] — full paper read [source: https://www.microsoft.com/en-us/research/wp-content/uploads/2018/08/GlanceableVis-InfoVis2018.pdf]

Two-alternative forced choice, staircase method, threshold set at ~91% correct. Stimulus exposure duration needed to correctly compare two values:

| Chart type | Study 1 (controlled 25% difference) | Study 2 (random difference) | Ratio |
|---|---|---|---|
| **Bar chart** | **159 ms** avg | 285 ms | 1.16× |
| **Donut chart** | **245 ms** avg | 216 ms | 1.35× |
| Radial bar chart | **1548 ms** avg | 1772 ms | 1.14× |

- Conclusion verbatim: "bar and donut charts should be preferred on smartwatch displays when quick data comparisons are necessary."
- Radial/spiral encodings cost roughly **6–10× more viewing time** than bar or donut.
- Data sizes tested: 7, 12, 24 values. Physical stimulus size 28.73 mm × 28.73 mm.
- Ergonomics pre-study (20 participants, Vicon tracking): mean watch pitch angle 50° (SD 8°), **mean viewing distance 28 cm** (SD 5), line-of-sight offset ~10° — i.e. the watch is never held square to the eye. Design for an off-axis, ~28 cm read.

### 1.4 Pizza et al. video study (as reported inside Blascheck et al.)
[medium: peer-reviewed, but cited secondhand — I did not fetch the Pizza paper]
- 12 participants, **1009 recorded instances** of smartwatch use on video.
- **~50% of all instances were checking the time, average duration ~2 s.**
- Notifications were the second most-used feature, **~7 s average, ~17% of instances**.

### 1.5 Apple Watch check frequency
[weak: 2015 vendor survey, snippet only — wareable.com returned HTTP 403, could not verify the page body]
- Wristly survey (2015): Apple Watch wearers wake the watch **60–80 times/day** (4–5 times/hour); 38% check 2–3×/hour, 28% check 4–5×/hour; 59% say viewing time or a complication is the several-times-an-hour action vs 6% for replying to a message. [source: https://www.wareable.com/smartwatches/apple-watch-wearers-check-smartwatch-80-times-a-day-1995 — **unverified**]
- Note: the CHI 2017 figure of 142.1 sessions/day is measured telemetry and is the more defensible number; the 60–80 figure is self-report.

---

## 2. Apple's own published design guidance
[medium: vendor/official, WWDC session transcript fetched] [source: https://developer.apple.com/videos/play/wwdc2023/10138/]

Verbatim Apple statements:
- "Apple Watch is a timekeeping device best suited for quick and focused interactions."
- "Watch experiences should be highly specialized for brief interactions."
- **"When you only get a few seconds of people's attention, you need to be concise."**
- **"If you had ten seconds of someone's attention, which information would you surface?"**
- "When you're designing your app, try to narrow the focus of the experience to just what's relevant at the time the wearer raises their wrist." (Apple calls this the "Apple Watch Moment.")
- "choose a navigation structure that accomplishes your 'Apple Watch Moment' in as few interactions as possible."
- "Strive to make your detail view so unmistakable at a glance that it doesn't need a title."
- Smart Stack: "With a turn of the digital crown, glanceable widgets spring onto the screen in an intelligently ordered stack… begin by thinking about which information would make the best Smart Stack widget and then design around those relevant and timely experiences to architect your app."

**Apple publishes no hard usage numbers in this session.** I found no WWDC talk with published wrist-raise counts or session-length statistics — treat "Apple has numbers" as unverified.

---

## 3. Habit formation mechanics with real underlying research

### 3.1 Checking habits — the mechanism most directly on-point
[strong: peer-reviewed, Personal & Ubiquitous Computing 2012 — abstract verified via search results; **full text not fetched** (ACM/Springer both 403/paywalled)]
Oulasvirta, Rattenbury, Ma, Raita, "Habits make smartphone use more pervasive," *Pers Ubiquit Comput* 16(1):105–114. [source: https://link.springer.com/article/10.1007/s00779-011-0412-2]
- Defines the **checking habit**: "brief, repetitive inspection of dynamic content quickly accessible on the device."
- "checking behaviors emerge and are reinforced by informational 'rewards' that are very quickly accessible."
- "A typical checking lasts less than 30 seconds and involves opening the screen lock and accessing a single application."
- Controlled field experiment: when the contact book was augmented with **real-time information about contacts' whereabouts**, users started regularly checking it — i.e. adding dynamism to a previously static screen *created* the checking habit.
- Users experienced repetitive habitual use "more as an annoyance than an addiction."

**This is the single strongest citation for the Laso question.** The reinforcer is *dynamic content + near-zero access cost*. Static content does not generate checking habits, no matter how valuable.

### 3.2 Goal-gradient effect
[strong: peer-reviewed, Journal of Marketing Research 2006] — full paper read [source: https://home.uchicago.edu/ourminsky/Goal-Gradient_Illusionary_Goal_Progress.pdf]
Kivetz, Urminsky, Zheng, *JMR* 43(1):39–58.
- Café loyalty field study: **949 completed 10-stamp cards, ~10,000 coffee purchases, 29,076 customer-days.**
- Interpurchase time falls as goal nears: mean difference first vs last interval **0.7 days = 20% acceleration** (t=2.6, p<.05).
- Whole-card effect: actual completion 24.6 days vs 29.4 days at the first-interval rate = **~5 days / 16% faster**.
- **Illusionary progress:** a 12-stamp card pre-stamped with 2 "bonus" stamps completes the same 10 required purchases *faster* than a plain 10-stamp card. Not explained by sunk cost.
- **Post-reward resetting:** effort resets to a lower rate after the reward is earned, then reaccelerates toward the next goal. (Direct warning: a completed ring/goal collapses motivation until a new goal is visible.)
- Stronger acceleration toward the goal **predicts greater retention and faster reengagement** in the program.

### 3.3 Reward uncertainty and dopamine
[strong: peer-reviewed, *Science* 2003] [source: https://pubmed.ncbi.nlm.nih.gov/12649484/]
Fiorillo, Tobler, Schultz, *Science* 299(5614):1898–1902.
- Two distinct dopamine responses: a phasic prediction-error burst, and **a previously unobserved sustained ramp of activity that covaries with uncertainty and grows until the potential reward time.**
- **Uncertainty-related sustained activation is maximal at P = 0.5** and falls off at higher and lower probabilities.
- Authors propose a role in "attention-based learning and risk-taking behavior."

**Applied read:** a score you can already predict (always ~the same) produces no sustained anticipatory signal. A score with genuine ~50/50 uncertainty about which direction it moved produces the strongest anticipatory response. This is the neuroscience under "variable reward" — cite Fiorillo, not Eyal.

### 3.4 Streaks / loss aversion — vendor experimental data
[medium: vendor A/B test data, published by Duolingo] [source: https://blog.duolingo.com/how-streaks-keep-duolingo-learners-committed-to-their-language-goals/]
- **Streak Wager** A/B test: **+14% Day-7 retention**; statistically significant lifts also at Day-1 and Day-14.
- **Weekend Amulet** A/B test: users **4% more likely to return a week later**, **5% less likely to lose their streak**.
- Baseline problem it solves: **DAU drops 5–10% on weekends** vs midweek peak.

[weak: secondary blogs, snippet only, not verifiable to a Duolingo primary source] Claims circulating that "users with 7+ day streaks retain at 2.4×" and "55% monthly DAU retention" appear only in marketing blogs. Do not use these numbers.

### 3.5 Zeigarnik effect — mostly does NOT replicate
[strong: 2025 meta-analysis, *Humanities & Social Sciences Communications* — **snippet only**, nature.com redirected to an auth wall] [source: https://www.nature.com/articles/s41599-025-05000-w]
- Meta-analysis finding: **no memory advantage for unfinished tasks** — the classic Zeigarnik memory effect fails to replicate.
- The **Ovsiankina effect (tendency to resume an interrupted task) is reliable.**

**Do not design on "incomplete things are remembered better."** Design on "incomplete things get resumed." An unfinished ring/bar is a resumption cue, not a memory hook.

### 3.6 Curiosity / information gap
[medium: highly cited theoretical review, abstract-level only] Loewenstein, "The psychology of curiosity," *Psychological Bulletin* 116:75–98 (1994). Curiosity as "cognitively induced deprivation arising from the perception of a gap in knowledge." [source: https://www.scirp.org/reference/referencespapers?referenceid=2828034] — I did not fetch the full paper; treat as framing, not evidence.

---

## 4. Composite scores as an engagement driver

### 4.1 WHOOP — the only first-party engagement definition I could verify
[medium: vendor, Chief Product Officer on record] [source: https://www.houseofkaizen.com/ama/ben-foster-whoop]
WHOOP CPO Ben Foster's engagement benchmark, verbatim structure:
- wear the device **28 of the last 28 days**
- use the app **28 of the last 28 days**
- use specific differentiated features **at least 7 of those 28 days**

Chosen because "(a) they correlate to retention, (b) it's believable that correlation reflects actual causation, and (c) sufficient volume exists to create meaningful business impact." Foster: "Retention is the leading indicator of long-term revenue."
**No churn or retention percentages are disclosed.** WHOOP has published no public retention numbers I could find.

### 4.2 WHOOP recovery score — independent reviewer critique
[medium: detailed first-party review by a domain reviewer] [source: https://www.dcrainmaker.com/2021/11/whoop-platform-review.html]
- Score delivery is a morning ritual: recovery arrives "usually a short bit after you get out of the shower."
- Critique: after 3h15m of jet-lagged sleep he received an **80% recovery score** and "still felt like crap."
- "the singular difference between a green and yellow score is simply keeping my HRV value above 54, everything else be damned."
- "I've consistently found… that it has the least correlation between my actual feelings and what the score says, of most of these devices."

**Risk flag for Laso:** a composite score that visibly contradicts felt state destroys trust, and trust is what makes a score worth glancing at.

### 4.3 Garmin Body Battery
[medium: vendor press data] Garmin 2024 Connect Data Report [source: https://www.stocktitan.net/news/GRMN/the-year-in-review-garmin-releases-2024-garmin-connect-data-9leugldv8330.html]: average Body Battery **71**, average sleep score 71, average stress 30, average training readiness 60, average 8,317 steps/day. **Garmin publishes no feature-level engagement or view-count data.** The report does not state user counts.

[medium: mainstream tech publication] [source: https://www.androidauthority.com/garmin-body-battery-1209128/]: range 1–100 in four tiers (0–25 low, 26–50 medium, 51–75 high, 76–100 very high); drained by stress, poor sleep, alcohol, illness, hard training; recharged by sleep and naps; **resets if the watch is removed for several hours**. Criticisms: requires 24/7 wear, HRV-derived only, misses injury/illness.

### 4.4 No published engagement numbers exist for Oura readiness
Searched; found none. **Unverified — do not claim Oura engagement data.**

---

## 5. Notification cadence — what the trials actually show

### 5.1 Bell et al., JMIR mHealth uHealth 2023;11:e38342 (Drink Less MRT)
[strong: micro-randomized trial, peer-reviewed] — full PDF read [source: https://researchonline.lshtm.ac.uk/id/eprint/4670198/1/Bell-etal-2023-How-notifications-affect-engagement-with.pdf]
- Design: 30-day MRT, **350 users** in the MRT arm (598 randomized total: 350 MRT, 121 standard-notification, 98 no-notification). Daily 8 PM randomization: 30% standard message / 30% new message / 40% no message.
- **Notification → 3.5-fold increase in probability of opening the app in the next hour (95% CI 2.91–4.25).**
- **Only 1.3-fold over a 24-hour window** — the effect is near-term, not day-level.
- **The effect did not change significantly over time** across 30 days (no measured habituation).
- Being "already engaged" that evening reduced the new-notification effect to 0.80× (95% CI 0.55–1.16) — directionally sensible, not significant.
- **Critically: across the three notification policies, time to disengagement was NOT significantly different.** Notifications bought in-the-moment opens, not retention.
- Baseline attrition: **50% of users disengaged by day 22** after download.
- 85% of sessions occurred within the Self-Monitoring & Feedback module; natural usage peak near 8 PM.
- Authors' conclusion: strong near-term effect, "Further optimization is required to improve the long-term engagement."

### 5.2 Bidargaddi et al., JMIR mHealth uHealth 2018;6(11):e10123
[strong: micro-randomized trial, peer-reviewed] [source: https://pmc.ncbi.nlm.nih.gov/articles/PMC6293241/]
- N = **1,255 users**, 50% randomization at each of 6 daily timepoints (8:30am, 12:30pm, 5:30pm, 6:30pm, 7:30pm, 8:30pm).
- Overall: **3.9% more likely to engage in the next 24 hours** (RR 1.039, 95% CI 1.01–1.08, P<.05).
- **Best slot: 12:30pm → 8.8% lift** (90% CI 1.04–1.15). Weekend 12:30pm → 11.8%.
- Weekend effect 8.7% (95% CI 1.01–1.17) vs weekday 2.5% (95% CI 0.98–1.07); difference not significant (P=.18).
- **Effect did not significantly attenuate over the 12-week study (P=.84)** — again no measured fatigue.

**Synthesis [strong]:** across two MRTs, notifications reliably move next-hour engagement (up to 3.5×) but move 24-hour engagement only marginally (1.04–1.3×) and move long-term retention **not at all**. Notification cadence is a poor retention lever. Slot choice (midday, weekends) matters more than volume. Neither trial found habituation within 30 days–12 weeks — so "notification fatigue kills the effect over weeks" is **not supported by these trials**; the failure mode is that the effect was never a retention effect.

---

## 6. What actually kills health-app and watch-app retention

### 6.1 Pratap et al., 100,000-participant cross-study retention analysis
[strong: 8 studies, 109,914 participants, peer-reviewed preprint/npj] — full PDF read [source: https://arxiv.org/pdf/1910.01165]
- Pool: **109,914 participants, >850,000 participant-days, ~3.5M remote health tasks, 2014–2019.**
- **Median engagement in the first 12 weeks: 5.5 days, with in-app tasks performed on only 2 days.**
- Median retention across studies: **2–12 days** (Brighten outlier: 26 days).
- **More than half of participants discontinued within the first week.**
- **Surviving the first 8 days is the whole game: the sub-cohort still engaged at day 8 had median retention +25 days.**
- Engagement clusters (among those with ≥7 days): C1/C2 high users used the app 96.4% and 63.1% of the first 84 days but were only **median 9.5% of participants**. C3 moderate 21.4%, C4 sporadic 22.6% (median 5 days between opens vs 2 for C3). **Abandoners (C5) = median 54.6% of participants, median app usage 1 day.**
- "Only 1 in 10 participants were in the high app use clusters."
- Retention modifiers (P<1e-16): clinician referral **+40 days** (median 44 vs 4 days self-selected); paid compensation **+22 days**; having the clinical condition of interest **+13 vs 6 days**; age 60+ **+4 days**. Gender: no effect (P=.3).
- Task completion concentrates in **evening (4–8 PM) and night (8–12 AM)**.

**Blunt read: >50% churn in week 1, and 1-in-10 become real users. Everything else is second order.**

### 6.2 Wearable device abandonment
[weak: industry survey, snippet only — Gartner press coverage, primary not fetched]
- ~**30% of fitness-tracker owners stop using the device within 6 months**; ~50% of owners eventually stop. [source: https://www.bitdefender.com/en-us/blog/hotforsecurity/a-third-of-wearable-device-owners-quit-using-them-gartner-says] — **unverified**
- Peer-reviewed treatment exists (Attig & Franke, *Computers in Human Behavior*, 2020, "Abandonment of personal quantification") but I could not retrieve the text. [source: https://www.sciencedirect.com/science/article/abs/pii/S0747563219303127] — **unverified**

### 6.3 The Apple Watch app "death spiral"
[medium: reported journalism, page fetched] [source: https://slate.com/technology/2018/04/apple-watch-popular-apps-are-leaving-the-platform-is-that-a-bad-sign.html]
- Instagram, Amazon, Google Maps, Slack, Twitter, TripAdvisor all removed their Apple Watch apps.
- Instagram's stated reason: the WatchKit 1.0 → watchOS 2 SDK migration "wasn't worth the time and resources."
- Amazon and TripAdvisor: the platform "wasn't the right solution for their customers at that point in time."
- **The article cites no engagement metrics at all** — the exits were justified by maintenance cost, not by published usage data.
- Reported conclusion: watch apps work for notifications, fitness tracking and productivity; not for browsing/social consumption.

[weak: opinion pieces, one 403'd] The "death spiral" framing (developers stop maintaining → users stop looking → Apple stops investing) comes from Cult of Mac [source: https://cultofmac.com/572999/fixing-apple-watch-app-death-spiral] — **HTTP 403, could not verify**.

### 6.4 App retention benchmarks
[weak: marketing-vendor blogs, no methodology disclosed] Frequently quoted: all-category D1 ~26%, D7 ~13%, D30 ~7%; fitness apps D1 30–35%, D7 15–18%, D30 8–10%. [source: https://uxcam.com/blog/mobile-app-retention-benchmarks/] **Treat as directional only. There is no credible published watchOS-specific retention benchmark that I could find — flagging that as a real gap.**

---

## 7. "Body Battery style depleting resource" — what the evidence actually supports

**Verdict: the specific claim ("depleting resources create more checking than static scores") is NOT directly tested anywhere I could find. It is an inference. But it is a well-supported inference, assembled from three peer-reviewed pieces:**

1. **[strong] Checking habits require *dynamic* content.** Oulasvirta et al. define the checking habit as "brief, repetitive inspection of **dynamic content**," and their field experiment showed that adding real-time changing information to a previously static app *caused* regular checking to emerge. A once-a-day static score is, by definition, static for 23 hours — it structurally cannot support a checking habit after the first look. A continuously depleting gauge is dynamic on every glance. [source: https://link.springer.com/article/10.1007/s00779-011-0412-2]

2. **[strong] Uncertainty produces sustained anticipatory dopamine, maximal at P=0.5.** Fiorillo et al. found a ramping activation that scales with outcome uncertainty. A score whose current value you cannot predict (because it has been draining unpredictably since you last looked) sits closer to maximal uncertainty than a fixed morning number you already memorized. [source: https://pubmed.ncbi.nlm.nih.gov/12649484/]

3. **[strong] Effort accelerates as perceived distance to a threshold shrinks, and resets after the goal is hit.** Kivetz et al.'s goal-distance model: effort investment is a function of *proportion of original distance remaining*. A gauge falling toward zero is a continuously shrinking goal distance and therefore a continuously strengthening pull. A static score has no gradient at all. Their post-reward resetting result also predicts the failure mode: once the gauge is full (or the ring closed) motivation drops until a new distance is visible. [source: https://home.uchicago.edu/ourminsky/Goal-Gradient_Illusionary_Goal_Progress.pdf]

**Counter-evidence and honest caveats:**
- **[weak: anecdote]** I found no user-behaviour data — Garmin publishes only population averages (avg Body Battery 71), not view counts. Reddit/forum threads about compulsive Body Battery checking did not surface in retrievable form. Treat "people check Body Battery more than they check a static score" as **unverified anecdote**.
- **[medium]** Body Battery resets if the watch is off for hours, and is HRV-derived only [source: https://www.androidauthority.com/garmin-body-battery-1209128/] — the depleting metaphor breaks visibly on imperfect wear, which is a trust risk of the same class DC Rainmaker described for WHOOP recovery.
- **[strong]** The Zeigarnik meta-analysis kills the "unfinished = better remembered" justification. If you argue depletion works because it leaves something "unfinished in memory," that is wrong. The defensible mechanism is **resumption (Ovsiankina) + goal gradient + dynamic content**, not memory. [source: https://www.nature.com/articles/s41599-025-05000-w — snippet only]

---

## 8. Numbers to design against (all verified above)

| Constraint | Number | Source strength |
|---|---|---|
| Design target for one glance | **≤5 s; median session is exactly 5.0 s** | strong |
| Sessions per day to compete for | **142/day** on-wrist | strong |
| Share of glances that are self-initiated | **82.3%** | strong |
| Time to read a bar comparison | **159–285 ms** | strong |
| Time to read a radial/spiral chart | **1548–1772 ms (6–10× worse)** | strong |
| Viewing distance / angle | **28 cm, ~50° off-axis** | strong |
| Notifications that produce any session | **9.4%** | strong |
| Notification lift, next hour | **3.5×** | strong |
| Notification lift, next 24 h | **1.04–1.3×** | strong |
| Notification lift on long-term retention | **none measurable** | strong |
| Best notification slot | **12:30pm; weekends stronger** | strong |
| Health-app users churning in week 1 | **>50%** | strong |
| Health-app users who become heavy users | **~1 in 10** | strong |
| Retention payoff for surviving day 8 | **+25 days median** | strong |
| Streak-mechanic D7 retention lift | **+14%** (Duolingo Streak Wager) | medium |
| Goal-gradient acceleration near goal | **20% faster; 16% faster completion** | strong |

---

## 9. Explicit unverified list
Do not cite these without further work:
- Wristly "60–80 checks/day" Apple Watch figure (2015 self-report; page 403'd).
- Gartner "30% abandon within 6 months" (primary not retrieved).
- Any Oura readiness engagement/retention number (none found).
- Any WHOOP churn/retention percentage (none published).
- Any watchOS-specific app retention benchmark (none found from a credible source).
- Claims that Duolingo streak users "retain 2.4×" or "55% monthly DAU retention" (marketing blogs only).
- Garmin feature-level view counts for Body Battery (never published).
- Apple WWDC talks containing quantitative watch usage data (none found; Apple's guidance is qualitative — "a few seconds", "ten seconds").
- Full text of Oulasvirta 2012 and Loewenstein 1994 (abstract-level only; both paywalled).
- Full text of the 2025 Zeigarnik/Ovsiankina meta-analysis (auth wall; conclusion from search snippet).

**Confidence: 84/100** — every number in sections 1, 3.2, 3.3, 5, 6.1 was read directly from the source PDF or page in this session, so those are solid. The score is held below 90 because: (a) the central "depleting resource drives more checking" claim in section 7 has no direct empirical test anywhere I could find and is an assembled inference, not a measured effect; (b) Oulasvirta 2012, Loewenstein 1994 and the Zeigarnik meta-analysis are abstract/snippet-level only since ACM, Springer and Nature all blocked full-text fetch; (c) the Apple Watch check-frequency figure (60–80/day) and the Gartner abandonment stat could not be verified at source (403 / primary not retrieved); (d) no watchOS-specific retention benchmark exists in anything I could reach, so section 6.4 rests on marketing blogs. | Source: internet

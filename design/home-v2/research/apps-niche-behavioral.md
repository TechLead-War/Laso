# Home / Today Screen Teardown — Niche & Behavioural Health Apps

Research date: 2026-07-29. Every claim below is traceable to a page I fetched or searched in this session; URLs are cited inline. Where I could not verify a detail from a fetched source I mark it `[UNVERIFIED]` rather than stating it as fact.

**Honesty note on method.** I could not install and open eleven apps. What I did was fetch official help docs, company design/engineering blog posts, App Store listings (description + visible reviews + rating counts), and hands-on long-form reviews. So: *element inventory* is well sourced; *exact pixel-perfect vertical order* is reconstructed and is marked `[order reconstructed]` wherever the source did not literally state the sequence. Anywhere a source did state the order, I say so.

---

## 0. The one-paragraph summary before the detail

Every app on this list has made the same core bet in a different currency: **the home screen is not a dashboard, it is a verdict.** The ones that work compress a large, noisy, multi-dimensional data set into one or two human-readable numbers plus one sentence telling you what to do about it. The ones that struggle (Strava, Calm, Eight Sleep post-redesign, Welltory) have let the home screen become a *shelf* — an inventory of everything the product can do — and users describe it as clutter. The single strongest pattern across all eleven: **the number is not the payload, the sentence next to the number is the payload.** RISE's founder said it most plainly: "there's only two things that matter" ([Built In Chicago](https://www.builtinchicago.org/articles/rise-science-app-launch-15m-funding)).

---

# 1. RISE (Rise Science) — the two-number app

## 1.1 Layout

```
┌─────────────────────────────────────┐
│ [date]                    ⚙ profile │
│                                     │
│   SLEEP DEBT                        │
│   ┌───────────────────────────┐     │  ← THE number, hero position
│   │      12h 30m              │     │
│   │  ▓▓▓▓▓▓▓▓░░░░░░  (bar)    │     │
│   └───────────────────────────┘     │
│   "Your sleep debt is high.         │  ← plain-English verdict
│    Aim for 8h 45m tonight."         │
│                                     │
│   ENERGY SCHEDULE                   │  ← THE second number, as a curve
│    ╭─╮      ╭──╮                    │
│   ╱   ╲____╱    ╲___                │
│   │grog│ peak │dip│ peak │wind-down │
│   ▲ now                             │
│                                     │
├──────────── fold ───────────────────┤
│  TODAY'S HABITS  (checklist)        │  ← 16 science-based habits
│  ☐ Get morning light                │
│  ☐ Avoid caffeine after 1:14pm      │
│  ☐ Start winding down at 9:40pm     │
│                                     │
│  [Melatonin window] [Nap window]    │
└─────────────────────────────────────┘
  Home  |  Sleep  |  Energy  |  Tools  |  Guidance
```

Tab structure confirmed by [TapSmart's review](https://www.tapsmart.com/apps/review-rise/) and search results citing the app's Home / Sleep / Energy / Tools / Guidance tabs. Sleep debt as the hero metric plus Energy Potential as the companion score is stated on [risescience.com](https://www.risescience.com/) and in [the app's own positioning](https://apps.apple.com/us/app/rise-sleep-tracker/id1453884781). `[order reconstructed]` for the exact card sequence below the energy curve.

## 1.2 What appears first, and why

**Sleep debt.** A single time value in hours and minutes, not a 0-100 score. The hypothesis for placement is stated almost verbatim by co-founder Jeff Kahn: "what the science very clearly shows is that there's only two things that matter: how much sleep deprivation you have at any given time, and when are you performing with your circadian rhythm" ([Built In Chicago](https://www.builtinchicago.org/articles/rise-science-app-launch-15m-funding)). RISE is built on the two-process model of sleep regulation, so the home screen is literally a UI rendering of a scientific model: process S (homeostatic sleep pressure → sleep debt) on top, process C (circadian rhythm → energy schedule) directly beneath.

The choice of **hours, not a score**, is the sharpest decision in this entire teardown. "12h 30m of sleep debt" is a *unit you already understand and can act on* — you can pay 30 minutes back tonight. "Sleep score 62" is a unit only the app understands. RISE deliberately refused the score abstraction that Eight Sleep, Whoop and Oura all adopted. Their own marketing calls sleep debt "the only sleep score" they emphasise ([risescience.com](https://www.risescience.com/)).

## 1.3 The single engineered action

**Go to bed earlier tonight / start the wind-down now.** Everything on the screen funnels there. The energy curve exists to tell you *when* the wind-down starts; the habit checklist exists to make the wind-down concrete; the sleep debt number exists to tell you *how much* earlier. It is a one-verb product.

## 1.4 Emotion in the first 3 seconds

**Mild, actionable guilt that converts into agency.** "Debt" is a loaded metaphor — it is deliberately an obligation you owe, not a failure you committed. Crucially it is *repayable*, and the app immediately tells you the repayment amount. Compare "sleep score 58/100" which is a judgement with no repayment schedule. So: guilt for ~1 second, agency by second 3. That transition is the whole design.

## 1.5 Progressive disclosure

Sleep stages, individual night graphs, sleep-time consistency, sleep quality trends all live behind the Sleep and Progress tabs ([TapSmart](https://www.tapsmart.com/apps/review-rise/)). Sounds, meditations, smart alarm, brain-dump and the sleep knowledge library live in Tools and Guidance ([App Store listing](https://apps.apple.com/us/app/rise-sleep-tracker/id1453884781)). The home screen carries no history and no charts of the past — only today's obligation and today's schedule.

## 1.6 Deliberate omissions

- **No sleep stages on home.** RISE does not even track stages well; a reviewer flags "RISE isn't a great fit for people who want detailed information about their overall sleep quality" and notes it doesn't break out individual stages like competitors ([Mattress Clarity](https://www.mattressclarity.com/accessories/rise-app-review/)).
- **No 0-100 nightly sleep score.**
- **No social layer, no comparison to other users.**

**Smart call.** REM/deep percentages are the single most-screenshotted, least-actionable numbers in consumer sleep tech. You cannot decide to have more REM. You *can* decide to go to bed 40 minutes earlier. Omitting stages removes the product's biggest source of unactionable anxiety and, conveniently, its biggest accuracy liability. The cost is real: it loses the "quantified self" audience, and the same reviewer's complaint is the receipt.

## 1.7 Strengths (mechanism, not adjectives)

1. **Unit choice as the core UX decision.** Hours:minutes of debt is self-explaining, self-normalising (everyone knows what 2 hours feels like), and directly convertible into tonight's action. No onboarding required to interpret it.
2. **The debt bar is a running balance, not a daily verdict.** A bad night dents a 14-day rolling balance instead of resetting a streak. This structurally prevents the "I blew it, why bother" collapse that daily-score apps produce.
3. **Time-anchored nudges.** The habit list is not "avoid caffeine", it is "avoid caffeine after 1:14pm" — a computed, personal, calendar-able instruction. This is the difference between advice and an instruction.
4. **The energy curve pre-commits the user's day.** By predicting the grogginess window (~90 minutes post-wake, per search results on the energy schedule) and the afternoon dip *before they happen*, RISE converts a symptom into a forecast. Forecasts feel like insight; the same information delivered after the fact feels like an accusation.
5. **Immediate value at install** — it back-computes from historical phone/wearable data rather than requiring two weeks of tracking ([TapSmart](https://www.tapsmart.com/apps/review-rise/)).

## 1.8 Weaknesses (sourced)

- Watch/phone sync of the wake function is unreliable; alarm sound library is thin; no countdown on the watch before wake time — a June 2024 review surfaced on the [App Store listing](https://apps.apple.com/us/app/rise-sleep-tracker/id1453884781).
- Sleep-need estimation is doubted: a reviewer questioned whether the nine-hour recommendation was accurate and suspected the phone mis-detects wake time when she wakes before touching it ([Mattress Clarity](https://www.mattressclarity.com/accessories/rise-app-review/)).
- The data-forward framing repels a chunk of users. The same reviewer, self-described "right-brained", found the numbers approach less appealing than a feelings-based check-in.
- **Structural risk of the debt metaphor:** debt only ever goes up on a bad week. For a chronically under-slept parent or shift worker, the hero number is a permanent red accusation with no achievable floor. I found no source addressing how RISE handles this. `[UNVERIFIED]`

## 1.9 What I would change

Cap the emotional range of the hero number. Show sleep debt *relative to your own last 14 days* ("2h better than your average") rather than as an absolute balance, for users whose absolute debt never clears. Second: the habit checklist below the fold is the actual behaviour-change engine but it is buried — the "next habit due in the next 2 hours" deserves to sit directly under the debt number, and everything else can collapse.

## 1.10 Numbers

- "80% of RISE users feel the benefits within 5 days" — company claim on [risescience.com](https://www.risescience.com/).
- 75,829 ratings and an "Apple Best Apps of 2026" credit on [risescience.com](https://www.risescience.com/); the [US App Store page](https://apps.apple.com/us/app/rise-sleep-tracker/id1453884781) shows 4.7★ from ~63,000 ratings and claims 10M+ users. The gap between the two ratings figures is a storefront-locale artefact, not a contradiction I can resolve.
- 20,000–30,000 installs per week at Series A; $15.5M raised total ($5.5M seed + $10M Series A led by Goodwater) ([Built In Chicago](https://www.builtinchicago.org/articles/rise-science-app-launch-15m-funding)).
- No published before/after retention numbers on home-screen changes. `[UNVERIFIED]`

---

# 2. Gentler Streak — the guilt-free streak

## 2.1 Layout

```
┌─────────────────────────────────────┐
│  "Kudos for Taking Action"          │  ← message ABOVE the chart
│                                     │
│   ACTIVITY PATH                     │
│   ┌───────────────────────────┐     │
│   │        ░░░░░░░░░░░░  over │     │
│   │  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  GREEN│     │  ← optimal band
│   │  ····•·······  you (dots) │     │
│   │        ░░░░░░░░░░░░  under│     │
│   └───────────────────────────┘     │
│   [ Day | 10 days | 30 days ]       │
│                                     │
├──────────── fold ───────────────────┤
│  FOR YOU  (morning ordering)        │  ← customisable stack
│  • Daily Wellbeing Recap            │
│  • Last Night's Sleep (14-night)    │
│  • Go Gentler suggestion  [Start]   │  ← the one action
│  • Menstrual cycle phase            │
│  • Monthly Recap / Insights         │
│                                     │
│  (later in the day, logged          │
│   activities move above For You)    │
└─────────────────────────────────────┘
   Streak  |  ...  |  ...     (3 tabs)
```

Sourced: the Activity Path is "the central visual" on the Streak tab, with a green band = optimal range and a white dotted line = your actual level, and contextual messages such as "Kudos for Taking Action" shown **above** the path ([Gentler Streak docs](https://docs.gentler.app/understanding-your-activity-path/interpret-the-activity-path)). The 2024 redesign cut four tabs to three, put the Streak page "directly below the Activity Path", and made "For You" lead in the morning with logged activities taking over later in the day ([BGR](https://www.bgr.com/tech/gentler-streak-gets-a-major-redesign-focused-on-your-wellbeing/)). Day / 10-day / 30-day path ranges and the wellness widgets (vitals, steps, sleep, cycle) are listed on the [App Store page](https://apps.apple.com/us/app/gentler-streak-workout-tracker/id1576857102).

## 2.2 What appears first, and why

**A sentence, then a band — not a number.** The topmost element is a human message interpreting your position ("Kudos for Taking Action"), and the hero visual is a *range* you sit inside rather than a target you hit or miss. CEO Katarina Lotrič on the 2024 redesign: "if we were launching version 1.0 with what we have today, how would we design it? The answer led us to reimagine the experience – putting everything that matters most right there on the Streak" ([BGR](https://www.bgr.com/tech/gentler-streak-gets-a-major-redesign-focused-on-your-wellbeing/)). Co-founder framing from Apple's Behind the Design: "Statistics are just numbers. Without knowing how to interpret them, they are meaningless. We wanted to change that and focus on the humanity" ([Apple Developer](https://developer.apple.com/news/?id=3m0ht22s)).

**This is the most important single design idea on the whole list.** A band has no failure state. There is no "0/3 rings closed". Being below the band is not failure, it is *capacity* — the docs literally say a low position means "your body is well-rested and can handle a more intense workout if you choose" ([docs](https://docs.gentler.app/understanding-your-activity-path/interpret-the-activity-path)). Being above the band is not victory, it is a warning. The app inverts the entire moral polarity of fitness UI.

## 2.3 The single engineered action

**Tap "Start Workout" on today's Go Gentler suggestion** — a specific workout type, intensity and duration scaled to today's readiness, with a Start button, available even from the Home Screen widget ([Gentler Streak widget docs](https://docs.gentler.app/using-gentler-streak-widgets/overview-of-available-gentler-streak-widgets)). Notably the action is sometimes "rest", and resting still maintains the streak — the App Store copy states streak maintenance "allows rest days without guilt" ([App Store](https://apps.apple.com/us/app/gentler-streak-workout-tracker/id1576857102)).

## 2.4 Emotion in the first 3 seconds

**Calm, then mild pride.** No red, no zeroes, no "you missed". The mascot Yorhart ("your heart") is there to make the app feel like a companion rather than a coach — Apple's piece says it helps users "establish a relationship with the app and with yourself" ([Apple Developer](https://developer.apple.com/news/?id=3m0ht22s)). Soft blues/greens set the tone ([Pixso](https://pixso.net/articles/gentler/)). If anything the risk is the *opposite* of anxiety: insufficient activation energy.

## 2.5 Progressive disclosure

Per-workout detail, heart-rate zones, training effect, weekly/monthly/yearly charts, monthly and yearly recaps, and the 140+ activity types all sit behind taps ([App Store](https://apps.apple.com/us/app/gentler-streak-workout-tracker/id1576857102)). "Sick / Injured / On a Break" statuses that suspend path expectations are set in the profile ([docs](https://docs.gentler.app/personalizing-your-profile/what-happens-when-i-set-my-status-to-sick-injured-or-on-a-br)). The user can also choose which For You cards appear at all — Wellbeing Recap, Sleep, Cycle, Go Gentler, Monthly Recap, Insights ([BGR](https://www.bgr.com/tech/gentler-streak-gets-a-major-redesign-focused-on-your-wellbeing/)).

## 2.6 Deliberate omissions

- **No calorie deficit, no weight, no BMI, no body composition.**
- **No leaderboard, no friends, no comparison to other people.** The Monthly Summary "emphasises individual progression over comparison to others" (Apple Design Awards coverage / Apple's Behind the Design).
- **No "you failed today" state at all.**

**Smart call, and the reason it won a 2024 Apple Design Award for Social Impact** ([Apple Newsroom](https://www.apple.com/newsroom/2024/06/apple-announces-winners-of-the-2024-apple-design-awards/)). The omitted metrics are precisely the ones that drive disordered-exercise behaviour in the target audience (people recovering from burnout and injury — the founders' own origin story per [Apple Developer](https://developer.apple.com/news/?id=3m0ht22s)). Removing them is not a feature gap, it is the product.

## 2.7 Strengths

1. **Range instead of target.** Structurally eliminates the binary pass/fail that every ring-based tracker creates.
2. **The message sits above the chart.** Interpretation precedes data. The user never has to decode the visual to know how they are doing — a rare inversion; almost every health app puts the chart first and the caption below.
3. **Rest counts as compliance.** The streak survives a rest day, so the streak stops being an anxiety generator and becomes a consistency record.
4. **The one recommended action is pre-scaled.** "Go Gentler" gives type + intensity + duration, so decision cost is near zero.
5. **Time-of-day reordering.** Morning shows guidance; after a logged workout the screen shows the workout. Same screen, two jobs, no user configuration.

## 2.8 Weaknesses (sourced, real reviews)

From reviews visible on the [App Store listing](https://apps.apple.com/us/app/gentler-streak-workout-tracker/id1576857102):
- **Effort mis-estimation for non-cardio.** "Every yoga class… registers as extremely light" even with real exertion, forcing manual RPE correction — which means the Activity Path, the hero visual, is wrong for whole categories of exercise. For a product whose entire promise is "don't overtrain", a systematically low reading is the worst possible failure mode.
- **Steps don't count toward the streak** despite being available, so users manually log walks as workouts to keep the picture honest.
- **Sleep data desync**: "Insufficient data" appears after editing sleep records in another app.
- Strength training suffers the same calibration problem as yoga (difficulty without heart-rate correlation).
- Paywall: monthly $8.99 / yearly $39.99 / lifetime $89.99+, free tier reduced to a homepage progress bar and widgets — a thin free home screen.

## 2.9 What I would change

The Activity Path is beautiful and *ambiguous*: a dotted line inside a band tells you where you are but not what changed since yesterday. I would add a one-line delta ("+18% vs your usual Tuesday") because "am I trending" is the question users actually bring. Second, self-reported RPE should be requested proactively for activity types the heart-rate model is known to underread (yoga, strength) instead of waiting for the user to discover the correction UI — the complaint above is a design failure, not a user failure.

## 2.10 Numbers

- 4.7★ from ~8,800 ratings; Editors' Choice ([App Store](https://apps.apple.com/us/app/gentler-streak-workout-tracker/id1576857102)).
- 2022 Apple Watch App of the Year; 2024 Apple Design Award, Social Impact ([Apple Newsroom](https://www.apple.com/newsroom/2024/06/apple-announces-winners-of-the-2024-apple-design-awards/)).
- The redesign rationale explicitly cites a discovery problem — many users "weren't discovering the app's full functionality previously" ([BGR](https://www.bgr.com/tech/gentler-streak-gets-a-major-redesign-focused-on-your-wellbeing/)). No published retention lift. `[UNVERIFIED]`

---

# 3. Levels (CGM) — turning a curve into a grade

## 3.1 Layout

```
┌─────────────────────────────────────┐
│  Current glucose         98 mg/dL   │  ← live value, top
│                                     │
│   GLUCOSE TIMELINE (today)          │
│    ╱╲      ╱╲                       │
│   ╱  ╲____╱  ╲___                   │  ← meals overlaid on the curve
│   🍳     🥗      🍝                  │
│                                     │
│   Avg glucose  |  Stability  | Spike│  ← 3-up metric strip
│      101       |     87      | 42m  │
│                                     │
│   TODAY'S 3 GOALS                   │
│   ☐ 12 hours of glucose stability   │
│   ☐ One stable meal                 │
│   ☐ One healthy habit               │
│                                     │
├──────────── fold ───────────────────┤
│   RECENT MEALS (Zone / meal scores) │
│   Oatmeal + berries          8/10   │
│   Pasta                      4/10   │
│                                     │
│   [+ Log food]  (AI photo logging)  │
└─────────────────────────────────────┘
```

Sourced: "Your home screen shows your current glucose level (once your sensor is connected), recent meals, and key insights" ([Levels support](https://support.levels.com/article/723-how-to-download-and-set-up-the-levels-app)). The hands-on review states the home screen shows "your average glucose, stability score, and spike duration" with "a three-item daily checklist featuring 12 hours of glucose stability, one stable meal, and one healthy habit like exercise or good sleep" ([Sterp / PowerMoves](https://sterp.com/reviews/levels-health)). The dashboard "shows your day as a glucose timeline with meals overlaid, making cause-and-effect relationships immediately obvious" ([BetterVitals](https://www.bettervitals.com/learn/levels-health-review)). `[order reconstructed]` for the exact sequence of the strip vs the checklist.

## 3.2 What appears first, and why

**The live glucose number and the day's curve.** The hypothesis is *causality visibility*: CGM's unique value is that the curve moves within 20 minutes of eating, so putting the timeline with meal markers on top makes the cause-effect loop the first thing you see. Everything else on the screen is a compression of that same curve.

The **Stability Score** is the interesting move: it is not a raw statistic but a graded one, running **60 to 100 "functioning similarly to letter grades"**, computed from standard deviation of glucose around a rolling four-hour baseline, with the guidance "aim for 85 or higher on most days" and >90 "above average" ([Levels support](https://support.levels.com/article/266-about-the-stability-score-feature)). Meals are scored 0-10 ([App Store description](https://apps.apple.com/us/app/levels-metabolic-health/id1481511675); [BetterVitals](https://www.bettervitals.com/learn/levels-health-review)).

Note the **floor at 60**. Levels deliberately made the worst possible score a D-minus, not a zero. That is an anxiety-management decision baked into the scale itself.

## 3.3 The single engineered action

**Log a meal** (now via AI photo capture). Every score on the screen is unattainable without logged meals — meal scores are, in the reviewer's words, "the main reason to pay for Levels over the free Stelo app" ([Sterp](https://sterp.com/reviews/levels-health)). The three-item checklist exists to make logging feel like progress rather than data entry.

## 3.4 Emotion in the first 3 seconds

**Curiosity, with a fast slide into anxiety.** A moving line about your own blood is inherently fascinating. The graded score then converts fascination into performance pressure. The ZOE reviewer's experience (§10) generalises to all food-scoring apps: "It's easy to become a bit too interested in your own measurements" ([Griffen Fitness](https://www.griffenfitness.com/blog/an-honest-review-of-zoe)).

## 3.5 Progressive disclosure

Zone comparison between meals, the daily report card (time in zone, best/worst meal), lab results, exercise correlation, and AI coaching all sit behind taps or arrive as an emailed morning report ([App Store](https://apps.apple.com/us/app/levels-metabolic-health/id1481511675); [BetterVitals](https://www.bettervitals.com/learn/levels-health-review)).

## 3.6 Deliberate omissions

- **No calories on the home screen** (calorie estimates exist in AI logging but are unreliable, per [Sterp](https://sterp.com/reviews/levels-health)).
- **No macros, no weight.**
- **No comparison to other users.**

**Smart call.** A CGM app that also counted calories would collapse into MyFitnessPal and lose its only differentiator. Staying single-signal is why the metabolic score reads as authoritative.

## 3.7 Strengths

1. **The 60-100 floored scale.** Scores that cannot reach zero cannot produce total-failure affect. Under-used trick industry-wide.
2. **Score + curve on the same screen.** The score is auditable — you can see the spike that caused it. Scores without their evidence breed distrust; this pairing pre-empts it.
3. **A three-item checklist, not a ten-item one.** The reviewer explicitly says this quantity "feels balanced without creating excessive app notifications" ([Sterp](https://sterp.com/reviews/levels-health)).
4. **Exercise-induced spikes are excluded from the score when marked strenuous** ([Levels support](https://support.levels.com/article/266-about-the-stability-score-feature)) — the scoring model refuses to punish healthy behaviour that happens to move the metric the "wrong" way. This is a scoring-integrity decision most apps get wrong.

## 3.8 Weaknesses (sourced)

- **Two-hour scoring window.** Dinner spikes that arrive at hour three never update the meal score, so the headline number is wrong exactly when it matters most ([Sterp](https://sterp.com/reviews/levels-health)).
- **"Mega zones."** Meals logged close together merge into one 6-hour zone and "the score is basically useless because it's averaging your glucose response across your entire afternoon" ([Sterp](https://sterp.com/reviews/levels-health)).
- From reviews visible on the [App Store listing](https://apps.apple.com/us/app/levels-metabolic-health/id1481511675): "75% of the time I have to close the app and reopen it to get it to sync"; the sync control is buried in settings rather than the main interface ("not intuitive or user friendly"); in-app articles were removed; and an AI-expert reviewer called the AI coach a "liability" that "gives bad advice" and sometimes analyses the wrong data.
- 4.7★ from ~6,600 ratings ([App Store](https://apps.apple.com/us/app/levels-metabolic-health/id1481511675)).

## 3.9 What I would change

Never show a score that is still provisional. A meal score inside its 2-hour window should render as "measuring…" with a partial curve, and finalise later. Shipping a confident wrong number is worse than shipping no number. Second: the sync state belongs on the home screen as a visible freshness stamp ("data as of 2 min ago"), because a stale glucose value on a CGM home screen is a safety-adjacent failure, not a cosmetic one.

## 3.10 Numbers

- Meal scores 0-10; Stability Score 60-100; target ≥85; typical non-diabetic excursion 26-28 mg/dL, avoid >30 mg/dL rise ([Levels support](https://support.levels.com/article/266-about-the-stability-score-feature)).
- No published engagement deltas from home-screen changes. `[UNVERIFIED]`

---

# 4. Eight Sleep — the score that got demoted

## 4.1 Layout (post-2024/25 redesign)

```
┌─────────────────────────────────────┐
│  Good morning, Ayush                │
│                                     │
│  ┌───────────────────────────────┐  │
│  │ AI SLEEP SUMMARY (paragraph)  │  │  ← the contested element
│  │ "You slept 7h12m with lower   │  │
│  │  than usual deep sleep…"      │  │
│  └───────────────────────────────┘  │
│                                     │
│   SLEEP FITNESS SCORE      82       │  ← demoted below the paragraph
│   Time asleep 7h12m  |  HRV 48      │
│                                     │
│   ⚠ Pod needs priming               │  ← maintenance alerts
│                                     │
├──────────── fold ───────────────────┤
│   SHORTCUTS                         │
│   [Temperature]  [Routines]         │
│   [Sleep report] [Health report]    │
│                                     │
│   Personalised insights / education │
│   (varies by time of day)           │
└─────────────────────────────────────┘
   Home  |  Routines  |  ...
```

Sourced: the home screen "acts as a bird's eye view to everything in the app" with "shortcuts for easy access to services you use most such as temperature controls, routines, and sleep and health reports", plus a new maintenance alert system for priming/refilling/connectivity, and content "personalized to match your profile and even the time of day that you're in" ([Eight Sleep blog](https://www.eightsleep.com/blog/the-all-new-eight-sleep-app-is-simpler-easier-and-more-powerful-than-ever/)). The AI paragraph sitting *above* the score is from the hands-on reviewer: "the first thing users see upon waking" is an AI-generated sleep summary paragraph, with "the sleep fitness score and key metrics like HRV" below it ([Sterp](https://sterp.com/reviews/eight-sleep)).

## 4.2 What appears first, and why

**An AI-written paragraph about last night.** The hypothesis is that a narrative explains better than a number — the same bet Strava made with Athlete Intelligence. The reviewer's verdict on that bet is brutal: "I don't know who thought anyone wanted to read that with their eyes half open" ([Sterp](https://sterp.com/reviews/eight-sleep)). Users report they "just want their sleep score and HRV visible."

This is the clearest natural experiment on the whole list: **a company moved its hero number below a paragraph of prose, and users noticed and objected.** Reading is a high-effort act at 6:45am. A number is a glance.

## 4.3 The single engineered action

Ambiguous, and that is the problem. The redesign optimises for **navigating to a shortcut** (temperature, routines, reports) rather than for a single behaviour. The commercial action is really "keep the subscription", and the home screen is a value-demonstration surface. Contrast RISE, where the action is unambiguous.

## 4.4 Emotion in the first 3 seconds

**Anxiety-then-effort.** A score you did not control (you were asleep) plus a paragraph you must read while half-conscious. Sleep scores are uniquely anxiety-producing because the behaviour being graded already happened and cannot be redone.

## 4.5 Progressive disclosure

Sleep stages, heart rate, HRV, breath rate, snoring duration, latency, bedtime consistency, and week/month/6-month trends all live in the sleep report ([App Store](https://apps.apple.com/us/app/eight-sleep/id1086913845)). Autopilot's reasoning is largely hidden.

## 4.6 Deliberate omissions

The Sleep Fitness Score is composed of only three factors — Sleep Quality, Sleep Routine, Time Slept — on a 0-100 scale with 90+ Excellent, 70-89 Good, <70 Needs improvement ([Eight Sleep](https://www.eightsleep.com/blog/sleep-fitness-score/)). Everything else (HRV, snoring, breath rate) is *measured but excluded from the headline*. Eight Sleep's own rationale: a single score makes sleep "not only measurable, but also actionable and achievable."

**Smart in principle, undermined in execution** — they built a clean three-factor score and then buried it under prose.

## 4.7 Strengths

1. **A genuinely simple score definition.** Three components, published thresholds, plain names. Most sleep scores are black boxes.
2. **Maintenance alerts on home.** Hardware products fail silently; surfacing "needs priming" on the home screen prevents the worst churn driver (device quietly stops working).
3. **Time-of-day personalisation** — evening shows routines/temperature, morning shows last night.
4. **2x faster load** after backend work; accuracy claims of 93% (sleep) and 99% (heart rate) against gold standard ([Eight Sleep blog](https://www.eightsleep.com/blog/the-all-new-eight-sleep-app-is-simpler-easier-and-more-powerful-than-ever/)).

## 4.8 Weaknesses (sourced)

- **Redesign fatigue.** "Redesigned five times in the last four years" and the current version is "the one I like the least"; the reviewer objects to relearning the interface annually ([Sterp](https://sterp.com/reviews/eight-sleep)).
- **AI paragraph above the score** — see above.
- From reviews on the [App Store listing](https://apps.apple.com/us/app/eight-sleep/id1086913845): alarm off/snooze buttons "way too small"; "Stop Tracking" hard to find on waking; temperature on one page and session-end on another; the End Session flow fails to close nap sessions without an app restart; no way to hide unused features.
- 4.8★ from ~17,000 ratings ([App Store](https://apps.apple.com/us/app/eight-sleep/id1086913845)).

## 4.9 What I would change

Put the score back on top and turn the AI paragraph into **one sentence, max twelve words**, directly under it. Narrative is not wrong — length is wrong for 6:45am. Second: stop redesigning. The single loudest complaint is not about any layout, it is about layouts *changing*. Home-screen stability has compounding value that no individual improvement outweighs.

## 4.10 Numbers

- Sleep Fitness Score bands 90-100 / 70-89 / <70 ([Eight Sleep](https://www.eightsleep.com/blog/sleep-fitness-score/)).
- 2x load-speed improvement; 93% / 99% accuracy claims ([Eight Sleep blog](https://www.eightsleep.com/blog/the-all-new-eight-sleep-app-is-simpler-easier-and-more-powerful-than-ever/)).
- No published retention effect of the redesign. `[UNVERIFIED]`

---

# 5. Welltory — three percentages and a coloured heart

## 5.1 Layout

```
┌─────────────────────────────────────┐
│  (background tinted GREEN/YELLOW/RED│  ← the whole screen is the signal
│   by your Health score)             │
│                                     │
│        ♥  HEALTH   78%              │  ← top element, per help docs
│        "Your body is coping well"   │
│                                     │
│   BATTERY        62%   ▓▓▓▓▓░░░     │  ← energy, all-day
│   STRESS         41%                │
│                                     │
│   [ ▶ Take a measurement ]          │  ← the action (camera / watch)
│                                     │
├──────────── fold ───────────────────┤
│   Sleep Analysis           →        │
│   Activity Report          →        │
│   Workout Report           →        │
│   Today's Longevity Goal            │
└─────────────────────────────────────┘
```

Sourced: the Today Screen "helps you track important metrics such as Health, Battery, and Stress"; Health is at the very top and its coloured heart "changes the background of the main screen"; from Today you go to Sleep Analysis, Activity Report and Workout Report ([Welltory help — Today Screen](https://help.welltory.com/en/articles/8907642-today-screen)). Definitions: Battery accounts for sleep, heart rate and everything you do all day; Stress shows how well you balance activity and rest (sedentary time *raises* Stress, movement lowers it); Health compares all your HRV measurements against your personal baseline and people like you (Welltory help centre, surfaced in search). "Today's Longevity Goal" appears in the [App Store description](https://apps.apple.com/us/app/welltory-health-heart-rate/id1074367771).

## 5.2 What appears first, and why

**A colour, before any number.** The background tint means the verdict is delivered pre-attentively — you know if today is green before you have read a digit. That is faster than any number can be. The Health percentage and its sentence follow.

## 5.3 The single engineered action

**Take a 60-second HRV measurement** (phone camera, Apple Watch, Samsung Watch, or HR monitor). The company's own framing of the loop: "connect your data sources once and come back for short, regular measurements" ([Welltory help — overview](https://help.welltory.com/en/articles/3352351-overview-of-the-welltory-app)). Reviewers call it "a check-in app for your body" ([Neura Health](https://neura.health/insight/welltory-app-hands-on-review)).

## 5.4 Emotion in the first 3 seconds

**Curiosity when green, anxiety when red.** A full-screen red tint is a strong affective stimulus and the user has no immediate remedy — HRV is not something you can fix in the next ten minutes. This is the highest-variance emotional design on the list.

## 5.5 Progressive disclosure

Eight distinct reports sit behind the Today screen: Battery, Stress, Sleep, Activity, Health, Heartbeat, Workout, Blood Pressure ([Welltory help — overview](https://help.welltory.com/en/articles/3352351-overview-of-the-welltory-app)). The Heartbeat report holds raw HRV metrics with interpretation. Today's HRV vs Average HRV splits "now" from "trend".

## 5.6 Deliberate omissions

Raw HRV in milliseconds is not the hero — percentages are. Welltory omits the number that HRV nerds actually want, and replaces it with a normalised 0-100% comparison against your own baseline and a matched cohort.

**Smart.** Raw RMSSD is meaningless without a personal baseline and is wildly variable; percentages against your own history are the only interpretable form. The cost is credibility with the quantified-self audience, and the app hedges by keeping raw metrics one tap away.

## 5.7 Strengths

1. **Colour as the primary channel, number as secondary.** Fastest possible comprehension.
2. **"Battery" as a metaphor.** Everyone knows what 20% battery means and what to do about it. This is the same trick as RISE's "debt" — borrow a mental model the user already owns rather than teaching a new one.
3. **A named, single action button** on the home screen; the app has one verb.
4. **Stress defined counter-intuitively** (sedentary raises it, movement lowers it) is a genuine insight that reframes a passive day as a stressor.

## 5.8 Weaknesses (sourced)

- "Can feel a little overwhelming" with excessive data presentation; lacks adaptive plans, programming, nutrition — a specialised tool, not a platform ([Neura Health](https://neura.health/insight/welltory-app-hands-on-review)).
- Three simultaneous percentages (Health, Battery, Stress) that all move independently is *two too many*. Users have no rule for which to obey when they disagree. This is the design's central flaw, and it is the exact opposite of the RISE approach. `[UNVERIFIED as a user complaint — this is my analysis, not a sourced quote]`
- I could not retrieve Reddit threads this session (reddit.com is not fetchable by this agent), so the negative-sentiment corpus for Welltory is thinner than for the other apps. `[UNVERIFIED]`
- 4.7★ from ~131,000 ratings ([App Store](https://apps.apple.com/us/app/welltory-health-heart-rate/id1074367771)).

## 5.9 What I would change

Pick one hero. Health, Battery and Stress are three views of the same autonomic state; promote whichever is most decision-relevant right now and demote the other two to a single line. Second: never tint the whole screen red without an accompanying achievable action — an unactionable red screen is pure anxiety generation.

## 5.10 Numbers

- 4.7★, ~131,000 ratings ([App Store](https://apps.apple.com/us/app/welltory-health-heart-rate/id1074367771)); HRV backed by "20,000+ studies" per the same listing.
- No published home-screen engagement data. `[UNVERIFIED]`

---

# 6. Human — two different apps, one great idea

**Ambiguity flagged.** "Human" maps to two products. I cover both, because the historical one is the more instructive design.

## 6a. Human — Activity Tracker (Mapbox), the "Daily 30"

```
┌─────────────────────────────────────┐
│                                     │
│         ╭───────────╮               │
│        │             │              │
│        │    24 min   │  ← ONE ring, │
│        │   of your   │    ONE goal  │
│        │   Daily 30  │              │
│         ╰───────────╯               │
│                                     │
│   walk 18m · run 6m · bike 0m       │
│                                     │
│   Your city: 34% hit their Daily 30 │
│   Map of your movement              │
└─────────────────────────────────────┘
```

The product: a passive tracker "with a simple goal: move every day for 30 minutes or more, dubbed the 'Daily 30'" ([TechCrunch on the Mapbox acquisition](https://techcrunch.com/2016/08/18/mapbox-is-acquiring-passive-fitness-tracking-app-human/); [MobiHealthNews](https://www.mobihealthnews.com/content/open-source-mapping-company-mapbox-acquires-passive-fitness-app-maker-human-its-anonymized)). It counted **active minutes, not steps** — "Human speaks your language—they don't count steps but show active minutes" — auto-detected walks, runs and bike rides, and compared you against your city ([BlessThisStuff](https://www.blessthisstuff.com/stuff/technology/apps/human-app/); search results on the app's positioning). Mapbox acquired it in August 2016 largely for anonymised movement data.

**Why it matters even though it is dead:** it is the purest example on this list of a home screen that is *one goal, one unit, one visual*. Zero configuration, zero logging, zero score. The action it engineered was "go outside now" and it needed no words to say so. Every ring-based tracker since (including Apple's Move ring) is downstream of this idea.

**The weakness that killed the category:** one binary goal has a hard failure state. At 11pm with 12 of 30 minutes, the screen is an accusation and the only response is to give up. Gentler Streak's band is the direct correction to Human's ring. `[The link between the two is my analysis, not a sourced claim.]`

I could not verify the app's current availability — `human.co` does not resolve and appadvice.com did not resolve this session. Treat as discontinued/unmaintained. `[UNVERIFIED]`

## 6b. Human Health: Chronic Illness (live, 2026)

```
┌─────────────────────────────────────┐
│  Today, 29 Jul                      │
│  ┌───────────────────────────────┐  │
│  │  DAILY SYMPTOM SURVEY  [Start]│  │  ← the one action
│  └───────────────────────────────┘  │
│  PINNED INSIGHTS                    │  ← user-chosen, kept on top
│   Fatigue ▁▂▄▆▅▃  ↓ better this wk  │
│   Naltrexone · day 34               │
│                                     │
├──────────── fold ───────────────────┤
│   Recent logs / timeline            │
│   [+ Log symptom]  [+ Add treatment]│
│   Trends  ·  PDF report for doctor  │
└─────────────────────────────────────┘
```

Sourced: 2,000+ loggable symptoms, medication/supplement/therapy tracking, PDF reports for clinicians, multiple profiles, photo-based medication scanning, built with UCSF and Stanford researchers, 300,000+ users, 4.6★ from 363 ratings ([App Store](https://apps.apple.com/us/app/human-health-chronic-illness/id1628460004)). The streamlined daily symptom survey and the "Pinned Insights" feature that keeps chosen symptoms and treatments "front and center" come from the app's own release notes surfaced in search. `[order reconstructed]`

- **First element / why:** the daily survey. For chronic illness, the product is worthless without today's entry, so the home screen is a data-collection prompt before it is a data-display surface.
- **Engineered action:** complete today's survey.
- **Emotion:** neutral-to-obligation. Deliberately flat affect — no score, no grade, no colour verdict. For chronic illness this is correct: these users do not need another thing telling them they are unwell.
- **Hidden:** correlations, trends, full timeline, report generation.
- **Omitted:** any wellness score. Smart — a "health score" for someone with a chronic condition is an insult with a number attached.
- **Strength:** *Pinned Insights* is the best idea here — the user, not the algorithm, decides what stays above the fold. For a population whose relevant metric differs person to person, user-pinning beats any recommender.
- **Weakness:** requested features from reviewers include calendar view, multi-symptom timestamping, and dedicated BP/blood-sugar fields ([App Store](https://apps.apple.com/us/app/human-health-chronic-illness/id1628460004)) — i.e. the home screen currently makes rapid, repeated, timestamped logging harder than it should be.
- **Change:** put the *last three things you logged* as one-tap repeat buttons on home. Repeat-logging is the dominant action in chronic tracking and it should be a single tap, not a survey.

---

# 7. Strava — the home screen that forgot the user

## 7.1 Layout

```
┌─────────────────────────────────────┐
│  Strava            🔍  💬  🔔       │
│  ┌───────────────────────────────┐  │
│  │  streak / promo strip (new)   │  │  ← whatever Strava is pushing
│  └───────────────────────────────┘  │
│                                     │
│  ┌───────────────────────────────┐  │
│  │ [avatar] Priya · Morning Run  │  │  ← SOMEONE ELSE'S activity
│  │  10.2 km · 4:58/km · map      │  │
│  │  👍 24 kudos    💬 3          │  │
│  └───────────────────────────────┘  │
│  ┌───────────────────────────────┐  │
│  │ [avatar] Sam · Ride           │  │
│  └───────────────────────────────┘  │
│              …infinite scroll…      │
└─────────────────────────────────────┘
  Home  |  Maps  |  ⏺ Record  |  Groups  |  You
```

Sourced: the redesign replaced the old navigation with **Home, Maps, Record, Groups, You**; Home replaced Feed and shows activities from people you follow; all personal data moved to the new You tab ([Velo](https://velo.outsideonline.com/road/road-racing/new-strava-update-makes-big-changes-to-layout-organization-and-navigation/)). Feed ordering offers Personalized or Latest Activities; favourited athletes float toward the top "regardless of which feed order option you've chosen"; your own activity feed and club feeds are always chronological ([Strava help — Feed Ordering](https://support.strava.com/en-us/articles/15402105-feed-ordering)). A new strip at the top of the Home feed showing a streak feature is reported in the Strava community hub (surfaced in search; the thread itself returned 403 to my fetch). Athlete Intelligence appears "alongside activity details" after an upload, not on the Home feed ([Strava press](https://press.strava.com/articles/stravas-athlete-intelligence-translates-workout-data-into-simple-and)).

## 7.2 What appears first, and why

**Another person's workout.** The hypothesis is social obligation: seeing peers move is a stronger activation cue than seeing your own numbers, and giving kudos creates reciprocal obligation that pulls the recipient back. Strava's data supports the retention half of this: "athletes logging group activities are more likely to remain active 12 months later than those doing solo activities only", and large-group activities attract up to 95% more kudos ([SQ Magazine, citing Strava](https://sqmagazine.co.uk/strava-statistics/)).

## 7.3 The single engineered action

**Give kudos.** One tap, zero cost, generates a notification for someone else, who returns to the app. 14 billion kudos were given in 2025 ([Strava Year in Sport, via SQ Magazine](https://sqmagazine.co.uk/strava-statistics/)).

## 7.4 Emotion in the first 3 seconds

**Comparison — pride or inadequacy depending on your week.** This is the only app on the list whose home screen emotion is set by *other people's* behaviour, and therefore the only one the product cannot control.

## 7.5 Progressive disclosure

Everything personal is one tab away: your activities, training insights, progress, goals, fitness data ([Velo](https://velo.outsideonline.com/road/road-racing/new-strava-update-makes-big-changes-to-layout-organization-and-navigation/)). Athlete Intelligence, segments, KOM/QOM, Local Legend, challenges and clubs are all deeper still.

## 7.6 Deliberate omissions

**Your own weekly stats are not on the Home tab.** A design critique states this explicitly: "personal metrics are buried in the 'You' tab rather than Home, forcing users to learn Strava's specific model", and notes the label "Home" signals a social-media conceptual model that conflicts with fitness apps like Garmin where Home means personal performance ([Pratt IXD design critique, Feb 2026](https://ixd.prattsi.org/2026/02/design-critique-strava-ios-app-3/)).

**Dumb call for a health product; rational for a social network.** Strava has decided it is a social network. The consequence is that a user who opens the app to answer "how am I doing?" — the number-one reason to open a health app — is answered with "here is what Priya did."

## 7.7 Strengths

1. **Kudos is the cheapest possible reciprocity loop.** One tap → a notification → a return visit. No content creation required from either party.
2. **Favourited-athlete pinning** overrides the ranking algorithm, preserving the relationships that actually drive retention ([Strava help](https://support.strava.com/en-us/articles/15402105-feed-ordering)).
3. **A persistent Record button** in the tab bar makes the money action always one tap away — and it works: a redesigned Record experience "increased mobile activity session starts by 19%" in Jul-Sep 2025 ([SQ Magazine](https://sqmagazine.co.uk/strava-statistics/)).
4. **Segment/Local Legend leaderboards are local**, so most users can plausibly win something.

## 7.8 Weaknesses (sourced)

- **Record button is dead weight for watch users** and adds cognitive load; the You tab is redundantly reachable from both the tab bar and the top-left avatar; Strava recalculates watch distances (5.00 km → 4.97 km), creating a "gulf of evaluation" between devices; activities default to public ([Pratt IXD critique](https://ixd.prattsi.org/2026/02/design-critique-strava-ios-app-3/)).
- **Feature-pushing at the top of Home.** Community feedback reports Strava "wants to promote new features by constantly pushing them to the top and pushing old features down in the Home tab and You tab" (Strava community hub, surfaced in search; thread 403'd on fetch).
- **Athlete Intelligence was mocked on launch** — users called it a waste of engineering, said it "really [does] nothing except getting in the way", and reported it confusing a bicycle with a gondola (Strava community hub threads + [Velo](https://velo.outsideonline.com/road/road-gear/strava-missteps/) headline "How Strava Traded User Goodwill for Nothing"; the Velo article itself is paywalled behind an auth redirect so I could only verify the framing, not the body). `[PARTIALLY UNVERIFIED]`
- Kudos notifications stack badly — "if you got 20 kudos… only the most recent person pops up" ([App Store reviews](https://apps.apple.com/us/app/strava-run-bike-hike/id426826309)).
- 4.8★ from ~365,000 ratings ([App Store](https://apps.apple.com/us/app/strava-run-bike-hike/id426826309)); 125M+ athletes, 10B+ uploads ([Strava press](https://press.strava.com/articles/stravas-athlete-intelligence-translates-workout-data-into-simple-and)); ~51M activities uploaded per week, 61% of sessions tracked by phone not wearable ([SQ Magazine](https://sqmagazine.co.uk/strava-statistics/)).

## 7.9 What I would change

Put **one** personal line at the top of Home — "3 activities, 24 km this week, 8 km ahead of last week" — above the feed. It costs one row, answers the question the user actually arrived with, and does not damage the social loop below it. Second: stop using the top of Home as a feature-marketing slot; that slot is the most valuable real estate in the product and spending it on promos is why the goodwill complaints exist.

## 7.10 Numbers

- 19% increase in mobile activity session starts after the Record redesign, Jul-Sep 2025 ([SQ Magazine](https://sqmagazine.co.uk/strava-statistics/)) — the only clean home-adjacent A/B-style number I found on this entire list.
- 14 billion kudos in 2025; up to 95% more kudos on large-group activities; group loggers more likely to still be active 12 months later; 55% of Gen Z cite social connection as their top reason for joining a group ([SQ Magazine](https://sqmagazine.co.uk/strava-statistics/), citing Strava Year in Sport).
- Cross-industry: apps with social streaks average 5.69-day streaks vs 4.25 without (+34%); users completing hardest-tier achievements retain at 74.2% vs 32.3% for easiest — note these are **Trophy's platform-wide numbers, not Strava's** ([Trophy](https://trophy.so/blog/strava-gamification-case-study)).

---

# 8. Headspace — one daily action, wrapped in a shop

## 8.1 Layout

```
┌─────────────────────────────────────┐
│  Good morning, Ayush      🔥 12     │  ← run streak
│  Favorites  ·  Recents              │  ← top of Today tab
│                                     │
│  DAILY ESSENTIALS                   │
│  ┌───────────────────────────────┐  │
│  │ Today's Meditation      10m ▶ │  │  ← THE action, counts to streak
│  └───────────────────────────────┘  │
│  ┌───────────────────────────────┐  │
│  │ The Wake Up (video)        ▶  │  │
│  └───────────────────────────────┘  │
│                                     │
│  START YOUR DAY / AFTERNOON LIFT /  │  ← time-of-day rows
│  WIND DOWN AT NIGHT                 │
│                                     │
├──────────── fold ───────────────────┤
│  Mindful Moments · Community Story  │
│  Recent sessions & courses          │
│  Sleepcasts · Focus music · Move    │
└─────────────────────────────────────┘
  Today | Meditate | Sleep | Move | Focus
```

Sourced: the Today tab is the first tab and the app's default landing screen; content is categorised by time of day with suggestions for "starting your day, getting an afternoon lift, and winding down at night"; Favorites and Recents sit at the top; Today's Meditation lives under "Daily Essentials" and counts toward the run streak; Today mode also contains The Wake Up, Mindful Moments, recent sessions/courses and a Community Story (Headspace help centre articles — my direct fetches returned 403, so these are from search-surfaced help-centre content, corroborated by [Android Authority](https://www.androidauthority.com/headspace-app-2746501/), which confirms the Today tab defaults and the five tabs Today / Meditate / Sleep / Move / Focus).

## 8.2 What appears first, and why

**The streak counter and Today's Meditation.** The hypothesis is habit-loop maintenance: the streak is the loss-aversion trigger, and the single named session immediately below it is the zero-decision action. Note that only meditation counts toward the streak — "sleepcasts, workouts, videos, and The Wake Up don't count" ([Android Authority](https://www.androidauthority.com/headspace-app-2746501/)). That is a deliberate scarcity decision: it keeps the streak meaningful and channels users into the one behaviour the product is actually about.

## 8.3 The single engineered action

**Press play on Today's Meditation.** Same session for everyone, same day, no choosing. Choice is the enemy of a daily habit and Headspace removes it.

## 8.4 Emotion in the first 3 seconds

**Warm and mildly obligated.** The visual language is "aggressively colorful" with a "pulsating orange blob and other smiling shapes" ([Android Authority](https://www.androidauthority.com/headspace-app-2746501/)) — cartoon friendliness that pre-empts the intimidation new meditators feel. The streak adds a light tug.

## 8.5 Progressive disclosure

500+ meditations, courses, sleepcasts, soundscapes, breathwork, mindful movement, therapy and coaching all live behind the other four tabs ([App Store](https://apps.apple.com/us/app/headspace-meditation-sleep/id493145008)). Stats (total minutes, streak, sessions, average length) sit in the profile, not on Today ([Android Authority](https://www.androidauthority.com/headspace-app-2746501/)).

## 8.6 Deliberate omissions

- **No library grid on Today.** The catalogue is deliberately not the home screen.
- **Badges are non-shareable by design** — "users can see their badges and feel like they have achieved something for themselves, not for their peers" — and the leaderboard is a "no leaders" board where you can only see which buddies used the app today ([StriveCloud](https://www.strivecloud.io/blog/headspace-gamification-features)).

**Very smart.** Removing social comparison from a mental-health product removes the mechanism most likely to harm the exact users it serves, while keeping the accountability benefit. This is the sharpest single decision in the meditation category.

## 8.7 Strengths

1. **One session, chosen for you, every day.** Decision cost ≈ 0.
2. **Streak restricted to the core behaviour**, so the streak cannot be farmed with low-value content.
3. **Time-of-day rows** turn a static catalogue into a schedule.
4. **Non-competitive gamification** (private badges, no-leader leaderboard).
5. **5-screen onboarding with a progress bar**, explicitly designed to reduce cognitive load and reach the "aha" fast ([StriveCloud](https://www.strivecloud.io/blog/headspace-gamification-features)).

## 8.8 Weaknesses (sourced)

- Below Daily Essentials the Today tab becomes a content merchandising surface (Mindful Moments, Community Story, recents, courses, plus therapy and coaching upsells), which dilutes the single-action clarity of the top.
- The whimsical art style is polarising ([Android Authority](https://www.androidauthority.com/headspace-app-2746501/)).
- Visible App Store reviews are mostly feature requests (shuffle sleepcasts, rewind, AirPlay, longer walking tracks) rather than home-screen complaints ([App Store](https://apps.apple.com/us/app/headspace-meditation-sleep/id493145008)) — I did not find substantiated home-screen-clutter complaints for Headspace, and I am not going to invent them. `[UNVERIFIED]`
- Category-wide the numbers are brutal: reported Day-1 / Day-7 / Day-30 retention of 27% / 11% / 4.7% for Headspace and 31% / 14% / 5.2% for Calm, against a mobile-app average of ~25% Day 1 and 5.6% Day 30 ([Pauso, citing Sensor Tower / data.ai / Statista 2024](https://www.pauso.com/blog/meditation-app-retention-rates)). **Treat these as third-party estimates, not company-published figures.**

## 8.9 What I would change

Cap Today at three cards above the fold: streak, today's session, and one contextual nudge. Everything else moves below a visible divider. The top of Today is currently doing habit formation *and* catalogue merchandising, and merchandising always wins that fight over time.

## 8.10 Numbers

- 2.8M paying subscribers; 105M cumulative downloads (2026); 2,700+ corporate partners ([StriveCloud, citing Business of Apps and Headspace](https://www.strivecloud.io/blog/headspace-gamification-features)). 30M+ users per [Android Authority](https://www.androidauthority.com/headspace-app-2746501/). 4.8★ from ~974,000 ratings ([App Store](https://apps.apple.com/us/app/headspace-meditation-sleep/id493145008)).
- Retention estimates above. Claims that "users who meditate 10 consecutive days have significantly higher 6-month retention" and "users are 2.3x more likely to continue with streak-based gamification" appeared in search results attributed to Headspace/Calm and to gamification vendors respectively — **I could not trace either to a primary source and both should be treated as marketing claims.** `[UNVERIFIED]`

---

# 9. Calm — the home screen as a mood, not a metric

## 9.1 Layout

```
┌─────────────────────────────────────┐
│ 👤                              ⚙   │  ← account icon, top-left
│                                     │
│   [ LOOPING NATURE VIDEO fills      │
│     the entire screen; swipe to     │  ← the "scene", ambient audio
│     change scene; ambience follows ]│
│                                     │
│   ┌───────────────────────────────┐ │
│   │  DAILY CALM      10 min    ▶  │ │  ← the one daily action
│   └───────────────────────────────┘ │
│                                     │
├──────────── fold ───────────────────┤
│   Featured  ·  Sleep Stories        │  ← card rows
│   Celebrity narrators               │
│   Daily Trip · Daily Jay            │
│   Music · Soundscapes · Kids        │
└─────────────────────────────────────┘
  Home | Meditate | Sleep | Music | More
```

Sourced: the home screen "is dominated by a series of looping nature videos that users can swipe through", changing the scene changes "the app's entire background and ambient soundscape"; navigation is "a handful of icons centered at the bottom" with account info "through an icon at top left"; Music, Meditate and Sleep present content in a card-based layout ([DesignRush](https://www.designrush.com/best-designs/apps/calm)). Content order per a UX review: ambient atmosphere → scene customisation → mood-based recommendations → featured content → celebrity-narrated stories → kids content ([User Journeys](https://www.userjourneys.blog/blog/calm)). Daily Calm, Daily Trip, Daily Jay, streaks and mindful-minutes tracking are in the [App Store description](https://apps.apple.com/us/app/calm-sleep-meditation/id571800810). `[order reconstructed]` for the exact position of the Daily Calm card relative to the scene.

## 9.2 What appears first, and why

**Not information — atmosphere.** Calm is the only app on this list whose first impression is deliberately *non-informational*. The hypothesis: for an anxiety product, the first three seconds must lower arousal, and any number would raise it. The state change is the product; the content library is the delivery mechanism.

## 9.3 The single engineered action

**Play the Daily Calm** — one new 10-minute themed session per day, the app's most popular feature. Same structural bet as Headspace: one dated item, no choosing.

## 9.4 Emotion in the first 3 seconds

**Calm, by construction.** Full-bleed motion video plus ambient audio (cricket sounds are noted in the review) is a direct physiological intervention before any cognitive processing occurs.

## 9.5 Progressive disclosure

The library (guided meditations by topic, Sleep Stories with celebrity narrators, breathwork, music, soundscapes, stretching, 7- and 21-day programmes) sits behind the tabs and below the fold ([App Store](https://apps.apple.com/us/app/calm-sleep-meditation/id571800810)).

## 9.6 Deliberate omissions

**No score, no streak in hero position, no data visualisation of any kind.** Streaks and mindful minutes exist but are relegated to progress tracking rather than the top of home.

**Smart for anxiety, weak for retention.** With no metric, there is no re-engagement hook other than the daily content itself and push notifications — and the category's Day-30 retention (~5.2% for Calm, per [Pauso](https://www.pauso.com/blog/meditation-app-retention-rates)) suggests content alone does not hold people.

## 9.7 Strengths

1. **Personalisable scene = ownership with zero configuration cost.** One swipe makes the app "yours"; both the visual and the soundscape change together, which is a surprisingly strong retention primitive for a product with no numbers.
2. **The daily item is dated**, so it expires — scarcity without gamification.
3. **Intent captured at onboarding** ("What brings you to Calm?"), which the reviewer credits as good intent-gathering and personalisation signalling ([User Journeys](https://www.userjourneys.blog/blog/calm)).

## 9.8 Weaknesses (sourced)

- **Aggressive onboarding monetisation**: notification permission requested before value is understood, then tracking permission, then a premium offer — creating "a stressful environment that contradicts Calm's core purpose"; pricing is inconsistent, with discounts that vanish later in the same session; premium content cannot be previewed at all ([User Journeys](https://www.userjourneys.blog/blog/calm)).
- **Content buried by ordering**: celebrity-narrated stories (high appeal) sit below general featured content, and kids content is several rows down and "significantly underutilized" ([User Journeys](https://www.userjourneys.blog/blog/calm)).
- **Streaks read as hollow**: "a shallow attempt at gamification without providing real value or motivation" ([User Journeys](https://www.userjourneys.blog/blog/calm)).
- **Navigation/discovery**: users report too many categories and difficulty finding content quickly; Calm has itself acknowledged that search "hasn't been great" and has been overhauling it with personalised results and category/time filters (Calm's own blog and coverage, surfaced in search).
- 4.8★ from ~2,000,000 ratings ([App Store](https://apps.apple.com/us/app/calm-sleep-meditation/id571800810)) — no home-screen complaints were visible in the reviews I could see.

## 9.9 What I would change

Give the home screen exactly one piece of information: **"you've meditated 4 of the last 7 days"** — a soft, non-binary consistency signal that cannot be broken. Calm currently has no reason-to-return other than content, and content is commoditised. Second: move the paywall behind the first completed session; asking for money before the product has produced its one effect is the highest-cost mistake in the funnel.

## 9.10 Numbers

- Day-1 / Day-7 / Day-30 of 31% / 14% / 5.2% (third-party estimate, [Pauso](https://www.pauso.com/blog/meditation-app-retention-rates)).
- 4.8★ / ~2M ratings ([App Store](https://apps.apple.com/us/app/calm-sleep-meditation/id571800810)).
- No published home-screen A/B results. `[UNVERIFIED]`

---

# 10. ZOE — the food scoreboard

## 10.1 Layout

```
┌─────────────────────────────────────┐
│  Today                    🔥 streak │
│                                     │
│   TODAY'S SCORE                     │
│      ┌─────────────┐                │
│      │     68      │  ← 0-100       │
│      └─────────────┘                │
│   "Add fibre to your next meal"     │
│                                     │
│   [ 📷 Log a meal ]  [ 🔍 Scan ]    │  ← the action
│                                     │
│   TODAY'S MEALS                     │
│    Porridge + berries        82     │
│    Sandwich                  41     │
│                                     │
├──────────── fold ───────────────────┤
│   Processed Food Risk Scale info    │
│   Habit / plant-diversity progress  │
│   Coaching content, recipes         │
└─────────────────────────────────────┘
```

Sourced: barcode scanning reveals a Processed Food Risk Scale score; photo logging gives instant health scoring; the app shows "visual meal scores, streaks, and progress monitoring", food risk scores on a 0-100 scale, and swap/fibre/variety recommendations ([App Store](https://apps.apple.com/us/app/zoe-health-ai-meal-tracker/id1471632228)). Meals scored 0-100 with "good" starting around 50 confirmed by a hands-on reviewer who scored 40 ("poor") ([Griffen Fitness](https://www.griffenfitness.com/blog/an-honest-review-of-zoe)). September 2025: the kit was reduced to gut-microbiome only, dropping the CGM and blood-fat tests, with an AI-powered app rebuild ([Which? and Home Cooks coverage, surfaced in search](https://home-cooks.co.uk/pages/review-zoe)). `[order reconstructed]`

## 10.2 What appears first, and why

**A score, then a logging button.** ZOE's entire commercial premise is that food quality, personalised to your biology, beats calorie counting — so the home screen must show a *quality* verdict, not an energy total. The score is the product's differentiator rendered as a number.

## 10.3 The single engineered action

**Photo-log a meal or scan a barcode.** Logging is easier than in the previous version — "logging your meals is definitely easier, with an AI camera that is pretty accurate" (Home Cooks / Which? coverage).

## 10.4 Emotion in the first 3 seconds

**Judgement.** Of everything on this list, ZOE produces the most explicitly moral first impression: your food, graded. A reviewer said outright she was not "a fan of points systems / grading when it comes to food", and separately reported becoming "chained to a smartphone" checking readings every two minutes and that "it's easy to become a bit too interested in your own measurements" ([Griffen Fitness](https://www.griffenfitness.com/blog/an-honest-review-of-zoe)).

## 10.5 Progressive disclosure

Microbiome results, the 4-week eating plan, recipes, nutritionist consultations and the detail behind the Processed Food Risk Scale all sit deeper ([LeafSnap](https://leafsnap.com/zoe-health-review/); [App Store](https://apps.apple.com/us/app/zoe-health-ai-meal-tracker/id1471632228)).

## 10.6 Deliberate omissions

**No calories and no macros anywhere.** A reviewer complains: "there's absolutely nothing else: no calorie counts, no nutritional information" ([App Store review](https://apps.apple.com/us/app/zoe-health-ai-meal-tracker/id1471632228)).

**Brave and correct, but under-defended.** Omitting calories is the entire brand thesis. The failure is that ZOE did not *earn* the omission on-screen — the score's methodology is withheld, so users are asked to trust an opaque number instead of a familiar one. A reviewer found the grading "somewhat arbitrary and poorly explained" ([Griffen Fitness](https://www.griffenfitness.com/blog/an-honest-review-of-zoe)), and concerns about withheld scoring methodology surfaced repeatedly in 2025 coverage.

## 10.7 Strengths

1. **A single quality score replaces four confusing numbers** (calories, carbs, fat, protein) with one.
2. **Barcode scanning in-store** moves the intervention to the decision moment, not the post-hoc review. That is the highest-leverage placement possible for a nutrition product.
3. **Positive framing on the recommendations** — add fibre, add variety, swap — rather than restrict/remove.

## 10.8 Weaknesses (sourced)

- **Opaque scoring** → distrust ([Griffen Fitness](https://www.griffenfitness.com/blog/an-honest-review-of-zoe); 2025 coverage on withheld methodology).
- **Obsessive-checking risk** self-reported by a reviewer ([Griffen Fitness](https://www.griffenfitness.com/blog/an-honest-review-of-zoe)).
- **Logging fatigue**: the same reviewer became "bored" and unmotivated by week two, finding constant logging exhausting without ongoing feedback.
- **Reliability**: food tracking "often failed to function properly after app updates", the recipe builder is frustrating, and some users "gave up on using the Zoe app altogether due to poor reliability" ([LeafSnap](https://leafsnap.com/zoe-health-review/)); duplicate entries, recipe-saving failures, AI food-recognition errors and a limited database were reported through 2025.
- **Personalisation gap**: recommendations "often resemble generic nutrition advice" ([LeafSnap](https://leafsnap.com/zoe-health-review/)).
- Subscription/billing failures: "I've hit the resubscribe button… every day for a week. Nothing. No response." ([App Store review](https://apps.apple.com/us/app/zoe-health-ai-meal-tracker/id1471632228)).
- 4.8★ from ~6,800 ratings; 18+ age rating ([App Store](https://apps.apple.com/us/app/zoe-health-ai-meal-tracker/id1471632228)). ZOE overall sits at 4.0/5 on Trustpilot from 13,000+ reviews (Trustpilot, surfaced in search).

## 10.9 What I would change

Show the *reason* alongside the score inline — "68 · low fibre, high processing" — so the number is self-explaining and the user never has to trust a black box. Second: kill the daily aggregate score. A per-meal score is a decision aid; a daily total score is a verdict on your day with no remaining action, and it is what turns food tracking into food anxiety.

## 10.10 Numbers

- Meal/food scores 0-100 with "good" from ~50 ([Griffen Fitness](https://www.griffenfitness.com/blog/an-honest-review-of-zoe)).
- Sept 2025 kit simplification to gut-only + AI app (search-surfaced coverage).
- No published engagement effects of the app rebuild. `[UNVERIFIED]`

---

# 11. Bearable — the home screen as a form

## 11.1 Layout

```
┌─────────────────────────────────────┐
│  Wed 29 Jul                    ✏️   │
│                                     │
│   MOOD           😞 😐 🙂 😀 😁     │  ← first, one tap
│   SYMPTOMS       [+ add]  pain 0-10 │
│   SLEEP          quality / duration │
│   ENERGY         morning midday eve │
│   Health data (Apple Health, auto)  │
│   Caffeine · smoking · time outside │
│   Habits (custom)                   │
│   Activities (by category)          │
│   Nutrition · water                 │
│   Gratitude                         │
│                                     │
│   [ Edit what appears here ]        │  ← user controls the whole screen
├──────────── fold ───────────────────┤
│   Calendar · Yearly pixel view      │
└─────────────────────────────────────┘
  Today | Insights | Calendar | More
```

Sourced order (this one *is* stated top-to-bottom): date at top, then mood → symptoms with pain levels → sleep → energy/productivity/motivation/focus → auto-populated health data → lifestyle factors (caffeine, smoking, time outdoors) → custom behavioural patterns → activities → nutrition, plus a Gratitude section and access to calendar, yearly pixel view and stats ([Apps Review Nest](https://appsreviewnest.com/app-review/bearable-app-best-symptom-tracker/)). The App Store describes it as "a consolidated daily entry sheet where users scroll through sections", and the edit function at the bottom of the home screen lets you add or remove trackers ([App Store](https://apps.apple.com/us/app/bearable-symptom-tracker/id1482581097); ChoosingTherapy review surfaced in search).

## 11.2 What appears first, and why

**Mood, as a five-emoji tap.** The lowest-friction possible first interaction — one tap, no typing, no thinking — placed first to start the entry momentum. Classic form design: open with the easiest field.

## 11.3 The single engineered action

**Complete today's entry.** Bearable's home screen is not a dashboard at all; it is an input form that happens to be the landing screen. Everything the product sells (correlations between habits and symptoms) requires the entry.

## 11.4 Emotion in the first 3 seconds

**Neutral obligation, tilting to burden.** No score, no colour verdict, no judgement — appropriate for chronic illness. But a long scrolling form is intrinsically demanding, and reviewers say so.

## 11.5 Progressive disclosure

Correlations, trends, advanced graphs and statistics (most premium-gated) live on the Insights tab; calendar and yearly pixel views are separate; doctor-ready export is deeper still ([App Store](https://apps.apple.com/us/app/bearable-symptom-tracker/id1482581097)).

## 11.6 Deliberate omissions

**No health score, no streak, no gamification on the home screen.** For a population managing IBS, PoTS, PCOS, EDS, migraine and mood disorders ([App Store](https://apps.apple.com/us/app/bearable-symptom-tracker/id1482581097)), a "wellness score" would be actively harmful, and a broken streak would punish people for being too unwell to log.

**Correct, and the most defensible omission on this list.**

## 11.7 Strengths

1. **The user configures their own home screen.** In a domain where the relevant variables differ per person, letting people delete the trackers they do not need is the only workable personalisation.
2. **Mood-first ordering** minimises activation energy.
3. **Auto-populated Apple Health / Fitbit fields** reduce the form's length without reducing the data.
4. **The output is a PDF a doctor will read** — an unusually concrete payoff for tracking, and the reason people tolerate the burden.

## 11.8 Weaknesses (sourced)

- **Overwhelm at onboarding**: "Bearable lets you track so many different things that it can be really easy to get overwhelmed when you first start with the app" (ChoosingTherapy review, surfaced in search; direct fetch 403'd).
- **Stability**: users report the app "will suddenly freeze, force quit, or will become very laggy as they are tracking their day" (same source). For a form-first product, a crash mid-entry destroys the day's data and the habit.
- **No quantities**: "You can't log specific amounts (like 5 cups of coffee)" ([Apps Review Nest](https://appsreviewnest.com/app-review/bearable-app-best-symptom-tracker/)) — which caps the quality of the correlations that are the product's whole point.
- **Most useful analysis is paywalled**; free users see limited insights.
- 4.8★ from 6,000+ ratings; 900,000+ users ([App Store](https://apps.apple.com/us/app/bearable-symptom-tracker/id1482581097)).

## 11.9 What I would change

Ship a 15-second "quick log" as the default home state — mood, top 3 pinned symptoms, energy — with the full form one tap away. The current design optimises for completeness on day 1 and loses people by day 10. Second: hard-guarantee entry persistence (write on every field change, not on save) — a form-first app that loses entries on a crash loses the user permanently.

## 11.10 Numbers

- 900,000+ users; 4.8★ from 6,000+ ratings ([App Store](https://apps.apple.com/us/app/bearable-symptom-tracker/id1482581097)).
- No published engagement effects of home-screen changes. `[UNVERIFIED]`

---

# 12. Cross-app synthesis

## 12.1 The four home-screen archetypes found

| Archetype | Apps | First element | Emotion | Risk |
|---|---|---|---|---|
| **Verdict** (one number + one sentence) | RISE, Levels, Eight Sleep, ZOE, Welltory | A score/quantity | Anxiety → agency, or anxiety → paralysis | Unactionable red state |
| **Range** (a band you sit inside) | Gentler Streak | A message + a band | Calm / pride | Too little activation |
| **Mood** (no information at all) | Calm | Atmosphere | Calm | No reason to return |
| **Form** (input before output) | Bearable, Human Health | A field to fill | Obligation | Logging fatigue |

Strava is the outlier: **Social**, where the first element is another person. It is the only one where the emotion produced is outside the product's control.

## 12.2 The unit is the design

The strongest home screens borrow a unit the user already owns:

- **debt** in hours (RISE) — repayable
- **battery** in % (Welltory) — depletable and rechargeable
- **a path with a green band** (Gentler Streak) — spatial, no failure state
- **a letter-grade-like 60-100** (Levels) — floored, never zero
- **active minutes toward 30** (Human) — the purest, and the most brittle

The weakest borrow nothing: "Sleep Fitness Score 82", "ZOE score 68". These require the app to teach a scale before the number means anything, and the teaching never sticks.

## 12.3 Where the "one number" apps put the sentence

RISE, Gentler Streak and Welltory all pair the number with a plain-English instruction. Gentler Streak goes furthest and puts the sentence **above** the visual. Eight Sleep went furthest in the wrong direction and put a *paragraph* above the number — and got called out for it ([Sterp](https://sterp.com/reviews/eight-sleep)). The lesson is not "prose bad"; it is **one sentence good, one paragraph bad, at the moment of first glance.**

## 12.4 The anti-guilt playbook, assembled

1. Floor the score above zero (Levels, 60-100).
2. Use a range, not a target (Gentler Streak).
3. Make rest count as compliance (Gentler Streak).
4. Use a rolling balance, not a daily reset (RISE sleep debt over 14 days).
5. Restrict the streak to the one core behaviour so it stays meaningful, and never show it as a big red zero (Headspace).
6. Make badges private and leaderboards leader-less (Headspace).
7. Never show a verdict without a next action attached.
8. Omit the metrics that drive disordered behaviour entirely — calories, weight, REM% (Gentler Streak, RISE, Bearable).

## 12.5 The single most cited failure mode

Not ugliness, not slowness — **the home screen becoming a shelf.** Strava pushing new features to the top of Home. Calm burying its best content six rows down. Eight Sleep making Home a "bird's eye view to everything in the app". Welltory showing three competing percentages. In every case the mechanism is identical: the home screen was reassigned from *answering the user's question* to *advertising the product's surface area*, and users noticed.

## 12.6 Frequency of redesign is itself a UX property

The loudest single complaint I found in this entire teardown was not about any particular layout: "redesigned five times in the last four years… the one I like the least" ([Sterp on Eight Sleep](https://sterp.com/reviews/eight-sleep)). Home-screen muscle memory compounds. Any redesign must beat not just the old design but the old design *plus* the accumulated familiarity.

---

# 13. Sources

Fetched this session:
risescience.com · apps.apple.com (RISE, Gentler Streak, Eight Sleep, ZOE, Bearable, Headspace, Welltory, Levels, Human Health, Calm, Strava) · developer.apple.com Behind the Design · sketch.com/blog/gentler-streak · pixso.net/articles/gentler · docs.gentler.app (index + Interpret the Activity Path) · bgr.com Gentler Streak redesign · help.welltory.com (Today Screen, Overview) · neura.health Welltory review · support.levels.com (Stability Score, app setup) · sterp.com/reviews/levels-health · sterp.com/reviews/eight-sleep · bettervitals.com Levels review · eightsleep.com blog (new app, Sleep Fitness Score) · support.strava.com Feed Ordering · press.strava.com Athlete Intelligence · velo.outsideonline.com Strava layout update · ixd.prattsi.org Strava design critique · sqmagazine.co.uk Strava statistics · trophy.so Strava gamification · androidauthority.com Headspace · strivecloud.io Headspace gamification · pauso.com meditation retention · designrush.com Calm · userjourneys.blog Calm · tapsmart.com RISE review · mattressclarity.com RISE review · builtinchicago.org Rise Science funding · appsreviewnest.com Bearable · leafsnap.com ZOE · griffenfitness.com ZOE · home-cooks.co.uk ZOE · blessthisstuff.com Human app

Searched but not fetchable (403 / paywall / DNS): help.headspace.com Today tab articles · levels.com/blog/zone-and-meal-scores · communityhub.strava.com threads · justuseapp.com review pages · choosingtherapy.com Bearable review · screensdesign.com/showcase/calm · velo.outsideonline.com Strava missteps (auth wall) · human.co · appadvice.com · reddit.com (blocked to this agent entirely)

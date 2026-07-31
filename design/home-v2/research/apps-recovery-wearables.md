# Home / Today Screen Teardown — Recovery-Score Wearable Apps

**Scope:** Whoop, Oura, Ultrahuman Ring Air, Athlytic, Bevel, Garmin Connect.
**Date of research:** 29 July 2026. All claims traceable to a page fetched or a search result this session; anything I could not verify is tagged `[UNVERIFIED]`.

**Method note and honesty warning.** I cannot install these apps and screenshot them. Everything below comes from company blogs, press releases, App Store listings, independent long-form reviews, forum threads and design critiques that I actually fetched. Three vendor domains (`whoop.com`, `support.whoop.com`, `businessofapps.com`, `nbcnews.com`) returned HTTP 403 to my fetcher, so for those I used search-engine extracts of the same pages plus third-party reviews that quote them. Where the layout order comes from a reviewer's prose rather than a screenshot inventory, I say so. Nothing here is invented.

---

## 0. The one-paragraph summary before the detail

Every one of these six apps has converged on the same skeleton: **a small fixed row or cluster of 2-4 composite scores pinned to the very top, then an infinite scroll of secondary cards below it.** The differentiation is no longer *what* is on the home screen — it is (a) how many scores are in the top cluster, (b) whether the app tells you *why* the number moved, and (c) whether the screen produces a decision or just a feeling. Whoop and Oura have both, in the last 12 months, moved *toward* each other: Whoop went from swipeable tabs to a single dense scroll with three dials on top (Oct 2025); Oura went from a time-of-day-morphing single column to a three-tab app with a score row on top (Oct 2025). Garmin, the laggard, shipped a Whoop-style four-stat "Essentials" row in July 2026 — an explicit copy of the pattern.

---

## 1. WHOOP

### Sources fetched
- https://www.925studios.co/blog/whoop-design-breakdown (fetched — full UI teardown)
- https://the5krunner.com/2023/03/28/new-whoop-home-screen-looks-pretty-but-is-it-as-intuitive/ (fetched)
- https://the5krunner.com/2025/10/15/whoop-homescreen-gets-a-revamp/ (fetched)
- https://the5krunner.com/2025/10/31/2026-whoop-5-0-mg-review-discount-accuracy-strain-recovery-athletes/ (fetched)
- https://apps.apple.com/us/app/whoop/id933944389 (fetched — description + reviews)
- https://www.techgearlab.com/reviews/health-fitness/fitness-tracker/whoop-5-0 (fetched)
- https://www.community.whoop.com/t/whoop-stuck-at-red-recovery/5293 (fetched)
- https://techcrunch.com/2026/03/27/whoop-has-lebron-now-it-wants-your-mom/ (fetched — engagement numbers)
- https://www.whoop.com/us/en/thelocker/the-all-new-whoop-home-screen/ (403 — used search extract)

### 1.1 Vertical order, top to bottom

```
┌─────────────────────────────────────────────┐
│  [avatar]      WHOOP        [battery %]     │  ← thin status strip
├─────────────────────────────────────────────┤
│                                             │
│   ( SLEEP )    ( RECOVERY )    ( STRAIN )   │  ← THREE DIALS (Oct-2025)
│     87%           74%            12.4       │     tap = deep-dive page
│                                             │     tap trend = 1w/1m/6m
├─────────────────────────────────────────────┤
│  Stress Monitor   │   Health Monitor        │  ← 2 more widgets, clickable
├─────────────────────────────────────────────┤  ══ fold on a 6.1" phone ══
│  MY DAY                                     │
│   Daily Outlook (AI text, morning)          │
│   activity / sleep entries as they happen   │
├─────────────────────────────────────────────┤
│  MY PLAN                                    │
│   Weekly Plan — targets that auto-adjust    │
├─────────────────────────────────────────────┤
│  MY DASHBOARD (customisable)                │
│   Strain vs Recovery weekly chart, HRV,     │
│   RHR, respiratory rate, skin temp …        │
├─────────────────────────────────────────────┤
│ [Home] [Health] [ + ] [Community] [Coach]   │  ← bottom nav; '+' centre,
└─────────────────────────────────────────────┘     Coach far right
```

- The three-dial row is confirmed by Whoop's own copy: "three new separate dials at the top of the Home screen reflect the primary metrics core to WHOOP: Sleep, Recovery, and Strain, each with dedicated deep dive pages" and "customize views to show one-week, one-month, or six-month trends for each metric with a single tap" (whoop.com locker post, via search extract — page itself 403).
- The five-widget + three-section structure is from the5krunner's 2026 MG review, fetched: the home tab contains "Strain, Recovery, Sleep, and the Stress and Health Monitors — all clickable for deeper insights", and below these appear "My Day, My Plan, and My Dashboard, the latter of which is customisable."
- The Oct 2025 revamp moved Whoop "from a layout that used multiple tabs (swipe left and right) to a more dense, scrollable home page" (the5krunner, 15 Oct 2025). In the same post: the Action button `+` is "more prominent and placed centrally", and the Coach button sits "in the right-hand corner of the bottom menu bar". Note the5krunner criticised both button placements and Whoop shipped a fix **overnight** — "Imagine my annoyance this morning when the new app version changed the two aspects I had just criticised." That is a tell about their release cadence and their willingness to move nav furniture fast.

### 1.2 What appears FIRST, and why

Sleep is leftmost, Recovery is centre, Strain is right. That is a **temporal narrative order**: last night → this morning's verdict → today's budget. Recovery in the centre position gets the optical centre of the screen and is the number the entire brand is built on. My hypothesis for the ordering: Whoop is not ranking by importance, it is ranking by *causality* — you read left to right and the sentence is "you slept X, therefore you recovered Y, therefore you may spend Z."

The 925studios teardown puts a number on the typographic weight: the Recovery figure renders at "approximately 72-point equivalent typography… readable from arm's length", while supporting text stays "small and secondary."

### 1.3 The single action the screen is engineered to produce

**Open the app again later.** Not a workout, not a log. The dials are all *read* affordances; the only *write* affordance is the `+` button. Whoop's business model is a subscription with no hardware margin, so the screen is tuned for daily habit, not for task completion. Evidence: 83% of monthly active users open the app on any given day, "a ratio that Ahmed says trails only WhatsApp" (TechCrunch, 27 Mar 2026, fetched). A screen designed to produce a task would not need to be opened 7 days a week.

Secondary engineered action: **tap a dial**, which is the entry to the three-tier disclosure funnel and to Coach.

### 1.4 Emotion in the first 3 seconds

**Verdict-anxiety, then either pride or guilt.** Whoop's own colour vocabulary is a moral one: green 67-99%, yellow 34-66%, red 1-33%. There is no neutral state. 925studios: "Every hue carries meaning" and the system "repeats across every screen, which means users learn the visual language once." Learning it once means the emotional reaction is instant and pre-verbal — you feel the colour before you read the number.

The community thread I fetched shows the failure mode plainly. Users describe notifications of the form "your HRV dropped by 16% so your recovery is yellow or red", and complain that "WHOOP flags every small HRV drop as a big problem" and "seems to overweight HRV dips compared to Oura, without factoring in long-term adaptation or trends." The emotion produced there is not calm — it is being scolded by a device.

### 1.5 Hidden behind taps (progressive disclosure)

925studios describes an explicit three-tier model:
- **Tier 1** — the overview dials. "no graphs, no charts, no noise."
- **Tier 2** — trend views, week-over-week charts, reached by tapping a tile.
- **Tier 3** — deep-dive graphs: "HRV trends, resting heart rate over 30 days, respiratory rate fluctuations, skin temperature deltas", built "for the 15% of users who want to correlate specific metrics."

Also behind taps: the *reason* for today's score. The recovery contributors (HRV, RHR, respiratory rate, sleep performance, skin temp, SpO2) are not on the home screen — you tap into Recovery, or you ask Coach. Whoop's own framing: "A member checking Recovery can ask why their score dipped and see how sleep consistency and strain contributed."

### 1.6 Deliberately omitted

- **No raw HRV number on the home dial.** Smart. HRV in milliseconds is meaningless without a personal baseline and inviting comparison across users is a known harm.
- **No delta vs yesterday on the dial itself.** The dial shows today's percentage; the trend toggle (1w/1m/6m) is the delta mechanism, and it is one tap away. I think this is **half-smart**: suppressing "-9 vs yesterday" reduces day-to-day whiplash, but it also removes the single cheapest explanation of why the number feels wrong. Users who "feel fine" and see 41% get no immediate "you slept 52 min less" line.
- **No step count as a hero.** Deliberate — Whoop rejects steps as a metric. Smart for their positioning, and it is one of the few genuinely differentiated omissions in the category.
- **Historical data on cancellation.** 925studios names this as a UX failure: "Cancel your WHOOP subscription and you lose access to all historical data."

### 1.7 Strengths — the actual mechanism

1. **Compression as the product.** 925studios: the design's job is transforming "dozens of biometric signals to one Recovery score." The home screen is the compression made visible. There is exactly one number you must understand.
2. **A three-colour vocabulary reused on every screen.** The user learns it once and never re-learns. This is why Whoop can afford a dense scroll below the fold — the colour semantics carry the load, so the density never has to be parsed cognitively, only scanned chromatically.
3. **Dark canvas as a functional choice, not a style choice.** Black backgrounds make "colored data points pop and reduce eye strain during early-morning checks" (925studios). The dominant usage moment is 6am in a dark bedroom. The palette is designed for the moment of use, not the screenshot.
4. **Zero-input data capture.** 925studios: automation removes "the biggest source of friction in fitness tracking: remembering to press start." The home screen never has an empty state caused by user forgetfulness.
5. **Bookended narrative.** "Daily Outlook each morning" and "Day in Review at night" (thedatastory case study, fetched) give the home screen two scheduled reasons to be opened, which is how you get to 83% DAU/MAU.

### 1.8 Weaknesses — real complaints, sourced

- **Density defeats new users.** the5krunner (2023): "new users of WHOOP may find the amount of information on the screen daunting, and navigating to more detailed insights is not always intuitive… The changes don't make it any easier for a new WHOOP owner to learn the breadth and depth of the available insights." The same reviewer in 2026: "The information and features are densely presented. Thus, while it's easy to start using, it takes time to discover all of its nuances, nooks, and crannies."
- **Coaching copy is robotic.** 925studios quotes it verbatim as a defect: "Multiple days below strain targets will promote recovery" — "technical jargon that confuses users."
- **No rest-day logic.** 925studios: users who consistently score high recovery get "perpetually elevated targets" with no "programmed deload periods."
- **No manual target override.** Users "cannot manually adjust their Recovery or Strain targets."
- **Over-reactive score.** Whoop community thread, fetched: "WHOOP flags every small HRV drop as a big problem"; concern that this "creates unnecessary worry, particularly for those with naturally lower HRV baselines."
- **App reliability.** App Store reviews I fetched: "App settings' tab redirects me to profile. Cannot access app settings" (02 Jul 2025); "It consistently disconnects from Bluetooth mid workout" (14 Jan 2025). Note the What's New notes for versions 5.40.0 → 5.63.0 are all literally "Various bug fixes and performance improvements" — no communication surface at all.
- **techgearlab's first impression:** the app looked "a bit jumbled with fluff articles that read more like content from a free health blog than a subscription service" until enough data accumulated. That is a cold-start problem on the home screen.

### 1.9 What I would change

1. **Put the delta and its cause on the dial.** Under `74%` print one line: `-9 vs yesterday · sleep 52 min short`. One clause of causality kills the largest single class of complaints (score doesn't match how I feel) without adding a tap.
2. **Kill the yellow/red moral framing for a *budget* framing.** "Recovery 31%" reads as a failing grade. "Today's budget: light" reads as an allocation. The underlying number can stay identical.
3. **Rate-limit the alarm.** Do not push "your HRV dropped 16%" unless the dip persists 2+ days or crosses the personal baseline by more than N sigma. Single-day HRV noise is not signal, and pushing it is what produces the community thread above.
4. **Give the first 14 days a different home screen.** techgearlab's "fluff articles" complaint and the5krunner's "daunting" complaint are the same complaint: the full dashboard is shipped to a user who has no baselines yet. Show a calibration screen instead of a scored one.

### 1.10 Numbers

- **83% of MAU open the app on any given day** — Will Ahmed via TechCrunch, 27 Mar 2026 (fetched). Trails only WhatsApp by his claim.
- Revenue "grew more than 100% last year" and Whoop reached cash-flow positive (same article).
- ~2.5M members, $1.1B revenue run rate, subscriptions and bookings +103% — search extract from Yahoo Finance / Sacra, not fetched directly. `[weakly sourced]`
- "More than 50% of members use WHOOP daily, even 18+ months after purchase" and "WHOOP Journal engagement (≥10 entries/month) linked to a 15% higher retention rate (2024)" — search extract, original page not fetched. `[UNVERIFIED — treat as directional]`
- **No published A/B result for the Oct 2025 home screen change.** Whoop says the redesign was "based on research and feedback from members" who "wanted a more intuitive experience, easier-to-find shortcuts, and more ways to see insights and coaching tips" (search extract of whoop.com locker post). No metric attached.

---

## 2. OURA

### Sources fetched
- https://ouraring.com/blog/new-oura-app-experience/ (fetched — the redesign announcement)
- https://ouraring.com/blog/new-app-design/ (fetched — the design rationale)
- https://ouraring.com/blog/readiness-score/ (fetched — score bands and contributors)
- https://www.dcrainmaker.com/2026/07/oura-ring-5-in-depth-review-comparison.html (fetched — July 2026 critique)
- https://www.crausser.com/oura-redesign (fetched — independent designer critique of the pre-2025 home screen)

### 2.1 Vertical order, top to bottom (Today tab, post-Oct-2025)

```
┌─────────────────────────────────────────────┐
│  ☰ Trends            Today          [icons] │
├─────────────────────────────────────────────┤
│  ⟨ Readiness  Sleep  Activity  HR  Stress ⟩ │  ← SCORE SHORTCUT ROW
│      82        79      64     58   1h12m    │     horizontally scrollable,
│                                             │     customisable, +Resilience
├─────────────────────────────────────────────┤
│  DAILY HIGHLIGHT                            │  ← the "one big thing"
│  "Your resting heart rate settled 4 bpm     │     changes by time of day
│   below your baseline last night."          │
├─────────────────────────────────────────────┤  ══ approx fold ══
│  TIMELINE                                   │
│   ▁▂▅▇▅▃▁ your day as it happened,          │
│   tags, activities, meals                   │
├─────────────────────────────────────────────┤
│  DISCOVERIES                                │
│   "On days you tag 'late caffeine',         │
│    your Sleep Score is 6 pts lower."        │
├─────────────────────────────────────────────┤
│      [Today]      [Vitals]     [My Health]  │  ← three-tab nav
└─────────────────────────────────────────────┘
```

Confirmed order from ouraring.com/blog/new-oura-app-experience/ (fetched): Score Shortcuts (Sleep, Readiness, Activity, plus quick access to heart rate, Daytime Stress, Cycle Insights) → Daily Highlight → Timeline → Discoveries. Rollout began **16 October 2025**.

DC Rainmaker (July 2026, fetched) confirms the shape independently: "a customizable row of scores at the top" and "a continuous scroll of larger display information below", with the top row containing "Readiness Score, Sleep Score, Activity Score, Heart Rate (Current), Stress (minutes), plus the ability to add Resilience or remove other metrics."

### 2.2 What appears FIRST, and why

The **score row**, and within it Readiness is the anchor. Oura's stated rationale, verbatim from ouraring.com/blog/new-app-design/: *"We cut through the clutter to help you focus on 'one big thing' — the most important score or insight you need right now."* And the mental model they name for the Today tab is a news product: *"the 'Top Stories' page of a news app, delivering the most timely, relevant health updates to help you navigate your day."*

That metaphor is the whole design thesis and it is worth pausing on. A Top Stories page is (a) editorially selected, (b) time-varying, (c) short. Oura is claiming the home screen is a *feed with an editor*, not a dashboard. The Daily Highlight is the editorial slot. Whether it delivers is a separate question (see 2.8).

Hypothesis for putting the scores above the highlight rather than the reverse: the scores are the *contract* — the thing the customer paid for and expects to see — while the highlight is the *value-add*. Putting the value-add first would feel like being made to read an ad before getting your number.

### 2.3 The single action the screen is engineered to produce

**Tap a score → land in a contributor breakdown.** Oura's business is retention on a $5.99/mo membership plus long-term health positioning; the engineered behaviour is *investigation*, not action. DC Rainmaker confirms the target of the tap: tapping Readiness gives "a timeline showing readiness over the past week" and "contributors to today's score."

A secondary engineered action, newer: **tag a behaviour on the Timeline**, which feeds Discoveries. That is the loop Oura is actually trying to close — tag → correlation → "Discovery" → felt causality → retention.

### 2.4 Emotion in the first 3 seconds

**Calm-leaning curiosity, with a soft-scold floor.** Oura's band labels are unusually gentle and are literally sentences, not grades (ouraring.com/blog/readiness-score/, fetched):

| Range | Label | Verbatim copy |
|---|---|---|
| 85-100 | Optimal | "Optimal, you're ready for action!" |
| 70-84 | Good | "Good, you've recovered well enough." |
| < 70 | Pay attention | "Pay attention, you're not fully recovered." |

"Pay attention" is doing enormous work. Compare it to Whoop's red. It is a nudge to notice, not a verdict of failure — and critically, the bottom band is a **single band covering 0-69**, so a 15 and a 68 read identically. That is a deliberate anxiety-suppressing choice: the app refuses to make you feel *degrees* of bad.

Oura also states the design system "uses color to signal your body's different states according to your biometrics, giving you an immediate visual signal of how you're doing each day" — so the chromatic hit is still first, same as Whoop, but the vocabulary attached is softer.

### 2.5 Hidden behind taps

- **Contributors.** Seven daily contributors, all one tap down from the score. Oura's blog groups them (fetched): Sleep pillar — Sleep, Sleep Balance; Activity pillar — Previous Day Activity, Activity Balance; Body Stress pillar — Resting Heart Rate, HRV Balance, Body Temperature, Recovery Index. (The page names three pillars and enumerates eight items while Oura elsewhere says "seven contributors" — the count is inconsistent in their own docs. `[flagged, minor]`)
- **The baseline logic.** DC Rainmaker: comparisons are "based on a 3-month rolling baseline" rather than the 7-day window many competitors use. This is a major behavioural difference — Oura's score is slower to move, which makes it feel more stable and less reactive than Whoop's, and it is invisible on the home screen.
- **Trends.** Reached via the upper-left menu on Today, not from the main scroll.
- **Everything long-term.** Cardiovascular Age, Stress Resilience, weekly/quarterly/yearly reports and shareable clinician reports all live in My Health, two navigation levels from the home screen.

### 2.6 Deliberately omitted

- **No numeric delta vs yesterday in the score row.** Confirmed absent in the layouts described by both Oura and DC Rainmaker; the delta lives in the tapped-through week timeline. `[UNVERIFIED whether a small arrow/chip exists — no source I fetched shows one.]` **Smart** given the 3-month baseline: a day-over-day delta would contradict the slow-baseline philosophy.
- **No strain/exertion budget.** Oura will not tell you how hard to train today in a number. Smart for their audience (Oura skews non-athlete, sleep-first) and it is the cleanest single-line difference vs Whoop.
- **No leaderboard, no social on Today.** Smart. Removes the single biggest anxiety vector in the category.
- **Images/photography removed from data screens.** The independent crausser critique of the pre-redesign app called for exactly this — "imagery was eliminated entirely to reduce clutter and improve data readability" — and Oura's shipped redesign went the same way.

### 2.7 Strengths — the actual mechanism

1. **The "one big thing" slot is a real architectural commitment, not a slogan.** There is a named region (Daily Highlight) whose job is to hold exactly one editorially-selected insight, and it changes with time of day: "Depending on the time of day (or night) you open the Oura App, Oura will surface a health insight relevant to your activities, habits, and how your biometrics have changed." That is a home screen that answers a different question at 7am than at 9pm from the *same* pixel region — enormously more efficient than adding cards.
2. **Bands as sentences.** "Pay attention, you're not fully recovered" is a complete instruction. No colour lookup needed, no jargon, no grade.
3. **Three-month baseline = a score that does not whipsaw.** The quiet reason Oura reads calmer than Whoop is not the palette, it is the statistics.
4. **Tab split by time horizon.** Today = now, Vitals = this week's pillars anchored to "your unique, personalized baselines", My Health = "the 'so what?' of your health." Splitting by *time horizon* rather than by *metric type* is the smartest structural call in this entire teardown. It means the home screen never has to carry a six-month chart.
5. **Discoveries closes the causality loop** by tying user-entered tags to score movement — the only mechanism in the set that makes the user's own behaviour the explanation.

### 2.8 Weaknesses — real complaints, sourced

- **The scroll dilutes.** DC Rainmaker, July 2026, verbatim: *"Personally, I find it dilutes the information too much, and doesn't really make your actual data very clear."*
- **Information recycling.** Same review: readiness, sleep and activity scores "appear repeatedly across different sections, creating redundancy rather than meaningful new insights." Three tabs each re-presenting the same three scores is the structural cost of the tab split.
- **Polarising reception.** Search extract of the same review: users "are either going to love it or hate it."
- **Pre-redesign sins that inform the redesign.** The crausser designer critique (fetched) of the older app found: "the app home screen was so incredibly long" with data "sparsely distributed"; and measured accessibility failures with Figma's Able plugin — "both the 'Record workout HR' CTA button and the 'Activity Goal Progress' text did not pass contrast accessibility." Also inconsistent CTA placement: the record-exercise button was prominent on one time-of-day variant and buried on the Readiness and Sleep variants.
- **The time-of-day-morphing home screen (pre-2025) was itself the problem** the crausser critique attacked, and the 2025 redesign retained the morphing *inside* one slot instead of morphing the whole screen. Worth noting as an evolution: full-screen contextual morphing failed; single-slot contextual morphing survived.

### 2.9 What I would change

1. **Kill the redundancy DC Rainmaker names.** If Vitals and My Health both re-render the score row, the score row should be a persistent pinned header owned by the app shell, drawn once, not three times as three different components.
2. **Give the Daily Highlight a "why" affordance inline.** Right now the highlight asserts. One `Because →` chip that expands to the two contributors driving it would convert an assertion into an explanation without a navigation.
3. **Show the baseline visually in the score row.** A 2px tick on each score chip at the user's 3-month median instantly communicates "82 is high *for you*", which is the entire premise of the product and currently invisible until you tap.
4. **Compress the sub-70 band into two.** One band covering 0-69 protects against anxiety but destroys signal for genuinely ill users. `Pay attention` / `Rest` at, say, a 50 boundary would keep the gentleness and restore the top-end of the alarm.

### 2.10 Numbers

- Redesign rollout began **16 October 2025**, globally over "the next few weeks" on iOS and Android (ouraring.com, fetched).
- Readiness bands 85 / 70 / <70 (ouraring.com/blog/readiness-score/, fetched).
- 3-month rolling baseline vs competitors' 7-day (DC Rainmaker, fetched).
- "80% weekly active users in 2024", "customer retention rates grew by 10% after significant updates in 2024", "community grew by 40% in 2024", "over 1 million members" — all from a search extract of canvasbusinessmodel.com, a low-quality aggregator. `[UNVERIFIED — do not quote to anyone senior.]`
- **No published engagement delta for the Oct 2025 redesign.** Nothing exists publicly. `[UNVERIFIED because unpublished]`

---

## 3. ULTRAHUMAN RING AIR

### Sources fetched
- https://ultrahuman.com/blog/ultrahuman-ring-recovery-score-guide/ (fetched — the score's own spec)
- https://apps.apple.com/us/app/ultrahuman/id1491286709 (fetched — description + reviews)
- https://www.engadget.com/2220780/ultrahuman-overhauls-app-brings-all-of-its-analysis-on-device/ (fetched — the "Emerald" overhaul)
- NBC Select Ultrahuman Ring Air review (403 on direct fetch; used search extract of the same URL)
- Search results covering the Emerald / UltraSphere / PowerPlugs update

### 3.1 Vertical order, top to bottom (the "Ring" / home tab)

```
┌─────────────────────────────────────────────┐
│  Ultrahuman        [ring battery] [profile] │
├─────────────────────────────────────────────┤
│  MOVEMENT INDEX                             │
│      ╭──────╮   speedometer / gauge          │  ← starts at 100 each morning,
│      │  72  │   decays with inactivity       │     DECAYS through the day
├─────────────────────────────────────────────┤
│  SLEEP INDEX                                │
│      86      + stages, SpO2, nap             │
├─────────────────────────────────────────────┤
│  DYNAMIC RECOVERY                           │
│      ▇▇▅▃▅▇  bar graph, updates live         │
│      85 — Optimal                            │
├─────────────────────────────────────────────┤  ══ fold ══
│  STIMULANT (CAFFEINE) WINDOW  — line graph  │
├─────────────────────────────────────────────┤
│  CARDIO FITNESS / VO2 · HR · SKIN TEMP      │
├─────────────────────────────────────────────┤
│  MACRONUTRIENT / METABOLIC BLOCK            │
├─────────────────────────────────────────────┤
│  ULTRAHUMAN STORE  ·  REFERRAL BANNER       │  ← commerce in the health feed
└─────────────────────────────────────────────┘
```

The three-index top is confirmed by search extracts: "The Ultrahuman app's home screen features its three big scores (Movement Index, Sleep Index, Recovery) front and center. There are also blocks for other info like the Stimulant Restriction Window, Cardio Fitness, heart rate, skin temperature, and more." The store block and referral banner are named in an Oura-vs-Ultrahuman comparison extract: "blocks for macronutrient integration, a section for the Ultrahuman Store, and a banner advertising referrals."

**After the "Emerald" update** (Engadget, fetched), the default tab became contextual: the app "puts contextual information on the default tab, customized to your needs at any given time", with "a focus on simplifying and decluttering its layout for easier parsing", and UltraSphere (an AI "decision engine") became the centrepiece. All insight processing moved on-device.

### 3.2 What appears FIRST, and why

**Movement Index** — and this is the most idiosyncratic call in the whole set. It is a 0-100 score that **resets to 100 every morning and decays with inactivity**, rising again when you move. So the first thing you see is a number you are *losing*.

Hypothesis for the placement: Ultrahuman's positioning is metabolic/behavioural rather than athletic-recovery, and their core belief is that continuous movement beats one workout. Putting a decaying score first converts the home screen from a morning-only ritual (Whoop, Oura) into an **all-day check-in**, because the number is only meaningful if you look repeatedly. It is a session-frequency mechanic dressed as a health metric.

That is clever and I respect it. It is also loss-framed by construction, which is the single most reliable anxiety generator in behavioural design.

### 3.3 The single action the screen is engineered to produce

**Get up and move now** (short term), and **open the app several times a day** (the real one). No other app in this set has a home-screen metric that punishes not looking.

Secondary and increasingly explicit: **buy something.** The store block and referral banner sit in the same scroll as the health data.

### 3.4 Emotion in the first 3 seconds

**Low-grade urgency / mild guilt.** A depleting bar is a loss frame. Compare Garmin's Body Battery (also depleting) — but Garmin puts Body Battery in a customisable row alongside four other things, whereas Ultrahuman leads with the depleting number.

The secondary emotion is **visual confusion**, which is unusual and worth naming as an emotion because it demonstrably slows the read. NBC Select, via search extract of their review: *"The Ring tab itself is a bit busy because each metric is displayed in such a disparate way. The movement summary looks like a speedometer, caffeine window is a line graph, dynamic recovery is a bar graph"* — and then, damningly, *"when you click in for more details, all of them show simple bar graphs with suddenly unified design language."* The detail views are more coherent than the home screen. That is backwards.

### 3.5 Hidden behind taps

- The five components of Dynamic Recovery: **Sleep Quotient, Stress Rhythm, Temperature, Resting Heart Rate, HRV Form** (ultrahuman.com recovery guide, fetched). The blog says: "If any of these values change, the overall score dwindles, showing you exactly what you need to improve on."
- Personal baseline logic: "Each individual's resting heart rate is different. Ultrahuman Ring AIR considers the individual's baseline to determine the deviation in resting heart rate."
- Unified detail charts (per NBC Select above).
- Post-Emerald: PowerPlugs — "supercharged micro-experiences" (Sleep Screener, Longevity tab, Connections, Windows, Live View, Goals) that are opt-in modules rather than default home content.

### 3.6 Deliberately omitted

- **No goal-progress framing on activity.** Movement Index replaces "7,412 / 10,000 steps" with a decaying 0-100. **Smart** in intent (steps goals are arbitrary and demotivating once missed) but **executed badly**, because a decaying score is a *worse* loss frame than a step goal, not a better one. You cannot "miss" a step goal until end of day; you can watch Movement Index bleed out at 2pm.
- **No single unified "today" verdict.** Three coequal indexes with no ranking means the user must decide which one matters. This is the clearest contrast with Oura's "one big thing."
- **No delta vs yesterday on the home cards** `[UNVERIFIED — not described in any source I fetched, and no reviewer mentions one]`.

### 3.7 Strengths

1. **A real-time recovery score.** "The system recognizes shifts in your markers and adapts the score in real-time" (ultrahuman.com, fetched). Every competitor freezes recovery at wake. A live-updating recovery number is genuinely differentiated and makes the home screen worth reopening at 3pm.
2. **Named, enumerable contributors with human-ish names.** "Sleep Quotient, Stress Rhythm, Temperature, Resting Heart Rate, HRV Form" is a better vocabulary than raw metric names.
3. **Explicit personal-baseline messaging.** They say out loud that RHR deviation is measured against *your* baseline. Most apps do this silently.
4. **On-device processing (Emerald).** Engadget notes it "improves functionality during travel when connectivity is limited" — a home screen that renders fully offline is a real reliability strength for a daily-ritual product.
5. **The company responds to clutter feedback.** They shipped a declutter release, and an App Store reviewer noted: "the recent update that allows you to clean up the home navigation bar is incredible."

### 3.8 Weaknesses — real complaints, sourced

- **Chart-form incoherence** (NBC Select, above). Three different visual grammars in the first screen.
- **Commerce in the health feed.** Store block + referral banner in the same scroll as recovery data. The comparison extract: "Reviewers tend to prefer Oura's slightly simpler, less cluttered approach."
- **Broken explanation affordances.** App Store review, fetched verbatim: *"None of the 'i' info buttons work, so you can't get an explanation of what is being tracked or understand the terminology."* An app whose home screen shows five bespoke coined terms and whose info buttons are broken has no explanation layer at all.
- **Sync gaps.** App Store review: "I do wish the data sync was more seamless… sometimes there will be a few consecutive days where no data uploads." A home screen built on a live-updating score fails hard when data is missing.
- **Release notes say nothing.** Fetched pattern: "We've made general improvements and fixed a few bugs" / "subtle improvements across the app." Same failure as Whoop.
- **Engadget's own framing admits the density was contested:** the author "previously appreciated the app's dense, data-rich layout" but acknowledges "other people don't feel the same."

### 3.9 What I would change

1. **One visual grammar for the top three.** Pick the gauge or pick the bar. NBC Select's observation that the *detail* views are unified while the *home* is not is a straight bug in the design system.
2. **Reframe Movement Index from decay to accrual.** Same maths, opposite sign. "Movement 28/100 earned" produces effort; "Movement 72/100 remaining" produces dread. If the decay mechanic is load-bearing for session frequency, keep it but show the *earned* number as the hero and the decay as the track behind it.
3. **Get commerce out of the primary scroll.** Move store and referral to the profile tab. Health-data adjacency to a buy button is the fastest way to lose the trust that makes the score credible.
4. **Fix the info buttons before shipping any new coined term.** "Stress Rhythm" and "HRV Form" are invented vocabulary. Invented vocabulary with a broken glossary is worse than raw metric names.

### 3.10 Numbers

- Dynamic Recovery scale 0-100, "a higher (85 or above) number indicating better recovery" (ultrahuman.com, fetched).
- Movement Index 0-100, resets to 100 daily (search extract, NBC Select).
- **No engagement or retention numbers published.** Ultrahuman has released none I could find. `[UNVERIFIED because unpublished]`

---

## 4. ATHLYTIC

### Sources fetched
- https://apps.apple.com/us/app/athlytic/id1543571755 (fetched — description, What's New v26.5.0, reviews)
- https://ibikerun.substack.com/p/athlytic-app-review-iosapple-watch (fetched — layout order)
- https://neura.health/insight/athlytic-app-in-depth-review (fetched)
- https://www.corahealth.app/compare/athlytic (fetched — churn reasons)
- https://fitnesstoolsreviewed.com/app-reviews/athlytic-review-the-unfiltered-truth-after-90-days/ (fetched)

### 4.1 Vertical order, top to bottom

```
┌─────────────────────────────────────────────┐
│  Athlytic                    [date] [gear]  │
├─────────────────────────────────────────────┤
│  RECOVERY                    ●  green       │  ← colour-coded card
│     78%    "ready to train"                 │
├─────────────────────────────────────────────┤
│  EXERTION                    ●  amber       │
│     9.2 / target 12-15                       │
├─────────────────────────────────────────────┤
│  SLEEP                                       │
│     7h 12m  ·  score                         │
├─────────────────────────────────────────────┤  ══ fold ══
│  ENERGY BURNED (net energy)                 │
├─────────────────────────────────────────────┤
│  HRV chart · HR chart · cardio fitness      │
├─────────────────────────────────────────────┤
│  trends: recovery vs exertion, cardio load, │
│  sleep performance, sleep stages            │
└─────────────────────────────────────────────┘
```

Order confirmed by ibikerun (fetched): "the main display includes 4 metrics in order: 1. Recovery 2. Exertion 3. Sleep 4. Energy Burned." Card format confirmed by search extract: "color-coded cards for Recovery, Exertion, and Sleep, plus detailed charts for HRV, heart rate, energy burn."

### 4.2 What appears FIRST, and why

**Recovery, unambiguously and alone at the top.** Athlytic is an Apple Watch app with no hardware of its own; its entire reason to exist is that Apple Health gives you raw HRV and no verdict. The product *is* the verdict. So the verdict is the first pixel.

This is the purest expression of the pattern in the set: one score, top-left, no competing element, no dial row. Athlytic does not have to balance a hardware story or a longevity story or a store.

### 4.3 The single action the screen is engineered to produce

**Decide today's training intensity, then close the app.** Cora's review, fetched: "The presentation is clean and glanceable — most users can check their readiness in under ten seconds, which is a deliberate and thoughtful design choice." Ten seconds is the design target. Athlytic is the only app here whose success metric appears to be *short* sessions.

The v26.5.0 What's New (fetched) confirms the deepening of exactly this action: *"Workout Suggestion Customization — You can now fine-tune the Workout Suggestions on the Exertion screen to fit how you want to train today!"*

### 4.4 Emotion in the first 3 seconds

**Pride or resignation, quickly.** Same red/yellow/green vocabulary as Whoop — "green means go hard, yellow means proceed with caution, and red means back off" (fitnesstoolsreviewed, fetched) — but delivered on a flat card rather than a hero dial, which lowers the drama. There is no glow, no animation on open described anywhere. The affect is closer to reading a weather widget than receiving a verdict.

### 4.5 Hidden behind taps

- Contributor detail (HRV vs RHR split), 7-day recovery-vs-exertion trend, cardio load, sleep stages, training effect, HR-zone charts per workout.
- Notably, fitnesstoolsreviewed says Athlytic is "Transparent about why your score is what it is" — but I could not find a source describing *where* on the home screen that transparency appears, so the explanation is likely one tap down. `[partially UNVERIFIED]`

### 4.6 Deliberately omitted

- **No training plan, no programming.** Cora names this as a top churn reason: users "want workout programming built in, which Athlytic intentionally does not provide." The word *intentionally* matters — it is a scope decision, not a gap. **Smart**: an app with no hardware, no cost of goods and a solo-ish team that tried to also be a coach would be worse at both.
- **No training load / accumulated stress.** ibikerun, verbatim: "Athlytic has no concept of training load. It does not show you accumulated training stress or the breakdown into aerobic zones." **Dumb** for their stated audience of athletes — a recovery score with no load counterpart is half a loop.
- **No Android, no Garmin, no Oura ingestion.** Cora lists device-switching as a churn reason. Smart for focus, expensive for TAM.
- **11+ widgets and 8+ complications** (App Store, fetched) — Athlytic deliberately pushes the score *off* the home screen and onto the OS. This is the most interesting strategic omission in the set: the best version of their home screen is a widget you never open.

### 4.7 Strengths

1. **One score, no competition for attention.** The other five apps all have 3-6 things fighting at the top. Athlytic has one.
2. **The widget-first strategy.** Shipping 11 home-screen widgets and 8 complications means the daily check does not require an app open at all. That is a *lower-engagement, higher-satisfaction* bet and it is the opposite of Whoop's. Worth stealing.
3. **Ten-second target as an explicit design constraint** (Cora). Naming a time budget is a discipline almost nobody in this category has.
4. **Cheap, fast iteration.** v26.5.0 shipped a granular Exertion-screen customisation; contrast with Whoop's 20 consecutive "various bug fixes" release notes.

### 4.8 Weaknesses — real complaints, sourced

- **Cardio bias in the score.** ibikerun, verbatim: *"if I do a lot of hill climbing on the bike… the recovery metric shows full recovery but my body is not fully recovered."* And the cascade: exertion targets are "based on the recovery score" and "may result in overtraining" by ignoring muscular fatigue.
- **Data-heavy for casual users.** neura.health, fetched: "Can feel overwhelming at first"; the interface "may feel too data-heavy for casual users"; "Athlytic can feel busy."
- **Noisy inputs.** Cora: "Apple Watch overnight HRV readings are inconsistent due to poor wrist contact during sleep — this is a hardware limitation, not an Athlytic bug, but it produces noisy recovery scores that frustrate some users."
- **Calibration period.** fitnesstoolsreviewed: "Calibration period can feel unreliable in the first two weeks."
- **Wearer-compliance dependency.** neura.health: "Less useful if you do not wear your watch overnight." No described empty/degraded state for a missing night.
- **Sane caveat from the reviewer:** scores "should not override how you actually feel."

### 4.9 What I would change

1. **Add a one-line "why" under the Recovery number.** They reportedly have the transparency; it is one tap too deep. `78% · HRV 8ms above your 60-day mean` costs one line and answers the #1 complaint category.
2. **Show muscular fatigue as a second axis, or say out loud that you don't measure it.** ibikerun's complaint is a *trust* failure, not an accuracy failure. A tiny `cardio only` qualifier next to the score would resolve it honestly and cheaply.
3. **Degrade gracefully with no overnight data.** Show `no sleep data — recovery unavailable` rather than a computed score from partial data. Fail loudly.
4. **First-14-days mode.** Same fix as Whoop. During calibration, show the trend and hide the verdict.

### 4.10 Numbers

- Recovery scale 0-100, green/yellow/red (fitnesstoolsreviewed, fetched).
- "under ten seconds" readiness check (Cora, fetched) — a design claim, not measured telemetry.
- 11+ iPhone widgets, 8+ Watch complications (App Store, fetched).
- **No engagement/retention numbers published.** `[UNVERIFIED because unpublished]`

---

## 5. BEVEL

### Sources fetched
- https://apps.apple.com/us/app/bevel-ai-health-coach/id6456176249 (fetched — feature copy + reviews)
- https://tech.yahoo.com/wearables/articles/bevel-sort-makes-apple-watch-230000160.html (fetched — layout order, best source)
- https://australianapplenews.com/2026/01/07/review-bevel-a-health-app-that-ticks-almost-all-the-boxes/ (fetched)
- https://www.autonomous.ai/ourblog/bevel-app-review (fetched — the "doesn't show its work" critique)
- https://neura.health/insight/bevel-health-app-in-depth-review (fetched)

### 5.1 Vertical order, top to bottom

```
┌─────────────────────────────────────────────┐
│  Bevel                        [date] [coach]│
├─────────────────────────────────────────────┤
│    ( STRAIN )   ( RECOVERY )   ( SLEEP )    │  ← circular indicators,
│      11.8          71%           81         │     all three tappable
├─────────────────────────────────────────────┤
│  STRESS & ENERGY                            │
│   ENERGY BANK ▇▇▇▇▇▇░░░░  62%               │  ← "your body's battery"
│   declines through day, refills on sleep    │
├─────────────────────────────────────────────┤  ══ fold ══
│  HEALTH MONITOR                             │
│   resp rate · RHR · HRV · SpO2 (blank) ·    │
│   skin temp · sleep time                    │
├─────────────────────────────────────────────┤
│  CARDIO LOAD  (consistency trend)           │
├─────────────────────────────────────────────┤
│  NUTRITION LOGGING (photo → AI macros)      │
├─────────────────────────────────────────────┤
│  TIMELINE / JOURNAL                         │
│   meals, exercise, sleep, mood, hydration   │
└─────────────────────────────────────────────┘
```

Order confirmed by the Yahoo/Engadget-syndicated review (fetched), which lists it explicitly: (1) Strain, Recovery, Sleep at top; (2) Stress and Energy card with the energy bank; (3) Health Monitor vitals — "respiratory rate, resting heart rate, HRV, blood oxygen (blank space), skin temperature, and sleep time"; (4) Cardio load; (5) Nutrition logging. Australian Apple News independently confirms the top: "circular metric indicators for Strain, Recovery and Sleep" plus Timeline and Journal.

### 5.2 What appears FIRST, and why

**Three circles: Strain, Recovery, Sleep** — a near-exact clone of Whoop's trio, which is the explicit framing of the review headline ("Bevel (Sort of) Makes Your Apple Watch Act Like a Whoop"). Bevel's positioning is "Whoop for people who already own an Apple Watch", and the home screen is the positioning statement. Placing Strain first (left) rather than Sleep first is the one deviation, and it reads as an athletic rather than a sleep-first ordering.

### 5.3 The single action the screen is engineered to produce

**Log something** — food photo, mood, hydration, workout. Bevel's differentiator is the Journal/Timeline and the AI food photo. The scores are the hook that gets you to the logging surface. Evidence: the App Store copy leads with Recovery/Sleep/Strain but the reviews that people write are about logging — "I love the ability to take a picture of the food and have AI guess it!" (Sept 2025 review, fetched).

### 5.4 Emotion in the first 3 seconds

**Calm and non-judgemental — deliberately.** The most striking single data point I found in this whole teardown is a Bevel App Store review, verbatim: *"No calorie 'goals' or 'you didn't hit your macro target' or cyber guilting."* A user wrote a review specifically to praise the *absence* of guilt mechanics. That is a design achievement and it is invisible in a feature list.

The Energy Bank is a depleting metric like Ultrahuman's Movement Index, but framed as a *bank* (a resource you spend) rather than an *index* (a score you lose). Same maths, materially better frame.

### 5.5 Hidden behind taps

Score contributors, trends, strength-training breakdowns, and — per the reviews — essentially all reasoning.

### 5.6 Deliberately omitted

- **No guilt copy, no goal-miss messaging.** Deliberate per the review above. **Smart**, and it is their most defensible differentiator.
- **No hardware.** Reads Apple Health. Smart — zero COGS, instant onboarding for existing Watch owners, and it makes the home screen populated on day one instead of day fourteen.
- **Guidance.** This one is not smart, it is a gap they have not filled — see 5.8.
- **SpO2 renders as an empty slot** for users whose Watch cannot supply it (Yahoo review names "blood oxygen (blank space)"). **Dumb.** Never render a labelled empty slot on a home screen; either hide it or state why it is empty.

### 5.7 Strengths

1. **Guilt-free framing as a shipped, noticed feature.** Users write reviews about it. In a category where the primary complaint is score anxiety, this is a moat.
2. **"Energy Bank" as the language for the depleting metric.** Bank = resource = agency. Compare Ultrahuman's decaying Movement Index and Garmin's Body Battery. Bevel's word is the best of the three.
3. **Free-standing scores with no hardware.** The home screen is fully populated the moment you install, because Apple Health already has history. Zero cold-start.
4. **One number per concept.** App Store copy is explicit: Sleep Score = "Track and understand your sleep with a single number"; Recovery = "Your daily readiness, simplified."
5. **Timeline + Journal in the same scroll as the scores** ties behaviour to outcome without a tab switch.

### 5.8 Weaknesses — real complaints, sourced

- **Numbers without direction.** Yahoo review, verbatim and devastating: *"Bevel is big on data, but falls short on guidance. While I sometimes get annoyed at Garmin or Whoop trying to tell me how to live my life, I feel the opposite way with Bevel, like it just throws a bunch of numbers at me and leaves me hanging."*
- **Conclusions without evidence.** autonomous.ai review, fetched: Bevel "presents confident daily conclusions" but does not "show its work" on how inputs drive the numbers. This is the exact opposite failure mode from Whoop (which over-explains in jargon) and it is arguably worse — confident and unexplained.
- **Strength-training credit is wrong and unlabelled.** Yahoo: after kettlebells and pull-ups, "Bevel credited me with only '3%' (of what?) work for my upper back." The parenthetical *(of what?)* is a units failure on a home-screen-adjacent metric.
- **Multi-source data pollution.** Yahoo: the app "sometimes pulled workout data incorrectly from multiple sources, initially crediting the reviewer with only a few minutes of zone work despite hour-long runs." Apple Health as a source is a double-edged sword.
- **Garbage-in dependency.** neura.health: "If your watch fit is loose or your sensor is dirty, the 'garbage in, garbage out' rule applies."

### 5.9 What I would change

1. **Add exactly one directive line under Recovery.** Not a coach, not a plan — one sentence. The Yahoo complaint is not asking for a training program; it is asking to not be left hanging. `71% · a normal day. Keep strain under 13.` closes it.
2. **Show the work under each score.** Two contributor chips per score, inline, no tap. This directly answers autonomous.ai's "doesn't show its work."
3. **Never render an empty labelled vital.** Replace `SpO2 —` with either nothing, or `SpO2 not available on your watch`.
4. **Put units on everything.** "3%" of nothing is worse than no number.

### 5.10 Numbers

- Latest version 3.1.4 What's New (fetched): "Added a way to select a Bluetooth heart rate sensor", "Improved widget and watch complication performance."
- **No engagement or retention numbers published.** `[UNVERIFIED because unpublished]`

---

## 6. GARMIN CONNECT

### Sources fetched
- https://www.stocktitan.net/news/GRMN/garmin-connect-gets-a-new-look-simplified-design-provides-a-more-wzg6l6cqev23.html (fetched — Garmin's own press release, section names verbatim)
- https://gadgetsandwearables.com/2024/04/24/garmin-connect-new-look/ (fetched — complaints)
- https://forums.garmin.com/apps-software/mobile-apps-web/f/garmin-connect-mobile-andriod/369630/new-ui-is-a-bad-design-with-little-thought (fetched — forum complaints)
- https://www.advnture.com/news/garmin-connect-feedback (fetched — Garmin's response + user quotes)
- https://garminrumors.com/garmin-connect-essentials-how-to/ (fetched — the July 2026 Essentials row)

### 6.1 Vertical order, top to bottom (Connect 5.27, July 2026)

```
┌─────────────────────────────────────────────┐
│  Garmin Connect              [⚙ Home Settings]│
├─────────────────────────────────────────────┤
│  ESSENTIALS  (added 20 Jul 2026, v5.27)     │  ← NEW: up-to-4 stat row,
│   🌙 82   🔋 68   ⚡ 74   ♥ Balanced         │     icon-first, optional,
│   Sleep  Battery  Readiness  HRV            │     drag to reorder
├─────────────────────────────────────────────┤
│  TODAY'S ACTIVITY / PLANNED WORKOUTS        │  ← section 1 of the 2024 design
│   last activity card, next 2 days of events │
├─────────────────────────────────────────────┤
│  IN FOCUS  (up to ~5 swappable tiles)       │  ← big cards: sleep score,
│   large card · large card · large card      │     Body Battery, weekly trend
├─────────────────────────────────────────────┤  ══ fold, usually here ══
│  AT A GLANCE  (up to ~8 data cards)         │  ← HR, steps, calories,
│   [card] [card] [card] [card] …             │     stress, VO2 max …
├─────────────────────────────────────────────┤
│  EVENTS  (race countdown, race-day weather) │
├─────────────────────────────────────────────┤
│  TRAINING PLANS  (Garmin Coach progress)    │
├─────────────────────────────────────────────┤
│  CHALLENGES  (badges, group, family)        │
└─────────────────────────────────────────────┘
```

Section names and order are **verbatim from Garmin's own press release** (stocktitan, fetched): Today's Activity → In Focus → At a Glance → Events → Training Plans → Challenges, with Garmin's stated goal being "a simplified design and more relevant insights to each customer to inform and inspire them as they continue to conquer their goals."

Essentials is confirmed by garminrumors (fetched): "a glanceable row of up to four key stats at the top of the home screen", selectable from Sleep Score, Body Battery, Training Readiness, HRV Status, Health Status, Steps, with "dragging to reorder stats and toggling visibility." Released **20 July 2026** in Connect 5.27, alongside the screenless CIRQA band.

### 6.2 What appears FIRST, and why

Until July 2026: **your last activity.** That is a Garmin-shaped decision — Garmin's identity is the activity log, and the app grew out of a training-history product, not a health product. The consequence is that the home screen opened with *what you already did* rather than *what you should do today*.

Since July 2026: **the Essentials row** — four health stats. Garmin has, after two years of complaints, adopted the Whoop/Oura pattern wholesale. garminrumors makes the mapping explicit: "Sleep % → Sleep Score", "Recovery → Training Readiness (with HRV Status nearby)", Body Battery as the closest parallel to Strain, both answering "how spent am I?" And the key structural difference they name: *"Garmin's row is optional and customizable; WHOOP's trio is fixed at the center of that app."*

That sentence is the whole strategic difference between Garmin and everyone else here, and it is why Garmin loses this comparison. An optional hero is not a hero.

### 6.3 The single action the screen is engineered to produce

**Start or review a workout.** Everything downstream (Events, Training Plans, Challenges) is training-program machinery. Garmin Connect is a companion to a device that already showed you your numbers; the app's job historically was the archive.

### 6.4 Emotion in the first 3 seconds

**Neutral-to-flat, and this is a regression they caused deliberately.** gadgetsandwearables, verbatim: *"The vibrant color coding that signaled goal achievements or progress is gone, replaced by more subtle and less impactful color schemes."* Garmin traded emotional signal for aesthetic calm and users noticed the loss.

Garmin is the only app in this set that produces **no** emotion in three seconds, which sounds safe and is actually the worst outcome: no emotion means no reason to return.

### 6.5 Hidden behind taps

Almost everything, and that is the complaint. Body Battery, Sleep Score, Stress, HRV Status, Training Readiness and the Morning Report are all "app glances" mirroring the watch-side glances; each is a card you must scroll to and tap into.

### 6.6 Deliberately omitted

- **No single composite "today" score.** Garmin has Training Readiness (1-24 Poor, 25-49 Low, 50-74 Moderate, 75-94 High, 95-100 Prime — search extract; note the5krunner's own page gives slightly different band boundaries, so the exact cutoffs are `[disputed across sources]`), but it does not promote it to the identity of the app the way Whoop promotes Recovery. **Dumb.** Garmin invented arguably the richest readiness metric in the industry — six inputs: sleep score, HRV status, recovery time, acute training load, stress history, Body Battery — and buried it in a glance.
- **Custom dashboards** (previously available on the web app) were removed. advnture notes users report this.
- **Editing sleep times from the home page** was removed — gadgetsandwearables: "Seemingly simple features like editing sleep times directly from the homepage have been removed, adding an extra step to a once simple process."

### 6.7 Strengths

1. **Named, user-editable sections with a settings entry point.** Home Settings is a real, discoverable surface. No other app here lets you restructure the home screen this thoroughly.
2. **Watch-glance ↔ app-glance parity.** The same mental model on both devices. Under-appreciated: a user who learns Body Battery on the watch does not re-learn it in the app.
3. **Training Readiness itself is the most defensible score in the category** on inputs alone — six factors including acute training load, which nobody else on this list models.
4. **Essentials (July 2026) is the right fix**, even if late. A pinned four-stat row at the top is exactly what the complaints demanded.

### 6.8 Weaknesses — real complaints, sourced

- **The "At a Glance" paradox.** Search extract of the Garmin wiki/forums: users "need to now swipe or scroll to view information titled 'at a glance' when previously all the information was on a single screen. It's the exact opposite of what it purports to be."
- **Bigger cards, less information.** gadgetsandwearables, verbatim: *"The emphasis on larger cards and a cleaner aesthetic means less information fits on the screen at once. This forces users to scroll more frequently to access the same metrics they could previously see with a quick glance."*
- **Customisation regression.** gadgetsandwearables: *"Adding tiles for specific metrics or activities is no longer an option to the same extent, confining users to the pre-determined choices set by Garmin."*
- **Colour signal removed** (quoted in 6.4).
- **Small-screen failure.** Garmin forum, verbatim: *"The glance section is squished, since i dont own a jumbo-screen phone apparently, and doesn't show all the info I've grown to expect."* Designed on a large device, shipped to everyone.
- **Removed historical views.** Same thread: *"I hate how they removed the historical running data in a Bar chart form. It was nice to be able to see how many days I ran in the past month."*
- **Navigation hidden behind an overflow menu.** Same thread: the move from visible side navigation to a three-dots menu "creates unnecessary friction, making previously accessible screens difficult to locate."
- **Blunt user verdicts.** advnture: *"I'm trying to get used to it but I absolutely hate it"* — with the balancing quote also present: *"I actually quite like the app. Takes some getting used to, but I feel like everything is more accessible."*
- **Garmin's response was a feedback form, not a fix.** advnture quotes a Garmin spokesperson on Instagram: *"We appreciate how passionate our customers are, and we've seen your feedback on the new Garmin Connect. We encourage you to share your feedback at garmin.com/ideas or leave us a DM."* It then took roughly two years to ship Essentials.

### 6.9 What I would change

1. **Make Essentials non-optional and put Training Readiness in slot one by default.** An optional hero row means most users never turn it on and the app has no identity. Ship it on by default; let people remove it.
2. **Cut the six sections to three.** Today's Activity / In Focus / At a Glance are three ways of saying "some cards." Events / Training Plans / Challenges are a second app and belong behind a tab.
3. **Restore chromatic goal signal.** The 2024 desaturation is a measurable loss of the only free emotional feedback the screen had.
4. **Design the glance row on a 5.4" viewport first.** The forum's "squished" complaint is a breakpoint failure, not a taste failure.

### 6.10 Numbers

- Connect **5.27, released 20 July 2026**, adds Essentials (garminrumors, fetched).
- Training Readiness bands 1-24 / 25-49 / 50-74 / 75-94 / 95-100 (search extract). `[cutoffs disputed between sources]`
- Home screen sections: In Focus up to ~5 tiles, At a Glance up to ~8 cards (search extract of Garmin wiki). `[UNVERIFIED — Garmin's own FAQ page did not render for me]`
- **No engagement numbers published for any Connect redesign.** `[UNVERIFIED because unpublished]`

---

## 7. Cross-app comparison: how each renders one 0-100 number

| | Whoop | Oura | Ultrahuman | Athlytic | Bevel | Garmin |
|---|---|---|---|---|---|---|
| **Name** | Recovery | Readiness | Dynamic Recovery | Recovery | Recovery | Training Readiness |
| **Scale** | 1-99% | 0-100 | 0-100 | 0-100% | 0-100% | 1-100 |
| **Form** | Dial, ~72pt number | Chip in a horizontal row | Bar graph | Flat colour card | Circle | Glance card / Essentials chip |
| **Bands** | 3 (67/34) | 3 (85/70) | "85 or above" = good | 3 (green/yellow/red) | `[UNVERIFIED]` | 5 (Prime/High/Moderate/Low/Poor) |
| **Words attached** | colour only, no adjective on the dial | full sentences: "Optimal, you're ready for action!" | "Optimal" | "go hard / caution / back off" | "your daily readiness, simplified" | Prime / High / Moderate / Low / Poor |
| **Delta vs yesterday on home** | No (trend toggle 1w/1m/6m instead) | No (in the tapped-through week view) | No `[UNVERIFIED]` | No `[UNVERIFIED]` | No `[UNVERIFIED]` | No |
| **Why-explanation on home** | No — one tap, or ask Coach | No — Daily Highlight may or may not be about it | No — 5 factors one tap down | No — one tap | **No, and reviewers call this out** | No |
| **Updates during the day** | No (fixed at wake) | No (fixed at wake) | **Yes, real-time** | No | No | Recomputes, but not framed as live |
| **Baseline window** | ~short/reactive (users complain it over-reacts) | **3-month rolling** | personal baseline, window unstated | Apple Watch history | Apple Health history | acute + chronic load |

**The single biggest finding in this table: not one of the six shows a numeric delta vs yesterday on the home screen, and not one shows the *reason* on the home screen.** Six independent, well-funded product teams all made the same two choices. That is either a very strong convergent insight (deltas cause whiplash; reasons cost too much vertical space) or a shared blind spot. Given that "the score doesn't match how I feel" is the #1 complaint in the Whoop community thread, the Ultrahuman info-button review, the Bevel "doesn't show its work" critique and the Athlytic cardio-bias critique — four of six apps, four independent sources — I read it as a shared blind spot worth attacking.

---

## 8. The anxiety problem, with evidence

This category has a documented mental-health externality and it is directly caused by home screen design.

- A 2024 cross-sectional study of 523 adults estimated **orthosomnia prevalence at 3-14%** depending on definition, and found **35.8% of participants regularly used sleep-tracking devices**. Cases had consistently higher insomnia (AIS) scores than non-cases at every cutoff. Source: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11592250/ (surfaced in search; abstract-level detail).
- Age skew: **~23% of users aged 18-35 said sleep apps made them stressed about their sleep, versus 2.4% of those 66+** (search extract from the sahha.ai / livity-app write-ups of the survey literature). `[secondary source — the underlying survey is the SLEEP 2026 abstract "0553 Exploring the Prevalence of Sleep Tracking and Orthosomnia in a National Survey of Adults in the US", https://academic.oup.com/sleep/article/49/Supplement_1/A246/8674102]`
- A dedicated instrument now exists: the **Bergen Orthosomnia Scale (2025)**.
- Named warning sign in the literature: **"morning mood depends on sleep score."** That is a description of a home screen.

The design consequence is direct. Every one of these six apps opens with a graded verdict. Oura's mitigation is soft language and a single wide bottom band. Bevel's mitigation is removing goal-miss copy entirely — and a user wrote a review to thank them for it. Whoop has no mitigation and has the most vocal complaint threads. Ultrahuman actively adds a loss frame.

---

## 9. Category benchmarks worth holding in mind

- **Average time in a health & fitness app: ~2.5 minutes per day** (Apptopia data, via businessofapps Health & Fitness App Benchmarks — the page returned 403 to my fetcher, so this is a search extract). `[weakly sourced]`
- Apps with average sessions over 5 minutes saw **35% D30 retention vs 22%** for shorter sessions (same source). `[weakly sourced]` Note this correlation almost certainly runs backwards — engaged users produce long sessions, not the reverse — so do **not** use it to justify making the home screen slower.
- Health & fitness **D14 retention ≈ 12%**; **D30 ranges from ~3% (broad category) to 27.2% (average) to 47.5% (top performers)** depending on the source. The spread between these figures is so wide that they are not measuring the same thing; treat all as directional only. `[weakly sourced, conflicting]`
- **Whoop's 83% DAU/MAU is the only rigorously attributable engagement number in this teardown** (CEO, on record, TechCrunch, March 2026), and it is roughly 3-10x the category. Whatever Whoop's home screen is doing, it is doing it.

---

## 10. Consolidated design conclusions

1. **The top cluster is the product.** All six converged on a pinned 1-4 score cluster. The variable is count: Athlytic 1, Whoop 3, Bevel 3, Ultrahuman 3, Oura 5-6, Garmin 4 (optional). The apps with the clearest identity have the fewest (Athlytic, Whoop). The app with the most has the "dilutes the information" complaint from the most credible reviewer in the space (Oura / DC Rainmaker).
2. **Nobody explains on the home screen. Everybody gets complained at for not explaining.** This is the open lane.
3. **Word choice on the band label is a bigger lever than colour.** "Pay attention, you're not fully recovered" and "Multiple days below strain targets will promote recovery" describe similar states. One is human, one is a compiler warning.
4. **Loss framing is the difference between Movement Index and Energy Bank.** Same maths, opposite emotion, and one of them earned a spontaneous thank-you review.
5. **Optional heroes are not heroes.** Garmin's Essentials row is off by default and Garmin has no identity number as a result.
6. **The best-loved home screen may be the one you don't open.** Athlytic's 11 widgets + 8 complications strategy is the only genuinely different bet in the set, and it optimises satisfaction over session count.
7. **Cold start is universally unsolved.** Whoop ("fluff articles" until data arrives), Athlytic ("calibration period can feel unreliable in the first two weeks"), Ultrahuman (broken info buttons on invented terms). Nobody ships a distinct first-14-days home screen, and every one of them pays for it in reviews.
8. **Commerce in the health scroll costs trust** (Ultrahuman store block + referral banner, called out in comparison reviews).
9. **Release notes are a wasted surface.** Whoop shipped ~20 consecutive versions of "Various bug fixes and performance improvements"; Ultrahuman ships "subtle improvements across the app." Both then complain that users do not discover features.
10. **Two-year feedback latency is a competitive weapon in the other direction.** Garmin took ~2 years from the 2024 redesign backlash to Essentials in July 2026. Whoop fixed two nav-button criticisms **overnight** in October 2025, publicly enough that the reviewer wrote about it.

---

## Appendix: every URL fetched or searched this session

**Fetched successfully:**
- https://www.925studios.co/blog/whoop-design-breakdown
- https://the5krunner.com/2023/03/28/new-whoop-home-screen-looks-pretty-but-is-it-as-intuitive/
- https://the5krunner.com/2025/10/15/whoop-homescreen-gets-a-revamp/
- https://the5krunner.com/2025/10/31/2026-whoop-5-0-mg-review-discount-accuracy-strain-recovery-athletes/
- https://apps.apple.com/us/app/whoop/id933944389
- https://www.techgearlab.com/reviews/health-fitness/fitness-tracker/whoop-5-0
- https://www.community.whoop.com/t/whoop-stuck-at-red-recovery/5293
- https://techcrunch.com/2026/03/27/whoop-has-lebron-now-it-wants-your-mom/
- https://thedatastory.substack.com/p/case-study-whoop
- https://ouraring.com/blog/new-oura-app-experience/
- https://ouraring.com/blog/new-app-design/
- https://ouraring.com/blog/readiness-score/
- https://www.dcrainmaker.com/2026/07/oura-ring-5-in-depth-review-comparison.html
- https://www.crausser.com/oura-redesign
- https://ultrahuman.com/blog/ultrahuman-ring-recovery-score-guide/
- https://apps.apple.com/us/app/ultrahuman/id1491286709
- https://www.engadget.com/2220780/ultrahuman-overhauls-app-brings-all-of-its-analysis-on-device/
- https://apps.apple.com/us/app/athlytic/id1543571755
- https://ibikerun.substack.com/p/athlytic-app-review-iosapple-watch
- https://neura.health/insight/athlytic-app-in-depth-review
- https://www.corahealth.app/compare/athlytic
- https://fitnesstoolsreviewed.com/app-reviews/athlytic-review-the-unfiltered-truth-after-90-days/
- https://apps.apple.com/us/app/bevel-ai-health-coach/id6456176249
- https://tech.yahoo.com/wearables/articles/bevel-sort-makes-apple-watch-230000160.html
- https://australianapplenews.com/2026/01/07/review-bevel-a-health-app-that-ticks-almost-all-the-boxes/
- https://www.autonomous.ai/ourblog/bevel-app-review
- https://neura.health/insight/bevel-health-app-in-depth-review
- https://www.stocktitan.net/news/GRMN/garmin-connect-gets-a-new-look-simplified-design-provides-a-more-wzg6l6cqev23.html
- https://gadgetsandwearables.com/2024/04/24/garmin-connect-new-look/
- https://forums.garmin.com/apps-software/mobile-apps-web/f/garmin-connect-mobile-andriod/369630/new-ui-is-a-bad-design-with-little-thought
- https://www.advnture.com/news/garmin-connect-feedback
- https://garminrumors.com/garmin-connect-essentials-how-to/
- https://liveworksleep.com/whoop-app-features/
- https://honehealth.com/edge/ultrahuman-air-ring-review/
- https://www.androidcentral.com/wearables/ultrahuman/ultrahuman-emerald-update-is-massive-ultrasphere-decision-engine-is-the-star-for-us (content truncated, unusable)

**Returned HTTP 403 to my fetcher — used search extracts of the same pages instead:**
- https://www.whoop.com/us/en/thelocker/the-all-new-whoop-home-screen/
- https://support.whoop.com/APP_FEATURES__COACHING/Understanding_Your_WHOOP_Features/The_All-New_Home
- https://support.whoop.com/s/article/WHOOP-Basics
- https://www.nbcnews.com/select/shopping/ultrahuman-ring-air-review-rcna202789
- https://www.businessofapps.com/data/health-fitness-app-benchmarks/
- https://www.reddit.com (blocked entirely for this tool — no Reddit thread could be read directly this session)

**Searched, cited from search extracts only:**
- https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11592250/ (orthosomnia prevalence)
- https://academic.oup.com/sleep/article/49/Supplement_1/A246/8674102 (orthosomnia national survey abstract)
- https://sahha.ai/blog/orthosomnia-sleep-tracker-anxiety/
- https://wiki.garminrumors.com/Garmin_Connect
- https://the5krunner.com/garmin-features/training/training-readiness/
- https://www.whoop.com/us/en/thelocker/everything-whoop-launched-in-2025/
- https://canvasbusinessmodel.com/products/oura-business-model-canvas (Oura engagement figures — low quality, flagged)
- https://www.ultrahuman.com/us/powerplugs/

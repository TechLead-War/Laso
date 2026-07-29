# Garmin, Fitbit, Gentler Streak — Glanceable Verdicts

# Glanceable Body-Status Design — Garmin, Fitbit, Gentler Streak

Verification key: **[F]** = page fetched and quoted; **[S]** = search-result snippet only, page not fetched (treat as weaker); **[U]** = unverified, could not confirm.

---

## A) GARMIN

### A1. Body Battery — the glance itself

**What the glance shows (verbatim):** "The Body Battery™ glance displays your current Body Battery level and a graph of your Body Battery level for the last several hours." **[F]** [source: https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-28BA6B01-9460-4FF3-8499-5D91269FD50B.html]

**Interaction ladder (exact, Forerunner 965/265):** **[F]** [same source]
1. "Press UP or DOWN to view the Body Battery glance." → **number + sparkline, zero taps beyond scrolling**
2. "Press START to view a graph of your body battery and stress levels since midnight."
3. "Press DOWN to view a more detailed graph of your Body Battery and stress levels."
4. "Press DOWN to view a list of factors impacting your Body Battery level." (each factor selectable for detail)

So: **level at 0 presses, causal explanation at 3 presses.** The "why" is progressively disclosed, never on the glance.

**Colour language inside the detail graph (verbatim):** **[F]** [same source]
- "Blue bars indicate periods of rest"
- "Orange bars indicate periods of stress"
- "Green bars indicate timed activities"
- "Gray bars indicate times when you were too active to determine your stress level"

Note the same blue/orange/green/gray vocabulary is reused verbatim in the Stress glance — one colour system, two features. **[F]** [source: https://www8.garmin.com/manuals/webhelp/GUID-F41EAFB3-6CC9-42DE-9C6C-9E358DBB0671/EN-US/GUID-DD8EE575-CC72-4829-B4C8-4BE1F8D3473E.html]

**Scale and band labels (verbatim):** "The Body Battery level range is from 5 to 100, where 5 to 25 is very low reserve energy, 26 to 50 is low reserve energy, 51 to 75 is medium reserve energy, and 76 to 100 is high reserve energy." **[F]** [source: https://www8.garmin.com/manuals/webhelp/GUID-5D183A14-BB43-4A9B-B441-5F824214CE40/EN-US/GUID-87E1392B-2C55-40B7-A1FF-3AB9252DA0A0.html]

Note: the range is **5–100, not 0–100**. It never reads empty. Also verbatim from the same page: "Good sleep charges your Body Battery"; "Strenuous activity and high stress can cause your Body Battery to drain more quickly"; "Food intake, as well as stimulants like caffeine, has no impact on your Body Battery."

Older devices (fēnix 6/7, Instinct Solar, Legacy) label 76–100 "very high reserve energy" instead of "high". **[S]** [source: https://www8.garmin.com/manuals/webhelp/fenix6-6ssport/EN-US/GUID-87E1392B-2C55-40B7-A1FF-3AB9252DA0A0.html]

### A2. Training Readiness — the strongest verdict pattern Garmin ships

**Definition (verbatim):** "Your training readiness is a score and a short message that helps you determine how ready you are for training each day." **[F]** [source: https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-C21BE0C8-A08E-4DA1-B6C6-2E0E2DDDB372.html]

**Exact band → colour → label → message table (verbatim from same page):** **[F]**

| Colour | Range | Label | Message |
|---|---|---|---|
| Purple | 95–100 | **Prime** | "Best possible" |
| Blue | 75–94 | **High** | "Ready for challenges" |
| Green | 50–74 | **Moderate** | "Good to go" |
| Orange | 25–49 | **Low** | "Time to slow down" |
| Red | 1–24 | **Poor** | "Let your body recover" |

Design read: **number + one-word label + a 2–4 word imperative**, all three on one screen. The message is an instruction ("Time to slow down"), not a description. Colour is a 5-step ramp that is *not* monotone — purple sits above blue as a "special" top state rather than extending the hue.

**Inputs listed (verbatim):** "Sleep score (last night), Recovery time, HRV status, Acute load, Sleep history (last 3 nights), Stress history (last 3 days)". **[F]** [same source]

Third-party sources disagree on band boundaries (e.g. "73–100 Prime") — the manual is the authority; ignore the blog numbers. **[S]** [source: https://the5krunner.com/garmin-features/training/training-readiness/]

### A3. Training Status — 9 named states, no number

Verbatim descriptions **[F]** [source: https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-6F81BF5B-B49A-4506-95E2-0F4A04D8B319.html]:

- **No Status** — "The watch needs you to record multiple activities over two weeks, with VO2 max. results from running or cycling, to determine your training status."
- **Detraining** — "You have a break in your training routine or you are training much less than usual for a week or more. Detraining means that you are unable to maintain your fitness level."
- **Recovery** — "Your lighter training load is allowing your body to recover, which is essential during extended periods of hard training."
- **Maintaining** — "Your current training load is enough to maintain your fitness level. To see improvement, try adding more variety to your workouts or increasing your training volume."
- **Productive** — "Your current training load is moving your fitness level and performance in the right direction. You should plan recovery periods into your training to maintain your fitness level."
- **Peaking** — "You are in ideal race condition. Your recently reduced training load is allowing your body to recover and fully compensate for earlier training."
- **Overreaching** — "Your training load is very high and counterproductive. Your body needs a rest. You should give yourself time to recover by adding lighter training to your schedule."
- **Unproductive** — "Your training load is at a good level, but your fitness is decreasing. Try focusing on rest, nutrition, and stress management."
- **Strained** — "There is imbalance between your recovery and training load. It is a normal result after a hard training or major event."

Design read: this is the **label-only** counterpart to Training Readiness. Nine states is a lot; each ships a 1–2 sentence explanation plus a prescription. Garmin explicitly names a "No Status" cold-start state rather than faking a value.

### A4. HRV Status — 4 states, colour-coded, 3-week cold start

Verbatim **[F]** [source: https://www8.garmin.com/manuals/webhelp/GUID-F41EAFB3-6CC9-42DE-9C6C-9E358DBB0671/EN-US/GUID-9282196F-D969-404D-B678-F48A13D8D0CB.html]:

| State | Colour | Definition |
|---|---|---|
| **Balanced** | Green | "Your seven-day average HRV is within your baseline range." |
| **Unbalanced** | Orange | "Your seven-day average HRV is above or below your baseline range." |
| **Low** | Red | "Your seven-day average HRV is well below your baseline range." |
| **Poor** | (no colour) | "Your HRV values are averaging well below the normal range for your age." |

"The watch requires three weeks of consistent sleep data to display your heart rate variability status." **[F]**

Design read: personal-baseline framing, not population norms — except "Poor", which is the only age-normative state and deliberately gets **no colour** (it is out of the ramp).

### A5. Morning Report — the push-not-pull pattern

- Trigger: "your watch displays a morning report based on your normal wake time." **[F]**
- Interaction: "Press DOWN, and select ✓ to view the report" — **one press to open a pre-composed digest**. **[F]** [source: https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-4D26FDDC-63BD-4910-95B8-98937FEC2545.html]
- Contents: "weather, sleep, overnight heart rate variability status, and more" **[F]**
- Customisation: Appearance > Morning Report > Show Report / Edit Report ("customize the order and type of data that appears"). **[S]** [source: https://www8.garmin.com/manuals-apac/webhelp/forerunner965/EN-SG/GUID-423F8C0C-21F0-4AAA-AA14-BDB9E98E4CCE-1571.html]

This is the single most transferable pattern: **the day's body verdict is delivered, unprompted, at wake time, in the user's chosen order** — interaction cost ≈ 1 press, and the glance loop becomes the follow-up rather than the primary channel.

### A6. Sleep Score and Stress

- **Sleep score**: 0–100 summarising duration, quality, and HRV-derived recovery; occasional "Sleep Insights" text. Garmin's own blog confirms the 0–100 score and the insight concept but **does not publish the label bands** on that page. **[F]** [source: https://www.garmin.com/en-US/blog/health/garmin-sleep-score-and-sleep-insights/]
- The commonly cited bands **Excellent 90–100 / Good 80–89 / Fair 60–79 / Poor 0–60** come from third-party writeups, not a manual page I fetched — treat as **[S]** [source: https://the5krunner.com/garmin-features/sleep/sleep-score/]
- **Stress glance**: "displays your current stress level and a graph of your stress level for the last several hours"; UP/DOWN → START → DOWN for details **or** START to begin a Breathwork activity. **[F]** [source: https://www8.garmin.com/manuals/webhelp/GUID-F41EAFB3-6CC9-42DE-9C6C-9E358DBB0671/EN-US/GUID-DD8EE575-CC72-4829-B4C8-4BE1F8D3473E.html]
  - The glance **offers an action, not just a reading** — one press from "you are stressed" to a breathing exercise.
- Stress bands 0–25 rest / 26–50 low / 51–75 medium / 76–100 high appear consistently across manuals but I only have this via search snippet. **[S]** [source: https://www8.garmin.com/manuals/webhelp/GUID-D93137A9-B374-4A24-8A4D-A66C9AC91265/EN-US/GUID-9282196F-D969-404D-B678-F48A13D8D0CB.html]

### A7. Glance order

**Garmin does not fix a canonical order — the user owns it.** Reordering is first-class: "Select Appearance > Glances", then "select a glance, and press UP or DOWN to change the location of the glance in the loop", plus "Add" to insert one; touch models drag-and-drop. **[S]** [source: https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-61C825F5-5D80-413F-BA3F-CD8C51BB63F2.html]

**[U]** I could not verify a documented factory-default glance order for any specific model. Do not claim one.

### A8. Connect IQ glance design guidance

- Official *design* guidance page (developer.garmin.com/connect-iq/core-topics/glances/) is JavaScript-rendered; WebFetch returned navigation chrome only, twice. **Its content is [U] — I did not read it.**
- What I could verify from the API reference **[F]** [source: https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/GlanceView.html]:
  - GlanceView is "the class that represents a glance view which can be used to display the widget preview content in a restricted drawing context (dc) among other widgets."
  - It "behaves mostly like a regular WatchUi.View" with `onLayout()` / `onUpdate()`.
  - **No `WatchUi.Layer` support** (`addLayer`, `removeLayer`, `insertLayer`, `clearLayers` all unavailable) and no page control — "there is only one view allowed during said mode."
  - Architecturally: a glance is **one non-scrolling, non-paged, single-layer canvas.** That constraint is the design guidance.
- Community-sourced numbers (a guest developer post on Garmin's own forum, explicitly his experimental findings, **not** an official spec): glance canvas ~**151×63 to 191×63 px** on fēnix 6 variants; **32 kB memory limit** for glance views. **[S/partially F — post fetched, but figures are the author's, not Garmin's]** [source: https://forums.garmin.com/developer/connect-iq/b/news-announcements/posts/widget-glances---a-new-way-to-present-your-data]

A ~190×63 px letterbox with one drawing layer is the real constraint that produced the "big number + tiny sparkline + label" Garmin house style.

### A9. Why Body Battery is loved — real commentary

Reddit is **blocked to this crawler** (`reddit.com` refused), so no Reddit threads could be cited. Everything below is from fetched non-Reddit sources.

- Popularity drivers (verbatim): users value it as a "general wellness indicator" for tracking "energy flows and recoveries during the day"; frequent updates appeal to people monitoring daily stress; morning scores give "a rough sense of overnight recovery." **[F]** [source: https://the5krunner.com/garmin-features/sleep/body-battery/]
- Criticism, same fetched source, verbatim: the score "moves for too many reasons unrelated to exercise or readiness — digestion, posture, caffeine, temperature — to be reliably actionable for athletes," and it "measures nervous system state, not how you actually feel." **[F]**
  - Direct contradiction worth noting: Garmin's manual states caffeine and food have **no** impact **[F]**; the5krunner asserts caffeine moves it **[F]**. One of them is wrong; I cannot adjudicate. **[U]**
- The mechanism behind the affection, per fetched/secondary coverage: it "considers recovery just as much as exertion," and it is valued by people with **energy-limiting conditions** to avoid a "push-crash cycle." **[S]** [source: https://www.wareable.com/garmin/garmin-body-battery-explained-how-it-works-8734] [source: https://www.androidcentral.com/wearables/garmin-body-battery]

**The design lesson, not the folklore:** Body Battery works because it borrows an **already-universal mental model** (a phone battery: fills overnight, drains with use, you plan your day around it), renders as **one integer plus a slope**, and — critically — the slope means the glance answers "am I going up or down *right now*", which a static score cannot.

---

## B) FITBIT

### B1. Daily Readiness / Readiness Score — current spec

**[F]** [source: https://support.google.com/fitbit/answer/14236710?hl=en]

| Band | Range | Recommendation wording (verbatim) |
|---|---|---|
| **Low Readiness** | 29 or below | "Prioritize rest and active recovery techniques" |
| **Moderate Readiness** | 30–64 | "your body is showing typical recovery levels and can handle a workout today" |
| **High Readiness** | 65 or above | "may be ready for peak performance" |

- Cold start: "wear your device for 7 nights of sleep to establish a personalized baseline."
- Placement: "featured prominently in your Today tab metrics dashboard" in the app; on watch it is a **tile** — Sense 2 / Versa 4 via install, and on Pixel Watch 3/4 you "add the **Readiness** tile to your watch for a quick glance at your recovery status."
- **No colour language is documented on the official help page. [U]** Do not assume a Fitbit readiness colour ramp exists in spec.

Only **three bands vs Garmin's five** — and the labels are the band name repeated ("Low Readiness"), not a distinct verdict word. Fitbit sells the recommendation sentence, Garmin sells the label.

### B2. Original 2021 behaviour and cold-start requirements

**[F]** [source: https://www.dcrainmaker.com/2021/11/fitbit-readiness-review.html]

- First score required **4 days of continuous wear**, **at least 3 hours of sleep on at least four nights**, ideally three workouts; then **~10 more days** to calibrate.
- Three pillars: **Activity levels**, **Recent sleep** (weighted average of last four nights), **HRV** (measured during deep sleep).
- Score "won't change for the remainder of the day, no matter what you do that day." — a **once-daily verdict**, structurally opposite to Body Battery's live curve.
- Interaction: tap the score → per-pillar breakdown (Activity / Sleep / HRV) + previous-day Active Zone minutes → tap again → per-pillar explanation. **Two taps to full reasoning.**
- Prescription is quantified as an Active Zone Minutes target range (example given: "78-110 Active Zone minutes") plus suggested Premium guided workouts.
- At review time the score **was not on the wearable at all** except as a widget on Sense and Versa 3 — phone-first by design.
- DC Rainmaker also flagged **label inconsistency**: PR mockups showed 30 as "Low" while the shipping app showed 30 as "Good". A cautionary note about band-boundary copy.
- Note the band vocabulary changed over time: 2021 review reports **Low / Good / Excellent**; current Google Health help reports **Low / Moderate / High**. Both are cited above; the current one is authoritative.

### B3. Tiles on Sense / Versa

**[S]** — I did not fetch these pages, treat as weaker:
- Reach it by swiping left/right from the clock face. [source: https://blog.google/products/fitbit/fitbit-sense-2-versa-4]
- Manage via Fitbit app → profile → device → Gallery → My Tiles → Manage; drag by the grid handle to reorder; X → Remove to delete; Add tile → Install to add.
- **Hard cap of 8 installed tiles.** [source: https://community.fitbit.com/t5/Versa-4/How-do-I-change-the-tiles-on-my-Versa-4/td-p/5617868]

A capped, user-ordered, swipe-linear tile strip — structurally the same idea as Garmin's glance loop, with a scarcity limit that forces prioritisation.

**[U]** Fitbit watch-face design guidance (the old dev.fitbit.com SDK design docs) — not verified in this session.

---

## C) GENTLER STREAK

### C1. Awards and editorial standing

From the App Store product page **[F]** [source: https://apps.apple.com/us/app/gentler-streak-workout-tracker/id1576857102]:
- **2024 Apple Design Award — Social Impact**
- **2022 Apple Watch App of the Year**
- Editors' Choice, App of the Day; press coverage in The Verge, Forbes, TechCrunch
- Rated 4.7 / 5 across 8.8K ratings

Note: `apps.apple.com/us/story/id1647057981` (Apple's Watch App of the Year editorial) returned **404** to me; and the Apple Design Awards index page I fetched lists Gentler Stories only as the developer of a different 2024 finalist ("The Outsiders: Athlete Tracker"). The ADA Social Impact win is asserted by the developer's own App Store listing — **credible but self-reported [F, self-reported]**.

### C2. What appears first on the Apple Watch

**[F]** [source: https://docs.gentler.app/using-gentler-streak-on-your-apple-watch/overview-of-the-apple-watch-app-interface]

- Verbatim: "When you open the app, you'll first see your **daily message**, which provides context for your current fitness level and readiness."
- "swipe down from the daily message to access the Start a Workout screen"
- "Go Gentler" section sits **at the top of the Start a Workout screen**, offering "recommended workouts tailored to your current readiness"
- In-workout: heart-rate zones "at the top with colored indicators"; long-press a metric to change it; swipe right for music, left for pause/end

**Interaction cost: the verdict is screen one, zero taps. The prescription is one swipe. The workout is two.** This is the tightest verdict→action path of the three products.

### C3. The Activity Path — the visual verdict

**[F]** [source: https://docs.gentler.app/understanding-your-activity-path/what-is-the-activity-path]
- "The Activity Path is your personalized, visual guide to balancing fitness and recovery" — "the green shaded area on your home screen."
- "The green shaded area is your ideal range for activity" (Optimal Zone)
- "The bottom edge of the path represents the minimum level of activity needed to maintain or build fitness"
- "The top edge warns against pushing too hard"
- A "white line graph" shows actual activity over time
- Computed from "a balance of your recent workouts (considering their intensity, duration, and frequency) and your overall recovery"
- "not a static goal but a fluid recommendation that adapts daily based on your body's signals"

**[F]** [source: https://docs.gentler.app/understanding-your-activity-path/interpret-the-activity-path]
- **Upper zone** — "approaching the edge of your healthy activity levels. The app will likely suggest rest or a light, active recovery workout"
- **Middle zone** — "good balance between your workouts and recovery"
- **Lower zone** — "your body is well-rested and can handle a more intense workout"
- Visual: green band = the path; **white dotted line** = your actual activity; **dark green** upper section, **light green** lower section
- Views: daily, 10-day, 30-day; picker made "clearer which view is chosen" in the iOS 26 update **[F]** [source: https://docs.gentler.app/release-notes-and-announcements/gentler-stories-black-friday-cyber-monday-offers]

**The core idea:** the verdict is **positional, not numeric** — where your dot sits inside a band. Above the band = back off, inside = balanced, below = you have room. A single glyph encodes both the value and the judgement, which no score can do without a second element.

### C4. Verdict wording — what is and is not verified

**[U] — The exact three-label taxonomy "Go / Take it easy / Rest" is NOT verified.** I could not find it in the developer's own docs, the App Store description, the newsroom post, or the reviews I fetched. Do not build on that phrasing as a quotation.

What *is* verified about their language:
- Explicit anti-score stance, verbatim: they "avoid putting your daily form into a score, percentage, or body battery concept" and instead use "simple words, as in everyday life." **[F]** [source: https://gentlerstories.com/newsroom/20230216newwellbeing]
- Design intent, verbatim: they "translate those stats into words: digesting your data and presenting it as your daily fitness status and the state of your current wellbeing"; copy should be "supportive but not cheesy, motivating but not fake-hyped." **[F]** [source: https://www.sketch.com/blog/gentler-streak/]
- A real observed daily-message string: **"Kudos for Taking Action"** **[F]** [source: https://docs.gentler.app/using-gentler-streak-widgets/overview-of-available-gentler-streak-widgets]
- Manual override statuses (user-set, not computed): **Active / On a Break / Sick / Injured** **[F]** [source: https://docs.gentler.app/understanding-your-activity-path/what-is-the-activity-path]
- "sometimes the suggestion was simply to take it easy" — Apple's editorial phrasing as surfaced in search **[S]**, original story URL 404'd for me.

### C5. Colour and the readiness bar

- Whole system is **one hue with two values**: dark green (upper/warning side) and light green (lower/rested side), with white for your own data line. **[F]** [interpret-the-activity-path]
- In-workout readiness bar, verbatim: "the readiness bar (the green stripe with an orange heart) shows you in real-time how much buffer you have left to stay within healthy activity levels while you work out." **[F]** [source: https://www.sketch.com/blog/gentler-streak/]
  - **Orange is the only alarm colour, and it is a marker (a heart) travelling along a green track — not a red state.** No red anywhere in the verified material.
- Mascot: "Yorhart", a heart illustration by Sören Selleslagh, chosen to "resonate with everyone, regardless of age, gender, race, or body shape." **[F]** [same source]
- Reviewer-observed: "warm tones and friendly charts", "green path" = "right on track", dots above/below signal adjustment. **[F]** [source: https://neura.health/insight/gentler-streak-app-hands-on-review]

### C6. Wellbeing tab

- Seven metrics: sleeping heart rate (or resting HR when SHR unavailable), sleep duration, HRV, respiratory rate, oxygen saturation, wrist temperature. **[F]** [source: https://gentlerstories.com/newsroom/20230216newwellbeing]
- Card format, verbatim: "Each statistic in the Wellbeing tab is presented as a card-like widget that includes the current data, a 10-day trendline, and an indicator of whether the measurement is within normal ranges." **[F]** [source: https://www.macstories.net/news/fitness-app-gentler-streak-adds-wellness-tracking/]

**Value + trend + in-range indicator, per card.** Same triad as Garmin's glance (number + sparkline + band), but the judgement is per-metric rather than fused into one score.

### C7. Widgets and complications

Widgets, verbatim names **[F]** [source: https://docs.gentler.app/using-gentler-streak-widgets/overview-of-available-gentler-streak-widgets]:
- **Activity Status** — "displays your current position on the Activity Path"; small square + larger rectangular; shows messages like "Kudos for Taking Action"
- **Go Gentler** — "provides your most optimal daily action directly on your Home Screen"; workout type + intensity + duration + a **Start Workout** button
- **Health Metrics** — Small (status bars), Large (SHR, wrist temp, HRV, respiratory rate, SpO₂), Single Metric
- **Period** — "displays your current phase and readiness information"

**The widgets docs page lists no watch complications. [F]** A claim that the watch app ships "a small orange heart that shows readiness based on the Activity Path" as a favourite complication appears in search-surfaced secondary coverage only — **[S/U]**, and the App Store description mentions "Live activities and home screen widgets" without naming complications **[F]**. Older 9to5Mac coverage says complications exist and that setting an Activity Status "will remove the activity measurement so you don't feel compelled to be active when you should be recovering" **[S]** [source: https://9to5mac.com/2022/02/17/gentler-streak-apple-watch-app/]. **Treat the exact complication families as unverified.**

---

## Cross-cutting comparison

### What appears first
| | First thing shown | Presses to verdict | Presses to "why" |
|---|---|---|---|
| **Garmin Body Battery glance** | Integer (5–100) + multi-hour sparkline | 0 (scroll to glance) | 3 (START, DOWN, DOWN → factor list) |
| **Garmin Morning Report** | Pre-composed digest, pushed at wake time | 1 (DOWN + ✓) | in-report, user-ordered |
| **Garmin Training Readiness** | Score + colour + one-word label + imperative | 0 (its own glance) | in-glance factor list |
| **Fitbit Readiness** | Score 0–100 + band name in Today tab; tile on watch | 0 in app / 1 swipe on watch | 2 taps (pillars → explanations) |
| **Gentler Streak Watch** | Daily **message** (words, no score) | 0 | swipe down → Go Gentler prescription |

### Verdict-label vocabularies, side by side
- **Garmin Readiness:** Prime / High / Moderate / Low / Poor — with "Best possible", "Ready for challenges", "Good to go", "Time to slow down", "Let your body recover" **[F]**
- **Garmin Training Status:** No Status / Detraining / Recovery / Maintaining / Productive / Peaking / Overreaching / Unproductive / Strained **[F]**
- **Garmin HRV:** Balanced / Unbalanced / Low / Poor **[F]**
- **Garmin Body Battery:** very low / low / medium / high "reserve energy" **[F]**
- **Fitbit:** Low Readiness / Moderate Readiness / High Readiness **[F]**
- **Gentler Streak:** no fixed label set published; positional zones + a written daily message **[F]**

### Colour language
- **Garmin:** two separate systems. (1) **Verdict ramp** — purple → blue → green → orange → red across 5 bands, with "off-ramp" states (HRV "Poor") deliberately uncoloured. (2) **Timeline semantics** — blue = rest, orange = stress, green = timed activity, gray = unknown, reused identically in Body Battery and Stress. **[F]**
- **Fitbit:** no documented colour spec on the official help page. **[U]**
- **Gentler Streak:** monochromatic green band (dark green upper / light green lower), white for the user's own line, orange only as a single moving marker. No red. **[F]**

### Three transferable patterns for Laso
1. **Push the verdict, don't make them fetch it.** Garmin's Morning Report costs one press and arrives at wake time, with user-controlled section ordering. **[F]**
2. **Number alone is never the verdict.** Garmin pairs score + colour + one word + a 2–4 word imperative on the same screen; Fitbit pairs score + a recommendation sentence; Gentler Streak drops the number entirely and ships only the sentence. All three refuse a bare integer.
3. **Design the cold start as a named state.** Garmin ships "No Status" and a stated 3-week HRV requirement; Fitbit states 7 nights for baseline. Neither invents a value to fill the screen. **[F]**

### Explicitly unverified — do not cite as fact
- Garmin's official Connect IQ **glance design guidance** page content (JS-rendered, unreadable to me).
- Any **factory-default Garmin glance order**.
- Garmin **sleep score band labels** (Excellent/Good/Fair/Poor + ranges) from an official manual page.
- Garmin **stress band ranges** from a fetched manual page (snippet only).
- **Fitbit readiness colour language**; Fitbit watch-face/SDK design guidelines.
- Gentler Streak's exact **"Go / Take it easy / Rest"** label set, and its **watch complication families**.
- **Reddit user commentary** — reddit.com is blocked to this crawler; no Reddit source could be fetched.
- Caffeine's effect on Body Battery: Garmin's manual and the5krunner directly contradict each other.

Confidence: 84/100 — every quoted string above came from a page I fetched in this session and is tagged [F]; the score is held below 90 because Garmin's official Connect IQ glance design-guidance page is JavaScript-rendered and returned only nav chrome on two attempts, Garmin's default glance order and sleep-score band labels are unconfirmed by any manual page I opened, Fitbit's tile mechanics and stress-band ranges rest on search snippets rather than fetched pages, Reddit was hard-blocked so the "why users love Body Battery" evidence is thinner than requested, and Gentler Streak's exact verdict labels and watch complications are absent from their own docs. | Source: internet

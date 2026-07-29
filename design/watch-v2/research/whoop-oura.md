# WHOOP vs Oura — Score and Surface Philosophy

# WHOOP & Oura — Wearable App Experience and Score Philosophy

Research date: 2026-07-29. Every claim below is tied to a page actually fetched. Items marked **unverified** could not be confirmed from a fetched source.

**Fetch note:** `support.whoop.com` and `whoop.com/thelocker` return HTTP 403 to automated fetches. WHOOP facts below come from `developer.whoop.com`, the WHOOP App Store listing, and detailed third-party reviews (DC Rainmaker, the5krunner, michaelkummer). Oura facts come mostly from Oura's own support + blog, which are fetchable.

---

## A) WHOOP

### A1. Score model, ranges, colour language

| Score | Range | Bands | Source |
|---|---|---|---|
| **Recovery** | 0–100% | **Green 67–100%** "well recovered and primed to perform" · **Yellow 34–66%** "maintaining and ready to take on moderate amounts of strain" · **Red 0–33%** "Rest is likely what your body needs" | [source: https://developer.whoop.com/docs/whoop-101/] |
| **Strain** | 0–21, **based on the Borg Scale of Perceived Exertion** | **Light 0–9** · **Moderate 10–13** · **High 14–17** · **All Out 18–21** | [source: https://developer.whoop.com/docs/whoop-101/] |
| **Sleep Performance** | 0–100% | bands not published in fetched sources — **unverified** | [source: https://apps.apple.com/us/app/whoop-performance-optimization/id933944389] |
| **Stress** | 0–3 real-time | bands **unverified** | [source: https://apps.apple.com/us/app/whoop-performance-optimization/id933944389] |

**Critical design fact — Strain is non-linear:** "Strain is not on a linear scale. It takes more stress to move from a score of 16 to 17 than 4 to 5." [source: https://developer.whoop.com/docs/whoop-101/]

**Range discrepancy worth noting:** the developer docs say Recovery is "a percentage between 0 - 100%", while the App Store marketing copy says "Recovery: Daily score (1-99%)". Both are WHOOP-official. [sources: https://developer.whoop.com/docs/whoop-101/ , https://apps.apple.com/us/app/whoop-performance-optimization/id933944389]

Recovery inputs: HRV, resting heart rate, respiratory rate, sleep duration/quality, skin temperature, SpO₂, and menstrual cycle phase when applicable [source: https://developer.whoop.com/docs/whoop-101/]. DC Rainmaker's hands-on finding is that **HRV dominates**: "the singular difference between a green and yellow score is simply keeping my HRV value above 54" [source: https://www.dcrainmaker.com/2021/11/whoop-platform-review.html].

**Day Strain vs workout Strain:** Day Strain accumulates continuously across the whole day; workouts carry their own Strain. The developer doc does not formally define a separate "Activity Strain" metric [source: https://developer.whoop.com/docs/whoop-101/].

### A2. What is shown FIRST

WHOOP has redesigned the home screen at least twice and the answer changed each time.

**2021–2022 (DC Rainmaker era):** the dashboard put **Strain at the top** as the lead metric; tapping it opened "a big oversized number" [source: https://www.dcrainmaker.com/2021/11/whoop-platform-review.html]. Navigation was swipe-based: "swipe left and right to toggle between the overview, strain, recovery and sleep screens" [source: https://michaelkummer.com/whoop-review/].

**2023 redesign:** home screen top = battery charge status, then a personalised daily overview of **Strain, Recovery, and Sleep scores** plus heart rate, HRV and respiratory rate. Layout was a "4×2 matrix"; swipe left/right for views, swipe up/down for more or less detail. Reviewer verdict: "shows more data on the screen," which new users may find "daunting," and navigation to detail "is not always intuitive." [source: https://the5krunner.com/2023/03/28/new-whoop-home-screen-looks-pretty-but-is-it-as-intuitive/]

**2025 current state (WHOOP 5.0/MG):** the home tab leads with **five primary widgets — "Strain, Recovery, Sleep, and the Stress and Health Monitors — all clickable for deeper insights"**, followed by sections **My Day, My Plan, and My Dashboard**, with a user-customisable dashboard (e.g. steps, VO₂ max). Stress + Health Monitors were promoted onto home in May 2025 for Peak/Life tiers. [source: https://the5krunner.com/2025/10/31/2026-whoop-5-0-mg-review-discount-accuracy-strain-recovery-athletes/]

**October 2025 revamp:** WHOOP moved "from a layout that used multiple tabs (swipe left and right) to a more dense, scrollable home page." The `+` action button moved to a central, prominent position (it was "poorly placed and easily overlooked"); the Coach button moved to the right-hand corner of the bottom menu bar and stays visible when reviewing previous days. [source: https://the5krunner.com/2025/10/15/whoop-homescreen-gets-a-revamp/]

**WHOOP's own stated reasoning for what comes first: unverified.** Their explanation lives on `whoop.com/thelocker/the-all-new-whoop-home-screen/` and `support.whoop.com/.../The_All-New_Home`, both of which returned 403. Search snippets attribute to WHOOP the claim that the redesign "puts the metrics that matter most — Sleep, Recovery, and Strain — front and center, with new dials that make daily trends easier to interpret," but this snippet was **not** confirmed by a fetch.

### A3. Named features

- **Strain Coach** — set a target Strain value for the day and keep working out until you hit it [source: https://www.dcrainmaker.com/2021/11/whoop-platform-review.html]. In-workout it shows "live data — including your strain, heart rate and calories burned" [source: https://michaelkummer.com/whoop-review/]. So Strain Coach is a *live target-chasing* mechanic, not a static score.
- **Sleep Coach** — user sets a wake time; WHOOP computes required bedtime and duration against three intent levels: **"peak," "perform" or "get by"** [source: https://michaelkummer.com/whoop-review/]. Sleep need is adjusted by naps ("reduce your sleep need by that amount" the following night) and by Sleep Debt + previous day's activity [sources: https://www.dcrainmaker.com/2021/11/whoop-platform-review.html , https://developer.whoop.com/docs/whoop-101/].
- **Haptic alarm** — the band buzzes; alarm can be set to an exact time, to a sleep goal, or **"once Whoop thinks recovery is in the green."** [source: https://www.dcrainmaker.com/2021/11/whoop-platform-review.html]
- **Health Monitor** — five vitals: respiratory rate, SpO₂, resting heart rate, HRV, skin temperature; shows whether each is inside or outside your baseline range [sources: https://www.dcrainmaker.com/2021/11/whoop-platform-review.html , https://michaelkummer.com/whoop-review/]. Anomaly warnings appear "right on the home screen" (example given: elevated RHR after alcohol) [source: https://michaelkummer.com/whoop-review/].
- **WHOOP Age / Healthspan** — nine metrics: sleep consistency, sleep duration, time in HR zones 1–3, time in HR zones 4–5, strength activity time, steps, VO₂ max, resting heart rate, lean body mass. **WHOOP Age** is a ~6-month slow-moving view; **Pace of Aging** is the fast signal, ranging **−1x to 3x** (3x = ageing faster, −1x = reversing). *Note: these numbers come from a search-result summary of whoop.com pages that 403'd on fetch — treat the −1x/3x range as **partially unverified**.* App Store copy does confirm "Healthspan: A powerful way to quantify your age and slow your Pace of Aging" [source: https://apps.apple.com/us/app/whoop-performance-optimization/id933944389].
- **Daily Outlook** — tap "Daily Outlook" on the home screen; contains recovery percentage, RHR, HRV, Strain suggestions, contextual insights (e.g. "your resting heart rate is trending lower") and comparisons to other members. It **replaced the old chatbot-first interaction**: "Instead of the old chatbot setup, you now get a daily overview that's way more useful and straight to the point." Rolled out in stages from Jan 2025. [source: https://gadgetsandwearables.com/2025/01/24/whoop-daily-outlook/] the5krunner calls it "an interactive overview of your day" [source: https://the5krunner.com/2025/10/31/2026-whoop-5-0-mg-review-discount-accuracy-strain-recovery-athletes/]
- **WHOOP Coach** — AI, accessed via the small "W" logo in the bottom menu bar; updated in 2025 to **keep a memory of your conversations over time** [source: https://the5krunner.com/2025/10/31/2026-whoop-5-0-mg-review-discount-accuracy-strain-recovery-athletes/].
- **Behaviors** — tracks "over 160+ daily habits and behaviors" [source: https://apps.apple.com/us/app/whoop-performance-optimization/id933944389].

### A4. WHOOP on the wrist / Apple Watch

- **The WHOOP band has no screen at all.** "The Whoop 4.0 pod, as with past units, has no display on it" — all interaction is in the phone app. [source: https://www.dcrainmaker.com/2021/11/whoop-platform-review.html] The only on-body output channel is haptics.
- **No Apple Watch app.** The WHOOP App Store listing declares compatibility with **iPhone (iOS 17.0+) and iPad (iPadOS 17.0+) only — no watchOS entry** [source: https://apps.apple.com/us/app/whoop-performance-optimization/id933944389]. DC Rainmaker notes "Whoop have resisted integrations with other wearables" [source: https://www.dcrainmaker.com/2023/01/apple-integrations-closer.html]. **Therefore: no WHOOP complications, and no WHOOP data on any Apple watch face.**
- **iOS widgets exist instead.** WHOOP ships iOS home-screen widgets, lock-screen widgets and Live Activities. Reported metric choices for lock-screen widgets: sleep performance, recovery percentage, performance summary (calories, last night's HRV, today's average HR), daily summary (sleep performance + recovery percentage + strain), strain score, or strap battery. Requires iOS 16+. *These specific widget option names come from search summaries of wareable/smartwatchinsight; the wareable page 403'd on fetch — **partially unverified**.* the5krunner independently confirms "iOS widgets are a neat way to show live, daily strain, recovery and sleep data" plus a "Whoop Live Lock Screen" [source: https://the5krunner.com/2025/10/31/2026-whoop-5-0-mg-review-discount-accuracy-strain-recovery-athletes/].

### A5. Notifications

- Haptic alarm on the band: exact time / sleep goal reached / green recovery reached [source: https://www.dcrainmaker.com/2021/11/whoop-platform-review.html].
- Health Monitor anomaly warnings surfaced on the home screen [source: https://michaelkummer.com/whoop-review/].
- Full push-notification catalogue and morning-delivery timing: **unverified** (lives on the 403'd support site).

### A6. What WHOOP intentionally does NOT put on the wrist

Everything. There is no display and no watchOS surface; the wrist device is a pure sensor + haptic actuator. All scores, coaching, and history are phone-only. [sources: https://www.dcrainmaker.com/2021/11/whoop-platform-review.html , https://apps.apple.com/us/app/whoop-performance-optimization/id933944389]

---

## B) OURA

### B1. Score model, ranges, colour/label bands

All three primary scores share **one identical 0–100 scale and one shared band vocabulary** — this is Oura's biggest UX advantage over WHOOP.

> "Readiness, Activity, and Sleep Scores — and their contributors — are rated on a scale of 0-100."
> **85–100 Optimal · 70–84 Good · 60–69 Fair · 0–59 Pay Attention**
> [source: https://support.ouraring.com/hc/en-us/articles/360025589793-Readiness-Score]

Sleep Score uses the same bands (85–100 Optimal, 70–84 Good, 60–69 Fair, <60 Pay Attention) with seven contributors: Total Sleep, Efficiency, Restfulness, REM Sleep, Deep Sleep, Latency, Timing. *Band figures for Sleep confirmed by the Readiness support article's "all three scores" statement; the seven contributor names come from a search summary of support.ouraring.com/.../360025445574 — **contributor list partially unverified**.*

**Readiness contributors:** Resting Heart Rate, Body Temperature, Sleep Quality, Physical Movement, HRV, Activity Balance, HRV Balance, Sleep Balance [source: https://support.ouraring.com/hc/en-us/articles/360025589793-Readiness-Score].

**Non-score states (Oura deliberately avoids numbers here):**

| Feature | States (exact labels) | Source |
|---|---|---|
| **Daytime Stress** | **Stressed · Engaged · Relaxed · Restored** | [https://support.ouraring.com/hc/en-us/articles/21205822135315-Daytime-Stress] |
| **Resilience** | **Exceptional · Strong · Solid · Adequate · Limited** (14-day average, not a daily value) | search summary of https://support.ouraring.com/hc/en-us/articles/25358829055251-Resilience — **label list verified only via search snippet, not fetched** |
| **Symptom Radar** | **No signs · Minor signs · Major signs** | [https://ouraring.com/blog/symptom-radar/] |
| **Cardiovascular Age** | expressed in years vs chronological age: **younger = −5 and below · aligned = −5 to +5 · older = +5 and higher** | [https://ouraring.com/blog/cardiovascular-age/] |
| **My Health / Health Areas** | **Thriving (blue) · Looking Good (green) · Worth Watching (yellow) · Needs Care (red)**, 90-day trend | [https://support.ouraring.com/hc/en-us/articles/42987005571859-How-to-Use-the-Oura-App] |

**Daytime Stress mechanics:** updates every 15 minutes while awake, wearing the ring, and relatively inactive; uses heart rate, HRV, motion, average body temperature; requires at least five days of continuous wear before results appear [source: https://support.ouraring.com/hc/en-us/articles/21205822135315-Daytime-Stress].

**Symptom Radar mechanics:** monitors skin temperature, average temperature trends, respiratory rate, resting heart rate, HRV, inactive time, plus age. "If there is a clear sign of strain, it will be spotlighted on the **Today** screen the following morning." Explicitly not optimal for pre-existing conditions; reduced accuracy in pregnancy and disable-able; not a medical device. [source: https://ouraring.com/blog/symptom-radar/]

**Cardiovascular Age mechanics:** pulse wave velocity estimated from infrared PPG; algorithm built on anonymised data from hundreds of thousands of members plus clinical studies with 600 participants; requires **14 nights** of data; lives in the **My Health** tab. [source: https://ouraring.com/blog/cardiovascular-age/]

### B2. What is shown FIRST — and Oura's stated reasoning

Oura collapsed **five tabs (Home, Readiness, Sleep, Activity, Resilience) into three (Today, Vitals, My Health)** [source: https://ouraring.com/blog/new-oura-app-experience/].

**Stated reasoning, verbatim-level:**
- Problem: as features accumulated beyond sleep/readiness/activity (stress, resilience, heart health, women's health), members struggled to extract meaningful insights [source: https://ouraring.com/blog/new-oura-app-experience/].
- "The newly designed Oura App helps distill the many health features into easily digestible insights, ready at your fingertips at any time of day." [source: https://ouraring.com/blog/new-oura-app-experience/]
- "Understanding your health shouldn't be complicated." [source: https://ouraring.com/blog/new-app-design/]
- **The "one big thing" principle:** the Today tab focuses users on "one big thing" — "the most important score or insight you need right now," giving "a clear, quick snapshot of your body's readiness and any unusual key metrics." [source: https://ouraring.com/blog/new-app-design/]
- Today "will update throughout that day. Each day will look different and contain a different set of features depending on what is most timely and relevant to you" — i.e. **the first screen is dynamic, not a fixed dashboard**. [source: https://ouraring.com/blog/new-oura-app-experience/]

**Today screen order, top to bottom** (official support doc):
1. Shortcuts to main metrics: **Readiness, Sleep, Activity, Cycle day/Pregnancy, Heart rate, Stress, Glucose**
2. Important updates and insights
3. Action items
4. Recent events
5. What's new
[source: https://support.ouraring.com/hc/en-us/articles/42987005571859-How-to-Use-the-Oura-App]

The launch blog phrases it as: Sleep, Readiness and Activity Scores at the top, plus shortcuts to heart rate, Daytime Stress and Cycle Insights [source: https://ouraring.com/blog/new-oura-app-experience/].

**Vitals tab:** organised cards grouped by health area — readiness, sleep, activity, stress, women's health, heart health, metabolic health, core metrics; anchored to personalised baselines; data updates as it syncs; calendar navigation; **user-reorderable via a pencil icon** [source: https://support.ouraring.com/hc/en-us/articles/42987005571859-How-to-Use-the-Oura-App]. Colour coding signals body state [source: https://ouraring.com/blog/new-app-design/].

**My Health tab:** Health Areas 90-day chart with the four rating levels; health area hubs (Sleep Health, Stress Management, Heart Health, Menopause Insights, Cycle Regularity); "Habits and Routines"; "A Deeper Look" containing Health Radar, reports, Health Panels, Chronotype. Explicitly holds the metrics "which aren't designed to be used every day" — Resilience, VO₂ Max, Cardiovascular Age. [source: https://support.ouraring.com/hc/en-us/articles/42987005571859-How-to-Use-the-Oura-App]

**This is the key architectural idea for a watch redesign:** Oura splits by *cadence* — Today = right now, Vitals = this week vs baseline, My Health = months/years. Slow metrics are deliberately buried two tabs deep.

### B3. Oura's Apple Watch app

The Oura App Store listing confirms **watchOS 9.0+** support (and visionOS 1.0+) [source: https://apps.apple.com/us/app/oura/id1043837948].

**Screens:** the watch app is described by Oura's support doc and by DC Rainmaker as "a mirror of Oura's iPhone app" with three data categories, each drillable:
1. **Readiness** — Score, heart rate metrics, temperature, respiratory rate, contributors
2. **Sleep** — Score, duration metrics, efficiency, contributors
3. **Activity** — Score, goal progress, burn, time, steps, contributors
[sources: https://www.dcrainmaker.com/2023/01/apple-integrations-closer.html , https://support.ouraring.com/hc/en-us/articles/12741671118739-Apple-Watch-Complications-Companion-App]

Also visible on the watch: heart rate, average body temperature, **ring battery level** [source: https://9to5mac.com/2023/01/25/oura-ring-now-offers-apple-watch-integration-with-new-app-complications-more/].

**Exact tab ordering on the watch: unverified** — the support doc does not name an order; DC Rainmaker lists Readiness → Sleep → Activity.

**Complications shipped:** described by *shape*, not by watchOS family name — **circular, rectangular, and corner** complications. Data available in complications: Scores, activity goal progress, ring battery level, and graphs for heart rate, movement, sleep, and average body temperature. Tapping a complication opens the app. [sources: https://support.ouraring.com/hc/en-us/articles/12741671118739-Apple-Watch-Complications-Companion-App , https://www.dcrainmaker.com/2023/01/apple-integrations-closer.html]
**Which watchOS complication families map to which shapes: unverified** — Oura's doc does not state it.

**Documented watch limitations (important for a watch redesign):**
- "Some user actions such as recording activity heart rate or adding a tag are not available through the Apple Watch companion app."
- "Oura data does not automatically update on the Apple Watch app in real time."
- The watch app **does not pair to the ring directly** — sync goes through the iPhone.
- In Rest Mode, the Activity Score is disabled.
[source: https://support.ouraring.com/hc/en-us/articles/12741671118739-Apple-Watch-Complications-Companion-App]
- No starting workouts from the watch; no real-time activity tracking; limited daytime score updates; "The updating of these scores is super laggy" and complications may show null values until a manual phone sync completes [source: https://www.dcrainmaker.com/2023/01/apple-integrations-closer.html].

### B4. Oura widgets (phone)

- **iOS home screen (Sleep Graph):** Small = sleep stages · Medium = sleep stages + sleep/wake time · Large = sleep stages + sleep/wake time + ring battery status.
- **iOS lock screen (iOS 16+):** Sleep / Readiness / Activity Scores, ring battery level, activity goal progress (active calorie burn or steps), and graphs for sleep stages, daily movement, heart rate, average body temperature.
- **Android home screen:** combined 3-score widget, individual Sleep / Readiness / Activity widgets, ring battery level. Requires Gen3 or Oura Ring 4 and app 7.3.0+.
[source: https://support.ouraring.com/hc/en-us/articles/11785597429907-Oura-Widgets]

### B5. Oura notifications — full documented list

| Notification | Trigger / timing |
|---|---|
| Battery Level | 2–3 hours before your bedtime, when ring battery is low. **On by default.** |
| Charging Case Battery Status | case battery + cycle updates (timing not specified) |
| Inactivity Alert | after **50 minutes** of inactivity. **On by default.** |
| Activity Progress | periodic reminders through the day on daily activity goal progress |
| Bedtime | **one hour prior** to your suggested bedtime |
| Insight | when a new insight is available, e.g. weekly summary |
| Glucose (Stelo integration) | after meals/activities, for "time above range" |
[source: https://support.ouraring.com/hc/en-us/articles/360025579173-Managing-Your-Notifications]

Bedtime Guidance additionally surfaces as a **card on the Today tab** roughly an hour before the recommended window opens, and requires two weeks of consistent data before recommendations appear. *This detail comes from a search summary of ouraring.com/blog/ideal-bedtime and support.ouraring.com/.../360025445154 — **partially unverified**, though the "one hour prior" push timing is confirmed by the fetched notifications doc.*

### B6. What Oura intentionally does NOT put on the wrist

- No tagging, no manual activity HR recording [source: https://support.ouraring.com/hc/en-us/articles/12741671118739-Apple-Watch-Complications-Companion-App].
- No workout start, no live activity tracking [source: https://www.dcrainmaker.com/2023/01/apple-integrations-closer.html].
- No real-time data — the watch is a read-only mirror behind a phone sync [source: https://support.ouraring.com/hc/en-us/articles/12741671118739-Apple-Watch-Complications-Companion-App].
- Long-horizon metrics (Resilience, VO₂ Max, Cardiovascular Age, Health Radar, reports) are not surfaced on the watch — they live in the phone's My Health tab and are explicitly "not designed to be used every day" [source: https://support.ouraring.com/hc/en-us/articles/42987005571859-How-to-Use-the-Oura-App].

---

## C) Direct contrast — the two philosophies

| Dimension | WHOOP | Oura |
|---|---|---|
| Wrist surface | **None.** No display, no watchOS app, no complications. Haptics only. [https://www.dcrainmaker.com/2021/11/whoop-platform-review.html , https://apps.apple.com/us/app/whoop-performance-optimization/id933944389] | Full watchOS companion app + circular/rectangular/corner complications [https://support.ouraring.com/hc/en-us/articles/12741671118739-Apple-Watch-Complications-Companion-App] |
| Scale consistency | Three different scales: Recovery 0–100%, Strain 0–21 (non-linear, Borg), Stress 0–3 | One scale for everything user-facing: 0–100 with four shared labels |
| Colour language | Green/Yellow/Red on Recovery, at fixed cutoffs 67 / 34 | Optimal/Good/Fair/Pay Attention at 85 / 70 / 60; separate 4-colour Thriving→Needs Care for long-term areas |
| First screen | Dense fixed dashboard: 5 tappable widgets + My Day / My Plan / My Dashboard [https://the5krunner.com/2025/10/31/2026-whoop-5-0-mg-review-discount-accuracy-strain-recovery-athletes/] | Dynamic "one big thing" — "the most important score or insight you need right now" [https://ouraring.com/blog/new-app-design/] |
| Tab count trend | Moved *away* from tabs to a single dense scrolling page (Oct 2025) [https://the5krunner.com/2025/10/15/whoop-homescreen-gets-a-revamp/] | Moved *from 5 tabs to 3* by cadence: Today / Vitals / My Health [https://ouraring.com/blog/new-oura-app-experience/] |
| Slow metrics | WHOOP Age / Healthspan promoted into a dedicated Health tab | Resilience, VO₂ Max, Cardiovascular Age deliberately demoted to My Health, "not designed to be used every day" |
| Illness signal | Health Monitor: 5 vitals in/out of baseline, warning on home screen | Symptom Radar: No signs / Minor signs / Major signs, spotlighted on Today **the following morning** |
| Coaching mechanic | Strain Coach = live target to chase; Sleep Coach = peak/perform/get by; Daily Outlook replaced the chatbot; Coach has conversation memory | Bedtime Guidance card + push one hour before window; Oura Advisor AI |
| Engagement hooks documented | Daily Outlook incl. peer comparison; 160+ behaviours to log; haptic wake on green recovery | Bedtime nudge (1h before), inactivity nudge (50 min), weekly summary insight, activity goal progress; **no streak mechanic found in fetched sources — unverified** |

## D) Explicit gaps (do not fill these from memory)

1. WHOOP's own written rationale for home-screen ordering — **unverified**, all WHOOP-owned pages 403.
2. WHOOP Sleep Performance band cutoffs and Stress 0–3 band labels — **unverified**.
3. WHOOP push notification catalogue and delivery times — **unverified**.
4. Pace of Aging −1x…3x range and the nine-metric list — from search snippets of blocked WHOOP pages, **partially unverified**.
5. WHOOP iOS widget metric-option list — from blocked wareable page, **partially unverified**.
6. Oura watch tab order, and the mapping of Oura complication shapes to watchOS families — **unverified**.
7. Oura Resilience 5-label list — snippet-level from a support URL that was not fetched directly, **partially unverified**.
8. Streak mechanics in either app — **not found in any fetched source**.

## Sources fetched

- https://developer.whoop.com/docs/whoop-101/
- https://apps.apple.com/us/app/whoop-performance-optimization/id933944389
- https://www.dcrainmaker.com/2021/11/whoop-platform-review.html
- https://www.dcrainmaker.com/2023/01/apple-integrations-closer.html
- https://the5krunner.com/2025/10/31/2026-whoop-5-0-mg-review-discount-accuracy-strain-recovery-athletes/
- https://the5krunner.com/2025/10/15/whoop-homescreen-gets-a-revamp/
- https://the5krunner.com/2023/03/28/new-whoop-home-screen-looks-pretty-but-is-it-as-intuitive/
- https://gadgetsandwearables.com/2025/01/24/whoop-daily-outlook/
- https://michaelkummer.com/whoop-review/
- https://apps.apple.com/us/app/oura/id1043837948
- https://support.ouraring.com/hc/en-us/articles/360025589793-Readiness-Score
- https://support.ouraring.com/hc/en-us/articles/42987005571859-How-to-Use-the-Oura-App
- https://support.ouraring.com/hc/en-us/articles/12741671118739-Apple-Watch-Complications-Companion-App
- https://support.ouraring.com/hc/en-us/articles/21205822135315-Daytime-Stress
- https://support.ouraring.com/hc/en-us/articles/360025579173-Managing-Your-Notifications
- https://support.ouraring.com/hc/en-us/articles/11785597429907-Oura-Widgets
- https://ouraring.com/blog/new-oura-app-experience/
- https://ouraring.com/blog/new-app-design/
- https://ouraring.com/blog/symptom-radar/
- https://ouraring.com/blog/cardiovascular-age/
- https://9to5mac.com/2023/01/25/oura-ring-now-offers-apple-watch-integration-with-new-app-complications-more/

Confidence: 82/100 — Oura side is strong (11 pages fetched directly from Oura's own support/blog plus App Store and DC Rainmaker, so scores, bands, tabs, notifications, complications and watch limitations are first-party verified). WHOOP side is weaker because support.whoop.com and whoop.com/thelocker returned 403 on every attempt, so WHOOP's own stated home-screen rationale, Sleep Performance bands, Stress 0-3 labels, the push-notification catalogue, the Pace of Aging -1x/3x range and the iOS widget metric list rest on search snippets or third-party reviews rather than fetched first-party pages; those eight items are flagged as unverified in section D. | Source: internet

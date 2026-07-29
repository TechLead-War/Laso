# Welltory, Heart Analyzer, Ultrahuman + 5 More

# Apple Watch Health App Research — Welltory, Heart Analyzer, Ultrahuman, + 5 others

All facts below come from pages fetched this session. Anything not fetched is marked **unverified**.

---

## 0) Platform constraints that shape every design below

| Fact | Value | Source |
|---|---|---|
| Typical watch interaction length | "most watch interactions last between two to three seconds" | [source: https://significa.co/blog/designing-better-ux-for-apple-watch] |
| Complication glance frequency | "about 60 to 80 times a day, albeit for just a blink" | [source: https://significa.co/blog/designing-better-ux-for-apple-watch] |
| Apple HIG line quoted | "Design a complication that unobtrusively provides useful information at a glance." | quoted via [source: https://significa.co/blog/designing-better-ux-for-apple-watch] — **direct developer.apple.com HIG page returned only a title on fetch, so the primary URL is unverified** |
| Complication refresh cap | "Apple limits apps to only being able to update complications 4 times per hour (or every 15 minutes)" | [source: https://athlytic.github.io/athlyticapp/troubleshooting/] |
| Feature filter for watchOS | time-sensitive value, glanceability, hands-free necessity, completion in under 30 seconds, frequency of use | [source: https://significa.co/blog/designing-better-ux-for-apple-watch] |

The 15-minute cap is load-bearing for Laso: any wrist score that changes faster than 15 min will visibly disagree with the phone. Athlytic ships that fact as user-facing documentation rather than treating it as a bug.

---

## A) Welltory

### Measurement flow on the wrist — the key finding
**Welltory does not run its own on-wrist measurement UI. It piggybacks on Apple's Breathe/Mindfulness app.**

Exact flow [source: https://help.welltory.com/en/articles/4241383-taking-measurements-with-your-apple-watch]:
1. "press the **Digital Crown** to go to the **Home** screen"
2. Open Breathe (or Mindfulness, depending on watchOS version)
3. "Turn the **Digital Crown** to set the measurement length to at least **3 minutes**"
4. Start it
5. "open Welltory and check out your feed to see the results"

- **Session length**: minimum **3 minutes**; "at least **5 minutes**" recommended for frequency-domain analysis.
- **During measurement**: "try not to move, don't control your breath, and keep silent." Breathe naturally — do not follow the Breathe animation.
- **Automatic path**: Apple Watch records HRV on its own when calm; those results appear in the feed with no user action.
- **Quota**: free tier = one measurement per day (5 a.m. to 5 a.m.); Premium = unlimited.

Accuracy protocol [source: https://help.welltory.com/en/articles/3361520-how-to-take-accurate-heart-rate-variability-measurements]:
- Best morning window: "between 5.00 AM and 12.00 PM"
- After waking: "stay in bed for 5–10 minutes"
- After activity: "wait for 10–15 minutes to let your heart rate get back to normal"
- Take it "after waking up, but before working out, taking a shower, or eating breakfast"
- Target measurement accuracy: "95–100%"
- Baseline training: "usually takes a week or two"
- Invalidators: moving, talking, controlled breathing, unstable HR, arrhythmia episodes

### First screen / screen list (iPhone "Today Screen")
[source: https://help.welltory.com/en/articles/8907642-today-screen]
- **Health** is "always at the top of your home screen" — a colored heart (green / yellow / red) that "reflects your current state and changes the background of the main screen." The whole screen's background color IS the score.
- Card order below it: **Health → Battery → Stress → Sleep Analysis → Activity Report → Workout Report**
- Battery's morning charge is computed from "resting heart rate upon waking, along with the quality and quantity of your sleep"
- Stress "updates in real time throughout the day"
- Activity Report uses an "Activity Mountain" visualization
- Today Screen is "exclusively available to iOS platform users who use Apple Watch or Oura"

Full report catalogue [source: https://help.welltory.com/en/articles/3352351-overview-of-the-welltory-app]: Battery, Stress, Sleep Analysis, Activity, Health, Heartbeat, Workout, Blood Pressure.

### Energy / Stress / Productivity outputs
- Both stress and energy derive from HRV — "the variation in the time intervals between heartbeats (RR intervals)". **The help page does not disclose which HRV metrics (SDNN/RMSSD/pNN50), the numeric range, or the band thresholds** [source: https://help.welltory.com/en/articles/3357744-what-are-stress-and-energy-calculating-based-on]. Scale/labels: **unverified**.
- Result screen returns two message types: a "chart message" with metrics from scientific formulas, and a "liquid message" showing the three scores **Stress, Energy, and Health** plus key insights [source: https://help.welltory.com/en/articles/4253039-how-do-i-make-sense-of-my-measurement-results].
- **Productivity** = productive-vs-distracting app time compared to your typical workday, plus focus, plus schedule. **Unverified** — this came from a search-result summary of `help.welltory.com/en/articles/8019779-productivity-analysis`, which I did not fetch directly.

### Watch app + complications
Native watch app confirmed: "Welltory has it's own Apple Watch app that shows you the latest HRV measurement insights on your watch face as well as personalized heart rate zone analysis for your workouts" [source: https://welltory.com/devices/apple-watch-hrv-app/].

Complication list [source: https://help.welltory.com/en/articles/4241383-taking-measurements-with-your-apple-watch]:
- **HRV Monitoring** (large and small)
- **Battery** (large and small)
- **Stress** (small icon)
- **Health** (small icon)
- **All-in-one** — Battery + Stress + Health, **large block only**
- Add flow offers: "Battery, HRV Monitoring, Stress, Health, or Workout"
- **Update cadence: "The data is updated approximately every half hour, about 50 times a day."**

Workout screen on watch [source: https://help.welltory.com/en/articles/10329671-new-workout-report-for-apple-watch-users]:
- First screen = "Your heart rate graph and key activity stats… The specific parameters may vary depending on the type of activity."
- Six named zones: **Zone 0 Light, Zone 1 Moderate, Zone 2 Vigorous, Zone 3 Hard, Zone 4 Very Hard, Zone 5 Max**
- Haptics: "During cyclical workouts like walking, running, or swimming, you'll feel the tap each time you enter or leave any zone. In all other cases, you will feel a vibration every time your heart rate goes up to the Light or Max Zone." Max Zone gets "a slightly more feelable haptic tap."

**Sub-5s interactions**: glance at the all-in-one complication (Battery+Stress+Health). Nothing else. The measurement itself is a 3–5 minute committed session — deliberately not a glance.
**Repeat-open driver**: the once-per-day free measurement quota plus a background-updating Stress card, so the feed changes without the user acting.

---

## B) Heart Analyzer (Helix Apps)

### Store position
4.7 / 5 from **22K ratings**. Free with IAP: monthly $3.99, annual $19.99, lifetime $49.99; à-la-carte modules Data Plus / Analytics Plus / Reports Plus at $9.99 each; Complete Premium $24.99 [source: https://apps.apple.com/us/app/heart-analyzer-pulse-tracker/id1006420410].

### First screen
**Dashboard** — "a clear summary of your day as soon as you open the app"; swipe between days, tap into individual data points, track Custom Heart Rate Zones from this view [source: https://www.helixapps.co.uk/heart-analyzer] [source: https://9to5mac.com/2023/04/18/heart-analyzer-apple-watch-iphone/].

### Screen list
- **Dashboard** (daily summary, day-swiping)
- **Insights** — renamed from "Heart Home" in v10; trends comparing the past 30 days to the preceding 30 days
- **Advanced Charts** / Deep Analytics — includes Cardio Fitness and Sleep Time averages
- **Heart Reports** — exportable PDF, custom timescales, password protection
- **Bookmarks** with notes
- Metric coverage: Heart Rate, HRV (rMSSD), Breathing Disturbance, Resting Heart Rate, Heart Rate Recovery, Blood Oxygen Saturation, VO2Max, Workouts, ECG. Up to "eight years of data."

### Watch app
"A re-designed app showing your Heart Rate over the day" plus "Charts with you on the go for **Move, Exercise, Cardio Points, HRV, Blood Oxygen Saturation and Resting Heart Rate**", plus **LiveHR** for a full live summary and post-workout Recovery / Cardio Fitness [source: https://apps.apple.com/us/app/heart-analyzer-pulse-tracker/id1006420410] [source: https://www.helixapps.co.uk/heart-analyzer].

### Complications
- "Customizable complications to keep you up to date with your Heart Rate and also support for Blood Oxygen Saturation, Heart Rate Variability and Resting Heart Rate trends"
- Heart Rate variants for **today, yesterday, or weekly**
- v10 added a **"Recent HRV chart" complication showing 12 hours of HRV data**, pitched for "monitoring readiness, indicating stress, or assessing periods when your heart might be running in AFib"; integrates with Apple Health AFib History
- **Cardio Points** has its own section and complication for weekly effort
- All chart complications rebuilt on Swift Charts in v10; range charts (SpO2, HRV, Respiratory Rate) render 10th & 90th percentiles as vertical bars to damp spikes
[source: https://9to5mac.com/2023/04/18/heart-analyzer-apple-watch-iphone/]

### Sub-5s interactions
The complication IS the product. A reviewer's framing: "No more tapping on your iPhone to drill down and locate your HRV values to understand your recovery. A glance at your watch face will provide you the weekly trend lines for your heart rate variability." One complication shows "the daily HRV values for the week along with the min, max, and average HRV values" [source: https://www.myhealthyapple.com/monitor-hrv-apple-watch-heartanalyzer/].

### Why users keep it
It is the chart layer Apple's Health app never shipped — dense multi-day HRV/HR trend rendered *on the watch face itself*, plus a PDF report you can hand to a doctor. Retention comes from data depth (8 years) and the exportable report, not from a daily ritual.

---

## C) Ultrahuman (Ring AIR)

### Dynamic Recovery / Recovery Score
[source: https://ultrahuman.com/blog/ultrahuman-ring-recovery-score-guide/]
- "a percentage measure from 0-100; a higher score indicates better recovery", with "85 or above" optimal
- **Five inputs**:
  1. **Sleep Quotient** — "sleep efficiency, total sleep, REM sleep, deep sleep and sleep timing"
  2. **Stress Rhythm** — classifies you "'stimulated', 'relaxed', or 'stressed'" by reading heart rate variation against your circadian cycle
  3. **Temperature** — skin temp as proxy for core temp / metabolic state
  4. **Resting Heart Rate** — personal baseline; healthy range cited as "60-100 beats per minute"
  5. **HRV Form**
- **Weights are not published.** Unverified.
- **"Dynamic Recovery is dynamic and can be improved throughout the day"** — the score is not frozen at wake-up. This is the single strongest differentiator vs. Athlytic (which sets Recovery once each morning).

Third-party API view of the same data: "Recovery Score (0-100 composite based on HRV, resting heart rate and sleep quality)", "Workout Index and Movement Index", and "Sleep temperature deviation is reported as a delta from the user's personal baseline" [source: https://openwearables.io/blog/ultrahuman-api-ring-data-cgm-recovery-metrics].

### Movement Index
"designed to keep you moving for optimum glucose metabolism and to increase your non-exercise energy usage" [source: https://www.ultrahuman.com/global/ring/]. Note the framing: the index is justified by a *mechanism* (glucose metabolism, NEAT), not by a step goal.

### Sleep Index
"intelligently designed to be your **sole metric for sleep health**, assesses your total sleep duration, resting heart rate, and restfulness" [source: https://www.ultrahuman.com/global/ring/]. Explicit single-number positioning.

Also named on that page: **Temperature tracking**, **HRV insights**, **Circadian alignment** built on the "Phase Response Curve (PRC)… mapped to a shift in your body's circadian rhythm", and **Personalized nudges** — "tailor-made insights and alerts to help you make better choices in real time."

### Caffeine / Stimulant Window
[source: https://www.ultrahuman.com/blog/introducing-caffeine-window-upgrade/]
- Shows **dynamic body caffeine levels updating in real time**
- Logging via the **Caffeine Bar**, "a repository of hundreds of caffeinated beverages", with tagged drinks in recents for one-tap re-log
- Driven by **Brain Waste Clearance** (deep sleep, HRV, sleep debt, skin temperature), producing three adaptive states:
  - **Caffeine Bonus** — "If your Brain Waste Clearance was strong, you earn a *Caffeine Bonus* and have a later cut-off."
  - **Early Cut-Off** — "If clearance was mildly impaired"
  - **Caffeine Detox** — "If last night's clearance was poor… to protect your deep sleep"
- **Half-life constants and actual cut-off times are not published.** Unverified.

### Apple Watch app
App Store lists Apple Watch under compatibility, "Requires watchOS 10.0 or later"; app rated 4.5 / 5 from **7.9K ratings**; free with IAP $2.90–$54.00 [source: https://apps.apple.com/us/app/ultrahuman/id1491286709].
**What the watchOS app actually displays, its screen list, and whether it ships complications: unverified.** No official Ultrahuman support doc describing watch screens was found across three searches; the app is a companion to the ring, with data reaching the watch mainly through Apple Health [source: https://blog.ultrahuman.com/blog/how-to-access-your-hrv-data-on-apple-health/ — referenced, not fetched].

### Criticism worth designing against
"It tells me that a half-degree drop in temperature isn't optimal but doesn't explain why it could happen or what it could mean… I wish there was a bit more explanation." Also: "The app measures tons of features during activity and sleep, so it can be a bit overwhelming." Ease-of-use still rated 4.5/5 [source: https://www.garagegymreviews.com/ultrahuman-ring-review].

---

## D) Four more well-designed watch health apps — one strong idea each

### 1. AutoSleep
[source: https://autosleepapp.tantsissa.com/watch-use] [source: https://www.macstories.net/reviews/autosleep-6-effortless-sleep-tracking-more-accessible-than-ever/]
- **First screen (watch)**: vertically scrollable colour-coded menu; "swipe with one finger to move up and down the menu or spin the side crown to move. Tap any menu option to view the details."
- **Screen list**: Sleep (duration + sleep bank, "Credit is represented by an up arrow, Debt by a down arrow"), Rings (Quality/Deep/bpm, or REM/Deep Stage/bpm in Sleep Stages mode), Session (condensed sleep-stage graph built for the watch), Readiness ("A colour keyed icon for your day's readiness" with words like "Great" or "Low"), Summary
- **Lights Off** button starts tracking and shows a live view of "how long you have been in bed, and how much of that time you have been asleep"
- **Complications**: update "roughly every 15 minutes"; Large Modular shows "your percentage of sleep goal & quality goal achieved as well as your average heart rate" and **updates live while you sleep**
- Colour language is traffic-light: "green is good, yellow not as good, and red is poor"
- Works "even without a separate Watch app installed"

> **Idea to steal**: the complication keeps updating *while the app is closed and the user is asleep*. Value is delivered at the moment of wrist-raise at 7 a.m., with zero taps and zero session.

### 2. HeartWatch
[source: https://heartwatch.tantsissa.com/user-guide/quick-guide]
- **Watch screens**: Pulse (a refresh option takes "five consecutive measures" for better accuracy), Activity, Workouts, Sleep, **Speak** (voice input for weight and blood pressure), Settings
- **iPhone first screen**: "tile" cards grouped into Wellness, Activity, Workouts, Notes
- **Complications** act as **shortcuts through to the function** in HeartWatch; there is also an option to open the watch app to the last displayed screen instead
- Workout mode = three swipeable screens: metrics / controls ("HR alerts, take notes, lock, live stream and end your workout") / music

> **Idea to steal**: a complication is a deep link, not a launcher. Tapping the Stress complication lands on Stress, not on a home screen. Also: **Speak** — voice entry for numbers that are miserable to dial in on a 40 mm screen.

### 3. Streaks
[source: https://apps.apple.com/us/app/streaks/id963034692?platform=appleWatch]
- $5.99, 4.8 / 5 from **27K ratings**, Apple Design Award winner, Editors' Choice
- "Track up to **24 tasks** you want to complete each day" — a hard cap
- "Includes one of the highest-praised Apple Watch apps, including Health app integration, complications, and rich notifications"; "Streaks supports **all Apple complication types**"
- Health integration auto-completes tasks (steps, mindfulness minutes, exercise ring) without opening the app

> **Idea to steal**: a hard cap on tracked items. Because the set is bounded, one complication can always represent the whole state meaningfully. Unbounded metric lists cannot be glanced.

### 4. Waterllama
[source: https://apps.apple.com/us/app/water-tracker-waterllama/id1454778585]
- 4.9 / 5 from **158K ratings** — 2022 App Store Award winner, 2022 Apple Design Award finalist, Editors' Choice
- watchOS 10+: **Interactive Smart Stack widgets**, **Double Tap to "Quickly add a cup of Water"**, and the ability to "add up to 64oz/2000ml at once"

> **Idea to steal**: the entire primary action is a **Double Tap gesture from the Smart Stack** — zero navigation, zero screens, sub-1-second. If Laso has any logging action (mood, caffeine, "I feel recovered"), this is the ceiling to aim at.

### 5. Athlytic (bonus — closest direct competitor to Laso)
[source: https://www.athlyticapp.com/getting-started] [source: https://athlytic.github.io/athlyticapp/troubleshooting/]
- **Recovery**: daily **0–100%** from HRV + Resting HR "compared against your personal **60-day baseline**", "set once each morning as a readiness snapshot"
- **Exertion**: **0–10** scale, accumulating when HR exceeds a personalized threshold; **Target Exertion Zone** combines Recovery + Exertion + Training Goal into a range
- **Battery**: unlike Recovery, "Updates throughout day with each new HRV sample… charging with a nap, yoga, or genuine rest, draining after a hard workout or a drink"
- **Sleep Quality** from REM, deep, awake time, interruptions, respiratory rate; plus Sleep Debt, Sleep Consistency, Heart Rate Dip
- **Stress**: "reads your heart-rate patterns around the clock to chart stress from low to high"
- Watch workout live view: colour-coded HR zone, Effort score, aerobic vs anaerobic split
- Ships the platform limitation as documentation: "Apple limits apps to only being able to update complications 4 times per hour (or every 15 minutes)", explicitly explaining why watch, widget and app can disagree
- Third-party statistical comparison: "Scores from Athlytic, Livity and Superset were statistically indistinguishable from each other and generally significantly more accurate than scores from other competing apps" — **unverified**, from a search summary of a Medium post I did not fetch

> **Idea to steal**: split the score into a **frozen morning number** (Recovery, a decision you make once) and a **live number** (Battery, which drifts all day). One is a verdict, the other is a feed. Different update cadences, different surfaces.

---

## Cross-app pattern summary for Laso

| Pattern | Who does it | Implication |
|---|---|---|
| One hero number, everything else demoted | Ultrahuman Sleep Index ("sole metric for sleep health"); Welltory Health tinting the whole background | One score owns the first screen |
| Split frozen-morning vs live-all-day scores | Athlytic Recovery (once) vs Battery (per HRV sample); Ultrahuman Dynamic Recovery improves during the day | Decide which of Laso's scores is a verdict and which is a feed |
| Complication that updates while the app is closed | AutoSleep (live during sleep); Heart Analyzer 12h HRV chart | Wrist value with zero session |
| Complication as deep link to its own function | HeartWatch | Tap lands on the detail screen the complication showed |
| Whole action in one gesture | Waterllama Double Tap from Smart Stack | Sub-1s logging |
| Measurement is a committed 3–5 min session, not a glance | Welltory via Apple's Breathe app | Do not fight this — reuse Breathe rather than build a custom timer |
| Publish the 15-min complication cap in-product | Athlytic | Prevents "the watch is wrong" support load |
| Explain *why*, not just *what* | Ultrahuman's top criticism is unexplained temperature deltas | Every score band needs a mechanism sentence |

---

**Explicitly unverified in this report**: Welltory's Productivity formula and score ranges/colour thresholds; Welltory Energy/Stress numeric scales; Ultrahuman factor weights, caffeine half-life constants and actual cut-off times; the entire Ultrahuman watchOS screen list and complication set; Apple's HIG complications page as a primary URL; the Medium statistical accuracy comparison.

Confidence: 84/100 — every cited claim was pulled from a page fetched this session (19 fetches, 9 searches), but three of the requested specifics could not be verified anywhere: Ultrahuman's watchOS app screens/complications (no official doc exists that I could find), Welltory's Energy/Stress numeric ranges and colour bands (help pages deliberately omit them), and the Welltory Productivity formula (only a search snippet, page not fetched). The Apple HIG complications page itself returned only a title, so that guidance is second-hand via Significa. | Source: internet

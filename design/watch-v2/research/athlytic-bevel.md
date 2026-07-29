# Watch-Native Rivals — Athlytic, Bevel, Training Today

# Watch-Native Recovery App Competitor Research: Athlytic, Bevel, Training Today

Research date: 2026-07-29. Reddit could not be searched or fetched (blocked to this agent) — every Reddit-specific claim below is marked **unverified**.

---

## 1. ATHLYTIC (MyndArc, LLC)

### Platform facts
- watchOS 10.6+; iOS 17.0+, iPadOS 17.0+, visionOS 1.0+. App size 69.2 MB. Rating 4.8/5 from ~11K ratings. [source: https://apps.apple.com/us/app/athlytic-ai-fitness-coach/id1543571755]
- Minimum hardware historically watchOS 7; "Series 0, 1, and 2 watches cannot run this version." [source: https://athlytic.github.io/athlyticapp/troubleshooting/]

### Watch screen inventory (from App Store listing + reviews)
Confirmed watch-side surfaces:
- **Vital Health Metrics screen** — HRV, Resting HR, Blood Oxygen, Respiratory Rate, Wrist Temperature
- **Training Load / Training Load Ratio displays**
- **Sleep**: Time Asleep, Wake Up Time
- **Watch Exertion Indicator** — shows current position relative to the Target Exertion Range
- **Live workout screens** — color-coded HR-zone route map, live mile/km splits, pace zones, auto-lap
[source: https://apps.apple.com/us/app/athlytic-ai-fitness-coach/id1543571755]

Vendor site states the watch surfaces five primary metrics: Recovery, Exertion, Sleep, Stress, and live workout data with heart-rate zones. [source: https://www.athlyticapp.com/]

**First screen**: an independent reviewer using an Apple Watch Ultra describes the main watch display as presenting **four metrics simultaneously with tap-through to detail views** — Recovery, Exertion, Sleep, Energy Burned. [source: https://ibikerun.substack.com/p/athlytic-app-review-iosapple-watch] Note: the vendor lists five tiles, the reviewer saw four; the exact current tile count is **unverified** (no screenshot-level source found).

Another reviewer confirms the during-workout watch view shows **"zones, effort, and heart rate recovery."** [source: https://craftingworlds.com/athlytic-the-apple-watch-coach-that-actually-tells-me-what-to-do/]

### Scores
| Score | Range | Inputs |
|---|---|---|
| **Recovery** | 0–100% | HRV + Resting HR vs a **60-day average baseline**; "weights HRV slightly higher for its strong link to your autonomic nervous system" [source: https://www.athlyticapp.com/getting-started] |
| **Exertion** | **0–10** | Cardiovascular load accumulated 24/7 whenever HR exceeds a personalized threshold; paired with a daily **Target Exertion Zone** derived from that morning's Recovery [source: https://www.athlyticapp.com/getting-started, https://www.athlyticapp.com/] |
| **Cardio Fitness** | VO2max estimate, units not published | "Athlytic calculates Cardio Fitness based on estimated VO2 Max"; formula uses Maximum HR and Resting HR; unlike Apple it "provides estimates for all workout types," not just running/walking/hiking [source: https://athlyticapp.helpscoutdocs.com/article/46-how-is-cardio-fitness-calculated-in-athlytic] |
| **Athlytic Age** | biological-vs-chronological age | Long-term trend indicator [source: https://apps.apple.com/us/app/athlytic-ai-fitness-coach/id1543571755, https://craftingworlds.com/athlytic-the-apple-watch-coach-that-actually-tells-me-what-to-do/] |

There is no score literally named "Cardiac" — the closest are **Cardio Fitness (VO2max)** and **Heart Rate Recovery**, both surfaced in post-workout analysis and Trends.

### Complications
App Store US listing: **8+ complications** — Recovery, Exertion, Blood Oxygen, Net Energy, Daily HRV Chart, Daily HR Chart, Daily Energy, Stress. [source: https://apps.apple.com/us/app/athlytic-ai-fitness-coach/id1543571755]
The Apple Watch platform page claims **"15+ watch complications and widgets across various sizes."** [source: https://apps.apple.com/us/app/athlytic-ai-fitness-coach/id1543571755?platform=appleWatch] The two numbers conflict; treat the exact count as **unverified**.

**Complication families are nowhere published.** The help article says only "Athlytic provides different complication types based on the watch face you are using" and points to a complications list page at athlyticapp.com/complications — **that URL returns HTTP 404**. [source: https://athlyticapp.helpscoutdocs.com/article/36-how-to-set-up-complications-or-configure-your-watch-faces]

### Smart Stack
Supported, and the listing claims contextual surfacing: "recovery/sleep data upon waking, training metrics during workouts, sleep planning at bedtime." [source: https://apps.apple.com/us/app/athlytic-ai-fitness-coach/id1543571755] Whether that is real relevance-scoring or just marketing copy is **unverified**.

### Live / real-time on watch
- **Real-time exertion monitoring with haptic notification when the Target Exertion range is reached** during a workout [source: https://apps.apple.com/us/app/athlytic-ai-fitness-coach/id1543571755?platform=appleWatch]
- Live HR-zone route map, color-coded by zone, drawn during the workout
- Live splits with **haptic feedback at each mile/km marker**; pace zones; auto-lap
- Supported: Running, Cycling, Hiking, Walking, XC Ski, Downhill Ski, Snowboard, Paddle, Swim, Wheelchair
[source: https://apps.apple.com/us/app/athlytic-ai-fitness-coach/id1543571755]

### Notifications
Daily Report (Recovery, Exertion, Sleep); Target Exertion minimum-reached and maximum-exceeded alerts; Health Alerts for out-of-range metrics; Training Load Ratio alerts; High Stress alerts; per-metric toggles in Settings. [source: https://apps.apple.com/us/app/athlytic-ai-fitness-coach/id1543571755]

### Hard engineering constraint they publicly document (directly relevant to any watch redesign)
> "Apple Watch widgets are only permitted to update **four times per hour**" — so Exertion/Steps lag reality.
> Apple Watch "can only access the past **7 days** of data" — so 60-day baselines are computed on iPhone and synced via **Watch Connectivity and iCloud**.
> Most discrepancies are "a syncing issue with iCloud or Apple Health data."
[source: https://athlyticapp.helpscoutdocs.com/article/12-widget-or-complication-out-of-sync, https://athlytic.github.io/athlyticapp/troubleshooting/]
The troubleshooting page also notes the watch Recovery view shows the **60-day baseline HRV and RHR as small numbers in parentheses** next to the live values.

### Reviewer praise
- "Athlytic made my Apple Watch feel like it knows me"; turns training into "clear daily choices"; widgets and complications make "the battery and exertion targets visible without opening the app" [source: https://craftingworlds.com/athlytic-the-apple-watch-coach-that-actually-tells-me-what-to-do/]
- "suggestions update after an activity" — unlike some competitors [source: https://ibikerun.substack.com/p/athlytic-app-review-iosapple-watch]
- "the most comprehensive Apple Watch recovery app" with "incredible UI" [source: https://www.gymshark.com/blog/article/best-apple-watch-recovery-apps]
- "Makes Apple Watch data easier to understand"; "More affordable than buying another wearable" [source: https://neura.health/insight/athlytic-app-in-depth-review]

### Reviewer criticism
- Recovery "skews heavily towards cardio" and ignores muscle fatigue; no aerobic-zone breakdown; no training plans or event targeting; suggestions are vague — it says "run for 50 minutes but does not tell you whether it is a steady state run or intervals" [source: https://ibikerun.substack.com/p/athlytic-app-review-iosapple-watch]
- Stress notifications backfire; the reviewer wants "a big friendly toggle to hush stress for a while," noting they increase anxiety rather than help [source: https://craftingworlds.com/athlytic-the-apple-watch-coach-that-actually-tells-me-what-to-do/]
- "Can feel overwhelming at first"; "data-heavy… scores should be treated as helpful guidance rather than absolute truth" [source: https://neura.health/insight/athlytic-app-in-depth-review]

### Pricing and how the watch drives it
$4.99/month, $29.99/year, 1-week free trial, no lifetime tier. [source: https://apps.apple.com/us/app/athlytic-ai-fitness-coach/id1543571755, https://www.athlyticapp.com/]
The watch app is a **subscription-gated client**: entitlement is pushed from phone to watch, and when it fails users are told to "force quit iPhone app and reopen to send subscription to watch" and verify iCloud is on for Athlytic. [source: https://athlytic.github.io/athlyticapp/troubleshooting/] Positioning is explicitly anti-WHOOP — "essentially all the same information at a much more reasonable price point" is the recurring user line quoted in review coverage. [source: https://apps.apple.com/us/app/athlytic-ai-fitness-coach/id1543571755]

---

## 2. BEVEL (Finerpoint, Inc / seller Starlight Tech LLC)

### Platform facts
- watchOS 10.6+; iOS 18.0+; macOS 15.0+ (M1+). App size **812.2 MB**. Rating 4.8/5 from 13K+ ratings on the US App Store; bevel.health markets 4.8 from 28.6K users. Age 13+. 13 languages. [source: https://apps.apple.com/us/app/bevel-all-in-one-health-app/id6456176249, https://www.bevel.health/]

### Watch screen inventory
The watch app is a **scrollable dashboard that mirrors the phone's Home Dashboard**, plus a workout engine and an alarm. Watch-side surfaces named in the listing:
- Scrollable score dashboard (Recovery, Sleep, Strain, Stress)
- **Health Monitor**
- **Cardio Load**
- **Nutrition Score, Calories, Macros, Net Energy, Glucose, Food Logs, Food Contributors**
- **Strength workout live tracking** with heart rate, workout templates, exercise previews with instructional video, real-time set/rep editing on the watch
- **Sleep Alarm** (incl. smart wake)
[source: https://apps.apple.com/us/app/bevel-all-in-one-health-app/id6456176249, https://apps.apple.com/us/app/bevel-ai-health-coach/id6456176249?platform=appleWatch]

**First screen**: Lifehacker's Beth Skwarecki: "When you open up the Bevel app, you'll see your **strain, recovery, and sleep** as they currently stand." She scopes the watch app tightly: it "does three things: it can show you your scores and data, the other Apple Watch features are the **smart alarm** and the **strength workouts**." [source: https://tech.yahoo.com/wearables/articles/bevel-sort-makes-apple-watch-230000160.html] Whether that first screen is identical on watch vs phone is **unverified**.

### Scores
| Score | Description | Range |
|---|---|---|
| **Recovery** | "Your daily readiness, simplified" — from sleep stages, HRV, RHR; needs **two full nights of sleep** before it appears | not published — **unverified** |
| **Sleep** | sleep stages, duration, interruptions → single metric | not published |
| **Strain** | "Measure how hard your body is working throughout the day"; in practice "mostly a shorthand for exercise" | not published |
| **Stress** | "See how stress shows up in your body with a real-time score" | not published |
| **Energy Bank** | "Your body's battery" — combines recovery, sleep, strain, stress | not published |
| **Biological Age** | weekly, from sleep, activity, fitness, lifestyle, bloodwork | age in years |
| **Cardio Load** | cumulative cardiovascular training impact | not published |
| **Nutrition Score** | calories, macros, nutrients from logged meals | not published |
[source: https://apps.apple.com/us/app/bevel-all-in-one-health-app/id6456176249, https://help.bevel.health/en/articles/11258241, https://tech.yahoo.com/wearables/articles/bevel-sort-makes-apple-watch-230000160.html]

Bevel publishes **no numeric ranges or band thresholds** anywhere I could find. This is a documented weakness, not an omission on my part — see criticism below.

### Complications
Listed complications: **Nutrition Score, Net Energy, Calories, Macros, Recovery, Sleep, Strain, Stress, Energy Bank, Biological Age.** [source: https://apps.apple.com/us/app/bevel-all-in-one-health-app/id6456176249]
Help doc describes them only as covering "key metrics and Insights, such as Strain, Recovery, Sleep, and Activity" and gives add-flow instructions from both the watch face and the iPhone Watch app. **No complication families are published anywhere.** [source: https://help.bevel.health/en/articles/10436609]

### Smart Stack
**Not confirmed.** Bevel's listing mentions watchOS complications and iPhone widgets; no source I fetched states an Apple Watch Smart Stack widget exists. **Unverified — treat as absent until proven.**

### Live / real-time on watch
- **Live Sync** between watch and phone during strength workouts, with live heart rate and real-time set/rep display and editing on the wrist
- Real-time feedback on **muscular strain**
- Real-time Stress score
- iPhone-side (not watch): Live Activities on lock screen (iOS 16.1+) and Dynamic Island (iPhone 14 Pro+)
- AirPods Pro 3 heart-rate ingest for phone-led workouts
[source: https://apps.apple.com/us/app/bevel-all-in-one-health-app/id6456176249]

### Notifications
**No notification inventory published** in any source fetched. **Unverified.**

### Reviewer praise
- Lifehacker: "One thing I love about Bevel is that it pulls in data, including workout data, from other devices"; strength training with muscle-group breakdown is "an excellent idea" [source: https://tech.yahoo.com/wearables/articles/bevel-sort-makes-apple-watch-230000160.html]
- "Low-friction" morning check; "Design is genuinely good"; "value compounds over weeks" [source: https://www.autonomous.ai/ourblog/bevel-app-review]
- "Bevel stands out"; the free version "can replace several other apps and save a significant amount of money" [source: https://australianapplenews.com/2026/01/07/review-bevel-a-health-app-that-ticks-almost-all-the-boxes/]

### Reviewer criticism
- Lifehacker: **"Bevel is big on data, but falls short on guidance"** versus Garmin/Whoop. Strength accuracy: it "credited me with only '3%' work for my upper back." Journal configuration is "confusing." Third-party sync (Strava/Coros) breaks. [source: https://tech.yahoo.com/wearables/articles/bevel-sort-makes-apple-watch-230000160.html]
- **"The scores are a black box"** — the app doesn't show "which inputs drove the number"; "breadth over depth, by design"; degrades on irregular schedules/travel; ~2-week baseline learning period [source: https://www.autonomous.ai/ourblog/bevel-app-review]
- Watch/phone value mismatch is an acknowledged live bug class on their own public board: users report the widget showing Recovery and Sleep "consistently 1–5 points lower than the iPhone app." (Board page itself renders as a JS shell to WebFetch — quote comes via search snippet, so **partially unverified**.) [source: https://feedback.bevel.health/bug-reports/p/bevel-phone-app-and-watch-app-values-dont-match]
- Watch app is not the product: Skwarecki notes its display features are things "the phone app can" already do. [source: https://tech.yahoo.com/wearables/articles/bevel-sort-makes-apple-watch-230000160.html]

### Pricing and how the watch drives it
- **Bevel Pro**: $14.99/month, $99.99/year, plus a 12-month-commitment monthly plan in limited regions
- **Bevel Intelligence credits** (consumable): 350 / $4.99, 750 / $9.99, 1,550 / $19.99, 4,200 / $49.99
- Free tier covers core scores, nutrition, Strength Builder, history; Health Records, Biological Age, and Bevel Intelligence are Pro
[source: https://apps.apple.com/us/app/bevel-all-in-one-health-app/id6456176249, https://www.autonomous.ai/ourblog/bevel-app-review]
Conflicting figure: an Australian review dated 2026-01-07 lists "Bevel Intelligence: $9.99/month or $79.99/year." [source: https://australianapplenews.com/2026/01/07/review-bevel-a-health-app-that-ticks-almost-all-the-boxes/] Likely stale or regional — **unresolved**.
The watch is **not** the monetization driver here: Bevel monetizes AI credits and Pro on the phone, and the watch is a mirror plus a workout/alarm terminal. Bevel is ~3–7× Athlytic's price and ~5× Training Today's.

---

## 3. TRAINING TODAY (Betoli Ltd, UK)

### Platform facts
- watchOS 10.6+; iOS 16.0+. App size 43 MB. Age 9+. US App Store: 4.6/5 from 2.6K ratings. DE/EN store page: 4.4/5 from 899 ratings. Free to download. [source: https://apps.apple.com/us/app/training-today/id1507992127, https://apps.apple.com/de/app/training-today/id1507992127?l=en-GB&platform=watch]
- Developed "with British Triathlon Coaches." Developer contact published: ian@betoli.com. [source: https://apps.apple.com/de/app/training-today/id1507992127?l=en-GB&platform=watch]
- **Runs independently on Apple Watch with no iPhone required** — the only one of the three that advertises this. [source: https://apps.apple.com/us/app/training-today/id1507992127]

### Watch screen inventory — the most precisely documented of the three
Official user-guide article "Apple Watch App, Complications and Widgets":
- **Main screen = your recent RTT chart.** "Use the Digital Crown to scroll through the week."
- Workout icons appear inline on the chart at points where a workout was logged
- **Tapping the chart** where a workout icon sits opens a **workout details screen**
[source: https://trainingtodayapp.helpscoutdocs.com/article/92-apple-watch-app-complications-and-widgets]

That is the entire documented watch app: **two screens**. Everything else lives on iPhone.

**First screen**: the weekly RTT chart, not a big number. This is the sharpest structural difference from Athlytic (four-tile dashboard) and Bevel (mirrored scrolling dashboard).

### Score
- **RTT (Readiness To Train)**: **0–10, not 0–100.** "The score ranges from 0 (total rest) to 10 (ready for peak performance)." [source: https://trainingtodayapp.helpscoutdocs.com/article/6-what-is-an-rtt-score] The brief's "0-100" premise is wrong.
- Core method: "uses your Heart Rate Variability (HRV) and presents it in a way that is easy to view and act on by **comparing the last 24hrs to your baseline 60-day average**." [source: https://trainingtodayapp.helpscoutdocs.com/article/84-how-training-today-works]
- Algorithm factors: 60-day baseline, chart direction/trend, smoothing values, and **user-adjustable intensity values**. [source: https://trainingtodayapp.helpscoutdocs.com/article/6-what-is-an-rtt-score]
- Presented as "a simple **traffic light** system indicating your readiness to perform." Exact colour thresholds are **not published** — unverified. [source: https://trainingtodayapp.com/]
- Secondary metrics (subscriber-only, iPhone): **AIS (Activity Intensity Score)**, **OFI (Overall Fitness Index)** with month/year analysis, Status Tags, sleep adaptation vs sleep debt. [source: https://apps.apple.com/us/app/training-today/id1507992127, https://trainingtodayapp.helpscoutdocs.com/article/49-subscription-features]
- iPhone weekly chart layers: RTT line, red dotted RHR line, light-blue sleep-duration bars, yellow AIS bars, white triangles for logged workouts, blue background band showing min/max of the 60-day rolling baseline, pink day highlights for menstruation. [source: https://trainingtodayapp.helpscoutdocs.com/article/85-understanding-training-today-screens]

### Complications
"Supports a complete set of complications for your Apple Watch" that you can put on any watch face. **The families are never enumerated** in the docs. [source: https://trainingtodayapp.helpscoutdocs.com/article/92-apple-watch-app-complications-and-widgets]
A 2020 hands-on names two concrete placements observed: **Infograph Modular** with the score as the main centre complication, and **Chronograph Pro** with the score in the bottom-left corner (example value "4.2"). [source: https://the5krunner.com/2020/10/10/apple-watch-6-readiness-to-train-with-training-today/] That review is 2020 — current family coverage is **unverified**.

### Smart Stack
**Yes, and it is subscriber-gated.** Two variants: "as either a **chart** or with the **text description** for your RTT score." [source: https://trainingtodayapp.helpscoutdocs.com/article/92-apple-watch-app-complications-and-widgets, https://trainingtodayapp.helpscoutdocs.com/article/49-subscription-features]

### Live / real-time on watch
No live-workout screen. Instead: **dynamic structured workouts** for running, cycling and swimming that adjust the session to your RTT. [source: https://apps.apple.com/us/app/training-today/id1507992127] Whether these render on the watch or only on iPhone is **unverified**.
RTT recalculates "automatically throughout the day," not just at wake. [source: https://apps.apple.com/us/app/training-today/id1507992127] Legacy trick documented by a reviewer: run a 1-minute **Breathe** session to force a fresh HRV reading and an instant RTT update. [source: https://the5krunner.com/2020/10/10/apple-watch-6-readiness-to-train-with-training-today/]

### Notifications
**Watch-native and delta-based, not absolute-value-based**: "the Apple Watch Training Today app can show notifications when your average RTT changes compared to the previous four days," with the change threshold set by the user in settings. Subscriber-only. [source: https://trainingtodayapp.helpscoutdocs.com/article/80-getting-started-with-training-today, https://trainingtodayapp.helpscoutdocs.com/article/49-subscription-features]

### Reviewer praise
- "it just works" and "displays the information simply, clearly and unambiguously" without requiring special testing procedures [source: https://the5krunner.com/2020/10/10/apple-watch-6-readiness-to-train-with-training-today/]
- "one of the more simple recovery applications" that stays "extremely user-friendly," with "great Apple Watch face complications" [source: https://www.gymshark.com/blog/article/best-apple-watch-recovery-apps]
- App Store users "praise accuracy in detecting recovery needs and illness impacts" [source: https://apps.apple.com/de/app/training-today/id1507992127?l=en-GB&platform=watch]

### Reviewer criticism
- the5krunner, on accuracy: **"Is it perfect? A: No."** — recommends treating it only "as a guide to your upcoming workout" [source: https://the5krunner.com/2020/10/10/apple-watch-6-readiness-to-train-with-training-today/]
- Their own docs admit Siri support is "noted as unreliable on watchOS 9" [source: https://trainingtodayapp.helpscoutdocs.com/article/49-subscription-features]
- Rating spread (4.6 US / 4.4 international) is the lowest of the three.

### Pricing and how the watch drives it
US: monthly **$2.99**, yearly **$29.99**, **lifetime $59.99**, one-off "additional charts" **$5.99**. EUR: €2.95 / €34.99 / €69.99 / €6.99. [source: https://apps.apple.com/us/app/training-today/id1507992127, https://apps.apple.com/de/app/training-today/id1507992127?l=en-GB&platform=watch]
**The watch drives the paywall directly and deliberately**: the free watch app gives you the RTT chart and complications; the paywall sits on **watch notifications**, the **watch Smart Stack widget**, Siri/Shortcuts, and every iPhone chart. You get the number free and pay for it to reach you without looking. [source: https://trainingtodayapp.helpscoutdocs.com/article/49-subscription-features]

---

## Cross-app comparison table

| | Athlytic | Bevel | Training Today |
|---|---|---|---|
| Watch first screen | ~4–5 metric tiles, tap-through | scrolling dashboard mirroring phone | weekly RTT chart, Crown-scrollable |
| Documented watch screens | vitals, training load, sleep, exertion indicator, live workout | dashboard, health monitor, cardio load, nutrition set, strength workout, sleep alarm | 2 (chart, workout detail) |
| Headline score | Recovery 0–100% | Recovery (range unpublished) | RTT 0–10 |
| Load score | Exertion 0–10 + Target Zone | Strain + Cardio Load | AIS (iPhone only) |
| Complications named | 8–15+, families unpublished | 10 named, families unpublished | "complete set," families unpublished |
| Watch Smart Stack | yes (claims contextual surfacing) | **unverified / likely no** | yes, 2 variants, paid |
| Live in-workout watch UI | strongest — zones, splits, route map, exertion haptics | strength only — sets/reps/HR Live Sync | none documented |
| Watch notifications | 6 categories incl. exertion min/max haptics | unpublished | RTT delta vs 4-day average, threshold user-set, paid |
| Standalone watch | no (needs iPhone for 60-day baselines) | no (phone-first) | **yes, advertised** |
| Price/yr | $29.99 | $99.99 | $29.99 (or $59.99 lifetime) |
| Rating | 4.8 / 11K | 4.8 / 13K | 4.6 / 2.6K |

## Design signals worth carrying into a Laso watch redesign
1. **The 7-day HealthKit ceiling on watch is the defining constraint.** Athlytic publicly documents computing 60-day baselines on iPhone and syncing them to the watch via Watch Connectivity + iCloud — and that this sync is their single most common support ticket. [source: https://athlyticapp.helpscoutdocs.com/article/12-widget-or-complication-out-of-sync]
2. **Complication refresh is capped at 4 updates/hour.** Both Athlytic docs state it. Any live-feeling number on a complication will be stale and will generate "watch doesn't match phone" complaints — Bevel already has that exact bug thread. [source: https://athlytic.github.io/athlyticapp/troubleshooting/, https://feedback.bevel.health/bug-reports/p/bevel-phone-app-and-watch-app-values-dont-match]
3. **None of the three publishes complication families.** Undifferentiated ground; also means no competitor is claiming full-family coverage as a feature.
4. **The consistent criticism across all three is guidance, not data.** "Bevel is big on data, but falls short on guidance"; Athlytic "does not tell you whether it is a steady state run or intervals"; "the scores are a black box." Score transparency + a concrete prescription is the open gap.
5. **Notification design is a real differentiator.** Training Today's delta-vs-4-day-average with a user-set threshold is the most restrained model; Athlytic's stress alerts drew an explicit reviewer complaint that they "increase anxiety."

**Confidence: 84/100** — every score, price, complication list and screen description above was read off a fetched page and cited; what drags it down: Reddit is blocked to this agent so zero forum-level detail was obtained, complication *families* are unpublished by all three vendors, Bevel publishes no score ranges and no notification list, Bevel's Smart Stack support could not be confirmed either way, Athlytic's watch complication count conflicts between its own two App Store pages (8+ vs 15+), Athlytic's official complications list URL 404s, and Training Today's traffic-light colour thresholds are undocumented. | Source: internet

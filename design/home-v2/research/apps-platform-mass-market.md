# Home / Today Screen Teardown — Mass-Market Health Platforms

Research date: 2026-07-29. Every claim below traces to a page fetched or a search performed in this session. Where I could not verify something, it is tagged `[UNVERIFIED]` with the reason. No invented numbers.

Apps covered: Apple Health (Summary tab), Apple Fitness (Summary + rings), Fitbit (now Google Health), Samsung Health, Google Fit (dead — post-mortem), MyFitnessPal.

---

## 0. Headline finding before the detail

**2025-2026 was the year all four platform-owned health apps rebuilt their home screen around a single AI-generated number or an AI chat entry point, and in three out of four cases users revolted — not because AI is bad, but because the redesign pushed *the raw number the user came to see* below the fold.**

The scoreboard:

| App | Home redesign | Result |
|---|---|---|
| MyFitnessPal | Diary tab → Today tab, v26.16.0, 21 Apr 2026 | Version rating fell **3.24 → 1.54 stars** ([mwm.ai](https://mwm.ai/articles/myfitnesspal-v26-16-0-replaces-diary-with-new-ui-sparking-rating-drop-in-april-2026)) |
| Fitbit → Google Health | 19 May 2026 | Play Store review-bombed; 39-item apology roadmap in 8 days ([9to5Google](https://9to5google.com/2026/05/27/google-health-roadmap-fitbit-backlash/)) |
| Samsung Health | 8 Jun 2026 (One UI 9) | Mixed; reviewer advice was literally "enjoy the old Samsung Health product while it's still around" ([Android Authority](https://www.androidauthority.com/samsung-health-app-2026-update-hands-on-3679261/)) |
| Apple Health | iOS 26.4 redesign reported Jan 2026 | Shipping status as of this research date `[UNVERIFIED]` |

The one home screen nobody revolted against in this window is **Apple Fitness**, which did not change its core metaphor at all. That is the strongest signal in the whole dataset.

---

# 1. Apple Health — Summary tab

## 1.1 Vertical order, top to bottom

Sources: [Apple Support 104997](https://support.apple.com/en-us/104997) (partially truncated on fetch), [MacRumors Health guide](https://www.macrumors.com/guide/health/), [How-To Geek](https://www.howtogeek.com/669637/how-to-customize-the-summary-tab-in-the-iphones-health-app/), [MacStories iOS 13 Health review](https://www.macstories.net/stories/health-in-ios-13-a-foundation-for-apples-grand-wellness-ambitions/).

```
┌──────────────────────────────────────────┐
│ Summary                       [avatar ⦿] │  ← large title + profile/settings
├──────────────────────────────────────────┤
│  ┌────────────────────────────────────┐  │
│  │  Activity  ◉◉◉   Move 412/500 kcal │  │  ← ONLY if Apple Watch paired.
│  │  Exercise 22/30  Stand 9/12        │  │    Auto-inserted at very top.
│  └────────────────────────────────────┘  │
│                                          │
│  Favorites                       Edit ▸  │
│  ┌───────────┐ ┌───────────┐             │
│  │ Steps     │ │ Sleep     │             │  ← alphabetical order, NOT
│  │ 6,412     │ │ 6h 51m    │             │    user-orderable
│  └───────────┘ └───────────┘             │
│  ┌───────────┐ ┌───────────┐             │
│  │ Headphone │ │ Heart Rate│             │
│  │ 71 dB     │ │ 64 BPM    │             │
│  └───────────┘ └───────────┘             │
├─────────────── FOLD ─────────────────────┤
│  Highlights                  Show All ▸  │
│  ┌────────────────────────────────────┐  │
│  │ Flights Climbed                    │  │  ← auto-generated week-over-week
│  │ ▁▃▅▂▇▄▆  "this week vs last week"  │  │    comparisons
│  └────────────────────────────────────┘  │
│  ┌────────────────────────────────────┐  │
│  │ Average Steps  ▁▃▅▂▇▄▆             │  │
│  └────────────────────────────────────┘  │
│                                          │
│  Health Checklist                        │  ← enable Fall Detection, Medical
│  ┌────────────────────────────────────┐  │    ID, ECG, Emergency SOS…
│  └────────────────────────────────────┘  │
│                                          │
│  Get More From Health                    │  ← articles, app recommendations,
│  ┌────────────────────────────────────┐  │    organ-donor registration
│  │ "Understanding Heart Rate"         │  │
│  └────────────────────────────────────┘  │
│  Apps                                    │
├──────────────────────────────────────────┤
│  [Summary]  [Sharing]  [Browse]          │  ← tab bar
└──────────────────────────────────────────┘
```

MacRumors describes the bottom-of-page section as "Get More From Health," offering "organ donor registration links, educational health content, and app recommendations." How-To Geek describes the whole tab as "a feed that's broken down in a couple of sections" — "Favorites, Highlights, Health Recommendations, Apps, and more" — and notes it is "dynamic (it updates with new information using the connected devices and time of the day)."

## 1.2 What appears FIRST, and the hypothesis for why

**Activity rings if a Watch is paired; otherwise the first Favorite alphabetically.**

The hypothesis: Apple treats Summary as a *reading list*, not a dashboard. MacStories reports Apple designed Summary explicitly on the model of Apple Books' "Reading Now" screen — "Summary serves the same purpose in Health. While previous versions of Health were more fragmented, with the Summary screen Apple puts all the data you might want in one place."

That analogy explains the strange behaviour: a Reading Now shelf does not rank your books by importance, it shows you what you touched last. Apple Health's Favorites do exactly the same, which is why they are **alphabetical and not reorderable**. Apple made an editorial decision that *the user*, not the algorithm, decides what matters — but then refused to let the user express priority beyond a binary star.

## 1.3 The single action the screen is engineered to produce

**Tap a Favorite tile to drill into a metric detail chart.** Nothing else on the screen is a first-class call to action. There is no logging affordance, no "start" button, no goal. Summary is a read-only index.

Secondary engineered action: complete the **Health Checklist** (turn on Fall Detection, Medical ID, ECG, High Heart Rate alerts). This is Apple's real business goal on this screen — feature activation for safety features that create hardware lock-in and PR-grade "the Watch saved my life" stories.

## 1.4 Emotion in the first 3 seconds

**Calm, tipping into indifference.** With a Watch, the rings give a half-second of pride/urgency. Without a Watch, the screen is a grid of grey numbers with no verdict attached — the dominant emotion is *neutral curiosity that decays fast*. There is nothing to feel guilty about because nothing tells you whether 6,412 steps is good or bad.

This is deliberate. Apple has regulatory exposure and will not label your numbers "good" or "bad." The cost is that Summary generates no emotional loop at all, which is exactly why Apple needed the separate Fitness app.

## 1.5 Hidden behind taps / progressive disclosure

- All chart history, ranges, day/week/month/6M/Y toggles — one tap into a metric.
- "About this data" explainers and what the metric means clinically — buried at the bottom of the metric detail page.
- Everything not starred — the entire category tree lives in the **Browse** tab, a separate tab entirely.
- Highlights beyond the first two or three — behind "Show All Highlights."
- Data sources and app priority ordering — buried under profile → Apps / Data Sources & Access.
- Trends, Sharing, medical records — all in other tabs.

## 1.6 Deliberately OMITTED

- **Any composite score.** No "health score", no readiness number. Apple did not ship one here.
- **Any judgement language.** No "good", "low", "you should".
- **Any streak.** Health has no streak mechanic at all.
- **Any goal for non-Activity metrics.** Steps has no target in Health.

**Smart or dumb?** Omitting the composite score is *smart for Apple, dumb for the user*. Smart because a single wellness score is a de-facto medical claim across dozens of jurisdictions, and Apple's Health app is a data custodian and HealthKit host, not a coach. Dumb because a person with no health literacy cannot read a wall of un-benchmarked numbers — the omission moves 100% of the interpretation burden onto the least-equipped party. Apple's own fix for this is Highlights (comparisons), which is the correct instinct executed too quietly.

Omitting streaks is straightforwardly smart and under-appreciated: Health is where sick people, pregnant people, and people managing chronic conditions look. A streak-breaking mechanic in that context is cruel.

## 1.7 Strengths — mechanism, not adjectives

1. **Favorites is a user-declared salience filter, not an algorithmic one.** MacStories: "The new Favorites section is far and away the change I appreciate most in this release, because it meets almost every need I have when opening Health." The mechanism is that the app stops guessing. For a data app with 100+ metric types, a manual star is more robust than any ranking model.
2. **Recency-agnostic tiles.** Favorites show "their most recent data whether it's a month old, a week old, or was just added" (per Apple's description surfaced in search). This kills the empty-tile problem — a tile with a stale value is more useful than a tile with a dash.
3. **Highlights is a comparison engine, not a number display.** Comparing "flights climbed last week versus the week beforehand" converts an uninterpretable absolute into an interpretable delta. This is the single most transferable idea on the screen: *for a health-illiterate audience, a delta is legible where an absolute is not.*
4. **The Health Checklist is a safety-feature activation funnel disguised as a card.** It converts a settings-buried toggle into a home-screen task.
5. **Time-of-day dynamism** (How-To Geek) — the feed reorders as the day progresses, so sleep is relevant in the morning and activity in the evening.

## 1.8 Weaknesses — real complaints with sources

- **Favorites cannot be reordered.** Apple Community thread [255591685](https://discussions.apple.com/thread/255591685): "you cannot sort manually the items in Favorites. They are invariably displayed in alphabetical order." The original poster came from Garmin, expected to arrange favorites "in an order which is useful to me," found only on/off toggles, and filed feedback with Apple. MacStories flagged the same gap at launch in 2019: "The one missing feature is the ability to reorder favorites so they display in the order you choose." **Seven years unfixed.** Alphabetical ordering means "Blood Oxygen" outranks "Sleep" for structural reasons that have nothing to do with the user.
- **Highlights cannot be disabled.** Apple Community thread [250678522](https://discussions.apple.com/thread/250678522) is titled "how do i switch off apple health app highlights" — users searching for how to "switch it off, disable it or hide it" (thread body not fetchable, HTTP 429; title and search-surfaced summary only, so treat the exact quotes as `[UNVERIFIED]`).
- **Perceived clutter after tab-based redesign.** [MacRumors forum thread "Health App Redesign"](https://forums.macrumors.com/threads/health-app-redesign.2198289/) surfaced complaints that "everything is in tabs and seems messy" and that the new design is "not as organized and intuitive as the old one," with users saying they "can't even see data day by day as before." `[UNVERIFIED — surfaced via search summary, thread not directly fetched]`
- **Third-party apps exist specifically to de-clutter Apple Health.** The existence of an ecosystem whose pitch is "cut through the clutter of Apple Health" is itself the review.

## 1.9 What I would change

1. **Let users reorder Favorites.** Seven-year-old request, zero technical risk, highest-signal complaint in the corpus.
2. **Promote Highlights above Favorites.** The delta ("you climbed 30% more stairs this week") is the only interpretable content on the screen for a novice, and it sits below the fold behind a grid of raw numbers.
3. **Attach one benchmark line per Favorite tile.** Not a score, not a verdict — "typical for you: 5,800" is factual, defensible, and instantly makes 6,412 legible.
4. **Ship a real no-data state.** Today, a user with no Watch sees a sparse grid; a first-run screen that says "your iPhone is already counting your steps, here they are" converts that dead space into the app's single most persuasive moment.
5. **Move Health Checklist above the fold for the first 7 days, then demote it.** Activation-critical, then noise.

## 1.10 Numbers

- No Apple-published engagement figures for the Summary tab exist that I could find.
- iOS 26.4 was reported in Jan 2026 to bring a Health redesign with "a new layout for categories" and "simplified metric logging," plus food tracking, health videos from medical professionals, and an AI health agent that analyses Apple Health data ([9to5Mac, 11 Jan 2026](https://9to5mac.com/2026/01/11/apple-health-new-features-and-overhaul-coming-ios-26-4/)). Whether it shipped, and what the final layout is, is `[UNVERIFIED]` — my web-search budget ran out before I could confirm the shipped state.

---

# 2. Apple Fitness — Summary tab + Activity rings

## 2.1 Vertical order, top to bottom

Sources: [Apple Fitness App Store listing](https://apps.apple.com/us/app/apple-fitness/id1208224953), [Apple Support: See your activity summary](https://support.apple.com/guide/iphone/see-your-activity-summary-iph4c34a8a95/ios) (truncated on fetch), search-surfaced summaries of [AFB iOS 26 features](https://afb.org/blog/entry/ios-26-mainstream-features) and [Digital Trends](https://www.digitaltrends.com/mobile/how-to-customize-the-apple-fitness-app-in-ios-18/).

```
┌──────────────────────────────────────────┐
│ Summary                Tue 29 Jul  [⦿]   │
├──────────────────────────────────────────┤
│                                          │
│            ╭───────────────╮             │
│           │   ◜◝ ◜◝ ◜◝    │              │  ← THE RINGS. Enormous.
│           │  ◟◞ ◟◞ ◟◞     │              │    ~40% of first viewport.
│            ╰───────────────╯             │    Red / Green / Blue,
│      Move      Exercise    Stand         │    concentric, animated.
│    412/500     22/30 min   9/12 hrs      │
│                                          │
├─────────────── FOLD ─────────────────────┤
│  Steps                                   │
│  6,412                                   │
│  Distance          2.4 mi                │
│  Flights Climbed   7                     │
│                                          │
│  Workouts                     Show More ▸│
│  ┌────────────────────────────────────┐  │
│  │ 🏃 Outdoor Run  ·  32:11  ·  4.2 km│  │
│  └────────────────────────────────────┘  │
│                                          │
│  Training Load                           │  ← newer; intensity × duration
│  ┌────────────────────────────────────┐  │    over time
│  └────────────────────────────────────┘  │
│                                          │
│  Awards                       Show More ▸│  ← locked until earned
│  ┌────────────────────────────────────┐  │
│                                          │
│  Trends                       Show More ▸│  ← LOCKED until ~180 days of
│  ↑ Move   ↓ Exercise   → Stand           │    data; compares 90d vs 365d
│                                          │
│  Activity History (calendar)             │
│  [Edit] [See All Categories]             │  ← lower-left, per iOS 26
├──────────────────────────────────────────┤
│ [Summary] [Fitness+] [Workout] [Search]  │  ← iOS 26 tab bar per AFB;
└──────────────────────────────────────────┘    a Sharing tab also exists
                                                per the App Store listing
```

Note on tabs: the AFB iOS 26 write-up (via search) describes four bottom tabs — Summary, Fitness+, Workout, Search — while the App Store listing separately describes "a separate Sharing tab where you can see highlights of your friends' activity or start a friendly competition." I could not reconcile these two in one fetch; treat the exact iOS 26 tab set as `[UNVERIFIED]`. The Summary-tab ordering itself is well corroborated.

## 2.2 What appears FIRST, and why

**Three concentric rings, occupying roughly the top 40% of the screen, with no number larger than the rings themselves.**

The hypothesis is explicit in the design literature. Per [Trophy's breakdown](https://trophy.so/blog/the-psychology-of-apple-watchs-close-your-rings), the rings exploit **the Gestalt principle of closure**: "our brains are hardwired to seek completion." A ring at 90% creates "an open loop"—"a psychological tension that drives action to finish the activity."

Three design decisions in the ring system that are easy to miss and hard to copy:

1. **Move is personalised and adjustable** — "personalized, adjustable baselines to prevent discouraging beginners." The goal moves to the user, not the user to the goal.
2. **Exercise is 30 minutes because the WHO says so** — the number is externally anchored, not invented. That is what makes it defensible in an app with no medical claim.
3. **Stand is an hourly micro-goal** — it converts one large daily commitment into 12 tiny ones, so the ring is always partially closable by someone who has done nothing.

Plus **the 24-hour reset**: "a daily window of urgency" with "low enough stakes to be approachable, but firm enough to drive action."

## 2.3 The single action the screen is engineered to produce

**Go do enough movement today to close a ring.** Not "tap something." The screen's job is to send you *out of the app*. Every element below the rings is supporting evidence for that one instruction. This is the most disciplined home screen in the entire comparison set — it has exactly one job and it does not hedge.

## 2.4 Emotion in the first 3 seconds

**Pride or urgency — engineered to be one or the other, never neutral.**

- Rings closed: pride, a full-screen closure animation, a haptic.
- Rings 80% closed: urgency. This is the target state. Goal-gradient plus Gestalt closure.
- Rings 5% closed at 9pm: **guilt**, and this is the failure mode the design does not defend against.

The guilt is documented and non-trivial. [Heather Grace](https://www.heather-grace.com/blog/how-my-apple-watch-impacted-my-mental-health-and-how-i-fixed-it): "Those rings started to have power over my mood; how active I was determined how happy I felt." She describes losing a 365-day streak to a cancelled flight and being unable to pursue the goals without harm given her perfectionism and anxiety. Her fixes were behavioural, not in-app: disable comparison notifications, and **change her watch face to remove the rings entirely**. The product had no lower-intensity mode to offer her.

Trophy names the retention mechanic honestly: streaks create "sunk cost bias" — users resist breaking chains they have built — and this "has the potential to double daily active usage." The same sentence describes the retention win and the mental-health liability.

Macworld's expert commentary ([Ring toss](https://www.macworld.com/article/3183369/ring-toss-why-the-apple-watch-activity-goals-need-an-update.html)) argues for shifting "emphasis from daily streaks to weekly consistency," which is "often more realistic and less guilt-inducing," and notes calories are "intuitive" but "noisy and sometimes demotivating." It also makes the segmentation point that should govern any ring-like feature: "those already active may not need it. Those strongly disengaged might ignore it, but people in the middle often benefit most from nudges and clear targets."

## 2.5 Hidden behind taps / progressive disclosure

- **Trends is time-locked.** It does not exist until you have accumulated enough history; then it compares your last 90 days against your last 365. Deliberate — a trend computed on 4 days of data is noise, and showing noise as insight destroys trust permanently.
- **Awards are locked and greyed until earned** — visible-but-unattained, which is the collection mechanic.
- Ring goals and per-weekday customisation (iOS 18+ lets you set different Move goals per day of week, or pause rings for rest days) sit behind Edit.
- Per-workout route maps, pace splits, heart-rate zones — one tap into a workout.
- Sharing / competitions — separate tab.

## 2.6 Deliberately OMITTED

- **Weight.** Not on the Fitness home screen at all.
- **Calories eaten.** Fitness shows burn, never intake. Enormous call: it keeps the app out of the diet-app emotional register and out of eating-disorder territory.
- **Any sleep or recovery metric on Summary.** Sleep lives in Health, not Fitness.
- **A composite fitness score.** No single number.
- **Any negative framing.** There is no "you failed today" copy. The empty ring is allowed to speak for itself.

**Smart or dumb?** Omitting intake is smart and structural — the moment burn and intake appear on one screen you have built a diet app, and the emotional profile changes from "did I move" to "am I allowed to eat." Omitting weight is likewise smart: weight is a lagging, noisy, shame-loaded metric, and rings are about a controllable input.

Omitting a composite score is smart *here* specifically because the rings already are a composite — three dimensions rendered as one visual gestalt. That is the trick worth stealing: **a composite you can read without reading a number.**

## 2.7 Strengths — mechanism

1. **The rings are a pre-attentive composite.** You perceive three-dimensional progress before you read anything. No number can do this. Any home screen whose top element requires reading has already lost to this.
2. **Personalised, adjustable Move goal** — the difficulty curve adapts, so the loop does not eject beginners.
3. **Externally-anchored Exercise goal (WHO 30 min)** — credible without making a medical claim.
4. **Hourly Stand micro-goal** — always a closable sub-goal available, so the screen is never entirely hopeless.
5. **Daily reset** — bounded stakes, renewable urgency.
6. **Trend-locking** — refuses to show trends until the data supports them.
7. **Progressive-unlock information architecture** — Trends and Awards materialise as the user earns the right to see them, so the day-one screen is simple and the day-200 screen is rich. Same app, different density.

## 2.8 Weaknesses — real complaints with sources

- **Guilt / mood coupling and streak-loss trauma.** [Heather Grace, first-person account](https://www.heather-grace.com/blog/how-my-apple-watch-impacted-my-mental-health-and-how-i-fixed-it), quoted above. The only remedy available to her was to remove the rings from her watch face.
- **Overjustification / motivation crowd-out.** Search-surfaced analysis ([UX Magazine on streak design](https://uxmag.medium.com/the-psychology-of-hot-streak-game-design-how-to-keep-players-coming-back-every-day-without-shame-3dde153f239c), [Smashing Magazine, Feb 2026](https://www.smashingmagazine.com/2026/02/designing-streak-system-ux-psychology/)) describes streaks and badges shifting motivation from internal ("I enjoy this") to external ("I need my number") — the overjustification effect. Grace's own version: activity trackers increase movement but "the same people enjoy their activities less."
- **Calorie-based Move goal is noisy and demotivating for some users** (Macworld expert commentary).
- **Three metrics may be the wrong three.** Macworld's expert proposes replacing them with "nutrition, exercise and sleep," or with "total minutes of cardiovascular activity, minutes spent in zone five… and strength."
- **Ring closure is rarer than the marketing implies.** A search-surfaced claim states "fewer than 40% of Apple Watch users close all three rings on any given day," and separately that 83% of Apple Watch users say it improved their health. **Both `[UNVERIFIED]`** — the sources surfaced (vertu.com, fitnesswrapped.com) are low-quality SEO pages, not Apple or peer-reviewed data. Do not quote these to anyone.

## 2.9 What I would change

1. **Ship a low-intensity mode, not just per-day goal editing.** A one-tap "maintenance mode" that keeps tracking, keeps trends, and drops the streak/closure pressure — for illness, injury, pregnancy, burnout, and the perfectionist cohort. Today the only exit is to hide the rings entirely, which loses the user.
2. **Make the primary streak weekly, keep daily as texture.** Per the Macworld argument: weekly consistency is more realistic and less guilt-inducing, and it survives a cancelled flight.
3. **Show a "typical you" ghost ring.** Comparison against your own last-4-weeks average is more actionable than a fixed goal and gives credit for a good day that still missed the target.
4. **Add one line of plain-English interpretation under the rings.** "22 of 30 exercise minutes — a 10-minute walk closes it." The rings are legible; the *next action* is not.

## 2.10 Numbers

From [Apple Newsroom, April 2025](https://www.apple.com/newsroom/2025/04/get-active-with-apple-watch/), based on the Apple Heart and Movement Study (with Brigham and Women's Hospital and the American Heart Association), "more than 140,000 participants" analysed within a study of "more than 200,000 participants across the United States." Comparing frequent ring-closers (closing ≥50% of the time) against infrequent closers (≤10%):

- **48% less likely** to experience poor sleep quality
- **73% less likely** to experience elevated resting heart rate
- **57% less likely** to report elevated stress (PSS-4)
- Associations "consistent across men and women, and across all age groups"

Read the causality carefully: this is observational and self-selecting. Apple is careful to say "less likely," not "because of." It is still the single strongest published behavioural claim any of these six apps has made about its home-screen metaphor.

---

# 3. Fitbit → Google Health

## 3.1 Status: the app changed name and owner-model mid-research

The Fitbit app **became the Google Health app on 19 May 2026** ([search-surfaced, corroborated across 9to5Google and PiunikaWeb coverage](https://9to5google.com/2026/05/10/google-health-kills-the-fitbit-we-knew-but-maybe-thats-not-a-bad-thing/)). The redesign first appeared in public preview in October 2025 with the Gemini health coach ([TechCrunch, 27 Oct 2025](https://techcrunch.com/2025/10/27/fitbits-revamped-app-with-gemini-powered-health-coach-rolls-out-to-premium-users/)).

## 3.2 Vertical order, top to bottom

Sources: [Google Health Help — Explore the redesigned Fitbit app](https://support.google.com/googlehealth/answer/16959617?hl=en_sg), [Google Health Help — What's new](https://support.google.com/fitbit/answer/17068213?hl=en), [Engadget hands-on](https://www.engadget.com/ai/a-closer-look-at-googles-ai-health-coach-and-the-redesigned-fitbit-app-160041881.html), [PiunikaWeb backlash coverage](https://piunikaweb.com/2026/05/25/google-health-app-fitbit-backlash-missing-features-ui-changes/).

```
┌──────────────────────────────────────────┐
│ Today                          [avatar]  │
├──────────────────────────────────────────┤
│  FOCUS METRICS  (user-customisable)      │
│  ┌────────┐ ┌────────┐ ┌────────┐        │  ← bars + rings.
│  │ ◉ Steps│ │ ▮ Sleep│ │ Ready- │        │    Teal = steps,
│  │  6,412 │ │ 6h 51m │ │ ness 74│        │    Purple = sleep.
│  └────────┘ └────────┘ └────────┘        │    Also: weekly cardio load,
│                                          │    calories.  [Edit]
├──────────────────────────────────────────┤
│  MESSAGES FROM YOUR COACH  (Premium)     │  ← morning readiness read-out,
│  ┌────────────────────────────────────┐  │    post-workout breakdown,
│  │ "Your readiness is lower than…"    │  │    evening recap.
│  │  <long AI paragraph>               │  │    THIS IS THE COMPLAINT ZONE.
│  └────────────────────────────────────┘  │
├─────────────── FOLD ─────────────────────┤
│  CARD FEED                               │
│  ┌────────────────────────────────────┐  │
│  │ Upcoming workout                   │  │
│  ├────────────────────────────────────┤  │
│  │ Recent activity                    │  │
│  ├────────────────────────────────────┤  │
│  │ Progress report                    │  │
│  └────────────────────────────────────┘  │
│                                          │
│        ( large empty region — the        │  ← "a huge block of empty space
│          documented complaint )          │     sits underneath"
│                                          │
│                            ┌───────────┐ │
│                            │ ✦ Ask     │ │  ← FLOATING, bottom-right,
│                            │   Coach   │ │    on EVERY page of the app
│                            └───────────┘ │
├──────────────────────────────────────────┤
│  [Today]  [Fitness]  [Sleep]  [Health]   │  ← 4 tabs with a device;
└──────────────────────────────────────────┘    2 tabs (Today, Health)
                                                without one
```

Google's own help page gives the Today tab as exactly two sections in order: (1) a **metrics dashboard** — "quick access to the metrics you care about most, such as steps, weekly cardio load, readiness, calories, and sleep," customisable via Edit; then (2) **Messages from your coach** (Premium) — morning readiness assessments, post-workout performance breakdowns, evening activity recaps.

## 3.3 What appears FIRST, and why

**Customisable focus metrics as bars and rings.** Engadget confirms the colour convention survived the rebrand: "purple represents sleep data, teal indicates steps."

The hypothesis for why customisation was chosen over a fixed hierarchy: Fitbit's install base spans trackers, smartwatches, the Pixel Watch, and app-only users with wildly different sensor coverage, so any fixed top-of-screen metric is wrong for a large slice of users. Letting the user pick is the cheap fix. The 2023 redesign already introduced a "customized focus" concept and Google promised to expand it ([Android Police](https://www.androidpolice.com/upcoming-changes-to-the-fitbit-app/)).

## 3.4 The single action the screen is engineered to produce

**Tap "Ask Coach."** This is unambiguous and it is the redesign's whole thesis. Engadget: the floating Ask Coach button "appears at the bottom right of every page, accessible across all tabs," and "the entire app was rebuilt so the health coach can understand your goals, build your plan, contextualize your metrics and bring insights at the right moments."

It is also the single most criticised decision. Kotaku quotes a reviewer: **"Why is the biggest button on the screen for AI questions? You're a fitness app; the biggest button should be to add an activity."** ([Kotaku](https://kotaku.com/google-fitbit-app-health-new-update-ai-filled-version-and-everybody-is-mad-2000699806))

## 3.5 Emotion in the first 3 seconds

**Intended: calm reassurance ("your coach has read your data"). Delivered: mild anxiety plus irritation.**

The delivered emotion is documented. PiunikaWeb: "Coach prompts and AI-generated text occupy space before actual health statistics display, creating an 'intrusive' and 'unnecessary' layer that impedes quick data access." A Kotaku staffer reported receiving unwanted AI-generated sleep summaries she never asked for, and cancelled her paid subscription over it.

Worse, for a period in May 2026 the emotion was **confusion** — the Today tab rendered completely blank for many users. PiunikaWeb documented daily vitals, sleep scores, readiness and weekly goal progress all missing, with one user describing the app as "trying to train their brain to absorb information in 30 milliseconds" as data flashed and vanished ([PiunikaWeb, 5 May 2026](https://piunikaweb.com/2026/05/05/fitbit-app-update-blank-today-tab/)).

## 3.6 Hidden behind taps

- Weekly goal progress — **moved off Today into the Fitness tab** (a documented complaint).
- SpO2 — moved to the Health tab.
- Everything sleep-detailed — Sleep tab.
- Card details — each feed card is a tap-through.
- Metric selection — behind Edit on the dashboard.
- All reasoning behind a readiness or cardio-load number — behind Ask Coach, i.e. behind a chat turn.

## 3.7 Deliberately OMITTED (removed, in this case)

Per Google's own "What's new" page and PiunikaWeb's inventory, the redesign **removed**:

- Badges and celebrations — historical badges deleted
- Sleep Profile and the monthly "sleep animals"
- Estimated Oxygen Variation (EOV)
- Groups, Community Feed, direct messaging, custom usernames, profile photos
- Hourly step tracking graphics and the day-by-day step visual
- 250-step hourly reminders
- Snore detection for Sense / Versa 3
- Numeric stress score — "Resilience replaces Stress score," with descriptive categories replacing numeric values
- Cardio fitness score renamed to VO2 max
- Daily goals replaced by **weekly cardio targets**

**Smart or dumb?**

Smart: **replacing the numeric stress score with descriptive categories.** A number implies precision the sensor does not have; a category is honest. Also smart: **daily → weekly cardio targets**, which is exactly the fix Macworld's experts recommended for Apple's rings — less guilt, more realism.

Dumb, and expensive: **deleting badges, sleep animals, groups, and community.** Those were the app's entire emotional layer. Fitbit's differentiator versus Apple was never sensor quality — it was that Fitbit felt social and playful. Stripping it left a metrics dashboard with a chatbot, competing head-on with Apple on Apple's terms. Also dumb: **killing 250-step hourly reminders**, which was Fitbit's equivalent of the Stand ring — the micro-goal that keeps a sedentary user in the loop.

## 3.8 Weaknesses — real complaints with sources

- **Dead space below the fold.** PiunikaWeb: the Today tab "highlights steps, readiness, and sleep at the top, but then a huge block of empty space sits underneath, making the interface feel unfinished rather than intentional." Direct user quote: **"Why so much white wasted space?"**
- **AI text sits above the data.** PiunikaWeb, quoted above. Kotaku's biggest-button quote.
- **Loss of tile-size control.** One user "could not" keep sleep as a large tile as before, calling it "a design change to something that wasn't broken."
- **Blank Today tab bug** persisting nearly a week ([PiunikaWeb](https://piunikaweb.com/2026/05/05/fitbit-app-update-blank-today-tab/)).
- **Navigation obscures data.** A Reddit thread titled "Google Health is inoperable" is cited by PiunikaWeb for exactly this.
- **Scale of revolt.** A Fitbit Community feedback thread asking to return to the previous app accumulated **3,419 votes and 3,255 comments** (PiunikaWeb). Play Store review-bombing and Reddit posts calling the app "ruined" and "slop" ([9to5Google](https://9to5google.com/2026/05/27/google-health-roadmap-fitbit-backlash/)).
- **Data-quality regressions:** runs converted to generic workouts, losing maps, pace and cadence; duplicate activities from Health Connect integrations.
- **This is the second Fitbit home-screen revolt, not the first.** In 2023 the three-tab redesign (Today / Coach / You) removed the Steps streak and the device battery indicator from Today; users objected that "the new look made things less readable, with increased spacing and a less intuitive arrangement of information," and Google committed to restore the streak (with progress preserved and celebration animations), restore the battery indicator, "tighten up the spacing and tweak the layout," expand customisable focus, and add dark mode ([Android Police](https://www.androidpolice.com/upcoming-changes-to-the-fitbit-app/)). Google made the same spacing mistake again three years later.

## 3.9 What I would change

1. **Demote Ask Coach to a header affordance; promote a primary logging FAB.** Take the Kotaku complaint literally — the biggest button should be the most frequent action.
2. **Coach message goes below the metrics, collapsed to one sentence, expandable.** Google's own roadmap already half-concedes this: make coach messages "more concise" and include charts and maps.
3. **Fill the dead space with the thing they deleted.** Hourly step distribution is the single best use of that region — it is glanceable, it needs no AI, and it is the one view that tells a sedentary person *when* to move.
4. **Restore a micro-goal.** Weekly cardio targets are the right macro frame, but a user needs something closable today. The 250-step hourly nudge was that, and it was free.
5. **Restore playfulness in some form.** Not necessarily badges — but the emotional layer needs a replacement, not a deletion.

## 3.10 Numbers

- **3,419 votes / 3,255 comments** on the revert request thread (PiunikaWeb).
- **39-item roadmap** published within days of the backlash peaking, with fixes "starting as soon as this week and continuing on an ongoing basis into the summer" ([9to5Google](https://9to5google.com/2026/05/27/google-health-roadmap-fitbit-backlash/)).
- Of those 39 items, **exactly one** addresses home-screen layout: "Make it easier to customize your Today and Health dashboards so you can more easily re-arrange metrics within them or add or remove metrics." Nothing on the empty-space complaint. Read that as Google treating the layout complaint as a customisation problem rather than a hierarchy problem — which it is not.
- Play Store rating-drop magnitude: `[UNVERIFIED]` — review-bombing is widely reported, but I found no numeric before/after.

---

# 4. Google Fit — post-mortem

## 4.1 Status: dead

Google Fit shut down in 2025; the Fit REST and Android APIs stopped accepting new developer signups on 1 May 2024 and are scheduled for end-of-service in late 2026. Fit users were migrated into Google Health; migration for existing users completed in May 2026, and **accounts not moved by 15 July 2026 were deleted** ([9to5Google, 7 May 2026](https://9to5google.com/2026/05/07/google-fit-shut-down-health-replacement-migration-tool-coming/); corroborated by search-surfaced Yahoo/AlternativeTo coverage).

It is still worth the teardown, because its home screen contained one idea nobody has beaten.

## 4.2 Vertical order, top to bottom

Source: [9to5Google hands-on with the Material Theme redesign](https://9to5google.com/2018/08/22/hands-on-google-fit-redesign/), [Wareable guide](https://www.wareable.com/sport/how-to-use-google-fit-get-set-with-the-android-fitness-platform).

```
┌──────────────────────────────────────────┐
│ Home                          [avatar]   │
├──────────────────────────────────────────┤
│                                          │
│            ╭───────────────╮             │
│           │   ◜◝◜◝◜◝      │              │  ← TWO rings only.
│           │  ◟◞◟◞◟◞       │              │    Green outer = Heart Points
│            ╰───────────────╯             │    Blue inner  = Move Minutes
│         Heart Points   12                │
│         Move Minutes   47                │    On completion the circles
│                                          │    MORPH INTO OCTAGONS.
├──────────────────────────────────────────┤
│   6,412 steps   ·  212 Cal  ·  4.7 km    │  ← smaller font, one row,
│                                          │    tappable → Day/Week/Month
├─────────────── FOLD ─────────────────────┤
│  ┌────────────────────────────────────┐  │
│  │ Steps          ▁▃▅▂▇▄▆             │  │
│  ├────────────────────────────────────┤  │
│  │ Heart rate     ▁▃▅▂▇▄▆   (if avail)│  │
│  ├────────────────────────────────────┤  │
│  │ Weight         ▁▃▅▂▇▄▆             │  │
│  └────────────────────────────────────┘  │
│                                     (+)  │  ← FAB: add data / start workout
├──────────────────────────────────────────┤
│  [Home]  [Journal]  [Profile]            │  ← animated icons; Home rings
└──────────────────────────────────────────┘    rotate, Journal clipboard swings
```

## 4.3 What appears FIRST, and why

**Two rings — Heart Points (green, outer) and Move Minutes (blue, inner).**

Google developed both metrics **alongside the American Heart Association**, framing Heart Points as exercise *quality* and Move Minutes as *quantity*. That is the same play Apple made with the WHO's 30 minutes: borrow an external body's credibility so the metric is defensible without being a medical claim.

**Two rings instead of three is the interesting choice.** It is strictly easier to read pre-attentively than three, and it maps to a genuine conceptual split (any movement vs. movement that raises your heart rate) rather than to three sensor streams.

## 4.4 The single action the screen is engineered to produce

**Earn Heart Points.** Google made this the hero metric because it is the one that survives contact with the AHA's evidence base — you can walk 10,000 slow steps and earn very few Heart Points, and Google wanted that to be visible.

## 4.5 Emotion in the first 3 seconds

**Calm and slightly playful.** The octagon morph on completion is the tell — a small, delightful, non-triumphal reward. Google Fit never reached the pride/guilt intensity of Apple's rings, partly because it had no streak, no awards wall, and no social comparison. That made it the least anxious health home screen in this set — and also, arguably, the least sticky, which is one plausible reason it is dead. `[UNVERIFIED — I found no data attributing Fit's shutdown to engagement.]`

## 4.6 Hidden behind taps

- Everything historical — one tap on any metric opens a graph filterable by Day / Week / Month.
- "My activity" breakdown of *when* points were earned — behind the avatar tap.
- Activity log — Journal tab.
- Adding data / starting a workout — behind the FAB.

## 4.7 Deliberately OMITTED

- **No streak.** No awards. No badges. No social feed. No leaderboard.
- **No sleep on the home screen.**
- **No composite score.**
- **Steps demoted to small text** — deliberately, so Heart Points could be the hero.

**Smart or dumb?** Demoting steps was **intellectually right and commercially wrong.** Right, because step count is a poor proxy for cardiovascular benefit and Google had AHA evidence saying so. Wrong, because step count is the only health metric the mass market already understands, and Fit spent its top-of-screen real estate teaching a new vocabulary to users who had not asked for one. Every subsequent Google product put steps back at the top — the Google Health Today tab leads with steps.

Omitting all gamification was defensible but left the app with no reason to be opened on a day when nothing happened.

## 4.8 Weaknesses

- The 9to5Google hands-on is largely positive and does not analyse retention; the honest summary is that I found **no substantive documented user complaint corpus** for Fit's home screen the way I did for the other five. `[UNVERIFIED]`
- The structural weakness is inferable from what happened next: two novel metrics with no external reference point, no streak, and no social layer produced a screen with nothing to come back for. Google's own successor product abandoned both metrics.

## 4.9 What I would change

1. **Lead with steps, teach Heart Points second.** Put the familiar number in the hero slot and use the ring to *reinterpret* it: "6,412 steps → 12 Heart Points, because most of it was slow." That teaches the new concept using the old one as scaffolding, instead of replacing it.
2. **Keep the two-ring composite.** It is more readable than three and the quantity/quality split is genuinely educational.
3. **Keep the octagon morph.** A low-intensity, non-streak reward is the right celebration for a general-population health app.

## 4.10 Numbers

None published that I could verify. Migration deadline (15 July 2026) and API end-of-service (late 2026) are the only hard dates.

---

# 5. Samsung Health

## 5.1 Vertical order, top to bottom

Redesign rolled out **8 June 2026** with One UI 9, initially Galaxy S26 only. Sources: [Android Authority hands-on](https://www.androidauthority.com/samsung-health-app-2026-update-hands-on-3679261/), [Samsung US product page](https://www.samsung.com/us/apps/samsung-health/), [SamMobile](https://www.sammobile.com/news/theres-an-all-new-samsung-health-and-heres-whats-changed/), plus search-surfaced Samsung Newsroom and SammyFans coverage.

```
┌──────────────────────────────────────────┐
│ ⌂  Activity  Sleep  Vitals  Mind  Nutri  │  ← TOP TOOLBAR: home + 5 pillars
├──────────────────────────────────────────┤   (this is new; a second nav)
│  ┌────────────────────────────────────┐  │
│  │  ENERGY SCORE            78        │  │  ← big blue banner, large
│  │  "Moderate — you slept well but…"  │  │    real-estate footprint.
│  │                                    │  │    Requires Galaxy Watch or Ring.
│  └────────────────────────────────────┘  │
│  ┌────────────────────────────────────┐  │
│  │  DAILY WELLNESS TIP                │  │  ← second anchor element
│  └────────────────────────────────────┘  │
├─────────────── FOLD ─────────────────────┤
│  WIDGET GRID  (drag / resize, weather-   │
│                app style)                │
│  ┌──────────┐ ┌──────────┐               │
│  │ Steps    │ │ Sleep    │               │  ← "tooth-achingly bright"
│  │  6,412   │ │ 6h 51m   │               │    per Android Authority
│  └──────────┘ └──────────┘               │
│  ┌─────────────────────────┐ ┌────────┐  │
│  │ Heart Rate              │ │ Water  │  │
│  └─────────────────────────┘ └────────┘  │
│  ┌──────────┐ ┌──────────┐               │
│  │ Food     │ │ Stress   │               │
│  └──────────┘ └──────────┘               │
│  … plus widgets for hardware you do not  │  ← default-on, must be removed
│    own, on by default                    │    manually. Documented gripe.
│                                          │
│                            [+ Quick Add] │  ← workouts / weight / food
├──────────────────────────────────────────┤
│  [Home]  [Together]  [Fitness]  [⋯]      │  ← bottom bar (exact set
└──────────────────────────────────────────┘    `[UNVERIFIED]`)
```

Android Authority confirms the **top shortcut bar** with Activity, Sleep, Vitals, Mindfulness, Nutrition plus a return-to-dashboard option, and that users "can customize widgets by moving, expanding, and shrinking them across the main dashboard area" — a pattern the reviewer compares to "smartly designed weather apps." SamMobile confirms the app "now features both a bottom menu bar and a top toolbar," and a new **quick add** for workouts, weight and food. Search-surfaced Samsung and SammyFans coverage states "two additions anchor the new home screen experience: daily wellness tips and an AI-generated Energy Score," with the Energy Score appearing as a **top blue banner that takes up significant home screen real estate**. The exact bottom-tab set is `[UNVERIFIED]` — my fetches of SammyFans and Android Central were blocked (403 / truncation).

## 5.2 What appears FIRST, and why

**Energy Score — a single AI-generated readiness number.**

Samsung's stated intent (surfaced via Samsung's own materials): a "single, digestible number that reflects how recovered and ready they are for the day ahead, pulling from sleep quality, overnight biometric readings, and activity history," delivered the next morning based on at least the previous day's activity and sleep, with tips if it is lower than expected.

The hypothesis for placing it first: Samsung is playing the Whoop/Oura game. The competitive insight is real — a readiness score is the only health metric that answers a question the user actually has at 7am ("how should I plan today?") rather than reporting what already happened. Steps at 7am is worthless; readiness at 7am is a decision input.

**The structural problem:** Energy Score requires a Galaxy Watch or Galaxy Ring. For the majority of Samsung Health's install base — [reported at 65M+ MAU and 1B+ downloads, `[UNVERIFIED]`, source nikolaroza.com is a low-quality stats aggregator](https://nikolaroza.com/samsung-health-statistics-facts-trends-data/) — the hero element of the home screen is a hardware upsell they cannot fill. That is a home screen whose top slot is empty for most users.

## 5.3 The single action the screen is engineered to produce

**Two actions, which is one too many.** Read the Energy Score (and by extension, buy a Galaxy Watch or Ring to get one), and navigate into one of the five pillars via the top toolbar. The quick-add button is a distant third.

The dual navigation — top toolbar *and* bottom bar — is the clearest evidence that Samsung could not decide. Two persistent navigation surfaces on one screen means the design never resolved whether Home is a dashboard or a hub.

## 5.4 Emotion in the first 3 seconds

**Overstimulation.** Android Authority is blunt about the colour system: "tooth-achingly bright widget cards," "excessive, incoherent color usage with no correlation to data types," and "colors and the relationships between these metrics are incongruent."

That is a specific, mechanical failure, not a taste complaint. When colour does not encode meaning, every card competes equally for attention and the user's eye has no entry point — so the composite emotion is closer to *mild stress* than to calm, pride, or curiosity. Compare Fitbit, where purple always means sleep and teal always means steps; and Apple, where red/green/blue map permanently to Move/Exercise/Stand. Samsung's colours are decoration.

Where a valid Energy Score is present, the intended emotion is **calm confidence**. Where it is absent, the emotion is **being sold to**.

## 5.5 Hidden behind taps

- Everything per-pillar — Activity, Sleep, Nutrition, Mindfulness, Vitals each behind a toolbar tap.
- Heart Health Score, Fitness Index, sleep apnea detection, ECG, blood pressure trending, medication reminders, AGEs index, weekly reports — all named on Samsung's product page, none on the home screen by default.
- Energy Score reasoning and "tips for customized advice on where to focus" — behind a tap on the score.

## 5.6 Deliberately OMITTED

- **No streak.**
- **No daily goal ring as hero** — steps demoted to a widget among widgets.
- **No social layer on Home.**
- Notably **not** omitted, and this is the flaw: **widgets for hardware the user does not own are on by default and must be removed manually** (Android Authority). Samsung omitted the wrong things.

**Smart or dumb?** Leading with readiness instead of a goal ring is smart and forward-looking — it is the correct 2026 read of where consumer health is going. Gating it behind hardware and then not designing a first-class fallback for the un-gated majority is dumb, and it is the single biggest own-goal in this teardown. A readiness score that degrades gracefully (phone-only: sleep estimate + activity + a lower-confidence badge) would have been strictly better than an empty hero.

## 5.7 Strengths — mechanism

1. **Readiness-first framing answers a forward-looking question.** Every other app on this list answers "what did you do?"; Samsung answers "what should you do?" That is a genuinely different and better job-to-be-done for a morning open.
2. **Weather-app widget model.** Drag, resize, reorder — this is the customisation model Apple Health has refused to ship for seven years, and it is the one users keep asking every vendor for.
3. **Five pillars as a stable mental model.** Activity, Sleep, Nutrition, Mindfulness, Vitals is a genuinely good taxonomy for a general-population audience — it is complete, non-overlapping, and jargon-free.
4. **Persistent top shortcut bar** means the pillar you want is always one tap away regardless of scroll position.
5. **Quick add** for workouts, weight, and food removes the most common multi-tap chore.

## 5.8 Weaknesses — real complaints with sources

- **Colour system carries no meaning.** Android Authority, quoted above: "excessive, incoherent color usage with no correlation to data types."
- **Default clutter from unsupported features.** Android Authority: unsupported device features "clutter the dashboard by default, forcing manual removal."
- **Inconsistent interaction grammar** — pinch-to-zoom works on some graphs and not others (Android Authority).
- **No multi-metric comparison** — you cannot put two metrics on one chart, which is the core analytical need of anyone trying to connect sleep to anything (Android Authority).
- **Reviewer's overall verdict** was to "enjoy the old Samsung Health product while it's still around."
- **Dark mode regression on a prior update.** A Samsung Members thread is titled "Samsung Health Update: New UI Ruined the Premium AMOLED Dark Mode" ([r2.community.samsung.com](https://r2.community.samsung.com/t5/Samsung-Health/Samsung-Health-Update-New-UI-Ruined-the-Premium-AMOLED-Dark-Mode/m-p/22473940)) — `[UNVERIFIED]`, title surfaced via search, thread not fetched.
- **Energy Score hardware gate** — requires Galaxy Watch or Ring sync (Samsung's own documentation).

## 5.9 What I would change

1. **Make Energy Score degrade, never disappear.** Phone-only version from step cadence, screen-time proxy for sleep window, and manual check-in, labelled with a confidence level. An honest low-confidence score beats an empty hero.
2. **Make colour mean something and then never break it.** One hue per pillar, locked. Sleep is always the same colour in every widget, chart, and tab. This is a one-week change with a permanent payoff.
3. **Kill the top toolbar or the bottom bar.** Two persistent navs is a decision the team owes the user.
4. **Default the widget grid to the user's actual sensors.** Zero widgets for hardware they do not own. Detect at first run.
5. **Add a two-metric overlay chart.** Sleep vs. steps, sleep vs. resting HR. This is the reviewer's request and it is also the only way the five-pillar model produces an insight rather than five silos.

## 5.10 Numbers

- Redesign announced 4 June 2026, rollout from 8 June 2026, One UI 9 / Galaxy S26 first.
- 65M+ MAU, 1B+ downloads — `[UNVERIFIED]`, aggregator source only.
- No published engagement effect of the redesign.

---

# 6. MyFitnessPal

## 6.1 Vertical order, top to bottom

The Diary tab was replaced by a Today tab in **v26.16.0, 21 April 2026** ([mwm.ai](https://mwm.ai/articles/myfitnesspal-v26-16-0-replaces-diary-with-new-ui-sparking-rating-drop-in-april-2026)). Sources for the order: [MyFitnessPal Help — Introducing the brand new Today tab](https://support.myfitnesspal.com/hc/en-us/articles/39985611667341-Introducing-the-brand-new-Today-tab) (403 on direct fetch; contents recovered via search summary), [MyFitnessPal blog](https://blog.myfitnesspal.com/myfitnesspal-today-screen-progress-tab-update/) (403), [App Store listing](https://apps.apple.com/us/app/myfitnesspal-calorie-counter/id341232718), [PiunikaWeb](https://piunikaweb.com/2026/04/24/myfitnesspal-new-update-complaints/).

```
┌──────────────────────────────────────────┐
│ Today                    🔥 47 day streak│  ← STREAK AT THE VERY TOP
├──────────────────────────────────────────┤
│  ┌────────────────────────────────────┐  │
│  │        ◜◝◜◝◜◝                      │  │  ← calorie ring + macro bars
│  │       │  1,240   │                 │  │    "Calories consumed and
│  │       │ remaining│                 │  │     remaining"
│  │        ◟◞◟◞◟◞                      │  │
│  │  Carbs ▓▓▓░  Fat ▓▓░░  Prot ▓▓▓▓░  │  │  ← free users see % only;
│  └────────────────────────────────────┘  │    Premium can toggle g
├─────────────── FOLD ─────────────────────┤    consumed / g remaining / %
│  MEALS  (large cards, one per meal)      │
│  ┌────────────────────────────────────┐  │
│  │ Breakfast              412 kcal  + │  │  ← must TAP IN to see items
│  ├────────────────────────────────────┤  │    (the core complaint)
│  │ Lunch                  680 kcal  + │  │
│  ├────────────────────────────────────┤  │
│  │ Dinner                   — kcal  + │  │
│  ├────────────────────────────────────┤  │
│  │ Snacks                   — kcal  + │  │
│  └────────────────────────────────────┘  │
│                          [ View All ▸ ]  │  ← full diary is BEHIND THIS
│                                          │
│  [ Complete Diary ]                       │  ← appears once ≥1 food logged
│                                          │
│  HEALTHY HABITS                          │
│  ┌────────┐ ┌────────┐ ┌────────┐        │
│  │ Water  │ │Exercise│ │ Steps  │        │  ← + weight
│  └────────┘ └────────┘ └────────┘        │
│                                          │
│  [ banner ad — free tier ]               │
├──────────────────────────────────────────┤
│  [Today] [Progress] [ (+) ] [Plans] [Me] │
└──────────────────────────────────────────┘
```

The App Store listing describes the change in one line: the redesigned Today section brings "your diary, calories, macros, and habits together on the home tab."

## 6.2 What appears FIRST, and why

**The logging streak, then calories remaining.**

Streak-first is a naked retention decision. MyFitnessPal's business is a subscription whose value is proportional to logging consistency; the streak is the cheapest available consistency lever, and putting it in the top-most slot means the user's first perception is of an asset they own and could lose.

Calories *remaining* rather than *consumed* is the more interesting choice and it is correct: remaining is a forward-looking budget you can spend, consumed is a backward-looking receipt you cannot change. Budget framing produces a decision ("what can I have for dinner"); receipt framing produces a judgement ("I already blew it"). MyFitnessPal has understood this for over a decade and the redesign kept it.

## 6.3 The single action the screen is engineered to produce

**Log a food.** Every meal card carries its own `+`. The centre tab-bar button is add. There is no ambiguity about this app's one action — which makes the execution failure below all the more striking.

## 6.4 Emotion in the first 3 seconds

**Accountability, tipping into guilt as the day progresses.** Morning: a full budget, a live streak, mild optimism. Evening with 1,800 of 1,600 consumed: the ring is over, the number goes negative, and the emotion is guilt.

This is the most guilt-loaded home screen of the six, structurally — a calorie budget is a screen you can *fail* mid-day in a way you cannot fail a step count. MyFitnessPal mitigates it by never using judgemental copy and by keeping the streak tied to *logging*, not to *hitting the target*. That last detail is genuinely good design: you can eat a whole cake and still keep your streak, so the app never gives you a reason to stop logging. Every other streak in this teardown punishes the behaviour rather than the record-keeping.

## 6.5 Hidden behind taps

- **The actual diary contents.** Individual food items now sit inside each meal card; PiunikaWeb reports "the food diary is buried behind a 'View All' button."
- **Per-meal macro breakdowns** — "harder to find" post-redesign (PiunikaWeb).
- Macro display modes (grams consumed / grams remaining / % of calories) — **Premium and Premium+ only**; free accounts see percentages only.
- Nutrient dashboard configuration (Macros + Heart Healthy, or Macros + Carb Conscious) — behind settings.
- Trends, weight history, reports — Progress tab.

## 6.6 Deliberately OMITTED

- **Removed: copying individual food items between meals or days** (mwm.ai) — a power-user workflow, deleted.
- **Removed: the prominent at-a-glance calorie adjustment from steps** (mwm.ai). The "you earned 210 calories from exercise" line used to be a headline; it is now demoted. Arguably smart — exercise-calorie credit is the most-abused and least-accurate mechanic in calorie tracking, and MyFitnessPal's own numbers over-credit — but the change was made silently, which is why it reads as a loss rather than a correction.
- **No revert option.** MyFitnessPal stated the redesign is permanent with "no option to revert" and positioned it as "the path forward."
- **No AI coach in the hero slot.** Notable: alone among the six, MyFitnessPal kept AI (its "AI Nutrition Coach" per the App Store listing) *out* of the top of the home screen. Smart — it means the app is the only one in this set that did not push the user's own data below an AI paragraph.

## 6.7 Strengths — mechanism

1. **Calories *remaining* is a budget, not a receipt.** Forward-looking framing converts a report into a decision aid.
2. **Streak is on logging, not on compliance.** You cannot fail your way out of the habit loop. This is the single most transferable idea from MyFitnessPal.
3. **Every meal card has its own inline add button.** Zero-navigation logging for the app's one action.
4. **"Healthy Habits" is a jargon-free umbrella** for water, exercise, steps, weight — no health literacy required, and it groups four unrelated metrics under one plain-English idea.
5. **Macros default to percentages for free users** — percentages are far more legible to a novice than grams, and the gram view is (accidentally) correctly positioned as the expert mode.
6. **Diary, calories, macros, and habits on one tab** genuinely does reduce cross-tab hopping for the common case.

## 6.8 Weaknesses — real complaints with sources

The evidence here is the most quantified in this entire teardown.

- **Version rating collapsed from 3.24 to 1.54 stars** — a 1.7-star fall between v26.15.0 and v26.16.0, across a corpus of **991,000 reviews**, against **923,000 downloads in 30 days (US iOS)**, with a virality score of 8/10 ([mwm.ai](https://mwm.ai/articles/myfitnesspal-v26-16-0-replaces-diary-with-new-ui-sparking-rating-drop-in-april-2026)). Note the contrast with the App Store *lifetime* rating, which remains **4.7 stars across 2.3M ratings, #10 in Health & Fitness** — the lifetime average hid a version-level catastrophe. If you only look at the store badge you would conclude nothing happened.
- **"The diary has been ruined by being converted to a list of gigantic, space-consuming cards."** (PiunikaWeb)
- **"Basic tasks now take more taps."** (PiunikaWeb)
- **Feature-request volume, ranked** ([Sunbeam](https://blog.sunbeam.cx/myfitnesspal-redesign-classic-look-toggle/)): classic-look toggle **99 requests** — the single largest; diary view showing all meals on one screen **75**; food lookup slow or broken **64**; integration failures with Garmin, Strava, MapMyWalk, Trainerize, Fitbit, Samsung Health, Google Fit and smart scales **61**.
- Verbatims from Sunbeam: *"At least give us a customisation option to have the classic look."* / *"I'd do anything to go back to the previous version."* / *"Why take away the diary? Please put this app right back the way it was."*
- Verbatim from a paying subscriber (mwm.ai): *"The new interface creates several needless layers to slog through... I wish there was an option to go back."*
- **Churn to competitors.** PiunikaWeb documents subscribers cancelling (one an $80/year plan), organised one-star review campaigns, and users migrating to Cronometer despite the cost of abandoning years of data and streaks.
- **Ad load on free tier.** [Nutrola's 2026 review](https://nutrola.app/en/blog/myfitnesspal-review-2026): "banner ads sit at the bottom of most screens, full-screen interstitial ads appear between actions," the app "feels bloated," and "navigation can feel cluttered, load times are not always snappy."
- Sunbeam's summary of where the anger concentrates is precise and worth quoting for the pattern: negative sentiment concentrates on **diary navigation, home screen redesign, and meal-tracking flow layout** — while **core calorie and macro tracking retained positive sentiment**. The redesign broke the navigation, not the product.

## 6.9 What I would change

1. **Put the food items back on the home screen.** The single change that generated 75 explicit requests and most of the 1.7-star drop was collapsing meals into cards. Show the last 2-3 items inside each meal card with a "+N more" — same card, no extra tap for the common case.
2. **Restore copy-item.** Deleting a workflow that a daily-active user performs daily is never worth the code cleanup.
3. **Ship the classic toggle for one release cycle** and instrument it. 99 requests is a free A/B test the users are begging to run for you. Then kill whichever loses. "No option to revert" as a stated position converted a design argument into a loyalty crisis.
4. **Keep the streak on the logging behaviour. Never move it to compliance.** The temptation to make the streak about hitting the calorie target would destroy the one humane mechanic in the app.
5. **Move exercise-calorie credit back into view, but reframed.** "+210 est. from exercise (rough)" is honest and restores a headline number people liked, without pretending to precision.

## 6.10 Numbers

- v26.15.0 → v26.16.0 rating: **3.24 → 1.54** (−1.70), 991,000 reviews, 923,000 US iOS downloads in 30 days, virality 8/10 (mwm.ai).
- Lifetime App Store: **4.7 stars, 2.3M ratings, #10 Health & Fitness** (App Store listing, fetched 2026-07-29).
- Feature-request counts: 99 / 75 / 64 / 61 (Sunbeam).
- Latest release at time of research: v26.30.0, described as routine maintenance — i.e. **nine versions later, no reversion shipped.**

---

# 7. Cross-app synthesis

## 7.1 The hero slot: what each app put in the top 30% of the screen

| App | Hero element | Type | Requires hardware? | Requires literacy? |
|---|---|---|---|---|
| Apple Health | Activity rings, else first Favorite (alphabetical) | Raw number grid | Rings: yes | Yes — no benchmark given |
| Apple Fitness | 3 concentric rings | Pre-attentive composite | Yes (Watch) | **No** |
| Google Health | Customisable focus metrics (bars + rings) | Raw numbers, user-chosen | Partly | Some |
| Google Fit (dead) | 2 rings, Heart Points + Move Minutes | Pre-attentive composite | No | Yes — invented vocabulary |
| Samsung Health | Energy Score (AI readiness number) | Composite score | **Yes** (Watch/Ring) | No |
| MyFitnessPal | Streak, then calories remaining | Budget + retention hook | No | **No** |

The two screens that require no health literacy to read in one second are Apple Fitness's rings and MyFitnessPal's calories-remaining. Both encode a *goal state* rather than a *measurement*. That is the pattern.

## 7.2 The five mechanisms worth stealing

1. **A pre-attentive composite** (Apple's rings, Fit's two rings). A shape that communicates multi-dimensional progress before any text is read. Nothing else on any of these six screens works in under one second.
2. **Delta over absolute** (Apple Health's Highlights). "30% more stairs than last week" is interpretable by a person who cannot interpret "47 flights."
3. **Externally-anchored goals** (Apple's WHO-derived 30 exercise minutes; Fit's AHA-derived Heart Points). Borrowed authority makes a target defensible without a medical claim.
4. **Streak on the record-keeping, not on the outcome** (MyFitnessPal). You can have a terrible day and keep the streak. Every compliance-based streak eventually teaches the user to stop opening the app on bad days — which are precisely the days the app has the most value to add.
5. **Progressive unlock as literacy scaffolding** (Apple Fitness's Trends, locked until enough history exists). Day-one screen is simple; day-200 screen is rich; same app. This also prevents the trust-destroying move of computing a trend from four days of noise.

## 7.3 The five mistakes all of them made, repeatedly

1. **Putting AI narration above the user's own numbers.** Fitbit/Google Health did it and got 3,419 revert votes and a Kotaku quote about the biggest button. Samsung did a softer version. The user came for a number; the paragraph is a tax on getting to it.
2. **Treating a hierarchy complaint as a customisation problem.** Google's 39-item roadmap answered "the layout is wrong" with "we'll make it easier to rearrange metrics." Customisation is what you ship when you cannot decide, and most users never touch it.
3. **Removing the playful/emotional layer in the name of seriousness.** Fitbit deleted badges, sleep animals, groups, community, and its 250-step nudges in one release. What remained was a metrics dashboard, which is the one category where Apple already wins.
4. **Adding taps to the app's single most frequent action.** MyFitnessPal buried the diary behind "View All" and lost 1.7 stars on the version.
5. **Gating the hero element behind hardware with no graceful degradation.** Samsung's Energy Score is empty for most of a 65M-MAU install base.

## 7.4 How they handle "no data yet"

Honestly: **badly, all of them, and it is the biggest open opportunity in the category.**

- **Apple Health** shows Favorites with the most recent value regardless of age — "whether it's a month old, a week old, or was just added." Clever hedge, but with zero data the screen is a sparse grid.
- **Apple Fitness** shows three empty rings, which is the best empty state in the set — an empty ring is self-explanatory and is itself the instruction.
- **Google Health** ships a reduced 2-tab experience (Today + Health) for users with no device — a real structural accommodation — but the blank-Today-tab bug in May 2026 showed how thin the fallback rendering was.
- **Samsung Health** shows widgets for hardware you do not own, by default, which is the inverse of a good empty state.
- **MyFitnessPal** has the strongest position by construction: the empty state *is* the call to action, because the whole screen is a budget waiting to be spent.

The generalisable rule from this set: **an empty goal-shape is a better empty state than an absent number.** An unfilled ring says "fill me." A blank tile says "this app is broken."

## 7.5 How they avoid jargon

- Samsung's **five pillars** (Activity, Sleep, Nutrition, Mindfulness, Vitals) is the best plain-English taxonomy in the set.
- MyFitnessPal's **"Healthy Habits"** groups water/exercise/steps/weight under one non-technical umbrella.
- Google Health **renamed "Cardio fitness score" to "VO2 max"** — the wrong direction, toward jargon — but simultaneously **replaced the numeric stress score with descriptive categories ("Resilience")**, which is the right direction. Same release, both directions.
- Apple's rings avoid jargon by avoiding words: Move / Exercise / Stand are three verbs a child understands.
- Google Fit's **Heart Points and Move Minutes** were plain English for concepts nobody had, which is the subtler jargon trap — familiar words, unfamiliar referent.

## 7.6 Category retention context

Two sources disagree and both should be held loosely:

- [productgrowth.in](https://productgrowth.in/insights/healthtech/health-app-retention-guide/): D30 average **15-25%**, top quartile **40%+**; D90 **6-10%** generally; **pure tracking apps below 10% at D90**; apps with an accountability partner show **2-3x higher D90**; habit formation takes **8-10 weeks**; maximum **2 notifications/day**.
- A separate search-surfaced source (darly.solutions) claims 30-day medical app retention of **3.5-4%** vs 8-11% in other industries, with **>90% churn in month one**. `[UNVERIFIED — conflicts with the above; different app definitions almost certainly explain the gap.]`

The one number both agree on directionally: **a pure tracking app has the worst retention profile in the category.** Which is exactly why every vendor in this teardown spent 2025-2026 trying to bolt a coach onto a tracker — and why they all did it by putting the coach on top of the data instead of underneath it.

---

# 8. Sources

Fetched directly:
- https://9to5mac.com/2026/01/11/apple-health-new-features-and-overhaul-coming-ios-26-4/
- https://discussions.apple.com/thread/255591685
- https://www.macstories.net/stories/health-in-ios-13-a-foundation-for-apples-grand-wellness-ambitions/
- https://www.macrumors.com/guide/health/
- https://www.howtogeek.com/669637/how-to-customize-the-summary-tab-in-the-iphones-health-app/
- https://apps.apple.com/us/app/apple-fitness/id1208224953
- https://www.apple.com/newsroom/2025/04/get-active-with-apple-watch/
- https://trophy.so/blog/the-psychology-of-apple-watchs-close-your-rings
- https://www.macworld.com/article/3183369/ring-toss-why-the-apple-watch-activity-goals-need-an-update.html
- https://www.heather-grace.com/blog/how-my-apple-watch-impacted-my-mental-health-and-how-i-fixed-it
- https://www.engadget.com/ai/a-closer-look-at-googles-ai-health-coach-and-the-redesigned-fitbit-app-160041881.html
- https://support.google.com/googlehealth/answer/16959617?hl=en_sg
- https://support.google.com/fitbit/answer/17068213?hl=en
- https://piunikaweb.com/2026/05/25/google-health-app-fitbit-backlash-missing-features-ui-changes/
- https://piunikaweb.com/2026/05/05/fitbit-app-update-blank-today-tab/
- https://9to5google.com/2026/05/27/google-health-roadmap-fitbit-backlash/
- https://9to5google.com/2026/05/10/google-health-kills-the-fitbit-we-knew-but-maybe-thats-not-a-bad-thing/
- https://kotaku.com/google-fitbit-app-health-new-update-ai-filled-version-and-everybody-is-mad-2000699806
- https://www.androidpolice.com/upcoming-changes-to-the-fitbit-app/
- https://9to5google.com/2018/08/22/hands-on-google-fit-redesign/
- https://www.androidauthority.com/samsung-health-app-2026-update-hands-on-3679261/
- https://www.samsung.com/us/apps/samsung-health/
- https://www.sammobile.com/news/theres-an-all-new-samsung-health-and-heres-whats-changed/
- https://mwm.ai/articles/myfitnesspal-v26-16-0-replaces-diary-with-new-ui-sparking-rating-drop-in-april-2026
- https://blog.sunbeam.cx/myfitnesspal-redesign-classic-look-toggle/
- https://piunikaweb.com/2026/04/24/myfitnesspal-new-update-complaints/
- https://apps.apple.com/us/app/myfitnesspal-calorie-counter/id341232718
- https://nutrola.app/en/blog/myfitnesspal-review-2026
- https://productgrowth.in/insights/healthtech/health-app-retention-guide/

Fetched and returned truncated / blocked (content recovered only via search summaries — treat as weaker):
- https://support.apple.com/en-us/104997 (truncated)
- https://support.apple.com/en-ie/HT203037 (truncated)
- https://support.apple.com/guide/iphone/see-your-activity-summary-iph4c34a8a95/ios (truncated)
- https://discussions.apple.com/thread/250678522 (HTTP 429)
- https://support.myfitnesspal.com/hc/en-us/articles/39985611667341-Introducing-the-brand-new-Today-tab (HTTP 403)
- https://blog.myfitnesspal.com/myfitnesspal-today-screen-progress-tab-update/ (HTTP 403)
- https://www.sammyfans.com/2026/06/17/samsung-health-one-ui-9-redesign-is-finally-rolling-out/ (HTTP 403)
- https://www.androidcentral.com/phones/samsung-galaxy/samsung-health-app-is-all-new-features-take-the-guesswork-your-wellbeing (truncated)
- https://dataconomy.com/2026/01/12/ios-26-4-apple-health-gets-a-major-redesign/ (HTTP 403)
- https://news.samsung.com/us/samsung-introduces-next-gen-galaxy-watch-features-ai-powered-everyday-health-companion (timeout)
- https://play.google.com/store/apps/details?id=com.myfitnesspal.android (truncated)

Surfaced via search only, not individually fetched:
- https://techcrunch.com/2025/10/27/fitbits-revamped-app-with-gemini-powered-health-coach-rolls-out-to-premium-users/
- https://9to5google.com/2026/05/07/google-fit-shut-down-health-replacement-migration-tool-coming/
- https://forums.macrumors.com/threads/health-app-redesign.2198289/
- https://afb.org/blog/entry/ios-26-mainstream-features
- https://www.digitaltrends.com/mobile/how-to-customize-the-apple-fitness-app-in-ios-18/
- https://www.wareable.com/sport/how-to-use-google-fit-get-set-with-the-android-fitness-platform
- https://r2.community.samsung.com/t5/Samsung-Health/Samsung-Health-Update-New-UI-Ruined-the-Premium-AMOLED-Dark-Mode/m-p/22473940
- https://nikolaroza.com/samsung-health-statistics-facts-trends-data/ (low quality)
- https://www.smashingmagazine.com/2026/02/designing-streak-system-ux-psychology/
- https://uxmag.medium.com/the-psychology-of-hot-streak-game-design-how-to-keep-players-coming-back-every-day-without-shame-3dde153f239c
- https://www.darly.solutions/blog/the-impact-of-healthcare-app-user-retention-how-to-reduce-churn-and-keep-users-engaged

## Research limitations

- Web-search budget (200 calls) was exhausted before I could confirm whether the reported iOS 26.4 Apple Health redesign actually shipped and what its final layout is. Everything about Apple Health's layout here describes the pre-26.4 Summary tab.
- Several publisher sites (SammyFans, Dataconomy, MyFitnessPal's own help centre and blog, Android Central) returned 403 to automated fetch. Where their content appears above, it came from search-engine summaries, which is a weaker chain of custody — those points are flagged inline.
- I could not view actual app screenshots. All ASCII layouts are reconstructions from textual descriptions in the sources cited directly above each sketch, not from pixel inspection. Ordering within a section (e.g. the exact widget order in Samsung Health's grid) should be treated as indicative.
- The ring-closure rate ("fewer than 40%") and the "83% say it improved their health" figure both come from low-quality SEO aggregators and should not be repeated.

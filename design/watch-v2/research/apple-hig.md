# Apple HIG — watchOS Constraints

# Apple watchOS Design Guidance — Verified Reference (current as of watchOS 26.6, July 2026)

**Method note:** Apple's HIG and developer docs are JavaScript SPAs; plain HTML fetches return empty. All Apple content below was pulled from the live backing JSON endpoints (`developer.apple.com/tutorials/data/design/human-interface-guidelines/<page>.json` and `.../tutorials/data/documentation/<path>.json`), which serve the identical published content. Canonical human URLs are cited.

**Version reality check:** There is no "watchOS 12". Apple renamed to year-based versioning in 2025. Current shipping release is **watchOS 26.6**, released 27 July 2026 [source: https://www.macrumors.com/2026/07/27/apple-releases-watchos-26-6-with-security-updates/] [source: https://9to5mac.com/2026/07/27/watchos-26-6-available-now-for-apple-watch-heres-whats-new/]. **Caution:** Apple's own WidgetKit sample code annotates the new relevance API as `@available(watchOS 12, *)`, but the API's declared platform availability is `watchOS 26.0`. Apple's doc snippet is wrong; trust the availability metadata [source: https://developer.apple.com/documentation/widgetkit/widget-suggestions-in-smart-stacks] [source: https://developer.apple.com/documentation/widgetkit/relevanceconfiguration].

---

## 1. Screen dimensions and safe areas

Apple publishes screen dimensions **in pixels only**, in HIG › Layout › Specifications › "watchOS device screen dimensions" [source: https://developer.apple.com/design/human-interface-guidelines/layout].

| Series | Case | Width (px) | Height (px) | Points @2x (derived) |
|---|---|---|---|---|
| Ultra (3rd gen) | 49mm | 422 | 514 | 211 × 257 |
| 10, 11 | 42mm | 374 | 446 | 187 × 223 |
| 10, 11 | 46mm | 416 | 496 | 208 × 248 |
| Ultra (1st & 2nd gen) | 49mm | 410 | 502 | 205 × 251 |
| 7, 8, 9 | 41mm | 352 | 430 | 176 × 215 |
| 7, 8, 9 | 45mm | 396 | 484 | 198 × 242 |
| 4, 5, 6, SE (all gens) | 40mm | 324 | 394 | 162 × 197 |
| 4, 5, 6, SE (all gens) | 44mm | 368 | 448 | 184 × 224 |
| 1, 2, 3 | 38mm | 272 | 340 | 136 × 170 |
| 1, 2, 3 | 42mm | 312 | 390 | 156 × 195 |

The point column is my arithmetic (px ÷ 2). watchOS is @2x — corroborated inside Apple's own complication tables, which state every value twice, e.g. "42x42 pt (84x84 px @2x)" [source: https://developer.apple.com/design/human-interface-guidelines/complications]. **44mm and 40mm are not the same device families as 42mm/46mm** — the old Series 1–3 42mm (312×390) and the Series 10/11 42mm (374×446) share a name and nothing else.

**Safe areas: Apple publishes NO numeric safe-area inset table for watchOS.** Verified by full-text search of the Layout page: it gives numeric safe-area insets for tvOS ("inset primary content 60 points from the top and bottom, and 80 points from the sides") and gives none for watchOS. Instead the watchOS guidance is qualitative:

> "Design your content to extend from one edge of the screen to the other. The Apple Watch bezel provides a natural visual padding around your content. To avoid wasting valuable space, consider minimizing the padding between elements."

Apple directs designers to the downloadable templates for actual guides: "For templates that include the guides and safe areas for each platform, see developer.apple.com/design/resources" [source: https://developer.apple.com/design/human-interface-guidelines/layout] [source: https://developer.apple.com/design/resources/]. Anyone quoting numeric watchOS safe-area insets is quoting a template measurement or a third party, not published guidance.

Other watchOS layout rules from the same page:
- "Avoid placing more than two or three controls side by side… display no more than three buttons that contain glyphs — or two buttons that contain text — in a row."
- "Although it's usually better to let text buttons span the full width of the screen, two side-by-side buttons with short text labels can also work well, as long as the screen doesn't scroll."
- Autorotation is opt-in for "views people might want to show others" (QR codes, images), via `WKExtension.isAutorotating`.

---

## 2. Smart Stack widget rules

**Sizes (points), HIG › Widgets › Specifications › watchOS dimensions** [source: https://developer.apple.com/design/human-interface-guidelines/widgets]:

| Apple Watch size | Smart Stack widget (pt) |
|---|---|
| 40mm | 152 × 69.5 |
| 41mm | 165 × 72.5 |
| 44mm | 173 × 76.5 |
| 45mm | 184 × 80.5 |
| 49mm | 191 × 81.5 |

**Gap:** the table has no rows for 42mm or 46mm (Series 10/11). This table was last corrected 17 January 2025 per the page's own change log; the Series 10 sizes were never added. Treat 46mm as ≈45mm and 42mm as ≈41mm and verify on device.

**Families supported in the Smart Stack:** only `accessoryRectangular` and `accessoryCircular` [source: https://developer.apple.com/design/human-interface-guidelines/widgets]. Apple's table:

| Widget size | Apple Watch |
|---|---|
| Accessory circular | Watch complications **and in the Smart Stack** |
| Accessory corner | Watch complications only |
| Accessory inline | Watch complications only |
| Accessory rectangular | Watch complications **and in the Smart Stack** |

Rendering modes on Apple Watch: **full-color and accented only. Vibrant is "Not supported"** on watchOS. In accented mode on Apple Watch specifically, "the system tints primary content white and accented content in the color of the watch face" [source: https://developer.apple.com/design/human-interface-guidelines/widgets].

**watchOS-specific design guidance (verbatim, HIG › Widgets › Platform considerations › watchOS):**
> "Provide a colorful background that conveys meaning. By default, widgets in the Smart Stack use a black background… the Stocks app uses a red background for falling stock values and a green background if a stock's value rises."
> "Encourage the system to display or elevate the position of your watchOS widget in the Smart Stack. Relevancy information helps the system show your widget when people need it most. Relevance can be location-based or specific to ongoing system actions, like a workout."

**Ranking / relevance APIs — watchOS diverges completely from iOS.** Apple's own platform matrix [source: https://developer.apple.com/documentation/widgetkit/widget-suggestions-in-smart-stacks]:

| App-provided clue | iOS | iPadOS | watchOS |
|---|---|---|---|
| `TimelineEntry.relevance` score + duration | Yes | Yes | **No** |
| Donate `PredictableIntent` app intents | Yes | Yes | **No** |
| Implement `TimelineProvider.relevance()` | **No** | **No** | **Yes** |
| `RelevantIntent` + `RelevantIntentManager` | No | No | **Yes** |
| `RelevanceConfiguration` + `RelevanceEntriesProvider` | No | No | **Yes (watchOS 26+)** |

Explicit note: "Smart Stacks on iPhone and iPad don't consider relevance information you provide with your timeline provider's `relevance()` callback… `RelevanceConfiguration` API is available in watchOS only." **A relevance score on a timeline entry does nothing on Apple Watch.**

Two watchOS paths:
- **Timeline provider path** — `relevance()` returns `WidgetRelevance`, built from `WidgetRelevanceAttribute(configuration:context:)`. Widget appears **once**; user can add and pin it.
- **`RelevanceConfiguration` path (watchOS 26+)** — widget can appear in the Smart Stack **multiple times simultaneously**, one instance per matching relevance clue. Trade-off, stated explicitly: "people can't configure widgets that use a `RelevanceConfiguration` to appear in the Smart Stack, add them to the Smart Stack, or pin them to a fixed location." Use `.associatedKind(_:)` so a relevance-based widget can replace a pinned timeline-based one when space runs out [source: https://developer.apple.com/documentation/widgetkit/widget-suggestions-in-smart-stacks].

**`RelevantContext` clue types (RelevanceKit, watchOS-only; API calls no-op on other platforms)** [source: https://developer.apple.com/documentation/relevancekit] [source: https://developer.apple.com/documentation/relevancekit/relevantcontext]:
- **Fitness:** `fitness(_:)` / `FitnessCondition`
- **Hardware:** `hardware(headphones:)`
- **Location:** `location(_:)`, `location(inferred:)` (home / work / school / commute), `location(category:)` (points of interest)
- **Sleep:** `sleep(_:)` (bedtime, wakeup)
- **Time:** `date(_:)`, `date(_:kind:)`, `date(interval:kind:)`, `date(range:kind:)`, `date(from:to:)`

**Permissions gate the clues:** "make sure your app and your widget extension request a person's permission to access location, workout, or sleep schedule information. For example, you need to request the `HKCategoryTypeIdentifier.sleepAnalysis` permission to provide a clue based on a person's sleep schedule."

**System-side behaviour (Apple Support, user-facing):** Smart Stack opens by turning the Digital Crown upward, swiping up from the watch face, or double tap. Live Activities appear at the top. "Apple Watch gently taps your wrist with a hint when the Smart Stack has a suggestion that's immediately useful for you." Swipe down on a hint to mute it for 24 hours [source: https://support.apple.com/guide/watch/see-widgets-in-the-smart-stack-apdecf142fb9/watchos]. Apple describes hints as "a proactive prompt for actionable suggestions that are immediately useful," generated from "more contextual data, sensor data, and data from a user's routine" [source: https://www.apple.com/newsroom/2025/06/watchos-26-delivers-more-personalized-ways-to-stay-active-and-connected/].

**Testing:** rotation-to-top and suggestion insertion are rate-limited in production. "To bypass this limit during development, enable the WidgetKit Developer Mode switch in Settings > Developer."

**"How many lines fit" — Apple states no line count.** Derived: at 45mm the widget is 80.5 pt tall; xLarge default `Body` on watchOS is 17 pt with 19.5 pt leading, so the hard ceiling is ~4 text lines before margins, realistically **1 title + 2–3 body lines**. That arithmetic is mine, not Apple's — the only related Apple rule is generic: "In general, display text using fonts at 11 points or larger" and "Balance information density. Sparse layouts can make the widget seem unnecessary, while overly dense layouts are less glanceable."

---

## 3. Complication families, content fit, and refresh budgets

Apple's watchOS 9+ families are **Circular, Corner, Inline, Rectangular**, plus legacy templates (circular small, modular small, modular large, extra large) for pre-watchOS 9 [source: https://developer.apple.com/design/human-interface-guidelines/complications]. WidgetKit is the required path: "Prefer using WidgetKit to develop complications for watchOS 9 and later." Hard consequence: "**As soon as you offer a widget-based complication, the system stops calling ClockKit APIs**" [source: https://developer.apple.com/documentation/widgetkit/creating-accessory-widgets-and-watch-complications].

**Sizes (45mm/49mm column, points; the system circular-masks every image except where noted):**

| Family | Content | 41mm | 45mm/49mm |
|---|---|---|---|
| Circular | Image | 44.5 × 44.5 | 50 × 50 |
| Circular | Closed gauge | 28.5 × 28.5 | 32 × 32 |
| Circular | Open gauge | 11.5 × 11.5 | 13 × 13 |
| Circular (X-Large face) | Image | 127 × 127 | 143 × 143 |
| Corner | Circular image | 34 × 34 | 38 × 38 |
| Corner | Gauge / text image | 21 × 21 | 24 × 24 |
| Inline (utilitarian small) | Ring | 15 × 15 | 16.5 × 16.5 |
| Inline (utilitarian small) | Square | 23.5 × 23.5 | 26 × 26 |
| Rectangular | Large image **with** title | 159 × 50 | 178.5 × 56 |
| Rectangular | Large image **without** title | 171.5 × 73 | 193 × 82 |
| Rectangular | Standard body / text gauge glyph | 12.5 × 12.5 | 14.5 × 14.5 |

Default SwiftUI text, all families: **SF Compact Rounded** [source: https://developer.apple.com/design/human-interface-guidelines/typography].

| Family | Default weight | Text size 41mm | Text size 45mm/49mm |
|---|---|---|---|
| Circular | Medium | 12.5 pt | 14.5 pt |
| Circular X-Large | Medium | 36.5 pt | 41 pt |
| Corner | Semibold | 10.5 pt | 12 pt |
| Rectangular | Medium | 17.5 pt | 19.5 pt |

**What each realistically fits (Apple's own descriptions):**
- **accessoryCircular** — "text, gauges, and full-color images in circular areas." Optional curved bezel text on faces like Infograph: "The text can fill nearly 180 degrees of the bezel before truncating."
- **accessoryCorner** — "full-color images, text, and gauges in the corners of the watch face." Smallest text (10.5–12 pt). Symbol + 2–4 characters.
- **accessoryInline** — API definition: "A flat widget that contains a single row of text and an optional image." "On some watch faces, the system renders the complication along a curve." **One tap target only** ("inline accessory widgets offer only one tap target") [source: https://developer.apple.com/documentation/widgetkit/widgetfamily/accessoryinline].
- **accessoryRectangular** — "works well for showing details about a value or process that changes over time, because it provides room for information-rich charts, graphs, and diagrams." Apple's cited exemplar is directly relevant to a recovery app: "the Heart Rate complication displays a graph of heart-rate values within a 24-hour period. The graph uses high-contrast white and red for the primary content and a lower-contrast gray for the graph lines and labels."

**Visual rules:** "generally use line widths of two points or greater. Thinner lines can be difficult to see at a glance, especially when the wearer is in motion." Gauge styles: **closed** = percentage of a whole; **open** = arbitrary min/max; **segmented** = rapid value changes (the Noise complication). Tinted mode: "Avoid using color as the only way to communicate important information… provide an alternative tinted-mode version of a full-color image" if the desaturated version looks bad.

**Refresh budgets — four separate, independently enforced budgets:**

1. **WidgetKit timeline reloads (all platforms):** "A widget's budget applies to a 24-hour period… For a widget the user frequently views, a daily budget typically includes **from 40 to 70 refreshes**. This rate roughly translates to widget reloads every **15 to 60 minutes**." Per-instance: two configurations of the same widget each get their own budget. **Minimum entry spacing: "Your timeline provider should create timeline entries that are at least about 5 minutes apart."** Reloads that do **not** count against budget: containing app in foreground; active audio or navigation session; widget performs an app intent; widget performs an animation; system locale change; Dynamic Type / Accessibility settings change [source: https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date].
2. **watchOS background app refresh tasks:** "the system performs **approximately four tasks per hour** for each app with a complication on the active watch face. **All the complications on the current watch face share this budget**" [source: https://developer.apple.com/documentation/watchkit/wkapplicationrefreshbackgroundtask].
3. **Snapshots:** "For apps in the dock, you can safely request **one snapshot per hour**. For apps with an active complication, you can request **up to four per hour**" [source: https://developer.apple.com/documentation/watchkit/preparing-to-take-your-watchos-app-s-snapshot].
4. **Bluetooth background scan / timely alert:** "The system limits your app to **five background-scan or timely alert opportunities in a rolling 24-hour window**. The opportunities become available 24 hours after their use, and the entire budget refreshes when the user launches your app" [source: https://developer.apple.com/documentation/watchkit/using-background-tasks].

Apple's own warning on complication data design: "You can update the timeline a limited number of times each day, and the system stores a limited number of timeline entries for each app, so you need to choose times that enhance the usefulness of your data."

---

## 4. Haptics

**`WKHapticType` — full API case list (14 cases)** [source: https://developer.apple.com/documentation/watchkit/wkhaptictype]:

`notification`, `directionUp`, `directionDown`, `success`, `failure`, `retry`, `start`, `stop`, `click`, `navigationGenericManeuver`, `navigationLeftTurn`, `navigationRightTurn`, `underwaterDepthCriticalPrompt`, `underwaterDepthPrompt`.

**HIG documents meanings for only 9 of them** (HIG › Playing haptics › Platform considerations › watchOS, verbatim) [source: https://developer.apple.com/design/human-interface-guidelines/playing-haptics]:

| Haptic | Apple's stated meaning |
|---|---|
| **Notification** | "Tells the person that something significant or out of the ordinary has happened and requires their attention. The system plays this same haptic when a local or remote notification arrives." |
| **Up** | "Tells the person that an important value increased above a significant threshold." |
| **Down** | "Tells the person that an important value decreased below a significant threshold." |
| **Success** | "Tells the person that an action completed successfully." |
| **Failure** | "Tells the person that an action failed." |
| **Retry** | "Tells the person that an action failed but they can retry it." |
| **Start** | "Tells the person that an activity started. Use this haptic when starting a timer or any other activity that a person can explicitly start and stop. The stop haptic usually follows this haptic." |
| **Stop** | "Tells the person that an activity stopped. Use this haptic when stopping a timer or other activity that the person previously started." |
| **Click** | "Provides the sensation of a dial clicking, helping you communicate progress at predefined increments or intervals. Overusing the click haptic tends to diminish its utility and can even be confusing when clicks overlap each other." |

The three navigation cases and two underwater-depth cases carry API abstracts only ("Indicates a new navigation step", "Indicates that the user should turn left/right"); the underwater cases have **no published abstract at all** — unverified as to intended semantics beyond the name. No HIG guidance covers any of the five.

**Hard runtime constraints on `WKInterfaceDevice.play(_:)`** [source: https://developer.apple.com/documentation/watchkit/wkinterfacedevice/play(_:)]:
- "This method has no effect when called while… `applicationState` is either `background` or `inactive`. **By default, you cannot play haptic feedback in the background. The only exception are apps with an active workout session.**"
- "Do not call this method multiple times in quick succession… the system stops the current feedback and imposes a **minimum delay of 100 milliseconds** before engaging the engine."
- **Critical for a health app:** "**Do not call this method while gathering heart rate data using HealthKit. When you engage the haptic engine, HealthKit stops gathering heart rate data until after the haptic engine finishes.**"

Cross-cutting HIG rules: "Use system-provided haptic patterns according to their documented meanings… If the documented use case for a pattern doesn't make sense in your app, avoid using the pattern to mean something else." "Avoid overusing haptics." "Make haptics optional." "In most apps, prefer playing short haptics that complement discrete events." watchOS "combines" the Taptic Engine pattern "with an audible tone."

---

## 5. Always-On Display rules

**What the system does** [source: https://developer.apple.com/documentation/watchos-apps/designing-your-app-for-the-always-on-state] [source: https://developer.apple.com/design/human-interface-guidelines/always-on]:
- Since watchOS 8, Apple Watch "continues to display your app's user interface as long as it's either the frontmost app or running a background session." The system dims the display and lowers UI update frequency.
- Enabled by default for apps compiled for watchOS 8+. Opt out via `WKSupportsAlwaysOnDisplay = false` (this restores the older blur-the-screen behaviour). Users can disable globally or **per-app** in Settings › Display & Brightness › Always On.
- **Not available on Apple Watch SE or Series 4 and earlier** — on those, the screen turns off entirely when the app goes background/inactive.
- "The system determines the screen's overall luminance by comparing the ratio of lit pixels to dark pixels. It then reduces the overall brightness to an appropriate level."

**What keeps updating without you doing anything:** `Text` with `DateStyle.relative`, `.offset`, `.timer` update automatically. "**Any controls in the user interface remain interactive.** Users can tap buttons, toggle switches, or select items from a list" — and doing so returns the app to active.

**What an app must do:**
- **Redact.** "It's crucial to redact personal information that people wouldn't want casual observers to view, like bank balances or **health data**." Use `.privacySensitive()` or check `redactionReasons.contains(.privacy)`. "**To protect the user's privacy, always hide any highly sensitive information, such as financial information or health data.** For information that may or may not be sensitive… default to showing the information."
- **Dim, don't delete.** Read `@Environment(\.isLuminanceReduced)`. Apple's prescribed pattern: "replacing large blocks of bright content with stroked outlines and dimmed interiors, as shown on the Numerals Duo watch face" — literally `Circle().fill(.white)` → `Circle().stroke(.gray, lineWidth: 10)` [source: https://developer.apple.com/documentation/swiftui/environmentvalues/isluminancereduced].
- **Keep layout stable.** "Avoid making distracting interface changes when Always On begins or ends… prefer transitioning an interactive component to an unavailable appearance — don't just remove it."
- **Kill sub-second motion.** "Gracefully transition motion to a resting state; don't stop it instantly." Apple's canonical example: the Workout app shows hundredths of a second and an animated heartbeat in foreground; in Always On it shows "a static heart image and the duration only shows time to the nearest second."
- **Match the cadence.** `TimelineView` exposes `context.cadence` = `.live` (up to 60 updates/sec), `.seconds`, `.minutes`. Branch on it, or on `scenePhase`.
- Contrast note from the widgets page: "Use levels of gray that provide enough contrast in the Always-On display, and make sure your content remains legible."

**Testing:** Xcode previews don't auto-dim — "you must test it on a device or in the simulator." Simulator has a "Toggle Always On" button in the status bar. Preview both states with `.environment(\.isLuminanceReduced, true).environment(\.redactionReasons, [.privacy])`.

---

## 6. Notification design on watchOS

Two stages, plus Notification Center [source: https://developer.apple.com/design/human-interface-guidelines/notifications]:

**Short look** — "appears when the wearer's wrist is raised and disappears when it's lowered."
- "Avoid using a short look as the only way to communicate important information. A short look appears only briefly, giving people just enough time to see what the notification is about and which app sent it."
- "Short looks are intended to be discreet, so it's important to provide only basic information. **Avoid including potentially sensitive information in the notification's title.**"

**Long look** — scrollable via swipe or Digital Crown; dismissed by tapping or lowering the wrist.
- Static vs dynamic interface. "**At the minimum, provide a static interface; prefer providing a dynamic interface too.** The system defaults to the static interface when the dynamic interface is unavailable, such as when there is no network or the iPhone companion app is unreachable. Be sure to create the resources for your static interface in advance and package them with your app."
- **Structure is fixed and not customisable:** "You can customize the content area for both static and dynamic long looks, but **you can't change the overall structure of the interface**. The system-defined structure includes a sash at the top of the interface and a Dismiss button at the bottom, below all custom buttons."
- Sash: displays your app icon and name; you may set its colour or make it blurred (use blurred when a photo sits at the top of the content area).
- Content background: "By default, the long look's background is transparent. If you want to match the background color of other system notifications, **use white with 18% opacity**."
- SwiftUI animations, SpriteKit, or SceneKit are all permitted in a custom long look.

**Actions:** "**up to four** custom actions below the content area," plus a system Dismiss button always at the bottom. Interface icon renders on the **trailing** side of the action title. Rules: "Avoid providing an action that merely opens your app." "Prefer nondestructive actions." Short title-case labels.

**Double tap on notifications:** "When a person responds to a notification with a double tap, the system selects **the first nondestructive action** as the response… consider placing the action that people use most frequently at the top of the list."

**Wrist flick (watchOS 26):** "When a user raises their wrist to check a notification but isn't ready to respond, they can quickly turn their wrist over and back to dismiss the notification." It "uses the accelerometer and the gyroscope — along with a machine learning model — to analyze a user's wrist movement" [source: https://www.apple.com/newsroom/2025/06/watchos-26-delivers-more-personalized-ways-to-stay-active-and-connected/]. **Unverified:** I found no HIG page or API surface exposing wrist flick to third-party apps; it appears to be system-handled only.

Cross-platform rules that bite hardest on watch: "Prefer brief titles that people can read at a glance, **especially on Apple Watch, where space is limited**." "Avoid sending multiple notifications for the same thing." "Avoid including sensitive, personal, or confidential information in a notification."

---

## 7. Digital Crown patterns Apple endorses

From HIG › Digital Crown [source: https://developer.apple.com/design/human-interface-guidelines/digital-crown]:

- **Crown is the primary navigation input since watchOS 10.** "On the watch face, people turn the Digital Crown to view widgets in the Smart Stack, and on the Home Screen, people use it to move vertically through their collection of apps. Within apps, people turn the Digital Crown to switch between vertically paginated tabs, and to scroll through list views and variable height pages."
- **"Anchor your app's navigation to the Digital Crown… List, tab, and scroll views are vertically oriented… When anchoring interactions to the Digital Crown, also be sure to back them up with corresponding touch screen interactions."**
- **Presses are off-limits:** "Apps don't respond to presses on the Digital Crown because watchOS reserves these interactions for system-provided functionality like revealing the Home Screen."
- **Second endorsed pattern — data inspection:** "In contexts where the Digital Crown doesn't need to navigate through lists or between pages, it's a great tool to inspect data in your app. For example, in World Clock, turning the Digital Crown advances the time of day at a selected location."
- "**Provide visual feedback in response to Digital Crown interactions**… If you don't provide visual feedback, people are likely to assume that turning the Digital Crown has no effect in your app."
- "Update your interface to match the speed with which people turn the Digital Crown… Avoid updating content at a rate that makes it difficult for people to select values."

**Crown haptics:** "Apple Watch Series 4 and later provides haptic feedback for the Digital Crown… **By default, the system provides linear haptic detents** that people can feel as they rotate the Digital Crown. Some system controls, like table views, provide detents as new items scroll onto the screen." Guidance: "Use the default haptic feedback when it makes sense in your app. If haptic feedback doesn't feel right… turn off the detents. You can also adjust the haptic feedback behavior for tables, letting them use linear detents instead of row-based detents. For example, if your table has rows with significantly different heights, linear detents may give people a more consistent experience."

**Verified APIs:** `WKCrownDelegate` (watchOS 3+) [source: https://developer.apple.com/documentation/watchkit/wkcrowndelegate]; `View.digitalCrownRotation(_:)` (watchOS 6+) [source: https://developer.apple.com/documentation/swiftui/view/digitalcrownrotation(_:)]; `DigitalCrownRotationalSensitivity` (watchOS 6+) — "The amount of Digital Crown rotation needed to move between two integer numbers… You may need to experiment to find the level of sensitivity that works for your use case" [source: https://developer.apple.com/documentation/swiftui/digitalcrownrotationalsensitivity]; `View.digitalCrownAccessory(_:)` (watchOS 9+) [source: https://developer.apple.com/documentation/swiftui/view/digitalcrownaccessory(_:)]. **Unverified:** the longer `digitalCrownRotation` overload carrying `isHapticFeedbackEnabled:` / detent parameters — I could not resolve its exact doc URL, so I will not state its signature.

**Vertical pagination rules** [source: https://developer.apple.com/design/human-interface-guidelines/page-controls] [source: https://developer.apple.com/design/human-interface-guidelines/scroll-views] [source: https://developer.apple.com/design/human-interface-guidelines/tab-views]:
- "watchOS displays tab views as pages." `TabView` in a vertical stack + crown = full-screen page navigation; the page indicator sits next to the Digital Crown "and shows people where they are in the content, both within the current page and within a set of pages."
- "**Use vertical pagination to separate multiple views into distinct, purposeful pages**… In watchOS, this design is more effective than horizontal pagination or many levels of hierarchical navigation."
- "**Consider limiting the content of an individual page to a single screen height.** Embracing this constraint encourages each page to serve a clear and distinct purpose and results in a more glanceable design. Use variable-height pages judiciously and, if possible, only place them after fixed-height pages."
- Lists: "Constrain the length of detail views if you want to support vertical page-based navigation… **If your detail views scroll, people won't be able to use vertical page-based navigation** to swipe among them."

**Double tap (watchOS 11+)** [source: https://developer.apple.com/design/human-interface-guidelines/gestures]:
- "In watchOS 11 and later, people can use the double-tap gesture to scroll through lists and scroll views, and to advance between vertical tab views."
- "**Avoid setting a primary action in views with lists, scroll views, or vertical tabs. This conflicts with the default navigation behaviors that people expect when they double-tap.**"
- "Choose the button that people use most commonly as the primary action in a view… in a media controls view, you could assign the primary action to the play/pause button."
- API: `handGestureShortcut(_:isEnabled:)` with `HandGestureShortcut.primaryAction`, watchOS 11.0+. "Performing the control's shortcut while the control is anywhere in the frontmost scene is equivalent to direct interaction with the control to perform its primary action." "The target of a hand gesture shortcut is resolved in a leading-to-trailing traversal of the active scene" [source: https://developer.apple.com/documentation/swiftui/view/handgestureshortcut(_:isenabled:)].
- Gesture spec table lists double tap as "perform a primary action on Apple Watch Series 9 and Apple Watch Ultra 2" (table not updated for Series 10/11/Ultra 3).

---

## 8. Accessibility on watchOS

From HIG › Accessibility [source: https://developer.apple.com/design/human-interface-guidelines/accessibility] and HIG › Typography [source: https://developer.apple.com/design/human-interface-guidelines/typography]:

**Text size:** "Ideally, give people the option to enlarge text by at least 200 percent (**or 140 percent in watchOS apps**)."

| Platform | Default type size | Minimum type size |
|---|---|---|
| watchOS | **16 pt** | **12 pt** |
| iOS/iPadOS | 17 pt | 11 pt |

**Control size:**

| Platform | Default control size | Minimum control size |
|---|---|---|
| watchOS | **44 × 44 pt** | **28 × 28 pt** |

Plus: "about 12 points of padding around elements that include a bezel. For elements without a bezel, about 24 points of padding works well around the element's visible edges."

**Contrast (WCAG AA, used by Accessibility Inspector):** ≤17 pt → **4.5:1**; 18 pt → **3:1**.

**Fonts:** "SF Compact is the system font in watchOS, and apps can also use NY. **In complications, watchOS uses SF Compact Rounded.**"

**watchOS Dynamic Type — the full ramp is published.** Default size class is **Large for 40/41/42mm** and **xLarge for 44/45/49mm**:

| Style | Large (40/41/42mm) | xLarge (44/45/49mm) | AX1 | AX2 |
|---|---|---|---|---|
| Large Title | 36 / 38.5 | 40 / 42.5 | 44 / 46.5 | 45 / 47.5 |
| Title 3 | 19 / 21.5 | 20 / 22.5 | 24 / 26.5 | 25 / 27.5 |
| Headline (Semibold) | 16 / 18.5 | 17 / 19.5 | 21 / 23.5 | — |
| Body | 16 / 18.5 | 17 / 19.5 | 21 / 23.5 | — |
| Caption 1 | 15 / 17.5 | 16 / 18.5 | 18 / 20.5 | — |
| Footnote 1 | 13 / 15.5 | 14 / 16.5 | 16 / 18.5 | — |

(size pt / leading pt). Sizes below Large exist for 38mm (Small) and xSmall; xxLarge and xxxLarge sit above; AX1–AX5 are the accessibility sizes. Tracking tables for SF Compact are published per point size (e.g. 12 pt → +20/1000 em → +0.23 pt; 16 pt → 0; 24 pt → −8/1000 em → −0.19 pt).

**VoiceOver** [source: https://developer.apple.com/design/human-interface-guidelines/voiceover]: "No additional considerations for… watchOS" — the general rules apply. Directly relevant to a recovery app: "**Make charts and other infographics fully accessible.** Provide a concise description of each infographic that explains what it conveys. If people can interact with the infographic to get more or different information, make these interactions available to people using VoiceOver, too." And from the Widgets page: "**Avoid rasterizing text.** Always use text elements and styles to ensure that your text scales well and to allow VoiceOver to speak your content."

**Reduce Motion:** "When this setting is active, ensure your app or game responds by reducing automatic and repetitive animations, including zooming, scaling, and peripheral motion. Other best practices for reducing motion include: tightening animation springs to reduce bounce effects; tracking animations directly with people's gestures; avoiding animating depth changes in z-axis layers; replacing transitions in x-, y-, and z-axes with fades to avoid motion; avoiding animating into and out of blurs."

**Colour:** "Convey meaning without relying on specific colors to represent information. Widgets can appear monochromatic (with or without a custom tint color), and **in watchOS, the system may invert colors depending on the watch face a person chooses.** Use text and iconography in addition to color to express meaning" [source: https://developer.apple.com/design/human-interface-guidelines/widgets].

**Motion caveat unique to watchOS:** "All layout- and appearance-based animations automatically include built-in easing that plays at the start and end of the animation. **You can't turn off or customize easing**" [source: https://developer.apple.com/design/human-interface-guidelines/motion].

**Unverified:** Apple's "Create accessible experiences for watchOS" article is listed in the watchOS Apps table of contents but I could not resolve a working URL for it under the paths I tried; its contents are not represented here.

---

## 9. Explicit Apple statements on interaction length and what NOT to do

**The two load-bearing quotes.**

HIG › Designing for watchOS [source: https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos]:
> "People glance at the Always On display many times throughout the day, **performing concise app interactions that can last for less than a minute each**. People frequently use a watchOS app's related experiences — like complications, notifications, and Siri interactions — **more than they use the app itself**."

Developer docs › watchOS apps [source: https://developer.apple.com/documentation/watchos-apps]:
> "The watchOS experience focuses on quick actions that achieve useful tasks through brief, punctuated interactions."
> "**On Apple Watch, keep interactions as short as possible. Provide vital information at a glance, encouraging the wearer to respond with just a few taps, and then drop their wrist and move on. They don't need to wait to see if the action succeeds; instead, the watchOS app automatically notifies them of any important updates.**"
> "For watchOS, expect to spend more time planning, designing, and refining your app's experience than writing the actual code."
> "The app's interface isn't necessarily the primary way people interact with your app. Many may prefer to interact through complications or notifications, and **may never explicitly launch your app**."

**Apple's seven watchOS best practices, verbatim** (HIG › Designing for watchOS):
1. "Support quick, glanceable, single-screen interactions that deliver critical information succinctly and help people perform targeted actions with a simple gesture or two."
2. "**Minimize the depth of hierarchy in your app's navigation**, and use the Digital Crown to provide vertical navigation for scrolling or switching between screens."
3. "Personalize the experience by proactively anticipating people's needs and using on-device data to provide actionable content that's relevant in the moment or very soon."
4. "Use complications to provide relevant, potentially dynamic data and graphics right on the watch face where people can view them on every wrist raise."
5. "Use notifications to deliver timely, high-value information and let people perform important actions without opening your app."
6. "Use background content such as color to convey useful supporting information, and use materials to illustrate hierarchy and a sense of place."
7. "**Design your app to function independently**, complementing your notifications and complications by providing additional details and functionality."

**Explicit "don'ts":**
- **No indeterminate spinners.** "Avoid displaying an indeterminate progress indicator — such as a loading indicator — in a watchOS app. An animated indicator can make people think they need to continue paying attention to the display, which isn't a good user experience. **To provide a better experience, reassure people that they'll receive a notification when the process completes**" [source: https://developer.apple.com/design/human-interface-guidelines/feedback]. Nuanced by the Loading page: "As much as possible, avoid showing a loading indicator… In situations where content needs a second or two to load, it's better to display a loading indicator than a blank screen" [source: https://developer.apple.com/design/human-interface-guidelines/loading].
- **No full-screen colour in long-lived views.** "Avoid using full-screen background color in views that are likely to remain onscreen for long periods of time, such as **in a workout** or audio-playing app" [source: https://developer.apple.com/design/human-interface-guidelines/color].
- **No app-like widget layouts.** "Offer interactivity while remaining glanceable and uncluttered… **avoid creating app-like layouts in your widgets**."
- **Don't mirror your widget inside your app.** "Including an element in your app that looks like your widget but doesn't behave like it can confuse people."
- **Static complications get deleted.** "A static complication that doesn't display meaningful data may be less likely to remain in a prominent position on the watch face." Same for widgets: "If a widget's content never appears to change, people may not keep it in a prominent position."
- **Don't reuse one deep link.** "Define a different deep link for each complication you support… If all the complications you support open the same area in your app, they can seem less useful."
- **During a workout, don't offer navigation.** "Avoid distracting people from a workout with information that's not relevant. For example, people don't need to review the list of workouts you offer or access other parts of your app while they're working out" [source: https://developer.apple.com/design/human-interface-guidelines/workouts].
- **Don't keep junk sessions.** "Discard extremely brief workout sessions. If a session ends a few seconds after it starts, either discard the data automatically or ask people if they want to record the data as a workout."
- **Don't misuse Activity rings.** "The Activity rings view is an Apple-designed element… Use them only for their documented purpose."
- **Don't define gestures that collide with the system.** "Several platforms offer gestures for accessing system behaviors, like edge swiping in watchOS" [source: https://developer.apple.com/design/human-interface-guidelines/gestures].

---

## 10. What is impossible or restricted on watchOS

**The governing sentence** [source: https://developer.apple.com/documentation/watchkit/background-execution]:
> "Apps on watchOS **primarily run in the foreground** to limit the impact on system resources. However, sometimes an app needs to perform an action when it's not the foreground app. **For a limited number of cases**, watchOS provides options for running in the background."

**Frontmost lifetime.** "When the user lowers their wrist or stops interacting with their watch, your app transitions to the inactive state. The system continues to display your app's user interface as long as your app remains the frontmost app (**usually two minutes**) before transitioning to the background and becoming suspended. If the user dismisses the app (for example, by pressing the Digital Crown or by covering the screen), the app transitions **immediately** to the background and doesn't become the frontmost app." User-configurable via Settings › General › Wake Screen › Return to Clock, including per-app. "**In watchOS 8 and later, apps can remain in the frontmost app state for a maximum of 1 hour**" [source: https://developer.apple.com/documentation/watchos-apps/designing-your-app-for-the-always-on-state].

**Background execution time is "a few seconds."** Stated twice: "the system launches your app and gives it **a few seconds** of background execution time to perform the task. Complete the background task as quickly as possible" [source: https://developer.apple.com/documentation/watchkit/background-execution]. "If the available background time expires before you finish processing the task, **the system may terminate your app, triggering an `EXC_CRASH (SIGKILL)` crash**" [source: https://developer.apple.com/documentation/watchkit/using-background-tasks].

**Background tasks are not guaranteed.** "The delivery of background tasks and the allocation of background execution time are **completely up to the system**." The system will:
- "Give each app an individual allotment of background execution time. The system only triggers an app's background tasks when it has time remaining in its budget."
- "Throttle background tasks when system resources are tight. Even if individual apps have the budget for tasks, the system doesn't trigger background tasks when the device's battery is low or the system conditions are poor."
- "**Throttle background execution when the user is performing high-priority activities, such as exercising or navigating.**" ← directly hostile to a recovery app that wants to refresh during a workout.

Apple's instruction: "**When designing your app, don't expect the system to trigger every background task. Design a fallback mechanism** so your app behaves correctly even when throttling occurs."

**Only three things can hold a true background session** [source: https://developer.apple.com/documentation/watchkit/background-execution]: `HKWorkoutSession` (workouts), `AVAudioSession` (background audio), `CLLocationManager` with `allowsBackgroundLocationUpdates` (location). Each requires the matching Background Mode capability **and must be started while the app is in the foreground**.

**Extended runtime sessions — one type per app, hard caps** [source: https://developer.apple.com/documentation/watchkit/using-extended-runtime-sessions]:

| Session type | Runtime | Schedulable | **Time limit** |
|---|---|---|---|
| Self care | Frontmost | No | **10 minutes** |
| Mindfulness | Frontmost | No | **1 hour** |
| Physical therapy | Background | No | **1 hour** |
| Smart alarm | Background | Yes (up to 36 h ahead) | **30 minutes** |

- "Each app can support **a single type** of extended runtime session."
- "Select a session type based on the app's **intended use** — not based on the features that the session provides."
- Frontmost sessions end "when the user explicitly leaves your app (for example, by pressing the digital crown or switching to a different app)."
- "**To maintain high performance on Apple Watch, limit the amount of work performed during an extended runtime session. If your app sustains high CPU usage over a period of time, the system may cancel the session** (`WKExtendedRuntimeSessionErrorCode.exceededResourceLimits`)."
- Smart alarm: "your app **must** trigger the alarm by calling `notifyUser(hapticType:repeatHandler:)`… **If you fail to play a haptic during the session, the system displays a warning and offers to disable future sessions.**"

**Other hard restrictions a designer must plan around:**

| Restriction | Statement | Source |
|---|---|---|
| No background haptics | "By default, you cannot play haptic feedback in the background. The only exception are apps with an active workout session." | `WKInterfaceDevice.play(_:)` |
| Haptics kill HR sampling | "When you engage the haptic engine, HealthKit stops gathering heart rate data until after the haptic engine finishes." | `WKInterfaceDevice.play(_:)` |
| Crown press is reserved | "Apps don't respond to presses on the Digital Crown." | HIG › Digital Crown |
| No real-time widgets | "Widgets don't support continuous, real-time updates." Live Activities are the alternative. | HIG › Widgets |
| ClockKit dies on migration | "As soon as you offer a widget-based complication, the system stops calling ClockKit APIs." | Creating accessory widgets |
| No Controls on watchOS | Control Center / Lock Screen / Action button **controls** are "Not supported in watchOS, tvOS, or visionOS." | HIG › Controls |
| BT background budget | 5 background-scan or timely-alert opportunities per rolling 24 h. | Using background tasks |
| Widget extension is not resident | "Your widget extension is not continually active, even if the widget is onscreen." | Keeping a widget up to date |
| Always On unavailable on older hardware | "Always On isn't available on Apple Watch SE or Apple Watch Series 4 and earlier." | Designing for the Always On state |
| Animation easing not overridable | "You can't turn off or customize easing." | HIG › Motion |
| Dock snapshot is your launch image | "When you launch an app, watchOS initially displays the latest snapshot" — a stale snapshot is what the user sees first. | Preparing to take your snapshot |

Networking: watchOS splits into "Making default and ephemeral requests" (foreground) and "Making background requests" (background `URLSession`), with background transfers waking the app via `WKURLSessionRefreshBackgroundTask`. I could not resolve working URLs for those two articles, so **any specific watchOS network throttling numbers are unverified** — I found none published.

---

## Design implications specific to a health/recovery app on Apple Watch

Not Apple quotes — my synthesis of the above, flagged as such:

1. **The complication and the Smart Stack widget are the product; the app is the detail view.** Apple states outright that people "frequently use a watchOS app's related experiences… more than they use the app itself" and "may never explicitly launch your app."
2. **`accessoryRectangular` is the highest-value surface** — it is the only family that both lives on the watch face *and* rotates into the Smart Stack, and Apple's own cited exemplar for it is a 24-hour heart-rate graph.
3. **A relevance score on your timeline entries is dead code on watchOS.** You need `relevance()` returning `WidgetRelevance`, or `RelevanceConfiguration` (watchOS 26+). `RelevantContext.fitness(_:)` and `.sleep(_:)` map exactly onto a recovery product, and both require the corresponding HealthKit permission on **both** the app and the widget extension.
4. **Recovery scores are health data → must be redacted in Always On.** Apple's rule is unconditional: "always hide any highly sensitive information, such as financial information or **health data**."
5. **Never fire a haptic while sampling heart rate.** This is the single most consequential API footnote for this product category.
6. **Budget arithmetic:** ~4 background refreshes/hour with a complication on the active face, shared across all your complications, plus 40–70 WidgetKit reloads/day, plus 5-minute minimum entry spacing. A recovery score that changes hourly fits comfortably; a live readiness meter does not.
7. **The 60-second ceiling is the design constraint.** One screen, one number, one action, crown-scrollable. Vertical `TabView` pages of fixed screen height, no nested hierarchy, no spinners.

---

Confidence: 92/100 — every number, quote, table, and API availability above was pulled this session from live Apple JSON endpoints and re-read in full; watchOS 26.6 currency and the wrist-flick/Smart Stack-hint wording were cross-checked against Apple Newsroom, Apple Support, MacRumors and 9to5Mac. Below 100 because: (a) point values in §1 are my ÷2 arithmetic, since Apple publishes watchOS screen dimensions in pixels only; (b) Apple publishes **no** numeric watchOS safe-area insets and **no** Smart Stack line count, so those two asks are answered with an explicit "not published" plus a derivation I have labelled as mine; (c) four Apple articles 404'd on every path I tried ("Create accessible experiences for watchOS", "Supporting multiple watch sizes", "Making background requests", "Enabling the double-tap gesture"), so watchOS network throttling limits and any extra a11y specifics in those pages are unrepresented; (d) the exact signature of the `digitalCrownRotation` overload carrying the haptic-detent parameter is unresolved and deliberately omitted; (e) the widget/complication spec tables have no 42mm or 46mm rows — that is Apple's gap, not mine, and it is untested on real Series 10/11 hardware. | Source: mixed: internet (developer.apple.com HIG + developer documentation JSON endpoints, apple.com newsroom, support.apple.com, macrumors, 9to5mac) + assumption (the px→pt @2x conversion and the Smart Stack line-count estimate, both explicitly labelled inline)

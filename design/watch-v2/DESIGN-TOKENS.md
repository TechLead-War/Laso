# Laso Watch design tokens

Source of truth for colour: `Common/Theme/AppColour.swift` and `Common/Components/DesignSystem.swift`,
dark values only. Source of truth for layout: Apple's watchOS HIG (see `research/apple-hig.md`).

**The Watch is dark, always.** watchOS has no light appearance for third-party apps and the OLED
panel makes true black free. Every prototype is dark only. Do not add a light-mode toggle.

---

## Canvas

Design target is **46mm Apple Watch Series 10 — 208 × 248 pt (416 × 496 px @2x)**, which is what the
existing `screenshots/apple-watch-416x496/` folder captures.

Every prototype must also render correctly at the **smallest supported size, 40mm — 162 × 197 pt**,
switchable from the dev toolbar. If a layout breaks at 40mm it is not a shipping layout.

| Size | Points | Notes |
|---|---|---|
| 40mm | 162 × 197 | floor — must work |
| 41mm | 176 × 215 | |
| 42mm (S10) | 187 × 223 | |
| 44mm | 184 × 224 | |
| 45mm | 198 × 242 | |
| 46mm (S10) | 208 × 248 | **design target** |
| 49mm (Ultra) | 205 × 251 | flat display, wider safe area |

Screen edge padding: `8pt` horizontal on 40-41mm, `10pt` on 44mm and up. The display is rounded on
every non-Ultra model, so **no content in the corner 12pt radius**.

---

## Colour (dark values, hex)

| Token | Hex | Use |
|---|---|---|
| `bg` | `#000000` | app background — true black, never `#0F0F13` on watch |
| `surfaceRaised` | `#1B1B21` | card / row background |
| `surfaceElevated` | `#26262D` | nested tile, selected chip |
| `surfaceSubtle` | `#17171C` | gauge track, rail fill |
| `textPrimary` | `#F2F2F6` | numbers, headlines |
| `textSecondary` | `#C9C9D2` | body |
| `textTertiary` | `#ADADB8` | captions, units, meta |
| `borderLow` | `#2E2E36` | 1px card stroke |
| `primary` | `#4DA3FF` | primary action, info |
| `accent` | `#22D3EE` | AI / ask-your-data affordance |
| `optimal` | `#33C48D` | score ≥ 67 |
| `fair` | `#E3B45A` | score 45-66 |
| `poor` | `#E05C64` | score < 45 |

### Score bands — the only threshold table in the app

```
>= 67  optimal   green  #33C48D   label "Optimal"
45-66  fair      amber  #E3B45A   label "Moderate"
<  45  poor      red    #E05C64   label "Low"
```

Verified against `Common/Theme/AppColour.swift` (dark literals) and
`DesignSystem.recoveryTier` (`optimalFloor = 67`, `fairFloor = 45`,
`Common/Components/DesignSystem.swift:189-200`). Note: `design/home-v2/DESIGN-TOKENS.md` lists the
green as `#3DCC99`; that document is stale, the shipping value is `#33C48D`.

**Colour carries the verdict before the number does.** This is the rule the shipping Watch app
breaks. A user must be able to make the decision from colour alone, in peripheral vision, without
reading a digit.

Never use colour as the *only* channel — always pair it with shape (arc fill), position, or a word,
for colour-blind users and for the Always-On dimmed state.

---

## Typography

System face only. watchOS ships SF Compact Rounded as the default; the app's custom faces are not
bundled in the Watch target and must not be simulated.

```css
font-family: -apple-system, "SF Compact Rounded", "SF Pro Rounded", system-ui, sans-serif;
font-variant-numeric: tabular-nums;
font-feature-settings: "tnum" 1;
```

| Role | Size (pt) | Weight | Use |
|---|---|---|---|
| heroNumber | 52 | 600 | the one number on a screen |
| heroNumberS | 40 | 600 | hero at 40mm |
| title | 22 | 600 | screen title, secondary number |
| headline | 17 | 600 | row title, button label |
| body | 16 | 400 | one-line verdict sentence |
| footnote | 13 | 400 | supporting line |
| caption | 12 | 400 | metric label |
| caption2 | 11 | 500 | unit, timestamp, delta |

**Line budget per screen: 4 lines of text maximum.** If a screen needs a fifth, it is two screens.

---

## Spacing and radius

4pt grid: `2, 4, 6, 8, 10, 12, 16, 20`.
Card interior padding `10`. Card gap `8`. Section gap `14`.

Radius: chip `6` · row `10` · card `14` · full-bleed hero card `18` · pill `9999`.

---

## Tap targets

**Minimum 44 × 44 pt.** On a 162pt-wide screen that means **at most 3 targets in a row**, and a
full-width row is the safe default. The shipping check-in screen puts 5 targets in a 162pt row
(~30 × 25pt each) — that is the exact mistake this rule exists to prevent.

Anything finer-grained than 3 choices uses the **Digital Crown**, not more buttons.

---

## Gauges — and the rule that overrides taste

**Bars beat rings for anything the user must compare.** Measured time to correctly compare two
values: bar `159-285 ms`, donut `216-245 ms`, radial bar `1548-1772 ms`
([Microsoft Research, InfoVis 2018](https://www.microsoft.com/en-us/research/wp-content/uploads/2018/08/GlanceableVis-InfoVis2018.pdf)).
A radial encoding costs 6-10× more viewing time against a 5-second session budget. Apple's own
exemplar for `accessoryRectangular` is a 24-hour heart-rate **graph**, not a ring
([HIG: Complications](https://developer.apple.com/design/human-interface-guidelines/complications)).

So:

| Use | Encoding |
|---|---|
| **One** hero value, absorbed not compared | Circular arc — legitimate, it reads as a level |
| Today vs yesterday, vs baseline, vs goal | **Bar**, never a second ring |
| A history of 7-24 points | **Bar sparkline or line**, never a spiral or radial |
| Position inside a target range | **Horizontal band with a marker** |
| Goal completion | Full 360° ring — "closed" is the whole signal |

- Circular arc: stroke `8pt` at 46mm, `6pt` at 40mm, round caps, track `surfaceSubtle`, sweep from
  12 o'clock clockwise. Minimum line width anywhere is `2pt` (HIG).
- Open-gap arc (the WHOOP/Oura shape): 270° sweep, 45° gap at the bottom.
- Bar sparkline: 3pt wide, 2pt gap, today highlighted. 7 bars fits 40mm, 24 bars fits 46mm.

**Never put two rings on one screen.** Two rings is a comparison rendered in the slowest possible
encoding.

---

## Motion

Fast and short. watchOS interactions are 5-20 seconds total, so animation must never be the
bottleneck.

- Screen transition: 220ms `cubic-bezier(.22,.61,.36,1)`.
- Number count-up on first appear: 400ms, once, never on re-render.
- Gauge sweep on appear: 600ms ease-out.
- Press state: `scale(0.96)` in 80ms.
- **Respect `prefers-reduced-motion`**: kill count-up and sweep, keep opacity crossfades.

---

## Haptics

HTML cannot fire a real Taptic Engine, so every prototype **renders a visible haptic marker** — a
short pulse ring at the screen edge plus a caption naming the real `WKHapticType` that would fire.

| watchOS `WKHapticType` | Use in this app |
|---|---|
| `.click` | crown detent, value step |
| `.success` | check-in saved, action marked done, log recorded |
| `.failure` | write rejected by the phone |
| `.notification` | proactive alert arriving (anomaly, stand, recovery ready) |
| `.directionUp` / `.directionDown` | a value crossed a band upward / downward |
| `.start` / `.stop` | timed session begin / end |

**Rule: every state-changing tap fires a haptic.** The shipping app fires none, and its two
"saved" strings are dead code that no view ever shows.

**Exception that bites:** *"When you engage the haptic engine, HealthKit stops gathering heart rate
data until after the haptic engine finishes"*
([WKInterfaceDevice.play](https://developer.apple.com/documentation/watchkit/wkinterfacedevice/play(_:))).
So a screen that is actively sampling heart rate must not fire haptics while it samples. Minimum
spacing between haptics is 100 ms, and there are no background haptics outside a workout session.

---

## Always-On Display — health scores must be REDACTED, not just dimmed

Apple's rule is unconditional: *"always hide any highly sensitive information, such as financial
information or health data"*
([Designing for the Always On state](https://developer.apple.com/documentation/watchos-apps/designing-your-app-for-the-always-on-state)).
**A recovery score is health data.** Anyone standing behind the user can read a dimmed screen.

When `isLuminanceReduced` is true:

- **Replace the number with a redacted placeholder** — the same glyph count as a dash row, or the
  gauge shape stroked as an empty outline. Keep the layout stable so nothing jumps on wake.
- Colour may stay only if it does not itself disclose a health verdict. A red arc that means
  "poor recovery" is disclosure — stroke it neutral instead.
- Non-sensitive context may stay: the app name, the time, a goal ring's *shape*.
- Never animate. Never update sub-second.

This is the opposite of what feels right, and it is what Apple requires. Every prototype must be
able to toggle into this state from the dev toolbar and must show a genuinely redacted screen.

## Loading — no spinners, ever

Apple: *"Avoid displaying an indeterminate progress indicator… An animated indicator can make
people think they need to continue paying attention to the display"*
([HIG: Feedback](https://developer.apple.com/design/human-interface-guidelines/feedback)).

Show the **last known value with a staleness marker** instead. A watch app that has ever had data
should never show a blank loading screen — it should show yesterday's truth, labelled as such.

## Freshness — say the quiet part out loud

A watch complication can update roughly **4 times per hour**, and widgets never update in real time
([Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date)).
The wrist will therefore disagree with the phone. Athlytic documents this cap in-product and
pre-empts the support ticket; Bevel does not and has a
[live public bug thread](https://feedback.bevel.health/bug-reports/p/bevel-phone-app-and-watch-app-values-dont-match)
about watch values being 1-5 points off.

**Every concept must show its own freshness** — a timestamp, a dot, or a word. Never a silent
stale number.

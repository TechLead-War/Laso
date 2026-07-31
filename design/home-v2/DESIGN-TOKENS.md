# Laso design tokens — verbatim from the shipping app

Source of truth: `Common/Theme/AppColour.swift` and `Common/Components/DesignSystem.swift`.
Every prototype must use these values. Do not invent colours, radii or spacing.

## Colour (hex, light / dark)

| Token | Light | Dark | Use |
|---|---|---|---|
| surfaceSunken | `#E4E4EC` | `#08080A` | page background |
| surfaceBase | `#EEEEF4` | `#0F0F13` | grouped background |
| surfaceRaised | `#F8F8FB` | `#1B1B21` | card background |
| surfaceElevated | `#FCFCFD` | `#26262D` | nested card / sheet |
| surfaceOverlay | `#FEFEFF` | `#33333B` | popovers, chips on cards |
| surfaceSubtle | `#EAEAF1` | `#17171C` | track / rail fills |
| textPrimary | `#1B1B20` | `#F2F2F6` | headlines, numbers |
| textSecondary | `#44444D` | `#C9C9D2` | body |
| textTertiary | `#5B5B65` | `#ADADB8` | captions, meta |
| borderLow | `#E0E0E8` | `#2E2E36` | card stroke |
| borderMedium | `#C9C9D3` | `#414149` | dividers, active stroke |
| primary | `#0064CC` | `#4DA3FF` | primary action, info |
| accent | `#0E7490` | `#22D3EE` | AI / ask-your-data affordance |
| success / scoreOptimal | `#0C7752` | `#3DCC99` | score ≥ 67 |
| warning / scoreFair | `#8A6400` | `#E3B45A` | score 45–66 |
| danger / scorePoor | `#C42B33` | `#E05C64` | score < 45 |

Light mode needs the shadow to separate a card from the page.
Dark mode uses opaque surface steps plus a 1px border, never shadows.

## Score bands (the ONLY threshold table in the app)

- `>= 67` optimal — label "Optimal", green
- `45 – 66` fair — label "Moderate", amber
- `< 45` poor — label "Low", red

## Spacing (4pt grid)

`4, 8, 12, 16, 20, 24, 32, 48`
Screen horizontal padding `12`. Card interior padding `16`.
Card-to-card gap `12`. Section separation `24`.

## Radius

chips `4` · inputs `8` · tiles `12` · large cards `16` · sheets `20` · hero cards `24` · pills `9999`

## Typography

System face (SF Pro / -apple-system). Numbers use rounded + tabular figures so digits do not jitter.

- displayXL `56px bold rounded`
- displayL `44px bold rounded`
- displayM `36px bold rounded`
- displayS `28px bold rounded`
- title `28px bold` · title2 `22px semibold` · title3 `20px semibold`
- headline `17px semibold` · body `17px` · callout `16px` · subheadline `15px`
- footnote `13px` · caption `12px` · caption2 `11px`

CSS: `font-family: -apple-system, "SF Pro Text", system-ui, sans-serif;`
Numeric: `font-feature-settings: "tnum" 1; font-variant-numeric: tabular-nums;`

## Card style

- Radius `24` for hero cards, `16` for standard cards.
- Light: `background: surfaceRaised; box-shadow: 0 1px 2px rgba(0,0,0,0.12); border: 1px solid borderLow;`
- Dark: `background: surfaceRaised; border: 1px solid borderLow;` no shadow.
- Tinted card = surfaceRaised base + 4% tint wash + 18% tint border.

## Motion

- press in `easeIn 80ms`, press out `spring ~300ms`
- ambient / toast `easeInOut 250ms`
- Respect `prefers-reduced-motion`.

## Chrome

- 3–4 tab bottom bar. Current shipping tabs: Today · Live · Explore · Settings.
- Status bar `9:41`, full signal, wifi, battery.
- iOS 26 Liquid Glass only on floating chrome, never on content cards.

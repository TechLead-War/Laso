# Laso Apple Watch redesign

Complete rethink of the Watch app from first principles. Read in this order.

| # | File | What it is |
|---|---|---|
| 1 | [01-CURRENT-APP-CRITIQUE.md](01-CURRENT-APP-CRITIQUE.md) | Teardown of the shipping Watch app, screen by screen, from the source |
| 2 | [research/00-SYNTHESIS.md](research/00-SYNTHESIS.md) | 18 watchOS rules, competitor comparison, 17 design principles, 11 ranked engagement mechanics, 18 anti-patterns, honest gaps |
| 3 | [02-CONCEPT-SET.md](02-CONCEPT-SET.md) | The ten concepts and the axes that separate them |
| 4 | **[FINAL.html](FINAL.html)** | **The final design — every screen on one page. Start here if you only open one file.** |
| 5 | [concepts/index.html](concepts/index.html) | The ten working prototypes that got us there |
| 6 | [03-ARCHITECTURE.md](03-ARCHITECTURE.md) | The engineering change every concept needs, with effort and risk |
| 7 | **[04-RECOMMENDATION.md](04-RECOMMENDATION.md)** | **The pick, why it wins, and Phase 1/2/3** |

Supporting: [PROTOTYPE-SPEC.md](PROTOTYPE-SPEC.md) (hard requirements + the shared fictional user)
· [DESIGN-TOKENS.md](DESIGN-TOKENS.md) (colour, type, gauges, haptics, Always-On) ·
[research/](research/) (six raw research reports with real URLs).

---

## The prototypes

Ten single-file HTML prototypes, no build step, no network. Open `concepts/index.html` and click
through, or open any `concepts/NN-slug.html` directly.

Each one renders the complete watch experience — watch face with complications, Smart Stack,
notifications, every app screen, plus loading, cold-start, empty, error, stale and Always-On states.
Mouse wheel or ↑/↓ turns the Digital Crown. The **Dev** button in the corner switches canvas size
(46mm/40mm), state, and the concept's key variable across all three colour bands.

Every prototype uses the same fictional user on the same day (Alex, 34, Tuesday 14:32) so they are
directly comparable.

**Verified:** all ten render in headless Chrome with zero JavaScript errors, contain no external
dependencies, and all internal links resolve. Not verified: how they look in a real browser at
other window sizes, and any of this on real watch hardware.

---

## The two findings that matter most

**1. The current Watch app cannot succeed as built.** It does not link HealthKit at all — its
entitlements file contains one App Group and nothing else. It renders a ten-field struct the phone
mails it, three fields of which no view ever draws, and the phone only mails it while the user is
looking at the phone. Its most common message is a request to go use the iPhone.

**2. "5-20 app opens a day" is the wrong unit.** All ten concepts, designed independently, came back
at 0.1-2.9 app opens per day. Apple states users *"may never explicitly launch your app"*, and the
measured reality is 142 wrist raises a day at a 5.0 second median. The achievable and correct target
is **15-25 zero-tap encounters a day on the face and in the Smart Stack**, plus 2-3 app opens when
someone wants the reason behind one. See [04-RECOMMENDATION.md §1](04-RECOMMENDATION.md).

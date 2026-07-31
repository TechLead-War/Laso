# Prototype spec — every concept must satisfy this

One concept = one standalone `.html` file. Nothing else. No build step, no network.

## Hard technical rules

1. Single file. Embedded `<style>` and `<script>`. No external libraries, no CDN, no web fonts, no remote images.
2. Charts are hand-built with inline SVG, CSS, or `<canvas>`. No chart library.
3. Icons are inline SVG paths or unicode. No icon font.
4. Works offline when opened straight from the filesystem with `file://`.
5. Responsive: renders correctly from 320px to desktop. On desktop it renders inside a centred phone frame (max 430px content width) so it reads as a real iOS screen.
6. Light and dark both supported. Follow `prefers-color-scheme` by default and provide a visible toggle.
7. Respect `prefers-reduced-motion`.
8. Accessible: real focus states, ≥44px tap targets, `aria-label` on icon-only buttons, text contrast ≥ 4.5:1.
9. No `alert()`. No dead links. Every control does something visible.

## What the screen must contain

The complete Home Screen, top to bottom, not isolated components:

- iOS status bar (9:41, signal, wifi, battery)
- Screen header / navigation
- Hero section
- Body content cards
- At least one chart or data visual rendered in SVG/CSS/canvas
- Expandable / progressive disclosure sections that really expand
- A bottom tab bar with the active tab highlighted
- Micro-interactions: press states, transitions, haptic-feel scale on tap
- A visible way to see the loading state and the empty state (a small dev toolbar toggle is fine, placed unobtrusively)

## Simulated data rules

- Use one consistent fictional user across every concept so the concepts are comparable.
  **Alex, 34. Readiness 62 today, 71 yesterday. HRV 48 ms (7-day avg 54). Resting HR 58 bpm (baseline 55). Slept 6h 12m against a 7h 40m need. Sleep debt 4h 20m over 5 nights. 8,400 steps yesterday. Hard run 2 days ago. Bedtime drifting 40 min later across the week.**
- Numbers on screen must be internally consistent with that user and with each other.
- Never fabricate a precision the data cannot support. No "biological age 27.3".
- Charts must plot plausible day-to-day variation, not a smooth invented curve.

## Dev toolbar

A single small button in a corner opening a panel that can switch: light/dark, loaded/loading/empty states, and (where the concept depends on it) high/medium/low readiness. It must not be part of the design being judged, so keep it visually out of the way.

## Naming

File: `design/home-v2/concepts/<NN>-<slug>.html`
Companion rationale: `design/home-v2/concepts/<NN>-<slug>.md`

## Rationale document

Each concept ships a markdown file answering, with research citations from the design brief:

1. The one-sentence philosophy.
2. Why this layout order, element by element.
3. Psychological principles used, and the specific mechanism.
4. UX principles applied.
5. Which user problems it solves.
6. Which metrics were given prominence and why.
7. Which metrics were deliberately hidden or removed and why.
8. Expected impact on daily engagement, with the mechanism.
9. Expected impact on retention, with the mechanism.
10. Honest drawbacks and who this design fails.
11. The five-questions scorecard for every component on the screen.

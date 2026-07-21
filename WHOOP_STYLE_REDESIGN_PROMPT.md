# Laso → WHOOP/Oura-class Redesign — Master Build Prompt

Paste this into Claude Code. Build one screen at a time in the order in §7. For each screen: read the current file → confirm the target → implement with existing tokens/components → run in the simulator → verify the real data flow → report. Do not batch screens.

---

## 1. Mission

Rebuild every Laso screen to the "Laso Signature" direction: WHOOP's data discipline + Oura's calm restraint. The rules:

- **One hero number per screen**, huge, in a colored ring. Everything else recedes.
- **Plain-English WHY on the surface itself** — first person, vs the user's own baseline ("HRV up 12% vs your 2-week average"). No jargon, no confidence %, no CI ranges above the fold.
- **Progressive disclosure, 3 tiers**: glance (hero + 2–3 dials) → why (ranked drivers) → raw (charts/history). One idea per card.
- **Color = meaning only.** Score bands and per-pillar hues carry information; nothing is decorative. Judge every metric against the user's *personal* baseline band, not a universal threshold (Oura's core idea).
- **A real daily-return engine**: near-zero-effort streak (open + glance) with 2 freezes, loss-framed copy, and a fresh-start morning reset. Neither WHOOP nor Oura ships this — it's the wedge.

Reference apps: WHOOP (three-dial home, Strain vs Recovery, Health Monitor), Oura (Today/Vitals/My Health intent tabs, personalized baselines, "one big thing"), Ultrahuman (real-time nudges, stimulant window — stretch ideas).

---

## 2. Guardrails (non-negotiable — from CLAUDE.md + the codebase)

- ViewModels are `@MainActor @Observable final class`. DI via `AppContainer` `makeXViewModel()` factories. No ObservableObject/Combine.
- HealthKit only through the injected `HealthKitManager` (Core/Data). Scorers consume time series. Never add `import HealthKit` to a view.
- **Every user-visible string** goes in `Common/Copy/Copy+<Domain>.swift` as a computed property resolving through `RemoteConfigManager.shared.copyString("copy_<domain>_<name>", default: "…")`. Reference as `Copy.<Domain>.name`. No inline literals, ever (notification bodies and interpolated templates included).
- Use `DS.*` tokens (spacing, radius, typography, motion, elevation) and `AppColour.*` only. No raw `.white`/`.opacity`/hex/`.systemBackground` literals. App is dark-mode-locked.
- Reuse existing components (see §3) — do not reinvent rings, cards, buttons, charts, badges.
- Score bands are single-source: the DS 3-band table (>75 optimal / ≥50 fair / <50 poor) must stay aligned with `DashboardViewModel.RecoveryState.init(score:)` and `HealthScoreBand`. Change the config, not per-screen `if/else`.
- No magic clinical numbers inline — thresholds live in the named central config with a source.
- No dead code (run Periphery). Useful comments only (explain *why*). Smallest correct change; don't touch unrelated code.
- **Verify at runtime** (drive the real screen in the simulator) before saying done. Bump `MARKETING_VERSION` + `CURRENT_PROJECT_VERSION` before any archive; commit message is bare `v2.NN`.
- Align on the target with me before coding each screen.

---

## 3. Design contract (every screen obeys this)

**Surfaces** — `AppColour.surfaceBase` canvas (near-black); cards `surfaceRaised` at `DS.Radius.xxl` (24); elevation via surface-lightening + hairline `borderLow/Medium`, never shadows (shadows only for floating overlays). Use the `cardStyle(tint:)` modifier.

**Color (meaning only)**
- Score bands: `scoreOptimal #10B981` / `scoreGood #34D399` / `scoreFair #F59E0B` / `scorePoor #E5484D` via `DS.scoreColor`.
- Per-pillar hues stay in separate color languages so a pillar color never means "score": Sleep `categorySleep #818CF8`, Stress `categoryStress #A78BFA`, Vitality/Recovery green ramp, Brain `categoryBrain #F472B6`. **Strain needs its own blue** (e.g. `#0093E7`) — `categoryActivity #FBBF24` collides with score-amber; add a `categoryStrain` token and resolve this collision.
- One action accent: `AppColour.accent` cyan `#22D3EE`, reserved for the single primary action per screen. Scarcity gives it meaning.
- Every metric colored against the user's **personalized baseline band** (their normal), not an absolute cutoff.

**Typography** — hero numeral in `DS.Typography.displayXL/displayL` (rounded, `.monospacedDigit()` so it doesn't jitter as it ticks). One dominant number; tier word beneath it in the band color; imperative line at `.body`; labels small and quiet. Aggressive size hierarchy — priority reads before content.

**Rings/gauges** — `HealthScoreRing` is the canonical 0–100 dial; every pillar renders as a ring/dial. Hero reveal uses `DS.Motion.reveal` (spring fill) + `DS.Motion.counter` (count-up), landing on the exact value and holding. Honor Reduce Motion (dissolve to final value, never hide the number).

**Disclosure** — glance/why/raw on three levels; push CI, model confidence, and scale legends behind a tap. Plain-English WHY visible without tapping.

---

## 4. Navigation / IA — the one strategic decision (confirm before building)

Current: 4 tabs `Today / Live / Explore / Settings`; the actual daily pillars (Recovery, Sleep, Strain, Weekly Review, Insights, Health State) are buried as Home cards + push routes, so there is no glanceable pillar navigation.

**Recommended target (Oura intent-model):**
- **Today** — now: hero + Recovery/Sleep/Strain dials + one action + streak.
- **Body** (rename Explore) — whole-body Vitals snapshot: every pillar as a dial against its personal baseline.
- **Trends** — long-horizon: Weekly Review, Vitality/Cardio age, Resilience, correlations.
- **Coach** — WHOOP-style AI + "ask your data", floating-accessible.
- Settings/Profile move behind a top-left avatar. Live folds into Today's hero while streaming (not its own tab).

Confirm this restructure (or keep 4 tabs) before touching `AppTab.swift`/`ContentView.swift`. The per-screen specs below hold either way.

---

## 5. Per-screen specs

Format: **Screen** (`file`) — current hero → **target hero** · tier structure · reuse · fix.

### A. Today & daily loop
- **Today / Home** (`Modules/Dashboard/Views/Home/HomeView.swift`) — 10+ stacked cards → **hero Recovery ring + a 3-dial row (Recovery/Sleep/Strain) above the fold**, one plain-English why line, ONE action card, then a collapsed "Insights" row. Demote Daily Narrative, Body Intelligence, Forecast, Ask-Your-Data into one "Today's insights" entry. Add the streak chip + fresh-start line to the greeting. Pin the hero; move Vitals to the Body tab. Reuse `HealthScoreRing`, `cardStyle`, `DS.Motion.reveal`.
- **Live** (`Modules/Live/Views/Live/LiveView.swift`) — HR dump → **live Strain-accruing ring as hero** with current HR + zone beside it; vitals collapse into a 2-col grid below. Surface live day-strain (WHOOP's live loop). Keep the streaming/stale states but lead with the ring.
- **Weekly Review** (`Modules/Dashboard/Views/Home/WeeklyReviewView.swift`) — score ring + text lists → keep the ring hero, add a **7-day bar strip** (per-day Recovery/Sleep/Strain) and per-pillar trend lines. Reuse `WeeklyBarChart`. Move to the Trends tab.

### B. The five pillars (make each a WHOOP-class detail)
- **Recovery/Readiness detail** — **pair Strain vs Recovery on one screen** (WHOOP's core loop; `workoutRecoveryBand` is already passed but unused). Ring hero + ranked contributors (HRV, RHR, resp rate, sleep, temp) each vs personal baseline + recovery trend line.
- **Sleep Coach** (`Modules/Sleep/Views/Sleep/SleepCoachView.swift`) — hero shows *recommended need* → **lead with last night's Sleep Performance score (0–100) in a ring**, stage donut/hypnogram at top; keep debt + 14-day history below. Render the `lastUpdated` freshness caption (currently dropped).
- **Strain** (`Modules/Strain/Views/Strain/StrainDetailView.swift`) — good ring already → add the **recovery pairing** and a live "X more to hit optimal" dial; promote the HR-zone breakdown out of the Learn-More disclosure; add per-workout contributions.
- **Stress** (`Modules/Stress/Views/Stress/StressMonitorView.swift`) — instantaneous gauge → add a **day timeline of stressed/relaxed/restorative minutes** (Oura daytime stress) and a restorative counterpart. Consider moving 0–3 to a 0–100 index for glance parity.
- **Vitality** (`Modules/Vitality/Views/Vitality/VitalityDetailView.swift`) — particle orb → keep the orb but add a **calm today read**: age delta as a scored ring + one-line verdict at top; simplify the 3 floating chips. Surface `lastUpdated`.
- **Brain Health** (`Modules/BrainHealth/…/BrainHealthDetailView.swift`) — naked number → **wrap the score in a colored ring** like every other pillar; collapse the 5-subscale "masterclass" behind disclosure. Fix the `readinessColor` bucket bug (0.5 and 0.3 both map to warning).

### C. Tracking & insights
- **Insights** (`Modules/Insights/Views/Insights/InsightsDetailView.swift`) — list only → add a **headline hero tile** (top insight of the day) + per-insight sparkline. Move the aha-moment paywall off the first view.
- **Correlations** (`…/CorrelationsView.swift`) — text tiers → add strength/scatter mini-charts; make `ProfeatureOverlay` actually replace content, not float over it.
- **Health State Timeline** (`Modules/HealthState/…/HealthStateTimelineView.swift`) — monthly calendar → keep as a Trends screen; add a single headline metric + trend line above the calendar; humanize state jargon.
- **Cycle** (`Modules/CycleTracking/…/CycleDetailView.swift`) — static phase copy → **personalize phase impacts to the user's own HRV/sleep/recovery**; overlay cycle phase on recovery trend (WHOOP women's insights).
- **Risk** (`Modules/Risk/…/HealthRiskDetailView.swift`) — static gauge → add a risk trend sparkline + a single "biggest lever" callout at top; lead with Focus Areas.
- **Journal** — **wire the dead screens.** `ExpandedJournalView` and `JournalInsightsView` have no call sites. Add a Journal entry point (Today + Coach), preload today's logged behaviors, show an end-of-day summary + streak, and surface the correlation analyzer output (WHOOP's Impacts view).

### D. Drilldowns
- **Metric Detail** (`Modules/MetricDetail/…/MetricDetailView.swift`) — monochrome number, chart below fold → **color the hero value by its baseline band + a position indicator**; move the chart up as the hero visual; collapse the 12 stacked sections.
- **Category Detail** (`Modules/CategoryDetail/…/CategoryDetailView.swift`) — make the hero ring timeframe-aware (currently inconsistent with the sections below); add the category-score trajectory; add a plain verdict + top driver next to the ring.
- **Explore → Body** (`Modules/Explore/…/ExploreView.swift`) — 9-section EWMA scroll → become the **Vitals tab**: pillar dials against personal baselines, swipeable metric-to-metric, drill-down arrows.
- **Discovery** (`Modules/Discovery/…/DiscoveryView.swift`) — one-time reveal; keep, but make discoveries revisitable in Trends.

### E. Account & settings
- **Settings** (`Modules/Settings/Views/SettingsView.swift`) — app-branded About box → **user-branded account header** (avatar, name, member-since) with a real editable profile; add an upgrade CTA for free users, a **referral/invite surface** (ReferralManager already exposes shareText/generateCode/daysRemaining — currently never shown), and a link to Achievements.
- **Notifications** (`…/NotificationsSettingsView.swift`) — surface the iOS permission status; add per-toggle preview; group by priority.
- **Devices** (`Modules/Devices/…/ConnectedDevicesView.swift`, `DeviceDetailView.swift`) — text status → per-device battery/last-worn/coverage as small rings; freshness per metric.
- **Achievements/Profile** (`Modules/Profile/…/AchievementsView.swift`) — strongest ring in the account area; link it from the new profile header; tie level thresholds to health outcomes, not just day counts.
- **Web Report** (`Modules/WebExport/…`) — add an in-app preview + date-range/metric selection before share.

### F. Onboarding & paywall
- **Onboarding (14 steps)** (`Modules/Onboarding/Views/Onboarding/OnboardingV2*.swift`) — keep the reveal flow; stop reusing the same heart orb on Welcome/Bridge/Cliffhanger/SignIn (give each a unique visual); make the ~7s scan gate on real load, not a fixed timer; add value labels to reveal charts. Lead-with-empowerment framing (onboarding rule), privacy is not the hero.
- **Paywalls (unify)** — the in-onboarding paywall (`OnboardingV2Screens14ToDone.swift`) uses OnbV2 tokens and personalizes to the user's findings; the standalone `Modules/Paywall/…/PaywallView.swift` is generic and uses different tokens. **Unify to one design system** and carry the personalized "what we'll watch" pitch into both.

---

## 6. Cross-cutting features to add
1. **Strain vs Recovery** paired view (the WHOOP loop) — Recovery detail + Live.
2. **Personalized baseline bands** on every metric (Oura) — a shared `BaselineBand` component + color helper.
3. **Daily-return engine**: streak chip (open+glance), 2 freezes, loss-framed copy ("Keep your 12-day run"), fresh-start morning reset line. New `StreakEngine` + Today UI.
4. **"One big thing"** time-of-day contextual hero on Today (morning readiness / midday stress / evening wind-down).
5. **Coach / Ask-your-data** as a first-class tab.
6. Stretch (Ultrahuman): caffeine/stimulant window, circadian nudges, real-time "get up and move" alerts.

---

## 7. Build order
1. **Design components first** — add `categoryStrain` token, `BaselineBand`, pillar `DialView`, `ContributorRow`, `StreakChip`; extend Copy domains. (No screen changes yet.)
2. Confirm §4 nav decision; restructure tabs if approved.
3. **Today** → **Body/Vitals** → the **5 pillar details** → **Weekly/Trends** → **Coach** → **drilldowns** → **account/settings** → **onboarding/paywall unify**.
4. One commit per screen (`v2.NN`), verified in the simulator before the next.

## 8. Definition of done (per screen)
Builds · runs in simulator with real data · tokens + Copy + HealthKit rules obeyed · no dead code (Periphery clean) · score bands single-sourced · screenshots attached · version bumped.

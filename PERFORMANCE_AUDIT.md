# Laso — iOS Performance Audit

**Target:** flagship iPhone, locked 60 fps (see §1 on why 120 is currently unreachable), no visible hangs.
**Scope:** 109 verified findings across 12 audit dimensions plus a completeness pass, merged and deduplicated here to 78 actionable entries.
**Verification level:** every claim below carries a `file:line`. Where a number came from a code comment written by the team rather than from a profiler, it is labelled as such. **No Instruments trace was taken for any finding in this report.** That is itself the first thing to fix.

---

# 1. Executive summary

**The single biggest cause of the reported problem is synchronous work on the main actor in two places: the dashboard refresh pipeline and the cold-launch path.** Not shaders, not blurs, not SwiftUI diffing. `DashboardViewModel.refreshCore` runs eight health scorers back-to-back inside one unyielding `await MainActor.run` block (`DashboardViewModel.swift:801-817`, `:1373`), which the team's own code comment prices at **300-500 ms** (`DashboardViewModel.swift:1376-1377`). Immediately after it, a **second** `MainActor.run` block nobody had audited (`DashboardViewModel.swift:820-831`) runs three more analysis engines, a ten-year `Calendar.component(.weekday:)` scan (`CircadianHealthAnalyzer.swift:146-188`), five JSON encode/decode round-trips and three synchronous ActivityKit daemon reads. The two blocks concatenate into one visible freeze on every refresh that carries new data. On cold launch it is worse: `ContentView.init` forces `DashboardViewModel.init`, which ends in `prewarmScorersFromStoreIfNeeded()` (`DashboardViewModel.swift:493`), which runs an **unpredicated, unlimited** `FetchDescriptor<StoredDailySample>` over the entire health history on the main thread *before the first frame exists* (`HealthDataStore.swift:300-333`) — and the table is deliberately never pruned (`RemoteConfigManager.swift:627`, `"retention_daily_sample_days": 0`), so that cost grows every day the user keeps the app. Then `AppStartupCoordinator.swift:55-61` throws that cache away unconditionally and forces the whole fetch a second time. That is the "occasional UI hangs".

**The second cause is that the app never shows itself.** After launch, the branded splash stays up until `runInitialSetup` finishes (`LasoApp.swift:133-141`), and that awaits `SubscriptionManager.configure()` (`AppStartupCoordinator.swift:32`, `:41`), which serially awaits a StoreKit product fetch with an **8-second** ceiling (`SubscriptionManager.swift:173-175`). The real UI is fully rendered underneath the whole time. Launch feel is therefore governed by network quality, not by the device. This is the cheapest large win in the report and it is a few lines.

**Only the third cause is rendering, and it is a repeated single mistake: a whole-view `.shadow` hung on top of content that changes every frame.** SwiftUI cannot resolve a `shadowPath` for a composite, so it derives the shadow from the rendered alpha of the group and re-rasterizes and re-blurs it offscreen every frame the group changes. It appears seven times, including on the floating tab bar over an `ultraThinMaterial` (`CustomTabBar.swift:18-20`) — which is on **every screen on iOS 17-25**, including both feeds the user named. The repo already fixed this pattern once, measured it at 883 ms, and wrote the reason down (`DesignSystem.swift:225-239`); the seven sites are the ones that were missed. Alongside it, three chart screens rebuild their entire Swift Charts mark tree on every single touch move because the scrub crosshair is declared inside the same `Chart { }` closure as the data (`MetricChartView.swift:188-207`). Two blunt facts before you read the numbers below. **This app is capped at 60 Hz**: `CADisableMinimumFrameDurationOnPhone` is absent from `project.yml` and the project (verified, no hits), so the frame budget is 16.7 ms, not 8.3, and "120 fps on ProMotion" is unreachable no matter what is fixed. And **the app emits zero performance telemetry** — one `import OSLog` across 437 Swift files, no `OSSignposter`, no MetricKit — so every millisecond figure in this report, including the team's own, is an argument rather than a measurement.

---

# 2. Findings by area

Notation: `Cx` = complexity, `Px` = priority. `[verified]` means the file was reopened during this pass.

## 2.1 Rendering / GPU

---

### R1 — Whole-view `.shadow` over changing content (7 sites, one root cause)

**Problem** — Seven surfaces hang a Gaussian-blur `.shadow` on a *composed view* rather than on a *shape*. Because the shadow's input is the group's rendered alpha, and the group's contents animate (a trimming ring, a scrubbing tooltip, a Canvas orb) or its backdrop moves (a material over a scroll), the shadow cannot be cached and is re-rasterized and re-blurred offscreen on every frame.

**Root cause** — SwiftUI resolves a fast `shadowPath` only when the shadow is attached to a resolvable shape. The repo already knows this: `DesignSystem.swift:225-239` documents the exact failure with an 883 ms measurement and `cardStyle()` at `:230-239` ships the correction by hanging the shadow on the background *shape*. These seven sites were missed.

| Site | Line | What animates under it | Correct fix (per-site — they are **not** the same) |
|---|---|---|---|
| Floating tab bar | `CustomTabBar.swift:20` | `.ultraThinMaterial` backdrop, every scroll frame | **Not** an opaque capsule (see §7). Shadow-only masked backing layer, or on iOS 26 delete the shadow entirely — `glassEffect(.regular)` already renders elevation |
| Vitality hero card | `VitalityHeroSection.swift:155` | `OrganicParticleOrbView` Canvas at `:20` | Move `.shadow` onto the `.fill(AppColour.surfaceInverse)` shape **before** `.overlay(...)` at `:136-150` |
| Strain hero card | `StrainDetailView.swift:234` | `Circle().trim` ring at `:178-183` | Wrap `RoundedRectangle.fill(strainGradient).shadow(...)` in `.background { }` — **do not** add `surfaceRaised` (§7) |
| Metric chart tooltip | `MetricChartView.swift:354` | tooltip text, every touch move (`:252`) | `.background { RoundedRectangle(8).fill(AppColour.surfaceOverlay).shadow(...) }` — pixel-identical, `surfaceOverlay` is alpha 1.00 (`AppColour.swift:86-90`) |
| Vitality trend tooltip | `VitalityTrendSection.swift:180` | same, `:131` | same |
| Strain chart tooltip | `StrainDetailView.swift:430` | same, `:378` | same |
| Weekly bar chart tooltip | `WeeklyBarChart.swift:145` | tap-driven only | same |

**Proposed solution** — Four of the seven (the tooltips) are literal one-line moves with a proven-opaque background, so they are pixel-identical. The Vitality hero is one line with a strict ordering requirement: the shadow must sit on `.fill(surfaceInverse)` *before* `.overlay(RadialGradient…)`, not on the `.background(...)` result — attaching it after the overlay re-creates a composite shadow and fixes nothing. The tab bar needs a masked backing capsule:

```swift
.background {
    Capsule()
        .fill(AppColour.surfaceRaised)
        .shadow(color: AppColour.shadowFloating, radius: 14, y: 4)
        .mask {
            Rectangle().overlay(Capsule().blendMode(.destinationOut)).compositingGroup()
        }
}
```
and delete line 20. The mask punches the bar's own area out of the backing capsule so only the outside halo survives and the material still samples live scroll content. The mask depends only on the bar's size, so it rasterizes once at layout.

**Expected improvement** — Tooltips: ~0.1-0.3 ms per touch move × 4 sites, i.e. 12-36 ms of avoidable work per second of scrubbing. Tab bar: 0.1-0.3 ms per scroll frame on every screen on iOS 17-25. Vitality hero: the single largest per-frame GPU item on that screen. Strain hero: ~0.5-2 ms per frame for the 1 s entry animation and every chart scrub frame. None measured.

**Complexity** Low (tooltips, Vitality hero, Strain hero) / Medium (tab bar, needs a visual check on iOS 17 and iOS 26) — **Priority** High

---

### R2 — Vitality orb runs two uncacheable full-orb gaussians at display rate while its own Canvas is throttled to 30 Hz

**Problem** — The Vitality detail screen is the worst sustained frame rate in the app. The orb stutters, the page scrolls badly while it is visible, and the device warms fast.

**Root cause** — `VitalityDetailView.swift:71-74` drives `withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) { orbPhase = .pi * 2 }`. `OrganicBlobShape` declares `animatableData` (`VitalityOrganicOrb.swift:216-233`), so `path(in:)` re-solves an 81-point trig loop on every SwiftUI animation tick — 60/s. Two offscreen gaussians sit on that animating content and therefore cannot cache: `.stroke(lineWidth: 16).blur(radius: 14).blendMode(.screen)` at `:72-78`, and `.shadow(radius: 20, y: 4)` on the whole composition at `:81`. The team's own throttle — `TimelineView(.animation(minimumInterval: 1.0 / frameRate))` at `:141` with `ThermalManager.maxFrameRate == 30.0` at nominal (`ThermalManager.swift:131-139`) — governs only the particle Canvas. The **cheap** part is throttled to 30 Hz; the **expensive** part runs at 60. The comment at `VitalityOrganicOrb.swift:17-20` claiming a fixed radius means the glow "is rasterised once" is wrong: a fixed radius does not make anything cacheable when the shadow's *source* animates. Orb is ~313 × 297 pt = ~0.84 Mpx at @3x (`VitalityHeroSection.swift:13-15`).

**Proposed solution** — Two steps, in order.
1. **Free and visually identical:** derive `orbPhase` from `timeline.date` inside the existing `TimelineView` and **delete** the `withAnimation` at `VitalityDetailView.swift:72`. Do the same for `glowPulse` (`:87-90`). An 18-second loop sampled at 30 fps is indistinguishable. This alone halves both gaussians and the trig loop. Note: simply moving the glow ring into the Canvas does **not** achieve this on its own — `phase` is a plain property fed by the parent's `withAnimation`, so the Canvas body still invalidates at display rate until the phase source moves onto the timeline.
2. **Optional, and NOT visually neutral:** move the glow into the Canvas as `glow.blendMode = .plusLighter; glow.addFilter(.blur(radius: 14))` and replace the `.shadow` with a static radial gradient, copying the pattern the repo already committed to at `RecoveryHeroCard.swift:181-188` ("rather than a Gaussian blur, which re-renders offscreen every frame and makes scrolling lag"). Canvas has no `.screen`, so `.plusLighter` composites differently against the dark core; and the current shadow follows the wobbling blob silhouette with a `y: 4` offset while a radial gradient is a circle. Needs design sign-off.

**Expected improvement** — Step 1: ~50 % of the blur GPU load and of the 81-point path solves on the screen, zero visual change. Step 2: collapses two layer-tree offscreens into one in-Canvas filter. Whole-screen estimate 2-6 ms/frame of gaussian at 0.84 Mpx and σ 14/20 on A17-class silicon — **estimated from pass count × buffer size, not traced**. Enough to make locked 60 possible on this screen. Already correctly gated: `paused` when off-screen (`:82-94`) and `staticOrb` under Reduce Motion or thermal throttle (`:34`).

**Complexity** Medium — **Priority** High

---

### R3 — Vitality orb Canvas is the only orb in the app that renders synchronously on the main thread, and allocates ~176 Colors per frame

**Problem** — The orb's entire particle draw competes with scroll and layout for main-thread budget, on a screen the user named.

**Root cause** — `VitalityOrganicOrb.swift:142` is the bare `Canvas { context, size in`. Both sibling orbs opt out of this: `AskDataOrbView.swift:90` and `OnbV2VitalityReveal.swift:65` both pass `rendersAsynchronously: true`. Inside `drawParticles` (`:175-206`), each of up to 160 particles (`:14`) builds `tint.opacity(particle.alpha)` inline at `:189-191` and fills with an **unresolved** `.color(color)` at `:193`, forcing a shading resolve per fill; ~16 large particles (`size > 3.0`, gated by `:114`) repeat both at `:203`. `drawDarkCore` (`:151-172`) builds a fresh 3-stop `Gradient` per frame at `:159-163`. The resolve-once fix exists twice in sibling files with an explanatory comment: `AskDataOrbView.swift:307-308` and `OnbV2VitalityReveal.swift:95-98`.

**Proposed solution** — Two changes.
```swift
Canvas(rendersAsynchronously: true) { context, size in     // do NOT copy colorMode: .linear — see §7
```
then hoist before the loop:
```swift
let base   = context.resolve(.color(tint))
let bright = context.resolve(.color(AppColour.markerOnInverse))
// per particle:
dots.opacity = particle.alpha            // glow: particle.alpha * 0.12
```
Pixel-identical: this Canvas sets no blend mode on the particle context (`.blendMode(.screen)` at `:70-77` is on the *overlay strokes*, outside the Canvas), so context opacity and colour opacity are equivalent for single non-overlapping solid fills. Hoist the `drawDarkCore` gradient to a `static let`.

**Expected improvement** — Removes ~320 fills + ~320 `Path` allocations + ~320 shading resolves per drawn frame from the main thread at the 30 Hz tick, and ~5,280 `Color` constructions per second of allocator churn. Sub-millisecond on its own; stacks with R2 on the same screen.

**Complexity** Low — **Priority** High

---

### R4 — AskDataOrb: 1,920 `Path` allocations and 1,920 state-changing fills per frame, 15 rebuilt gradients, ~10 filtered draws, ~19 MB resident cache, and no Reduce Motion gate

**Problem** — The most expensive view in the app, on a pushed screen. Opening it costs a visible pause; while open it holds ~19 MB and churns ~57,600 heap allocations per second.

**Root cause** — Five separate defects in one file:
- `AskDataOrbView.swift:310-314` allocates a fresh `Path(CGRect(...))` per particle inside the draw closure and mutates `shell.opacity` between every fill. Particle count is 1,920 (`:511-513`: 12 ribs × 100 + 8 ribs × 90; `reserveCapacity(1920)` at `:526`).
- Fifteen `Gradient(stops:)` are rebuilt inside the draw closure every frame (`:226, 240, 256, 267, 277, 287, 330, 344, 355, 372, 382, 398, 409, 419, 441`), ten of them fully constant, plus ~42 `Color` allocations via `rgba()` at `:452-454`.
- Six filtered sub-contexts (`:252, 324, 343, 367, 430, 438`) issue ~10 filtered draw operations per frame — a filter creates a transparency layer per *drawing operation*, not per context copy.
- `cacheFrameCount = 180` (`:67`) × 1,920 × 40-byte `CachedParticle` = 13.5 MB exact, plus ~1,218 traced path points per frame; `cache` is `@State` (`:63`) with no release, and `.task(id: size)` (`:114-116`) rebuilds the whole thing from scratch on every appearance.
- **No `accessibilityReduceMotion` read anywhere in the file.** It gates only on thermal state (`:82`) and visibility (`:87`). Every other animated surface in the app honours it: `VitalityOrganicOrb.swift:10, 23, 34`; `OnbV2VitalityReveal.swift:62`; even `BreathworkLiveActivityWidget.swift:289`.

**Proposed solution** — In effort order.
1. **One line, accessibility:** add `@Environment(\.accessibilityReduceMotion) private var reduceMotion` and change `:82` to `if reduceMotion || thermalManager.shouldThrottle { staticOrb }` — the exact expression already at `VitalityOrganicOrb.swift:34`, reusing the static branch that already exists.
2. **One word:** `:459` `Task.detached(priority: .userInitiated)` → `.utility`. The view already falls through to `staticOrb` while `cache` is nil (`:93-95`), so a later cache is an invisibly longer static hold.
3. **Free hoist:** promote the ten constant gradients to `private nonisolated static let` (the pattern already used for `shellTintBlue`/`shellTintCyan` at `:73-74`), and resolve shadings once at the top of `renderCached`. Note: "resolve them in `.task(id: size)`" does not compile — a `GraphicsContext` only exists inside the draw closure.
4. **Memory:** release the cache in the existing `.onDisappear` at `:113` (`cache = nil`) so it rebuilds via `.task(id: size)` on re-entry — verify first that the navigation container actually tears the view down, or move the cache to a `static` keyed on `size` so re-entry is free. Either is better than holding 13.5 MB against jetsam headroom for the life of the view.
5. **Allocation, not draw calls:** pre-build one `Path` per particle-size bucket (only two sizes exist, `:512-513`) and translate the context per draw.

**Do not** merge the particles into per-bucket Paths and **do not** merge the blur sub-contexts — both change the picture. See §7.

**Expected improvement** — Reduce Motion users get the full Canvas cost eliminated (query `uses_reduce_motion`, already collected at `AppAnalytics.swift:484`, to size that population). Cache release reclaims ~13.5 MB while the user is elsewhere. Gradient hoist removes ~15 arrays + ~42 Colors/frame for free. Draw-call count is **not** reducible without a visual change. Note the Canvas is already `rendersAsynchronously: true` (`:90`) and `paused: !isVisible` (`:87`) — it cannot cost frames on Today or Biology.

**Complexity** Low (1-4) / Medium (5) — **Priority** Medium

---

### R5 — Four live blurs on Home for paywall decliners, with no rasterization cache

**Problem** — Users who declined the paywall scroll Home with four full-width cards under a live `.blur(radius: 10)`.

**Root cause** — `SoftLockModifier` at `HomeView.swift:1157-1178`, blur at `:1162`, gate at `:397-399` (`appStateStore.paywallDeclined && !FeatureGate.hasFullAccess`), applied at `:544` (RecoveryHeroCard), `:642` (compactAlertBanner), `:658` (MetricStripView), `:687` (WeeklyReviewEntryCard). `grep drawingGroup` across App/Modules/Common/Core returns nothing, so nothing caches the rasterized result.

**Proposed solution** — `.drawingGroup()` on the locked branch so each blurred card rasterizes into one layer instead of re-compositing its subtree. If it must stop re-rendering entirely, render a locked *placeholder* card that takes no live inputs. **Do not** snapshot with `ImageRenderer` — `RecoveryHeroCard`, `MetricStripView` and `compactAlertBanner` all take live view-model data and keep updating under the blur; a snapshot freezes them for the session. `.redacted(reason: .placeholder)` is a different visual treatment and needs design sign-off, not a perf refactor.

**Expected improvement** — Four offscreen blur passes per composited frame removed for the declined-free segment. **Unquantified — profile with Core Animation → offscreen rendering before assigning a budget.** The 883 ms figure at `DesignSystem.swift:225-229` is from 31 nested day dials and does not transfer to four flat card blurs.

**Complexity** Low — **Priority** Medium

---

### R6 — `ActivationProgressBanner` puts a backdrop-sampling glass surface on a content card inside the Home scroll

**Problem** — A card in the Home feed carries a live backdrop blur, which re-samples every frame the content moves.

**Root cause** — `ActivationProgressBanner.swift:104` applies `.glassChrome(in: RoundedRectangle(cornerRadius: DS.Radius.md))` to `progressBar`. `DesignSystem.swift:248-255` resolves that to `glassEffect(.regular)` / `.ultraThinMaterial`, both of which sample the backdrop. The helper's own doc comment on the line above (`DesignSystem.swift:247`) says: "Per Apple HIG, use only on floating surfaces, never on content cards." Rendered inside `HomeView.swift:448`'s LazyVStack at `:590-594`. Every other `glassChrome` call site is a genuine floating surface.

**Proposed solution** — Replace line 104 with `.background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.md))` plus a `.strokeBorder(AppColour.borderLow, lineWidth: 1)` overlay, matching `cardStyle()` at `DesignSystem.swift:230-239`. This is a small but real visual change (the current glass picks up page tint); check both appearances.

**Expected improvement** — ~0.1-0.3 ms of GPU per Home scroll frame, first 8 days only (`ActivationProgressBanner.swift:16`, `state.isComplete` gate). The stronger argument is that it is the only place in the app that breaks the design system's own written rule.

**Complexity** Low — **Priority** Low

---

### R7 — Onboarding blurs two full-screen radial gradients per screen inside a `GeometryReader` that does nothing

**Problem** — Each onboarding screen runs one or two radius-30 gaussians over a full-bleed gradient.

**Root cause** — `OnboardingV2Foundation.swift:239-256`: a `GeometryReader` at `:240`, `.frame(geo.size)` + `.position(center)` at `:248-249`, `.opacity(0.999)` at `:250`, `.blur(radius: 30)` at `:251`, and a dead `.onAppear { _ = (cx, cy) }` at `:254`. Ten of eleven ambient cases call it twice (`:172-232`); full-bleed via `:154`. **Nothing animates the ambient gradient** — no TimelineView, no repeatForever — so the blur rasterizes once per screen appearance and Core Animation caches the layer. This is a one-time first-frame cost on a first-run-only flow, not a per-frame or per-transition cost.

**Proposed solution** — Do only the safe half: delete the `GeometryReader` (`:240`), the `.frame`/`.position` pair (`:248-249`) and the dead `onAppear` (`:254`). `RadialGradient` already takes a relative `UnitPoint` centre and an absolute `endRadius`, so all of that is dead weight plus one extra layout pass per bloom. Replacing the blur with tuned gradient stops is a **visual change** (the blur is hiding a Mach band at `endRadius`) — treat it as a design tweak with side-by-side screenshots on each of the 10 ambient cases, not a silent perf refactor.

**Expected improvement** — One layout pass per bloom removed, certain but small. The blur itself is not a recurring cost.

**Complexity** Low — **Priority** Low

---

## 2.2 SwiftUI state & invalidation

---

### S1 — `smartDailyAction` runs a SwiftData fetch and writes observed state from inside HomeView's body

**Problem** — The only place in the app that puts unbounded disk I/O inside a frame. Every dashboard refresh and every life-context chip toggle clears the daily-action cache; the next Home body pass hits the miss, and *inside the body* runs a SwiftData predicate fetch, the full recommendation advisor and two UserDefaults writes, then writes two **observed** properties, re-invalidating the body that produced them.

**Root cause** — `HomeView.swift:865` calls `viewModel.smartDailyAction(liveVM:)` during body evaluation. The cache fields at `DashboardViewModel.swift:102-103` are declared **without** `@ObservationIgnored` — compare `:113`, where `_cachedDriftInsights` correctly has it. On a miss, `:2186` runs `RecommendationEvaluator.buildActionProof(store:)` → `RecommendationEvaluator.swift:104` → `HealthDataStore.swift:792-797` `modelContext?.fetch(descriptor)` with a `#Predicate`. Then `:2199-2201` writes both observed cache properties, `:2201` `saveActionKey(...)` and `:2205` `DailyActionStore.save(...)` — two UserDefaults writes. The write at `:2199` re-invalidates HomeView, forcing a second full body + layout pass. Cache cleared at `DashboardViewModel.swift:822` and from `HomeView.swift:461-465` on every chip toggle.

**Proposed solution** — Both halves, not just the one-liner. Mark `_cachedDailyAction` / `_cachedDailyActionDate` `@ObservationIgnored` **and** compute the action in `refreshCore` immediately after `invalidateDailyActionCache()` at `:822`, publishing one observed `dailyAction: SmartAction`. `primaryActionCard` then reads a value. The one-liner alone is unsafe: `@ObservationIgnored` means `invalidateDailyActionCache()` no longer invalidates anything, and the card would show stale advice until something else happens to repaint Home. That is masked today but fragile.

**Expected improvement** — Removes one full HomeView body + layout pass per refresh and per chip toggle, and moves a SwiftData predicate fetch plus two UserDefaults writes off the render path. Budget the fetch at 0.5-2 ms warm, higher on the first fetch after launch when SwiftData compiles the predicate. Visual output identical.

**Complexity** Low — **Priority** Critical

---

### S2 — HomeView is one monolithic body observing ~30 properties across 12 `@Observable` objects

**Problem** — Every card on Today is a computed property of HomeView, so the feed is a single SwiftUI body. Any one of ~30 observed properties changing re-evaluates the entire feed.

**Root cause** — `HomeView.body` at `:42-162` plus `homeContent` at `:446-715` is one body; the cards are `private var` computed properties (`primaryActionCard :863`, `compactAlertBanner :740`, `streakMilestoneCard :245`, `softLockBottomBar :403`) and cannot be invalidated independently. Cross-object reads at `:44, :45, :50, :65, :70, :76, :91, :101-102, :152, :159, :461, :497-499, :548, :562, :569, :591-592, :648, :742-743`.

**Proposed solution** — Extract rows into small `View` structs. If you also publish an aggregate snapshot, **the setter must guard on equality** — Observation fires `withMutation` on every set regardless of value, so an `Equatable` snapshot buys nothing without `if new != homeSnapshot { homeSnapshot = new }`. And a snapshot only collapses DashboardViewModel-side sources: HomeView still reads `healthKitManager.timeSeries`, five LiveViewModel sub-objects, `thermalManager.currentState`, `lifeContextStore.active` and `appStateStore` directly. Realistic collapse is ~30 sources to ~8, not to 1.

**Expected improvement** — **Not the frame win it looks like.** The team's own measured figure for a full Home body pass is **0.34 ms** (`DashboardViewModel.swift:80-86`; the 2.13 ms in the same comment is Explore's number, not Home's). Observation tracking is also one-shot per pass, so a burst of writes already coalesces into one pass. Treat this as *enabling*: it makes S1 and the argument-evaluation costs structurally impossible to reintroduce.

**Complexity** High — **Priority** High

---

### S3 — Duplicate and uncached derived values evaluated inside the Home body

**Problem** — Several derived values are computed as function calls inside the Home body, two of them twice in the same pass.

**Root cause** — `HomeView.swift:493` and `:494` call `viewModel.readinessSummary(score:)` twice on adjacent lines for `.head` and `.sub`. `shareTemplates` (`HomeView.swift:205-207` → `ShareableCard.swift:81-175`) is built twice: once for the nil-check at `:519` and again inside the sheet closure at `:533`. `recoveryWhyReasons` (`DashboardViewModel.swift:2568-2638`) runs a candidate build, an `enumerated().sorted()`, a `Set(map)` and an `allCases.filter` per pass.

**Proposed solution** — Two `let` bindings at the top of `homeContent`: `let summary = viewModel.readinessSummary(score: liveReadinessScore)` and `let templates = shareTemplates`. Then cache `cachedWhyReasons` and a `cachedHasShareTemplate: Bool` in the existing `updateCachedProperties()` next to `cachedDailyScoresByDay` (`DashboardViewModel.swift:1151`), keeping the full `shareTemplates` build inside the `.sheet` closure.

**Expected improvement** — 0.1-0.3 ms per Home body pass. **Correcting the audit's own headline:** `signalCoverage` is already fixed — `DashboardViewModel.swift:2663-2668` uses the binary-searched `samples(from:until:)`, and the 0.238/0.436 ms in the comment above it is explicitly the *pre-fix* number ("it **was** the only reading here that got slower … **because it filtered** all five metrics' full sample arrays"). Do not cache it again. `WeeklyReviewViewModel.init` is a single assignment (`WeeklyReviewViewModel.swift:20-22`), ~50 ns, not a perf item.

**Complexity** Low — **Priority** Medium

---

### S4 — `onChange(of: lastRefresh)` → `rebuildMetricTilesFromLive` bounce

**Problem** — Every completed refresh costs one extra full feed pass.

**Root cause** — `HomeView.swift:102-104` fires *after* the body pass that observed the change, then writes `cachedMetricTiles` (`DashboardViewModel.swift:1648`, declared `:413`, observed, and `MetricTile` is not Equatable so the write always publishes), which the body reads at `HomeView.swift:648`. The `.onAppear` cluster at `:105-123` is **not** a problem — those writes happen in one synchronous block inside one transaction and coalesce into a single update.

**Proposed solution** — Have LiveViewModel push its sleep summary into DashboardViewModel on each fetch, then move the rebuild into `refreshCore` at `:822`. The direct move is blocked by ownership: `DashboardViewModel.swift:1494-1496` and `:1554` state explicitly that it does not own LiveViewModel's sleep state, which is why `rebuildMetricTiles` takes sleep values as parameters.

**Expected improvement** — ~0.34 ms (one Home body pass) per refresh.

**Complexity** Medium — **Priority** Low

---

### S5 — Only one view in the entire app is `Equatable`, so no leaf body can ever be skipped

**Problem** — Heavy leaf cards on both hot screens re-evaluate their bodies on every parent pass even when inputs are identical.

**Root cause** — `[verified this pass]` `grep "View, Equatable"` across App/Modules/Common/Core returns exactly one hit: `ExploreMonthCalendarSection.swift:11`. `grep "\.equatable()"` returns exactly one hit: `ExploreView.swift:106`. `RecoveryWhyReason` is `Identifiable` only (`DashboardViewModel.swift:2529`); `MetricTile` likewise. `RecoveryHeroCard.swift:6-27` carries `whyReasons` plus `onTap`, `onTapWhy`, `onShare`; `MetricStripView.swift:20-22` is `let tiles: [MetricTile]` plus a closure. Closures with captured context defeat SwiftUI's reflection-based field comparison, so those bodies always re-run.

**Proposed solution** — Order matters. Add `Equatable` to `RecoveryWhyReason` and `MetricTile` first, apply `.equatable()` to `MetricStripView` and `WeekScoreStrip` (pure data plus one route closure), and treat `RecoveryHeroCard` **last**: when `EquatableView`'s `==` returns true SwiftUI keeps the **old** view value including its closures, so verify `onShare` — which is nil-or-not based on `shareTemplates.isEmpty`, a captured value at `HomeView.swift:519` — does not go stale. A share affordance that stays hidden after a win is earned would be a real regression. `ExploreMonthCalendarSection` is safe only because its comment at `:25-27` documents that its ignored closure reads live view-model state at tap time.

**Expected improvement** — ~0.1-0.2 ms per skipped invalidation on Home. **Do not** extrapolate from the calendar's 88 ms (`ExploreMonthCalendarSection.swift:21-24`) — that figure is 31 simultaneously rasterized day dials, nothing like a single ring or a six-tile strip, and Home's whole body pass is 0.34 ms. The comparison itself is not free either: `[MetricTile]` array equality runs on every pass.

**Complexity** Low — **Priority** Medium

---

### S6 — Both hero score rings replay a 1-second trim animation on every scroll-back

**Problem** — Scrolling past the score card on Today or Biology and back replays the full ring fill from zero, which reads as the score having just changed. A credibility bug on the app's headline number.

**Root cause** — `HealthScoreRing.swift:16` `@State private var animatedProgress: Double = 0`; `:63-65` `.onAppear { animatedProgress = progress }`; `:50` the 1.0 s easeInOut gated on `animatesOnAppear`, which defaults to `true` (`:26`). Inside a LazyVStack the row is destroyed on scroll-off, so `@State` resets and `onAppear` replays. Neither hero site passes the flag: `RecoveryHeroCard.swift:190-196` (inside `HomeView.swift:448`'s LazyVStack at `:491`, several items down, so it definitely recycles) and `ExploreScoreHeroSection.swift:12-18` (first child of `ExploreView.swift:42`). `ExploreCategoriesSection.swift:88-96` already passes `animatesOnAppear: false` and documents why. The component's own comment at `:11-13` names this bug.

**Proposed solution** — Fix it once in the component, not per call site. Delete the `.animation(_:value:)` at `:50` and split the two paths:
```swift
.onAppear {
    var t = Transaction(); t.disablesAnimations = true
    withTransaction(t) { animatedProgress = progress }
}
.onChange(of: score) { withAnimation(.easeInOut(duration: 1.0)) { animatedProgress = progress } }
```
**Do not** just pass `animatesOnAppear: false` at the hero sites — that flag gates the `.animation` modifier itself, which also drives the `onChange(of: score)` path, so the ring would **snap** instead of animating when the score genuinely changes (on Home, every 30 minutes behind the readiness timer). Also note `.contentTransition(.numericText())` at `:80` does **not** re-run on remount — the Text is created fresh at its final value with no prior value to transition from.

**Expected improvement** — Reclassify as visual correctness. One 104 pt stroked arc is tens of microseconds per frame; this recovers no measurable frames. It removes a visible glitch on the two most-read elements in the app.

**Complexity** Low — **Priority** Medium

---

### S7 — View models constructed inside `navigationDestination` and body closures

**Problem** — A pushed detail screen can be handed a brand-new view model whose state has reset to defaults, and Home allocates a throwaway view model on its first render.

**Root cause** — `ContentView.swift:418-424` (CategoryDetailViewModel), `:426-436` (MetricDetailViewModel), `:547` (WeeklyReviewViewModel), `:557-559` (HealthStateTimelineViewModel) all build inline in destination closures, and ContentView's body invalidates from `:271, :307, :328, :331, :334, :342`. `MetricDetailViewModel.swift:12` `selectedTimeRange` is bound through a custom `Binding` at `MetricDetailView.swift:85-99`, so a re-created VM silently resets the user's 7D/30D/90D choice. Worse: `MetricDetailView.swift:82-95`'s `.onAppear` mutates `viewModel.selectedTimeRange` in a probe loop over `[90, 180, 365]`, so a re-created VM re-runs up to three `chartSamples` windowings and three observed writes. The HomeView half is deterministic: `ensureWeeklyReviewVM()` runs in `.onAppear` (`:106`), which fires *after* the first body evaluation, so `weeklyReviewViewModel` is guaranteed nil on the first pass and the `?? WeeklyReviewViewModel(...)` fallback at `:672` always allocates a throwaway.

**Proposed solution** — Standard `@State`-owning wrapper views per destination. For `HomeView:672`, hoist construction to where `ensureWeeklyReviewVM()` is called and render nothing until it exists.

**Expected improvement** — Effectively zero frame gain — a small class allocation is microseconds. The value is correctness: the range selection surviving an unrelated ContentView invalidation.

**Complexity** Medium — **Priority** Medium

---

### S8 — `MetricDetailViewModel` derived series are unmemoized computed properties read 3-4 times per body pass

**Problem** — Chart series, regression and month comparison are recomputed several times per pass.

**Root cause** — `chartSamples` (`MetricDetailViewModel.swift:40-43`) → `MetricTimeSeries.swift:120-127`, one binary search plus `Array(samples[startIndex...])`, a full copy; read at `MetricDetailView.swift:39, :168, :171, :309, :313, :314, :318, :320, :330, :333`. `trendLineSamples` (`:171-185`) runs a rolling window where `window.map(\.value).reduce(0, +)` allocates a fresh 7-element array per iteration — 359 allocations at the 365-day range. `Calendar.monthSymbols` is hit at `:95, :234, :236`.

**Proposed solution** — Three small things, no cache. Hoist `monthSymbols` to a `static let`. Bind `let chart = viewModel.chartSamples`, `let trend = viewModel.trendLineSamples`, `let forecast = viewModel.forecastSamples` once at the top of `metricDetailBody`. Rewrite the rolling average with a running sum (four lines, strictly better). **Skip the UUID-keyed cache and the `didSet`-backed stored-property conversion** — `trend`, `baseline`, `insights` and `historicalContext` all read through to `AnalysisEngine` and would go stale when a background analysis phase republishes, which a `didSet` on `selectedTimeRange` would never observe.

**Expected improvement** — ~0.3 ms per body pass at the 365-day worst case, well under 0.1 ms at the typical 30-90 day range. Scrub selection is `@State` **inside** `MetricChartView` (`:18`), so this body does **not** rebuild per touch — this is a refresh-path cost, not a frame-path cost.

**Complexity** Low — **Priority** Low

---

### S9 — `primaryActionCard.onAppear` writes root `@State` on every scroll-back

**Root cause** — `HomeView.swift:931-933` assigns `actionDoneToday = DailyActionCompletion.isDoneToday` (`@State` at `:19`). `DailyActionCompletion.swift:15-20` is a `UserDefaults.object(forKey:)` plus `Date.cal.isDateInToday`, 5-20 µs. The write is **idempotent** after the first fire, so SwiftUI's attribute graph likely dedupes it.

**Proposed solution** — Add the one-line guard that the three existing precedents use (`WatchComplicationCard.swift:64`, `MorningCheckInView.swift:111`, `ActivationProgressBanner.swift:29`). **Do not** replace `@State` with a computed property "driven off the `.sensoryFeedback` trigger" — `.sensoryFeedback` is an output, not a state driver, and cannot invalidate anything.

**Expected improvement** — Microseconds. Hygiene only. **Complexity** Low — **Priority** Low

---

### S10 — Live tab's pulse animation lives in the parent's `@State`

**Root cause** — `pulseScale` and `lastAnimationTime` are declared on `LiveView` (`:9, :12, :13`) and written by a child through bindings (`:77, :82, :97, :102, :113-115, :120, :126, :135`); the writer is `LiveHeartRateSection.swift:46-55`. Nothing outside that section reads them.

**Proposed solution** — Move both into `LiveHeartRateSection` as local `@State`, delete both bindings. Swap the `maxScrollDepth` writes for the shipped `ScrollDepthTracker` (`ScrollDepthTracker.swift:10-18`, already adopted at `HomeView.swift:28`) for consistency only — `LiveView` uses a plain `VStack` at `:48`, so those writes fire four times on tab open, not per scroll.

**Expected improvement** — Removes one to two LiveView body passes per second while streaming. **Not** "three per heartbeat to zero": LiveView's body already invalidates on every heart-rate delivery because it reads `viewModel.vitals` directly (`:110-116`), so the floor is one pass per update.

**Complexity** Low — **Priority** Medium

---

## 2.3 Animation

---

### A1 — Onboarding Vitality reveal writes screen-root state ~230 times in 3.7 s just to tick a number

**Root cause** — `OnbV2VitalityReveal.swift:469-479` `tweenAge` loops `duration / 0.016` steps writing `age` (a screen-root `@State` at `:297`, read at `:343`) with a 16 ms `Task.sleep`; `runSequence` (`:481-520`) calls it five times for ~3.7 s.

**Proposed solution** — Two lines: replace the tween body with `withAnimation(.easeOut(duration: duration)) { age = to }` and add `.contentTransition(.numericText(value: age))` on the Text at `:343`. Note `runSequence` reads `age` at `:503` and `:508` (`from: age`). If the exact 0.1-step ticking readout is required, extract a leaf view reusing the existing `OnbV2CountUp` pattern (`OnboardingV2Foundation.swift:575-605`) rather than writing a third copy.

**Expected improvement** — ~200-230 root value-tree rebuilds removed, ~25-70 ms of main-thread work over 3.7 s. **Not** the ~1 ms/pass the original assumed: `OnbV2MetricChip` bodies do **not** re-evaluate (`metrics` is a `let` fixed in `init` at `:261` and `OnbV2Metric` is all String/Double), so the 8 nested GeometryReaders and 3 gradients are never re-run. First-run only.

**Complexity** Low — **Priority** Medium

---

### A2 — Onboarding scan screen rewrites root state at 20 Hz during the HealthKit import

**Root cause** — `OnboardingV2Screens8to13.swift:408` `Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true)` on `.common` (`:429`) writes `progress` and `foundCount` (`@State` at `:175-176`). `progress` is read at `:263` and `:268`, so the whole body rebuilds 20×/s, re-running `foundValues` (five `OnbHealthFormat.duration` calls, `:197-206`), `longestDuration` (`:209-214`) and `s10Status`, which hits Firebase Remote Config plus a `String(format:)` (`Copy+OnboardingV2.swift:119-124`) — while the HealthKit import is running.

**Proposed solution** — **One character:** change `0.05` to `0.1` at `:408`. The progress bar is 4 pt tall and the status text shows an integer percent, so 10 Hz is visually identical and halves the cost. If more is needed, hoist `progress` into a leaf; `foundCount` must stay at the root because `:250`'s `.animation(..., value: foundCount)` drives the row reveal.

**Expected improvement** — Halves root-body invalidations during the import. **Do not** rework the 12 satellite glows at `:325-331` — `.rotationEffect` on the parent (`:333`) is an ancestor transform, so the dots' rasterized shadows are reused for free. The spins are already gated behind `!reduceMotion` (`:394`) and the timer is correctly invalidated in `.onDisappear` (`:278-281`).

**Complexity** Low — **Priority** Medium

---

### A3 — Discovery flow keeps a `repeatForever` pulse alive with no cancellation

**Root cause** — `DiscoveryView.swift:85-91` attaches `.easeInOut(duration: 1.5).repeatForever(autoreverses: true)` to `appeared`, set true once in `.onAppear` (`:48-56`); `.onDisappear` (`:65-71`) only fires analytics. The correct cancel pattern exists in the repo at `VitalityOrganicOrb.swift:82-94`.

**Proposed solution** — Delete the `repeatForever` and make `:86-91` a one-shot `.easeInOut(duration: 0.6)`. Skip the `onChange(of: currentPage)` + Transaction gating — that adds a state machine to cancel an animation you should just delete. Visual change: the circle stops breathing.

**Expected improvement** — No frame recovery (a `scaleEffect` on a solid-fill circle is a free GPU transform). It keeps the display link pinned while the user reads a first-run flow — a battery cost. `thermallyConstrained` (`:15-18, :49-51`) already suppresses it under thermal pressure.

**Complexity** Low — **Priority** Low

---

### A4 — Onboarding count-up schedules a raw 60 Hz run-loop Timer with no cancellation path

**Root cause** — `OnboardingV2Foundation.swift:586-597`: `Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true)` inside `.onAppear`, added to `RunLoop.main` in `.common` (`:596`), with no stored handle and no `.onDisappear` — the chain ends at `:598`. Used on four screens (`OnboardingV2Screens8to13.swift:503, 746, 764, 1051`). It is **bounded**: the tick body self-invalidates at `p >= 1`, so the worst case is ~96 stray ticks over `duration` (1.6 s default, `:564`), not a leak.

**Proposed solution** — Replace with `withAnimation(.easeOut(duration: duration)) { current = target }` plus `.contentTransition(.numericText())`, which deletes the `asyncAfter` block too. If a real ticker is needed, use the shipped `RepeatTimer` (`RepeatTimer.swift:4-19`, has `stop()` and `deinit { stop() }`) with `.onDisappear { ticker.stop() }` — the same shape as the correct sibling at `OnboardingV2Screens8to13.swift:407, 430`. **Do not** use `TimelineView(.animation)` — that runs at display rate, up to twice the wakeups you are removing.

**Expected improvement** — Lifecycle hygiene, no measurable frame cost. First-run only.

**Complexity** Low — **Priority** Low

---

### A5 — Breathwork session: 10 Hz timer, not `@State`, and a `tick()` that counts ticks instead of elapsed time

**Problem** — On the app's meditation screen, the session progress ring advances in visible 10 fps steps, the 776-line body re-evaluates ~2,400-3,000 times per session, and timed sessions run **long**.

**Root cause** — Three defects. (1) `BreathworkView.swift:158` `private var timer = Timer.publish(every: 0.1, ...).autoconnect()` is a plain stored property, not `@State`, sitting directly below thirteen correctly-marked `@State` properties (`:142-154`) — so it is re-created whenever the parent re-renders (`StressMonitorView.swift:457-459`, a NavigationLink destination closure), dropping ticks. (2) `tick()` (`:627-643`) hardcodes `let dt = 0.1` and decrements, so every dropped tick makes the session run long by exactly that amount. (3) Both decremented values are root `@State` (`:137, :138`) read by the active subtree at `:162-166, :389, :398, :421, :447-450`, so every tick rebuilds the whole body — and `phaseCountdownText` shows an integer second, driven at ten times that rate.

**Proposed solution** — Delete the timer.
1. Store `sessionEndDate` and `phaseEndDate`; render both countdowns as `Text(timerInterval: Date.now...phaseEndDate, countsDown: true)`. The system renders this off the main thread at **zero** body passes. The app already uses exactly this API for the same countdown in `BreathworkLiveActivityWidget.swift:138, :256`.
2. Scope a `TimelineView(.animation)` around **only** the progress ring so it glides at display rate instead of stepping — this looks *better* than today and never invalidates the parent.
3. Keep one **one-shot** timer at `phaseEndDate` for phase advancement.
4. Interim one-keyword fix if you are not doing the rewrite today: add `@State` to `:158`. That stops the tick loss but not the drift, which is rooted in the hardcoded `dt`.
5. Add `@Environment(\.accessibilityReduceMotion)` — the breathing circle's scale animation (`:432-448`) is exactly what that setting exists for, and this file does not read it.

**Expected improvement** — ~2,400-3,000 body passes per session down to ~40. Correctness: session length becomes accurate. Visual: the ring glides instead of stepping — on the screen whose entire product promise is smoothness.

**Complexity** Medium — **Priority** Medium

---

## 2.4 Scroll & lists

---

### L1 — `CategoryDetailViewModel.valueForRange` does an uncached linear filter, called twice per row

**Root cause** — `CategoryDetailViewModel.swift:174-185` filters `series.samples` with no cache and no date index, while the same type already offers a binary-searched window. Called twice per row — `CategoryDetailView.swift:303` for the visible text and `:331` for the accessibility label, both inside `ForEach(viewModel.metricsSortedBySeverity)` at `:167`. Its siblings (`trend(for:)`, `weekOverWeekChange`, `numericWeekOverWeekChange`) all route through the memoized `trendResult(for:)` at `:155-170` — this is the only one that was missed. Row counts come from `HealthCategory.swift:74`: Activity 19 metrics, Body 11, Heart 7.

**Proposed solution** — `let inRange = series.samples(from: cutoff, until: .distantFuture)` (`MetricTimeSeries.swift:151-167`) returns an identical set, since the init sorts samples. Add a `[HealthMetric: String]` memo cleared in the `selectedTimeRange` `didSet` alongside the existing `trendCache = nil` at `:19` — that is where invalidation already lives; do not add a second clearing path.

**Expected improvement** — Using the app's own calibration (`DashboardViewModel.swift:2659-2661`, ~0.048 ms per filter over ~365 daily samples): **2-5 ms on Activity, 1-2 ms on Heart** at three years of history, halved by the memo, and the binary search stops it growing with tenure. Note the series are daily-bucketed (`HealthKitManager.swift:809-812`, `interval.day = 1`), so a metric holds ~1,100 samples at three years, not 26k.

**Complexity** Low — **Priority** High

---

### L2 — 24 `ScrollView { VStack }` screens — but the win only lands where sections are separate `View` structs

**Problem** — Detail screens pushed from Today and Biology build and lay out all of their content before the first frame.

**Root cause** — `LazyVStack` defers a child's *body* and layout, never the *construction* of the child value. On screens where each section is a separate View struct it defers the section body — which is why Explore's 2.13 ms figure was real there. But `SleepCoachView.swift:137-141` stacks `heroSection`, `performancePicker`, `scheduleSection`, `debtSection`, `historySection` as **computed properties on the same View**, so calling them happens inside the parent's ViewBuilder regardless of laziness. `StrainDetailView.swift:126-131` and `StressMonitorView` are the same shape; `CategoryDetailView.swift:15` inlines everything. Only three LazyVStacks exist in the whole app: `HomeView.swift:448`, `ExploreView.swift:42`, `CorrelationsView.swift:225`.

**Proposed solution** — Convert **only** screens whose sections are already separate View structs. Realistic list: MetricDetail, CategoryDetail, VitalityDetail, SleepCoach. Drop `ContentView.swift:730` from the list — it is a five-child empty state. On the computed-property screens, extracting sections into structs is the real change; price it as that, not as a `VStack` rename. Two prerequisites: (a) `LazyVStack` takes the full proposed width where `VStack` sizes to its widest child, so `.frame(maxWidth: .infinity)` is compensating for a sizing change, and `BrainHealthDetailView.swift:21-22` already hand-sizes off a GeometryReader — visual check required; (b) fix impression inflation **inside `SectionTracker` itself** first — `SectionTracker.swift:114-119` emits on every `disappeared()`, and `LazyVStack` turns each into one analytics event per scroll-off. MetricDetail has 7 tracker pairs (`:55-138`), CategoryDetail 5 (`:25-190`).

**Expected improvement** — **Unmeasured.** The only real datum is 2.13 ms per pass on Biology, a screen built from separate section structs. On the computed-property screens expect low single-digit milliseconds off the push at best.

**Complexity** Medium — **Priority** High

---

### L3 — `IntradayActivityCard` emits up to 96 `Rectangle` views and re-scans its bucket array inside the render loop

**Root cause** — `IntradayActivityCard.swift:112-121` is `ForEach(Array(buckets.enumerated()), id: \.offset)` producing `Rectangle().fill().frame().offset()` per non-zero bucket, inside a `GeometryReader` at `:96`. `peak` (`:22`) and `total` (`:21`) are computed properties read at `:41, :58, :68, :113, :118, :143`, so `buckets.max()` runs repeatedly. 96 buckets confirmed by `HealthKitManager.swift:648-662` (`bucketMinutes: Int = 15`) and the preview at `:156`. The card's own header comment at `:13-15` says it was built with plain shapes because "the cheapest draw wins"; the repo's batching precedent is documented at `ExploreMonthCalendarSection.swift:300-303`.

**Proposed solution** — Two parts. (a) Hoist: `let peak = self.peak`, `let total = self.total` above the `GeometryReader` — free, zero risk. (b) Replace the tick `ForEach` with a single `Shape` that adds one rect per non-zero bucket and is filled once with `AppColour.accent`. A `Shape` gets its own `rect`, so the `GeometryReader` and its extra layout pass disappear. This is genuinely **pixel-identical**: `tickWidth = max(1, min(2, slot * 0.5))` (`:97-99`) guarantees ticks never overlap and all share one solid colour with no blend mode. Keep the dashed baseline (`:105-109`) as its own stroked Path — it uses `accent.opacity(0.55)` with `Self.dash` — and leave the three gridlines (`:79-93`) alone.

**Expected improvement** — ~96 view identities, ~96 layout entries and ~190 array scans collapse to 1 fill + 1 stroke: ~0.1-0.5 ms per card build. This is a **build-time** cost, not per-frame — the card's only stored property is `let buckets: [Double]`, which is Equatable, so SwiftUI likely already skips it on unrelated Home invalidations. Verify whether `liveViewModel.activity.intradayActiveEnergy` vends a stable array before assuming otherwise. Only renders on days with logged energy (`HomeView.swift:562`).

**Complexity** Low — **Priority** Medium

---

### L4 — Biology month calendar recomputes its 31-date grid three times, re-derives `today` ~70 times, and builds 31 VoiceOver strings unconditionally

**Root cause** — `ExploreMonthCalendarSection.swift:40-53` `cells` is a computed property doing `dateInterval(of: .month)`, `range(of:in:)`, a weekday component and up to 31 `Date.cal.date(byAdding:)` calls. Read at `:60` (`scoredThisMonth`), `:64` (`daysElapsed`) and `:175` (`grid`) — though `:60` and `:64` sit behind `if isViewingCurrentMonth` at `:272-273`, so past months rebuild once, not three times. `today` (`:36`) is a computed `startOfDay(for: Date())` read at `:56, :64, :73-78, :189, :190`. `accessibilityLabel(day:score:contexts:)` (`:247-259`) runs a `DateFormatter.string`, two `Copy.*` lookups and a `joined` for all 31 cells on every grid build; its own comment at `:237-240` admits this happens "whether or not VoiceOver is running".

**Proposed solution** — Three local changes, no rendering-model change. (a) Resolve `cells` and `today` once at the top of `body` and thread them into `grid`, `dayCell`, `scoredThisMonth` and `daysElapsed` — the pattern already used at `VitalityTrendSection.swift:25-26` and `ExploreView.swift:31`. (b) Gate the accessibility label on `UIAccessibility.isVoiceOverRunning`. (c) `[verified this pass]` `.equatable()` **is** already applied at `ExploreView.swift:106` to the section constructed at `:95`, and the `==` at `:29-31` compares `scoresByDay` and `contextsByDay` — so the "×9 passes per refresh" multiplier does not apply and no change is needed there.

**Expected improvement** — ~0.4-0.8 ms of Calendar and DateFormatter work per *calendar* body pass, on a pass the Equatable guard already makes uncommon. **Do not** quote the 88 ms figure at `:21-24` as a current cost — the same file documents the TickArc batching at `:300-303` ("2 strokes per dial instead of 20") that landed after it, and `DesignSystem.swift:225-229` documents the shadow fix that landed after it too.

**Complexity** Low — **Priority** Medium

---

### L5 — Explore's `insightCountsByCategory` runs above the ScrollView

**Root cause** — `ExploreView.swift:29-33` binds it as the first statement of the body, above `ScrollView` at `:34`, so laziness cannot defer it. `:427-437` walks `analysisEngine.insights`, buckets by category, then `mapValues { InsightCoordinator.coordinate($0).count }`. Uncached where its neighbours (`cachedDailyScoresByDay`, `exploreSortedCategories`) are cached.

**Proposed solution** — Add `cachedInsightCountsByCategory` to DashboardViewModel, filled in `updateCachedProperties()` beside `cachedDailyScoresByDay` (`:1151`). Bind `decliningHighlights` (`:415-417`, called at `:257` and `:259`) to a single `let`. **Measure the current property first** — if the residual is tens of microseconds, a third cached map plus its invalidation path is not worth it.

**Expected improvement** — Unknown and strictly **less** than the 0.55 ms in the comment at `:30-32`, which is explicitly the *pre-optimization* per-row cost ("each call ran the whole InsightCoordinator pipeline"). The property's own doc at `:427-429` states the current version is one grouping pass. Multiplying a retired number by nine passes double-counts a shipped fix.

**Complexity** Low — **Priority** Low

---

## 2.5 Main-thread CPU

---

### M1 — Eight health scorers run synchronously inside one unyielding `MainActor.run` block

**Problem** — Pull-to-refresh, cold launch and throttled foreground return freeze the UI for a third to half a second. Scroll stops, the refresh spinner sticks, taps are swallowed. This is the largest single item in the report.

**Root cause** — `DashboardViewModel.swift:801-817` is one `await MainActor.run { … }` with no yield point, calling `computeNewEngines` at `:815` (`@MainActor` at `:1373`), which runs StrainScorer, StrainCoach, StressScorer, BrainHealthScorer, SleepDebtTracker, SleepNeedCalculator, GamificationEngine and VitalityScorer back to back. Main-actor pinning verified: `StrainScorer.swift:171` `@MainActor func compute`, `StrainScorer.swift:398` reaching `store.loadDailyStrainHistory`, `VitalityScorer.swift:392` `MainActor.assumeIsolated { store.loadAllTimeSeries() }`, `HealthDataStore.swift:152-154` `@MainActor @Observable`. The memo at `:1376-1395` gates repeats, but any new sample changes the hash, so a genuine refresh always pays full price. **Frequency correction:** the 120 s timer does *not* reach this — `HomeView.swift:173-178` dispatches to `fetchHomeDataTiered()` or `retrySyncIfNeeded()`, neither of which reaches `refreshCore`, and the RC default is 120 s not 60 (`RemoteConfigManager.swift:625`). Real triggers: pull-to-refresh (`HomeView.swift:97`, `ExploreView.swift:393`, `ContentView.swift:443/715/855`), initial `load()`, and the throttled `refreshOnForegroundIfNeeded()` at `ContentView.swift:265`.

**Proposed solution** — This is **not** a hoist-reads-then-fan-out refactor, and the naive version crashes. The scorers are not pure: `StressScorer.swift:173` and `VitalityScorer.swift:392` call `MainActor.assumeIsolated { store.loadAllTimeSeries() }` from inside `compute` (these **trap**, not degrade, off main), and they *write* to the store mid-compute — `StrainScorer.swift:257` `store.saveDailyStrain(...)`, `:414` `store.loadDailyStrainHistory(...)`, `VitalityScorer.swift:838-840` `saveVitalityAge` + `loadVitalityAgeHistory`. Each scorer must be individually converted to take plain `Sendable` inputs and return a `Sendable` result, with **all** store reads and writes lifted to the call site. There are also real ordering dependencies inside `computeNewEngines` (strainCoach consumes `strainScorer.currentStrain`; sleepNeedCalculator consumes `sleepDebtTracker.currentDebt`), and the scorers are themselves `@Observable` objects whose properties drive the UI — so the off-main version must compute into local values **in the same order** and write the observable objects only in one final main-actor batch. Writing them from the detached task moves the hang into a cross-thread publish. **Do not** parallelise with a TaskGroup until the scorers are actually pure — the interleaved store writes make concurrent execution unsafe today.

**Expected improvement** — Removes ~300-500 ms of main-thread block from launch, pull-to-refresh and throttled foreground return. **That figure is the team's own code comment at `DashboardViewModel.swift:1376-1377`, not an independent measurement.** Signpost it before committing to a multi-day refactor — that is a ten-minute job.

**Complexity** High — **Priority** Critical

---

### M2 — A **second** `MainActor.run` block in the same refresh, never previously audited

**Problem** — A second hitch immediately after M1. Today freezes twice per refresh, not once.

**Root cause** — `DashboardViewModel.swift:820-831`:
```swift
await MainActor.run {
    invalidateDailyActionCache()
    if !shouldReuseThermalSnapshot {
        refreshIntelligenceBriefing()     // :2221-2234 — takes the whole timeSeries
        refreshHealthForecasts()          // :2743-2748
        refreshCircadianBiomarkers()      // :2782-2790 — see M3
        checkActivationMilestones()
    }
    writeWidgetSnapshots()                // :2313-2353
    pushTodayScoreLiveActivity()          // :2410-2445
}
```
`writeWidgetSnapshots()` additionally constructs a fresh `ReadinessStore()` at `:2320`, decodes `DailyActionStore.today()` at `:2346`, then runs five `saveXIfChanged` compares in `WidgetDataStore.swift:219-241` — each a `JSONDecoder().decode` (`:216-218`) plus a `JSONEncoder().encode` (`:210-213`) — then `WidgetCenter.shared.reloadAllTimelines()` (`:237`). `pushTodayScoreLiveActivity()` makes three **synchronous** ActivityKit daemon queries before doing anything useful (`TodayScoreLiveActivityManager.swift:52, :66, :101`) plus one 8-key analytics event on either branch (`:108-119` / `:133-144`).

**Proposed solution** — Nothing in this block needs the main actor except four `@Observable` assignments. Compute off-actor, assign on-actor, using the shape the same file already uses at `:792`:
```swift
let briefing  = await Task.detached(priority: .utility) { … generateBriefing(…) }.value
let forecasts = await Task.detached(priority: .utility) { ForecastBuilder.buildForecasts(…) }.value
let circadian = await Task.detached(priority: .utility) { CircadianHealthAnalyzer.computeBiomarkers(from: ctx) }.value
await MainActor.run {                      // now microseconds
    intelligenceBriefing = briefing
    healthForecasts      = forecasts
    circadianBiomarkers  = circadian
    checkActivationMilestones()
}
```
`writeWidgetSnapshots()` should not be on the main actor at all — it only reads computed values and writes to an App Group; the snapshot structs are Codable value types, and `reloadAllTimelines()` is thread-safe. `pushTodayScoreLiveActivity()` should build its `ContentState` on main and hand the value to a detached task; `Activity.update` is already inside a `Task` (`TodayScoreLiveActivityManager.swift:103-105`) — it is the three *reads* before it that block.

**Expected improvement** — Best guess **15-40 ms per refresh**, dominated by `generateBriefing` plus M3 plus five JSON round-trips; the ActivityKit reads are XPC-backed and are the wildcard. This block runs immediately after M1, so the two stalls concatenate into one visible freeze.

**Complexity** Medium — **Priority** High

---

### M3 — `CircadianHealthAnalyzer` scans the full 10-year daily step series on the main actor, with a `Calendar.component()` per sample

**Root cause** — `CircadianHealthAnalyzer.swift:146-188` sorts the whole unwindowed steps series (up to ~3,650 daily samples after the 10-year backfill at `HealthKitManager.swift:365`), allocates three copies, sorts twice, then walks every element calling `calendar.component(.weekday, from: samples[i].date)` — one of the most expensive Calendar operations there is. Called synchronously from the M2 block via `DashboardViewModel.swift:2782-2790`. No lookback window anywhere in the function.

**Proposed solution** — Both halves.
```swift
let cutoff = Date().daysAgo(90)
let samples = stepsSeries.samples.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
```
Relative amplitude, interdaily stability and intradaily variability are 30-90 day constructs — a decade of history does not make them more accurate, it makes them less responsive. Then detach: `computeBiomarkers` is a `static func` over value types with no actor state, so it is already safe to call anywhere. If any long window is kept, hoist the weekday out of the loop — the samples are consecutive daily buckets, so compute the first weekday once and use `(first + i) % 7`.

**Expected improvement** — 5-15 ms of main-thread stall per refresh removed (three array copies + two sorts ≈ 2-4 ms, plus 3,650 × `Calendar.component` at 0.5-2 µs ≈ 2-7 ms). Against a 16.7 ms budget that is one guaranteed dropped frame per refresh.

**Complexity** Low — **Priority** High

---

### M4 — LiveViewModel fires up to 16 separate `Task { @MainActor }` writes per home fetch

**Root cause** — `LiveViewModel.swift:213-223` fans out to ten fetch helpers. `:601-636` spawns **six** `Task { @MainActor in self?.activity.todayX = v; self?.finishCumulativeStatsFetch() }` blocks; `:723-738` spawns two more that **each** call `computeReadinessScore()`. `finishCumulativeStatsFetch` (`:645-651`) only decrements a counter — it batches nothing.

**Proposed solution** — Simpler than a new accumulator actor, since the class is already `@MainActor` (`:9`). Have each cumulative-stat callback write into an `@ObservationIgnored` backing field, and publish all six in one assignment from `finishCumulativeStatsFetch()` when `pendingCumulativeStatsCallbacks` hits 0 — that counter already exists at `:637-652` and needs no new synchronisation. Gate `computeReadinessScore()` on both recovery callbacks landing rather than running it twice.

**Expected improvement** — Collapses the cumulative burst from six publishes to one and the recovery pair from two to one. **Not 16-to-1:** state is already split into independently observable sub-objects (`:6-8`), and the main-actor executor drains all available jobs before yielding, so HealthKit callbacks landing within milliseconds already coalesce — realistic is ~4-7 passes down to 2-3. The user-visible win is that tiles fill together instead of popping in one at a time.

**Complexity** Low — **Priority** Medium

---

### M5 — Every RC-backed `AppColour` token does a Firebase lock, string work and a fresh `UIColor` on every read — 186 read sites

**Problem** — Reading a colour token looks like reading a constant. It is not, and the fresh `UIColor` breaks SwiftUI's value-diffing early-out on every view that stores a `Color`.

**Root cause** — `AppColour.swift` declares 25 `static var` RC-backed tokens; `remote()` at `:51-58` calls `RemoteConfigManager.shared.color(forKey:)` → `RemoteConfigSchema.swift:355-358` (`let hex = string(forKey: key) ?? ""; return Color(hex: hex)`, **no cache**) → `RemoteConfigManager.swift:490-494` → `:157-160` `remoteConfig?.configValue(forKey: key).stringValue`, where the `remoteConfig` getter takes an `NSLock` on every call (`:31-38`). None of the `color_*` keys ship a default (comment at `AppColour.swift:44-48`), so `Color(hex:)` fails its length guard at `RemoteConfigKeys.swift:269-273` and falls back to `dynamic(light:dark:)` at `AppColour.swift:33-35`, which **mints a brand-new closure-backed `UIColor` per call**. The `cachedCopy` fix for strings exists at `RemoteConfigManager.swift:130-155` with a comment describing this exact cost (`:95-105`) — the colour path bypasses it. Read-site count independently verified at **186**. Amplifiers: `DayScoreDial.swift:33` resolves one per dial and `ExploreMonthCalendarSection.swift:207` draws one dial per day cell; `DesignSystem.swift:154-160` `DS.scoreColor`; `HealthCategory.swift:46-56`.

**Proposed solution** — Two independent changes.
1. Add `colorCache: [String: Color?]` mirroring `cachedCopy` — same `NSLock`, same `configGeneration` token, invalidated by the same `invalidateCopyCache()`. **Critical detail the obvious implementation gets wrong:** `observeFetchUpdates()` (`:88-91`) must still run on every colour read *even on a cache hit*. That `MainActor.assumeIsolated { _ = lastFetchTime }` is the SwiftUI dependency edge — cache the resolution, not the observation, or a published colour change silently stops repainting.
2. Memoize the `dynamic(light:dark:)` fallback keyed on the (light, dark) pair so a token returns one shared `UIColor` instance. This is the half that actually restores `Color` equality between renders and lets child views that store a `let color: Color` early-out of diffing.

**Expected improvement** — ~1-4 µs per read → a dictionary hit. At ~60-100 reads per Biology body pass, ~0.1-0.4 ms/pass. The **stronger** value is identity, not cost: the memoized UIColor restores the diffing early-out across the whole app. Fixing this also makes the frozen globals at `VitalityDetailHelpers.swift:3-5` removable (`let vitalityWhoopGreen = AppColour.vitalityWhoopGreen` etc. are file-scope, lazily initialised once, so a later RC activation never repaints them — a live correctness bug).

**Complexity** Low — **Priority** High

---

### M6 — `copyArray` is the one Remote Config path with no cache, and Home's Ask card hits it plus `Calendar.ordinality` per pass

**Root cause** — `RemoteConfigManager.swift:514-526` `copyString` is cached; `copyArray` directly beneath it at `:531-547` is not — every read does a Firestore-override probe, a Firebase `configValue`, a UTF-8 conversion, a **freshly allocated `JSONDecoder`** and a decode. Hot site: `ActivationProgressBanner.swift:168-173` `samplePrompt` reads `Copy.Home.AskYourData.conciergePrompts` **and** calls `Date.cal.ordinality(of: .day, in: .year, for: Date())`, read from the card body at `:184`. Second site: `AskYourDataView.swift:14` `private let suggestedQuestions = Copy.Home.AskYourData.suggestedQuestions` — a stored property with an initializer on a `View` struct runs on **every construction**, i.e. every parent body pass.

**Proposed solution** — Give `copyArray` a dedicated `[String: [String]]` cache sharing the existing `copyCacheLock` and `copyCacheToken` (`:113-118`). Make `samplePrompt` a `private static let` — it changes once a day, and the comment at `:167` already states the intent is "shifts daily without flickering within a session", which a static gives you and a per-pass computation does not. Same for `AskYourDataView.swift:14`.

**Expected improvement** — ~50-100 µs per Home body pass. Not a dropped frame on its own; it is a fixed tax on an already-excessive pass count and a five-line fix.

**Complexity** Low — **Priority** Medium

---

### M7 — CategoryDetail runs the insight coordinator three times per body pass

**Root cause** — `CategoryDetailView.swift:92, :94, :95` read `viewModel.insights` three times in adjacent lines; `CategoryDetailViewModel.swift:31-33` is a plain computed var with no memo, while `trendCache` at `:11-16` shows the memo pattern was applied to trends and skipped here.

**Proposed solution** — One line: `let insights = viewModel.insights` at the top of `body`, used for all three reads — the pattern `ExploreView.swift:29-33` already uses. **Skip** the `@ObservationIgnored insightCache` and the pre-lowercasing on `Insight`: `InsightCoordinator.swift:7` caps at `maxInsights = 15`, `:13-18` only calls `inferDirective` when `copy.directive == .informational`, and `:35-45` has category fast paths that return before the `lowercased()` calls at `:51-52`.

**Expected improvement** — Two of three pipeline runs removed, each tens of microseconds. Worth doing because the fix is one line. Also correct the framing: bodies re-evaluate on state change, **not** per rendered frame — scrolling a ScrollView does not re-run the body.

**Complexity** Low — **Priority** Low

---

### M8 — All analytics runs synchronously on the main actor, including section-view events fired by LazyVStack scroll-off

**Root cause** — `AppAnalytics.swift:380-386` is `@MainActor`. `logEvent` (`:3717`) builds ~14 global properties inline (`:3726-3765`) then runs `sanitizeParameters` (`:3766`), which calls `sanitizeEventName` per key (`:3536-3540`) — and that function (`:3465-3476`) does a `.lowercased()`, a per-character `.map` allocating a `[Character]`, a `String(...)` rebuild and a `trimmingCharacters`. Roughly 3 String allocations plus one Character array per key, ~20 keys per event, 157 `logEvent(` call sites in that file. Four methods block on `queue.sync` (`:852, :974, :1090, :1121`), two of which fire on every screen appear/disappear. The scroll-time trigger is `SectionTracker.swift:114-119` — Home, Explore and CategoryDetail hold 5-7 trackers each, and a section scrolling off a LazyVStack fires one synchronous event mid-gesture. Worst burst: `LiveView.swift:146-164`, ten synchronous events during the 320 ms tab cross-fade.

**Proposed solution** — Four steps, cheapest first. (1) Memoize `sanitizeEventName` in a `[String: String]` — names come from a closed set of literals, so it recomputes the same answers forever. (2) Change the four `queue.sync` to `queue.async` — nothing reads the result synchronously. (3) Make `logEvent` capture the raw dictionary and do enrichment + sanitisation + `provider.capture` inside a `Task.detached(priority: .utility)`; the parameter dictionaries are value types and caller signatures are unchanged. (4) Buffer `SectionTracker.disappeared()` events and flush on a debounce or on screen exit rather than one synchronous event per lazy-stack recycle.

**Expected improvement** — Order 50-150 µs per event. A scroll down and back on Home fires ~a dozen section events, so ~0.6-2 ms of scroll-time main-thread work. Rank this **below** every render and refresh finding; items 1 and 2 are near-zero-risk and can ride along with any other analytics change.

**Complexity** Medium — **Priority** Low

---

## 2.6 Startup

---

### ST1 — The branded splash is held up by a StoreKit network round-trip with an 8-second ceiling

**Problem** — After the launch screen the user stares at an icon and spinner for a variable 0.3-8 s while the real UI is already rendered underneath. The delay scales with network quality, not device speed.

**Root cause** — `showSplash` is `@State` at `LasoApp.swift:12`, rendered at `:122-126`, and cleared **only** at `:139-141`, after `await container.startupCoordinator.runInitialSetup(...)` at `:133-136`. `AppStartupCoordinator.swift:32` starts `async let subscriptionTask: Void = subscriptionManager.configure()` and `:41` blocks on `_ = await subscriptionTask`. `SubscriptionManager.configure()` (`:136-146`) serially awaits `processUnfinishedTransactions()` (`:152-157`), `loadProducts()` (`:173-175`, `Product.products(for:)` inside `Self.withTimeout(seconds: 8)`) and `refreshStatus()` (`:345`). CloudKit is free (`CloudBackupManager.swift:23`, `container: CKContainer? = nil`). After the StoreKit await the splash still waits on `WatchMonitor.configure` + `startMonitoring` (`:46-47`) and `pruneExpiredDataIfNeeded` (`:52`, body `:55-61`). Nothing rendered by `splashView` (`LasoApp.swift:169-185` — a colour, an image and a `ProgressView`) reads any StoreKit state.

**Proposed solution** — Fire-and-forget the setup and drop the splash immediately (or on a short `Task.sleep` ceiling):
```swift
Task.detached(priority: .utility) { await container.startupCoordinator.runInitialSetup(...) }
// dismiss splash here
```
**Verified safe:** `SubscriptionManager.status` defaults to `.unknown` (`:22`) and `shouldEnforcePaywall` returns true only for `.expired` (`:48-51`), so `LasoApp.shouldShowPaywall` (`:22-28`) is false while status is unknown — dropping the splash early **cannot** flash the paywall, and it re-evaluates on its own when `refreshStatus` writes the real status. Keep the awaited ordering inside `runInitialSetup` (`processUnfinishedTransactions` before `refreshStatus`, per the comment at `SubscriptionManager.swift:137-141`) — the fire-and-forget move preserves it. Do **not** additionally split `configure()` to make `loadProducts` lazy; once the splash is off that path it is off the launch path entirely, and splitting risks a blank paywall on first present.

**Expected improvement** — **Removes 300-1500 ms of visible splash on a normal connection, up to 8 s on a degraded one.** Time-to-content becomes the ContentView first paint, which is separately taxed by ST2/ST3.

**Complexity** Low — **Priority** Critical

---

### ST2 — `ContentView.init` runs an unbounded whole-table SwiftData fetch and four scorer computes on the main thread, before the first frame

**Problem** — The first SwiftUI body evaluation blocks while the app materializes its entire on-device health history on the main thread. The cost grows without bound with account age.

**Root cause** — `ContentView.swift:29` `_dashboardViewModel = State(wrappedValue: container.dashboardViewModel)` forces the `lazy var` at `AppContainer.swift:90-99`, and `ContentView(container:)` is constructed inside `LasoApp`'s body at `:82`. `DashboardViewModel.init` ends with `rebuildMetricTiles()` (`:487`) and `prewarmScorersFromStoreIfNeeded()` (`:493`). That method's guard at `:513` is effectively always true on cold launch — its own comment at `:507-512` says "Brain + Stress have no on-disk snapshot today … so always run them on launch when missing" — and it calls `brainHealthScorer.compute(from: store, timeSeries: nil)` (`:516`) and `stressScorer.compute(...)` (`:519`), each falling through to `store.loadAllTimeSeries()` (`BrainHealthScorer.swift:288`, `StressScorer.swift:174`, `StrainScorer.swift:184`, `VitalityScorer.swift:393`). `HealthDataStore.loadAllTimeSeries()` (`:300-333`) builds `FetchDescriptor<StoredDailySample>()` with **no predicate and no fetchLimit**, sorts by date, materializes every row, groups by metric and rebuilds a `MetricTimeSeries` per metric (each re-sorting, outlier-filtering and day-bucketing its slice, `MetricTimeSeries.swift:13-71`). All synchronous on main, inside `View.init`, before `body`. The table is explicitly never pruned (`RemoteConfigManager.swift:627`, `"retention_daily_sample_days": 0` — "No pruning — days counter must grow unbounded"). The repo's own note at `MetricTimeSeries.swift:56-60`: "at ~26k samples on a cold load this loop was the single largest main-actor cost in the store."

**Proposed solution** — In cost/benefit order.
1. **Do this first.** Add `loadRecentTimeSeries(days:)` with a `#Predicate { $0.date >= cutoff }` and use it for the prewarm. 365 days covers every scorer window in the repo. Answer the Explore "days of data" counter from `oldestDataDate` (`HealthDataStore.swift:728-732`, already `fetchLimit = 1`) rather than by loading rows — and note `computeNewEngines` feeds `analysis.dataDepth` from `series.values.map(\.daysOfData).max()` (`:1227-1231`), which gates the Explore Health State section at `ExploreView.swift:177` (`daysOfData >= 30`), so that reading must move to a stored install date **before** you bound the window or you will silently hide sections.
2. Only then consider a `@ModelActor` reader. It is a large refactor of a `@MainActor @Observable` type that ~30 call sites read synchronously, and it is **not required** to remove the launch stall.
3. **Do not** simply defer the prewarm to a `.task`. `rebuildMetricTiles()` runs at `:487`, *before* the prewarm, and the prewarm's own `rebuildMetricTiles()` at `:538` is what fills in Brain and Stress — so deferring ships a first frame with Vitality/Strain but no Brain/Stress tiles, which then pop in. That is exactly the pop-in the doc comment at `:496-502` says the prewarm exists to prevent. If you defer, render explicit placeholder tiles.

**Expected improvement** — Plausibly **100-300 ms** of main-thread time on the ~26k rows the repo's own comment cites; treat 150-400 ms as an unmeasured upper estimate. The **certain** win is capping unbounded growth on a table that is never pruned.

**Complexity** Medium (bound the fetch) / High (ModelActor) — **Priority** Critical

---

### ST3 — The startup coordinator unconditionally nukes the time-series cache, forcing a second whole-table fetch on every launch

**Problem** — ST2's expensive materialization happens a **second** time on every cold launch, because the cache is invalidated even when nothing was pruned.

**Root cause** — `AppStartupCoordinator.swift:55-61` calls `DataRetentionManager().pruneIfNeeded(context:)` then `store.invalidateTimeSeriesCache()` **unconditionally**. `pruneIfNeeded` returns `Void`, early-returns when it already ran today (`DataRetentionManager.swift:14-19`), computes `totalPruned` and **discards it** (`:31-45`), and `cutoffDate` returns nil for `days <= 0` (`:57-60`) so `pruneStoredDailySample` is a no-op at the shipped default of 0 (`RemoteConfigManager.swift:627`). `invalidateTimeSeriesCache()` clears both tiers (`HealthDataStore.swift:222-225`), and `loadAndSync`'s first statement is `if timeSeries.isEmpty { timeSeries = store.loadAllTimeSeries() }` (`HealthKitManager.swift:274-277`). Runs from `LasoApp.swift:133` while the splash is up.

**Proposed solution** — **One line, and it is the whole fix.** Make it `@discardableResult func pruneIfNeeded(context:) -> Int` returning `totalPruned` (already computed at `:47`), then:
```swift
if DataRetentionManager().pruneIfNeeded(context: retentionContext) > 0 { store.invalidateTimeSeriesCache() }
```
Stop there. Per-model invalidation buys nothing once the count guard is in, and moving prune to a detached task is a separate change that should not ride along with a one-line correctness fix.

**Expected improvement** — Removes one duplicate full-table main-thread fetch per cold launch. Its size is whatever ST2's fetch costs — **do not add the two estimates independently.** On the default config nothing is ever pruned, so the invalidation is pure waste on 100 % of launches.

**Complexity** Low — **Priority** Critical

---

### ST4 — Every cold launch forces the full "onboarding calibration" ML pipeline, not just the first one

**Root cause** — `ContentView.swift:136-137` computes `needsFullCalibration` from `dashboardViewModel.lastRefresh == nil || healthKitManager.timeSeries.isEmpty`. Both are **process-lifetime only**: `DashboardViewModel.swift:286-288` proxies `healthKitManager.lastRefresh`, and `HealthKitManager.swift:35-36` declares both as plain stored properties never restored from disk before that line runs. So it is true on **every** cold launch. It is passed as both `awaitDeferredAnalysis` and `forceHeavyDeferred` (`:138-141`), defeating two throttles: `refresh(awaitDeferredAnalysis: true)` skips the 500 ms debounce (`DashboardViewModel.swift:699-706`), and `runDeferredHeavy(force: true)` skips the TTL guard `guard force || needsHeavyAnalysis` (`AnalysisEngine.swift:307`). The serial chain at `DashboardViewModel.swift:850-886` then runs cycle flow → deferred essentials → deferred heavy → post-heavy → ML phase. The only exemption is `ContentView.swift:124-126`, which covers the single launch right after onboarding.

**Proposed solution** — Gate on persisted freshness, which already exists: `AnalysisEngine.lastAnalysis` is restored from disk in `init` (`AnalysisEngine.swift:166`, declared `:19`). **Snapshot it into a local `let` first** — it is a tracked property on an `@Observable` class, and reading it directly inside `ContentView`'s `.task` body would register an observation dependency and re-render ContentView on every analysis write. Then drop `forceHeavyDeferred` from the launch call so the 1-hour TTL does its job. Stated tradeoff: dropping `awaitDeferredAnalysis` also re-enables the 500 ms debounce at `:713`, so first-data-on-screen is 500 ms **later** on the normal path.

**Expected improvement** — Stops a full correlations + causal-chain + historical + 20-engine ML pass being redone on every cold launch that the existing TTL would skip. **Correct the mechanism:** every heavy phase already runs in `Task.detached` (`:852`, `:862`) off the main actor, so this is CPU/thermal contention and battery, not a main-thread block. The one real functional cost is that `ui.hasCompletedInitialLoad = true` is not reached until `:605`, i.e. after the entire chain, which keeps `refreshOnForegroundIfNeeded` (`:656`), the HealthKit reprompt check (`ContentView.swift:155-161`) and the PMF/renewal sheets (`:182-190`) blocked for the whole duration.

**Complexity** Medium — **Priority** High

---

### ST5 — First-launch refresh replays up to **fourteen** full analysis passes on the main thread

**Root cause** — `backfillScoreHistoryIfNeeded()` is called at `DashboardViewModel.swift:812`, inside the same unyielding `MainActor.run` block as M1. The loop at `:1883` is `for offset in 1...WeeklyScoreSmoothing.windowDays`, and `windowDays` is **14** (`:18`), not 7 — so it is up to fourteen `AnalysisEngine.replay` calls plus fourteen `saveBackfillSnapshot` writes, inline on main. `AnalysisEngine.replay` (`:416-475`) slices every metric's full series (`:425-428`), computes a baseline per metric (`:430-435`), detects an anomaly per metric (`:437-445`), then iterates `HealthMetric.allCases` and `HealthCategory.allCases` (`:450-461`) and computes adaptive weights — the same shape of work the team deliberately pushed to `Task.detached` for `runCoreAnalysis`. Steady state is guarded: `:1876` `if history.count >= WeeklyScoreSmoothing.windowDays { return }`.

**Proposed solution** — Easy: `AnalysisEngine.replay` is already `static` and takes only value types. Hoist the whole loop into `Task.detached(priority: .utility)`, collect `[(date, overallScore, categoryScores, baselines)]`, then hop to main once for the fourteen writes followed by a single `invalidateScoreHistoryCache()`. Keep the ordering guarantee (await the task before the deferred phases) — the Explore EWMA reads score history.

**Expected improvement** — Removes up to fourteen full replay passes from the main thread on first launch and on any account with under two weeks of stored snapshots. Zero cost in steady state.

**Complexity** Low — **Priority** High

---

### ST6 — Third-party SDK bootstrap in `didFinishLaunching`

**Root cause** — `AppDelegate.swift:15-18` runs the Facebook launch hook as the first statement, then `:20` calls `launchCoordinator.configureOnLaunch()` synchronously. `AppLaunchCoordinator.swift:22-24` `FirebaseApp.configure()` (7 products, `project.yml:36-52`); `:27-33` `Auth.auth().currentUser` (keychain + on-disk session) plus `signInAnonymously`; `:37` `PushNotificationManager.shared.configure()`; `:58` `CopyOverridesStore.shared.start()`; `:60-61` `analyticsManager.configure()` and `installCrashHandlers()`. Only the RC fetch (`:39-41`) and the notification-auth prime (`:46-53`) are already wrapped in `Task`. `CopyOverridesStore.swift:61-73` attaches a Firestore snapshot listener whose callback decodes a ~1,500-key document (`:25`) and bumps `revision` (`:71`), which feeds the copy-cache token at `RemoteConfigManager.swift:131` and therefore **drops every resolved string** mid-launch. `AmplitudeProvider.swift:238` `guard amplitude != nil else { return }` means crash handlers are hostage to the Amplitude bootstrap.

**Proposed solution** — Narrow, and two of the obvious moves are unsafe.
- **Defer:** `CopyOverridesStore.shared.start()` → a post-first-frame `Task.detached(priority: .utility)` alongside the existing detached `AppIntegrityGuard` task at `LasoApp.swift:132`. It is idempotent by design (`listener?.remove()` at `:63`), English literals are baked into `Common/Copy/Copy+*.swift`, and the resolution order at `CopyOverridesStore.swift:11-14` falls through to them.
- **Defer:** `analyticsManager.configure()` — `AmplitudeProvider.swift:54-61` explicitly buffers pre-configure errors, so late configuration is a designed-for case. Also split `installCrashHandlers` so the persistence half (which needs nothing) is not gated on `guard amplitude != nil`.
- **Defer:** the `Auth.auth().currentUser` keychain read.
- **KEEP synchronous:** `FirebaseApp.configure()` and `installCrashHandlers()`.
- **DO NOT MOVE** the Facebook `didFinishLaunchingWithOptions` hook — Meta's SDK requires it there for SKAdNetwork registration, AEM/ATT setup and deferred app-link attribution. `application(_:open:)` at `AppDelegate.swift:71-82` only covers direct URL opens. Deferring it silently breaks paid-acquisition attribution with no crash to tell you.
- **DO NOT DEFER** `PushNotificationManager.shared.configure()` without checking the FCM delegate binding — the comment at `AppLaunchCoordinator.swift:35-36` says swizzling maps the APNS token into `Messaging` automatically, and the token callback can arrive before a deferred Task runs.

**Expected improvement** — Real but **unmeasured and modest**; the two most expensive synchronous items and the attribution-critical one all stay. What genuinely moves off the critical window is Firestore's background init contention plus the main-queue snapshot callback that decodes ~300 KB and drops the copy cache. Signpost `configureOnLaunch` before quoting a number.

**Complexity** Low — **Priority** Medium

---

### ST7 — `AppContainer.init` builds everything eagerly, and a duplicate `PersistenceManager` runs the encrypted-store migration twice per launch

**Root cause** — `LasoApp.swift:61-68` builds `AppContainer()` in `init`; `AppContainer.swift:31` `persistenceManager = PersistenceManager()`, `:35` `analysisEngine = AnalysisEngine()`, `:38-43` the 11-type `ModelContainer` open, `:51-55` five singleton touches, `:65` `PhoneWatchSession.shared.activate`. `PersistenceManager.swift:41-45` `init` runs `startCloudSync()` + `migratePlaintextData()` + `migrateCriticalAlertsDefault()`, looping six encrypted keys (`:26-33, :55-59`). `AnalysisEngine.swift:6` declares a **second** `private let persistence = PersistenceManager()` — so the migration and the iCloud KVS observer registration run twice per launch. `AnalysisEngine.swift:161` also constructs `MLOrchestrator()`, which eagerly builds 20 engines (`MLOrchestrator.swift:13-41`).

**Proposed solution** — Inject the single `PersistenceManager` into `AnalysisEngine` (change `:6` to an injected `let`, pass from `AppContainer.swift:35`), and guard `migratePlaintextData()` behind a version flag the way `migrateCriticalAlertsDefault()` already is (`PersistenceManager.swift:65-67`). The duplicate `NotificationCenter` observer from `startCloudSync()` (`:85-94`) is the more meaningful of the two. **Making `analysisEngine` a `lazy var` defers nothing** — `AppContainer.dashboardViewModel` (`:90-99`) takes it as a constructor argument and `ContentView.init` forces that pre-first-frame. To actually defer the 20 engines, make `mlOrchestrator` lazy inside `AnalysisEngine` (`:161`) — but check `currentHealthState` (`:162`) and `ContentView.swift:558/:582` first. The `ModelContainer` open must stay eager.

**Expected improvement** — Low single-digit milliseconds. The keychain cost is **not** what it looks like: `EncryptedStore.swift:138-142` caches the `SymmetricKey` on the shared singleton, so exactly one Keychain read happens per process, and each `migrateIfNeeded` (`:65-78`) is a UserDefaults read plus one AES-GCM open on a small blob.

**Complexity** Low — **Priority** Low

---

### ST8 — Remote Config activation adds an extra root body-evaluation cascade mid-launch and drops the whole copy cache

**Root cause** — `LasoApp.body` reads `remoteConfig.requiresForceUpdate` (`:77`) and `killSwitchEnabled` (`:79`); those resolve through `boolValue` (`RemoteConfigManager.swift:172`) whose first statement is `observeFetchUpdates()` (`:88-91`), which deliberately touches the tracked `lastFetchTime` to register the SwiftUI dependency. `fetchAndActivate` (kicked off during launch from `AppLaunchCoordinator.swift:39-41`) writes `invalidateCopyCache()` (`:201`) and `lastFetchTime = Date()` (`:202`); the realtime listener repeats both (`:234-235`). `invalidateCopyCache` (`:122-127`) bumps `configGeneration` and clears `copyCache` wholesale.

**Proposed solution** — Resolve the two blocking flags into `@State` on `LasoApp` refreshed via `.onChange(of: remoteConfig.lastFetchTime)`, or put them behind a two-Bool `@Observable` gate that only writes on an actual value change. **Do not** attempt "value-aware cache invalidation" — Firebase gives an activation status, not a payload diff, so "only invalidate when the payload differs" means hashing every resolved key on every activation. If you want a cheap 80 %, gate on `.successUsingPreFetchedData`.

**Expected improvement** — One extra full body-evaluation cascade plus one cold copy-cache refill per launch, and the same pair on every realtime config push. Extrapolating from the team's own figures (Home 0.34 ms, Explore 2.13 ms per pass, `DashboardViewModel.swift:80-85`) that is single-digit to low-double-digit ms — **nobody traced it.** Note this is body *re-evaluation*, not teardown: `AppContainer.swift:82-89` already documents that ContentView is reconstructed at least once per launch anyway and made the view models `lazy` for that reason.

**Complexity** Low — **Priority** Medium

---

### ST9 — Home's loading gate depends on whether work is running, not on whether there is anything to show

**Root cause** — `HomeView.swift:44` `if viewModel.ui.isLoading && viewModel.healthKitManager.timeSeries.isEmpty`. `ui.isLoading = true` at `DashboardViewModel.swift:563`; `timeSeries` is hydrated by `HealthKitManager.swift:275-277`, the first statement of `loadAndSync`, reached only after `await healthKitManager.requestAuthorization()` at `DashboardViewModel.swift:581`. Meanwhile `cachedMetricTiles` (`:413`) is already populated by `rebuildMetricTiles()` in `init` (`:487`).

**Proposed solution** — Ship this **with** ST1, not standalone — today the splash covers it entirely, so it is a consequence of fixing ST1, not an independent regression. Gate on `cachedMetricTiles.isEmpty` plus the existing `ui.isFirstLaunchSync` branch. Avoid `overallScore.score == 0` as a sentinel — a genuine zero is representable. Name the product decision: a returning user sees slightly stale numbers instead of a loading screen (standard stale-while-revalidate), so keep an inline refresh affordance. Hoisting `store.loadAllTimeSeries()` out of `loadAndSync` into the prewarm is a genuine simplification — do it **together with ST2** or the hoist just relocates an unbounded scan. **Skip** caching the read-type `Set<HKObjectType>` — tens of microseconds. Also correct the retry claim: `requestAuthorization` early-returns at `HealthKitManager.swift:181-188` when status is `.unnecessary` (the normal returning-user path); the ~2 s retry ladder (`:232-240`) only runs on a genuine first grant.

**Expected improvement** — Zero on the current build. After ST1: removes a full-screen loader-in/loader-out swap on every cold launch.

**Complexity** Low — **Priority** Low

---

### ST10 — 13 embedded dynamic frameworks including the full gRPC/BoringSSL/absl C++ stack

**Root cause** — `[reproduced]` `ls .../Laso.app/Frameworks` returns exactly 13: absl, AmplitudeCore, FBAEMKit, FBSDKCoreKit, FBSDKCoreKit_Basics, FirebaseAnalytics, FirebaseFirestoreInternal, GoogleAdsOnDeviceConversion, GoogleAppMeasurement, GoogleAppMeasurementIdentitySupport, grpc, grpcpp, openssl_grpc. `project.yml:19-31` declares four packages, `:36-58` ten products. The target's `settings.base` (`:104-121`) contains no static-link or merged-binary directive. The `absl`/`grpc`/`grpcpp`/`openssl_grpc`/`FirebaseFirestoreInternal` cluster comes from FirebaseFirestore.

**Proposed solution — measure, do not act.** Both obvious levers are wrong. `MERGED_BINARY_TYPE: automatic` does **not** merge prebuilt binary frameworks — Xcode's mergeable-libraries feature requires each dependency to be built from source with `MAKE_MERGEABLE`/`MERGEABLE_LIBRARY`, and all 13 arrive as precompiled xcframeworks, so setting it on the app target is a no-op. And Firestore is not removable: six files import it or call `Firestore.firestore()` — `CopyOverridesStore.swift`, `SubscriptionManager.swift`, `FeedbackPromptManager.swift`, `UserProfileStore.swift`, `PushNotificationManager.swift`, `ReferralManager.swift`. Run a `DYLD_PRINT_STATISTICS=1` launch or an App Launch Instruments trace first. If Firestore dominates, the tractable move is retiring its two lightest consumers (copy overrides → an RC JSON blob, feedback prompts) to shrink the surface.

**Expected improvement** — The framework count is a hard fact; the launch cost attributed to it is **entirely unverified**. Modern dyld with the shared cache and chained fixups is materially cheaper than the "1-5 ms per framework" heuristic assumes.

**Complexity** High — **Priority** Medium (measurement only)

---

## 2.7 Data & network

---

### D1 — `loadAndSync` is `@MainActor`: the SwiftData batch write runs on the main thread

**Problem** — First sync (fresh install or post-wipe) blocks the UI for seconds while tens of thousands of rows are inserted and saved on the main thread.

**Root cause** — `HealthKitManager.swift:269-271` `@MainActor func loadAndSync(store:)` on a class that is **not** main-isolated (`:17-18`). The `withTaskGroup` at `:333` correctly fans the per-metric HealthKit queries off-main (the `addTask` closure is `@Sendable` and `fetchMetric` at `:574` is nonisolated) — **that half of the finding is fine**. But `persistFetchedData` (`:493-494`) and `finalizeInMemoryTimeSeries` (`:522-523`) are both `@MainActor`, and `persistFetchedData` calls `HealthDataBatchWriter.persistAll`, which per metric does a predicated `context.fetch` (`:101-105`), builds a day-keyed dictionary (`:108-118`), inserts every new sample (`:130-152`) and ends in one monolithic `try context.save()` (`:53`). First sync uses a 10-year `startDate` (`HealthKitManager.swift:365`). Rows are day-bucketed, so the ceiling is ~3,650 rows per metric for metrics that actually returned samples — still tens of thousands of inserts on main. The result-consumption loop at `:372-386` also mutates the `@Observable` `syncProgress` up to four times per metric on main.

**Proposed solution** — Move **only** persistence off main; do not try to de-isolate all of `loadAndSync` in one pass. Add a `@ModelActor HealthDataWriterActor` with its own `ModelContext` from the same `ModelContainer` (the detached-context pattern already exists at `AppStartupCoordinator.swift:58`), move `persistAll` onto it, and `await` it from `persistFetchedData`. Two things **must** stay on main or behaviour changes: `store.invalidateTimeSeriesCache(for:)` (HealthDataStore is `@MainActor` by explicit design, `:150-154`) and the `timeSeries` assignment in `finalizeInMemoryTimeSeries` (`@Observable` state SwiftUI reads). Note the writer actor's context is **not** the same context `store` reads from, so `persistAll`'s existing comment ("uses the caller's context so reads see the written data immediately") stops holding — the main-actor cache invalidation is what keeps reads correct, and that must be verified, not assumed. Chunk saves every ~2,000 inserts regardless. Also coalesce the ~288 `syncProgress` writes into a cadence-based publish — cheap and safe.

**Expected improvement** — First sync: removes a genuine **multi-second** main-thread block. Steady state: `newData` only carries metrics whose incremental fetch returned samples, so a typical foreground refresh is a handful of metrics — realistically **5-30 ms**, not 40-150.

**Complexity** High — **Priority** Critical (first sync) / Medium (steady state)

---

### D2 — Every sync ends with one unindexed full-table scan per changed metric, on the main actor, re-reading rows just written

**Root cause** — `persistFetchedData` calls `store.invalidateTimeSeriesCache(for: batchResult.metricsWithChanges)` (`HealthKitManager.swift:515`), which nils `allSeriesCache` wholesale and removes the per-metric entries (`HealthDataStore.swift:228-236`). `finalizeInMemoryTimeSeries` then loops `newData` calling `store.loadTimeSeries(for: metric)` (`:544-552`), falling through to a predicated `FetchDescriptor<StoredDailySample>` on `metricRawValue` (`HealthDataStore.swift:287-297`) plus a full `MetricTimeSeries` rebuild. `StoredDailySample` (`:9-20`) carries **no index attribute**, unlike `StoredSyncMetadata` at `:23-25`.

**Proposed solution** — The index half **does not compile on this project**: `project.yml:4-5` sets iOS 17.0 `[verified]`, SwiftData's `#Index` macro is iOS 18+, and iOS 17 SwiftData exposes no attribute-level index option. Drop it or gate it behind `@available`. The real fix is reuse of two functions already in the file: `HealthDataBatchWriter.persistAll` writes these exact rows from these exact samples, so `persistFetchedData` should call the existing `store.updateSeriesCaches(...)` (`HealthDataStore.swift:199-219`, merges into both cache tiers with no SwiftData read) instead of `invalidateTimeSeriesCache(for:)`, and `finalizeInMemoryTimeSeries` should use the already-present `mergeSeries(metric:existing:incoming:)` (`HealthKitManager.swift:558-572`) rather than a round trip. `mergedByLocalDay` is the same merge the store performs, so no behaviour change.

**Expected improvement** — Per changed metric, a predicated scan over a ~26k-row unindexed table plus a rebuild is roughly **1-3 ms** (by analogy with the team's own 3.16 ms `loadScoreHistory` figure at `DashboardViewModel.swift:1148`). A refresh where 8-16 metrics changed costs roughly **10-45 ms** on the main actor. The in-memory merge captures all of it without needing the index.

**Complexity** Medium — **Priority** High

---

### D3 — First sync pulls ten years of raw sleep-stage samples in one unbounded query

**Root cause** — On first sync `lastSync` is nil so `HealthKitManager.swift:356-366` sets `startDate` to `-10 years`. Sleep metrics route into `fetchAllSleepStages`, one `HKSampleQuery(sampleType: .sleepAnalysis, limit: HKObjectQueryNoLimit, ...)` over that whole span (`:1097-1107`). The one-shot backfill replays it for **existing** installs: `:310-312` `let needsSleepBackfill = !isFirstSync && !UserDefaults.standard.bool(forKey: sleepBackfillKey)` drives `rewriteSleepHistory`, which takes the same branch (`:337, :359-366`). Redundant work: the query already sorts ascending by `HKSampleSortIdentifierStartDate` and `filter` preserves order, yet `groupSleepSessions` re-sorts at `:937-939` — and the function's own comment at `:955-961` declares it already relies on that ascending invariant.

**Proposed solution** — Two zero-risk pieces first, independently: delete the redundant `.sorted` at `:937-939`, and stop early once a chunk returns nothing so a two-year user stops paying for eight empty years. Then, if chunking: sessions are built by gap-grouping across the whole array (`:934-951`), so a night straddling a chunk boundary splits into two sessions and its wake-day attribution can move — **that is a data correctness change**. Overlap each chunk by more than `sleepSessionGapThreshold` and de-duplicate by sample UUID at the seam, or the backfill this code exists to perform will itself mis-attribute nights.

**Expected improvement** — A three-year user is ~65k `HKCategorySample` objects ≈ **20-70 MB transient**, not the 100-300 MB originally claimed. Jetsam during onboarding is a genuine risk for long-tenured users; no memory trace proves it happens.

**Complexity** Medium — **Priority** Medium

---

### D4 — Live-tab anchored streams pass `anchor: nil` and discard the returned anchor; sample parsing runs on the main actor

**Root cause** — `LiveViewModel.swift:436-452` passes `anchor: nil` with `HKObjectQueryNoLimit` and binds the new anchor to `_` in both handlers; `:562-580` repeats it for SpO2 (6 h) and respiratory rate (24 h). `processHeartRateSamples` sorts and maps on the main actor (`:531-539`) because the class is `@MainActor` (`:9-10`). It also pays a **double** main-actor hop: `:446`/`:450` correctly hop from the off-main HealthKit callback, then `:466` opens a **second** `Task { @MainActor in }` inside the already-main-isolated function; same shape at `:591`.

**Proposed solution** — Delete the redundant inner hops at `:466` and `:591` — two lines, pure scheduling waste. Mark `processHeartRateSamples` / `processLatestSample` `nonisolated` so the parse runs on HealthKit's callback queue (both already end in a main-actor hop). **Do not** add a query limit — `HKAnchoredObjectQuery` ignores sort descriptors, so "limit a few hundred with a descending sort" is not something the API supports and a bare limit returns an arbitrary subset, which would visibly change the chart. **Do not** persist an `HKQueryAnchor` through `NSKeyedArchiver` — a new stateful mechanism with stale-anchor and migration failure modes, bought for a query that returns a few dozen samples.

**Expected improvement** — Well under 1 ms in the common passive case, ~1 ms after a long workout. **Live tab only** — verified: `startStreaming()` is invoked only from `LiveView.swift:147, :171, :173`; nothing in HomeView or ContentView starts these streams, so the "opening Home produces a hitch" framing is false.

**Complexity** Low — **Priority** Low

---

### D5 — Uncapped 72-way HealthKit fan-out with a live `@Observable` progress counter written per metric

**Root cause** — `HealthMetric` has exactly 72 cases; `HealthKitManager.swift:334-336` adds one child task per case with no width cap, and `:351, :372-386` mutate `syncProgress` up to four times per completion.

**Proposed solution** — Take **only** the progress throttle: accumulate the counters in locals and publish `syncProgress` on a cadence. Skip the fan-out cap — HealthKit serializes on its own daemon regardless, and no trace shows 72 concurrent queries is worse than 8. The sleep-key rounding is one line and removes up to four redundant short scans per incremental sync (`HealthDataBatchWriter.swift:168` stamps `let now = Date()` per call, so the five sleep metrics can straddle a second boundary) — but bill it as a cleanup, not as preventing a decade-wide scan, which it does not: on first sync and backfill all five sleep metrics derive `startDate` from the single shared `endDate` (`:359-366`) and already dedupe to one.

**Expected improvement** — Removes up to ~200 invalidations of **one small view** — `syncProgress` is read only by `HomeConnectHealthView.swift:39, 89, 105, 120, 134`, the connect/empty state, which is on screen only during first-launch sync. No effect on any user who already has data.

**Complexity** Low — **Priority** Low

---

### D6 — Menstrual flow queried twice per refresh, and the first query fires before the applicability gate

**Root cause** — `DashboardViewModel.swift:775` launches `async let cycleFlowSamplesTask = healthKitManager.fetchMenstrualFlowSamples(days: 365)` with **no gating**, and `MenstrualCycleTracker.swift:184` independently issues `fetchMenstrualFlowSamples(days: 730)` — a strict superset. The applicability hoist already exists (`DashboardViewModel.swift:889-900`, with a comment saying it was hoisted for exactly this reason) and gates the *second* query at `:902-904`; only the first is ungated.

**Proposed solution** — Move the three applicability lines (`:896-900`) above line 775 and wrap the existing `async let` in that gate. That deletes the query entirely for every user the feature does not apply to. Merging the two fetches into one shared 730-day array is a further step; do it only if you are already in that file.

**Expected improvement** — No frame time — the fetch runs through `withCheckedContinuation` and its callback executes on HealthKit's queue. Redundant work worth deleting on principle.

**Complexity** Low — **Priority** Low

---

### D7 — Background refresh rebuilds a `PersistenceManager` per wake and does its SwiftData reads on the main actor

**Root cause** — `BackgroundRefreshCoordinator.swift:81` wraps the whole body in `Task { @MainActor in }`. `rearmNotifications` (`:202-203`, `@MainActor`) runs `AnswerReadyScheduler.checkAndFire(store:)` (`:219` → `AnswerReadyScheduler.swift:75-80`, one `store.loadTimeSeries` per `PredictionMetric.allCases`) and `SleepNeedCalculator().compute(from: store, ...)` (`:231`). `:248` constructs an inline `PersistenceManager()`, re-running `startCloudSync()` + `migratePlaintextData()` + `migrateCriticalAlertsDefault()` (`PersistenceManager.swift:41-45`) on every background wake. `WidgetDataStore.swift:208-216` allocates fresh coders per call.

**Proposed solution** — Two contained pieces only. (1) Replace the inline `PersistenceManager()` at `:248` with the container's long-lived instance (`AppContainer.swift:10`) — the coordinator is built by the container, so pass it in. (2) Hoist `WidgetDataStore`'s coders to `private static let`. **Do not** de-isolate `handle` — that means auditing a body that touches an `@MainActor @Observable` view model throughout, for a contention window that only exists if the user foregrounds mid-refresh. And correct the premise: `try? await Task.sleep(for: .seconds(delay))` at `:109` **suspends** the task and releases the executor — the "5-second main-actor occupancy" does not exist.

**Expected improvement** — One redundant `PersistenceManager` init per background wake removed; certain but small. The launch-contention claim is unproven.

**Complexity** Low — **Priority** Low

---

### D8 — Returning to Today fires the refresh pipeline twice on the legacy path

**Root cause** — `ContentView.swift:325-328` fires `liveViewModel.fetchHomeDataTiered()` on tab change, and on iOS 17-25 `HomeView` remounts (`didInitialLiveFetch` at `:34` resets), so `.onAppear` also runs the full ten-query `fetchHomeData()`. `fetchHomeData` (`LiveViewModel.swift:204-206`) debounces **only** against `lastHomeFetchDate` even though it writes both timestamps at `:211-212`; `fetchHomeDataTiered` debounces against `lastTieredFetchDate` (`:245-250`). So both run milliseconds apart and re-issue three to six identical queries.

**Proposed solution** — **One line:** make `fetchHomeData()` also honour `lastTieredFetchDate`. **Do not** delete `ContentView.swift:326-328` — on iOS 26 HomeView's identity survives the tab switch, so `onAppear` fetches nothing and that line is the *only* refresh on tab return; deleting it leaves Today stale until the 120 s timer.

**Expected improvement** — Three to six duplicated HealthKit queries per tab return on the legacy path. Async, so the main-thread saving is small.

**Complexity** Low — **Priority** Low

---

## 2.8 Memory

---

### MM1 — Share card renders a multi-megabyte bitmap synchronously on the main thread with no loading state

**Root cause** — `ShareButton.swift:45` sets `isRendering = true`, `:83` sets `renderer.scale = UIScreen.main.scale`, `:85` hits `guard let image = renderer.uiImage` — a synchronous MainActor rasterization inside a Button action, all in one run-loop turn, so the disabled state never commits before the freeze. Card sizes: 390×693 for score/insight (`ShareableCard.swift:289, 347, 411, 469`) = 9.28 MB at @3x; 390×520 for the template card (`:839, :969`) = 7.30 MB. Two live call sites only: `WeeklyReviewView.swift:157` and `ShareableCard.swift:587` (`ShareWinSheet`). `InviteFriendsView.swift:174` shares text and never rasterizes.

**Proposed solution** — `ImageRenderer` is `@MainActor`-isolated and so is `render(rasterizationScale:renderer:)` — the CGContext closure body still runs on the main actor, so **this cannot be moved to a background queue.** What works: (1) make `shareCard()` async and `await Task.yield()` after `isRendering = true` so SwiftUI commits a spinner before the blocking call — turning a frozen frame into visible progress; (2) add the spinner UI, since `:31-35` currently just shows a static SF Symbol; (3) pin `renderer.scale = 2` — flagged honestly as a **visual change**: the PNG drops from 1170×2079 to 780×1386, a 33 % linear resolution loss. Very likely fine for social targets; eyeball a template card with a user photo first.

**Expected improvement** — Nobody measured this. The freeze is synchronous by construction; instrument one tap with signposts before quoting a number. Scale 2 roughly halves rasterization time and cuts the transient bitmap to 4.1 MB / 3.2 MB.

**Complexity** Low — **Priority** Medium

---

### MM2 — Verified non-issues (do not re-investigate)

`[re-verified this pass where cheap]`

- **Images:** `Assets.xcassets` is 108 KB with one imageset (LaunchIcon). `grep AsyncImage` → 0 hits.
- **Formatters:** every `DateFormatter()` construction site is inside a `static let` closure or routes through the thread-keyed cache at `Date+Extensions.swift:9-29`. Checked: `GamificationEngine.swift:250`, `ChangePointDetector.swift:386`, `ActionReminderScheduler.swift:15`, `SleepCoachView.swift:551`/`:871`, `BrainHealthDetailView.swift:444`, `WeeklyPatternAnalyzer.swift:6`.
- **Observers:** exactly three `addObserver` sites (`ThermalManager.swift:147`, `AppAnalytics.swift:3202`, `PersistenceManager.swift:86`), all storing a token.
- **Release build settings:** `SWIFT_COMPILATION_MODE = wholemodule` (`project.pbxproj:3324`), `SWIFT_OPTIMIZATION_LEVEL = -O` (`:3325`), `ENABLE_NS_ASSERTIONS = NO` (`:3309`), `ENABLE_DEBUG_DYLIB = NO` (`:3259, :3364`). No `DEBUG` leaking into Release. 19 `print(` calls app-wide.
- **Widgets and Live Activities are the best-optimised code in the repo.** They deliberately use `RadialGradient` instead of `.blur` (`TodayScoreLiveActivityWidget.swift:73, :348`; `WindDownLiveActivityWidget.swift:228`), use `Text(timerInterval:)` instead of ticking state (`BreathworkLiveActivityWidget.swift:138, :256, :302`), honour Reduce Motion (`:289`), use `.periodic(by: 60)` on lock screen (`WindDownLiveActivityWidget.swift:286, :364`), and gate `reloadAllTimelines()` on a content-changed check (`WidgetDataStore.swift:234-238`).
- **Extensions:** `Collection+Statistics.swift` is single-pass or n log n with `reserveCapacity`; `movingAverage` (`:73-94`) already uses a running total. One central util per job.
- **No SwiftData `@Query` in the view layer, no `.id(UUID())`, no `ScrollViewReader`/`scrollTo`** — all three greps return zero hits.
- **`cardStyle()` is already correct** (`DesignSystem.swift:230-239`), so its 101 call sites are **not** part of the shadow problem — only the seven raw `.shadow(` sites in R1.
- **Live tab streaming lifecycle is sound** (`LiveView.swift:146-181`), correctly distinguishing `.inactive` from `.background`.

**Priority** — Informational. The value is negative work avoided.

---

## 2.9 Navigation

---

### N1 — Weekly Review destination builds a fresh `PersistenceManager` on every ContentView body pass, and can blank the screen

**Root cause** — `ContentView.swift:546-547` `case .weeklyReview: WeeklyReviewView(viewModel: WeeklyReviewViewModel(dashboardViewModel: dashboardViewModel))`. `WeeklyReviewViewModel.swift:7` `private let persistence = PersistenceManager()`, whose `init` (`PersistenceManager.swift:41-45`) runs `startCloudSync()` (registers an observer, then `cloud.synchronize()`, `:85-94`) and loops six encrypted keys (`:56-60`). The freshly-injected view model has `review == nil` while `onAppear` (`WeeklyReviewView.swift:168-169`) will not re-fire under an unchanged structural identity. **HomeView already solved this three files away:** `HomeView.swift:15` `@State private var weeklyReviewViewModel: WeeklyReviewViewModel?` + `ensureWeeklyReviewVM()` at `:375-379`, called from `.onAppear` (`:106`). `HomeView.swift:683` is what pushes into the leaky path.

**Proposed solution** — Route the push through HomeView's already-stable instance instead of building one in the destination. The identity problem and the blank-screen risk both disappear in one move. **Skip** the wider PersistenceManager injection sweep — `AnalysisEngine.swift:6` is once per app; `SubscriptionManager.swift:452`, `WatchMonitor.swift:310` and `BackgroundRefreshCoordinator.swift:248` are one-shot background reads. `WeeklyReviewViewModel.swift:7` is the only one on a navigation path.

**Expected improvement** — Removes one `NSUbiquitousKeyValueStore.synchronize()` + 6 UserDefaults reads + up to 6 AES-GCM opens from the push and from every subsequent root pass while it is on screen — realistically **0.5-3 ms** depending on the forecaster-model blob size. Note the keychain cost is not what it looks like: `EncryptedStore.shared` caches the key for the process (`EncryptedStore.swift:138-150`). The content-loss risk is the stronger reason to fix it.

**Complexity** Low — **Priority** High

---

### N2 — Legacy tab switch cross-fades two full screen trees for 320 ms and destroys the outgoing tab's state

**Root cause** — `CustomTabBar.swift:30-34` writes `selectedTab` inside `withAnimation(.spring(duration: 0.32, bounce: 0.18))`, while `ContentView.swift:521-532` `tabContent` is a bare `switch selectedTab` producing `_ConditionalContent`, embedded as the NavigationStack root at `:402-404`. A structural branch change inside an animation transaction gets the default opacity insertion/removal transition, so **both** trees are retained and composited for the full 320 ms. State destruction is real: `HomeView.swift:34` `didInitialLiveFetch` resets on remount and `:106-112` re-runs `fetchHomeData()`, whose ten calls (`LiveViewModel.swift:201-225`) are guarded only by a 1 s debounce that a tab round trip trivially exceeds. Legacy path is `#available(iOS 26.0, *)`'s else-branch (`ContentView.swift:366-372`) with an iOS 17.0 floor `[verified]`.

**Proposed solution** — **Do now, Low risk, no visual change:** delete `withAnimation` at `CustomTabBar.swift:31-33`, write `selectedTab = tab` bare, and scope the spring to the pill with `.animation(.spring(duration: 0.32, bounce: 0.18), value: selectedTab)` on the `matchedGeometryEffect` background at `:59-63`. The pill slides identically; the screen swap becomes instant; the dual-tree composition is gone. This delivers the entire composition win on its own.

**Do NOT** do the ZStack-with-opacity rewrite. Keeping all four roots mounted fires every tab's `onAppear` at once, which breaks the 22 `SectionTracker` impression pairs, `HomeView`'s `startHomeRefresh()`/`stopHomeRefresh()` timer lifecycle (`:113`/`:129` — hidden tabs would keep polling HealthKit), and every `trackFeatureOpen`/`trackFeatureClose` pair. It does **not** match iOS 26 `TabView`, which defers body evaluation until selection; a ZStack does not.

**Expected improvement** — Eliminates 320 ms of dual-tree composition per tab tap on iOS 17-25. Magnitude untraced. The ten-query and scroll-position wins require the risky half and should not be counted here.

**Complexity** Low — **Priority** High

---

### N3 — `SettingsView.init` does a disk read, an AES-GCM open and a JSON decode on every ContentView body pass (iOS 26)

**Root cause** — `ContentView.swift:374-396`: the four `Tab { ... }` closures are plain ViewBuilder parameters, so `homeTabView`, `liveTabView`, `exploreTabView` and `settingsTabView` (`:470-478`) all execute per pass. `SettingsView.swift:51` `self._preferences = State(initialValue: persistence.loadPreferences())`. (On the legacy path `tabContent` is a `switch` and builds one tab root, so this is iOS 26 only.)

**Proposed solution** — **Two lines:** `@State private var preferences: NotificationPreferences = .default` and load the real value in the existing `.task` at `:154-160`. No visual change — the Form is only visible once the tab is selected. **Skip** the `visitedTabs` gate (TabView already defers a tab's *body*; a gate only saves the struct init, which after this fix is free) and **skip** the SectionTracker allocation concern (`SectionTracker.swift:96-105` is three stored properties).

**Expected improvement** — Tens of microseconds per navigation event. Worth it because the fix is two lines, not because it will show on a trace — the AES key is cached process-wide (`EncryptedStore.swift:138-150`).

**Complexity** Low — **Priority** Low

---

### N4 — All three `NavigationPath`s live as root `@State`, so every push and pop invalidates ContentView

**Root cause** — `ContentView.swift:18-20` declares `navigationPath`, `homePath`, `explorePath` as `@State`. Pushing appends to one, which invalidates ContentView's body by definition; the paths are then handed down as bindings (`:376-378`, `:459-467`, `:480-487`), so the tab root re-evaluates too, and on iOS 26 that pass re-runs all four `Tab` closures. Pushing Metric Detail from Today re-runs the Home feed body **underneath** the pushed screen, and again on pop. The three `.onChange(of: <path>.count)` handlers at `:329-338` are **inert** with respect to invalidation — `@State` ownership alone does it — so do not touch them.

**Proposed solution** — Stage it. Do N3 first (two lines, removes the decrypt from the pass), confirm on a trace that the remaining root pass actually costs frames, and only then decide whether path extraction earns its risk. Moving each path into a `HomeTabRoot`/`ExploreTabRoot` wrapper means re-homing `navigate(to:)` (`:910-923`), `handleDeepLink(_:)` (`:927-947`), the NotificationRouter consumption at `:336-338` and the `ShowTrendsIntent` notification path (`ShowTrendsIntent.swift:24`) — every external entry point into the app. A route can arrive before a tab root has mounted, which the current direct `@State` write handles for free. This must land with UI-test coverage for widget, Live Activity, push-notification and Siri entry.

**Expected improvement** — Mechanism certain, magnitude **unmeasured**. Profile the push before committing to a High-complexity refactor of every deep-link entry point.

**Complexity** High — **Priority** Medium

---

### N5 — Four stacked `.sheet` modifiers on HomeView's root, plus a fifth inside a lazy feed row

**Root cause** — `HomeView.swift:74` (`$showScoreGuide`), `:81` (`$showJournalEntry`), `:84` (`$showSoftLockPaywall`), `:87` (`$showRecoveryInfo`) are all on the same `Group`, plus `.fullScreenCover` at `:64-66` and `.sheet(isPresented: $showShareCard)` at `:532` **inside** the LazyVStack feed row. SwiftUI honours one `.sheet` per view level. `ContentView.swift:13-17` documents this exact failure mode and `:41-58` shows the single `.sheet(item:)` `RootSheet` pattern the root already uses.

**Proposed solution** — Port `RootSheet` into HomeView as a `HomeSheet: Identifiable` enum with one `.sheet(item:)`, and move the in-feed sheet at `:532` into that slot, capturing the templates at tap time (matching the `ContentView.swift:43-45` rationale). **Drop** the `shareTemplatesCache` half — `DashboardViewModel.swift:2129-2144` reads a handful of already-computed scalars and hands them to `ShareTemplateBuilder.build`; caching microseconds into `@State` adds a staleness window for no gain, and `dailyResult` also feeds it, so it would need a second invalidation trigger.

**Expected improvement** — No frame saving. Closes a latent empty-sheet class bug and removes a presentation host from a lazily-destroyed row.

**Complexity** Medium — **Priority** Low

---

### N6 — App root is Observation-subscribed to Remote Config and StoreKit

**Root cause** — `LasoApp.swift:76`/`:78` read `remoteConfig.requiresForceUpdate`/`killSwitchEnabled` in the WindowGroup body; `ContentView.swift:491` reads `killLiveTab` and `:499` `FeatureGate.canAccess(.liveTab)` inside `liveTabView`, evaluated inside `liquidGlassTabs` (`:380-383`) and `tabContent` (`:526`). `startRealtimeUpdates` (`RemoteConfigManager.swift:219-238`) stamps `lastFetchTime` from a Firebase listener; the comment at `:214-217` says stamping it "re-renders every @Observable-tracked gate mid-session" — a known, deliberate design.

**Proposed solution** — Only the ContentView half is worth doing: make `liveTabView` an unconditional `LiveView(...)` and move the kill-switch/entitlement branch inside LiveView's own body, so the gate re-renders one tab instead of the root. **Drop** mirroring gate results into plain `@State` — that trades an Observation edge for hand-maintained cache invalidation on a kill switch, the one flag that must never be stale. Leave `LasoApp:76-78` alone; a force-update gate belongs at the root.

**Expected improvement** — Near zero in a typical session: a Firebase realtime push requires an admin publish and a StoreKit status change requires a transaction. Defensive, not measurable.

**Complexity** Low — **Priority** Low

---

## 2.10 Charts

---

### C1 — `MetricChartView` rebuilds its entire Swift Charts mark tree on every scrub touch

**Problem** — The scrub crosshair is declared inside the same `Chart { }` closure as the data, so every touch move re-constructs every mark and re-runs scale and layout solving instead of repainting one rule and two dots. **This is the largest single per-frame cost identified anywhere in this report.**

**Root cause** — `MetricChartView.swift:188-207` declares the selection `RuleMark` plus two `PointMark`s inside the same closure as the data series; `selectedSample` (`:57-72`) derives from `@State selectedDate` (`:18`), written per touch move by the DragGesture at `:232-254`. The data series at `:97-119` emits both a `LineMark` **and** an `AreaMark` per sample, each `.interpolationMethod(.catmullRom)`; the trend overlay at `:134-145` adds N−6 more. `MetricDetailView.swift:167-176` auto-expands the range up to 365 days when the 30-day window is empty. `selectedSample` is already O(log n) (`:59`), so the entire per-touch cost is Swift Charts — which strengthens the case for extraction.

**Proposed solution** — Extract the static marks into a nested `struct MetricBaseChart: View, Equatable` over the samples, the trend line and the y-domain, apply `.equatable()`, and move the crosshair into `.chartOverlay` driven by `proxy.position(forX:)`/`position(forY:)`. Two implementation notes: `MetricSample` must be `Equatable` (or you hand-write `==`) or the extraction silently buys nothing; and the existing overlay at `:226-292` already holds the gesture, so keep `.sensoryFeedback(.selection, trigger:)` (`:296`) wired to the same sample or the haptic regresses. `yDomain` is already precomputed in `init` (`:44-49`) — the right precedent.

**Skip LTTB downsampling.** At 365 daily points across a ~340 pt plot you are at roughly one point per point of width, so there is nothing meaningful to remove without visible loss, and the repo already has a simpler `stride`-based decimation (`ExploreYourTrendsSection.swift:132-144`) if one is ever needed.

**Expected improvement** — 8-20 ms per touch move at the 365-day worst case, 2-6 ms at the typical 30-90 day range. **Unmeasured**, but the mechanism is certain and the extraction is contained. Note the 365-day path is reached only via auto-expand for sparse metrics.

**Complexity** Medium — **Priority** Critical

---

### C2 — `StrainDetailView` keeps chart scrub state at the screen root, rebuilding the whole 778-line screen per touch

**Root cause** — `@State private var selectedHistoryDate: Date?` is declared on `StrainDetailView` itself (`:82`); the drag writes it per `onChanged` (`:377-379`); `body` (`:123-153`) unconditionally builds `heroSection`, `historySection`, `trendsSection`, `snapshotSection`, `learnMoreSection` and `disclaimerNote`. `TrendSparkCard` (`:474-481`) is not Equatable and carries a `[TrendSparkPoint]` of non-Equatable elements, so SwiftUI cannot skip it — its full Swift Charts body re-runs per touch move.

**Proposed solution** — Move `historySection` into `private struct StrainHistoryChart: View` owning `@State private var selectedHistoryDate` **and `isScrubbing`** (`:85` — it must move with it, or the drag-latching behaviour the comment at `:83-84` protects breaks), taking `weekHistory` and `targetStrainRange` as lets. Do this **together with** the Strain hero shadow fix in R1 — neither is worth much alone. **Skip** the `PersonalBand.make` hoist (`:479`, ~1-2 µs on 30 points, and moving it means threading a parameter through `ContentView.swift:607`) and the `selectedHistoryPoint` double read (`:90-95`, O(7)).

**Expected improvement** — ~1.5-4 ms per touch move. Composition: the hero's offscreen shadow re-blur (**shared with R1 — do not sum**) plus the TrendSparkCard rebuild plus the rest of the tree's view construction.

**Complexity** Low — **Priority** High

---

### C3 — `VitalityTrendSection` re-emits 180 chart marks and two 90-point catmull-rom solves per scrub frame

**Root cause** — `VitalityTrendSection.swift:37-54` emits an `AreaMark` and a `LineMark` per history point, both `.interpolationMethod(.catmullRom)`; the selection `RuleMark` and two `PointMark`s sit **inside the same `Chart { }` closure** at `:65-83`; the drag writes `selectedTrendDate` at `:131` per touch move. `VitalityScorer.swift:297` `trendWindowDays = 90` and `:262` `history: [(date: Date, age: Double)]` confirm up to 90 points.

**Proposed solution** — Same shape as C1: extract the static marks into a nested `struct VitalityBaseChart: View, Equatable` over `history`, `chronologicalAge`, `tint` and `yRange`, call `.equatable()`, and move the crosshair into a sibling overlay. A tuple of `(Date, Double)` is `Equatable` in Swift, so `==` synthesises — you do **not** need to convert `VitalityScorer.history` to an Identifiable struct, and you should not: that changes a `private(set)` property on a Core analysis type plus every consumer to save ~1 µs. Do the free version of the y-range fix: `let yRange = chartYRange` at the top of `body`, next to the existing `let selected = selectedTrendPoint` at `:26`. Do **not** add a stored property to `VitalityScorer` for a ~5 µs computation.

**Note on a claim to discard:** there is no plottable-collection initialiser for `LineMark`/`AreaMark` in Swift Charts — every mark initialiser takes a single point. `ForEach` over the data is the framework's intended idiom and cannot be collapsed to "2 marks". The fix is the rebuild, not the mark count.

**Expected improvement** — ~1.5-4 ms per touch move. Proportionally less than C1 (90 points/180 marks vs 365/~1100).

**Complexity** Medium — **Priority** Medium

---

### C4 — `chartXSelection` and a hand-rolled `DragGesture` both write the same selection state

**Root cause** — Three charts declare both: `MetricChartView.swift:210` + `:232-254`; `VitalityTrendSection.swift:85` + `:120-133`; `StrainDetailView.swift:337` + `:366-380`. The custom gesture exists for good reason — the latching behaviour documented at `MetricChartView.swift:21-23` and `:234-237` is not something `chartXSelection` provides.

**Proposed solution** — Remove the redundant `.chartXSelection(value:)` at the three sites as **cleanup, not as a perf fix**. Two things to check first, neither of which is optional: `chartXSelection` supplies the system selection accessibility and, on iPad and with a trackpad, pointer-hover selection, which the custom gesture does not replicate — confirm with VoiceOver and a trackpad before removing. And the `onTapGesture` block carries the analytics call and the tap-to-deselect toggle, so it cannot simply be dropped with the drag handler.

**Expected improvement** — **Most likely zero.** SwiftUI coalesces same-turn invalidations within a transaction, so two writes to the same `@State` from one touch produce one body pass, not two. Measure with `Self._printChanges()` before claiming anything.

**Complexity** Low — **Priority** Low

---

### C5 — `TrendSparkCard` spins up a full Swift Charts instance for a 132×56 pt sparkline

**Root cause** — `TrendSparkCard.swift:112-147` builds a real `Chart` with a `RectangleMark` band, an N-point `LineMark` ForEach with `.interpolationMethod(.catmullRom)` and a `PointMark`, then hides both axes (`:143-144`), rendered at 132×56 (`:100-101`). Three call sites, ~30 points each: `StrainDetailView.swift:474-481`, `StressMonitorView.swift:350-357`, `BrainHealthDetailView.swift:194-201`.

**Proposed solution** — **Do not do this yet.** Fix C2 first — that removes the per-scrub rebuild on Strain Detail, which is the only reason this card is on any frame path. Re-measure afterwards; a once-per-appearance 1-3 ms is not a frame problem. If it still profiles badly, a Canvas rewrite must **preserve the curve** (`ctx.addQuadCurve` or Catmull-Rom→Bezier): at 30 points across 132 pt the spacing is ~4.4 pt, i.e. 13 px at @3x, so a polyline is a visible change on three screens, not sub-pixel. And **do not** substitute `SparklineView` (`ExploreYourTrendsSection.swift:187-214`) — it strokes at 1.5 pt vs 2.0, has no band rectangle and no endpoint dot.

**Expected improvement** — 1-3 ms per card appearance, three appearances per session. **Complexity** Medium — **Priority** Low

---

## 2.11 Concurrency

---

### CC1 — `runPostHeavyPhase` and `runMLPhase` inherit main-actor isolation despite being launched from `Task.detached`

**Root cause** — `DashboardViewModel` is `@MainActor @Observable` (`:22-23`), and `runPostHeavyPhase` (`:971`) and `runMLPhase` (`:1082`) are plain private methods with no `nonisolated`, so `await self.runPostHeavyPhase(...)` at `:952` hops the detached task straight back onto main and runs the whole body there.

**Proposed solution** — Mark both `nonisolated`; the existing `await MainActor.run { }` blocks inside them then become the real hops. Check `housekeepingService.perform` and `WakeUpTimeDetector.detectAndPersist` for their own isolation first — they are the untested unknowns. **Drop** the `loadAllBaselineHistory` restructuring: it sits behind a 1-hour memo (`:115` `driftInsightsTTL = 3600`, checked at `:999-1002`), so the 30-80 ms JSON decode runs at most hourly, and the circadian block is gated on `needsCircadianAnalysis` (weekly).

**Expected improvement** — Per-refresh main-thread cost is `ScoreTrajectoryAnalyzer` over ≤60 score rows (`ScoreTrajectoryAnalyzer.swift:8-9`) plus `InsightCoordinator` capped at 15 (`InsightCoordinator.swift:7`) plus housekeeping — likely **under 10 ms**, not the 50-120 ms originally claimed.

**Complexity** Medium — **Priority** Medium

---

### CC2 — `loadAndSync` has no in-flight guard, so two concurrent refreshes can run the sync and batch write twice against one `ModelContext`

**Root cause** — `HealthKitManager.swift:291` sets `isLoading = true` and `:420` clears it, but it is never **read** as a gate. `refresh()` cancels `refreshTask` (`DashboardViewModel.swift:708`), but cancelling that task does not stop an already-running `refreshCore` — `refreshCore` never checks `Task.isCancelled` and its `await loadAndSync` is not a cancellation point. So two pull-to-refresh gestures more than 0.5 s apart during a slow first sync put two `loadAndSync` calls in flight. (The onboarding-calibration race is **not** reachable: `refreshOnForegroundIfNeeded` at `:654-667` guards on `ui.hasCompletedInitialLoad`, `!ui.isLoading` and a 30 s throttle.)

**Proposed solution** — Five lines, mirroring the idiom already in the same file at `HealthKitManager.swift:127-138`: `private var inFlightSync: Task<SyncResult, Never>?`, coalesce on entry. Skip a second `refreshRunToken` guard on `refreshCore` — that token already discards stale results.

**Expected improvement** — A correctness fix first (two writers into one `ModelContext`), a perf fix second. The failure mode is a doubled multi-second main-thread block.

**Complexity** Low — **Priority** Medium

---

### CC3 — `AskDataOrbView` precomputes 180 animation frames at `.userInitiated`, competing with Home's first layout

**Root cause** — `AskDataOrbView.swift:459` `await Task.detached(priority: .userInitiated)` around a 180-iteration loop (`:468-471`) doing eight path traces per frame (`:485-487, :492-496`) plus `computeShellParticles` (`:498`) — roughly 1,210 trig point evaluations × 180.

**Proposed solution** — **One word:** `.userInitiated` → `.utility`. `:93-95` already falls through to `staticOrb` while `cache` is nil. **Drop** the `isVisible` gate suggestion — `.task` is already tied to view lifetime.

**Expected improvement** — This is already off the main thread, so the exposure is core contention, not a stall. Estimate 20-60 ms of one core, once per card appearance. Take the change because it is free, not because "4-10 dropped frames" is defensible.

**Complexity** Low — **Priority** Low

---

### CC4 — No cancellation checks in the ML pipeline, and its detached task is unreachable by any cancel

**Root cause** — `grep "Task.checkCancellation|Task.isCancelled"` across Core/Analysis and Core/Data returns exactly two hits, neither inside an analysis loop. `MLPipelineRunner.swift:67` is `return await Task.detached(priority: .background) { [self] in` with the handle discarded — and because it is detached it does **not** inherit cancellation, so `deferredHeavyTask?.cancel()` (`DashboardViewModel.swift:737-738`) cannot stop it. The only in-loop suspension point (`:189`, `if forecastIdx % 10 == 0 { await Task.yield() }`) yields without checking. `shouldStopForThermal` (`:299-310`) checks thermal state only.

**Proposed solution** — **One line, no plumbing:** `shouldStopForThermal` already returns `Bool` and is already called at all seven gates, so add `if Task.isCancelled { return true }` as its first line and those seven gates become cancellation checkpoints. Add `if Task.isCancelled { return output }` next to the yield at `:189`. Separately, store the detached task on `MLOrchestrator` so it can actually be cancelled — a prerequisite for any of this to have an effect. **Do not** make `run` throwing; that changes the signature and every call site.

**Expected improvement** — Indirect: stops background ML burning E-cores after the user navigates away, reducing the thermal pressure `ThermalManager` then reacts to by degrading animations.

**Complexity** Low — **Priority** Low

---

## 2.12 Architecture

---

### AR1 — The app is capped at 60 Hz, and nothing in the codebase says so

**Root cause** — `[verified this pass]` `grep -rn CADisableMinimumFrameDuration project.yml App Laso.xcodeproj` → **no hits**. Without that Info.plist opt-in, SwiftUI animations on this app are capped at 60 Hz on ProMotion iPhones. Several findings across this audit reason against an 8.3 ms budget; the correct budget is **16.7 ms**.

**Proposed solution** — This is a product decision, not a perf fix. Enabling it raises the ceiling **and** the power draw. Decide deliberately, and re-baseline every number in §3 if you enable it. **Do not** book it as a "gain".

**Complexity** Low — **Priority** Medium (decision, not code)

---

### AR2 — `ThermalManager` writes `@Observable` state from an arbitrary thread and ignores Low Power Mode

**Root cause** — `ThermalManager.swift:147-152` registers the thermal-state observer with **no queue**, and `:157-170` writes the `@Observable` `currentState` on whatever thread posts the notification, while SwiftUI bodies read it on the main actor. `grep isLowPowerModeEnabled` across App/Modules/Common/Core → **no hits**. `accessibilityReduceMotion` is read ad hoc per view (`VitalityOrganicOrb.swift:10`, `VitalityDetailView.swift:6`) rather than folded into one tier.

**Proposed solution** — Two lines: wrap the write as `Task { @MainActor in self.currentState = newState }` or pass `queue: .main` to `addObserver`. Add `ProcessInfo.processInfo.isLowPowerModeEnabled` plus a `.NSProcessInfoPowerStateDidChange` observer folded into `shouldReduceVisualEffects` — Low Power Mode is a stronger signal of user intent than thermal state. **Do not** raise `maxFrameRate` to 120 as a "gain" (see AR1), and **do not** build a three-case `RenderQuality` enum until a second consumer needs it — today there are three call sites that already read the two booleans directly. Note `maxFrameRate`'s `.critical → 0.0` case (which would produce `1.0 / 0.0` as a `minimumInterval`) is unreachable: `VitalityOrganicOrb.swift:34` and `AskDataOrbView.swift:81` both short-circuit to a static branch whenever `shouldThrottle` is true.

**Expected improvement** — No frame gain. Fixes one latent data race; adds a battery-respecting fallback the app lacks.

**Complexity** Low — **Priority** Low

---

### AR3 — Remote-Config-backed colours frozen at file scope

**Root cause** — `VitalityDetailHelpers.swift:3-5` declares `let vitalityWhoopGreen = AppColour.vitalityWhoopGreen` and two siblings as file-scope globals. Swift initializes those lazily **once**, so whatever Remote Config returned at first access is frozen for the process lifetime and a later RC activation never repaints them.

**Proposed solution** — Delete the three globals and read the tokens directly. Landing M5's colour cache makes them pointless anyway.

**Expected improvement** — Correctness, not performance. **Complexity** Low — **Priority** Low

---

## 2.13 Build & instrumentation

---

### B1 — The app emits zero performance telemetry

**Problem** — Nobody on the team can see a hitch happen. Every number in this report — including the team's own 300-500 ms and 883 ms comments — is an argument from reading code. After the fixes ship there is no way to prove any of them worked, and no way to catch the next regression.

**Root cause** — `grep -rn "os_signpost|OSSignposter|MetricKit|MXMetricManager|signpost|OSLog" --include="*.swift" App Core Modules Common LasoWidgets Shared` returns **one line**: `ThermalManager.swift:2: import OSLog`. Across 437 Swift files there is no `OSSignposter`, no `import MetricKit`, no `MXMetricManagerSubscriber` — so `MXHangDiagnostic` and `MXAppLaunchDiagnostic` payloads from real devices are never collected. Crashlytics is linked (`project.yml:41`) but does not report hangs or hitches. The only runtime perf signal in the entire app is `ThermalManager`'s thermal state.

**Proposed solution** — Three pieces, half a day total.
1. One shared signposter in `Core/Config/Perf.swift`:
   ```swift
   let perfLog = OSSignposter(subsystem: "com.lasohealth.fit", category: "perf")
   ```
   Wrap **five** intervals only, not broadly: (a) `AppDelegate.didFinishLaunching`, (b) `AppContainer.init` (`AppContainer.swift:31-35`), (c) `ContentView.init`, (d) the refresh from `DashboardViewModel.swift:801` through the end of the second block at `:831`, (e) `HealthKitManager.loadAndSync`. Signposts cost a few ns when Instruments is not attached, so they ship in Release.
2. A ~25-line `MXMetricManagerSubscriber` registered in `didFinishLaunching`. Forward `payload.hangDiagnostics` (each `MXHangDiagnostic` carries `hangDuration` plus a symbolicated call tree) into the existing `AnalyticsBackend`, and take `MXMetricPayload.applicationLaunchMetrics.histogrammedTimeToFirstDraw` — the real cold-launch number from real devices, which directly measures ST1, ST2 and ST3.
3. Adopt the reading protocol in §6.

**Expected improvement** — 0 ms directly. It converts ~78 findings from arguments into a ranked, measured backlog. **Do this first.**

**Complexity** Low — **Priority** Critical

---

# 3. Top 20 ranked by impact

Frame budget is **16.7 ms** (60 Hz cap, AR1). Every figure below is an estimate unless marked *(team comment)*; none is from a profiler.

| Rank | Fix | Screens | Expected gain | Cx | Pri | Files touched |
|---|---|---|---|---|---|---|
| 1 | **B1** — signposts + MetricKit + hang diagnostics | Whole app | 0 ms directly; makes every other row provable | Low | Critical | `Core/Config/Perf.swift` (new), `AppDelegate.swift` |
| 2 | **ST1** — stop the splash awaiting StoreKit | Every launch | **removes 300-1500 ms of visible splash**, up to 8 s on bad network | Low | Critical | `LasoApp.swift` |
| 3 | **ST3** — invalidate cache only when prune > 0 | Launch | **removes one duplicate whole-table main-thread fetch on 100 % of launches** (one line) | Low | Critical | `AppStartupCoordinator.swift`, `DataRetentionManager.swift` |
| 4 | **M1** — 8 scorers off the main actor | Today, Biology, Live (shared VM) | **removes ~300-500 ms hang** per data-bearing refresh *(team comment)* | High | Critical | `DashboardViewModel.swift`, 4 scorers |
| 5 | **ST2** — bound `loadAllTimeSeries` in `ContentView.init` | Pre-first-frame, all screens | **removes ~100-300 ms launch hang**, and caps growth on a never-pruned table | Medium | Critical | `HealthDataStore.swift`, `DashboardViewModel.swift` |
| 6 | **D1** — SwiftData batch write off the main actor | First sync, onboarding | **removes multi-second first-sync hang**; 5-30 ms steady state | High | Critical | `HealthKitManager.swift`, `HealthDataBatchWriter.swift` (new ModelActor) |
| 7 | **S1** — `smartDailyAction` out of HomeView's body | Today | **removes a SwiftData fetch + 2 UserDefaults writes from inside a frame**, plus one full body+layout pass (~0.34 ms) | Low | Critical | `DashboardViewModel.swift`, `HomeView.swift` |
| 8 | **C1** — extract MetricChartView's crosshair | Metric Detail | **scrub 2-6 ms/touch typical, 8-20 ms at 365 d** → near-zero | Medium | Critical | `MetricChartView.swift` |
| 9 | **M2** — split the second `MainActor.run` block | Today, Biology | **removes ~15-40 ms hang** per refresh (concatenates with #4) | Medium | High | `DashboardViewModel.swift`, `WidgetDataStore.swift`, `TodayScoreLiveActivityManager.swift` |
| 10 | **ST5** — detach the 14 backfill replays | First launch, all tabs | **removes up to 14 full analysis replays** from the launch main thread | Low | High | `DashboardViewModel.swift` |
| 11 | **R1a** — tab-bar shadow off the material | **Every screen, iOS 17-25** | ~0.1-0.3 ms/scroll frame everywhere, incl. both problem feeds | Medium | High | `CustomTabBar.swift` |
| 12 | **N2** — delete `withAnimation` from the tab switch | All 4 tabs, iOS 17-25 | **removes 320 ms of dual-tree composition per tab tap** | Low | High | `CustomTabBar.swift` |
| 13 | **R1b** — remaining 6 shadow sites | Metric/Vitality/Strain Detail, Weekly Bar | ~0.1-0.3 ms per scrub frame × 4 tooltips; ~0.5-2 ms/frame on Strain + Vitality heroes | Low | High | 5 files, one line each |
| 14 | **M3** — circadian: 90-day window + detach | Today, Biology | **removes 5-15 ms hang** per refresh | Low | High | `CircadianHealthAnalyzer.swift`, `DashboardViewModel.swift` |
| 15 | **R2 + R3** — Vitality orb: phase from timeline, async Canvas, resolve colours | Vitality detail | halves both gaussians and the 81-pt trig solve; **~2-6 ms/frame → ~1-3**; unblocks locked 60 on that screen | Medium | High | `VitalityOrganicOrb.swift`, `VitalityDetailView.swift` |
| 16 | **ST4** — gate `needsFullCalibration` on persisted freshness | Today first ~10 s | stops a full ML pipeline re-run every cold launch; unblocks `hasCompletedInitialLoad` | Medium | High | `ContentView.swift` |
| 17 | **M5** — colour cache + memoized `UIColor` | App-wide, densest Biology/Today | ~0.1-0.4 ms/Biology pass, **plus restores the Equatable diffing early-out at 186 sites** | Low | High | `RemoteConfigSchema.swift`, `RemoteConfigManager.swift`, `AppColour.swift` |
| 18 | **L1** — `valueForRange` binary search + memo | Category Detail (Biology) | **−2-5 ms per push on Activity**, −1-2 ms Heart; stops growth with history | Low | High | `CategoryDetailViewModel.swift` |
| 19 | **D2** — reuse `mergeSeries`/`updateSeriesCaches` after write | Today, Biology, Explore refresh | **removes ~10-45 ms** of main-actor unindexed scans per refresh | Medium | High | `HealthKitManager.swift` |
| 20 | **M4** — collapse LiveViewModel's publish burst | Today, Live | 4-7 passes → 2-3; **removes visible staggered tile pop-in** on every Home appear | Low | Medium | `LiveViewModel.swift` |

**Just below the line, deliberately:** N1 (Weekly Review VM — Low complexity, High priority, also fixes a content-loss risk), C2 (Strain scrub extraction), S5 (Equatable leaf cards), S6 (hero ring replay), N3 (SettingsView.init). All appear in §4 or §5.

---

# 4. Best gain per unit of effort

Everything here is Low complexity. The first block is **one line or one keyword**.

### One-liners

| Fix | Change | File:line | Why now |
|---|---|---|---|
| ST3 | `if pruneIfNeeded(...) > 0 { invalidateTimeSeriesCache() }` | `AppStartupCoordinator.swift:58-60` + `DataRetentionManager.swift:33-49` | Kills a duplicate whole-table main-thread fetch on **every** launch. Highest ratio in the report. |
| N2 | delete `withAnimation`, scope spring to the pill | `CustomTabBar.swift:31-33` → `:59-63` | 320 ms of dual-tree composition per tab tap, gone, no visual change |
| R1 ×4 | move `.shadow` into `.background { shape.fill().shadow() }` | `MetricChartView.swift:354`, `VitalityTrendSection.swift:180`, `StrainDetailView.swift:430`, `WeeklyBarChart.swift:145` | Pixel-identical — `surfaceOverlay` is verified alpha 1.00 (`AppColour.swift:86-90`) |
| A2 | `0.05` → `0.1` | `OnboardingV2Screens8to13.swift:408` | Halves root-body invalidations during the HealthKit import. One character. |
| CC3 | `.userInitiated` → `.utility` | `AskDataOrbView.swift:459` | One word |
| CC4 | `if Task.isCancelled { return true }` | first line of `MLPipelineRunner.shouldStopForThermal` (`:299`) | Turns seven existing gates into cancellation checkpoints |
| R4a | `if reduceMotion \|\| thermalManager.shouldThrottle` | `AskDataOrbView.swift:82` | Accessibility. Reuses the static branch that already exists. |
| A5(4) | add `@State` | `BreathworkView.swift:158` | Stops tick loss on the meditation screen. One keyword. |
| D8 | honour `lastTieredFetchDate` in `fetchHomeData` | `LiveViewModel.swift:204-206` | Kills 3-6 duplicate HealthKit queries per legacy tab return |
| M7 | `let insights = viewModel.insights` | `CategoryDetailView.swift:92` | 3 pipeline runs → 1 |
| S3 | `let summary = …`, `let templates = …` | `HomeView.swift:493`, `:519` | Two duplicate builds per Home pass, gone |
| S8a | `monthSymbols` → `static let` | `MetricDetailViewModel.swift:95` | It cannot change while the app runs |
| AR2 | `queue: .main` on the observer | `ThermalManager.swift:147-152` | Closes a data race on `@Observable` state |
| D4 | delete the two redundant inner `Task { @MainActor }` | `LiveViewModel.swift:466`, `:591` | Two lines of pure scheduling waste |
| N3 | `.default` + load in the existing `.task` | `SettingsView.swift:51` | Two lines; removes disk+AES+JSON from every iOS 26 nav event |

### One-file changes, High or Critical priority

| Fix | File | Payoff |
|---|---|---|
| ST1 | `LasoApp.swift` | Removes the entire `runInitialSetup` duration from the visible splash. **Safety verified**: `status` defaults to `.unknown`, `shouldEnforcePaywall` only fires on `.expired`, so no paywall flash. |
| M3 | `CircadianHealthAnalyzer.swift` (+1 call site) | 90-day filter + `Task.detached` = 5-15 ms of hang per refresh |
| ST5 | `DashboardViewModel.swift` | Hoist the 14-iteration loop into `Task.detached`; `replay` is already `static` over value types |
| L1 | `CategoryDetailViewModel.swift` | `samples(from:until:)` + a memo cleared in the existing `didSet` at `:19` |
| S1 | `DashboardViewModel.swift` + `HomeView.swift:865` | `@ObservationIgnored` on `:102-103` + compute in `refreshCore` after `:822` |
| M5 | `RemoteConfigSchema.swift` + `RemoteConfigManager.swift` | ~15 lines mirroring `cachedCopy` — but keep `observeFetchUpdates()` on the hit path |
| N1 | `ContentView.swift:547` | Route through HomeView's stable `weeklyReviewViewModel` |
| S6 | `HealthScoreRing.swift` | Fix in the component, not per call site — catches the sites nobody has noticed |
| L3 | `IntradayActivityCard.swift` | Hoist `peak`/`total`, collapse 96 Rectangles into one Shape. Pixel-identical. |

---

# 5. Roadmap

### Day 1 — one engineer, safely shippable same day

Everything in §4's one-liner table, plus:

- **#1** — drop in `Perf.swift` with the five `OSSignposter` intervals and the MetricKit subscriber. Do this **first**, before any fix, so you get a before-baseline.
- **#3** — the prune-cache guard (`@discardableResult -> Int` + one `if`).
- **#12** — delete `withAnimation` from `CustomTabBar`, scope the spring to the pill.
- **#13** — the four tooltip shadow moves (`MetricChartView`, `VitalityTrendSection`, `StrainDetailView`, `WeeklyBarChart`).
- **#14** — circadian 90-day window + `Task.detached`.
- **#2** — the splash detach. It is a few lines and the safety precondition is already verified.
- **#10** — hoist the 14 backfill replays into `Task.detached`.
- **#18** — `valueForRange` binary search + memo.
- **§4 one-liners:** A2, CC3, CC4, R4a, A5(4), D8, M7, S3, S8a, AR2, D4, N3.
- **AR3** — delete the three frozen RC globals in `VitalityDetailHelpers.swift:3-5`.

Ship, then re-record the Day-1 baseline against the Day-0 one.

### Week 1 — structural, needs care, no redesign

- **#7** — `smartDailyAction` out of the body: `@ObservationIgnored` **plus** the compute moved into `refreshCore`.
- **#8** — MetricChartView crosshair extraction (check `MetricSample: Equatable` first; keep `.sensoryFeedback` wired).
- **#9** — split the second `MainActor.run` block; move `writeWidgetSnapshots` off main entirely.
- **#11** — tab-bar shadow-only masked capsule; visual check on iOS 17 **and** iOS 26.
- **#5** — add `loadRecentTimeSeries(days:)`; move the "days of data" reading onto `oldestDataDate` **before** bounding the window.
- **#15** — Vitality orb step 1 (phase and pulse from `timeline.date`, delete `withAnimation`) + `rendersAsynchronously: true` + hoisted resolves.
- **#16** — gate `needsFullCalibration` on `AnalysisEngine.lastAnalysis` (snapshot to a local `let` first).
- **#17** — colour cache + memoized `UIColor`.
- **#19** — reuse `mergeSeries`/`updateSeriesCaches` instead of the post-write re-read.
- **#20** — collapse LiveViewModel's publish burst using the existing counter.
- **N1** — Weekly Review destination via HomeView's stable VM.
- **C2** — Strain scrub extraction (move `isScrubbing` with it) **together with** its hero shadow fix from #13.
- **S6** — hero ring seed/animation split in `HealthScoreRing`.
- **L3, L4** — IntradayActivityCard Shape; calendar `cells`/`today` hoist + VoiceOver gate.
- **CC2** — `inFlightSync` guard on `loadAndSync`.
- **ST6** — defer `CopyOverridesStore.start()` and `analyticsManager.configure()`; split `installCrashHandlers` off the Amplitude guard. **Leave the Facebook hook alone.**

### Month 1 — redesigns

- **#4** — purify the eight scorers: `Sendable` inputs/outputs, all store reads *and* writes lifted to the call site, ordering preserved, one final main-actor batch. Remove the three `MainActor.assumeIsolated` escapes. Start with the two most expensive, measured.
- **#6** — `@ModelActor` writer for the SwiftData batch path, with chunked saves and a verified cache-coherence story.
- **S2** — decompose HomeView into per-card `View` structs; add `Equatable` to `MetricTile` and `RecoveryWhyReason` (**S5**), applying `.equatable()` to MetricStripView and WeekScoreStrip before RecoveryHeroCard.
- **#15 step 2** — move the Vitality orb glow into the Canvas and replace the shadow with a radial gradient. Design sign-off required (`.plusLighter` vs `.screen`, circle vs blob silhouette).
- **R4** — AskDataOrb: static cache or `onDisappear` release, pre-built per-size Paths. Metal `.colorEffect` **only** if it shows in a trace.
- **L2** — LazyVStack conversion for the four screens that qualify, preceded by the `SectionTracker` impression-inflation fix.
- **A5** — Breathwork rewrite: `Text(timerInterval:)` + scoped `TimelineView(.animation)` + one-shot phase timer + Reduce Motion.
- **N4** — nav-path extraction, with UI-test coverage for widget, Live Activity, push and Siri entry.
- **AR1/AR2** — decide on the ProMotion opt-in; add Low Power Mode to `shouldReduceVisualEffects`. Only build a `RenderQuality` tier when a second consumer exists.
- **ST10** — run `DYLD_PRINT_STATISTICS`; act on Firestore only if it dominates.
- **M8** — analytics off the main actor + `sanitizeEventName` memo + buffered section-view events.

---

# 6. Measurement plan

## 6.1 Instrument the code first (half a day, ships in Release)

```swift
// Core/Config/Perf.swift
import OSLog
let perfLog = OSSignposter(subsystem: "com.lasohealth.fit", category: "perf")
```

Five intervals, no more:

| Signpost name | Wrap | Proves |
|---|---|---|
| `launch.didFinishLaunching` | `AppDelegate.swift:11-20` | ST6, ST10 |
| `launch.containerInit` | `AppContainer.swift:31-65` | ST7 |
| `launch.contentViewInit` | `ContentView.swift:27-31` | **ST2** |
| `refresh.mainActorBlocks` | `DashboardViewModel.swift:801` → `:831` | **M1 + M2 + M3 + ST5** |
| `sync.loadAndSync` | `HealthKitManager.swift:269` → `:420` | **D1 + D2 + CC2** |

Pattern: `let s = perfLog.beginInterval("refresh.mainActorBlocks")` / `perfLog.endInterval("refresh.mainActorBlocks", s)`.

MetricKit subscriber (~25 lines, registered in `didFinishLaunching`): implement `didReceive(_ payloads: [MXDiagnosticPayload])`, forward `payload.hangDiagnostics` (`hangDuration` + symbolicated call tree) into the existing `AnalyticsBackend`, and take `MXMetricPayload.applicationLaunchMetrics.histogrammedTimeToFirstDraw` — that is the real field number for ST1/ST2/ST3.

## 6.2 The five traces to take, before and after

Build the exact configuration you ship:

```bash
xcodebuild -project Laso.xcodeproj -scheme Laso -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath build clean build
```

| # | Instruments template | Scenario | Record |
|---|---|---|---|
| 1 | **App Launch** | Cold launch, airplane mode OFF, then repeat with a throttled network (Network Link Conditioner → "Very Bad Network") | Time to first frame; the `launch.*` signpost durations. **The throttled run is the ST1 proof** — the delta between good and bad network is the StoreKit block. |
| 2 | **Animation Hitches** | Scroll Today top→bottom→top three times; repeat on Biology | Hitch time ratio (ms hitch per second of scroll) and the commit-vs-render attribution. Target: hitch ratio < 5 ms/s. |
| 3 | **Time Profiler** (main thread only) | Pull-to-refresh on Today | Total main-thread time inside `refresh.mainActorBlocks`. **This is the M1/M2/M3 number.** |
| 4 | **SwiftUI** (View Body / Properties lanes) | Scroll Today; then push Metric Detail and scrub the chart end-to-end | Body-evaluation counts per view type. Direct proof for S1, S2, S5, C1, C2, C3. |
| 5 | **Allocations** | Open Ask Your Data, leave, return ×3 | Persistent bytes on the `AskDataOrbView` cache. Proves R4's ~13.5 MB and whether the release actually happens. |

Command form (substitute your device UDID and bundle id):

```bash
xcrun xctrace list devices                 # get the UDID
xcrun xctrace record --template 'Animation Hitches' \
  --device <UDID> --output today-scroll-before.trace \
  --launch com.lasohealth.fit
```

## 6.3 The two-second on-device checks

Run the app from Xcode on device, then **Debug → View Debugging**:

- **Color Offscreen-Rendered** — every yellow region is an offscreen pass. This is the one-second confirmation of **all seven R1 shadow sites**, the R2 orb gaussians, R5's four soft-lock blurs and R6's glass banner. Scroll Today and Biology with it on, before and after. Target after R1: **no yellow on the tab bar during scroll.**
- **Color Blended Layers** — red is per-pixel blending. Useful on the orbs and the soft-lock cards.

For body-pass counting without Instruments, drop `let _ = Self._printChanges()` at the top of the body under test — this is the cheapest way to settle C4 (does the duplicate selection writer actually cost a pass?) and S4 (does the `onAppear` cluster really coalesce?).

## 6.4 Launch dyld cost (ST10, before spending any engineering)

Xcode → Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables → add `DYLD_PRINT_STATISTICS = 1`. Launch on device and read the console. If total pre-main is not a meaningful share of time-to-first-frame, close ST10 and never revisit it.

## 6.5 Numbers to record, per fix

| Fix | Metric | Where | Pass condition |
|---|---|---|---|
| ST1 | Time to first content, good vs throttled network | App Launch + MetricKit `histogrammedTimeToFirstDraw` | The good/bad-network delta collapses to ~0 |
| ST2/ST3 | `launch.contentViewInit` duration; count of `loadAllTimeSeries` calls per launch | Signpost + a temporary counter | One call, not two; duration flat as history grows |
| M1/M2/M3/ST5 | `refresh.mainActorBlocks` duration | Signpost + Time Profiler | Under 16.7 ms |
| D1/D2 | `sync.loadAndSync` main-thread time | Signpost + Time Profiler (main thread only) | Main-thread portion near zero |
| R1/R2/R5/R6 | Yellow area during scroll | Color Offscreen-Rendered | No yellow on the tab bar; orb yellow halved |
| C1/C2/C3 | Body evaluations per scrub gesture; hitch ratio during scrub | SwiftUI template + Animation Hitches | Base chart body count → 0 during a drag |
| S1/S2/S5 | HomeView body count per refresh and per scroll-back | SwiftUI View Body lane | Refresh: 2 passes → 1. Scroll-back: 0 new passes. |
| R4 | Persistent bytes after leaving Ask Your Data ×3 | Allocations | Returns to baseline, does not stair-step |
| N2 | Frames with two tab trees composited | Animation Hitches, tab-tap gesture | Zero |
| Field | Hangs per 1,000 sessions, p50/p95 time-to-first-draw | MetricKit → AnalyticsBackend | Both trend down release over release |

---

# 7. Risks and what NOT to do

## 7.1 Fixes in this audit that are wrong as originally proposed

These would ship visual regressions or crashes. Each was corrected in §2; repeated here because they are the ones most likely to be copy-pasted.

- **Do not put an opaque capsule behind the tab bar's material.** `.ultraThinMaterial` samples whatever is behind it; an opaque `surfaceRaised` capsule means the bar stops showing the scrolling content through the glass. `CustomTabBar.swift:3-5` says that refraction is the point of the component. The `cardStyle()` analogy does **not** transfer — a card's background genuinely is opaque, a glass bar's is not. Use the masked backing capsule in R1.
- **Do not add `surfaceRaised` under the Strain hero gradient.** `AppColour.swift:69-78` shows `surfaceBase` at 0.933 vs `surfaceRaised` at 0.973 in light mode — the card gets visibly lighter. Hang the shadow on a `RoundedRectangle.fill(strainGradient)` instead, and accept that a trace of the shadow now shows through the translucent fill (invisible at radius 12 / 0.28 alpha, but check it).
- **Do not merge AskDataOrb's 1,920 particle fills into one Path.** `AskDataOrbView.swift:306` sets `shell.blendMode = .plusLighter`. Under additive blending, N overlapping rects filled separately accumulate at the overlaps; one merged Path paints the union once. Shell-1's 12 ribs sit inside a radial spread of `R * 0.08` at 0.006 rad offsets, so they **do** overlap. Merging visibly dims the densest bands.
- **Do not merge AskDataOrb's blur sub-contexts.** `glow` (`:324`) draws **before** mainRing/blur7/second-ring core; `hotGlow` (`:367`) draws **after** all of them — merging reorders the traveling hotspot glows under the rings. And merging `:430` (R×0.045) with `:438` (R×0.073) shifts both bloom radii by +33 % / −18 %. No adjacent pair shares both blend mode and radius, so **no safe merge exists**.
- **Do not copy `colorMode: .linear` onto the Vitality orb's Canvas** when adding `rendersAsynchronously: true`. It changes blending math for the dark-core radial gradient and the particle fills.
- **Do not pass `animatesOnAppear: false` at the hero ring call sites as the fix.** That flag gates the `.animation` modifier itself at `HealthScoreRing.swift:50`, which also drives `onChange(of: score)` — the ring would **snap** instead of animating when the score genuinely changes, which on Home happens every 30 minutes.
- **Do not `ImageRenderer`-snapshot the soft-locked Home cards.** `RecoveryHeroCard`, `MetricStripView` and `compactAlertBanner` all take live view-model data and keep updating under the blur. A one-shot snapshot freezes them for the session.
- **Do not try to move `ImageRenderer` off the main thread.** It is `@MainActor`-isolated in every rendering entry point, including `render(rasterizationScale:renderer:)` — the CGContext closure body still runs on the main actor.
- **Do not fan the eight scorers out with `Task.detached` before purifying them.** `StressScorer.swift:173` and `VitalityScorer.swift:392` call `MainActor.assumeIsolated { … }`, which **traps** off main. `StrainScorer.swift:257/:414` and `VitalityScorer.swift:838-840` write to the store mid-compute, so concurrent execution is unsafe today.
- **Do not set `MERGED_BINARY_TYPE: automatic`.** Mergeable libraries require dependencies built from source with `MAKE_MERGEABLE`; all 13 embedded frameworks arrive as precompiled xcframeworks. It is a no-op.
- **Do not defer the Facebook `didFinishLaunchingWithOptions` hook** (`AppDelegate.swift:15-18`). Meta's SDK requires it there for SKAdNetwork registration and deferred app-link attribution. `application(_:open:)` at `:71-82` does not substitute. This trades a revenue regression for a few milliseconds, with no crash to tell you.
- **Do not defer `PushNotificationManager.shared.configure()`** without checking the FCM delegate binding — the comment at `AppLaunchCoordinator.swift:35-36` says swizzling maps the APNS token into `Messaging`, and the token callback can arrive before a deferred Task runs.
- **Do not delete `ContentView.swift:326-328`.** On iOS 26 HomeView's identity survives the tab switch, so `onAppear` fetches nothing and that line is the only refresh on tab return. Fix `LiveViewModel.swift:204-206` instead.
- **Do not delete the ExploreView calendar fallback** at `:96-98`. The comment at `:85-95` documents the exact window it covers: core analysis fills `categoryScores` on a background task, so `hasScoreData` can flip true a fetch ahead of the publish, and the calendar flashes empty.
- **Do not hoist that ternary above the ScrollView.** Swift evaluates only the taken branch, so it already runs once per pass; hoisting forces `dailyScoresByDay(366)` on passes that do not render the calendar. Net regression.
- **Do not keep all four tab roots mounted in a ZStack.** Every tab's `onAppear` fires at once, breaking 22 `SectionTracker` impression pairs, `HomeView`'s timer lifecycle (`:113`/`:129` — hidden tabs keep polling HealthKit) and every `trackFeatureOpen`/`trackFeatureClose` pair.
- **Do not add `#Index` to `StoredDailySample`.** It is iOS 18+; `project.yml:4-5` sets a 17.0 floor `[verified]`, and iOS 17 SwiftData exposes no attribute-level index option.
- **Do not use `TimelineView(.animation)` to replace a 60 Hz Timer.** It runs at display refresh rate — up to 120 Hz on ProMotion, i.e. **twice** the wakeups you are removing.
- **Do not chunk the sleep backfill without seam overlap.** Sessions are gap-grouped across the whole array (`HealthKitManager.swift:934-951`), so a night straddling a boundary splits into two and its wake-day attribution moves. That is a data correctness change.
- **Do not build a naive colour cache.** `observeFetchUpdates()` (`RemoteConfigManager.swift:88-91`) must still run on a cache **hit** — it is the SwiftUI dependency edge, and skipping it silently stops live Remote Config repaints.
- **Do not `.equatable()` `RecoveryHeroCard` first.** When `==` returns true SwiftUI keeps the **old** view value including its closures. Verify `onShare` — nil-or-not from a captured `shareTemplates.isEmpty` at `HomeView.swift:519` — does not go stale, or a share affordance stays hidden after a win is earned.

## 7.2 Classic optimisations that would hurt here

- **`.drawingGroup()` on anything containing text.** It rasterizes the subtree into a Metal layer at a fixed scale: text loses subpixel rendering and stops responding to Dynamic Type without a re-render. Use it **only** on the soft-lock blur branch (R5), where the content is already unreadable by design.
- **Rendering the month calendar to an `ImageRenderer` bitmap.** Proposed in one dimension; refuted. A bitmap does not respond to Dynamic Type, resamples on rotation and width change, loses subpixel text, and needs a duplicate invisible hit-testing/accessibility layer kept in sync forever — with a cache key spanning `colorScheme`, width, Dynamic Type **and** both dictionaries, so it would miss often enough to pay the render cost anyway. Verified: `.equatable()` is already applied at `ExploreView.swift:106`; use that, plus the L4 hoists.
- **Premature Metal.** The `.colorEffect`/`.layerEffect` shader rewrite of AskDataOrb is technically the right endgame, but it is a from-scratch look-matching exercise on a 600-line hand-tuned art file, for a screen users open deliberately and infrequently, whose Canvas already runs off the main thread (`:90`) and is paused off-screen (`:87`). Do it only if it shows in a real trace.
- **Over-caching.** Every new cached property is a new invalidation source working against S2, plus a staleness bug waiting to happen. Specifically **skip**: `cachedSignalCoverage` (already binary-searched, `DashboardViewModel.swift:2663-2668`), `CategoryDetailViewModel.insightCache` (capped at 15 items, tens of µs, would need keying on `analysisEngine.lastAnalysis`), a UUID-keyed cache on `MetricDetailViewModel` (three stored properties plus a token for ~0.3 ms on a non-frame path), `shareTemplatesCache` (microseconds, two invalidation triggers), and precomputing `hasGlow: Bool` onto `ParticleSeed` (one float compare, ~160 ns/frame).
- **Converting computed properties to `didSet`-backed stored properties on `MetricDetailViewModel`.** `trend`, `baseline`, `insights` and `historicalContext` all read through to `AnalysisEngine` and would go stale when a background phase republishes — which a `didSet` on `selectedTimeRange` never observes.
- **Capping the HealthKit fan-out at 8 concurrent.** HealthKit serializes on its own daemon regardless; adding a `group.next()` throttle to a working task group is complexity that should follow a measurement, not precede it.
- **Persisting `HKQueryAnchor` through `NSKeyedArchiver`.** A new stateful mechanism with stale-anchor-after-reset and schema-migration failure modes, bought for a query that returns a few dozen samples on the Live tab.

## 7.3 Visual regressions to watch for, per fix

| Fix | What to check | Where |
|---|---|---|
| R1 tab bar | The bar still refracts scrolling content behind it | iOS 17 **and** iOS 26, light and dark |
| R1 Strain hero | Card colour unchanged; shadow bleed-through invisible | Light and dark |
| R1 Vitality hero | Shadow must sit on `.fill()` **before** `.overlay()` — after it fixes nothing | — |
| R2 step 2 | Glow ring shape (`.plusLighter` vs `.screen`, blob vs circle silhouette) | Design sign-off |
| R6 | Banner reads slightly flatter without the glass tint | Light and dark, first 8 days |
| S6 | The ring still animates when the score genuinely changes (30-min readiness timer) | Today, wait for a real update |
| MM1 | Shared PNG at scale 2 (780×1386) with a user photo in a template card | Both live share sites |
| A3 | The Discovery circle stops breathing | First-run flow |
| R7 | Mach band at `endRadius` reappears if the blur is removed | All 10 ambient cases |
| ST9 | Returning users see stale numbers instead of a loader — needs a refresh affordance | Today, cold launch |
| C5 | Sparkline curve preserved (not a polyline) if the Canvas rewrite happens | 3 detail screens |
| M4 / D-series | Tiles filling together instead of popping in is the **intended** change | Today, foreground return |
| L2 | `LazyVStack` cross-axis sizing differs from `VStack` — check `BrainHealthDetailView.swift:21-22` | Every converted screen |
| N2 | The pill still slides with the same spring; only the screen swap becomes instant | All 4 tabs, iOS 17-25 |

---

**One closing caveat, stated plainly.** Nothing in this report was profiled. The three largest figures in it — 300-500 ms for the scorers, 883 ms for the shadow pattern, 88 ms for the calendar — are all code comments written by the team, and at least one of them (88 ms) predates optimizations that have since landed in the same file. Rank 1 exists because of that. Take the Day-1 baseline before you change anything, and re-measure after each block.

Confidence: 88/100 — every finding below is anchored to a file:line and the four load-bearing facts I could cheaply re-verify were re-verified this session (`.equatable()` count and location, the missing ProMotion opt-in, the iOS 17.0 floor, the single `View, Equatable` conformance); the remaining ~105 findings are carried forward from the audit's corrected fields and were not independently re-opened, no Instruments trace was taken, and no code was built or run, so every millisecond figure is reasoned rather than measured. | Source: mixed: user-statement+code
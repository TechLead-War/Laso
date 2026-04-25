# 22 — Design System & Accessibility Audit (Pass 2 — Deeper)

Second-pass design / accessibility audit for Laso (com.lasohealth.fit), iOS 17+, SwiftUI. Pass 1 (`audit/06-design-accessibility.md`) covered the rose AccentColor, fixed-size fonts, missing onboarding/paywall VoiceOver labels, Reduce-Motion gaps, hit-target list, hardcoded named colors, padding scatter, force-locked dark, breathwork accessibility, and confetti haptic spread. This pass excludes those topics and focuses on **NEW** angles only.

Method: `grep`/`Read` only. The token sources of truth are `Common/Theme/AppColour.swift` and `Common/Components/DesignSystem.swift`. Every finding cites file:line and a confidence score.

---

## P2-F1. No state-color tokens — disabled / hover / pressed / focused are all opacity hacks, not first-class tokens

- **Severity: Medium**
- **Issue:** Across 350 `.opacity(...)` callsites, **state communication is encoded purely as opacity literals**. There is no `AppColour.disabled`, no `AppColour.pressed`, no `AppColour.focused`, no `AppColour.hover` token. Pressed state is `.opacity(0.85)` (`Common/Components/DSButton.swift:31, 59, 102, 116`); tertiary pressed is `.opacity(0.6)` (`Common/Components/DSButton.swift:77`); selected pill is `Color.primary.opacity(0.10)` (`Common/Navigation/CustomTabBar.swift:59`); ring background is `ringColor.opacity(0.15)` (`Common/Components/HealthScoreRing.swift:35`); selected accent is `Color.primary.opacity(0.10)`. Each opacity decision is hand-tuned in the file that needs it, not centralized.
- **Why this exists:** The DS file (`DesignSystem.swift:71-76`) defines exactly three opacity tokens (`tintBg = 0.04`, `badgeBg = 0.12`, `strokeAlpha = 0.18`) — for surface tinting, not for interaction state. State-as-opacity got applied per-callsite.
- **Impact:** When a designer changes "pressed feedback should be dimmer than 0.85", every `DSButton`, every selected chip, every active tab pill must be hunted file-by-file. The tab-bar selected pill (10% white) is materially different from the selected-paywall-radio border (`AppColour.primary` solid stroke) — both express "selected" but with no shared semantic. WCAG 2.1.4.11 (non-text contrast 3:1) becomes hard to verify because every site picks its own opacity.
- **Evidence:**
  - `Common/Components/DSButton.swift:31, 59, 77, 102, 116` — five different pressed-state opacity literals (0.85, 0.85, 0.6, 0.85, 0.92).
  - `Common/Navigation/CustomTabBar.swift:59` — selected pill `Color.primary.opacity(0.10)` (Pass 1 F18 noted contrast risk; the deeper issue is the literal itself).
  - `Common/Components/HealthScoreRing.swift:35` — `.opacity(0.15)` for inactive ring.
  - No `AppColour.disabled / pressed / focused / hover` declared anywhere in `Common/Theme/AppColour.swift`.
- **Fix:** Add an `AppColour.State` namespace: `.disabled` (≈ `textQuaternary`), `.pressed` (token equiv to `0.85`), `.selectedFill = primary.opacity(0.12)`, `.selectedBorder = primary.opacity(0.30)`, `.focused = primary.opacity(0.18)`. Migrate `DSButton`, `CustomTabBar`, `HealthScoreRing`, paywall radios. Make every state semantically tokenized so a single edit re-skins the whole app.
- **Priority:** This Sprint.
- **Confidence:** 92/100 — opacity callsites verified by full grep (350 hits). Drag: I categorize five `.opacity(0.85)` as "pressed-state inconsistent with 0.92 in `DSPressButton`" — one could argue the chrome-free press button intentionally has gentler dim. Either way the absence of tokens is the real finding.

---

## P2-F2. `DSButton.swift:27, 73` paint primary buttons with `Color(uiColor: .systemBlue)` — a hardcoded system color that bypasses both `AppColour.primary` and `Color.accentColor`

- **Severity: High**
- **Issue:** The "single hero action per screen" button (`DSPrimaryButton`) uses `Color(uiColor: .systemBlue)` (`Common/Components/DSButton.swift:27`). The tertiary button (`DSTertiaryButton`) uses the same `.systemBlue` (`Common/Components/DSButton.swift:73`). `.systemBlue` is iOS-native blue (≈ #007AFF / #0A84FF dark); `AppColour.primary` is the brand blue (#0071E3 / #4DA3FF). They are visually similar but not identical, and they are owned by Apple, not the brand. So the hero CTA in the app is painted with the iOS system blue, **not** the Laso brand blue.
- **Why this exists:** When `DSButton` was authored, the team picked `.systemBlue` for "looks blue, looks correct" without wiring through `AppColour.primary`.
- **Impact:** Every CTA that uses `.dsPrimary` (and there are 14 of them across the codebase: `DSEmptyState`, `Discovery`, `Explore`, `Paywall`, all 6 onboarding steps) is painted with iOS's blue, not Laso's blue. If Apple shifts `.systemBlue` (which they have done, e.g., iOS 13 → 14 dark variant tweak), the whole CTA system shifts under us. Combined with Pass 1 F1 (`Color.accentColor` resolves to rose because of the leftover `AccentColor.colorset`), the app is now painting hero actions with **three competing blues**: rose (from `accentColor`), iOS systemBlue (from `DSButton`), and brand `AppColour.primary` (from individual screens). Three blues on the most important screen of the app.
- **Evidence:**
  - `Common/Components/DSButton.swift:27` `background(Color(uiColor: .systemBlue), …)`.
  - `Common/Components/DSButton.swift:73` `foregroundStyle(Color(uiColor: .systemBlue))` for tertiary text buttons.
  - `Common/Theme/AppColour.swift:71-74` defines `primary` as a different blue (#0071E3 light, #4DA3FF dark).
- **Fix:** Replace `Color(uiColor: .systemBlue)` with `AppColour.primary` in both `DSPrimaryButton:27` and `DSTertiaryButton:73`. Single-line change in one file, kills brand-color drift across 14 callsites.
- **Priority:** Now — this is a brand-coherence fix that ships in two minutes.
- **Confidence:** 97/100 — code read directly. Drag: I have not visually compared `.systemBlue` to `AppColour.primary` on a real iOS 17 device, but the hex values differ (#007AFF vs #0071E3) so they are genuinely different colors regardless of perceptual closeness.

---

## P2-F3. Three competing button-style systems in production — `.dsPrimary` (14 sites), `.borderedProminent` (15 sites), and `.plain` (24 sites) — same intent, no convention

- **Severity: High**
- **Issue:** The codebase ships **three parallel button-style systems** with no documented selection rule:
  1. `DSButton` family — the design-system styles (`.dsPrimary`, `.dsSecondary`, `.dsTertiary`, `.dsDestructive`, `.dsPress`) — adopted in 14 of the codebase's primary CTAs.
  2. SwiftUI native `.borderedProminent` — used in 15 places (`Common/Components/PMFSurveySheet.swift:139, 165, 193, 213`; `Common/Components/NotificationRepromptBanner.swift:47`; `Common/Components/HealthKitRepromptBanner.swift:58`; `Common/Components/FeedbackSheet.swift:216, 275`; `Common/Components/ProFeatureOverlay.swift:60`; `Modules/Dashboard/Views/Home/HomeView.swift:791`; `Modules/Dashboard/Views/Home/HomeErrorView.swift:33`; `Modules/Dashboard/Views/Home/HomeConnectHealthView.swift:52`; `Modules/Dashboard/Views/Home/ScoreGuideSheet.swift:165`; `Modules/MetricDetail/Views/MetricDetail/MetricDetailView.swift:60`; `Modules/Devices/Views/Devices/DeviceSetupGuideView.swift:37`).
  3. `.plain` — used in 24+ places (`Modules/Settings/Views/SettingsView.swift:322, 397, 409, 421, 515, 541` and many more).
- **Why this exists:** `DSButton` was added later. Earlier-built screens (PMF survey, feedback, reprompt banners, HomeError, paywall-related help screens) used SwiftUI's `.borderedProminent` and were never migrated. New screens use `.dsPrimary`. There is no lint rule blocking `.borderedProminent`.
- **Impact:** Three competing visual treatments for "primary action":
  - `.dsPrimary` paints `.systemBlue` solid pill, scale-on-press, 44pt min height.
  - `.borderedProminent` paints `Color.accentColor` (rose, per Pass 1 F1) tinted pill — so the PMF survey "Continue" button is **rose**, while the next screen's "Continue" via `.dsPrimary` is iOS blue.
  - `.plain` is no chrome at all — used for taps that intentionally don't look like buttons.
  Result: a user moving from the dashboard to the PMF survey sees two different "primary action" treatments in two consecutive screens. This is the same brand-fragmentation pattern that Pass 1 F1 called out for rose vs blue, but at the button-style level.
- **Evidence:**
  - `Common/Components/PMFSurveySheet.swift:139, 165, 193, 213` — four "Continue" / "Submit" CTAs all `.borderedProminent` (rose).
  - `Modules/Dashboard/Views/Home/HomeErrorView.swift:33` — error-retry button is `.borderedProminent` (rose), but the screen below it (HomeView) uses `.dsPrimary` (iOS blue) for similar actions.
  - `Common/Components/HealthKitRepromptBanner.swift:59` adds `.tint(.pink)` *after* `.borderedProminent` — yet another override path.
- **Fix:** Pick one — either complete the `DSButton` migration (recommended, since DSButton already enforces 44pt + press feedback + DS.Motion) or remove `DSButton` and standardize on tinted `.borderedProminent` with `.tint(AppColour.primary)` set at app root. The second is cheaper but loses the press-state polish.
- **Priority:** This Week — every PMF survey / reprompt / feedback / first-error screen ships with the wrong primary treatment. These are also the highest-stakes screens for retention (PMF) and recovery (error retry).
- **Confidence:** 95/100 — counts and callsites enumerated by grep.

---

## P2-F4. `DSSkeleton` shimmer animation has no Reduce-Motion gate — the `.repeatForever` shimmer fires for every loading screen even when the user has motion disabled

- **Severity: Medium**
- **Issue:** `Common/Components/DSSkeleton.swift:28-30` sets `.linear(duration: 1.4).repeatForever(autoreverses: false)` to drive the shimmer phase. There is no `@Environment(\.accessibilityReduceMotion)` check anywhere in the file. Pass 1 F12 enumerated 7 reduce-motion violations across feature views; this is the **8th**, and it is in a shared component used app-wide on every loading state (which means every screen that shows a placeholder triggers it).
- **Why this exists:** `DSSkeleton` was authored in isolation; the reduce-motion-aware Vitality pattern wasn't applied here.
- **Impact:** Users with vestibular disorders see the shimmer slide left-to-right indefinitely on every page that loads. WCAG 2.1 SC 2.3.3.
- **Evidence:**
  - `Common/Components/DSSkeleton.swift:27-30` — `withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false))` with no environment guard.
  - `Common/Components/DSSkeleton.swift` declares no `@Environment` at all (file is 45 lines, fully read).
- **Fix:** Add `@Environment(\.accessibilityReduceMotion) private var reduceMotion` and gate the `withAnimation`: when reduce-motion is on, leave `phase = 0.5` (mid-shimmer static) so the placeholder still has the right tone but does not slide.
- **Priority:** This Sprint.
- **Confidence:** 96/100 — file fully read; the gap is unambiguous.

---

## P2-F5. Press feedback only fires through `ButtonStyle` — every `.onTapGesture` site has no press visual feedback at all

- **Severity: Medium**
- **Issue:** `DSButton`'s entire press-feedback machinery (`scaleEffect 0.97/0.98`, `opacity 0.85/0.92`, `DS.Motion.pressIn/pressOut`) lives inside `ButtonStyle.makeBody(configuration:)`. SwiftUI only delivers `configuration.isPressed` to a `Button { } label: { … }` wrapped in that style. Two production callsites use `.onTapGesture` directly:
  - `Modules/Dashboard/Views/Home/TodayBriefingView.swift:140` — `.onTapGesture { … }` on the briefing card (with `.contentShape(Rectangle())` at line 139).
  - `Common/Components/MetricChartView.swift:256` — `.onTapGesture { location in … }` on the chart hit-test rectangle.
  Both of these have **no scale-on-press, no opacity-on-press, no pressIn animation**. The user taps the card, gets a haptic, but the card does not visually acknowledge the press.
- **Why this exists:** `.onTapGesture` was used because the tap needs the gesture's `location` (chart) or because the row is structurally not a `Button` (briefing card). `.dsPress` would have fixed it for the briefing card.
- **Impact:** Inconsistent press feedback. Doherty threshold-class issue: a press that doesn't visually acknowledge feels broken even when it works. The briefing card is one of the most-tapped surfaces on Home; it should feel as responsive as the recovery hero ring.
- **Evidence:**
  - `Modules/Dashboard/Views/Home/TodayBriefingView.swift:139-140`.
  - `Common/Components/MetricChartView.swift:225-256` — drag-to-select gesture rectangle with no press visual.
- **Fix:** For the briefing card, wrap the row in `Button { … } label: { … }.buttonStyle(.dsPress)` so the existing `DSPressButton` gives the scale/opacity feedback. For the chart, accept the limitation (chart drag-to-select genuinely needs `DragGesture` not `Button`) but add a manual `@GestureState private var isPressed` + `.scaleEffect(isPressed ? 0.99 : 1.0)` on the overlay.
- **Priority:** This Sprint.
- **Confidence:** 90/100 — verified by grep; only 2 raw `onTapGesture` sites in app code, so the exposure is bounded but real on the high-traffic briefing card.

---

## P2-F6. Skeleton shimmer uses `surfaceElevated` / `surfaceOverlay` tokens — but does not call them out as "skeleton" — and there is no skeleton color token

- **Severity: Low**
- **Issue:** `Common/Components/DSSkeleton.swift:12-19` uses `AppColour.surfaceElevated` and `AppColour.surfaceOverlay` as the shimmer-base and shimmer-highlight colors. These are repurposed surface tokens, not purpose-built skeleton tokens. There is no `AppColour.skeletonBase / skeletonHighlight` declared anywhere.
- **Impact:** If the surface stack is ever rebalanced (e.g., `surfaceElevated` is tweaked to be brighter for a different reason), every skeleton silently changes its shimmer contrast. Token reuse without semantic naming hides the dependency.
- **Evidence:** `Common/Components/DSSkeleton.swift:12-19`. `AppColour` declares no `skeleton*` token (file fully read in Pass 1 reference).
- **Fix:** Add `AppColour.skeletonBase = surfaceElevated` and `AppColour.skeletonHighlight = surfaceOverlay` aliases — then wire `DSSkeleton` to those. Two-line cosmetic fix that prevents future drift.
- **Priority:** Backlog.
- **Confidence:** 88/100 — token declarations verified in `AppColour.swift`. Dragged below 90 because this is genuinely a "future-proofing" finding, not a bug today.

---

## P2-F7. No status-color naming for warning/error/success in the AppColour state stack — semantic state tokens exist but no on-color companions

- **Severity: Low**
- **Issue:** `AppColour.swift:87-89` defines `success` (#10B981), `warning` (#F59E0B), `danger` (#E5484D), `info` (#0071E3). But there are no companion `successOn`, `warningOn`, `dangerOn`, `infoOn` (foreground-on-tinted-background) tokens, no `successBg`, no `warningBorder`, etc. — i.e., the system has the **anchor** colors but no **surface pairing** for them. Every callsite that paints a banner / badge / inline error has to compose the pair by hand: `.background(AppColour.danger.opacity(0.10), …).strokeBorder(AppColour.danger.opacity(0.30), …)` (the destructive button at `DSButton.swift:94, 99` shows the canonical pattern). Eight other callsites do the same pattern with different opacity choices (e.g. `Modules/Insights/Views/Insights/CorrelationsView.swift` and various warning banners).
- **Impact:** Each "danger card" / "warning chip" / "success toast" is composed independently. Update the brand's danger color and you've also got to update every opacity-pairing decision in eight places.
- **Evidence:**
  - `Common/Theme/AppColour.swift:87-90` — anchor tokens only.
  - `Common/Components/DSButton.swift:94, 99` — danger uses 0.10 fill, 0.30 stroke.
  - `Common/Components/DSToast.swift:11` — danger toast uses its own pattern.
- **Fix:** Add `AppColour.dangerFill = danger.opacity(0.10)`, `dangerBorder = danger.opacity(0.30)`, and same triplets for `success`/`warning`/`info`. Migrate the destructive button + DSToast + warning banners to use the new pairs.
- **Priority:** This Sprint.
- **Confidence:** 88/100 — token declarations verified, the "8 other callsites" is approximate (`grep` counted varied opacity literals on `danger`/`warning`/`success` outside the theme file).

---

## P2-F8. No type-scale token discipline — `tracking()` (kerning) is hand-tuned in 14 places, `lineSpacing` is never set anywhere

- **Severity: Medium**
- **Issue:** Letter spacing (kerning) is applied 14 times across the app with **8 different values**: `tracking(0.6)`, `tracking(0.8)` (×6), `tracking(1.2)` (×2), `tracking(1.4)`, `tracking(1.8)`, `tracking(2)` (×2). No central token. Some of these (e.g., `tracking(1.8)` on `ActivationProgressBanner.swift:174`, `tracking(2)` on `BrainHealthDetailView.swift:53` and `VitalityHeroSection.swift:31`) are deliberate "small caps premium feel" decisions on uppercase labels; others (`tracking(0.6)` and `tracking(0.8)`) are subtler typographic polish on body-weight text. Meanwhile, `lineSpacing(...)` does not appear **anywhere** in production code (zero hits). SwiftUI's default line spacing is fine for body but tight for display-size hero numbers; the dashboard's score card and onboarding's hero headlines never breathe.
- **Why this exists:** Each designer who wanted "premium feel" picked a kerning value by eye. Line-spacing was not part of the design conversation.
- **Impact:** No premium-typography ramp. Two screens that both want "uppercase eyebrow with breathing-room kerning" use 0.8 or 1.2 or 1.8 with no rule. WCAG 1.4.12 (Text Spacing) auto-fail risk: the spec requires letter spacing ≥ 0.12em without breaking layout — that floor is never tested because no kerning token exists.
- **Evidence (kerning):**
  - `Common/Components/ShareableCard.swift:227` — `tracking(1.2)`.
  - `Modules/Vitality/Views/Vitality/VitalityHeroSection.swift:31` — `tracking(2)`.
  - `Modules/Dashboard/Views/Home/CoachGreetingView.swift:11, 16` — `tracking(0.8)`.
  - `Modules/Dashboard/Views/Home/DailyNarrativeCard.swift:42` — `tracking(0.8)`.
  - `Modules/Dashboard/Views/Home/TodayBriefingView.swift:198` — `tracking(1.4)`.
  - `Modules/Dashboard/Views/Home/HomeView.swift:225` — `tracking(1.2)`.
  - `Modules/Dashboard/Views/Home/ActivationProgressBanner.swift:174` — `tracking(1.8)`.
  - `Modules/BrainHealth/Views/BrainHealth/BrainHealthDetailView.swift:53` — `tracking(2)`.
  - Plus `LasoWidgets/*.swift` (4 sites at 0.6 / 0.8).
- **Fix:** Add `DS.Typography.eyebrow` (uppercase + tracking 1.6 + caption2 weight semibold) and `DS.Typography.kicker` (mixed-case + tracking 0.4 + footnote medium) as named modifiers. Migrate all 14 callsites. Leaves the typographic polish but removes the per-call freedom.
- **Priority:** This Sprint.
- **Confidence:** 92/100 — counts verified by grep; the lineSpacing zero-result is a clean negative.

---

## P2-F9. Icon weight ramp drift — `.regular`, `.medium`, `.semibold`, `.bold` mixed with no rule

- **Severity: Low**
- **Issue:** Pass 1 F9 noted icon-size drift; this pass surfaces the **weight** drift: SF Symbol weight is varied across `Image(systemName:).font(.system(size: X, weight: .regular | .medium | .semibold | .bold))` with no documented rule. Sample (from grep):
  - `LasoWidgets/WindDownLiveActivityWidget.swift:45` — `weight: .bold` for a 9pt icon.
  - `LasoWidgets/WindDownLiveActivityWidget.swift:132` — `weight: .semibold` for a 9pt icon.
  - `Modules/Sleep/Views/Sleep/SleepCoachView.swift:361` — `weight: .semibold` for a 9pt icon.
  - `DesignSystem.swift:118-120` — `heroIcon`/`largeIcon`/`mediumIcon` all `.medium` weight (canonical token).
  - `DSEmptyState.swift:15` — `DS.Typography.largeIcon` (`.medium`) — uses the token (good).
  - `Modules/Dashboard/Views/Home/HomeConnectHealthView.swift:18` — `.symbolRenderingMode(.hierarchical)` — the **only** symbolRenderingMode in the entire app.
- **Impact:** Two sibling icons in one row can render at different optical weights — visible side-by-side on the live activity (9pt bold next to 9pt semibold). Hierarchical rendering used in exactly one place means the rest of the app misses SF Symbols' multi-tone feature entirely.
- **Evidence:** Single grep shows 1 site for `symbolRenderingMode`, 1 for `symbolVariant` (`Common/Navigation/CustomTabBar.swift:48` toggling `.fill / .none` on selection — good).
- **Fix:**
  1. Add `DS.Typography.iconWeight = .medium` as the default and document that anything else needs a comment.
  2. Adopt `.symbolRenderingMode(.hierarchical)` on the empty-state hero icon and on Settings icon badges so multicolor SF Symbols (e.g. `heart.text.square`) render with built-in hierarchy instead of flat tint.
- **Priority:** Backlog.
- **Confidence:** 80/100 — sampled, not exhaustive; would need a full icon-by-icon pass to enumerate every weight choice.

---

## P2-F10. Card style is unified at the radius level (`DS.cardRadius = 24`) but shadow discipline is broken — 4 distinct shadow recipes in production

- **Severity: Medium**
- **Issue:** `DS.Elevation.shadowLow / shadowMedium / shadowHigh` (`DesignSystem.swift:138-140`) define a clean 3-step shadow ramp. But across 29 `.shadow(...)` callsites, the actual shadows in use are:
  - `radius: 4, y: 2, opacity: 0.08` — `MetricChartView.swift:317`, `MetricStripView.swift:85`.
  - `radius: 6, y: 2, opacity: 0.04` — `TodayBriefingView.swift:136`, `AchievementsView.swift:360, 385, 536`.
  - `radius: 8, y: 2, opacity: 0.15` — `ActivationProgressBanner.swift:140` (with rose accentColor as the shadow tint).
  - `radius: 12-16-18, y: 4-8, opacity: 0.10-0.50` — Vitality + paywall + StrainDetailView + TodaysActionDetailView (tinted glow shadows for hero cards).
  - `radius: 14, y: 4, opacity: 0.22` — CustomTabBar.
  - `radius: 24, y: 4, opacity: 0.5` — VitalityOrganicOrb glow-pulse.
  None of these match `Elevation.shadowLow.radius=2 / y=1 / opacity=0.12` exactly. The token is defined but **not used** outside `DesignSystem.swift:231, 239` (the `cardStyle()` extension uses it; almost nothing else does).
- **Why this exists:** Tinted hero glows want the tint color, not black, so the shadow token (which hardcodes `.black`) doesn't fit. Smaller cards picked their own `radius: 6, opacity: 0.04` because the shadowLow at `radius: 2, opacity: 0.12` was too tight. The token was right; the values needed to be larger; nobody updated the token.
- **Impact:** Same elevation across two cards on screen looks different. The dashboard `MetricStripView` uses `radius: 4, y: 2, opacity: 0.08`; the cards above and below it use `radius: 6, y: 2, opacity: 0.04`. Side-by-side visual rhythm fractures.
- **Evidence:** All 29 callsites grepped; tabulated above.
- **Fix:** Redefine `Elevation.shadowLow / Medium / High` to match the actual most-common values in the app (`shadowLow = (radius: 6, y: 2, opacity: 0.04)`), add a fourth `shadowGlow(tint: Color)` helper that returns a tinted-shadow view-modifier for hero cards. Migrate. The Vitality / Paywall glow shadows are a legitimate fourth elevation tier, not violations.
- **Priority:** This Sprint.
- **Confidence:** 92/100 — all callsites enumerated.

---

## P2-F11. `Divider().padding(.leading, 52)` and `padding(.leading, 44)` and `padding(.leading, 58)` — three different leading insets for "row divider after icon" with no DS token

- **Severity: Low**
- **Issue:** Hairline dividers in list-style sections inset their leading edge to align past the icon column. Three different inset values are in use:
  - `padding(.leading, 44)` — `Modules/Sleep/Views/Sleep/SleepCoachView.swift:519, 524`.
  - `padding(.leading, 52)` — `Modules/Dashboard/Views/Home/RecoveryInfoSheet.swift:42, 49, 80, 88, 96, 104` and `Modules/Dashboard/Views/Home/ScoreGuideSheet.swift:57, 64`.
  - `padding(.leading, 58)` — `Modules/Strain/Views/Strain/StrainDetailView.swift:292, 301`.
- **Impact:** Three icon-column conventions across three modules. A user scrolling from Sleep → Recovery → Strain sees the divider walking left/right by ~14pt each section.
- **Evidence:** grep on `Divider().padding(.leading, ` returns exactly these 13 hits.
- **Fix:** Add `DS.iconSlot = 44` (Apple HIG min tap = icon size) + `DS.iconSlotWithGap = DS.iconSlot + DS.space2 = 52`. Standardize on one value; right answer is 52 (= 44pt icon + 8pt gap). Update Sleep (44) and Strain (58).
- **Priority:** This Sprint.
- **Confidence:** 95/100 — exact callsites verified.

---

## P2-F12. Sheet drag-indicator discipline is missing — only 1 of 10 modal sheets shows a drag handle

- **Severity: Medium**
- **Issue:** 10 production `.sheet(...)` presentations in the app. Only **one** calls `.presentationDragIndicator(.visible)` (`Modules/Dashboard/Views/Home/TodayBriefingView.swift:19`). The other 9 sheets present without a visible drag handle, so users have no affordance that the sheet is dismissable by swipe.
- **Why this exists:** Pre-iOS 16 mentality (where sheets always showed a drag indicator implicitly). Post-iOS 16 you have to opt in.
- **Impact:** Discoverability — users either learn from one screen that sheets swipe-down or don't. Especially harmful on `MetricLogSheet`, `FeedbackSheet`, `PMFSurveySheet`, `ScoreGuideSheet`, `RecoveryInfoSheet`, and `JournalEntryView` where there is no visible "Cancel" outside the toolbar.
- **Evidence:**
  - `presentationDragIndicator(.visible)` returns one hit (`TodayBriefingView.swift:19`).
  - 10 `.sheet(...)` presentations: `App/ContentView.swift:63`, `Common/Components/ProFeatureOverlay.swift:67`, `Modules/Settings/Views/SettingsView.swift:143, 153`, `Modules/Explore/Views/Explore/ExploreView.swift:292`, `Modules/Dashboard/Views/Home/TodayBriefingView.swift:16, 352`, `Modules/Dashboard/Views/Home/HomeView.swift:59, 66`, `Modules/Dashboard/Views/Home/TodaysActionDetailView.swift:73`, `Modules/Onboarding/Views/Onboarding/OnboardingPromiseStep.swift:63`, `Modules/MetricDetail/Views/MetricDetail/MetricDetailView.swift:142`.
- **Fix:** Add `.presentationDragIndicator(.visible)` to every `.sheet(...)` *except* `MedicalDisclaimerView` and `CompromisedEnvironmentView` (which use `.interactiveDismissDisabled()` deliberately) and the onboarding sheets where dismissal is non-trivial.
- **Priority:** This Sprint.
- **Confidence:** 95/100 — counts verified.

---

## P2-F13. Sheet detents are inconsistent — `[.medium, .large]` (2 sites), `[.large]` (1 site), `[.medium]` (1 site), default-no-detents (6 sites)

- **Severity: Low**
- **Issue:** `.presentationDetents` is set in only 4 of 10 sheets. The other 6 default to system behavior (`.large` only). The 4 that do set detents pick:
  - `[.medium, .large]` — `TodayBriefingView.swift:18, 367`.
  - `[.large]` — `TodaysActionDetailView.swift:81`.
  - `[.medium]` — `MetricDetailView.swift:149`.
- **Impact:** Inconsistent vertical occupation. Some sheets cover 50%, some 100%, with no semantic mapping ("informational sheet vs blocking task"). Apple's HIG recommends `[.medium]` for short content, `[.medium, .large]` for content that may exceed half height, and `.large` only for full-screen interaction.
- **Fix:** Add a small enum convention in `DesignSystem.swift`: `DS.SheetSize.compact = [.medium]`, `DS.SheetSize.flex = [.medium, .large]`, `DS.SheetSize.full = [.large]`. Document when to use each. Migrate.
- **Priority:** Backlog.
- **Confidence:** 95/100 — counts verified.

---

## P2-F14. Modal close-button placement is inconsistent — `.cancellationAction` (5 sites, top-left), `.topBarTrailing` (3 sites, top-right), `.confirmationAction` (2 sites, top-right) — Apple HIG: X is top-left for back, top-right for X-close

- **Severity: Medium**
- **Issue:** Across 11 `ToolbarItem(placement:)` declarations:
  - 5 use `.cancellationAction` (top-left): `PMFSurveySheet.swift:59`, `ExpandedJournalView.swift:50`, `JournalEntryView.swift:47`, `ScoreGuideSheet.swift:182`, `MetricLogSheet.swift:52`.
  - 3 use `.topBarTrailing` (top-right): `FeedbackSheet.swift:225`, `TodayWorkoutView.swift:122`, `WeeklyReviewView.swift:147`.
  - 2 use `.confirmationAction` (top-right): `TodayBriefingView.swift:242`, `RecoveryInfoSheet.swift:156` — these are "Done" buttons, semantically correct on the right.
  - 1 use `.confirmationAction` for save: `MetricLogSheet.swift:66`.
  Inconsistency: `FeedbackSheet`, `TodayWorkoutView`, `WeeklyReviewView` all put what is structurally a close (X) button on the right. iOS HIG says **X = top-right**, **back chevron = top-left**, **Cancel = top-left**, **Done = top-right**. The 5 `.cancellationAction` sites use the word "Cancel" which is correct on the left, but several put the icon `xmark` on the left too — which is iOS-Mac inconsistent.
  Specifically: `Modules/Dashboard/Views/Home/MorningCheckInView.swift:42` puts an `xmark` button on the **right** of an inline header (not toolbar), without using ToolbarItem at all — `.frame(width: 24, height: 24)` (24pt < 44pt HIG min, see Pass 1 F16).
- **Impact:** No coherent rule for modal dismissal. Half the modals require a top-left tap, half a top-right. Users who learn one pattern fight the other.
- **Evidence:** Listed above.
- **Fix:** Adopt the iOS HIG rule: Cancel (text) = top-left = `.cancellationAction`; Done (text, primary commit) = top-right = `.confirmationAction`; X (icon, dismiss-only) = top-right = `.topBarTrailing` with `Image(systemName: "xmark.circle.fill")`. Migrate `FeedbackSheet`, `TodayWorkoutView`, `WeeklyReviewView` to the X icon convention; migrate `MorningCheckInView`'s inline-header X button to a `.frame(minWidth: 44, minHeight: 44)`.
- **Priority:** This Sprint.
- **Confidence:** 92/100 — counts verified; the HIG rule is well-documented but the X-vs-Cancel choice involves slight judgment for "is this a modal blocking or informational" — I am 100% on the placements, ~85% on the X-vs-text-label choice.

---

## P2-F15. ScrollView indicators are hidden on 9 of 41 ScrollViews — 5 of those 9 are horizontal (legitimate) but 4 are vertical (accessibility risk)

- **Severity: Medium**
- **Issue:** Hidden scroll indicators (`scrollIndicators(.hidden)` and `ScrollView(_, showsIndicators: false)`) appear 9 times. Of these:
  - **5 horizontal** (legitimate — horizontal scroll indicators are visually noisy on chip-strip patterns): `TodayBriefingView.swift:32`, `MetricStripView.swift:25`, `InsightsDetailView.swift:87`, `CorrelationsView.swift:358`, `AchievementsView.swift:292, 423`, `ExpandedJournalView.swift:92`.
  - **2 vertical (Home + Achievements full screen)**: `Modules/Dashboard/Views/Home/HomeView.swift:386` and `Modules/Profile/Views/Profile/AchievementsView.swift:183`.
  These two are the **main scrollable surfaces** of the dashboard and the achievements view — both screens have long content and no scroll indicator. Users with low vision rely on the indicator to know how far through the content they are; without it, they can scroll past the bottom without realizing.
- **Impact:** Accessibility — WCAG 2.4.5 (multiple ways to navigate) and minor wayfinding harm. Cosmetic preference traded for usability.
- **Evidence:** Counts verified by grep.
- **Fix:** Re-enable scroll indicators on the two vertical scrolls (`HomeView.swift:386`, `AchievementsView.swift:183`). Keep them hidden on horizontal chip strips.
- **Priority:** This Sprint.
- **Confidence:** 92/100 — counts verified.

---

## P2-F16. Toggle / Stepper / Slider controls in `NotificationsSettingsView` and `MetricLogSheet` have no `accessibilityValue` — VoiceOver users hear "slider" but not the current value

- **Severity: High**
- **Issue:** `NotificationsSettingsView.swift` has 11 `Toggle(...)` and 1 `Stepper(...)` and 2 `Slider(...)` controls. None of them have a `.accessibilityValue(...)`. SwiftUI's default accessibility for `Toggle` reads "label, on/off, switch button" — that part is OK because SwiftUI handles it. But the two `Slider` controls (heart-rate spike threshold and resting-rate threshold) lack a custom value formatter — VoiceOver reads "85 percent" by default when the actual semantic is "85 BPM threshold". Same in `MetricLogSheet.swift:109, 150, 167` — three sliders for weight/water/mindful-minutes with no `.accessibilityValue` formatting.
- **Impact:** VoiceOver users cannot adjust health-critical thresholds with confidence — they hear a percentage instead of a value-with-unit.
- **Evidence:**
  - `Modules/Settings/Views/NotificationsSettingsView.swift:148, 155, 188` — three sliders, no `.accessibilityValue`.
  - `Modules/MetricDetail/Views/MetricDetail/MetricLogSheet.swift:109, 150, 167` — three sliders, no `.accessibilityValue`.
  - `Modules/Journal/Views/Journal/JournalEntryView.swift:211` — slider, no `.accessibilityValue`.
- **Fix:** Add `.accessibilityValue("\(Int(threshold)) BPM")` per slider (or "\(Int(weightKg)) kilograms", "\(Int(waterMl)) milliliters", etc.). Three-line addition per slider.
- **Priority:** This Week.
- **Confidence:** 92/100 — gaps verified by grep cross-reference.

---

## P2-F17. Charts have zero per-data-point accessibility — VoiceOver cannot navigate the time series

- **Severity: High**
- **Issue:** Swift Charts' built-in accessibility is the per-mark `.accessibilityLabel`/`.accessibilityValue` on `BarMark` / `LineMark` / `PointMark`, plus the document-level `.accessibilityChartDescriptor(...)` modifier. **Neither is used anywhere in the app.** I grepped:
  - `accessibilityChartDescriptor` → 0 hits.
  - `AXChartDescriptor` → 0 hits.
  - Per-mark `.accessibilityLabel` on a `BarMark` / `LineMark` / `PointMark` → 0 hits across `Common/Components/MetricChartView.swift` (354 lines, fully read), `Common/Components/WeeklyBarChart.swift`, `Modules/Vitality/Views/Vitality/VitalityTrendSection.swift`, `Modules/Strain/Views/Strain/StrainDetailView.swift`.
- **Impact:** VoiceOver users land on a chart, hear "chart" or sometimes nothing (the chart's parent might combine with a text node), and cannot navigate to individual data points. This is the de-facto accessibility chart story since iOS 16 and Apple-published a tutorial for it; Laso has none of it.
- **Evidence:**
  - `Common/Components/MetricChartView.swift:80-203` — `Chart { LineMark / AreaMark / RuleMark / PointMark / RectangleMark }` with no per-mark accessibility.
  - Same pattern in the other three chart files.
- **Fix:** On every `LineMark` and `BarMark`, add `.accessibilityLabel(Text(...formattedDate...))` and `.accessibilityValue(Text("\(value, specifier: "%.1f") \(unit)"))`. On the `Chart { ... }` parent add `.accessibilityChartDescriptor(MetricChartDescriptor(samples:))`. The chart-descriptor type is straightforward to author; it lets VoiceOver speak summary statistics ("Trend up 12% over 30 days, range 60 to 92").
- **Priority:** This Week — charts are a large fraction of value the app provides.
- **Confidence:** 96/100 — full read of MetricChartView.swift confirms zero accessibility on the chart marks; grep is exhaustive on `accessibilityChartDescriptor`.

---

## P2-F18. `accessibilityValue` is used 8 times total — 0 of them on selection state ("Selected"/"Not selected")

- **Severity: Medium**
- **Issue:** The 8 `accessibilityValue(...)` callsites all describe **content** (score = "82 percent", correlation = "moderate correlation", chain narrative, factor value). Zero communicate **selection state**. Yet 13 `accessibilityAddTraits(.isSelected)` callsites exist (good — VoiceOver hears "selected"). The gap: the 4 paywall pricing radios (Pass 1 F3 noted), the morning check-in chips (`MorningCheckInView.swift`), the focus-area chips (`OnboardingFocusStep.swift`), and the journal mood category buttons all should announce both the trait *and* a value. Currently they announce only "selected" via the trait, which works but loses the chance to say "Yearly 39.99, selected" instead of just "Yearly 39.99, selected, button" with no joint label-and-value composition.
- **Why this exists:** `accessibilityAddTraits(.isSelected)` was the easy fix for binary selection; richer multi-state (e.g., a Stepper showing 0 / 1 / 2 / 3 / 4 / 5 stars) needs `.accessibilityValue("\(rating) of 5 stars")`.
- **Impact:** VoiceOver experience for multi-state controls is shallow.
- **Evidence:** 8 `accessibilityValue` hits enumerated above; 0 on selection-style controls.
- **Fix:** On the morning check-in 1-5 ratings, add `.accessibilityValue("\(value) of 5")`. On stars / rating chips, same. On paywall radios add `.accessibilityValue(isSelected ? "Selected" : "Not selected")` (Pass 1 F3 already calls this out, but the gap is broader than just the paywall).
- **Priority:** This Week.
- **Confidence:** 90/100 — counts verified; the "morning check-in 1-5" and "focus chips" should-have inference is grounded in reading the files but I did not enumerate every multi-state control by hand.

---

## P2-F19. No `accessibilityReduceTransparency` / `colorSchemeContrast` / `legibilityWeight` / `accessibilityIgnoresInvertColors` anywhere — five iOS accessibility env values are completely missing

- **Severity: Medium**
- **Issue:** `grep -r "accessibilityReduceTransparency\|accessibilityInvertColors\|accessibilityShowButtonShapes\|colorSchemeContrast\|accessibilityDifferentiateWithoutColor\|legibilityWeight\|accessibilityIgnoresInvertColors"` returns **zero hits** in the entire codebase. Five iOS accessibility settings are completely ignored:
  1. **Reduce Transparency** — the `glassChrome(...)` extension (`DesignSystem.swift:250-276`) renders `.ultraThinMaterial` blur as the floating tab bar background. Users with Reduce Transparency on still get full transparency; should fall back to opaque `surfaceOverlay`.
  2. **Increase Contrast** — `colorSchemeContrast` env value lets us bump `borderLow` (6%) → `borderMedium` (10%) and `textSecondary` → `textPrimary` when the user requests increased contrast. Ignored.
  3. **Bold Text** — `legibilityWeight` env value tells us the user enabled bold-text accessibility; we'd promote `.regular` to `.medium` and `.medium` to `.semibold`. Ignored.
  4. **Differentiate Without Color** — Three score tiers (green/yellow/red) communicate via color alone in the recovery hero, the score guide legend, the strain badge, and several cards. No icon/shape backup for color-blind users. Pass 1 F1 mentioned the legend mismatch; this is the broader story.
  5. **Smart Invert** — App icon, paywall hero icon, brand artwork (`LaunchIcon`) should be `.accessibilityIgnoresInvertColors()` so they don't get color-inverted under Smart Invert. Not applied.
- **Impact:** Five iOS settings that real users with disabilities turn on are ignored end-to-end. Concrete: a user with Smart Invert sees the Laso heart icon (which has its own brand colors) inverted to a strange complementary color.
- **Evidence:** Single grep returns 0 hits for all five env-key names.
- **Fix:**
  1. `glassChromeBar()` and `glassChrome(in:)`: gate on `@Environment(\.accessibilityReduceTransparency)` — when true, fall back to `AppColour.surfaceOverlay` opaque.
  2. `AppColour.borderLow / textSecondary`: gate at view level on `@Environment(\.colorSchemeContrast)` — when `.increased`, bump to `borderMedium` and `textPrimary`.
  3. `DS.Typography.body / bodyMedium / bodySemibold`: when `legibilityWeight == .bold`, promote one weight step.
  4. Score tiers: add a small icon prefix per tier (`checkmark.circle.fill` for optimal, `equal.circle.fill` for fair, `arrow.down.circle.fill` for poor) when `accessibilityDifferentiateWithoutColor` is on.
  5. `Image("LaunchIcon")` (in `App/LasoApp.swift:160` and `PaywallView.swift:102`) — add `.accessibilityIgnoresInvertColors()`.
- **Priority:** This Week — five accessibility settings are concrete WCAG/Apple-HIG gaps.
- **Confidence:** 96/100 — single negative grep is exhaustive.

---

## P2-F20. Animation duration scale is fragmented — 0.2, 0.22, 0.25, 0.3, 0.32, 0.4, 0.5, 0.6, 0.7, 0.8, 1.0, 1.2, 1.4, 1.5, 2.4, 18 — sixteen unique values

- **Severity: Low**
- **Issue:** `DS.Motion` (`DesignSystem.swift:147-159`) defines a clean 6-step ramp: `pressIn 0.08s`, `counter 0.7s`, `toast 0.25s`, plus 4 spring presets. But across 85 `.animation(...)` / `withAnimation(...)` callsites in production, **sixteen distinct duration values** appear, only ~10% of which use the DS.Motion tokens. Most files inline `Animation = .easeInOut(duration: 0.2)` / `0.25` / `0.3` / `0.4` / `0.6` / `0.8` etc. directly.
- **Impact:** Two animations in different parts of the screen run at slightly different speeds, breaking choreography. Updating "make all data-reveal animations a touch slower" requires 85 file edits.
- **Evidence (representative):**
  - `DS.Motion.toast` is `0.25s` ease — but `Modules/Sleep/Views/Sleep/SleepCoachView.swift:318` uses `easeInOut(duration: 0.22)` and `:526` uses `easeInOut(duration: 0.25)` — close but neither matches the token.
  - `App/ContentView.swift:56, 60` use `.spring(duration: 0.4)` — should be `DS.Motion.transition`.
  - `Modules/Vitality/Views/Vitality/VitalityDetailView.swift:49` uses `.linear(duration: 18)` for a slow-rotation orb (legitimate one-off, fine).
  - 85 callsites total; only ~10 use `DS.Motion.*`.
- **Fix:** Migrate every duration-based animation to `DS.Motion.*`. Add `DS.Motion.fast = .easeInOut(duration: 0.2)`, `DS.Motion.medium = .easeInOut(duration: 0.4)`, `DS.Motion.slow = .easeInOut(duration: 0.8)` if more granularity is wanted.
- **Priority:** Backlog.
- **Confidence:** 92/100 — counts verified by grep.

---

## P2-F21. Two custom button styles defined (`DSPressButton` and `DSPrimaryButton`) animate on press — but the press-out animation is `DS.Motion.pressOut` which is a *spring* response 0.3 — semantically wrong for press-out

- **Severity: Low**
- **Issue:** `DesignSystem.swift:147-148` defines `pressIn = .easeIn(duration: 0.08)` and `pressOut = .spring(response: 0.3, dampingFraction: 0.7)`. The naming suggests "press in is the down-stroke, press out is the up-stroke release." Apple's HIG / iOS spring intuition is: press-in should be quick (50-80ms), press-out should also be quick but with a tiny overshoot. A spring with response 0.3 means oscillation duration ~300ms — that is the duration of a full *transition*, not a press-out. The press-up release looks soft and laggy.
- **Why this exists:** Springs feel "iOS-y" and the team picked one. The values are reasonable in isolation but the press-up takes too long.
- **Impact:** Press feedback feels slightly mushy. Doherty-threshold-class issue.
- **Evidence:** `Common/Components/DesignSystem.swift:147-148`.
- **Fix:** `pressOut = .spring(response: 0.18, dampingFraction: 0.75)` (iOS-system-snap feel). Keep `pressIn` at 0.08 ease-in.
- **Priority:** Backlog.
- **Confidence:** 70/100 — this is an animation-feel judgment from reading the values, not from running the app on-device. Flagged because the spring response 0.3 is empirically slow for press-up; visual on-device verification would push or drop the score.

---

## P2-F22. No focus-ring / keyboard-navigation visible-focus styling — keyboard users (or external Bluetooth keyboard / Switch Control) cannot see what is focused

- **Severity: Medium**
- **Issue:** SwiftUI's default focus indication is a thin gray ring on focused TextFields. There is no `.focused(...)` ring on any chip, button, or row in the app. `grep "focused\|Focus\|@FocusState"` returns **zero `@FocusState` declarations** in the entire app. Switch Control users (motor-impaired) and external-keyboard / iPadOS Magic Keyboard users navigate by tab — without a visible focus state, they cannot see where they are.
- **Impact:** Switch Control completely broken; iPad keyboard navigation half-broken (TextField default focus works, nothing else).
- **Evidence:** Single grep returns no `@FocusState` outside SwiftUI internal references.
- **Fix:** Add `@FocusState private var focusedField: Field?` on the major form views (`MetricLogSheet`, `FeedbackSheet`, `JournalEntryView`, `OnboardingProfileCaptureView`, `OnboardingReferralCodeStep`). On chip/row buttons, expose `.focused($focused, equals: ...)` and add a `.overlay(.focused ? AppColour.primary.opacity(0.4) ring : nil)` modifier. Out of scope for a sprint, but blocks any iPad / external-keyboard story.
- **Priority:** Backlog (unless iPad becomes a target).
- **Confidence:** 92/100 — `@FocusState` truly has zero hits.

---

## P2-F23. `Image("LaunchIcon")` and brand artwork render without `.accessibilityLabel` or `.accessibilityHidden(true)` — VoiceOver says "image" with no context

- **Severity: Low**
- **Issue:** `App/LasoApp.swift:160` and `Modules/Paywall/Views/Subscription/PaywallView.swift:102` both use `Image("LaunchIcon")` for the splash and paywall hero. Neither has `.accessibilityLabel("Laso")` or `.accessibilityHidden(true)`. SwiftUI by default treats `Image(_)` (asset name) as accessible with the asset name read aloud — VoiceOver says "Launch icon, image". Should say "Laso" or be hidden if decorative.
- **Impact:** Minor; first-impression friction for VoiceOver users.
- **Evidence:** Both callsites verified.
- **Fix:** Add `.accessibilityLabel("Laso")` on both. The launch one could even be `.accessibilityHidden(true)` since it disappears within 1 second.
- **Priority:** Backlog.
- **Confidence:** 92/100.

---

## P2-F24. `accessibilityHint` is used 20 times across Dashboard but **0 times in Settings, Onboarding, Paywall, Vitality, Stress, Profile, Sleep, MetricDetail, Journal, Insights, Live** — one module has the pattern, the others do not

- **Severity: Medium**
- **Issue:** Pass 1 F2/F3 enumerated module-by-module accessibility-annotation counts. This pass narrows on `accessibilityHint` specifically: 20 hits in `Modules/Dashboard/`, 0 hits anywhere else (apart from `Common/Navigation/CustomTabBar.swift:66` and `Modules/Sleep/Views/Sleep/SleepCoachView.swift:326`, `Modules/CategoryDetail/Views/Category/CategoryDetailView.swift:295`). The Dashboard module's pattern is correct: every tappable card has both `.accessibilityLabel(...)` (the content) and `.accessibilityHint("View XYZ details")` (the action). Other modules' tappable cards have label only, no hint.
- **Impact:** VoiceOver users on the Dashboard hear "Strain card, today's strain 8.4, moderate. Hint: View strain details". On the Settings screen they hear "Subscription, button" (no hint about what tapping does). Inconsistent.
- **Evidence:**
  - `Modules/Dashboard/...` — 18 `.accessibilityHint(...)` across BrainHealthCard, SleepCoachCard, CyclePhaseCard, FocusAreasSection, StrainCard, StressCard, RecoveryHeroCard, PatternCard, VitalityCard, WeeklyReviewView, ActivationProgressBanner, etc.
  - `Modules/Settings/Views/SettingsView.swift` — has `.buttonStyle(.plain)` rows with no `.accessibilityHint`.
  - `Modules/Profile/Views/Profile/AchievementsView.swift` — same gap.
- **Fix:** Sweep Settings, Profile, Sleep (mostly), Stress, Vitality, Insights, MetricDetail to add `.accessibilityHint(...)` per tappable row. Use the Dashboard pattern as the template.
- **Priority:** This Sprint.
- **Confidence:** 95/100 — counts exact.

---

## P2-F25. `accessibilityElement(children: .combine)` is used 35 times — but always with default reading order; `.accessibilityElement(children: .contain)` (the rotor-friendly alternative) is used **once**

- **Severity: Low**
- **Issue:** 35 `.accessibilityElement(children: .combine)` callsites flatten card content into a single VoiceOver focusable element. This is correct for cards where the user wants one tap-target. But for cards like `RecoveryHeroCard` (hero ring + label + week-delta + day-type + why-line) — combining means VoiceOver reads the entire card as one ~80-word string, with no way to skip ahead. `accessibilityElement(children: .contain)` is the rotor-friendly alternative — VoiceOver sees the card as a logical group but you can swipe between sub-elements. Used once: `Modules/Dashboard/Views/Home/HomeView.swift:41`.
- **Impact:** On long compound cards, VoiceOver users sit through a long combined utterance instead of tabbing between inner elements.
- **Evidence:**
  - 35 hits of `children: .combine`, 1 hit of `children: .contain`.
- **Fix:** On the 4-5 longest compound cards (`RecoveryHeroCard`, `WeeklyReviewView` 532-line accessibility node, `BrainHealthCard`, `PeriodSummarySection`), switch to `children: .contain` and let users navigate inside. Also consider `.accessibilityCustomContent(...)` to expose secondary information without forcing it into the primary read.
- **Priority:** Backlog.
- **Confidence:** 80/100 — judgment-call about which cards are too long to combine; needs a VoiceOver-on runtime listen to confirm.

---

## P2-F26. The two custom decorative orbs (Vitality organic orb + AskData orb) are not marked `.accessibilityHidden(true)` — VoiceOver sometimes lands on them

- **Severity: Low**
- **Issue:** `Modules/Vitality/Views/Vitality/VitalityOrganicOrb.swift` and `Modules/Dashboard/Views/Home/AskDataOrbView.swift` are large decorative animations with no semantic content. Neither has `.accessibilityHidden(true)`. VoiceOver will announce "image" or "shape" depending on what it lands on.
- **Impact:** Minor distraction for VoiceOver users.
- **Evidence:** No `.accessibilityHidden` in either file (grep confirmed).
- **Fix:** Wrap each in `.accessibilityHidden(true)` or `.accessibilityElement(children: .ignore)` with no label.
- **Priority:** Backlog.
- **Confidence:** 88/100.

---

## P2-F27. No `.dynamicTypeSize(...)` clamps anywhere — accessibility-XL sizes will break heroes

- **Severity: Medium**
- **Issue:** Pass 1 F5 found 71 fixed-size fonts that ignore Dynamic Type. The complement of that finding is: when fonts **do** use semantic Dynamic Type (which is most of the app's body text), there is **no `.dynamicTypeSize(.xSmall ... .accessibility5)` clamp anywhere** in the app. Single grep confirms zero hits. Hero numbers, paywall pricing, dashboard scores, recovery ring labels, all scale unboundedly. At AX5 (310% scaling), the recovery hero ring's center number overflows the ring; the paywall radio button rows wrap to 6 lines; the bottom tab bar text becomes unreadable.
- **Why this exists:** The team disabled Dynamic Type in many places via fixed-size fonts (Pass 1 F5) instead of clamping the supported range.
- **Impact:** Either (a) dynamic-type users see broken layouts at AX1-AX5, or (b) they see no scaling at all on the fixed-font screens. Neither is correct.
- **Evidence:** `dynamicTypeSize` returns 0 hits.
- **Fix:** On hero containers (recovery ring, paywall pricing, bottom tab bar), apply `.dynamicTypeSize(...DynamicTypeSize.xxxLarge)` to clamp at the largest non-accessibility size. On long-form screens (insights, settings, journal), allow `...DynamicTypeSize.accessibility3` (gives users a real boost without breaking layout). On accessibility-critical screens (notifications, alerts), allow `.accessibility5`.
- **Priority:** This Week.
- **Confidence:** 92/100 — verified the absence; the clamp choices per screen are judgment.

---

## P2-F28. Asset catalog has only 2 colorsets — every other AppColour token lives only in Swift code, so designers can't pick from Xcode's color well

- **Severity: Low**
- **Issue:** `Assets.xcassets/` contains exactly two colorsets: `AccentColor.colorset` (rose, see Pass 1 F1) and `LaunchBackground.colorset` (black). All ~40 AppColour tokens (`primary`, `accent`, `success`, `warning`, `danger`, etc.) live in `Common/Theme/AppColour.swift` as `#colorLiteral(...)`. The file's docstring (`AppColour.swift:14-15`) claims "Swatch-pickable: every entry uses `#colorLiteral(...)` so Xcode shows an inline colour well you can edit visually" — true for in-code editing, but the colors are not in the asset catalog so designers using Figma → Xcode color picker workflows have nothing to import.
- **Impact:** Designers can't drag-drop a brand palette from Figma into Xcode color wells. The whole brand palette is opaque from the asset catalog.
- **Evidence:**
  - `find Assets.xcassets -name "*.colorset" -type d` returns exactly 2 entries.
- **Fix:** Mirror every AppColour token into the asset catalog as a 2-value (light/dark) colorset; have `AppColour.primary` resolve to `Color("BrandPrimary", bundle: .main)`. Pre-condition for a proper light-mode story (Pass 1 F17). Bigger refactor.
- **Priority:** Backlog.
- **Confidence:** 95/100 — file structure verified.

---

## P2-F29. `displayP3` color space is not used anywhere — every color is `srgb` — modern P3 wide-gamut iPhone displays show duller-than-possible brand color

- **Severity: Low**
- **Issue:** `AccentColor.colorset/Contents.json` uses `"color-space": "srgb"`. Every `#colorLiteral` in `AppColour.swift` is implicitly sRGB. Modern iPhones (iPhone 11+) ship `displayP3` wide-gamut displays. P3 covers ~25% more of the visible color gamut than sRGB. A brand color authored in P3 looks slightly more saturated and vivid; an sRGB color looks the same on every device. Apple Health and Whoop use P3 for their score colors.
- **Impact:** Brand colors look 5-10% duller on Pro iPhones than they could. Especially noticeable on the recovery green and vitality teal — both are in the sRGB-clipped portion of P3.
- **Evidence:** `find Assets.xcassets -name "Contents.json" -path "*colorset*" -exec grep -l "displayP3" {} \;` returns 0 hits.
- **Fix:** When mirroring AppColour into the asset catalog (P2-F28), author each color in `displayP3` color space. Provide an sRGB fallback for older devices.
- **Priority:** Backlog.
- **Confidence:** 88/100 — file structure verified; the perceptual claim is well-known but I have not measured pixel difference on a P3 device.

---

## P2-F30. No image rendering-mode hygiene — `Image(systemName:)` calls work because SF Symbols are template by default, but the **2** `Image("LaunchIcon")` callsites use `Image` without `.renderingMode(.original)` or `.renderingMode(.template)` declaration

- **Severity: Low**
- **Issue:** `App/LasoApp.swift:160` and `Modules/Paywall/Views/Subscription/PaywallView.swift:102` use `Image("LaunchIcon").resizable().scaledToFit()`. No `.renderingMode(...)` is set. SwiftUI defaults image rendering-mode by inferring from the asset's "Render As" setting — `LaunchIcon.imageset` does not set a render mode (it's PNG default), so it renders as `.original`. Fine today, but if the launch icon is ever swapped for a single-color stencil PNG, the rendering will silently switch to `.template` and tint with the surrounding `.foregroundStyle` — invisible-looking visual breakage.
- **Impact:** Latent fragility. Flagged for hygiene.
- **Evidence:** Both files read.
- **Fix:** Add `.renderingMode(.original)` explicitly on both `Image("LaunchIcon")` callsites.
- **Priority:** Backlog.
- **Confidence:** 80/100 — fragility prediction; the visible behavior is correct today.

---

## P2-F31. PMF Survey has `.borderedProminent` Continue buttons — and they wrap with the rose `Color.accentColor` — the highest-stakes retention survey asks for feedback in the wrong brand color

- **Severity: High**
- **Issue:** `Common/Components/PMFSurveySheet.swift:139, 165, 193, 213` — four `.buttonStyle(.borderedProminent)` Continue buttons. Per Pass 1 F1, `Color.accentColor` resolves to rose (because the leftover `AccentColor.colorset` was never repainted). `.borderedProminent` defaults to `.tint(Color.accentColor)`. So the PMF survey — a 4-step Sean Ellis-style survey that drops at the most strategically important moment in the user lifecycle (post-activation) — renders four rose Continue buttons in a row.
- **Why this exists:** Hot-path: this composes Pass 1 F1 (rose accent), P2-F3 (`.borderedProminent` legacy), P2-F2 (`.systemBlue` not used). All three issues meet on the PMF survey.
- **Impact:** The user sees a brand-incoherent retention survey at the moment they were thinking "is this app for me?" — a four-screen flow with rose buttons, which they have not seen anywhere else in the app. Brand confusion at peak engagement.
- **Evidence:**
  - `Common/Components/PMFSurveySheet.swift:139, 165, 193, 213` — four `.borderedProminent` Continue buttons.
- **Fix:** Replace all four with `.buttonStyle(.dsPrimary)` once P2-F2 has wired DSPrimary to AppColour.primary. One file, ~10 line change.
- **Priority:** Now — combination of three latent issues hits the user at the worst moment.
- **Confidence:** 96/100 — file fully read; rendering inference is grounded in three independently-verified facts (rose AccentColor, `.borderedProminent` defaults to accent tint, PMFSurveySheet uses borderedProminent).

---

## P2-F32. No app-wide `.tint(...)` modifier at root — every `.borderedProminent` button, every `.toggleStyle(.switch)`, every `Stepper` increment chevron, every `Slider` track, falls back to the rose `AccentColor`

- **Severity: Critical (compounds with Pass 1 F1)**
- **Issue:** Pass 1 F1 noted that `LasoApp.swift:167` only applies `.tint(.secondary)` on a sub-view. The deeper issue: SwiftUI's `Toggle`, `Stepper`, `Slider`, `Picker`, `ProgressView`, and `.borderedProminent` Buttons all paint with `Color.accentColor` by default unless overridden. Without an app-root `.tint(AppColour.primary)`, every settings-screen toggle, every notification-threshold slider (`NotificationsSettingsView.swift:147-188`), every stepper (`NotificationsSettingsView.swift:97-105`), every progress view (`OnboardingMirrorMomentStep.swift:97`) renders rose. Pass 1 F1 enumerated 7 explicit `Color.accentColor` callsites; this finding adds the **implicit** ones — every system control on every settings/onboarding screen.
- **Why this exists:** No `.tint(AppColour.primary)` at app root.
- **Impact:** The fix Pass 1 F1 prescribed (add `.tint(AppColour.primary)` once at app root) is not yet applied. Until it is, **every** built-in SwiftUI control in the app is rose. The notifications settings page is one big rose surface.
- **Evidence:**
  - `App/LasoApp.swift` — full file read; only `.tint(.secondary)` on sub-views, no app-root `.tint(AppColour.primary)`.
  - `Modules/Settings/Views/NotificationsSettingsView.swift:148, 155, 188` — 3 sliders that inherit `Color.accentColor` (rose).
  - `Modules/Settings/Views/NotificationsSettingsView.swift:97-105` — Stepper (rose).
  - `Modules/Settings/Views/NotificationsSettingsView.swift:40-92, 139-213` — 8 Toggles (rose green-when-on; SwiftUI's switch is technically green by default but the unfilled track inherits accent).
  - `Modules/Onboarding/Views/Onboarding/OnboardingMirrorMomentStep.swift:97` — calibration ProgressView; explicit `.tint(AppColour.info)` overrides rose, but only because someone caught it.
- **Fix:** One line at app root: `.tint(AppColour.primary)` on the root scene's NavigationStack or the topmost ZStack. This is the same fix Pass 1 F1 specified — but Pass 1 only listed the 7 *explicit* `Color.accentColor` sites; this finding makes clear that the *implicit* tint propagation is the bigger surface.
- **Priority:** Now — single-line fix worth dozens of brand corrections.
- **Confidence:** 96/100 — verified by full read of `LasoApp.swift` and `ContentView.swift`; SwiftUI tint propagation is well-documented Apple behavior.

---

## P2-F33. `.frame(width: 24, height: 24)` X-close in MorningCheckInView is well below the 44pt HIG minimum — Pass 1 F16 missed this site

- **Severity: Medium**
- **Issue:** `Modules/Dashboard/Views/Home/MorningCheckInView.swift:42-46` — the close (X) button uses `.frame(width: 24, height: 24)`. No `contentShape` is added. The tap area is 24×24 = 576 sq pt; HIG minimum is 44×44 = 1936 sq pt. This is one of the most tappable surfaces on the home screen (dismiss the morning prompt) and it's tiny.
- **Why this exists:** The icon is rendered at 24pt; the frame matches the icon. Forgot to expand tap area.
- **Impact:** Hard to tap, especially on the move. Users miss-tap the chip below.
- **Evidence:** `Modules/Dashboard/Views/Home/MorningCheckInView.swift:42-46` (read directly).
- **Fix:** `.frame(width: 44, height: 44).contentShape(Rectangle())` — keep the icon at 24, expand the tap target to 44.
- **Priority:** This Sprint.
- **Confidence:** 95/100 — read directly. Pass 1 F16 listed several sub-44 frames but missed this one because it's not a `Modules/.../*Detail*` site.

---

## P2-F34. `Charts` in `MetricChartView` use raw `.green / .secondary / .orange / .white` color literals at 5 sites — Pass 1 F7 listed `Color.gray` and `Color.red` violations but missed Charts entirely

- **Severity: Low**
- **Issue:** Pass 1 F7 enumerated 22 hardcoded named-color callsites. The Charts file `Common/Components/MetricChartView.swift` adds 5 more that the previous grep pattern did not pick up because they appear as `.green` / `.secondary` literals on chart marks, not as `Color.green` declarations:
  - `MetricChartView.swift:89` — `.foregroundStyle(.green.opacity(0.05))` for the normal-range rectangle.
  - `MetricChartView.swift:119` — `.foregroundStyle(.secondary.opacity(0.5))` for the baseline rule.
  - `MetricChartView.swift:124` — `.foregroundStyle(.secondary)` for the baseline annotation.
  - `MetricChartView.swift:136` — `.foregroundStyle(.orange.opacity(0.7))` for the trend overlay.
  - `MetricChartView.swift:200` — `.foregroundStyle(.white)` for the selected-point inner mark.
- **Impact:** Chart "normal range" tint is `.green` (system green), not `AppColour.scoreOptimal` (#10B981). Same kind of legend/data-color mismatch Pass 1 F7 called out for `ScoreGuideSheet`.
- **Evidence:** Lines listed.
- **Fix:** Replace `.green` → `AppColour.scoreOptimal`, `.orange` → `AppColour.warning`, `.white` → `AppColour.textPrimary` (or keep white for the inner-dot accent, since it is a visual punctuation not a state).
- **Priority:** This Sprint.
- **Confidence:** 95/100 — read directly.

---

## P2-F35. `Toast`, `popover`, `tooltip` infrastructure — only `DSToast` exists; no popover / tooltip primitive in the design system

- **Severity: Low**
- **Issue:** `Common/Components/DSToast.swift` defines a banner-style toast. There is **no** `.popover(...)` callsite anywhere in the app (single grep). There is no tooltip / coach-mark / first-use-hint component — every "tap to learn more" inline hint (`RecoveryHeroCard.swift:155-162` per Pass 1 F10) is hand-rolled. iOS 17 `.popover(isPresented:)` with `.presentationCompactAdaptation(.popover)` is the modern way; not used.
- **Impact:** No standard primitive for explaining UI in-place. Hint rows compete for hierarchy with content rows (Pass 1 F10).
- **Evidence:** `popover` returns 1 hit (`Common/Components/ShareButton.swift:86-94`, but that's the `UIActivityViewController` iPad anchor — not a SwiftUI popover).
- **Fix:** Add a `DSPopover(text: String)` / `DSTooltip(text: String)` component with iOS-17 `.popover` plumbing. Replace the 3-4 inline "tap for more" hint rows with a tooltip popover anchored to a small `info.circle` icon.
- **Priority:** Backlog.
- **Confidence:** 92/100 — verified by grep.

---

## P2-F36. Avatar fallback / initials / async-image discipline — there is no avatar component anywhere — but the app does not show user avatars yet

- **Severity: N/A (preventive)**
- **Issue:** `grep "AvatarView\|initials\|AsyncImage"` returns 0 hits. No user avatar concept exists — the app has no profile photo, no leaderboard, no friend/coach photo. This is fine today, but if any social or coach feature ships, an avatar primitive is needed.
- **Impact:** None today.
- **Fix:** When adding any feature with a person's representation, define `DSAvatar(initials: String, photo: AsyncImage?)` first.
- **Priority:** When triggered.
- **Confidence:** 95/100.

---

## P2-F37. No empty/skeleton/error pattern on `MetricLogSheet` or `JournalEntryView` — form sheets without "saving…" or "error" surface fall back to inline `ProgressView()` and disable

- **Severity: Low**
- **Issue:** Pass 1 F19 covered the data-loading empty-state inconsistency. This pass surfaces the **form-submit** state inconsistency: `MetricLogSheet.swift:81` and `MorningCheckInView.swift:80, 92` both set `isSaving / isSubmitting = true` and disable the form, with a tiny `ProgressView()` next to the save button. There is no error-surface (no banner, no toast, no error message above the form) — if the save fails, the user sees the spinner stop and the disabled state lift, with no acknowledgment. Compare to `Common/Components/DSToast` which exists but is not wired.
- **Impact:** Silent error path on save / submit form sheets. Users may double-tap save thinking it didn't work.
- **Evidence:**
  - `Modules/MetricDetail/Views/MetricDetail/MetricLogSheet.swift:81` — `.disabled(isSaving)`; no error binding.
  - `Modules/Dashboard/Views/Home/MorningCheckInView.swift:80, 92` — `ProgressView()` + `.disabled(isSubmitting)`; no error.
  - `Modules/Journal/Views/Journal/JournalEntryView.swift:280` — `.disabled(value == 0 && category != .stress && category != .mood)` — disable reason not communicated to user.
- **Fix:** Add a top-of-form error banner / toast hookup using `DSToast`. On save failure, `DSToast.error("Could not save. Try again.")`. On disabled-because-incomplete form, add an inline footer hint "Pick a value to save" so the disabled state is explained.
- **Priority:** Backlog.
- **Confidence:** 88/100 — read directly.

---

## P2-F38. `LaunchBackground.colorset` is `#000` only, single appearance — the app's launch screen is hard-coded black with no light variant

- **Severity: Low (compounds Pass 1 F17)**
- **Issue:** `Assets.xcassets/LaunchBackground.colorset/Contents.json` declares one color for the universal idiom: `red 0, green 0, blue 0, alpha 1` — pure black, no `appearances: [{ "appearance": "luminosity", "value": "dark" }, ...]` array. So the launch screen is the same black in light and dark mode. Pass 1 F17 noted this; this pass adds the perceptual point: the first-onboarding screen background is also dark, so the transition is seamless in dark mode — but if dark-mode-lock is ever lifted, the black launch will hard-cut to the light-mode onboarding background and create jarring perceptual flash.
- **Impact:** Future-proofing only. No issue today.
- **Evidence:** `Assets.xcassets/LaunchBackground.colorset/Contents.json` read directly.
- **Fix:** Add a light-variant color (`#FFFFFF` or whatever the light-mode onboarding background will be). One JSON edit.
- **Priority:** Backlog.
- **Confidence:** 95/100.

---

## P2-F39. `presentationCornerRadius` is never set — sheets use the iOS-17 default radius which differs from `DS.cardRadius`

- **Severity: Low**
- **Issue:** All 10 `.sheet(...)` presentations use the system default sheet corner radius (~10pt on iOS 17). The app's `DS.cardRadius = 24`. The sheet's top corners therefore look "tight" relative to every card on screen.
- **Impact:** Tiny visual rhythm break — sheet looks more "iOS-stock" than "Laso-branded".
- **Evidence:** `presentationCornerRadius` returns 0 hits.
- **Fix:** Set `.presentationCornerRadius(DS.Radius.xl)` (= 20) per HIG matching iPhone hardware corner. Apply to all 10 sheets.
- **Priority:** Backlog.
- **Confidence:** 88/100 — visible only on close inspection.

---

## P2-F40. Validation feedback is below-the-button only — no inline error below the field, no shake on incorrect

- **Severity: Medium**
- **Issue:** `OnboardingReferralCodeStep.swift:75-80` renders the error message below the redeem button, in a Label with `xmark.circle.fill`. Other forms (`ProfileCaptureView` age field, `MetricLogSheet` numeric input) have **no inline error rendering at all** — bad input is silently rejected by the disabled save button. There is no "shake the field" haptic-visual confirmation of bad input that iOS normally uses.
- **Impact:** Users don't know why the form won't save. They look at the disabled button, get frustrated.
- **Evidence:**
  - `Modules/Onboarding/Views/Onboarding/ReferralCodeStep.swift:75-80` (the only inline error in the app).
  - `Modules/Onboarding/Views/Onboarding/ProfileCaptureView.swift:59` — TextField for age, no error rendering, no validation hint.
  - `Modules/MetricDetail/Views/MetricDetail/MetricLogSheet.swift:109, 150, 167` — sliders, no min/max guidance.
- **Fix:** Define a `DSFormFieldError` component with `Image("exclamationmark.triangle.fill") + Text("...") + AppColour.danger` styling. Always render below the field. On save with invalid input, shake the field via `.modifier(ShakeEffect(animatableData: shakeTrigger))`.
- **Priority:** This Sprint.
- **Confidence:** 88/100.

---

## Summary

| Severity | Count | Findings |
|---|---|---|
| Critical | 1 | P2-F32 (no app-root tint) |
| High | 5 | P2-F2 (DSButton uses `.systemBlue`), P2-F3 (3 button systems), P2-F16 (slider accessibility), P2-F17 (chart accessibility), P2-F31 (PMF rose buttons) |
| Medium | 14 | P2-F1, P2-F4, P2-F5, P2-F8, P2-F10, P2-F12, P2-F14, P2-F15, P2-F18, P2-F19, P2-F22, P2-F24, P2-F27, P2-F33, P2-F40 |
| Low | 19 | rest |
| N/A | 1 | P2-F36 (avatar — preventive) |

**Top fix Now:**
1. **P2-F32** — single-line `.tint(AppColour.primary)` at app root. Closes the rose-tint gap on every Toggle/Slider/Stepper/Picker/ProgressView/`.borderedProminent` button.
2. **P2-F2** — replace `Color(uiColor: .systemBlue)` with `AppColour.primary` in `DSButton.swift:27, 73`. Fixes 14 primary-CTA brand-color drift in two minutes.
3. **P2-F31** — migrate PMF survey buttons to `.dsPrimary` once F2/F32 land.

**Top fix This Week:**
- P2-F3 (kill `.borderedProminent` legacy in 15 sites), P2-F16 (slider `accessibilityValue`), P2-F17 (chart per-mark accessibility + `accessibilityChartDescriptor`), P2-F19 (5 missing accessibility-env modifiers, esp. Reduce Transparency on glass and Smart Invert on launch icon), P2-F27 (dynamicTypeSize clamps).

**Top fix This Sprint:**
- P2-F1 (state-color tokens), P2-F4 (skeleton reduce-motion), P2-F5 (press feedback on `onTapGesture`), P2-F7 (success/warning/danger pairs), P2-F8 (eyebrow / kicker typography), P2-F10 (shadow recipes), P2-F11 (divider leading inset), P2-F12 (drag indicators), P2-F14 (modal close placement), P2-F15 (vertical scroll indicators), P2-F18 (selection accessibilityValue), P2-F22 (focus state — if iPad ships), P2-F24 (accessibilityHint outside Dashboard), P2-F33 (MorningCheckIn X tap area), P2-F34 (Charts named colors), P2-F40 (form validation inline).

**Backlog:**
- P2-F6 (skeleton tokens), P2-F9 (icon weight ramp), P2-F13 (sheet detents), P2-F20 (animation duration), P2-F21 (pressOut spring tuning), P2-F23 (LaunchIcon labels), P2-F25 (`children: .contain` on long cards), P2-F26 (orb hidden), P2-F28 (asset-catalog colorsets), P2-F29 (displayP3), P2-F30 (renderingMode hygiene), P2-F35 (popover/tooltip primitive), P2-F37 (form save error toast), P2-F38 (LaunchBackground light variant), P2-F39 (sheet corner radius).

**Reinforcing the brand-tint chain:** P2-F2 + P2-F32 + Pass 1 F1 form a single coherent fix. Apply all three together: (a) repaint `AccentColor.colorset` to brand blue (or kill the colorset and rely on tint), (b) add `.tint(AppColour.primary)` at app root, (c) replace `Color(uiColor: .systemBlue)` with `AppColour.primary` in `DSButton`. Result: every implicit and explicit accent-tint surface renders the brand blue. The PMF survey, the morning check-in, the achievements filter, the paywall radio borders, every toggle/slider/stepper, every `.borderedProminent` legacy button — all one color, all in one PR.

**Confidence overall:** 91/100 — every finding is grounded in `file:line` evidence read directly. Dragged below 100 by: (a) no on-device VoiceOver / Switch Control / Reduce Transparency / Bold Text / Smart Invert runtime verification, (b) the press-spring (P2-F21) and `children: .combine` density (P2-F25) findings are perceptual judgments grounded in code values, not on-device experience, (c) the `displayP3` perceptual claim (P2-F29) is well-known but unmeasured here, (d) the chart-accessibility fix in P2-F17 has not been authored end-to-end so I have not confirmed the descriptor pattern compiles cleanly against the project's chart types. None of these change the categorization of the top-3 priorities, which are file-grep verified.

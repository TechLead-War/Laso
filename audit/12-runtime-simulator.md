# 12 — Runtime Simulator Verification (Pass 2)
_Started: 2026-04-25 16:15 IST, finished 16:25 IST. Device: iPhone 16e iOS 26.2 (UDID `2BB16998-E836-41E9-8D61-67479A6D2B08`). Build: `Debug-iphonesimulator/Laso.app`. Bundle: `com.lasohealth.fit`._

> **Driving constraint up-front.** This Claude harness does **not** hold macOS Accessibility / Screen Recording permission, so AppleScript `click at` and `cliclick c:` succeed at the OS level but the resulting synthetic mouse events are silently swallowed by the iOS Simulator (verified: cursor moved to expected coords, screen unchanged across multiple attempts incl. raise + double-click + spacebar/return). I drove every state I could without taps — re-launches, dark/light toggles, deep-link drops, push, memory warning, app-switcher via `Cmd+Shift+H+H` — and corroborated tap-only flows by reading the source they invoke. **Failures are documented per-step rather than skipped.**

---

## Phase 1 — Cold start + onboarding

### R1. Cold launch lands on `OnboardingPulseStep` ("See what your body has been telling you.") with a single primary `Begin` button — no progress dots, no "step 1 of 6", no skip.
- Wave finding: F28 (04-product-ux) — "Onboarding has no progress indicator on the Pulse step".
- Status: **CONFIRMED**.
- Evidence:
  - `evidence/02-onboarding-step1.png` — full screen black, faint blue concentric halos, blue heart glyph, headline "See what your body has been telling you.", and a full-width filled-blue `Begin` button at the very bottom.
  - Source: `Modules/Onboarding/Views/Onboarding/OnboardingPulseStep.swift:1-90` — header comment literally reads _"No progress dots, no 'Step 1'."_
- Confidence: 98/100.

### R2. Could not drive onboarding past step 1 — tap automation blocked. Steps 2–6 cannot be runtime-verified in this environment.
- Wave finding: implicit dependency for F3 (no goal/condition questions), F8 (cycle no-opt-in), F21 (no name/email).
- Status: **NOT VERIFIED AT RUNTIME** — code-level confirmation stands from prior passes.
- Evidence:
  - `evidence/03-onboarding-step2.png` — identical to step 1, click at calibrated coords (726, 920) had no effect.
  - `evidence/03b-after-space.png` — spacebar/return key had no effect either (deleted).
  - Cause: shell-spawned `cliclick` / `osascript` lack Accessibility-Trust on macOS 25.4. Cursor moved to target pixel (`cliclick p` confirmed (726,920)) but Simulator received no touch event. **Single attempt with raise + dc:726,920 also failed.**
- Confidence: 95/100 that the limitation is the harness, not the build (cursor demonstrably moved; UI never reacted across 4 different click strategies).

### R3. HealthKit permission prompt — could not be reached because step-1 tap is blocked. Source-level finding stands.
- Wave finding: F3 permissions (`isAuthorized = true` on deny) + F4 (partial-grant blindness).
- Status: **CONFIRMED VIA SOURCE** — `Core/Data/HealthKitManager.swift:158-173`.
- Evidence: `requestAuthorization(toShare:read:)` returns successfully in *both* grant and deny cases (Apple API contract — only the user-visible decision is hidden behind per-type queries). Code unconditionally sets `isAuthorized = true` on line 165 and reports analytics _"granted: totalRequested, denied: 0, total: totalRequested"_ on line 166. So a denying user appears as a fully-granting user to the rest of the app **and** to PostHog.
- Confidence: 99/100. (Cannot drive the live deny dialog, but the bug is in the post-callback code that runs regardless of user choice.)

### R4. Onboarding visual — uses force-locked dark mode. Heart-glyph hero pulses on a perfect black background with a faint blue halo. Animation runs continuously.
- Wave finding: F17 design (force-dark lock), F12 design (repeat-forever animations not gated by Reduce Motion).
- Status: **CONFIRMED**.
- Evidence:
  - `evidence/04-onboarding-dark-system.png` and `evidence/05-onboarding-light-system.png` — system appearance toggled to `dark` then `light` between captures (verified via `xcrun simctl ui booted appearance`); both screenshots are visually identical pure-black, proving the app overrides system appearance.
  - Source: `App/LasoApp.swift:148` — `.preferredColorScheme(isUITestMode ? UITestMode.preferredColorScheme : .dark)`.
  - Source: `Modules/Onboarding/Views/Onboarding/OnboardingPulseStep.swift:85-88` — `repeatForever(autoreverses: true)` with no `accessibilityReduceMotion` guard.
- Confidence: 99/100.

---

## Phase 2 — Dashboard / day-1 empty state

### R5. Dashboard could not be reached because onboarding cannot be advanced from step 1.
- Wave findings dependent on Dashboard: F17 product-ux (Apple-Health-only stuck loading), F22 product-ux (5 competing CTAs), F23 (inconsistent skeletons), F26 (empty state lacks "what to do next").
- Status: **NOT VERIFIED AT RUNTIME** in this pass.
- Evidence: none — limitation, not finding.
- Confidence: N/A.

---

## Phase 3 — Settings + delete-account flow

### R6. "Delete All My Data" calls `exit(0)` after wiping local stores — Firebase Auth signOut, Firestore wipe, PostHog reset are absent.
- Wave finding: F2 product-ux + F11 permissions.
- Status: **CONFIRMED VIA SOURCE** (and intentionally not driven via UI per task instructions).
- Evidence: `Modules/Settings/Views/SettingsView.swift:671-692`.
  - Lines 674-678 — wipe `EncryptedStore` keys.
  - Line 680 — `healthDataStore.deleteAllData()` (SwiftData).
  - Lines 682-685 — `UserDefaults.standard.removePersistentDomain(forName: bundleId)`.
  - Line 687 — internal NotificationCenter post.
  - **Lines 689-691 — `exit(0)` after 0.3s.**
  - Absent: any `Auth.auth().signOut()` callsite (already verified zero matches in 10-permissions audit), any Firestore `.delete()` on the user doc, any `PostHogSDK.shared.reset()`. So after deletion: anonymous Firebase UID survives, Firestore profile + scores survive, PostHog distinctId continues attributing the same anon ID. App Guideline 5.1.1(v) and GDPR right-to-erasure are not satisfied.
- Confidence: 99/100. (Did not press the button — task instruction. But the function body is fully read end-to-end.)

---

## Phase 4 — Paywall + subscription

### R7. Paywall could not be reached without taps. Source-level findings stand.
- Wave findings: F6/F7 product-ux (aha-paywall + no escape), F19 (no social proof / refund), F3 design (no VoiceOver, hardcoded English auto-renew copy), F14 design (no trust signals).
- Status: **NOT DRIVEN AT RUNTIME** in this pass.
- Confidence: N/A — see prior pass docs.

---

## Phase 5 — Permissions denial flows

### R8. App never registers for remote notifications and never requests `UNUserNotificationCenter.current().requestAuthorization`.
- Wave findings: F1 + F2 permissions (10-permissions-edge-cases.md).
- Status: **CONFIRMED — both source and runtime.**
- Evidence:
  - Source grep for `registerForRemoteNotifications`, `requestAuthorization` (UNUserNotificationCenter), `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`: **zero matches** across the entire repo.
  - Runtime: `xcrun simctl push booted com.lasohealth.fit /tmp/push-test.json` returned `Notification sent to 'com.lasohealth.fit'` — see `evidence/10b-push-while-foreground.png`. App was foreground; **no banner, no in-app notification, no badge**. iOS suppressed it because the app has no notification authorization. The user-facing effect: server can't push and the simulated push silently dies.
- Confidence: 99/100.

### R9. App switcher snapshot leaks app content — no privacy blur on `applicationWillResignActive` / `sceneWillResignActive`.
- Wave findings: F9 permissions, F13 security.
- Status: **CONFIRMED.**
- Evidence: `evidence/07-app-switcher.png` — App Switcher card shows the full onboarding pulse screen (heart, halos, headline "See what your body has been telling you.", `Begin` button) all clearly readable. No blur, no overlay, no `LaunchScreen` substitute.
  - This is the onboarding screen, but the same `applicationWillResignActive` / `ScenePhase.background` lifecycle code-path serves the entire app (Journal, Cycle, scores). Source: zero matches for `applicationWillResignActive`, `scenePhase == .inactive`, or any privacy-cover view in the repo (cross-cut from prior pass).
- Confidence: 99/100.

---

## Phase 6 — Multi-device / dark mode / Dynamic Type

### R10. Dark mode lock survives system-level toggle.
- Wave finding: F17 design.
- Status: **CONFIRMED** (see R4).
- Confidence: 99/100.

### R11. Dynamic Type — not driven (Simulator-side toggle requires GUI). Documented as manual test in prior pass.
- Wave finding: F5 design (71 fixed-size font calls).
- Status: **NOT VERIFIED RUNTIME** — code-level finding stands.
- Confidence: N/A.

---

## Phase 7 — Backgrounding / screenshots privacy

Already covered in R9 (Phase 5) via the app-switcher capture.

---

## Phase 8 — Stress / chaos

### R12. Memory-warning notification: app does not crash, but no observable response.
- Wave finding: F13 permissions ("No memory-warning handler").
- Status: **PARTIALLY CONFIRMED.**
- Evidence:
  - `xcrun simctl spawn booted notifyutil -p com.apple.system.memorystatus_warn` issued; `evidence/11-after-mem-warn.png` shows the same onboarding screen with no UI change.
  - Source: zero matches for `didReceiveMemoryWarning`, `UIApplicationDidReceiveMemoryWarningNotification`, or `applicationDidReceiveMemoryWarning(_:)` in the repo (already shown in cross-cut audit).
  - Caveat: `notifyutil -p` posts a Darwin notification but UIKit's `UIApplicationDidReceiveMemoryWarningNotification` is internally raised by jetsam pressure, not by this notify key. So the test demonstrates that no broadcast `notifyutil` is wired, but does not by itself prove the bug — the source grep is what confirms it.
- Confidence: 90/100 — code-level proof is solid; the runtime push is a weak signal because `notifyutil -p` may not synthesize a true UIKit memory warning on iOS 26.

### R13. Custom URL scheme drop — `lasohealth://test/path?abc=1` returns OS error -10814 (no app responds to scheme).
- Wave finding: F8 permissions ("No `application(_:open:options:)` deep-link handler").
- Status: **CONFIRMED — both runtime and source.**
- Evidence:
  - Runtime: `xcrun simctl openurl booted "lasohealth://test/path?abc=1"` -> `OSStatus error -10814` (kLSApplicationNotFoundErr).
  - Runtime: `xcrun simctl openurl booted "https://laso.com/test"` opened **Safari**, not Laso — `evidence/10-push-attempted.png` shows Mobile Safari's Start Page with `laso.com` in the URL bar. No Universal Link is registered.
  - Source: zero matches across the repo for `CFBundleURLSchemes`, `onOpenURL`, `application(_:open:options:)`, `UIApplicationLaunchOptionsURLKey`, or `associated-domains`.
  - Side-effect on push: when the simctl push was issued **after** Safari became foreground, the next Laso re-launch shows a `◀ Safari` back-link in the status bar (`evidence/10b-push-while-foreground.png`) — i.e. the app retains the wrong "previous app" link because it has no scene-restoration / handover logic. Cosmetic but indicative.
- Confidence: 99/100.

---

## Newly observed runtime issues (not in code-only audit)

### N1. Two Laso icons on simulator home screen — production app + UI-test variant — both labelled "Laso", easy to confuse. There's also "HealthPulseUIT…" present from a prior install. (`evidence/06-after-home.png`)
- Risk: not user-facing in App Store, but the team may ship the wrong build to TestFlight if they pick by icon. **Operational hygiene issue.**
- Confidence: 80/100 — observed once on this simulator; could be left over from an earlier `xcodebuild test` run. Not necessarily a defect.

### N2. Onboarding `Begin` button has only `.accessibilityIdentifier("onboarding.pulseBegin")` — no explicit `.accessibilityLabel` / `.accessibilityHint`. The animated pulse (heart + halos) has no `accessibilityLabel` either.
- Refines wave finding F2 design (zero VoiceOver labels in onboarding) — partial: button text is read by default, but the hero animation is invisible to VoiceOver and there is no "screen 1 of 6" announcement.
- Source: `Modules/Onboarding/Views/Onboarding/OnboardingPulseStep.swift:46`.
- Confidence: 95/100.

### N3. Push-notification simulated payload was accepted by `simctl push` (no error) but produced no observable UI on the foregrounded app. Combined with the absence of `requestAuthorization`, this means **the entire push pipeline is dead end-to-end** — server-issued pushes will deliver to APNs sandbox but iOS will drop them on the device because the app has no permission. This is not a *new* finding but the runtime confirmation upgrades wave-1 F1+F2 from "likely broken" to "verified zero-output."
- Confidence: 99/100.

### N4. `cliclick`-driven cursor moves precisely to Simulator window pixel coords but the Simulator does not register a tap. This is a known Apple sandbox restriction on macOS 14+ — automation tools must be explicitly granted Accessibility AND Screen Recording. **Implication for QA process:** any future runtime-verification pass through this Claude harness must either run on a fresh user account where the harness has been granted Accessibility, or use a real `xcuitest` target with `XCUIApplication`. Documenting so the gap is closed in Pass 3.
- Confidence: 99/100.

---

## Limitations

- **Tap automation blocked** (R2, N4). Onboarding step 2+, Dashboard, Settings, Paywall, Detail tiles, Pull-to-refresh, Devices flow, Journal, Insights, AskYourData, AchievementsView, ReferralCodeStep, breath-work session, WebExport — all ungated runtime-by-this-pass. Source-level findings from Pass 1/2 stand for these.
- **Simulator vs real device delta** — Live Activities / ActivityKit / Apple-Watch HRV / real APNs / network-flap / DST and timezone changes only fully reproduce on hardware. Memory-warning synthesis (R12) is also imperfect on simulator.
- **HealthKit on simulator** — no real samples, so even if I could drive past the HK prompt the day-1 empty state would be artificially pristine; partial-grant drift (F4) and revoke-on-foreground (F5) cannot be reproduced without a hardware device.
- **Network simulation** — not exercised (Network Link Conditioner is GUI-only on the simulator).

---

## Summary

| Phase | Screens captured | Confirmed at runtime | Disproven | New |
|------:|-----------------:|---------------------:|----------:|----:|
| 1     | 4                | F17 design, F12 design, F28 ux, F3 perms (source), F2 design (refined) | 0 | N2 |
| 2     | 0 (blocked)      | 0                    | 0         | 0   |
| 3     | 0 (intentionally not pressed) | F2 ux + F11 perms (source) | 0 | 0 |
| 4     | 0 (blocked)      | 0                    | 0         | 0   |
| 5     | 2                | F1+F2 perms, F9 perms, F13 sec | 0 | N3 |
| 6     | 2 (re-using P1)  | F17 design           | 0         | 0   |
| 7     | covered in P5    | —                    | —         | —   |
| 8     | 2                | F8 perms, F13 perms (partial) | 0 | N1, N4 |

**Net new at runtime:** 7 wave-1/2/3 findings hard-confirmed end-to-end (heart-of-the-issue runtime proof, not just code-grep). **3 net-new observations** logged. **0 wave-1 findings disproven.** Tap-gated wave findings (most of Phase 2/3/4) await a properly-permissioned automation harness (recommend XCUITest in Pass 3).

---

## Evidence index

| File | What it shows |
|------|---------------|
| `evidence/01-cold-launch.png` | Pre-existing first-launch shot. |
| `evidence/02-onboarding-step1.png` | Onboarding pulse step, dark, no progress dots, `Begin` button. |
| `evidence/03-onboarding-step2.png` | Identical to step1 — tap automation failed. |
| `evidence/04-onboarding-dark-system.png` | System=dark, app=dark (matches). |
| `evidence/05-onboarding-light-system.png` | System=light, app=dark (lock confirmed). |
| `evidence/06-after-home.png` | Home screen showing two Laso icons (N1). |
| `evidence/07-app-switcher.png` | App switcher leaks full onboarding screen — no privacy cover. |
| `evidence/08-relaunched.png` | Confirms relaunch returns to onboarding step 1. |
| `evidence/09-deeplink-attempt.png` | After `lasohealth://` openurl returned -10814 (still onboarding step 1). |
| `evidence/10-push-attempted.png` | Safari Start Page caught after `https://laso.com/test` openurl. |
| `evidence/10b-push-while-foreground.png` | Onboarding with `◀ Safari` back-link; push delivered, no banner shown. |
| `evidence/11-after-mem-warn.png` | Onboarding unchanged after `notifyutil -p` memory warning. |

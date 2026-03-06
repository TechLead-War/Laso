<wizard-report>
# PostHog post-wizard report

The wizard has completed a deep integration of PostHog analytics into HealthPulse. The existing `PostHogManager.swift` wrapper was updated to read credentials from Xcode scheme environment variables (replacing the hardcoded placeholder). The PostHog iOS SDK (`posthog-ios` v3.45.0) was added as a Swift Package Manager dependency via `project.pbxproj`. Eight business-critical events covering the full user lifecycle — from first HealthKit connection through onboarding, calibration, trial, and subscription — were instrumented across four files.

| Event | Description | File |
|---|---|---|
| `onboarding_completed` | User finishes all 7 onboarding steps | `Views/Onboarding/OnboardingView.swift` |
| `healthkit_authorized` | User taps "Connect Apple Health" during onboarding | `Views/Onboarding/OnboardingView.swift` |
| `calibration_completed` | Initial baseline calibration succeeds | `Views/Onboarding/OnboardingView.swift` |
| `calibration_failed` | Initial baseline calibration fails (with error message + elapsed time) | `Views/Onboarding/OnboardingView.swift` |
| `subscription_purchased` | User successfully purchases a subscription | `Subscriptions/SubscriptionManager.swift` |
| `trial_started` | Status resolves to trial for the first time (transition from unknown) | `Subscriptions/SubscriptionManager.swift` |
| `subscription_expired` | Trial ends with no purchase (churn signal) | `Subscriptions/SubscriptionManager.swift` |
| `pro_feature_upgrade_tapped` | Free user taps "Upgrade to Pro" on a gated feature | `Views/Components/ProFeatureOverlay.swift` |

## Files modified

- **`Tracking/PostHogManager.swift`** — Replaced hardcoded placeholder keys with `PostHogEnv` enum reading from `ProcessInfo.processInfo.environment`. Added `fatalError` guard so misconfiguration is caught immediately at launch.
- **`Laso.xcodeproj/project.pbxproj`** — Added `XCRemoteSwiftPackageReference` for `posthog-ios` (≥ 3.45.0), `XCSwiftPackageProductDependency` for `PostHog`, and `PBXBuildFile` linking it into the Frameworks phase.
- **`Laso.xcodeproj/xcshareddata/xcschemes/HealthPulse.xcscheme`** — Added `POSTHOG_API_KEY` and `POSTHOG_HOST` as Run scheme environment variables.
- **`Views/Onboarding/OnboardingView.swift`** — 4 events: `onboarding_completed`, `healthkit_authorized`, `calibration_completed`, `calibration_failed`.
- **`Subscriptions/SubscriptionManager.swift`** — 3 events: `subscription_purchased`, `trial_started`, `subscription_expired`.
- **`Views/Components/ProFeatureOverlay.swift`** — 1 event: `pro_feature_upgrade_tapped`.

## Next steps

We've built a pinned dashboard and four insights for you to monitor user behavior:

- **Dashboard**: [Analytics basics](https://eu.posthog.com/project/136950/dashboard/556193)
- **Onboarding → Trial → Purchase Funnel**: [YfdtTzf7](https://eu.posthog.com/project/136950/insights/YfdtTzf7) — ordered 30-day conversion funnel
- **Subscriptions vs Churn (Weekly)**: [kC8zgaGP](https://eu.posthog.com/project/136950/insights/kC8zgaGP) — 90-day weekly trend
- **Pro Upgrade Intent**: [AU57U1IJ](https://eu.posthog.com/project/136950/insights/AU57U1IJ) — daily upgrade taps broken down by feature name
- **Onboarding Completions (Daily)**: [0SmdDg3H](https://eu.posthog.com/project/136950/insights/0SmdDg3H) — HealthKit connect → calibration → onboarding done

### Agent skill

We've left an agent skill folder in your project at `.claude/skills/posthog-integration-swift/`. You can use this context for further agent development when using Claude Code. This will help ensure the model provides the most up-to-date approaches for integrating PostHog.

</wizard-report>

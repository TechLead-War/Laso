# Visual Regression Workflow (Local)

This repo keeps approved screenshots in `visual-regression/baseline/`.

## Directory contract

- `visual-regression/baseline/` - committed approved screenshots
- `visual-regression/current/` - latest screenshots from current build (ignored)
- `visual-regression/reports/latest/` - compare output and diffs (ignored)
- `visual-regression/manifest.json` - complete flow/screen inventory with metadata

## Screenshot naming

Deterministic names — one file per flow step per theme:

`<ios_version>-<device>-<theme>-<locale>-<profile>-<step>.png`

Example: `ios26_2-iphone_17_pro-dark-en_in-main-home.png`

## Covered flows (10 data-independent + 9 data-dependent = 19 screens x 2 themes)

| Profile     | Step                | Description                          | Requires Data |
|-------------|---------------------|--------------------------------------|:---:|
| onboarding  | welcome             | App logo + Get Started               | |
| onboarding  | value-proposition   | Three value props                    | |
| onboarding  | profile-capture     | Name, gender, age form               | |
| onboarding  | connect-health      | HealthKit permissions checklist       | |
| onboarding  | focus-selection     | Health focus area chips              | |
| main        | home                | Today tab — full dashboard           | |
| main        | live                | Live vitals tab                      | |
| main        | explore             | Explore/analysis tab                 | |
| detail      | recovery-hero       | Score guide sheet                    | Y |
| detail      | vitality-detail     | Vitality age breakdown               | Y |
| detail      | sleep-coach         | Sleep need + debt + history          | Y |
| detail      | strain-detail       | Strain score + zones + weekly        | Y |
| detail      | stress-monitor      | Stress score + HRV (conditional)     | Y |
| detail      | cycle-detail        | Cycle phase + history (conditional)  | Y |
| detail      | insights-detail     | Action Items / All Insights tabs     | Y |
| detail      | weekly-review       | Weekly score + wins + coach plan     | Y |
| detail      | achievements        | Level + streaks + achievement list   | Y |
| settings    | main                | All settings sections                | |
| settings    | connected-devices   | Device list with status              | |

## Test methods

| Test method            | Appearance | Screens captured           |
|------------------------|------------|----------------------------|
| testOnboardingDark     | Dark       | 5 onboarding               |
| testOnboardingLight    | Light      | 5 onboarding               |
| testMainFlowDark       | Dark       | 3 tabs                     |
| testMainFlowLight      | Light      | 3 tabs                     |
| testHomeDetailsDark    | Dark       | 0-9 detail (data-dependent)|
| testHomeDetailsLight   | Light      | 0-9 detail (data-dependent)|
| testSettingsDark       | Dark       | 2 settings                 |
| testSettingsLight      | Light      | 2 settings                 |

## Local commands

1. Build for testing:

```bash
xcodebuild build-for-testing \
  -project Laso.xcodeproj \
  -scheme Laso \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build/visual-tests/DerivedData
```

2. Run all screenshot tests:

```bash
xcodebuild test-without-building \
  -xctestrun build/visual-tests/DerivedData/Build/Products/*.xctestrun \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:LasoUITests
```

3. Approve current as new baseline:

```bash
rm -f visual-regression/baseline/*.png
cp visual-regression/current/*.png visual-regression/baseline/
```

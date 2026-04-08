# Device Compatibility DRP

Date: 2026-04-07
Project: Laso / HealthPulse
Prepared from: local code inspection, simulator build verification, official vendor docs and official App Store listings

## Scope And Limits

- This is a verification report, not a marketing summary.
- I verified repository claims against code and official brand sources where possible.
- I did not run end-to-end hardware tests with physical watches, rings, scales, or CGMs.
- I did run a simulator build. `xcodebuild -scheme Laso -project Laso.xcodeproj -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO build` succeeded.
- No automated test target exists in this repo at the moment.

## Executive Summary

- The website device list and app device list are broadly aligned for 33 named third-party brands. The app also contains `iPhone` and `generic`, for 35 total enum entries.
- The website claim `50+ devices supported` is not substantiated by the current repo. The hardcoded app catalog has 33 named third-party devices, not 50+.
- The website claim `86 health metrics` is not substantiated by the current repo. `HealthMetric` currently defines 72 enum cases.
- The website claim `No extra apps. No manual setup.` is false relative to the app implementation. The app explicitly requires companion apps plus Apple Health sharing for third-party sources.
- The app does not do full-capability device detection. It only scans Apple Health sources for five metrics: heart rate, steps, sleep duration, blood oxygen, and active calories.
- Because of that scan design, at least `Renpho`, `Dexcom`, and `Freestyle Libre` are blind spots in the Connected Devices screen even if they are syncing to Apple Health.
- The Live tab is Apple Watch-specific in the current implementation. It is not a generic real-time wearable stream.
- The website misclassifies `WHOOP` under `Smart Rings`.
- Several devices are overclaimed in the app's hardcoded `supportedMetrics`, especially `Fitbit`, `Samsung Galaxy`, `Google Pixel Watch`, `Huawei`, `Noise`, `boAt`, `Fire-Boltt`, and `TAG Heuer`.

## Repo-Backed Findings

### 1. Catalog Parity

- App catalog: `Models/SupportedDevice.swift` defines 35 enum values total, including `iPhone` and `generic`.
- Website catalog: `website/src/pages/index.astro` lists 33 named third-party devices.
- The 33 named third-party devices in app and website match, except capitalization: app uses `Whoop`, website uses `WHOOP`.
- Website classification bug: `WHOOP` is placed under `Smart Rings`.

### 2. Metric Count Claim

- Website claim: `86 health metrics` appears in SEO JSON-LD, hero/supporting copy, and FAQ.
- Code reality: `HealthMetric` currently contains 72 cases.
- HealthKit authorization is driven from `HealthMetric.allCases`, so the implemented metric surface is the enum, not the website copy.

### 3. Device Detection Is Narrow

- `DeviceSourceManager` only scans representative metrics:
  - `heartRate`
  - `steps`
  - `sleepDuration`
  - `bloodOxygen`
  - `activeCalories`
- Devices only appear in Connected Devices if their Apple Health source writes at least one of those five metrics and the bundle prefix matches a hardcoded prefix.
- This is not equivalent to "device works with Laso."

### 4. Guaranteed Detection Blind Spots

- `Renpho`: app claims only `weight`, `bmi`, `bodyFatPercentage`. None are scanned for source detection.
- `Dexcom`: app claims only `bloodGlucose`. Not scanned for source detection.
- `Freestyle Libre`: app claims only `bloodGlucose`. Not scanned for source detection.

### 5. Feature Surfaces Are Hardcoded

- The unconnected-device UI shows `X metrics via Companion App` from `SupportedDevice.supportedMetrics`.
- That is a hardcoded assumption, not a runtime capability check.
- The connected-device view does show actual `metricsProvided`, but only after the device has already been discovered by the narrow source scan.

### 6. Third-Party Setup Is Explicitly Required

- The app setup guide says third-party devices connect through Apple Health.
- The setup flow tells the user to install the companion app, pair the device, open Apple Health sync inside the companion app, and allow writes to Apple Health.
- This directly contradicts the website copy `No extra apps. No manual setup.`

## Claim Audit

| Claim | Current State | Verdict |
|---|---|---|
| `50+ devices supported` | Repo hardcodes 33 named third-party devices, plus `iPhone` and `generic` | Overstated |
| `86 health metrics` | Code defines 72 `HealthMetric` cases | Overstated |
| `No extra apps. No manual setup.` | App requires companion apps and Apple Health setup for third-party devices | False |
| `If it syncs to Apple Health, Laso can read and analyze it` | Not universally true for Connected Devices because detection only scans 5 metrics | Overstated |
| Generic live / real-time wearable implication | Live implementation is Apple Watch-centric | Overstated |

## Per-Device Verification Matrix

Status legend:

- `Verified`: official source clearly documents Apple Health / HealthKit support.
- `Partial`: official source documents some Apple Health support, but not the full metric set or not the claimed direction.
- `Unverified`: I did not find an official source that proves the claimed Apple Health write path.

| Device | Official Apple Health Status | Officially Documented Metrics Or Direction | Laso Risk | Verdict |
|---|---|---|---|---|
| Apple Watch | Verified | Native Apple Health source | Strongest-supported path in app and live features | Keep |
| iPhone | Verified | Native Apple Health source | Works for passive phone metrics only | Keep |
| Garmin | Verified | Active energy, body fat %, BMI, flights climbed, HR, resting energy, sleep, steps, walking/running distance, water, weight, workouts | App underclaims some official Garmin fields and may overclaim others | Keep, tighten metric list |
| Fitbit | Unverified for direct Apple Health write | Official-source evidence for direct Fitbit -> Apple Health sync not found; Fitbit community product expert says third-party bridge needed | App and website currently present Fitbit as compatible | High-risk claim |
| Oura Ring | Verified | Active energy, HR, height, mindful minutes, respiratory rate, sleep duration/start/end/stages, steps, weight, workouts, workout calories, distance, duration, type | App path is plausible; exact in-app metric list should match Oura docs | Keep |
| WHOOP | Partial | Official sources support Apple Health integration, but field matrix is partial and HR write behavior is conditional | Website places WHOOP under Smart Rings and app likely overstates exact fields | Keep, reclassify and tighten |
| Samsung Galaxy Watch / Samsung Health | Partial | Official iPhone app explicitly says Apple Health can share step count into Samsung Health; I did not verify Galaxy Watch export back to Apple Health on iOS | App currently claims broad `midMetrics` support | High-risk claim |
| Amazfit / Zepp | Partial | Official evidence exists for Apple Health sync in Zepp Life / Zepp Active contexts, but not a clean universal export matrix for all Zepp/Amazfit products | App claims broad `midMetrics` support | Soften claim |
| Withings | Verified | Sleep, steps, distance, calories, weight, body composition, HR, VO2 max, BP export; steps and HR import | App underclaims VO2 max and may mislead if user only owns a scale and no scanned metrics are present | Keep, refine copy |
| Polar | Verified | Active energy, HR, resting energy, sleep, steps, weight, workouts | App support is plausible; exact app metric list should mirror Polar docs | Keep |
| Xiaomi Smart Band / Mi Fitness | Partial | Official docs confirm Apple Health sync with selectable items; named examples include calories, steps, sleep, heart rate, stress, SpO2, workouts depending on model | App claims `midMetrics` generically for the whole family | Soften claim |
| Google Pixel Watch | Unverified for Apple Health export | Google Fit iOS reads from Apple Health; I did not verify Pixel Watch -> Apple Health via official sources | App maps Pixel Watch to `Google Fit`, which is likely the wrong iOS companion path for modern Pixel Watch | High-risk claim |
| Noise | Verified, but partial field proof | Official App Store copy ties movement, calories, and sleep to Apple Health; HR/stress/SpO2 are in-app features but not explicitly tied to Apple Health export | App claims broader `basicMetrics` | Soften metric claim |
| boAt | Verified, but partial field proof | Official source explicitly mentions HealthKit integration and steps | App claims broader `basicMetrics` | Soften metric claim |
| Fire-Boltt | Verified, but partial field proof | Official sources say device/exercise data sync to Apple Health; full metric list not enumerated | App claims broader `basicMetrics` | Soften metric claim |
| Huawei Watch / Huawei Health | Verified, but narrow official wording | Official iPhone app explicitly mentions HealthKit sync for weight and exercise/motion data | App claims `fullMetrics`, which is much broader than verified wording | Overclaimed |
| COROS | Verified | Cycling distance, HR, sleep, steps, swimming distance, walking/running distance | App may overclaim beyond official list | Keep, tighten metric list |
| Suunto | Partial | Official sources confirm Apple Health connection, but not a clean field matrix | App claims `fullMetrics + vo2Max - bloodOxygen` | Soften claim |
| Wahoo | Partial | Official support confirms Apple Health sync in app / ELEMNT RIVAL context; explicit list is limited | App may overclaim | Soften claim |
| TicWatch / Mobvoi | Verified, but narrow official wording | Motion recording, heart rate, sleep | App claims `midMetrics` across the family | Likely overclaimed |
| Casio G-Shock | Verified | Steps, HR on HR-capable models, distance, time, training effect | App claims `basicMetrics` broadly | Keep, qualify model dependence |
| TAG Heuer | Verified, but narrow official wording | Sport sessions with activity type and start date in FAQ; App Store lists richer workout summary fields | App claims `basicMetrics` broadly | Soften metric claim |
| Fossil | Partial, legacy-weighted | Clear Apple Health wording exists for legacy app; current app evidence is weaker | App claims `midMetrics` for current Fossil | High-risk claim |
| Ultrahuman Ring Air | Verified | HealthKit/Apple Health support documented; named examples include HRV, temperature, energy expenditure, plus sleep/workout/menstrual sync in official materials | App path is plausible; exact metric list not fully enumerated | Keep, tighten metric list |
| RingConn | Verified | Official docs mention sleep stages, HRV, steps, blood oxygen to Apple Health | App underclaims because `ringMetrics` excludes steps | Fix app metric list |
| Circular Ring | Verified | Official sources confirm Apple HealthKit sync for sleep, activity, HR and broader health data | App path is plausible; exact field matrix is not exhaustively documented | Keep, tighten metric list |
| Omron | Verified, but exact Apple Health field list is vague | Official docs confirm Apple Health exchange; public materials describe BP, weight, activity, steps, sleep, BMI in app | App claims only BP + HR/RHR; may underclaim or misrepresent by device | Keep, qualify by product |
| Renpho | Verified for RENPHO Health, partial for ring | Official sources document Apple Health sync for body composition fields; ring-specific export mapping is not verified | Connected Devices scan cannot detect scale-only Renpho because it never scans weight/body-fat/BMI | Fix detection and copy |
| Dexcom | Verified | Glucose to Apple Health is documented; official source says there is a 3-hour delay | Connected Devices scan cannot detect glucose-only sources | Fix detection and call out delay |
| Freestyle Libre / LibreLink | Unverified from official sources checked | I did not verify an official Abbott Apple Health / HealthKit export source | App lists it as supported and detection cannot discover it anyway | High-risk claim |
| Eight Sleep | Partial | Official terms allow Apple Health connection, but exact exchanged metric list is not clearly documented | App claims sleep stages, HR, RHR, body temp; detection depends on scanned metrics | Soften claim |
| Biostrap | Partial-to-Verified | Official listing says biometrics sync with Apple Health; explicitly mentions HR, HRV, SpO2, respiratory rate, sleep stages | App path is plausible | Keep, tighten metric list |
| Myzone | Verified | Activity calories, height, weight, BMI, BMR, body fat | App underclaims by listing mostly HR/workout fields only | Fix app metric list |
| Peloton | Partial | Official sources support Apple Health read/write and Apple Watch workout integration, but no fixed export matrix | App claims HR/RHR/calories/workouts/distance cycling | Keep, qualify fields |

## Device-Level Feature Extraction Mismatches

These are the highest-signal mismatches between official vendor evidence and Laso's hardcoded `supportedMetrics`.

- `Fitbit`: app presents direct compatibility, but official direct Apple Health write support is not verified.
- `Samsung Galaxy`: app implies broad Apple Health-based compatibility, but official iPhone evidence only clearly proves Apple Health step data flowing into Samsung Health.
- `Google Pixel Watch`: app maps the device to `Google Fit`, which is likely the wrong iOS companion path for modern Pixel Watch. Official Apple Health export is not verified.
- `Huawei`: app claims `fullMetrics`, but official iPhone wording only explicitly names weight and exercise/motion sync through HealthKit.
- `RingConn`: official docs mention steps in Apple Health, but app `ringMetrics` excludes steps.
- `Withings`: official docs mention VO2 max export, but app does not include `vo2Max` in Withings `supportedMetrics`.
- `Myzone`: official listing includes height, weight, BMI, BMR, body fat; app only shows HR/workout-heavy metrics.
- `Renpho`, `Dexcom`, `Freestyle Libre`: even where official Apple Health support exists or may exist, the current Connected Devices scan will not surface them because it never queries weight/body-fat/glucose source types.

## Work Required

### P0

- Remove or rewrite the website claims:
  - `50+ devices supported`
  - `86 health metrics`
  - `No extra apps. No manual setup.`
- Remove or qualify unsupported/high-risk device claims:
  - `Fitbit`
  - `Google Pixel Watch`
  - `Freestyle Libre`
  - `Samsung Galaxy Watch` on iOS as a broad Apple Health export claim
  - `Fossil` current-generation broad support
- Fix the website classification error that puts `WHOOP` under `Smart Rings`.

### P1

- Rework `DeviceSourceManager` device detection to scan all relevant HealthKit types, or at minimum add source queries for:
  - `bloodGlucose`
  - `bodyMass`
  - `bodyMassIndex`
  - `bodyFatPercentage`
  - `bloodPressureSystolic`
  - `bloodPressureDiastolic`
- Stop using hardcoded `supportedMetrics` as user-facing proof for unconnected devices unless each list has been validated against official docs.
- Split brand-level entries where needed. Several brands cover multiple product types with different Apple Health behavior.
- Fix `Google Pixel Watch` mapping. The current app maps it to `Google Fit`, not the modern Fitbit-centric path.

### P2

- Build a physical-device validation matrix:
  - device
  - iOS companion app
  - Apple Health categories enabled
  - whether Laso detects device in Connected Devices
  - actual metrics shown in `metricsProvided`
  - last sync behavior
  - live feature behavior
- Capture at least one real Apple Health source sample per brand family and save screenshots / logs.
- Add automated coverage for device detection logic with mock source bundle IDs and metric sets.

## File And Source References

Local code:

- `Models/SupportedDevice.swift`
- `Models/HealthMetric.swift`
- `Data/DeviceSourceManager.swift`
- `Data/HealthKitMetricRegistry.swift`
- `Data/HealthKitManager.swift`
- `Views/Devices/ConnectedDevicesView.swift`
- `Views/Devices/DeviceDetailView.swift`
- `Views/Devices/DeviceSetupGuideView.swift`
- `ViewModels/ConnectedDevicesViewModel.swift`
- `ViewModels/LiveViewModel.swift`
- `website/src/pages/index.astro`
- `Info.plist`

Official vendor sources used in verification:

- Oura: https://support.ouraring.com/hc/en-us/articles/360025438734-Apple-Health-Integration
- Garmin: https://support.garmin.com/en-US/?faq=lK5FPB9iPF5PXFkIpFlFPA&productID=125677
- Fitbit community official forum: https://community.fitbit.com/t5/iOS-App/Fitbit-does-not-appear-in-iOS-Health-App/td-p/5544463
- Polar: https://support.polar.com/us-en/support/connecting_polar_flow_with_apple_health
- COROS: https://support.coros.com/hc/en-us/articles/360041549551-Connecting-Apple-Health-with-COROS-App
- Suunto: https://apps.apple.com/us/app/suunto/id1230327951
- Wahoo: https://support.wahoofitness.com/hc/en-us/articles/360018076140-Using-ELEMNT-RIVAL-with-Apple-Health
- Peloton: https://www.onepeloton.com/en-AU/blog/wearables-integration
- Myzone: https://apps.apple.com/us/app/myzone-make-movement-count/id969938732
- Biostrap: https://apps.apple.com/us/app/biostrap/id1187535208
- Ultrahuman: https://blog.ultrahuman.com/blog/how-to-access-your-hrv-data-on-apple-health/
- RingConn: https://de.ringconn.com/en/blogs/guides/smart-ring-kompatibilitaet-apple-health-samsung-health
- Circular: https://www.circular.xyz/post/circular-ring-achieves-seamless-compatibility-with-apple-healthkit
- Samsung Health: https://apps.apple.com/us/app/samsung-health/id1224541484
- Google Fit: https://apps.apple.com/us/app/google-fit-activity-tracker/id1433864494
- Huawei Health: https://apps.apple.com/us/app/id1325481372
- Zepp Life: https://apps.apple.com/us/app/zepp-life-formerly-mifit/id938688461
- Xiaomi FAQ: https://www.mi.com/global/support/faq/details/KA-230360/
- Mobvoi: https://apps.apple.com/us/app/mobvoi/id1287014629
- Fossil legacy: https://apps.apple.com/us/app/fossil-q-legacy/id1266525345
- TAG Heuer: https://faq.tagheuer.com/articles/en_US/FAQ/000051127
- G-SHOCK MOVE: https://apps.apple.com/us/app/g-shock-move/id1498029407
- NoiseFit Assist: https://apps.apple.com/us/app/noisefit-assist/id1569343572
- boAt: https://apps.apple.com/us/app/boat-crest/id1573391983
- Fire-Boltt: https://apps.apple.com/us/app/fireboltt-invincible/id1603034044
- Withings: https://support.withings.com/hc/en-us/articles/203934573-Partner-Apps-Frequently-asked-questions-about-Apple-Health
- Omron: https://omronhealthcare.com/omron-connect-app
- Renpho: https://apps.apple.com/us/app/renpho-health/id1543340610
- Dexcom: https://www.dexcom.com/en-us/faqs/how-do-i-share-glucose-data-from-dexcom-g6-app-to-apple-health-app
- Abbott LibreLink newsroom page checked: https://www.abbott.com/en-us/corpnewsroom/diabetes-care/freestyle-librelink
- Eight Sleep terms: https://www.eightsleep.com/ae/app-terms-conditions/

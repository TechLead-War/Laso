import Foundation
import SwiftUI

/// A setup step for configuring a wearable's companion app to sync with HealthKit
struct SetupStep: Identifiable {
    let id = UUID()
    let instruction: String
}

/// All supported wearable devices and their HealthKit integration details
enum SupportedDevice: String, CaseIterable, Identifiable {
    var id: String { rawValue }

    case appleWatch
    case iPhone
    case garmin
    case fitbit
    case ouraRing
    case whoop
    case samsungGalaxy
    case amazfit
    case withings
    case polar
    case xiaomiSmartBand
    case googlePixelWatch
    case noise
    case boAt
    case fireBoltt
    case huawei
    case coros
    case suunto
    // Sports / Fitness Watches
    case wahoo
    case ticWatch
    case casioGShock
    case tagHeuer
    case fossil
    // Smart Rings
    case ultrahumanRing
    case ringConn
    case circularRing
    // Health / Medical Devices
    case omron
    case renpho
    case dexcom
    case freestyleLibre
    case eightSleep
    // Fitness Platforms
    case biostrap
    case myzone
    case peloton
    case generic

    var displayName: String {
        switch self {
        case .appleWatch: return "Apple Watch"
        case .iPhone: return "iPhone"
        case .garmin: return "Garmin"
        case .fitbit: return "Fitbit"
        case .ouraRing: return "Oura Ring"
        case .whoop: return "Whoop"
        case .samsungGalaxy: return "Samsung Galaxy"
        case .amazfit: return "Amazfit"
        case .withings: return "Withings"
        case .polar: return "Polar"
        case .xiaomiSmartBand: return "Xiaomi Smart Band"
        case .googlePixelWatch: return "Google Pixel Watch"
        case .noise: return "Noise"
        case .boAt: return "boAt"
        case .fireBoltt: return "Fire-Boltt"
        case .huawei: return "Huawei Watch"
        case .coros: return "COROS"
        case .suunto: return "Suunto"
        case .wahoo: return "Wahoo"
        case .ticWatch: return "TicWatch"
        case .casioGShock: return "Casio G-Shock"
        case .tagHeuer: return "TAG Heuer"
        case .fossil: return "Fossil"
        case .ultrahumanRing: return "Ultrahuman Ring Air"
        case .ringConn: return "RingConn"
        case .circularRing: return "Circular Ring"
        case .omron: return "Omron"
        case .renpho: return "Renpho"
        case .dexcom: return "Dexcom"
        case .freestyleLibre: return "Freestyle Libre"
        case .eightSleep: return "Eight Sleep"
        case .biostrap: return "Biostrap"
        case .myzone: return "Myzone"
        case .peloton: return "Peloton"
        case .generic: return "Unknown Device"
        }
    }

    var companionAppName: String {
        switch self {
        case .appleWatch, .iPhone: return "Apple Health"
        case .garmin: return "Garmin Connect"
        case .fitbit: return "Fitbit"
        case .ouraRing: return "Oura"
        case .whoop: return "Whoop"
        case .samsungGalaxy: return "Samsung Health"
        case .amazfit: return "Zepp"
        case .withings: return "Withings Health Mate"
        case .polar: return "Polar Flow"
        case .xiaomiSmartBand: return "Mi Fitness"
        case .googlePixelWatch: return "Google Fit"
        case .noise: return "NoiseFit"
        case .boAt: return "boAt Wearables"
        case .fireBoltt: return "FireBoltt"
        case .huawei: return "Huawei Health"
        case .coros: return "COROS"
        case .suunto: return "Suunto"
        case .wahoo: return "Wahoo Fitness"
        case .ticWatch: return "Mobvoi"
        case .casioGShock: return "G-SHOCK MOVE"
        case .tagHeuer: return "TAG Heuer Connected"
        case .fossil: return "Fossil Smartwatches"
        case .ultrahumanRing: return "Ultrahuman"
        case .ringConn: return "RingConn"
        case .circularRing: return "Circular"
        case .omron: return "OMRON connect"
        case .renpho: return "Renpho"
        case .dexcom: return "Dexcom"
        case .freestyleLibre: return "LibreLink"
        case .eightSleep: return "Eight Sleep"
        case .biostrap: return "Biostrap"
        case .myzone: return "Myzone"
        case .peloton: return "Peloton"
        case .generic: return "Companion App"
        }
    }

    var companionAppBundlePrefixes: [String] {
        switch self {
        case .appleWatch: return ["com.apple.health", "com.apple.watch"]
        case .iPhone: return ["com.apple.Health", "com.apple.health"]
        case .garmin: return ["com.garmin"]
        case .fitbit: return ["com.fitbit"]
        case .ouraRing: return ["com.ouraring"]
        case .whoop: return ["com.whoop"]
        case .samsungGalaxy: return ["com.sec.samsung", "com.samsung.health"]
        case .amazfit: return ["com.huami", "com.amazfit"]
        case .withings: return ["com.withings"]
        case .polar: return ["com.polar"]
        case .xiaomiSmartBand: return ["com.xiaomi", "com.mi."]
        case .googlePixelWatch: return ["com.google.ios.fit", "com.google.Fit"]
        case .noise: return ["com.noisefit"]
        case .boAt: return ["com.boat", "com.imaginmarketing"]
        case .fireBoltt: return ["com.fireboltt"]
        case .huawei: return ["com.huawei.health"]
        case .coros: return ["com.coros"]
        case .suunto: return ["com.suunto"]
        case .wahoo: return ["com.wahoofitness"]
        case .ticWatch: return ["com.mobvoi"]
        case .casioGShock: return ["jp.co.casio"]
        case .tagHeuer: return ["com.tagheuer"]
        case .fossil: return ["com.fossil"]
        case .ultrahumanRing: return ["com.ultrahuman"]
        case .ringConn: return ["com.ringconn"]
        case .circularRing: return ["com.circular"]
        case .omron: return ["jp.co.omron.healthcare"]
        case .renpho: return ["com.renpho"]
        case .dexcom: return ["com.dexcom"]
        case .freestyleLibre: return ["com.abbott.librelink"]
        case .eightSleep: return ["com.eightsleep"]
        case .biostrap: return ["com.biostrap"]
        case .myzone: return ["com.myzone"]
        case .peloton: return ["com.onepeloton"]
        case .generic: return []
        }
    }

    var appStoreURL: URL? {
        switch self {
        case .appleWatch, .iPhone, .generic: return nil
        case .garmin: return URL(string: "https://apps.apple.com/app/garmin-connect/id583446403")
        case .fitbit: return URL(string: "https://apps.apple.com/app/fitbit-health-fitness/id462638897")
        case .ouraRing: return URL(string: "https://apps.apple.com/app/oura-ring/id1043837948")
        case .whoop: return URL(string: "https://apps.apple.com/app/whoop/id933944389")
        case .samsungGalaxy: return URL(string: "https://apps.apple.com/app/samsung-health/id1224498498")
        case .amazfit: return URL(string: "https://apps.apple.com/app/zepp-formerly-amazfit/id1127269366")
        case .withings: return URL(string: "https://apps.apple.com/app/withings-health-mate/id542701020")
        case .polar: return URL(string: "https://apps.apple.com/app/polar-flow/id717172678")
        case .xiaomiSmartBand: return URL(string: "https://apps.apple.com/app/mi-fitness/id1502091498")
        case .googlePixelWatch: return URL(string: "https://apps.apple.com/app/google-fit/id1433864494")
        case .noise: return URL(string: "https://apps.apple.com/app/noisefit-health-fitness/id1498457147")
        case .boAt: return URL(string: "https://apps.apple.com/app/boat-wearables/id1542443145")
        case .fireBoltt: return URL(string: "https://apps.apple.com/app/fireboltt-pro/id6480042961")
        case .huawei: return URL(string: "https://apps.apple.com/app/huawei-health/id1174646498")
        case .coros: return URL(string: "https://apps.apple.com/app/coros/id1169521325")
        case .suunto: return URL(string: "https://apps.apple.com/app/suunto/id1230327951")
        case .wahoo: return URL(string: "https://apps.apple.com/app/wahoo-fitness/id391599899")
        case .ticWatch: return URL(string: "https://apps.apple.com/app/mobvoi/id1454523498")
        case .casioGShock: return URL(string: "https://apps.apple.com/app/g-shock-move/id1472764049")
        case .tagHeuer: return URL(string: "https://apps.apple.com/app/tag-heuer-connected/id1456817498")
        case .fossil: return URL(string: "https://apps.apple.com/app/fossil-smartwatches/id1027498498")
        case .ultrahumanRing: return URL(string: "https://apps.apple.com/app/ultrahuman/id1547498498")
        case .ringConn: return URL(string: "https://apps.apple.com/app/ringconn/id6443824498")
        case .circularRing: return URL(string: "https://apps.apple.com/app/circular/id1571234498")
        case .omron: return URL(string: "https://apps.apple.com/app/omron-connect/id1003177498")
        case .renpho: return URL(string: "https://apps.apple.com/app/renpho/id1219889498")
        case .dexcom: return URL(string: "https://apps.apple.com/app/dexcom-g7/id1431476498")
        case .freestyleLibre: return URL(string: "https://apps.apple.com/app/librelink/id1307476498")
        case .eightSleep: return URL(string: "https://apps.apple.com/app/eight-sleep/id1127389498")
        case .biostrap: return URL(string: "https://apps.apple.com/app/biostrap/id1187459498")
        case .myzone: return URL(string: "https://apps.apple.com/app/myzone/id874028498")
        case .peloton: return URL(string: "https://apps.apple.com/app/peloton/id792750948")
        }
    }

    var systemImageName: String {
        switch self {
        case .appleWatch: return "applewatch"
        case .iPhone: return "iphone"
        case .ouraRing, .ultrahumanRing, .ringConn, .circularRing: return "circle.circle"
        case .whoop: return "waveform.path.ecg.rectangle"
        case .withings, .renpho: return "scalemass.fill"
        case .omron: return "waveform.path.ecg"
        case .dexcom, .freestyleLibre: return "drop.fill"
        case .eightSleep: return "bed.double.fill"
        case .myzone: return "heart.fill"
        case .wahoo, .peloton: return "figure.indoor.cycle"
        case .generic: return "sensor.fill"
        default: return "watchface.applewatch.case"
        }
    }

    var iconColor: Color {
        switch self {
        case .appleWatch, .iPhone, .coros, .wahoo: return .blue
        case .garmin: return .cyan
        case .fitbit: return .teal
        case .ouraRing, .ultrahumanRing, .circularRing: return .mint
        case .whoop, .xiaomiSmartBand, .fireBoltt, .myzone: return .orange
        case .samsungGalaxy, .suunto, .tagHeuer: return .indigo
        case .amazfit, .polar, .noise, .boAt, .huawei, .peloton: return .red
        case .withings, .googlePixelWatch, .dexcom, .freestyleLibre: return .green
        case .ticWatch, .fossil, .biostrap: return .purple
        case .casioGShock: return .yellow
        case .ringConn: return .pink
        case .omron, .renpho: return .teal
        case .eightSleep: return .cyan
        case .generic: return .secondary
        }
    }

    // MARK: - Metric Tiers (shared sets to reduce duplication)

    /// Basic: HR, steps, calories, distance, SpO2, basic sleep, workouts
    private static let basicMetrics: Set<HealthMetric> = [
        .heartRate, .restingHeartRate,
        .sleepDuration,
        .steps, .activeCalories, .distanceWalkingRunning,
        .bloodOxygen,
        .workoutCount, .workoutDuration
    ]

    /// Mid: basic + sleep stages
    private static let midMetrics: Set<HealthMetric> = basicMetrics.union([
        .sleepREM, .sleepDeep, .sleepCore, .sleepAwake
    ])

    /// Full: mid + HRV
    private static let fullMetrics: Set<HealthMetric> = midMetrics.union([
        .heartRateVariability
    ])

    /// Ring: full + body temp, but no steps/distance (smart rings)
    private static let ringMetrics: Set<HealthMetric> = fullMetrics.union([
        .bodyTemperature
    ]).subtracting([.steps, .distanceWalkingRunning])

    var supportedMetrics: Set<HealthMetric> {
        switch self {
        case .appleWatch:
            return Set(HealthMetric.allCases)
        case .iPhone:
            return [.steps, .distanceWalkingRunning, .flightsClimbed, .exerciseMinutes, .walkingSpeed, .activeCalories]
        case .garmin:
            return Self.fullMetrics.union([.exerciseMinutes, .vo2Max, .respiratoryRate])
        case .ouraRing:
            return Self.fullMetrics.union([.respiratoryRate, .bodyTemperature])
                .subtracting([.distanceWalkingRunning])
        case .whoop:
            return Self.fullMetrics.union([.respiratoryRate])
                .subtracting([.steps, .distanceWalkingRunning])
        case .withings:
            return Self.fullMetrics.union([.weight, .bmi, .bodyFatPercentage, .bloodPressureSystolic, .bloodPressureDiastolic])
        case .polar:
            return Self.fullMetrics.union([.vo2Max]).subtracting([.bloodOxygen])
        case .coros:
            return Self.fullMetrics.union([.vo2Max])
        case .suunto:
            return Self.fullMetrics.union([.vo2Max]).subtracting([.bloodOxygen])
        case .huawei:
            return Self.fullMetrics
        case .fitbit, .samsungGalaxy, .amazfit, .xiaomiSmartBand, .googlePixelWatch, .ticWatch, .fossil:
            return Self.midMetrics
        case .noise, .boAt, .fireBoltt, .casioGShock, .tagHeuer:
            return Self.basicMetrics
        case .ultrahumanRing, .ringConn, .circularRing:
            return Self.ringMetrics
        case .omron:
            return [.bloodPressureSystolic, .bloodPressureDiastolic, .heartRate, .restingHeartRate]
        case .renpho:
            return [.weight, .bmi, .bodyFatPercentage]
        case .dexcom, .freestyleLibre:
            return [.bloodGlucose]
        case .eightSleep:
            return [.sleepDuration, .sleepREM, .sleepDeep, .sleepCore, .sleepAwake,
                    .heartRate, .restingHeartRate, .bodyTemperature]
        case .biostrap:
            return Self.fullMetrics.union([.respiratoryRate])
        case .myzone:
            return [.heartRate, .restingHeartRate, .activeCalories,
                    .workoutCount, .workoutDuration]
        case .peloton:
            return [.heartRate, .restingHeartRate, .activeCalories,
                    .workoutCount, .workoutDuration, .distanceCycling]
        case .wahoo:
            return Self.basicMetrics.union([.distanceCycling])
        case .generic:
            return []
        }
    }

    // MARK: - Setup Steps

    /// Custom Apple Health navigation path per device (only for non-standard paths)
    private var healthSyncPath: String? {
        switch self {
        case .garmin: return "Settings → Health → Apple Health → enable all categories"
        case .fitbit: return "Account → App Settings → enable Apple Health sync"
        case .samsungGalaxy: return "Settings → Connected Services → Apple Health"
        case .amazfit: return "Profile → Add Accounts → Apple Health → enable all"
        case .withings: return "Profile → Health → Apple Health → enable all"
        case .huawei: return "Me → Settings → Data Sharing → Apple Health → enable all"
        case .suunto: return "Settings → Partner Services → Apple Health → enable all"
        case .wahoo: return "Settings → Health → Apple Health → enable all categories"
        case .omron: return "More → App Settings → Apple Health → enable all"
        case .renpho: return "Me → Apple Health → enable all"
        case .dexcom: return "Settings → Health → Apple Health → enable glucose sharing"
        case .freestyleLibre: return "Connected Apps → Apple Health → enable glucose"
        case .eightSleep: return "Settings → Health → Apple Health → enable all"
        case .peloton: return "More → Health App → Apple Health → enable all"
        default: return nil
        }
    }

    var setupSteps: [SetupStep] {
        switch self {
        case .appleWatch:
            return [
                SetupStep(instruction: "Pair your Apple Watch with your iPhone via the Watch app"),
                SetupStep(instruction: "Open the Watch app → Health → enable all health categories"),
                SetupStep(instruction: "Data syncs automatically to Apple Health")
            ]
        case .iPhone:
            return [
                SetupStep(instruction: "iPhone sensors track steps, distance, and flights automatically"),
                SetupStep(instruction: "Open Settings → Privacy & Security → Motion & Fitness → enable Fitness Tracking"),
                SetupStep(instruction: "Data appears in Apple Health automatically")
            ]
        default:
            // Standard 4-step flow for all third-party devices
            let appName = companionAppName
            let deviceName = displayName
            let syncPath = healthSyncPath ?? "Settings → Apple Health → enable all categories"
            return [
                SetupStep(instruction: "Install \(appName) from the App Store"),
                SetupStep(instruction: "Pair your \(deviceName) device in \(appName)"),
                SetupStep(instruction: "Open \(appName) → \(syncPath)"),
                SetupStep(instruction: "Allow \(appName) to write to Apple Health when prompted")
            ]
        }
    }

    /// Devices that appear in the "Add More Devices" section (excludes generic and iPhone)
    static var discoverableDevices: [SupportedDevice] {
        allCases.filter { $0 != .generic && $0 != .iPhone }
    }
}

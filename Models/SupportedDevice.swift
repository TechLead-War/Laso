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
    case samsungGalaxyWatch
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
    case generic

    var displayName: String {
        switch self {
        case .appleWatch: return "Apple Watch"
        case .iPhone: return "iPhone"
        case .garmin: return "Garmin"
        case .fitbit: return "Fitbit"
        case .ouraRing: return "Oura Ring"
        case .whoop: return "Whoop"
        case .samsungGalaxyWatch: return "Samsung Galaxy Watch"
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
        case .samsungGalaxyWatch: return "Samsung Health"
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
        case .samsungGalaxyWatch: return ["com.sec.samsung", "com.samsung.health"]
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
        case .samsungGalaxyWatch: return URL(string: "https://apps.apple.com/app/samsung-health/id1224498498")
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
        }
    }

    var systemImageName: String {
        switch self {
        case .appleWatch: return "applewatch"
        case .iPhone: return "iphone"
        case .ouraRing: return "circle.circle"
        case .whoop: return "waveform.path.ecg.rectangle"
        case .withings: return "scalemass.fill"
        case .generic: return "sensor.fill"
        default: return "watchface.applewatch.case"
        }
    }

    var iconColor: Color {
        switch self {
        case .appleWatch, .iPhone, .coros: return .blue
        case .garmin: return .cyan
        case .fitbit: return .teal
        case .ouraRing: return .mint
        case .whoop, .xiaomiSmartBand, .fireBoltt: return .orange
        case .samsungGalaxyWatch, .suunto: return .indigo
        case .amazfit, .polar, .noise, .boAt, .huawei: return .red
        case .withings, .googlePixelWatch: return .green
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

    var supportedMetrics: Set<HealthMetric> {
        switch self {
        case .appleWatch:
            return Set(HealthMetric.allCases)
        case .iPhone:
            return [.steps, .distanceWalkingRunning, .flightsClimbed, .exerciseMinutes, .walkingSpeed]
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
        case .fitbit, .samsungGalaxyWatch, .amazfit, .xiaomiSmartBand, .googlePixelWatch:
            return Self.midMetrics
        case .noise, .boAt, .fireBoltt:
            return Self.basicMetrics
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
        case .samsungGalaxyWatch: return "Settings → Connected Services → Apple Health"
        case .amazfit: return "Profile → Add Accounts → Apple Health → enable all"
        case .withings: return "Profile → Health → Apple Health → enable all"
        case .huawei: return "Me → Settings → Data Sharing → Apple Health → enable all"
        case .suunto: return "Settings → Partner Services → Apple Health → enable all"
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

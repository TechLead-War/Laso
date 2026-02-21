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
        case .generic: return "Unknown Device"
        }
    }

    var companionAppName: String {
        switch self {
        case .appleWatch: return "Apple Health"
        case .iPhone: return "Apple Health"
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
        case .generic: return []
        }
    }

    var appStoreURL: URL? {
        switch self {
        case .appleWatch, .iPhone: return nil
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
        case .generic: return nil
        }
    }

    var systemImageName: String {
        switch self {
        case .appleWatch: return "applewatch"
        case .iPhone: return "iphone"
        case .garmin, .fitbit, .samsungGalaxyWatch, .amazfit, .polar, .xiaomiSmartBand, .googlePixelWatch:
            return "watchface.applewatch.case"
        case .ouraRing: return "circle.circle"
        case .whoop: return "waveform.path.ecg.rectangle"
        case .withings: return "scalemass.fill"
        case .generic: return "sensor.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .appleWatch: return .blue
        case .iPhone: return .blue
        case .garmin: return .cyan
        case .fitbit: return .teal
        case .ouraRing: return .mint
        case .whoop: return .orange
        case .samsungGalaxyWatch: return .indigo
        case .amazfit: return .red
        case .withings: return .green
        case .polar: return .red
        case .xiaomiSmartBand: return .orange
        case .googlePixelWatch: return .green
        case .generic: return .secondary
        }
    }

    var supportedMetrics: Set<HealthMetric> {
        switch self {
        case .appleWatch:
            return Set(HealthMetric.allCases)
        case .iPhone:
            return [.steps, .distanceWalkingRunning, .flightsClimbed, .exerciseMinutes, .walkingSpeed]
        case .garmin:
            return [
                .heartRate, .restingHeartRate, .heartRateVariability,
                .sleepDuration, .sleepREM, .sleepDeep, .sleepCore, .sleepAwake,
                .steps, .activeCalories, .exerciseMinutes, .distanceWalkingRunning,
                .vo2Max, .bloodOxygen, .respiratoryRate,
                .workoutCount, .workoutDuration
            ]
        case .fitbit:
            return [
                .heartRate, .restingHeartRate,
                .sleepDuration, .sleepREM, .sleepDeep, .sleepCore, .sleepAwake,
                .steps, .activeCalories, .distanceWalkingRunning,
                .bloodOxygen,
                .workoutCount, .workoutDuration
            ]
        case .ouraRing:
            return [
                .heartRate, .restingHeartRate, .heartRateVariability,
                .sleepDuration, .sleepREM, .sleepDeep, .sleepCore, .sleepAwake,
                .steps, .activeCalories,
                .bloodOxygen, .respiratoryRate, .bodyTemperature
            ]
        case .whoop:
            return [
                .heartRate, .restingHeartRate, .heartRateVariability,
                .sleepDuration, .sleepREM, .sleepDeep, .sleepCore, .sleepAwake,
                .activeCalories, .bloodOxygen, .respiratoryRate,
                .workoutCount, .workoutDuration
            ]
        case .samsungGalaxyWatch:
            return [
                .heartRate, .restingHeartRate,
                .sleepDuration, .sleepREM, .sleepDeep, .sleepCore, .sleepAwake,
                .steps, .activeCalories, .distanceWalkingRunning,
                .bloodOxygen,
                .workoutCount, .workoutDuration
            ]
        case .amazfit:
            return [
                .heartRate, .restingHeartRate,
                .sleepDuration, .sleepREM, .sleepDeep, .sleepCore, .sleepAwake,
                .steps, .activeCalories, .distanceWalkingRunning,
                .bloodOxygen,
                .workoutCount, .workoutDuration
            ]
        case .withings:
            return [
                .heartRate, .restingHeartRate, .heartRateVariability,
                .sleepDuration, .sleepREM, .sleepDeep, .sleepCore, .sleepAwake,
                .steps, .weight, .bmi, .bodyFatPercentage,
                .bloodPressureSystolic, .bloodPressureDiastolic,
                .bloodOxygen,
                .workoutCount, .workoutDuration
            ]
        case .polar:
            return [
                .heartRate, .restingHeartRate, .heartRateVariability,
                .sleepDuration, .sleepREM, .sleepDeep, .sleepCore, .sleepAwake,
                .steps, .activeCalories, .distanceWalkingRunning,
                .vo2Max,
                .workoutCount, .workoutDuration
            ]
        case .xiaomiSmartBand:
            return [
                .heartRate, .restingHeartRate,
                .sleepDuration, .sleepREM, .sleepDeep, .sleepCore, .sleepAwake,
                .steps, .activeCalories, .distanceWalkingRunning,
                .bloodOxygen,
                .workoutCount, .workoutDuration
            ]
        case .googlePixelWatch:
            return [
                .heartRate, .restingHeartRate,
                .sleepDuration, .sleepREM, .sleepDeep, .sleepCore, .sleepAwake,
                .steps, .activeCalories, .distanceWalkingRunning,
                .bloodOxygen,
                .workoutCount, .workoutDuration
            ]
        case .generic:
            return []
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
        case .garmin:
            return [
                SetupStep(instruction: "Install Garmin Connect from the App Store"),
                SetupStep(instruction: "Pair your Garmin device in Garmin Connect"),
                SetupStep(instruction: "Open Garmin Connect → Settings → Health → Apple Health → enable all categories"),
                SetupStep(instruction: "Allow Garmin Connect to write to Apple Health when prompted")
            ]
        case .fitbit:
            return [
                SetupStep(instruction: "Install the Fitbit app from the App Store"),
                SetupStep(instruction: "Pair your Fitbit device in the Fitbit app"),
                SetupStep(instruction: "Open Fitbit → Account → App Settings → enable Apple Health sync"),
                SetupStep(instruction: "Allow Fitbit to write to Apple Health when prompted")
            ]
        case .ouraRing:
            return [
                SetupStep(instruction: "Install the Oura app from the App Store"),
                SetupStep(instruction: "Pair your Oura Ring in the Oura app"),
                SetupStep(instruction: "Open Oura → Settings → Apple Health → enable all categories"),
                SetupStep(instruction: "Allow Oura to write to Apple Health when prompted")
            ]
        case .whoop:
            return [
                SetupStep(instruction: "Install the Whoop app from the App Store"),
                SetupStep(instruction: "Pair your Whoop strap in the Whoop app"),
                SetupStep(instruction: "Open Whoop → Settings → Health App Integration → enable all"),
                SetupStep(instruction: "Allow Whoop to write to Apple Health when prompted")
            ]
        case .samsungGalaxyWatch:
            return [
                SetupStep(instruction: "Install Samsung Health from the App Store"),
                SetupStep(instruction: "Pair your Galaxy Watch in the Samsung Health app"),
                SetupStep(instruction: "Open Samsung Health → Settings → Connected Services → Apple Health"),
                SetupStep(instruction: "Enable all data categories and allow writing to Apple Health")
            ]
        case .amazfit:
            return [
                SetupStep(instruction: "Install the Zepp app (formerly Amazfit) from the App Store"),
                SetupStep(instruction: "Pair your Amazfit device in the Zepp app"),
                SetupStep(instruction: "Open Zepp → Profile → Add Accounts → Apple Health → enable all"),
                SetupStep(instruction: "Allow Zepp to write to Apple Health when prompted")
            ]
        case .withings:
            return [
                SetupStep(instruction: "Install Withings Health Mate from the App Store"),
                SetupStep(instruction: "Pair your Withings device in Health Mate"),
                SetupStep(instruction: "Open Health Mate → Profile → Health → Apple Health → enable all"),
                SetupStep(instruction: "Allow Health Mate to write to Apple Health when prompted")
            ]
        case .polar:
            return [
                SetupStep(instruction: "Install Polar Flow from the App Store"),
                SetupStep(instruction: "Pair your Polar device in Polar Flow"),
                SetupStep(instruction: "Open Polar Flow → Settings → Apple Health → enable all categories"),
                SetupStep(instruction: "Allow Polar Flow to write to Apple Health when prompted")
            ]
        case .xiaomiSmartBand:
            return [
                SetupStep(instruction: "Install Mi Fitness from the App Store"),
                SetupStep(instruction: "Pair your Xiaomi Smart Band in Mi Fitness"),
                SetupStep(instruction: "Open Mi Fitness → Profile → Settings → Apple Health → enable all"),
                SetupStep(instruction: "Allow Mi Fitness to write to Apple Health when prompted")
            ]
        case .googlePixelWatch:
            return [
                SetupStep(instruction: "Install Google Fit from the App Store"),
                SetupStep(instruction: "Sign in to Google Fit with your Google account"),
                SetupStep(instruction: "Open Google Fit → Profile → Settings → Apple Health → enable all"),
                SetupStep(instruction: "Allow Google Fit to write to Apple Health when prompted")
            ]
        case .generic:
            return [
                SetupStep(instruction: "Install your device's companion app from the App Store"),
                SetupStep(instruction: "Pair your device in the companion app"),
                SetupStep(instruction: "Enable Apple Health sync in the companion app's settings"),
                SetupStep(instruction: "Allow the app to write to Apple Health when prompted")
            ]
        }
    }

    /// Devices that appear in the "Add More Devices" section (excludes generic and iPhone)
    static var discoverableDevices: [SupportedDevice] {
        allCases.filter { $0 != .generic && $0 != .iPhone }
    }
}

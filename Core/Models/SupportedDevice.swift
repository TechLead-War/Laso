import Foundation
import SwiftUI

/// A setup step for configuring a wearable's companion app to sync with HealthKit
struct SetupStep: Identifiable {
    let id = UUID()
    let instruction: String
}

/// Static metadata for a supported wearable device
struct SupportedDeviceInfo {
    let displayName: String
    let companionAppName: String
    let bundlePrefixes: [String]
    let appStoreURL: URL?
    let isPublicCatalogSource: Bool
    let syncSummary: String?
    let systemImageName: String?
    let iconColor: Color?
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

    // MARK: - Metadata Lookup

    private static let deviceInfo: [SupportedDevice: SupportedDeviceInfo] = [
        .appleWatch: SupportedDeviceInfo(displayName: "Apple Watch", companionAppName: "Apple Health", bundlePrefixes: ["com.apple.health", "com.apple.watch"], appStoreURL: nil, isPublicCatalogSource: true, syncSummary: "Syncs directly through Apple Health", systemImageName: "applewatch", iconColor: .blue),
        .iPhone: SupportedDeviceInfo(displayName: "iPhone", companionAppName: "Apple Health", bundlePrefixes: ["com.apple.Health", "com.apple.health"], appStoreURL: nil, isPublicCatalogSource: false, syncSummary: "Built-in sensors feed Apple Health", systemImageName: "iphone", iconColor: .blue),
        .garmin: SupportedDeviceInfo(displayName: "Garmin", companionAppName: "Garmin Connect", bundlePrefixes: ["com.garmin"], appStoreURL: URL(string: "https://apps.apple.com/app/garmin-connect/id583446403"), isPublicCatalogSource: true, syncSummary: nil, systemImageName: nil, iconColor: .cyan),
        .fitbit: SupportedDeviceInfo(displayName: "Fitbit", companionAppName: "Fitbit", bundlePrefixes: ["com.fitbit"], appStoreURL: URL(string: "https://apps.apple.com/app/fitbit-health-fitness/id462638897"), isPublicCatalogSource: true, syncSummary: "Syncs to Apple Health through a bridge app", systemImageName: nil, iconColor: .teal),
        .ouraRing: SupportedDeviceInfo(displayName: "Oura Ring", companionAppName: "Oura", bundlePrefixes: ["com.ouraring"], appStoreURL: URL(string: "https://apps.apple.com/app/oura-ring/id1043837948"), isPublicCatalogSource: true, syncSummary: nil, systemImageName: "circle.circle", iconColor: .mint),
        .whoop: SupportedDeviceInfo(displayName: "Whoop", companionAppName: "Whoop", bundlePrefixes: ["com.whoop"], appStoreURL: URL(string: "https://apps.apple.com/app/whoop/id933944389"), isPublicCatalogSource: true, syncSummary: nil, systemImageName: "waveform.path.ecg.rectangle", iconColor: .orange),
        .samsungGalaxy: SupportedDeviceInfo(displayName: "Samsung Galaxy", companionAppName: "Samsung Health", bundlePrefixes: ["com.sec.samsung", "com.samsung.health"], appStoreURL: URL(string: "https://apps.apple.com/app/samsung-health/id1224498498"), isPublicCatalogSource: false, syncSummary: nil, systemImageName: nil, iconColor: .indigo),
        .amazfit: SupportedDeviceInfo(displayName: "Amazfit", companionAppName: "Zepp", bundlePrefixes: ["com.huami", "com.amazfit"], appStoreURL: URL(string: "https://apps.apple.com/app/zepp-formerly-amazfit/id1127269366"), isPublicCatalogSource: true, syncSummary: nil, systemImageName: nil, iconColor: .red),
        .withings: SupportedDeviceInfo(displayName: "Withings", companionAppName: "Withings Health Mate", bundlePrefixes: ["com.withings"], appStoreURL: URL(string: "https://apps.apple.com/app/withings-health-mate/id542701020"), isPublicCatalogSource: true, syncSummary: nil, systemImageName: "scalemass.fill", iconColor: .green),
        .polar: SupportedDeviceInfo(displayName: "Polar", companionAppName: "Polar Flow", bundlePrefixes: ["com.polar"], appStoreURL: URL(string: "https://apps.apple.com/app/polar-flow/id717172678"), isPublicCatalogSource: true, syncSummary: nil, systemImageName: nil, iconColor: .red),
        .xiaomiSmartBand: SupportedDeviceInfo(displayName: "Xiaomi Smart Band", companionAppName: "Mi Fitness", bundlePrefixes: ["com.xiaomi", "com.mi."], appStoreURL: URL(string: "https://apps.apple.com/app/mi-fitness/id1502091498"), isPublicCatalogSource: true, syncSummary: nil, systemImageName: nil, iconColor: .orange),
        .googlePixelWatch: SupportedDeviceInfo(displayName: "Google Pixel Watch", companionAppName: "Fitbit", bundlePrefixes: ["com.google.ios.fit", "com.google.Fit"], appStoreURL: URL(string: "https://apps.apple.com/app/fitbit-health-fitness/id462638897"), isPublicCatalogSource: false, syncSummary: nil, systemImageName: nil, iconColor: .green),
        .noise: SupportedDeviceInfo(displayName: "Noise", companionAppName: "NoiseFit", bundlePrefixes: ["com.noisefit"], appStoreURL: URL(string: "https://apps.apple.com/app/noisefit-health-fitness/id1498457147"), isPublicCatalogSource: true, syncSummary: nil, systemImageName: nil, iconColor: .red),
        .boAt: SupportedDeviceInfo(displayName: "boAt", companionAppName: "boAt Wearables", bundlePrefixes: ["com.boat", "com.imaginmarketing"], appStoreURL: URL(string: "https://apps.apple.com/app/boat-wearables/id1542443145"), isPublicCatalogSource: true, syncSummary: nil, systemImageName: nil, iconColor: .red),
        .fireBoltt: SupportedDeviceInfo(displayName: "Fire-Boltt", companionAppName: "FireBoltt", bundlePrefixes: ["com.fireboltt"], appStoreURL: URL(string: "https://apps.apple.com/app/fireboltt-pro/id6480042961"), isPublicCatalogSource: true, syncSummary: nil, systemImageName: nil, iconColor: .orange),
        .huawei: SupportedDeviceInfo(displayName: "Huawei Watch", companionAppName: "Huawei Health", bundlePrefixes: ["com.huawei.health"], appStoreURL: URL(string: "https://apps.apple.com/app/huawei-health/id1174646498"), isPublicCatalogSource: true, syncSummary: nil, systemImageName: nil, iconColor: .red),
        .coros: SupportedDeviceInfo(displayName: "COROS", companionAppName: "COROS", bundlePrefixes: ["com.coros"], appStoreURL: URL(string: "https://apps.apple.com/app/coros/id1169521325"), isPublicCatalogSource: true, syncSummary: nil, systemImageName: nil, iconColor: .blue),
        .suunto: SupportedDeviceInfo(displayName: "Suunto", companionAppName: "Suunto", bundlePrefixes: ["com.suunto"], appStoreURL: URL(string: "https://apps.apple.com/app/suunto/id1230327951"), isPublicCatalogSource: true, syncSummary: nil, systemImageName: nil, iconColor: .indigo),
        .wahoo: SupportedDeviceInfo(displayName: "Wahoo", companionAppName: "Wahoo Fitness", bundlePrefixes: ["com.wahoofitness"], appStoreURL: URL(string: "https://apps.apple.com/app/wahoo-fitness/id391599899"), isPublicCatalogSource: true, syncSummary: nil, systemImageName: "figure.indoor.cycle", iconColor: .blue),
        .ticWatch: SupportedDeviceInfo(displayName: "TicWatch", companionAppName: "Mobvoi", bundlePrefixes: ["com.mobvoi"], appStoreURL: URL(string: "https://apps.apple.com/app/mobvoi/id1454523498"), isPublicCatalogSource: false, syncSummary: nil, systemImageName: nil, iconColor: .purple),
        .casioGShock: SupportedDeviceInfo(displayName: "Casio G-Shock", companionAppName: "G-SHOCK MOVE", bundlePrefixes: ["jp.co.casio"], appStoreURL: URL(string: "https://apps.apple.com/app/g-shock-move/id1472764049"), isPublicCatalogSource: false, syncSummary: nil, systemImageName: nil, iconColor: .yellow),
        .tagHeuer: SupportedDeviceInfo(displayName: "TAG Heuer", companionAppName: "TAG Heuer Connected", bundlePrefixes: ["com.tagheuer"], appStoreURL: URL(string: "https://apps.apple.com/app/tag-heuer-connected/id1456817498"), isPublicCatalogSource: false, syncSummary: nil, systemImageName: nil, iconColor: .indigo),
        .fossil: SupportedDeviceInfo(displayName: "Fossil", companionAppName: "Fossil Smartwatches", bundlePrefixes: ["com.fossil"], appStoreURL: URL(string: "https://apps.apple.com/app/fossil-smartwatches/id1027498498"), isPublicCatalogSource: false, syncSummary: nil, systemImageName: nil, iconColor: .purple),
        .ultrahumanRing: SupportedDeviceInfo(displayName: "Ultrahuman Ring Air", companionAppName: "Ultrahuman", bundlePrefixes: ["com.ultrahuman"], appStoreURL: URL(string: "https://apps.apple.com/app/ultrahuman/id1547498498"), isPublicCatalogSource: true, syncSummary: nil, systemImageName: "circle.circle", iconColor: .mint),
        .ringConn: SupportedDeviceInfo(displayName: "RingConn", companionAppName: "RingConn", bundlePrefixes: ["com.ringconn"], appStoreURL: URL(string: "https://apps.apple.com/app/ringconn/id6443824498"), isPublicCatalogSource: true, syncSummary: nil, systemImageName: "circle.circle", iconColor: .pink),
        .circularRing: SupportedDeviceInfo(displayName: "Circular Ring", companionAppName: "Circular", bundlePrefixes: ["com.circular"], appStoreURL: URL(string: "https://apps.apple.com/app/circular/id1571234498"), isPublicCatalogSource: true, syncSummary: nil, systemImageName: "circle.circle", iconColor: .mint),
        .omron: SupportedDeviceInfo(displayName: "Omron", companionAppName: "OMRON connect", bundlePrefixes: ["jp.co.omron.healthcare"], appStoreURL: URL(string: "https://apps.apple.com/app/omron-connect/id1003177498"), isPublicCatalogSource: true, syncSummary: nil, systemImageName: "waveform.path.ecg", iconColor: .teal),
        .renpho: SupportedDeviceInfo(displayName: "Renpho", companionAppName: "Renpho", bundlePrefixes: ["com.renpho"], appStoreURL: URL(string: "https://apps.apple.com/app/renpho/id1219889498"), isPublicCatalogSource: true, syncSummary: nil, systemImageName: "scalemass.fill", iconColor: .teal),
        .dexcom: SupportedDeviceInfo(displayName: "Dexcom", companionAppName: "Dexcom", bundlePrefixes: ["com.dexcom"], appStoreURL: URL(string: "https://apps.apple.com/app/dexcom-g7/id1431476498"), isPublicCatalogSource: true, syncSummary: nil, systemImageName: "drop.fill", iconColor: .green),
        .freestyleLibre: SupportedDeviceInfo(displayName: "Freestyle Libre", companionAppName: "LibreLink", bundlePrefixes: ["com.abbott.librelink"], appStoreURL: URL(string: "https://apps.apple.com/app/librelink/id1307476498"), isPublicCatalogSource: false, syncSummary: nil, systemImageName: "drop.fill", iconColor: .green),
        .eightSleep: SupportedDeviceInfo(displayName: "Eight Sleep", companionAppName: "Eight Sleep", bundlePrefixes: ["com.eightsleep"], appStoreURL: URL(string: "https://apps.apple.com/app/eight-sleep/id1127389498"), isPublicCatalogSource: true, syncSummary: nil, systemImageName: "bed.double.fill", iconColor: .cyan),
        .biostrap: SupportedDeviceInfo(displayName: "Biostrap", companionAppName: "Biostrap", bundlePrefixes: ["com.biostrap"], appStoreURL: URL(string: "https://apps.apple.com/app/biostrap/id1187459498"), isPublicCatalogSource: true, syncSummary: nil, systemImageName: nil, iconColor: .purple),
        .myzone: SupportedDeviceInfo(displayName: "Myzone", companionAppName: "Myzone", bundlePrefixes: ["com.myzone"], appStoreURL: URL(string: "https://apps.apple.com/app/myzone/id874028498"), isPublicCatalogSource: true, syncSummary: nil, systemImageName: "heart.fill", iconColor: .orange),
        .peloton: SupportedDeviceInfo(displayName: "Peloton", companionAppName: "Peloton", bundlePrefixes: ["com.onepeloton"], appStoreURL: URL(string: "https://apps.apple.com/app/peloton/id792750948"), isPublicCatalogSource: true, syncSummary: nil, systemImageName: "figure.indoor.cycle", iconColor: .red),
        .generic: SupportedDeviceInfo(displayName: "Unknown Device", companionAppName: "Companion App", bundlePrefixes: [], appStoreURL: nil, isPublicCatalogSource: false, syncSummary: nil, systemImageName: "sensor.fill", iconColor: .secondary),
    ]

    private var info: SupportedDeviceInfo {
        Self.deviceInfo[self] ?? SupportedDeviceInfo(displayName: rawValue, companionAppName: "Companion App", bundlePrefixes: [], appStoreURL: nil, isPublicCatalogSource: false, syncSummary: nil, systemImageName: nil, iconColor: nil)
    }

    var displayName: String { info.displayName }

    var companionAppName: String { info.companionAppName }

    var companionAppBundlePrefixes: [String] { info.bundlePrefixes }

    var appStoreURL: URL? { info.appStoreURL }

    var isPublicCatalogSource: Bool { info.isPublicCatalogSource }

    var syncSummary: String {
        info.syncSummary ?? "\(companionAppName) writes into Apple Health"
    }

    var systemImageName: String {
        info.systemImageName ?? "watchface.applewatch.case"
    }

    var iconColor: Color {
        info.iconColor ?? .secondary
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
        case .fitbit:
            return [
                SetupStep(instruction: "Install Fitbit from the App Store and pair your device"),
                SetupStep(instruction: "Install a bridge app such as Sync Solver for Fitbit from the App Store"),
                SetupStep(instruction: "Open the bridge app and sign in with your Fitbit account"),
                SetupStep(instruction: "Enable Apple Health sync inside the bridge app"),
                SetupStep(instruction: "Allow the bridge app to write to Apple Health when prompted")
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
        allCases.filter(\.isPublicCatalogSource)
    }
}

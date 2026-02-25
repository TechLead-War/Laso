import SwiftUI

/// Main entry point for the Laso app
@main
struct HealthPulseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @AppStorage("healthpulse.onboardingCompleted") private var onboardingCompleted = false
    @AppStorage("healthpulse.appTheme") private var appTheme: String = "system"

    @State private var healthKitManager: HealthKitManager
    @State private var analysisEngine = AnalysisEngine()
    @State private var deviceSourceManager: DeviceSourceManager

    private var colorScheme: ColorScheme? {
        switch appTheme {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }

    init() {
        let hkManager = HealthKitManager()
        _healthKitManager = State(wrappedValue: hkManager)
        _deviceSourceManager = State(wrappedValue: DeviceSourceManager(healthStore: hkManager.healthStore))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                healthKitManager: healthKitManager,
                analysisEngine: analysisEngine,
                deviceSourceManager: deviceSourceManager
            )
            .preferredColorScheme(colorScheme)
            .fullScreenCover(isPresented: Binding(
                get: { !onboardingCompleted },
                set: { if !$0 { onboardingCompleted = true } }
            )) {
                OnboardingView(healthKitManager: healthKitManager) {
                    onboardingCompleted = true
                    // Sync onboarding flag to iCloud for other devices
                    NSUbiquitousKeyValueStore.default.set(true, forKey: "healthpulse.onboardingCompleted")
                }
            }
        }
    }
}

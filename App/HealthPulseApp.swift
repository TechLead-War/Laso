import SwiftUI

/// Main entry point for the Laso app
@main
struct HealthPulseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var healthKitManager = HealthKitManager()
    @State private var analysisEngine = AnalysisEngine()
    @State private var featureGate = FeatureGate()
    @State private var subscriptionManager = SubscriptionManager()

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(
                healthKitManager: healthKitManager,
                analysisEngine: analysisEngine,
                featureGate: featureGate,
                subscriptionManager: subscriptionManager
            )
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    AnalyticsManager.shared.startSession()

                    // Set Firebase user properties
                    FirebaseAnalyticsService.shared.setUserProperties()

                    // Re-fetch remote config on foreground
                    Task { await RemoteConfigManager.shared.fetchAndActivate() }
                case .background:
                    AnalyticsManager.shared.endSession()
                default:
                    break
                }
            }
        }
    }
}

import SwiftUI
import HealthKit

// MARK: - HealthFocus

enum HealthFocus: String, Codable, Identifiable, Hashable, CaseIterable {
    case sleep
    case fitness
    case heartHealth
    case weightBody
    case recovery

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sleep: "Sleep"
        case .fitness: "Fitness"
        case .heartHealth: "Heart Health"
        case .weightBody: "Weight & Body"
        case .recovery: "Recovery"
        }
    }

    var systemImageName: String {
        switch self {
        case .sleep: "bed.double.fill"
        case .fitness: "figure.run"
        case .heartHealth: "heart.fill"
        case .weightBody: "scalemass.fill"
        case .recovery: "bolt.heart.fill"
        }
    }

    var color: Color {
        switch self {
        case .sleep: .indigo
        case .fitness: .green
        case .heartHealth: .red
        case .weightBody: .orange
        case .recovery: .purple
        }
    }

    /// Maps this focus to one or more HealthCategory values for insight filtering
    var healthCategories: Set<HealthCategory> {
        switch self {
        case .sleep: [.sleep]
        case .fitness: [.activity]
        case .heartHealth: [.heart]
        case .weightBody: [.body]
        case .recovery: [.heart, .respiratory]
        }
    }

    /// All HealthCategory values covered by a set of focuses
    static func categories(for focuses: Set<HealthFocus>) -> Set<HealthCategory> {
        var result = Set<HealthCategory>()
        for focus in focuses {
            result.formUnion(focus.healthCategories)
        }
        return result
    }
}

// MARK: - OnboardingView

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var selectedFocuses: Set<HealthFocus> = []

    let healthKitManager: HealthKitManager
    let onComplete: () -> Void

    private let totalPages = 6

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentPage) {
                WelcomePage { currentPage = 1 }
                    .tag(0)

                FeatureHighlightsPage { currentPage = 2 }
                    .tag(1)

                HealthFocusPage(selectedFocuses: $selectedFocuses) { currentPage = 3 }
                    .tag(2)

                HealthKitPermissionPage(healthKitManager: healthKitManager) { currentPage = 4 }
                    .tag(3)

                NotificationsPage { currentPage = 5 }
                    .tag(4)

                AllSetPage { finishOnboarding() }
                    .tag(5)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Progress dots
            HStack(spacing: 6) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Circle()
                        .fill(index <= currentPage ? Color.accentColor : Color.secondary.opacity(0.2))
                        .frame(
                            width: index == currentPage ? 8 : 6,
                            height: index == currentPage ? 8 : 6
                        )
                        .animation(.spring(response: 0.4), value: currentPage)
                }
            }
            .padding(.bottom, 16)
        }
        .background(Color(.systemGroupedBackground))
        .interactiveDismissDisabled()
        .sensoryFeedback(.selection, trigger: currentPage)
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.onboarding)
        }
        .onChange(of: currentPage) { _, newPage in
            AppAnalytics.shared.trackAction("onboarding_page_viewed", metadata: ["page": newPage])
        }
    }

    private func finishOnboarding() {
        let focuses = selectedFocuses.isEmpty ? Set(HealthFocus.allCases) : selectedFocuses
        PersistenceManager().saveHealthFocuses(focuses)
        AppAnalytics.shared.trackFeatureClose(.onboarding, metadata: [
            "focuses_selected": focuses.map(\.rawValue).joined(separator: ","),
            "focuses_count": focuses.count
        ])
        onComplete()
    }
}

// MARK: - Page 0: Welcome

private struct WelcomePage: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            GlowIcon(systemName: "heart.text.clipboard", color: .accentColor)

            VStack(spacing: 12) {
                Text("Your health, understood.")
                    .font(.title3.weight(.semibold))

                Text("HealthPulse turns your Apple Watch data into actionable health insights — all on your device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()

            Button("Get Started") { onContinue() }
                .buttonStyle(.borderedProminent)
                .font(.subheadline.weight(.medium))
                .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Page 1: Feature Highlights

private struct FeatureHighlightsPage: View {
    let onContinue: () -> Void

    private let features: [(icon: String, title: String, subtitle: String)] = [
        ("chart.bar.xaxis", "Health Score", "One number for your overall health"),
        ("waveform.path.ecg", "Live Vitals", "Real-time heart rate and recovery"),
        ("sparkles", "Smart Insights", "Personalized trends and anomaly alerts"),
        ("shield.lefthalf.filled", "Risk Assessment", "Early warnings for health issues"),
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("What you'll get")
                .font(.title3.weight(.semibold))

            VStack(spacing: 0) {
                ForEach(features, id: \.title) { feature in
                    HStack(spacing: 14) {
                        Image(systemName: feature.icon)
                            .font(.system(size: 20))
                            .foregroundStyle(.tint)
                            .frame(width: 36, height: 36)
                            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(feature.title)
                                .font(.subheadline.weight(.medium))
                            Text(feature.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if feature.title != features.last?.title {
                        Divider().padding(.leading, 66)
                    }
                }
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            Spacer()

            Button("Continue") { onContinue() }
                .buttonStyle(.borderedProminent)
                .font(.subheadline.weight(.medium))
                .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Page 2: Health Focus

private struct HealthFocusPage: View {
    @Binding var selectedFocuses: Set<HealthFocus>
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Text("What matters most to you?")
                    .font(.title3.weight(.semibold))

                Text("We'll prioritize insights for these areas.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Multi-select pills
            FlowLayout(spacing: 10) {
                ForEach(HealthFocus.allCases) { focus in
                    let isSelected = selectedFocuses.contains(focus)
                    Button {
                        if isSelected {
                            selectedFocuses.remove(focus)
                        } else {
                            selectedFocuses.insert(focus)
                        }
                    } label: {
                        Label(focus.displayName, systemImage: focus.systemImageName)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                isSelected ? focus.color.opacity(0.15) : Color.secondary.opacity(0.08),
                                in: Capsule()
                            )
                            .foregroundStyle(isSelected ? focus.color : .secondary)
                            .overlay(
                                Capsule()
                                    .strokeBorder(isSelected ? focus.color.opacity(0.4) : .clear, lineWidth: 1.5)
                            )
                    }
                    .sensoryFeedback(.selection, trigger: isSelected)
                }
            }
            .padding(.horizontal)

            Spacer()

            Button("Continue") { onContinue() }
                .buttonStyle(.borderedProminent)
                .font(.subheadline.weight(.medium))
                .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Page 3: HealthKit Permission

private struct HealthKitPermissionPage: View {
    let healthKitManager: HealthKitManager
    let onContinue: () -> Void

    private let benefits: [(icon: String, text: String)] = [
        ("checkmark.circle.fill", "See trends in sleep, heart rate, and activity"),
        ("checkmark.circle.fill", "Get personalized health insights"),
        ("checkmark.circle.fill", "Track your recovery and readiness"),
        ("lock.fill", "100% on-device — your data never leaves"),
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            GlowIcon(systemName: "heart.text.clipboard", color: .red)

            VStack(spacing: 12) {
                Text("Connect Apple Health")
                    .font(.title3.weight(.semibold))

                Text("We read your health data to generate insights. Nothing is uploaded — everything stays on your device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 0) {
                ForEach(benefits, id: \.text) { benefit in
                    HStack(spacing: 12) {
                        Image(systemName: benefit.icon)
                            .font(.system(size: 16))
                            .foregroundStyle(benefit.icon == "lock.fill" ? .orange : .green)
                            .frame(width: 24)

                        Text(benefit.text)
                            .font(.subheadline)
                            .foregroundStyle(.primary)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    if benefit.text != benefits.last?.text {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            Spacer()

            if HKHealthStore.isHealthDataAvailable() {
                Button("Connect Apple Health") {
                    Task {
                        await healthKitManager.requestAuthorization()
                        onContinue()
                    }
                }
                .buttonStyle(.borderedProminent)
                .font(.subheadline.weight(.medium))
                .padding(.bottom, 48)
            } else {
                VStack(spacing: 12) {
                    Text("HealthKit is not available on this device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Continue Anyway") { onContinue() }
                        .buttonStyle(.borderedProminent)
                        .font(.subheadline.weight(.medium))
                }
                .padding(.bottom, 48)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Page 4: Notifications

private struct NotificationsPage: View {
    let onContinue: () -> Void

    private let notificationTypes: [(icon: String, text: String)] = [
        ("sun.max.fill", "Daily health summary every morning"),
        ("exclamationmark.triangle.fill", "Alerts when metrics need attention"),
        ("trophy.fill", "Celebrations when you hit milestones"),
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            GlowIcon(systemName: "bell.badge.fill", color: .blue)

            VStack(spacing: 12) {
                Text("Stay in the Loop")
                    .font(.title3.weight(.semibold))

                Text("Choose what to be notified about.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 0) {
                ForEach(notificationTypes, id: \.text) { type in
                    HStack(spacing: 12) {
                        Image(systemName: type.icon)
                            .font(.system(size: 16))
                            .foregroundStyle(.tint)
                            .frame(width: 24)

                        Text(type.text)
                            .font(.subheadline)
                            .foregroundStyle(.primary)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    if type.text != notificationTypes.last?.text {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            Spacer()

            VStack(spacing: 12) {
                Button("Enable Notifications") {
                    Task {
                        await NotificationManager.shared.requestAuthorization()
                        onContinue()
                    }
                }
                .buttonStyle(.borderedProminent)
                .font(.subheadline.weight(.medium))

                Button("Not Now") { onContinue() }
                    .buttonStyle(.bordered)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Page 5: All Set

private struct AllSetPage: View {
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            GlowIcon(systemName: "checkmark.circle.fill", color: .green)

            VStack(spacing: 12) {
                Text("You're All Set!")
                    .font(.title3.weight(.semibold))

                Text("HealthPulse is ready to analyze your health data.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()

            Button("Let's Go") { onComplete() }
                .buttonStyle(.borderedProminent)
                .font(.subheadline.weight(.medium))
                .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Glow Icon Component

private struct GlowIcon: View {
    let systemName: String
    let color: Color

    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.1))
                .frame(width: 120, height: 120)
                .scaleEffect(animate ? 1.3 : 0.9)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: animate)

            Circle()
                .fill(color.opacity(0.05))
                .frame(width: 160, height: 160)
                .scaleEffect(animate ? 1.5 : 1.0)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animate)

            Image(systemName: systemName)
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 80, height: 80)
                .background(color.opacity(0.12), in: Circle())
        }
        .onAppear { animate = true }
    }
}


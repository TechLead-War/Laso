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

    private let totalPages = 2

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentPage) {
                ConnectHealthPage(healthKitManager: healthKitManager) {
                    currentPage = 1
                }
                .tag(0)

                FocusPage(selectedFocuses: $selectedFocuses) {
                    finishOnboarding()
                }
                .tag(1)
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

// MARK: - Page 0: Connect Health

private struct ConnectHealthPage: View {
    let healthKitManager: HealthKitManager
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            GlowIcon(systemName: "heart.text.clipboard", color: .red)

            VStack(spacing: 12) {
                Text("Your health, understood.")
                    .font(.title3.weight(.semibold))

                Text("Laso turns your Apple Watch data into clear health scores and insights — privately, on your device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 0) {
                benefitRow(icon: "waveform.path.ecg", color: .red, text: "Scores, trends, and live vitals")
                Divider().padding(.leading, 52)
                benefitRow(icon: "sparkles", color: .blue, text: "Personalized insights and alerts")
                Divider().padding(.leading, 52)
                benefitRow(icon: "lock.fill", color: .orange, text: "100% on-device — nothing uploaded")
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

    private func benefitRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Page 1: Focus + Finish

private struct FocusPage: View {
    @Binding var selectedFocuses: Set<HealthFocus>
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Text("What matters most to you?")
                    .font(.title3.weight(.semibold))

                Text("Pick your areas — we'll prioritize those insights.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

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

            Button("Get Started") { onComplete() }
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

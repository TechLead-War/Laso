import SwiftUI

// MARK: - Morning Check-In View

/// Compact 3-question morning check-in for subjective recovery data.
/// Based on HRV research (Sensors MDPI 2025): combining physiological signals
/// (HRV, RHR) with subjective well-being scores significantly improves
/// readiness prediction accuracy over either alone.
///
/// Questions: Sleep Quality, Energy Level, Muscle Soreness
/// Each on 1-5 scale. Total time: < 10 seconds.
struct MorningCheckInView: View {
    let onComplete: (MorningCheckIn) -> Void
    let onDismiss: () -> Void

    @State private var sleepQuality: Int = 0
    @State private var energyLevel: Int = 0
    @State private var soreness: Int = 0
    @State private var isSubmitting = false

    private var isComplete: Bool {
        sleepQuality > 0 && energyLevel > 0 && soreness > 0
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Copy.Home.MorningCheckIn.greeting)
                        .font(.system(size: 18).weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(Copy.Home.MorningCheckIn.subtitle)
                        .font(.system(size: 13.2))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    AppAnalytics.shared.trackBlockTap(title: "Morning Check-In Dismissed", type: .smartAction, screen: .home, metadata: ["source": "morning_checkin", "completed": false])
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14.4).weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 24, height: 24)
                }
            }

            // Questions
            VStack(spacing: 12) {
                checkInRow(
                    icon: "moon.fill",
                    label: "Sleep quality",
                    emojis: ["😫", "😕", "😐", "😊", "😴"],
                    selection: $sleepQuality
                )

                checkInRow(
                    icon: "bolt.fill",
                    label: "Energy level",
                    emojis: ["🪫", "😮‍💨", "😐", "💪", "⚡"],
                    selection: $energyLevel
                )

                checkInRow(
                    icon: "figure.walk",
                    label: "Body soreness",
                    emojis: ["😵", "😣", "😐", "👌", "🤸"],
                    selection: $soreness
                )
            }

            // Submit
            if isComplete {
                Button {
                    submit()
                } label: {
                    HStack(spacing: 6) {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                                .controlSize(.small)
                        }
                        Text("Done")
                            .font(.system(size: 18).weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.tint, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.white)
                }
                .disabled(isSubmitting)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(DS.space4)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
        .padding(.horizontal, DS.screenPadding)
        .animation(.snappy(duration: 0.25), value: isComplete)
        .accessibilityIdentifier("home.morningCheckInCard")
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.home, metadata: ["subscreen": "morning_checkin"])
        }
    }

    // MARK: - Row Builder

    private func checkInRow(
        icon: String,
        label: String,
        emojis: [String],
        selection: Binding<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13.2))
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.system(size: 14.4).weight(.medium))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 0) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        withAnimation(.snappy(duration: 0.15)) {
                            selection.wrappedValue = value
                        }
                    } label: {
                        Text(emojis[value - 1])
                            .font(.system(size: 24))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                selection.wrappedValue == value
                                    ? Color.accentColor.opacity(0.15)
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(
                                        selection.wrappedValue == value
                                            ? Color.accentColor.opacity(0.3)
                                            : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: selection.wrappedValue)
                }
            }
        }
    }

    // MARK: - Submit

    private func submit() {
        isSubmitting = true
        let checkIn = MorningCheckIn(
            date: Date(),
            sleepQuality: sleepQuality,
            energyLevel: energyLevel,
            soreness: soreness
        )
        AppAnalytics.shared.trackCoreAction(.completedMorningCheckIn, screen: .home)
        AppAnalytics.shared.trackBlockTap(title: "Morning Check-In Submitted", type: .smartAction, screen: .home, metadata: ["source": "morning_checkin", "sleep_quality": sleepQuality, "energy_level": energyLevel, "soreness": soreness])
        onComplete(checkIn)
    }
}

// MARK: - Morning Check-In Model

struct MorningCheckIn: Codable {
    let date: Date
    /// 1 (terrible) to 5 (great)
    let sleepQuality: Int
    /// 1 (exhausted) to 5 (energized)
    let energyLevel: Int
    /// 1 (very sore) to 5 (no soreness)
    let soreness: Int

    /// Composite subjective score (0-1) for ML feature integration
    var compositeScore: Double {
        Double(sleepQuality + energyLevel + soreness) / 15.0
    }

    /// Individual normalized scores for feature vector
    var normalizedSleepQuality: Double { Double(sleepQuality - 1) / 4.0 }
    var normalizedEnergy: Double { Double(energyLevel - 1) / 4.0 }
    var normalizedSoreness: Double { Double(soreness - 1) / 4.0 }

    /// Readiness adjustment factor: shifts readiness score based on subjective feel
    /// Returns -10 to +10 adjustment
    var readinessAdjustment: Int {
        let raw = compositeScore
        if raw >= 0.8 { return Int((raw - 0.6) * 25) }   // up to +10
        if raw <= 0.33 { return Int((raw - 0.5) * 25) }   // down to -10
        return 0
    }
}

#Preview {
    VStack {
        Spacer()
        MorningCheckInView(
            onComplete: { checkIn in
                print("Check-in: sleep=\(checkIn.sleepQuality) energy=\(checkIn.energyLevel) soreness=\(checkIn.soreness)")
            },
            onDismiss: { print("Dismissed") }
        )
        Spacer()
    }
    .background(Color(uiColor: .systemGroupedBackground))
}

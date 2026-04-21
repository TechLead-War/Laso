import SwiftUI

/// Compact card for the Home tab showing the current menstrual cycle phase.
/// Only displayed for female users who have cycle tracking data.
/// Matches the accent-bar card style used by StrainCard, SleepCard, VitalityCard.
struct CyclePhaseCard: View {
    let phaseName: String
    let phaseIcon: String
    let phaseColor: Color
    let dayInCycle: Int
    let cycleLength: Int
    let daysUntilPeriod: Int
    let onTap: () -> Void

    @State private var animatedProgress: Double = 0

    private var cycleProgress: Double {
        guard cycleLength > 0 else { return 0 }
        return min(Double(dayInCycle) / Double(cycleLength), 1.0)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Left accent bar
                RoundedRectangle(cornerRadius: DS.accentRadius)
                    .fill(phaseColor)
                    .frame(width: 4)
                    .padding(.vertical, 6)

                VStack(spacing: 10) {
                    // Main row: icon + text + chevron
                    HStack(spacing: 12) {
                        // Phase icon
                        Image(systemName: phaseIcon)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: DS.iconSize, height: DS.iconSize)
                            .background(phaseColor, in: Circle())

                        // Center text
                        VStack(alignment: .leading, spacing: 4) {
                            Text(phaseName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)

                            HStack(spacing: 8) {
                                Text("Day \(dayInCycle) of \(cycleLength)")
                                    .font(.caption.weight(.medium).monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .postHogMask()

                                periodCountdownBadge
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }

                    // Cycle progress bar
                    cycleProgressBar
                }
                .padding(.leading, DS.accentLeading)
                .padding(.trailing, DS.accentTrailing)
                .padding(.vertical, DS.accentVertical)
            }
            .cardStyle(tint: phaseColor)
        }
        .buttonStyle(.plain)
        .onAppear { animatedProgress = cycleProgress }
        .onChange(of: dayInCycle) { animatedProgress = cycleProgress }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(phaseName), day \(dayInCycle) of \(cycleLength), \(daysUntilPeriod) days until next period")
        .accessibilityHint("View cycle tracking details")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("home.cycleCard")
    }

    // MARK: - Period Countdown Badge

    private var periodCountdownBadge: some View {
        let text = daysUntilPeriod == 1 ? "1 day until period" : "\(daysUntilPeriod) days until period"

        return Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(phaseColor)
            .padding(.horizontal, DS.badgeH)
            .padding(.vertical, DS.badgeV)
            .background(phaseColor.opacity(DS.badgeBg), in: Capsule())
            .postHogMask()
    }

    // MARK: - Cycle Progress Bar

    private var cycleProgressBar: some View {
        GeometryReader { geo in
            let width = geo.size.width

            ZStack(alignment: .leading) {
                // Background track with phase segments
                HStack(spacing: 1) {
                    phaseSegment(fraction: 5.0 / Double(cycleLength), color: .red, width: width)       // Menstrual
                    phaseSegment(fraction: follicularFraction, color: .pink, width: width)              // Follicular
                    phaseSegment(fraction: 3.0 / Double(cycleLength), color: .orange, width: width)     // Ovulation
                    phaseSegment(fraction: lutealFraction, color: .purple, width: width)                // Luteal
                }
                .opacity(0.3)

                // Filled progress
                HStack(spacing: 1) {
                    phaseSegment(fraction: 5.0 / Double(cycleLength), color: .red, width: width)
                    phaseSegment(fraction: follicularFraction, color: .pink, width: width)
                    phaseSegment(fraction: 3.0 / Double(cycleLength), color: .orange, width: width)
                    phaseSegment(fraction: lutealFraction, color: .purple, width: width)
                }
                .mask(alignment: .leading) {
                    Rectangle()
                        .frame(width: width * animatedProgress)
                }
                .animation(.easeInOut(duration: 0.8), value: animatedProgress)
            }
        }
        .frame(height: 6)
        .clipShape(Capsule())
    }

    private func phaseSegment(fraction: Double, color: Color, width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: max(width * fraction - 1, 0), height: 6)
    }

    // MARK: - Phase Fractions

    /// Follicular phase fills between menstrual end and ovulation start.
    private var follicularFraction: Double {
        let ovulationCenter = max(8, cycleLength - 14)
        let ovulationStart = max(6, ovulationCenter - 1)
        let follicularDays = max(0, ovulationStart - 5)
        return Double(follicularDays) / Double(cycleLength)
    }

    /// Luteal phase fills from ovulation end to cycle end.
    private var lutealFraction: Double {
        let ovulationCenter = max(8, cycleLength - 14)
        let ovulationEnd = min(cycleLength, ovulationCenter + 1)
        let lutealDays = max(0, cycleLength - ovulationEnd)
        return Double(lutealDays) / Double(cycleLength)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        CyclePhaseCard(
            phaseName: "Follicular Phase",
            phaseIcon: "leaf.fill",
            phaseColor: .pink,
            dayInCycle: 8,
            cycleLength: 28,
            daysUntilPeriod: 20,
            onTap: {}
        )

        CyclePhaseCard(
            phaseName: "Menstrual Phase",
            phaseIcon: "drop.fill",
            phaseColor: .red,
            dayInCycle: 3,
            cycleLength: 28,
            daysUntilPeriod: 25,
            onTap: {}
        )

        CyclePhaseCard(
            phaseName: "Ovulatory Phase",
            phaseIcon: "sparkles",
            phaseColor: .orange,
            dayInCycle: 14,
            cycleLength: 30,
            daysUntilPeriod: 16,
            onTap: {}
        )

        CyclePhaseCard(
            phaseName: "Luteal Phase",
            phaseIcon: "moon.stars.fill",
            phaseColor: .purple,
            dayInCycle: 22,
            cycleLength: 28,
            daysUntilPeriod: 6,
            onTap: {}
        )
    }
    .padding(.horizontal)
    .background(Color(.systemGroupedBackground))
}

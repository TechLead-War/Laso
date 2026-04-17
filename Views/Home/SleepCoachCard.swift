import SwiftUI

/// Compact card for the Home tab showing tonight's sleep recommendation.
/// Displays needed sleep duration, recommended bedtime, and optional sleep debt.
struct SleepCoachCard: View {
    let hoursNeeded: Double
    let bedtime: String?
    let debtHours: Double?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Left icon
                Image(systemName: "bed.double.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: DS.iconSize, height: DS.iconSize)
                    .background(.indigo, in: Circle())

                // Center content
                VStack(alignment: .leading, spacing: 3) {
                    Text("Tonight's Goal")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    HStack(spacing: 8) {
                        Text(formatDuration(hoursNeeded))
                            .font(.title3.weight(.bold).monospacedDigit())
                            .foregroundStyle(.primary)
                            .postHogMask()

                        if let debt = debtHours, debt > 0 {
                            debtPill(debt)
                        }
                    }

                    if let bedtime {
                        Text("Bed by \(bedtime)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .postHogMask()
                    }
                }

                Spacer(minLength: 4)

                // Right chevron
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(DS.cardPadding)
            .cardStyle()
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("View sleep coach details")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("home.sleepCoachCard")
    }

    // MARK: - Subviews

    private func debtPill(_ debt: Double) -> some View {
        Text("\(formatDuration(debt)) debt")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.orange)
            .padding(.horizontal, DS.badgeH)
            .padding(.vertical, DS.badgeV)
            .background(Color.orange.opacity(DS.badgeBg), in: Capsule())
            .postHogMask()
    }

    // MARK: - Helpers

    private func formatDuration(_ hours: Double) -> String {
        let clamped = max(0, hours)
        let h = Int(clamped)
        let m = max(0, Int((clamped - Double(h)) * 60))
        if h == 0 { return "\(m)m" }
        return "\(h)h \(String(format: "%02d", m))m"
    }

    private var accessibilityDescription: String {
        var desc = "Tonight's sleep goal: \(formatDuration(hoursNeeded))"
        if let bedtime {
            desc += ", bed by \(bedtime)"
        }
        if let debt = debtHours, debt > 0 {
            desc += ", \(formatDuration(debt)) sleep debt"
        }
        return desc
    }
}

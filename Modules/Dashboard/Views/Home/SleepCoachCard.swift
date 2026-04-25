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
                    .font(.system(size: 20.4).weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: DS.iconSize, height: DS.iconSize)
                    .background(.indigo, in: Circle())

                // Center content
                VStack(alignment: .leading, spacing: DS.space1) {
                    Text(Copy.Home.Cards.tonightsGoal)
                        .font(DS.Typography.calloutSemibold)
                        .foregroundStyle(AppColour.textSecondary)
                        .textCase(.uppercase)

                    HStack(spacing: 8) {
                        Text(formatDuration(hoursNeeded))
                            .font(.system(size: 24).weight(.bold).monospacedDigit())
                            .foregroundStyle(.primary)
                            .postHogMask()

                        if let debt = debtHours, debt > 0 {
                            debtPill(debt)
                        }
                    }

                    if let bedtime {
                        Text(Copy.Home.Cards.bedBy(bedtime))
                            .font(DS.Typography.callout)
                            .foregroundStyle(AppColour.textSecondary)
                            .postHogMask()
                    }
                }

                Spacer(minLength: DS.space1)

                // Right chevron
                Image(systemName: "chevron.right")
                    .font(DS.Typography.footnoteMedium)
                    .foregroundStyle(AppColour.textTertiary)
            }
            .padding(DS.cardPadding)
            .cardStyle()
        }
        .buttonStyle(.dsPress)
        .padding(.horizontal, DS.screenPadding)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("View sleep coach details")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("home.sleepCoachCard")
    }

    // MARK: - Subviews

    private func debtPill(_ debt: Double) -> some View {
        Text("\(formatDuration(debt)) debt")
            .font(DS.Typography.captionSemibold)
            .foregroundStyle(AppColour.warning)
            .padding(.horizontal, DS.badgeH)
            .padding(.vertical, DS.badgeV)
            .background(AppColour.warning.opacity(DS.badgeBg), in: Capsule())
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

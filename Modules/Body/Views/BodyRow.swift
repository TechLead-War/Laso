import SwiftUI

/// One signal on the Body tab: name, today's reading, where it sits in the
/// person's usual band, and a one-line status in the tone's colour.
struct BodyRow: View {
    let row: BodyRowsBuilder.Row
    let onTap: () -> Void

    private var isTappable: Bool { row.route != nil || row.metric != nil }

    private var statusColor: Color {
        switch row.tone {
        case .good, .neutral: return AppColour.scoreGood
        case .fair: return AppColour.scoreFair
        case .poor: return AppColour.scorePoor
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DS.space2) {
                HStack(alignment: .firstTextBaseline, spacing: DS.space2) {
                    Text(row.title)
                        .font(DS.Typography.bodyMedium)
                        .foregroundStyle(AppColour.textPrimary)
                    Spacer(minLength: DS.space2)
                    Text(row.valueText)
                        .font(DS.Typography.subheadline.monospacedDigit())
                        .foregroundStyle(AppColour.textSecondary)
                    if isTappable {
                        Image(systemName: "chevron.right")
                            .font(DS.Typography.caption)
                            .foregroundStyle(AppColour.textTertiary)
                    }
                }

                if let band = row.band {
                    UsualBandBar(band: band, tone: row.tone)
                }

                Text(row.status)
                    .font(DS.Typography.caption)
                    .foregroundStyle(statusColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, DS.space3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isTappable)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("body.row.\(row.id)")
    }
}

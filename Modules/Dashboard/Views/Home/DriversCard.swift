import SwiftUI

/// What is pulling on today's readiness: up to three drivers, each with its
/// reading, one sentence and, where the signal has a usual range, the reading
/// drawn against it. Tapping a row opens the driver's detail.
struct DriversCard: View {
    let drivers: [DailyBrief.Driver]
    let onTap: (DriverKind) -> Void

    private static let iconTile: CGFloat = 36

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(drivers.enumerated()), id: \.element.id) { index, driver in
                if index > 0 {
                    Divider().overlay(AppColour.borderLow)
                }
                row(driver)
            }
        }
        .padding(.horizontal, DS.cardPadding)
        .padding(.vertical, DS.space1)
        .cardStyle()
    }

    private func row(_ driver: DailyBrief.Driver) -> some View {
        Button {
            onTap(driver.kind)
        } label: {
            HStack(alignment: .top, spacing: DS.space3) {
                Image(systemName: Self.symbol(for: driver.kind))
                    .font(DS.Typography.bodySemibold)
                    .foregroundStyle(Self.toneColor(driver.tone))
                    .frame(width: Self.iconTile, height: Self.iconTile)
                    .background(
                        Self.toneColor(driver.tone).opacity(DS.badgeBg),
                        in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: DS.space1) {
                    HStack(alignment: .firstTextBaseline, spacing: DS.space2) {
                        Text(driver.title)
                            .font(DS.Typography.bodySemibold)
                            .foregroundStyle(AppColour.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: DS.space2)
                        Text(driver.valueText)
                            .font(DS.Typography.subheadlineMedium.monospacedDigit())
                            .foregroundStyle(AppColour.textSecondary)
                    }
                    Text(driver.sentence)
                        .font(DS.Typography.footnote)
                        .foregroundStyle(AppColour.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let band = driver.band {
                        UsualBandBar(band: band, tone: driver.tone)
                            .padding(.top, DS.space1)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption)
                    .foregroundStyle(AppColour.textTertiary)
                    .padding(.top, DS.space2)
            }
            .padding(.vertical, DS.space3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.driver.\(driver.kind.id)")
    }

    private static func symbol(for kind: DriverKind) -> String {
        switch kind {
        case .restDays: return "figure.walk"
        case .sleepBalance: return "moon.zzz.fill"
        case .heartRateBounceBack: return "waveform.path.ecg"
        case .strainHigh: return "flame.fill"
        case .stressHigh: return "wind"
        case .anomaly(let metric): return metric.systemImageName
        }
    }

    private static func toneColor(_ tone: DailyBrief.Tone) -> Color {
        switch tone {
        case .good, .neutral: return AppColour.scoreGood
        case .fair: return AppColour.scoreFair
        case .poor: return AppColour.scorePoor
        }
    }
}

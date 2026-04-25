import SwiftUI

struct LiveVitalsSection: View {
    let vitals: LiveViewModel.VitalsData
    var vitalsTracker: SectionTracker
    @Binding var maxScrollDepth: Int

    var body: some View {
        HStack(spacing: 12) {
            vitalCard(
                icon: "drop.fill",
                iconColor: .blue,
                label: "SpO2",
                value: vitals.currentBloodOxygen.map { String(format: "%.0f", $0) },
                unit: "%",
                timestamp: vitals.bloodOxygenTimestamp,
                status: vitals.bloodOxygenStatus,
                isFresh: vitals.isBloodOxygenFresh
            )

            vitalCard(
                icon: "wind",
                iconColor: .teal,
                label: "Resp Rate",
                value: vitals.currentRespiratoryRate.map { String(format: "%.0f", $0) },
                unit: "br/min",
                timestamp: vitals.respiratoryRateTimestamp,
                status: vitals.respiratoryRateStatus,
                isFresh: vitals.isRespiratoryRateFresh,
                isUnavailable: vitals.respiratoryRateUnavailable,
                unavailableHint: "Measured during sleep"
            )
        }
        .padding(.horizontal)
        .onAppear { vitalsTracker.appeared(); maxScrollDepth = max(maxScrollDepth, 45) }
        .onDisappear { vitalsTracker.disappeared() }
    }

    private func vitalCard(
        icon: String,
        iconColor: Color,
        label: String,
        value: String?,
        unit: String,
        timestamp: Date?,
        status: LiveViewModel.VitalStatus,
        isFresh: Bool = true,
        isUnavailable: Bool = false,
        unavailableHint: String? = nil
    ) -> some View {
        let isStale = !isFresh && timestamp != nil
        let blockType: BlockType? = {
            switch label {
            case "SpO2": return .vitalCardSpo2
            case "Resp Rate": return .vitalCardRespRate
            default: return nil
            }
        }()

        return Button {
            guard let blockType else { return }
            let metricId: String = label == "SpO2" ? HealthMetric.bloodOxygen.rawValue : HealthMetric.respiratoryRate.rawValue
            AppAnalytics.shared.trackBlockTap(
                title: label,
                type: blockType,
                screen: .live,
                metadata: [
                    "metric_id": metricId,
                    "status": status.label,
                    "is_stale": isStale ? 1 : 0
                ]
            )
            vitalsTracker.tapped(target: label.lowercased().replacingOccurrences(of: " ", with: "_"))
        } label: {
            VStack(alignment: .leading, spacing: DS.space2) {
                HStack {
                    Image(systemName: icon)
                        .font(DS.Typography.captionSemibold)
                        .foregroundStyle(iconColor.opacity(isStale ? 0.5 : 1.0))

                    Text(label)
                        .font(DS.Typography.caption2Medium)
                        .foregroundStyle(AppColour.textSecondary)

                    Spacer()
                }

                if isUnavailable && value == nil {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No data")
                            .font(DS.Typography.subheadlineMedium)
                            .foregroundStyle(AppColour.textTertiary)
                        if let hint = unavailableHint {
                            Text(hint)
                                .font(DS.Typography.caption2)
                                .foregroundStyle(AppColour.textQuaternary)
                        }
                    }
                } else if let value {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(value)
                            .font(DS.Typography.title2.monospacedDigit())
                            .foregroundStyle(AppColour.textPrimary.opacity(isStale ? 0.4 : 1.0))
                            .contentTransition(.numericText())
                            .postHogMask()

                        Text(unit)
                            .font(DS.Typography.caption2Medium)
                            .foregroundStyle(AppColour.textSecondary.opacity(isStale ? 0.5 : 1.0))
                    }
                } else {
                    Text("Syncing")
                        .font(DS.Typography.subheadlineMedium)
                        .foregroundStyle(AppColour.textTertiary)
                }

                if isStale {
                    // Prominent stale timestamp
                    if let ts = timestamp {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(DS.Typography.caption2)
                            Text(ts, style: .relative)
                                .font(DS.Typography.caption2Medium)
                            Text("ago")
                                .font(DS.Typography.caption2Medium)
                        }
                        .foregroundStyle(AppColour.textSecondary)
                    }
                } else {
                    HStack(spacing: 4) {
                        if status != .unknown {
                            Circle()
                                .fill(status.color)
                                .frame(width: 6, height: 6)
                            Text(status.label)
                                .font(DS.Typography.caption2Medium)
                                .foregroundStyle(status.color)
                        }

                        Spacer()

                        if let ts = timestamp {
                            Text(ts, style: .relative)
                                .font(DS.Typography.caption2)
                                .foregroundStyle(AppColour.textQuaternary)
                        }
                    }
                }
            }
            .padding(DS.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(label), \(value ?? "no data") \(unit), \(status.label)")
            .accessibilityHint("Opens \(label) detail")
        }
        .buttonStyle(.dsPress)
    }
}

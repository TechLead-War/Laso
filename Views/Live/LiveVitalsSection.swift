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

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(iconColor.opacity(isStale ? 0.5 : 1.0))

                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()
            }

            if isUnavailable && value == nil {
                VStack(alignment: .leading, spacing: 2) {
                    Text("No data")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.tertiary)
                    if let hint = unavailableHint {
                        Text(hint)
                            .font(.caption2)
                            .foregroundStyle(.quaternary)
                    }
                }
            } else if let value {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(.primary.opacity(isStale ? 0.4 : 1.0))
                        .contentTransition(.numericText())

                    Text(unit)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary.opacity(isStale ? 0.5 : 1.0))
                }
            } else {
                Text("Syncing")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.tertiary)
            }

            if isStale {
                // Prominent stale timestamp
                if let ts = timestamp {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(ts, style: .relative)
                            .font(.caption2.weight(.medium))
                        Text("ago")
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 4) {
                    if status != .unknown {
                        Circle()
                            .fill(status.color)
                            .frame(width: 6, height: 6)
                        Text(status.label)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(status.color)
                    }

                    Spacer()

                    if let ts = timestamp {
                        Text(ts, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.quaternary)
                    }
                }
            }
        }
        .padding(DS.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value ?? "no data") \(unit), \(status.label)")
        .onTapGesture {
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
        }
    }
}

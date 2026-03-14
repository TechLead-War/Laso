import SwiftUI

struct LiveStaleVitalsPrompt: View {
    let vitals: LiveViewModel.VitalsData
    let primaryDevice: SupportedDevice?

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                Image(systemName: primaryDevice?.systemImageName ?? "waveform.path.ecg")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(promptTitle)
                        .font(.subheadline.weight(.semibold))

                    Text(promptBody)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)

            // Last known readings — compact muted row
            if vitals.hasAnyData {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("Last Known Readings")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 16) {
                        if let hr = vitals.currentHeartRate {
                            staleReadingPill(
                                icon: "heart.fill",
                                color: .red,
                                value: "\(Int(hr))",
                                unit: "bpm",
                                timestamp: vitals.heartRateTimestamp
                            )
                        }
                        if let spo2 = vitals.currentBloodOxygen {
                            staleReadingPill(
                                icon: "drop.fill",
                                color: .blue,
                                value: "\(Int(spo2))",
                                unit: "%",
                                timestamp: vitals.bloodOxygenTimestamp
                            )
                        }
                        if let rr = vitals.currentRespiratoryRate {
                            staleReadingPill(
                                icon: "wind",
                                color: .teal,
                                value: "\(Int(rr))",
                                unit: "br/m",
                                timestamp: vitals.respiratoryRateTimestamp
                            )
                        }
                    }
                }
                .padding(DS.cardPadding)
                .cardStyle()
                .padding(.horizontal)
            }
        }
    }

    private func staleReadingPill(icon: String, color: Color, value: String, unit: String, timestamp: Date?) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color.opacity(0.6))
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(value)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            if let ts = timestamp {
                Text(ts, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var promptTitle: String {
        if let primaryDevice {
            return "\(primaryDevice.displayName) data is stale"
        }
        return "Live vitals need a wearable source"
    }

    private var promptBody: String {
        if let primaryDevice {
            return "\(primaryDevice.displayName) has not written a fresh sample recently. Reopen its companion app or wear the device again to refresh live vitals."
        }
        return "Apple Health still has your last readings, but live heart rate, oxygen, and breathing updates need a wearable that syncs into Health."
    }
}

struct LiveWaitingForDataView: View {
    let isStreaming: Bool
    let primaryDevice: SupportedDevice?
    let hasLiveSource: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 40)

            Image(systemName: primaryDevice?.systemImageName ?? "waveform.path.ecg")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse, isActive: isStreaming)

            VStack(spacing: 8) {
                Text(titleText)
                    .font(.title3.weight(.semibold))

                Text(bodyText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text(footnoteText)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(tips, id: \.text) { tip in
                    tipRow(icon: tip.icon, text: tip.text)
                }
            }
            .padding(DS.cardPadding)
            .cardStyle()
            .padding(.horizontal)

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var titleText: String {
        if hasLiveSource {
            return "Waiting for Live Data"
        }
        return "Live monitoring needs a wearable"
    }

    private var bodyText: String {
        if let primaryDevice {
            return "\(primaryDevice.displayName) is connected. Wear it or reopen its companion app so fresh samples can reach Apple Health."
        }
        return "You can still use Laso with regular Health data, but live heart rate, oxygen, and respiratory updates need a wearable source."
    }

    private var footnoteText: String {
        if hasLiveSource {
            return "Fresh samples usually appear within a minute"
        }
        return "Connect a wearable source to unlock the Live tab"
    }

    private var tips: [(icon: String, text: String)] {
        if let primaryDevice {
            return [
                (primaryDevice.systemImageName, "Wear your \(primaryDevice.displayName) and keep it nearby"),
                ("bluetooth", "Keep Bluetooth enabled on iPhone"),
                ("heart.fill", "Open the companion app or start a quick workout to generate a fresh sample"),
                ("arrow.clockwise", "Recent data may take a moment to sync")
            ]
        }

        return [
            ("sensor.fill", "Connect a supported wearable through its companion app"),
            ("square.and.arrow.down.on.square", "Enable Apple Health sharing in the companion app"),
            ("heart.fill", "Use Home and Explore normally while Laso waits for live vitals"),
            ("arrow.clockwise", "Return after the first wearable sync")
        ]
    }

    private var accessibilityLabel: String {
        if let primaryDevice {
            return "Waiting for live data from \(primaryDevice.displayName)."
        }
        return "Live monitoring needs a wearable source."
    }
}

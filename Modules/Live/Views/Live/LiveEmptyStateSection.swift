import SwiftUI

struct LiveStaleVitalsPrompt: View {
    let vitals: LiveViewModel.VitalsData
    let primaryDevice: SupportedDevice?

    var body: some View {
        VStack(spacing: DS.cardPadding) {
            HStack(spacing: DS.itemSpacing) {
                Image(systemName: primaryDevice?.systemImageName ?? "waveform.path.ecg")
                    .font(DS.Typography.title2)
                    .foregroundStyle(AppColour.textSecondary)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: DS.space1) {
                    Text(promptTitle)
                        .font(DS.Typography.subheadlineSemibold)

                    Text(promptBody)
                        .font(DS.Typography.caption)
                        .foregroundStyle(AppColour.textSecondary)
                        .lineLimit(2)
                }
            }
            .padding(DS.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .padding(.horizontal)

            // Last known readings. compact muted row
            if vitals.hasAnyData {
                VStack(alignment: .leading, spacing: DS.space2) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(DS.Typography.captionSemibold)
                            .foregroundStyle(AppColour.textSecondary)
                        Text(Copy.Live.lastKnownReadings)
                            .font(DS.Typography.captionSemibold)
                            .foregroundStyle(AppColour.textSecondary)
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
        VStack(spacing: DS.space1) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(DS.Typography.caption2)
                    .foregroundStyle(color.opacity(0.6))
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(value)
                        .font(DS.Typography.subheadlineSemibold.monospacedDigit())
                        .foregroundStyle(AppColour.textSecondary)
                    Text(unit)
                        .font(DS.Typography.caption2)
                        .foregroundStyle(AppColour.textTertiary)
                }
            }
            if let ts = timestamp {
                Text(ts, style: .relative)
                    .font(DS.Typography.caption2)
                    .foregroundStyle(AppColour.textQuaternary)
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
        VStack(spacing: DS.sectionSpacing) {
            Spacer().frame(height: 40)

            Image(systemName: primaryDevice?.systemImageName ?? "waveform.path.ecg")
                .font(DS.Typography.heroIcon)
                .foregroundStyle(AppColour.textSecondary)
                .symbolEffect(.pulse, isActive: isStreaming)

            VStack(spacing: DS.space2) {
                Text(titleText)
                    .font(DS.Typography.title3)

                Text(bodyText)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(AppColour.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.space7)

                Text(footnoteText)
                    .font(DS.Typography.caption)
                    .foregroundStyle(AppColour.textTertiary)
                    .padding(.top, DS.space1)
            }

            VStack(alignment: .leading, spacing: DS.itemSpacing) {
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
        HStack(spacing: DS.itemSpacing) {
            Image(systemName: icon)
                .font(DS.Typography.body)
                .foregroundStyle(AppColour.info)
                .frame(width: 28)
            Text(text)
                .font(DS.Typography.subheadline)
                .foregroundStyle(AppColour.textSecondary)
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
                ("antenna.radiowaves.left.and.right", "Keep Bluetooth enabled on iPhone"),
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

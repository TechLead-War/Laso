import SwiftUI

struct LiveStaleVitalsPrompt: View {
    let vitals: LiveViewModel.VitalsData

    var body: some View {
        VStack(spacing: 16) {
            // Wear your watch CTA
            VStack(spacing: 12) {
                Image(systemName: DeviceMessaging.deviceIcon)
                    .font(.system(size: 36))
                    .foregroundStyle(.orange)

                Text(DeviceMessaging.wearPromptTitle)
                    .font(.title3.weight(.semibold))

                Text(DeviceMessaging.staleVitalsMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.orange.opacity(0.15), lineWidth: 0.5)
            )
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
                    .font(.system(size: 9))
                    .foregroundStyle(.quaternary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct LiveWaitingForDataView: View {
    let isStreaming: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 40)

            Image(systemName: DeviceMessaging.deviceIcon)
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse, isActive: isStreaming)

            VStack(spacing: 8) {
                Text("Waiting for Live Data")
                    .font(.title3.weight(.semibold))

                Text(DeviceMessaging.ensurePairedMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Tips
            VStack(alignment: .leading, spacing: 12) {
                tipRow(icon: DeviceMessaging.deviceIcon, text: "Wear your \(DeviceMessaging.deviceName) snugly")
                tipRow(icon: "bluetooth", text: "Keep Bluetooth enabled on iPhone")
                tipRow(icon: "heart.fill", text: "Open a workout or check your heart rate on the Watch")
                tipRow(icon: "arrow.clockwise", text: "Recent data may take a moment to sync")
            }
            .padding(DS.cardPadding)
            .cardStyle()
            .padding(.horizontal)

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Waiting for live data from \(DeviceMessaging.deviceName). Make sure your device is paired and worn.")
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
}

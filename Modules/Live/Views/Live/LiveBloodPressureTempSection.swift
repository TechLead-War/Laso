import SwiftUI

struct LiveBloodPressureTempSection: View {
    let vitals: LiveViewModel.VitalsData
    var bpTempTracker: SectionTracker

    var body: some View {
        let hasBP = vitals.latestSystolic != nil
        let hasTemp = vitals.latestBodyTemp != nil

        if hasBP || hasTemp {
            HStack(spacing: 12) {
                if let sys = vitals.latestSystolic, let dia = vitals.latestDiastolic {
                    // Blood Pressure card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "waveform.path.ecg")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.purple)
                            Text("Blood Pressure")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(Int(sys))/\(Int(dia))")
                                .font(.title2.weight(.bold).monospacedDigit())
                                .postHogMask()
                            Text("mmHg")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 4) {
                            Circle()
                                .fill(vitals.bloodPressureStatus.color)
                                .frame(width: 6, height: 6)
                            Text(vitals.bloodPressureStatus.label)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(vitals.bloodPressureStatus.color)
                        }
                    }
                    .padding(DS.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                    .onTapGesture {
                        AppAnalytics.shared.trackBlockTap(
                            title: "Blood Pressure",
                            type: .bloodPressureCard,
                            screen: .live,
                            metadata: [
                                "metric_id": "blood_pressure",
                                "systolic": Int(sys),
                                "diastolic": Int(dia)
                            ]
                        )
                        bpTempTracker.tapped(target: "blood_pressure")
                    }
                }

                if let temp = vitals.latestBodyTemp {
                    // Temperature card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "thermometer.medium")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                            Text("Temperature")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(String(format: "%.1f", temp))
                                .font(.title2.weight(.bold).monospacedDigit())
                                .postHogMask()
                            Text("°C")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }

                        if let ts = vitals.bodyTempTimestamp {
                            Text(ts, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(DS.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                    .onTapGesture {
                        AppAnalytics.shared.trackBlockTap(
                            title: "Temperature",
                            type: .temperatureCard,
                            screen: .live,
                            metadata: [
                                "metric_id": HealthMetric.bodyTemperature.rawValue,
                                "value_c": temp
                            ]
                        )
                        bpTempTracker.tapped(target: "temperature")
                    }
                }
            }
            .padding(.horizontal)
            .onAppear { bpTempTracker.appeared() }
            .onDisappear { bpTempTracker.disappeared() }
        }
    }
}

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
                    Button {
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
                    } label: {
                        VStack(alignment: .leading, spacing: DS.space2) {
                            HStack {
                                Image(systemName: "waveform.path.ecg")
                                    .font(DS.Typography.captionSemibold)
                                    .foregroundStyle(.purple)
                                Text("Blood Pressure")
                                    .font(DS.Typography.caption2Medium)
                                    .foregroundStyle(AppColour.textSecondary)
                            }

                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text("\(Int(sys))/\(Int(dia))")
                                    .font(DS.Typography.title2.monospacedDigit())
                                    .postHogMask()
                                Text("mmHg")
                                    .font(DS.Typography.caption2Medium)
                                    .foregroundStyle(AppColour.textSecondary)
                            }

                            HStack(spacing: 4) {
                                Circle()
                                    .fill(vitals.bloodPressureStatus.color)
                                    .frame(width: 6, height: 6)
                                Text(vitals.bloodPressureStatus.label)
                                    .font(DS.Typography.caption2Medium)
                                    .foregroundStyle(vitals.bloodPressureStatus.color)
                            }
                        }
                        .padding(DS.cardPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()
                    }
                    .buttonStyle(.dsPress)
                }

                if let temp = vitals.latestBodyTemp {
                    // Temperature card
                    Button {
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
                    } label: {
                        VStack(alignment: .leading, spacing: DS.space2) {
                            HStack {
                                Image(systemName: "thermometer.medium")
                                    .font(DS.Typography.captionSemibold)
                                    .foregroundStyle(AppColour.warning)
                                Text("Temperature")
                                    .font(DS.Typography.caption2Medium)
                                    .foregroundStyle(AppColour.textSecondary)
                            }

                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(String(format: "%.1f", temp))
                                    .font(DS.Typography.title2.monospacedDigit())
                                    .postHogMask()
                                Text("°C")
                                    .font(DS.Typography.caption2Medium)
                                    .foregroundStyle(AppColour.textSecondary)
                            }

                            if let ts = vitals.bodyTempTimestamp {
                                Text(ts, style: .relative)
                                    .font(DS.Typography.caption2)
                                    .foregroundStyle(AppColour.textTertiary)
                            }
                        }
                        .padding(DS.cardPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()
                    }
                    .buttonStyle(.dsPress)
                }
            }
            .padding(.horizontal)
            .onAppear { bpTempTracker.appeared() }
            .onDisappear { bpTempTracker.disappeared() }
        }
    }
}

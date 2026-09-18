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
                                Text(Copy.Live.bloodPressure)
                                    .font(DS.Typography.caption2Medium)
                                    .foregroundStyle(AppColour.textSecondary)
                            }

                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(Copy.Live.bloodPressureSysOverDia(Int(sys), Int(dia)))
                                    .font(DS.Typography.title2.monospacedDigit())
                                    .postHogMask()
                                Text(Copy.Live.mmhg)
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
                                Text(Copy.Live.temperature)
                                    .font(DS.Typography.caption2Medium)
                                    .foregroundStyle(AppColour.textSecondary)
                            }

                            // Body temperature is stored canonically
                            // in °C by HealthKit but US/UK users expect °F.
                            // Convert via Measurement<UnitTemperature> so the
                            // value + unit label respect Locale.current.
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(Self.localizedTemperatureValue(temp))
                                    .font(DS.Typography.title2.monospacedDigit())
                                    .postHogMask()
                                Text(Self.localizedTemperatureUnit())
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

    // Convert the canonical Celsius value into the user's
    // measurement system. Using `Measurement<UnitTemperature>` keeps this
    // self-contained and avoids depending on shared helpers that other
    // agents may revert. `Locale.current.measurementSystem == .metric`
    // covers metric vs imperial; UK reports metric for temperature too.
    private static func localizedTemperatureValue(_ celsius: Double) -> String {
        let isMetric = Locale.current.measurementSystem == .metric
        if isMetric {
            return String(format: "%.1f", celsius)
        }
        let m = Measurement(value: celsius, unit: UnitTemperature.celsius)
            .converted(to: .fahrenheit)
        return String(format: "%.1f", m.value)
    }

    private static func localizedTemperatureUnit() -> String {
        Locale.current.measurementSystem == .metric ? "°C" : "°F"
    }
}

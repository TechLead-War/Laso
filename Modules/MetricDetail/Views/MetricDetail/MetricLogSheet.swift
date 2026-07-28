import SwiftUI
import HealthKit

/// Sheet for logging weight, water intake, or mindful session data to HealthKit
struct MetricLogSheet: View {
    let metric: HealthMetric
    let healthKitManager: HealthKitManager
    let healthDataStore: HealthDataStore

    @Environment(\.dismiss) private var dismiss

    // Weight
    @State private var weightKg: Double = 70

    // Water
    @State private var waterMl: Double = 250

    // Mindful
    @State private var mindfulMinutes: Double = 10

    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didSave = false
    @State private var formTracker = SectionTracker(section: .metricLogForm, tab: .metricLog)

    var body: some View {
        NavigationStack {
            Form {
                switch metric {
                case .weight:
                    weightSection
                case .waterIntake:
                    waterSection
                case .mindfulMinutes:
                    mindfulSection
                default:
                    Text(Copy.MetricDetail.loggingNotSupported)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(AppColour.danger)
                            .font(DS.Typography.subheadline)
                    }
                }
            }
            .navigationTitle(Copy.MetricDetail.logTitle(metric.displayName))
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("screen.metricLog")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Copy.MetricDetail.cancel) {
                        AppAnalytics.shared.trackBlockTap(
                            title: "Cancel",
                            type: .metricLogCancel,
                            screen: .metricLog,
                            metadata: [
                                "metric_id": metric.rawValue
                            ]
                        )
                        formTracker.tapped(target: "cancel")
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(Copy.MetricDetail.save) {
                        AppAnalytics.shared.trackBlockTap(
                            title: "Save",
                            type: .metricLogSave,
                            screen: .metricLog,
                            metadata: [
                                "metric_id": metric.rawValue,
                                "value": currentInputValue
                            ]
                        )
                        formTracker.tapped(target: "save")
                        Task { await save() }
                    }
                    .fontWeight(.semibold)
                    .disabled(isSaving)
                }
            }
            .sensoryFeedback(.success, trigger: didSave)
        }
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.metricLog, metadata: [
                "metric": metric.rawValue
            ])
            formTracker.appeared()
        }
        .onDisappear {
            AppAnalytics.shared.trackFeatureClose(.metricLog, metadata: [
                "metric": metric.rawValue
            ])
            formTracker.disappeared()
        }
    }

    // MARK: - Weight

    private var weightSection: some View {
        Section {
            VStack(spacing: 12) {
                Text("\(String(format: "%.1f", weightKg)) kg")
                    .font(DS.Typography.displayM)
                    .monospacedDigit()

                Slider(value: $weightKg, in: 30...250, step: 0.1) { editing in
                    // Only on release, so one drag is one event instead of one per frame.
                    guard !editing else { return }
                    AppAnalytics.shared.trackBlockTap(
                        title: "Weight Slider",
                        type: .valueInputAdjusted,
                        screen: .metricLog,
                        metadata: [
                            "metric_id": HealthMetric.weight.rawValue,
                            "value": weightKg
                        ]
                    )
                    formTracker.tapped(target: "weight_slider")
                }
            }
            .padding(.vertical, DS.space2)
        } header: {
            Text(Copy.MetricDetail.bodyWeightHeader)
        }
    }

    // MARK: - Water

    private var waterSection: some View {
        Section {
            VStack(spacing: 16) {
                Text(Copy.MetricDetail.mlText(Int(waterMl)))
                    .font(DS.Typography.displayM)
                    .monospacedDigit()

                HStack(spacing: 12) {
                    ForEach([250, 500, 750, 1000], id: \.self) { amount in
                        Button {
                            waterMl = Double(amount)
                            AppAnalytics.shared.trackBlockTap(
                                title: "Water \(amount)",
                                type: .metricLogQuickAmount,
                                screen: .metricLog,
                                metadata: [
                                    "metric_id": HealthMetric.waterIntake.rawValue,
                                    "amount_ml": amount
                                ]
                            )
                            formTracker.tapped(target: "water_\(amount)")
                        } label: {
                            Text(Copy.MetricDetail.xText(amount))
                                .font(DS.Typography.subheadlineMedium)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(Int(waterMl) == amount ? AppColour.primary : AppColour.textSecondary)
                    }
                }

                Slider(value: $waterMl, in: 50...2000, step: 50) { editing in
                    // Only on release, so one drag is one event instead of one per frame.
                    guard !editing else { return }
                    AppAnalytics.shared.trackBlockTap(
                        title: "Water Slider",
                        type: .valueInputAdjusted,
                        screen: .metricLog,
                        metadata: [
                            "metric_id": HealthMetric.waterIntake.rawValue,
                            "value": waterMl
                        ]
                    )
                    formTracker.tapped(target: "water_slider")
                }
            }
            .padding(.vertical, DS.space2)
        } header: {
            Text(Copy.MetricDetail.waterIntakeHeader)
        }
    }

    // MARK: - Mindful

    private var mindfulSection: some View {
        Section {
            VStack(spacing: 12) {
                Text(Copy.MetricDetail.minText(Int(mindfulMinutes)))
                    .font(DS.Typography.displayM)
                    .monospacedDigit()

                Slider(value: $mindfulMinutes, in: 1...120, step: 1) { editing in
                    // Only on release, so one drag is one event instead of one per frame.
                    guard !editing else { return }
                    AppAnalytics.shared.trackBlockTap(
                        title: "Mindful Minutes Slider",
                        type: .valueInputAdjusted,
                        screen: .metricLog,
                        metadata: [
                            "metric_id": HealthMetric.mindfulMinutes.rawValue,
                            "value": mindfulMinutes
                        ]
                    )
                    formTracker.tapped(target: "mindful_slider")
                }
            }
            .padding(.vertical, DS.space2)
        } header: {
            Text(Copy.MetricDetail.sessionDurationHeader)
        }
    }

    // MARK: - Save

    private func save() async {
        isSaving = true
        errorMessage = nil

        do {
            switch metric {
            case .weight:
                try await healthKitManager.saveWeight(weightKg)
            case .waterIntake:
                try await healthKitManager.saveWaterIntake(milliliters: waterMl)
            case .mindfulMinutes:
                try await healthKitManager.saveMindfulSession(minutes: mindfulMinutes)
            default:
                break
            }

            await healthKitManager.refreshMetric(metric, store: healthDataStore)
            didSave = true
            dismiss()
        } catch {
            errorMessage = Copy.MetricDetail.saveFailed(error.localizedDescription)
            isSaving = false
        }
    }

    private var currentInputValue: String {
        switch metric {
        case .weight:
            return String(format: "%.1f", weightKg)
        case .waterIntake:
            return "\(Int(waterMl))"
        case .mindfulMinutes:
            return "\(Int(mindfulMinutes))"
        default:
            return "0"
        }
    }
}

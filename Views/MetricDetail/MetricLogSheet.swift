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
                    Text("Logging not supported for this metric.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Log \(metric.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .fontWeight(.semibold)
                    .disabled(isSaving)
                }
            }
            .sensoryFeedback(.success, trigger: didSave)
        }
    }

    // MARK: - Weight

    private var weightSection: some View {
        Section {
            VStack(spacing: 12) {
                Text("\(String(format: "%.1f", weightKg)) kg")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()

                Slider(value: $weightKg, in: 30...250, step: 0.1)
            }
            .padding(.vertical, 8)
        } header: {
            Text("Body Weight")
        }
    }

    // MARK: - Water

    private var waterSection: some View {
        Section {
            VStack(spacing: 16) {
                Text("\(Int(waterMl)) mL")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()

                HStack(spacing: 12) {
                    ForEach([250, 500, 750, 1000], id: \.self) { amount in
                        Button {
                            waterMl = Double(amount)
                        } label: {
                            Text("\(amount)")
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(Int(waterMl) == amount ? .blue : .secondary)
                    }
                }

                Slider(value: $waterMl, in: 50...2000, step: 50)
            }
            .padding(.vertical, 8)
        } header: {
            Text("Water Intake")
        }
    }

    // MARK: - Mindful

    private var mindfulSection: some View {
        Section {
            VStack(spacing: 12) {
                Text("\(Int(mindfulMinutes)) min")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()

                Slider(value: $mindfulMinutes, in: 1...120, step: 1)
            }
            .padding(.vertical, 8)
        } header: {
            Text("Session Duration")
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
            errorMessage = "Failed to save: \(error.localizedDescription)"
            isSaving = false
        }
    }
}

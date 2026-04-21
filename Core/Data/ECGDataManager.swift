import Foundation
import HealthKit

/// Fetches ECG recordings from HealthKit and extracts voltage measurements
struct ECGDataManager {

    struct ECGRecording {
        let uuid: UUID
        let date: Date
        let classification: HKElectrocardiogram.Classification
        let averageHeartRate: Double?   // bpm
        let samplingFrequency: Double   // Hz
        let voltageMeasurements: [Double]  // Voltage values in microvolts
        let numberOfSamples: Int
    }

    /// Fetch all ECG recordings within the date range
    static func fetchECGs(
        healthStore: HKHealthStore,
        from startDate: Date,
        to endDate: Date
    ) async -> [ECGRecording] {
        guard HKHealthStore.isHealthDataAvailable() else { return [] }

        let ecgType = HKObjectType.electrocardiogramType()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let samples: [HKElectrocardiogram] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: ecgType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, results, error in
                guard let ecgSamples = results as? [HKElectrocardiogram], error == nil else {
                    continuation.resume(returning: [])
                    return
                }
                continuation.resume(returning: ecgSamples)
            }
            healthStore.execute(query)
        }

        // Fetch voltage measurements for each ECG
        var recordings: [ECGRecording] = []
        for sample in samples {
            let voltages = await fetchVoltages(healthStore: healthStore, ecg: sample)
            let avgHR = sample.averageHeartRate?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))

            recordings.append(ECGRecording(
                uuid: sample.uuid,
                date: sample.startDate,
                classification: sample.classification,
                averageHeartRate: avgHR,
                samplingFrequency: sample.samplingFrequency?.doubleValue(for: .hertz()) ?? 512.0,
                voltageMeasurements: voltages,
                numberOfSamples: sample.numberOfVoltageMeasurements
            ))
        }

        return recordings
    }

    /// Fetch voltage measurements for a single ECG recording
    private static func fetchVoltages(
        healthStore: HKHealthStore,
        ecg: HKElectrocardiogram
    ) async -> [Double] {
        await withCheckedContinuation { continuation in
            var voltages: [Double] = []
            voltages.reserveCapacity(ecg.numberOfVoltageMeasurements)

            let query = HKElectrocardiogramQuery(ecg) { _, result in
                switch result {
                case .measurement(let measurement):
                    if let voltage = measurement.quantity(for: .appleWatchSimilarToLeadI) {
                        voltages.append(voltage.doubleValue(for: .voltUnit(with: .micro)))
                    }
                case .done:
                    continuation.resume(returning: voltages)
                case .error:
                    continuation.resume(returning: voltages)
                @unknown default:
                    break
                }
            }
            healthStore.execute(query)
        }
    }
}

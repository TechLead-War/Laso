import Foundation
import HealthKit
import Observation

/// What the wrist measures for itself.
///
/// Deliberately not a port of `HealthKitManager`. That class covers 72 metrics, a
/// registry, SwiftData persistence, thermal gating and an ML pipeline, none of which
/// belongs on a watch. This reads the five values `WatchVerdict` needs to produce a word
/// with the phone switched off, and nothing else.
///
/// The split this file exists to serve: anything describing **now** is measured here and
/// can never be stale, while anything needing 30 to 90 days of history arrives in the
/// phone's payload. That is what makes "open Laso on your iPhone" unreachable as a
/// state — see `design/watch-v2/03-ARCHITECTURE.md`.
///
/// watchOS keeps roughly seven days of samples locally, so nothing here attempts a
/// baseline. Baselines come from the phone.
@Observable
@MainActor
final class WatchHealthStore {

    private(set) var restingHeartRate: Double?
    private(set) var heartRate: Double?
    private(set) var heartRateSampledAt: Date?
    private(set) var heartRateVariability: Double?
    private(set) var exerciseMinutesToday: Int = 0
    private(set) var stepsToday: Int = 0
    private(set) var stepsLastTenMinutes: Int = 0
    private(set) var exerciseMinutesLastTenMinutes: Int = 0

    /// Nil until the first authorization answer.
    ///
    /// False means HealthKit is unavailable on this device or the request itself failed.
    /// It does NOT mean the wearer tapped Don't Allow: HealthKit deliberately never
    /// reports a read denial, precisely so an app cannot infer what was hidden. See
    /// `hasNoReadableData` for the state that covers a refusal.
    private(set) var isAuthorized: Bool?

    /// True once a completed refresh found nothing at all.
    ///
    /// Read access was refused, or this watch genuinely has no data yet. The two are
    /// indistinguishable by design, so the screen says how to check rather than
    /// asserting which one it is. Nil before the first refresh completes, so the app
    /// never accuses anyone on the strength of a query that has not returned.
    private(set) var hasNoReadableData: Bool?

    private let store = HKHealthStore()
    private var streamQuery: HKAnchoredObjectQuery?

    /// Read set, kept to what the ladder actually consumes. Every addition here is a new
    /// line in the permission sheet, so the list is a product decision, not a habit.
    private static var readTypes: Set<HKObjectType> {
        Set([
            HKQuantityType(.heartRate),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.appleExerciseTime),
            HKQuantityType(.stepCount)
        ])
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            isAuthorized = false
            return
        }
        do {
            try await store.requestAuthorization(toShare: [], read: Self.readTypes)
            isAuthorized = true
            await refresh()
            // Only safe to start once authorization has resolved. Starting it from the
            // scene-phase handler alone meant it never started at all on a cold launch,
            // because that handler runs while `isAuthorized` is still nil.
            startHeartRateStream()
        } catch {
            // Fail loudly on the screen rather than silently showing an empty wrist:
            // `WatchRootView` renders the health-off state off this flag.
            isAuthorized = false
        }
    }

    // MARK: - Read

    /// One pass over everything the ladder needs. Cheap enough to run on every
    /// appearance: five queries, all bounded to today or to a single latest sample.
    func refresh() async {
        guard HKHealthStore.isHealthDataAvailable(), isAuthorized != false else { return }

        async let resting = latest(.restingHeartRate, unit: .count().unitDivided(by: .minute()))
        async let hrv = latest(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli))
        async let live = latestWithDate(.heartRate, unit: .count().unitDivided(by: .minute()))
        async let exercise = sumToday(.appleExerciseTime, unit: .minute())
        async let steps = sumToday(.stepCount, unit: .count())
        async let recentSteps = sum(.stepCount, unit: .count(), since: Date().addingTimeInterval(-600))
        async let recentExercise = sum(.appleExerciseTime, unit: .minute(), since: Date().addingTimeInterval(-600))

        restingHeartRate = await resting
        heartRateVariability = await hrv
        let sample = await live
        heartRate = sample?.value
        heartRateSampledAt = sample?.date
        exerciseMinutesToday = Int((await exercise ?? 0).rounded())
        stepsToday = Int((await steps ?? 0).rounded())
        stepsLastTenMinutes = Int((await recentSteps ?? 0).rounded())
        exerciseMinutesLastTenMinutes = Int((await recentExercise ?? 0).rounded())

        // Nothing readable at all after a completed pass. Either read access was refused
        // or this watch has no history yet; HealthKit will not say which.
        hasNoReadableData = restingHeartRate == nil && heartRate == nil
            && heartRateVariability == nil && stepsToday == 0 && exerciseMinutesToday == 0
    }

    /// Live heart rate while the app is in front.
    ///
    /// Foreground only, on purpose. Background execution on watchOS is "a few seconds"
    /// and never guaranteed, so a stream that claimed to run all day would be a lie the
    /// battery pays for. The complication reads the last cached value instead.
    func startHeartRateStream() {
        guard HKHealthStore.isHealthDataAvailable(), isAuthorized == true, streamQuery == nil else { return }

        // HealthKit calls this on its own queue, so it is marked sendable and hops to
        // the main actor before touching any stored property.
        let handler: @Sendable (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void = {
            [weak self] _, samples, _, _, _ in
            guard let newest = (samples as? [HKQuantitySample])?.max(by: { $0.endDate < $1.endDate })
            else { return }
            let bpm = newest.quantity.doubleValue(for: .count().unitDivided(by: .minute()))
            Task { @MainActor [weak self] in
                self?.heartRate = bpm
                self?.heartRateSampledAt = newest.endDate
            }
        }

        let query = HKAnchoredObjectQuery(
            type: HKQuantityType(.heartRate),
            predicate: HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-3600), end: nil),
            anchor: nil,
            limit: HKObjectQueryNoLimit,
            resultsHandler: handler
        )
        query.updateHandler = handler
        streamQuery = query
        store.execute(query)
    }

    func stopHeartRateStream() {
        guard let streamQuery else { return }
        store.stop(streamQuery)
        self.streamQuery = nil
    }

    // MARK: - Queries

    private func latest(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        await latestWithDate(id, unit: unit)?.value
    }

    private func latestWithDate(
        _ id: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async -> (value: Double, date: Date)? {
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKQuantityType(id),
                predicate: nil,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: (sample.quantity.doubleValue(for: unit), sample.endDate))
            }
            store.execute(query)
        }
    }

    private func sumToday(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        await sum(id, unit: unit, since: Date.cal.startOfDay(for: Date()))
    }

    private func sum(_ id: HKQuantityTypeIdentifier, unit: HKUnit, since: Date) async -> Double? {
        await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: HKQuantityType(id),
                quantitySamplePredicate: HKQuery.predicateForSamples(withStart: since, end: nil),
                options: .cumulativeSum
            ) { _, statistics, _ in
                continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }
}

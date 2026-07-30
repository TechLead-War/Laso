import Foundation
import MetricKit
import OSLog

/// Performance telemetry. Two pieces, both meant to ship in Release:
/// signposts for Instruments traces on a build identical to the shipped one,
/// and MetricKit for the numbers only real devices in the field can give.
///
/// The signposts are deliberately not wrapped in `#if DEBUG`. A signpost costs
/// a few nanoseconds when no tracing tool is attached, and a Debug-only
/// signpost cannot profile the binary users actually run.
enum Perf {

    static let signposter = OSSignposter(subsystem: "com.lasohealth.fit", category: "perf")

    // The five intervals worth tracing, and no more. Instruments groups
    // intervals by name, so a renamed interval reads as a brand new one with no
    // history — treat these strings as stable.

    /// `AppDelegate.application(_:didFinishLaunchingWithOptions:)`.
    static let launchDidFinishLaunching: StaticString = "launch.didFinishLaunching"

    /// `AppContainer.init`.
    static let launchContainerInit: StaticString = "launch.containerInit"

    /// `ContentView.init` — everything here happens before the first frame.
    static let launchContentViewInit: StaticString = "launch.contentViewInit"

    /// The main-actor work a dashboard refresh does end to end.
    static let refreshMainActorBlocks: StaticString = "refresh.mainActorBlocks"

    /// `HealthKitManager.loadAndSync`, query through persistence.
    static let syncLoadAndSync: StaticString = "sync.loadAndSync"

    /// Opens an interval. Pair every call with `end`, normally via `defer`.
    static func begin(_ name: StaticString) -> OSSignpostIntervalState {
        signposter.beginInterval(name)
    }

    /// Closes an interval. `name` must match the one passed to `begin`.
    static func end(_ name: StaticString, _ state: OSSignpostIntervalState) {
        signposter.endInterval(name, state)
    }

    /// Starts collecting MetricKit payloads. Call once, from `didFinishLaunching`.
    static func startFieldMetrics() {
        MXMetricManager.shared.add(PerfFieldMetrics.shared)
    }
}

/// Receives MetricKit's daily payloads and forwards the two field numbers the
/// app has no other way to see: how long real devices hang, and how long they
/// take to draw their first frame. Call stacks are not forwarded — they are
/// megabytes of JSON that Amplitude would truncate, and Xcode Organizer already
/// shows them symbolicated for free. What Organizer cannot do is trend the
/// numbers per release next to the rest of the product analytics.
///
/// `@unchecked Sendable`: MetricKit invokes these callbacks on a background
/// queue. The class holds no mutable state, so there is nothing to protect; it
/// cannot be plain `Sendable` because `NSObject` is not.
private final class PerfFieldMetrics: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {

    static let shared = PerfFieldMetrics()

    private override init() {}

    // MARK: - Diagnostics (hangs, slow launches)

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            for hang in payload.hangDiagnostics ?? [] {
                report(context: "metrickit_hang", seconds: hang.hangDuration.converted(to: .seconds).value)
            }
            for launch in payload.appLaunchDiagnostics ?? [] {
                report(context: "metrickit_slow_launch", seconds: launch.launchDuration.converted(to: .seconds).value)
            }
        }
    }

    private func report(context: String, seconds: Double) {
        AnalyticsBackend.provider.captureError(
            context,
            context: context,
            metadata: ["duration_ms": (seconds * 1000).rounded()]
        )
    }

    // MARK: - Metrics (time to first draw)

    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            guard let histogram = payload.applicationLaunchMetrics?.histogrammedTimeToFirstDraw else { continue }
            let buckets = Self.buckets(of: histogram)
            let total = buckets.reduce(0) { $0 + $1.count }
            guard total > 0 else { continue }

            AnalyticsBackend.provider.captureError(
                "metrickit_time_to_first_draw",
                context: "metrickit_time_to_first_draw",
                metadata: [
                    "launch_count": total,
                    "ttfd_p50_ms": Self.quantile(0.5, buckets, total),
                    "ttfd_p95_ms": Self.quantile(0.95, buckets, total)
                ]
            )
        }
    }

    /// Bucket upper edges in milliseconds with their sample counts, in the
    /// ascending order MetricKit vends them.
    private static func buckets(of histogram: MXHistogram<UnitDuration>) -> [(ms: Double, count: Int)] {
        var result: [(ms: Double, count: Int)] = []
        for case let bucket as MXHistogramBucket<UnitDuration> in histogram.bucketEnumerator {
            let end = bucket.bucketEnd.converted(to: .milliseconds).value
            result.append((ms: end, count: bucket.bucketCount))
        }
        return result
    }

    /// Upper edge of the bucket the quantile lands in. MetricKit vends no raw
    /// samples, so this is bucket resolution, not an exact percentile — good
    /// enough to trend release over release, not to quote to three digits.
    private static func quantile(_ q: Double, _ buckets: [(ms: Double, count: Int)], _ total: Int) -> Double {
        let target = Double(total) * q
        var seen = 0
        for bucket in buckets {
            seen += bucket.count
            if Double(seen) >= target { return bucket.ms }
        }
        return buckets.last?.ms ?? 0
    }
}

import Foundation

typealias HeartRatePoint = (date: Date, value: Double)

struct LiveHeartRateTimelineReducer {
    struct PendingUpdate {
        let merged: [HeartRatePoint]
        let latestValue: Double
        let latestTimestamp: Date
    }

    struct SessionStats: Equatable {
        let minimum: Double?
        let maximum: Double?
        let average: Double?
    }

    let bucketSize: TimeInterval
    let retentionWindow: TimeInterval
    let maxPoints: Int

    init(
        bucketSize: TimeInterval = 10,
        retentionWindow: TimeInterval = 30 * 60,
        maxPoints: Int = 180
    ) {
        self.bucketSize = bucketSize
        self.retentionWindow = retentionWindow
        self.maxPoints = maxPoints
    }

    func reduce(
        existing: [HeartRatePoint],
        incoming: [HeartRatePoint],
        latestSample: HeartRatePoint,
        now: Date
    ) -> PendingUpdate {
        let bucketedPoints = bucket(points: incoming)
        let merged = merge(existing: existing, incoming: bucketedPoints, now: now)
        return PendingUpdate(
            merged: merged,
            latestValue: latestSample.value,
            latestTimestamp: latestSample.date
        )
    }

    func sessionStats(for points: [HeartRatePoint]) -> SessionStats {
        guard !points.isEmpty else {
            return SessionStats(minimum: nil, maximum: nil, average: nil)
        }

        var minValue = Double.greatestFiniteMagnitude
        var maxValue = -Double.greatestFiniteMagnitude
        var sum = 0.0

        for point in points {
            minValue = min(minValue, point.value)
            maxValue = max(maxValue, point.value)
            sum += point.value
        }

        return SessionStats(
            minimum: minValue,
            maximum: maxValue,
            average: sum / Double(points.count)
        )
    }

    private func bucket(points: [HeartRatePoint]) -> [HeartRatePoint] {
        guard !points.isEmpty else { return [] }

        var bucketedPoints: [HeartRatePoint] = []
        bucketedPoints.reserveCapacity(points.count)

        for point in points {
            let bucketedDate = bucketDate(point.date)
            if let last = bucketedPoints.last, last.date == bucketedDate {
                bucketedPoints[bucketedPoints.count - 1] = (date: bucketedDate, value: point.value)
            } else {
                bucketedPoints.append((date: bucketedDate, value: point.value))
            }
        }

        return bucketedPoints
    }

    private func merge(
        existing: [HeartRatePoint],
        incoming: [HeartRatePoint],
        now: Date
    ) -> [HeartRatePoint] {
        var merged = existing
        merged.reserveCapacity(existing.count + incoming.count)

        for point in incoming {
            if let last = merged.last, last.date == point.date {
                merged[merged.count - 1] = point
            } else {
                merged.append(point)
            }
        }

        let cutoff = now.addingTimeInterval(-retentionWindow)
        if let firstKeptIndex = merged.firstIndex(where: { $0.date >= cutoff }) {
            if firstKeptIndex > 0 {
                merged.removeFirst(firstKeptIndex)
            }
        } else {
            merged.removeAll()
        }

        if merged.count > maxPoints {
            merged.removeFirst(merged.count - maxPoints)
        }

        return merged
    }

    private func bucketDate(_ date: Date) -> Date {
        let time = date.timeIntervalSince1970
        return Date(timeIntervalSince1970: floor(time / bucketSize) * bucketSize)
    }
}

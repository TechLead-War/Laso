import Foundation

/// Compact, action-led tail strings for an out-of-range metric.
/// Replaces the previous `if metric.contains("hrv") ...` ladder so the
/// classification happens once and tails stay specific (Airship/OneSignal
/// 2026: vague "Worth a look" filler underperforms concrete actions).
enum MetricCue {
    case hrv, heartRate, bloodOxygen, respiratory, sleep, activity, other

    static func from(rawMetric: String) -> MetricCue {
        let key = rawMetric.lowercased()
        // HRV must precede heart rate. "heart rate variability" contains "heart rate".
        if key.contains("hrv") || key.contains("variability") { return .hrv }
        if key.contains("heart rate") || key.contains("resting") { return .heartRate }
        if key.contains("oxygen") || key.contains("spo2") { return .bloodOxygen }
        if key.contains("breath") || key.contains("respiratory") { return .respiratory }
        if key.contains("sleep") { return .sleep }
        if key.contains("steps") || key.contains("activity") { return .activity }
        return .other
    }

    /// Concrete short tail. No "Worth a look" filler. Airship 2026 flags it as
    /// the lowest performing CTA pattern in health-and-fitness pushes.
    func tail(isAbove: Bool) -> String {
        switch self {
        case .hrv:          return isAbove ? Copy.Notifications.cueHRVAbove : Copy.Notifications.cueHRVBelow
        case .heartRate:    return isAbove ? Copy.Notifications.cueHeartRateAbove : Copy.Notifications.cueHeartRateBelow
        case .bloodOxygen:  return Copy.Notifications.cueBloodOxygen
        case .respiratory:  return isAbove ? Copy.Notifications.cueRespiratoryAbove : Copy.Notifications.cueRespiratoryBelow
        case .sleep:        return Copy.Notifications.cueSleep
        case .activity:     return Copy.Notifications.cueActivity
        case .other:        return Copy.Notifications.cueOther
        }
    }
}

import Foundation

// MARK: - Receptivity Estimator

/// Estimates user receptivity for nudge/recommendation delivery timing.
/// Based on JITAI research (Frontiers in Digital Health 2025): effective interventions
/// require detecting vulnerability AND receptivity states before delivering.
///
/// Receptivity signals:
/// - Chronotype alignment (is it the right time of day for this user?)
/// - Stress level (low-moderate stress = more receptive)
/// - Recent app engagement (engaged users are more receptive)
/// - Context appropriateness (not mid-workout, not sleeping)
/// - Notification fatigue (diminishing returns on frequent nudges)
final class ReceptivityEstimator {

    // MARK: - Types

    struct ReceptivityAssessment {
        /// Overall receptivity probability (0-1)
        let receptivityScore: Double
        /// Whether the user is likely receptive right now
        let isReceptive: Bool
        /// Optimal delivery window for today
        let optimalWindow: OptimalWindow?
        /// Factors contributing to the assessment
        let factors: [ReceptivityFactor]
        /// Recommended delay if not currently receptive
        let suggestedDelay: TimeInterval?

        var isHighlyReceptive: Bool { receptivityScore > 0.75 }
    }

    struct OptimalWindow {
        let startHour: Int
        let endHour: Int
        let confidence: Double

        var description: String {
            let startStr = formatHour(startHour)
            let endStr = formatHour(endHour)
            return "\(startStr) - \(endStr)"
        }

        private func formatHour(_ hour: Int) -> String {
            let h = hour % 12 == 0 ? 12 : hour % 12
            let ampm = hour < 12 ? "AM" : "PM"
            return "\(h) \(ampm)"
        }
    }

    struct ReceptivityFactor {
        let name: String
        let score: Double  // 0-1
        let weight: Double
        let reason: String
    }

    // MARK: - Configuration

    /// Minimum receptivity to consider delivering a nudge
    private static let receptivityThreshold: Double = 0.45

    /// Hours since last nudge before allowing another
    private static let nudgeCooldownHours: Double = 8.0

    /// Time windows considered inappropriate for nudges
    private static let quietHoursStart = 22  // 10 PM
    private static let quietHoursEnd = 7     // 7 AM

    // MARK: - Core Assessment

    /// Assess current receptivity given all available signals.
    func assess(
        currentHour: Int = Calendar.current.component(.hour, from: Date()),
        currentHRV: Double? = nil,
        recentStressLevel: Double? = nil,
        lastAppOpenDate: Date? = nil,
        lastNudgeDate: Date? = nil,
        isWorkoutActive: Bool = false,
        chronotype: Chronotype = .intermediate,
        notificationsSentToday: Int = 0,
        daysSinceInstall: Int = 0
    ) -> ReceptivityAssessment {

        var factors: [ReceptivityFactor] = []

        // 1. Time-of-day alignment with chronotype
        let chronoScore = chronotypeAlignment(hour: currentHour, chronotype: chronotype)
        factors.append(ReceptivityFactor(
            name: "Chronotype Alignment",
            score: chronoScore,
            weight: 0.25,
            reason: chronoScore > 0.6 ? "Good time for your chronotype" : "Suboptimal time for your rhythm"
        ))

        // 2. Stress/HRV signal (low-moderate stress = more receptive)
        let stressScore: Double
        if let hrv = currentHRV {
            // Higher HRV = calmer = more receptive
            stressScore = min(1.0, max(0, hrv / 80.0))  // normalized around 80ms baseline
        } else if let stress = recentStressLevel {
            stressScore = max(0, 1.0 - stress)  // inverse of stress (0-1)
        } else {
            stressScore = 0.5  // neutral when unknown
        }
        factors.append(ReceptivityFactor(
            name: "Physiological State",
            score: stressScore,
            weight: 0.20,
            reason: stressScore > 0.6 ? "Relaxed state detected" : "Elevated stress — not ideal timing"
        ))

        // 3. App engagement recency
        let engagementScore: Double
        if let lastOpen = lastAppOpenDate {
            let hoursSinceOpen = Date().timeIntervalSince(lastOpen) / 3600
            if hoursSinceOpen < 1 { engagementScore = 1.0 }
            else if hoursSinceOpen < 4 { engagementScore = 0.8 }
            else if hoursSinceOpen < 12 { engagementScore = 0.5 }
            else { engagementScore = 0.3 }
        } else {
            engagementScore = 0.4
        }
        factors.append(ReceptivityFactor(
            name: "App Engagement",
            score: engagementScore,
            weight: 0.15,
            reason: engagementScore > 0.7 ? "Recently active in app" : "Not recently engaged"
        ))

        // 4. Context appropriateness
        var contextScore = 1.0
        if isWorkoutActive {
            contextScore = 0.05  // almost never interrupt a workout
        }
        if currentHour >= Self.quietHoursStart || currentHour < Self.quietHoursEnd {
            contextScore = min(contextScore, 0.1)  // quiet hours
        }
        factors.append(ReceptivityFactor(
            name: "Context",
            score: contextScore,
            weight: 0.25,
            reason: contextScore > 0.5 ? "Appropriate context" : "Inappropriate timing (quiet hours or workout)"
        ))

        // 5. Notification fatigue
        let fatigueScore: Double
        if let lastNudge = lastNudgeDate {
            let hoursSinceNudge = Date().timeIntervalSince(lastNudge) / 3600
            if hoursSinceNudge < Self.nudgeCooldownHours {
                fatigueScore = hoursSinceNudge / Self.nudgeCooldownHours * 0.5
            } else {
                fatigueScore = min(1.0, 0.5 + (hoursSinceNudge - Self.nudgeCooldownHours) / 24.0 * 0.5)
            }
        } else {
            fatigueScore = 1.0  // never been nudged
        }
        // Penalize multiple notifications in a day
        let dailyFatiguePenalty = max(0, 1.0 - Double(notificationsSentToday) * 0.25)
        let adjustedFatigueScore = fatigueScore * dailyFatiguePenalty
        factors.append(ReceptivityFactor(
            name: "Notification Fatigue",
            score: adjustedFatigueScore,
            weight: 0.15,
            reason: adjustedFatigueScore > 0.5 ? "Fresh — not over-notified" : "Recent notifications may reduce receptivity"
        ))

        // Weighted sum
        let totalScore = factors.reduce(0.0) { $0 + $1.score * $1.weight }
        let isReceptive = totalScore >= Self.receptivityThreshold && contextScore > 0.1

        // Compute optimal window
        let optimalWindow = computeOptimalWindow(chronotype: chronotype)

        // Suggested delay if not receptive
        let suggestedDelay: TimeInterval?
        if !isReceptive {
            if contextScore <= 0.1 {
                // During quiet hours, delay until morning
                let hoursUntilMorning = currentHour >= Self.quietHoursStart
                    ? Double(24 - currentHour + Self.quietHoursEnd)
                    : Double(Self.quietHoursEnd - currentHour)
                suggestedDelay = hoursUntilMorning * 3600
            } else {
                suggestedDelay = Self.nudgeCooldownHours * 3600  // default cooldown
            }
        } else {
            suggestedDelay = nil
        }

        return ReceptivityAssessment(
            receptivityScore: totalScore,
            isReceptive: isReceptive,
            optimalWindow: optimalWindow,
            factors: factors,
            suggestedDelay: suggestedDelay
        )
    }

    // MARK: - Chronotype

    enum Chronotype: String, Codable {
        case earlyBird     // morning person
        case intermediate  // neither
        case nightOwl      // evening person

        /// Peak cognitive/receptivity hours
        var peakHours: ClosedRange<Int> {
            switch self {
            case .earlyBird: return 8...12
            case .intermediate: return 9...13
            case .nightOwl: return 10...14
            }
        }

        /// Secondary good window (evening wind-down)
        var eveningWindow: ClosedRange<Int> {
            switch self {
            case .earlyBird: return 17...19
            case .intermediate: return 18...20
            case .nightOwl: return 19...21
            }
        }
    }

    // MARK: - Private Helpers

    private func chronotypeAlignment(hour: Int, chronotype: Chronotype) -> Double {
        if chronotype.peakHours.contains(hour) {
            return 1.0
        } else if chronotype.eveningWindow.contains(hour) {
            return 0.7
        } else if hour >= Self.quietHoursStart || hour < Self.quietHoursEnd {
            return 0.05
        } else {
            // Gradual falloff from peak hours
            let peakMid = (chronotype.peakHours.lowerBound + chronotype.peakHours.upperBound) / 2
            let distance = abs(hour - peakMid)
            return max(0.2, 1.0 - Double(distance) * 0.12)
        }
    }

    private func computeOptimalWindow(chronotype: Chronotype) -> OptimalWindow {
        OptimalWindow(
            startHour: chronotype.peakHours.lowerBound,
            endHour: chronotype.peakHours.upperBound,
            confidence: 0.8
        )
    }
}

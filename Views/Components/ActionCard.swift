import SwiftUI

/// Prescriptive action card for the Home screen.
///
/// Format: **bold action** -> supporting reason -> expected benefit.
/// Language is direct, body-focused, and jargon-free.
struct ActionCard: View {
    let insight: Insight
    let onTap: () -> Void

    private var categoryColor: Color {
        insight.metric.category.color
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Left accent bar
                RoundedRectangle(cornerRadius: DS.accentRadius)
                    .fill(categoryColor)
                    .frame(width: 4)
                    .padding(.vertical, 6)

                HStack(spacing: 12) {
                    // Metric icon in colored circle
                    Image(systemName: insight.metric.systemImageName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: DS.iconSize, height: DS.iconSize)
                        .background(categoryColor, in: Circle())

                    // Prescriptive content: action -> reason -> benefit
                    VStack(alignment: .leading, spacing: 6) {
                        // Bold prescriptive action
                        Text(prescriptiveAction)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        // Supporting reason in plain language
                        Text(supportingReason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        // Expected benefit + tap hint
                        HStack(spacing: 6) {
                            Text(expectedBenefit)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(categoryColor)
                                .lineLimit(1)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.leading, DS.accentLeading)
                .padding(.trailing, DS.accentTrailing)
                .padding(.vertical, DS.accentVertical)
            }
            .cardStyle(tint: categoryColor)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(prescriptiveAction), \(supportingReason)")
        .accessibilityValue(expectedBenefit)
        .accessibilityHint("Tap for details")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Prescriptive Language

    /// Bold, direct action -- no hedging ("Do X" not "You might consider X")
    private var prescriptiveAction: String {
        let action = extractAction(from: insight.recommendation)

        // Strip metric jargon and make body-focused
        return action
            .replacingOccurrences(of: "HRV", with: "recovery")
            .replacingOccurrences(of: "heart rate variability", with: "recovery")
            .replacingOccurrences(of: "resting heart rate", with: "resting pulse")
            .replacingOccurrences(of: "VO2 max", with: "cardio fitness")
    }

    /// Plain-language reason tied to the body, not metrics
    private var supportingReason: String {
        let devPct = Int(abs(insight.deviationPercent))

        if insight.severity == .critical {
            if insight.trend == .declining {
                return "Your body has been under strain -- this has been dropping fast"
            }
            return "Your body needs attention here -- this is well outside your normal range"
        }

        if insight.trend == .declining && devPct > 10 {
            return "Your body is showing signs of decline -- down \(devPct)% from your normal"
        }

        if devPct > 15 {
            let direction = insight.deviationPercent < 0 ? "below" : "above"
            return bodyFocusedReason(direction: direction, devPct: devPct)
        }

        if insight.trend == .declining {
            return "This has been trending down -- acting now prevents a bigger dip"
        }

        return "Your body responds well when you stay on top of this"
    }

    /// Concrete expected benefit -- quantified when possible
    private var expectedBenefit: String {
        let timeframe = benefitTimeframe
        let devPct = Int(abs(insight.deviationPercent))

        if devPct > 20 {
            let recoveryPct = min(devPct, Int(Double(devPct) * 0.4))
            return "Expected: +\(recoveryPct)% recovery \(timeframe)"
        }

        if insight.severity == .critical {
            return "Expected: noticeable improvement \(timeframe)"
        }

        if insight.trend == .declining {
            return "Expected: stop the decline \(timeframe)"
        }

        return "Expected: maintain your baseline \(timeframe)"
    }

    // MARK: - Helpers

    /// Extract the first actionable sentence from the recommendation
    private func extractAction(from recommendation: String) -> String {
        var searchStart = recommendation.startIndex
        while searchStart < recommendation.endIndex {
            guard let dotIndex = recommendation[searchStart...].firstIndex(of: ".") else { break }
            let beforeDot = recommendation[searchStart..<dotIndex]
            // Skip numeric prefixes like "1." or "2."
            if beforeDot.trimmingCharacters(in: .whitespaces).allSatisfy(\.isNumber) {
                searchStart = recommendation.index(after: dotIndex)
                continue
            }
            return String(recommendation[recommendation.startIndex...dotIndex])
        }
        return recommendation
    }

    /// Generate a body-focused reason without metric jargon
    private func bodyFocusedReason(direction: String, devPct: Int) -> String {
        switch insight.metric.category {
        case .sleep:
            return "Your body is running a sleep deficit -- \(devPct)% \(direction) your usual"
        case .heart:
            return "Your cardiovascular recovery is off -- \(devPct)% \(direction) your normal"
        case .activity:
            return "Your activity level is \(devPct)% \(direction) where your body does best"
        case .body:
            return "This is \(devPct)% \(direction) your personal baseline"
        case .respiratory:
            return "Your breathing patterns are \(devPct)% \(direction) your normal"
        case .mindfulness:
            return "Your stress recovery is lagging -- \(devPct)% \(direction) baseline"
        case .mobility:
            return "Your movement quality is \(devPct)% \(direction) your usual"
        case .nutrition:
            return "Your intake is \(devPct)% \(direction) what works best for you"
        }
    }

    /// Benefit timeframe based on the metric category
    private var benefitTimeframe: String {
        switch insight.metric.category {
        case .sleep:
            return "tomorrow"
        case .heart:
            return "within 2 days"
        case .activity:
            return "today"
        case .body:
            return "this week"
        case .respiratory:
            return "within 2 days"
        case .mindfulness:
            return "today"
        case .mobility:
            return "this week"
        case .nutrition:
            return "today"
        }
    }
}

/// Inline badge showing deviation percentage from baseline
struct DeviationBadge: View {
    let percent: Double

    var body: some View {
        let arrow = percent >= 0 ? "↑" : "↓"
        let formatted = String(format: "%.0f%%", abs(percent))

        Text("\(arrow)\(formatted)")
            .font(.caption2.weight(.bold))
            .foregroundStyle(percent >= 0 ? .red : .blue)
            .padding(.horizontal, DS.badgeH)
            .padding(.vertical, DS.badgeV)
            .background(
                (percent >= 0 ? Color.red : Color.blue).opacity(0.1),
                in: Capsule()
            )
    }
}

#Preview {
    let insights = SampleDataProvider.generateSampleInsights()
    ScrollView {
        VStack(spacing: 10) {
            ForEach(insights.prefix(3)) { insight in
                ActionCard(insight: insight, onTap: {})
                    .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}

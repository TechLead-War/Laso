import SwiftUI

/// Daily focus actions from your coach — 3 concrete things to do today.
/// For new users (<7 days), shows a living summary of what we've learned so far
/// plus a roadmap of upcoming feature unlocks.
struct CoachGoalsSection: View {
    let goals: [DashboardViewModel.CoachGoal]
    let daysOfData: Int
    let timeSeries: [HealthMetric: MetricTimeSeries]
    let onTapGoal: (HealthMetric) -> Void

    var body: some View {
        if daysOfData < 7 {
            earlyDaysSection
        } else if !goals.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Your Focus Today")
                    .font(.headline)
                    .padding(.horizontal)

                ForEach(goals.prefix(2)) { goal in
                    Button {
                        onTapGoal(goal.metric)
                    } label: {
                        goalCard(goal)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Early Days (< 7 days of data)

    private var earlyDaysSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What We Know So Far")
                .font(.headline)
                .padding(.horizontal)

            // Living summary — show real metrics we've collected
            if !snapshots.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(snapshots.enumerated()), id: \.offset) { index, snapshot in
                        snapshotRow(snapshot)
                        if index < snapshots.count - 1 {
                            Divider().padding(.leading, 50)
                        }
                    }
                }
                .padding(.vertical, 8)
                .cardStyle()
                .padding(.horizontal)
            }

            // Roadmap — what's coming next
            roadmapCard
        }
    }

    // MARK: - Metric Snapshots

    private struct MetricSnapshot: Identifiable {
        let id = UUID()
        let icon: String
        let color: Color
        let label: String
        let value: String
    }

    private var snapshots: [MetricSnapshot] {
        var result: [MetricSnapshot] = []

        // Sleep
        if let sleep = timeSeries[.sleepDuration]?.latestValue, sleep > 0 {
            let hrs = Int(sleep)
            let mins = Int((sleep - Double(hrs)) * 60)
            var detail = "\(hrs)h \(mins)m"
            if let deep = timeSeries[.sleepDeep]?.latestValue, deep > 0 {
                let dh = Int(deep)
                let dm = Int((deep - Double(dh)) * 60)
                detail += " · \(dh)h \(dm)m deep"
            }
            result.append(MetricSnapshot(icon: "bed.double.fill", color: .indigo, label: "Last Night", value: detail))
        }

        // Resting Heart Rate
        if let rhr = timeSeries[.restingHeartRate]?.latestValue {
            let context = rhrContext(rhr)
            result.append(MetricSnapshot(icon: "heart.fill", color: .red, label: "Resting HR", value: "\(Int(rhr)) bpm · \(context)"))
        }

        // HRV
        if let hrv = timeSeries[.heartRateVariability]?.latestValue {
            result.append(MetricSnapshot(icon: "waveform.path.ecg", color: .green, label: "HRV", value: "\(Int(hrv)) ms"))
        }

        // Steps
        if let steps = timeSeries[.steps]?.latestValue, steps > 0 {
            result.append(MetricSnapshot(icon: "figure.walk", color: .orange, label: "Steps", value: formatSteps(Int(steps))))
        }

        // VO2 Max
        if let vo2 = timeSeries[.vo2Max]?.latestValue {
            let context = vo2Context(vo2)
            result.append(MetricSnapshot(icon: "lungs.fill", color: .cyan, label: "VO2 Max", value: String(format: "%.1f · %@", vo2, context)))
        }

        return Array(result.prefix(4))
    }

    private func snapshotRow(_ snapshot: MetricSnapshot) -> some View {
        HStack(spacing: 12) {
            Image(systemName: snapshot.icon)
                .font(.subheadline)
                .foregroundStyle(snapshot.color)
                .frame(width: DS.iconSize, height: DS.iconSize)
                .background(snapshot.color.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.iconRadius))

            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(snapshot.value)
                    .font(.subheadline.weight(.medium))
            }

            Spacer()
        }
        .padding(.horizontal, DS.cardPadding)
        .padding(.vertical, 6)
    }

    // MARK: - Population Context

    private func rhrContext(_ bpm: Double) -> String {
        switch bpm {
        case ..<60: return "Athletic"
        case 60..<70: return "Healthy"
        case 70..<80: return "Average"
        case 80..<90: return "Above average"
        default: return "Elevated"
        }
    }

    private func vo2Context(_ vo2: Double) -> String {
        switch vo2 {
        case 50...: return "Excellent"
        case 40..<50: return "Good"
        case 30..<40: return "Average"
        case 20..<30: return "Below average"
        default: return "Low"
        }
    }

    private func formatSteps(_ steps: Int) -> String {
        if steps >= 1000 {
            let k = Double(steps) / 1000.0
            return String(format: "%.1fK", k)
        }
        return "\(steps)"
    }

    // MARK: - Unlock Roadmap

    private var roadmapCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                Text("Coming Soon")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 6) {
                roadmapRow(day: 7, label: "Personalized daily goals", unlocked: daysOfData >= 7)
                roadmapRow(day: 14, label: "Trend detection & alerts", unlocked: daysOfData >= 14)
                roadmapRow(day: 30, label: "Correlations & pattern discovery", unlocked: daysOfData >= 30)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 4)
                    Capsule()
                        .fill(.orange.gradient)
                        .frame(width: geo.size.width * progressFraction, height: 4)
                }
            }
            .frame(height: 4)
            .padding(.top, 2)

            Text("Day \(daysOfData) of 7")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(DS.cardPadding)
        .cardStyle(tint: .orange)
        .padding(.horizontal)
    }

    private var progressFraction: Double {
        min(1.0, Double(daysOfData) / 7.0)
    }

    private func roadmapRow(day: Int, label: String, unlocked: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: unlocked ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundStyle(unlocked ? .green : .secondary)
            Text(label)
                .font(.caption)
                .foregroundStyle(unlocked ? .primary : .secondary)
            Spacer()
            Text("Day \(day)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Goal Card (7+ days)

    private func goalCard(_ goal: DashboardViewModel.CoachGoal) -> some View {
        HStack(spacing: 12) {
            Image(systemName: goal.metric.systemImageName)
                .font(.title3)
                .foregroundStyle(goal.metric.category.color)
                .frame(width: DS.iconSize, height: DS.iconSize)
                .background(goal.metric.category.color.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.iconRadius))

            VStack(alignment: .leading, spacing: 3) {
                Text(goal.action)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(goal.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }
}

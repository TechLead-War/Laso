import SwiftUI

struct LiveActivitySection: View {
    let activity: LiveViewModel.ActivityData
    var activityTracker: SectionTracker
    var quickStatsTracker: SectionTracker
    @Binding var maxScrollDepth: Int

    private var isActivityAllZeros: Bool {
        activity.todayActiveCalories == 0 && activity.todayExerciseMinutes == 0 && activity.todayStandHours == 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity Rings")
                .font(.headline)
                .padding(.horizontal)

            if isActivityAllZeros && Calendar.current.component(.hour, from: Date()) < 10 {
                HStack(spacing: 12) {
                    Image(systemName: "figure.stand")
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("No activity yet")
                            .font(.subheadline.weight(.medium))
                        Text("Your rings will fill as you move throughout the day.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(DS.cardPadding)
                .cardStyle()
                .padding(.horizontal)
            } else {

            HStack(spacing: 16) {
                // Triple ring
                ZStack {
                    // Stand (outer). cyan
                    ringArc(progress: activity.standProgress, color: .cyan, size: 90, lineWidth: 8)
                    // Exercise (middle). green
                    ringArc(progress: activity.exerciseProgress, color: .green, size: 70, lineWidth: 8)
                    // Move (inner). pink
                    ringArc(progress: activity.moveProgress, color: .pink, size: 50, lineWidth: 8)
                }
                .frame(width: 100, height: 100)

                // Labels
                VStack(alignment: .leading, spacing: 10) {
                    ringLabel(
                        color: .pink,
                        label: "Move",
                        value: "\(Int(activity.todayActiveCalories))/\(Int(activity.moveGoal)) kcal",
                        progress: activity.moveProgress
                    )
                    ringLabel(
                        color: .green,
                        label: "Exercise",
                        value: "\(Int(activity.todayExerciseMinutes))/\(Int(activity.exerciseGoal)) min",
                        progress: activity.exerciseProgress
                    )
                    ringLabel(
                        color: .cyan,
                        label: "Stand",
                        value: "\(Int(activity.todayStandHours))/\(Int(activity.standGoal)) hrs",
                        progress: activity.standProgress
                    )
                }

                Spacer()
            }
            .padding(DS.cardPadding)
            .cardStyle()
            .padding(.horizontal)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Activity rings. Move: \(Int(activity.todayActiveCalories)) of \(Int(activity.moveGoal)) calories, \(Int(activity.moveProgress * 100)) percent. Exercise: \(Int(activity.todayExerciseMinutes)) of \(Int(activity.exerciseGoal)) minutes, \(Int(activity.exerciseProgress * 100)) percent. Stand: \(Int(activity.todayStandHours)) of \(Int(activity.standGoal)) hours, \(Int(activity.standProgress * 100)) percent.")
            .onTapGesture {
                AppAnalytics.shared.trackBlockTap(
                    title: "Activity Rings",
                    type: .activityRingsSection,
                    screen: .live,
                    metadata: [
                        "metric_id": "activity_rings",
                        "move_progress": Int(activity.moveProgress * 100),
                        "exercise_progress": Int(activity.exerciseProgress * 100),
                        "stand_progress": Int(activity.standProgress * 100)
                    ]
                )
                activityTracker.tapped(target: "activity_rings")
            }

            // Quick stats row
            HStack(spacing: 12) {
                quickStatPill(
                    icon: "figure.walk",
                    value: formatLargeNumber(activity.todaySteps),
                    label: "Steps",
                    color: .green,
                    blockType: .quickStatSteps
                )
                quickStatPill(
                    icon: "location.fill",
                    value: String(format: "%.1f km", activity.todayDistance),
                    label: "Distance",
                    color: .blue,
                    blockType: .quickStatDistance
                )
                quickStatPill(
                    icon: "figure.stairs",
                    value: "\(Int(activity.todayFlightsClimbed))",
                    label: "Flights",
                    color: .purple,
                    blockType: .quickStatFlights
                )
            }
            .padding(.horizontal)
            .onAppear { quickStatsTracker.appeared() }
            .onDisappear { quickStatsTracker.disappeared() }

            } // end else (has activity)
        }
        .onAppear { activityTracker.appeared(); maxScrollDepth = max(maxScrollDepth, 65) }
        .onDisappear { activityTracker.disappeared() }
    }

    private func ringArc(progress: Double, color: Color, size: CGFloat, lineWidth: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)
                .frame(width: size, height: size)
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
        }
    }

    private func ringLabel(color: Color, label: String, value: String, progress: Double) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)

            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.primary)

            Spacer()

            Text("\(Int(progress * 100))%")
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
        }
    }

    private func quickStatPill(icon: String, value: String, label: String, color: Color, blockType: BlockType) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)

            Text(value)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(.primary)
                .contentTransition(.numericText())

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(DS.tintBg), in: RoundedRectangle(cornerRadius: DS.cardRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
        .onTapGesture {
            let metricId: String = switch blockType {
            case .quickStatSteps: HealthMetric.steps.rawValue
            case .quickStatDistance: HealthMetric.distanceWalkingRunning.rawValue
            case .quickStatFlights: HealthMetric.flightsClimbed.rawValue
            default: "unknown"
            }
            AppAnalytics.shared.trackBlockTap(
                title: label,
                type: blockType,
                screen: .live,
                metadata: [
                    "metric_id": metricId,
                    "value": value
                ]
            )
            quickStatsTracker.tapped(target: label.lowercased())
        }
    }

    private func formatLargeNumber(_ value: Double) -> String {
        if value >= 10000 {
            return String(format: "%.0fk", value / 1000)
        } else if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        } else {
            return String(format: "%.0f", value)
        }
    }
}

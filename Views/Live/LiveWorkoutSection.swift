import SwiftUI

struct LiveWorkoutSection: View {
    let workout: LiveViewModel.WorkoutData
    var workoutTracker: SectionTracker
    @Binding var maxScrollDepth: Int

    var body: some View {
        if let type = workout.lastWorkoutType {
            VStack(alignment: .leading, spacing: 12) {
                Text("Last Workout")
                    .font(.headline)
                    .padding(.horizontal)

                HStack(spacing: 14) {
                    // Workout icon
                    Image(systemName: "figure.run")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.green)
                        .frame(width: DS.iconSize, height: DS.iconSize)
                        .background(.green.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.iconRadius))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(type)
                            .font(.subheadline.weight(.semibold))

                        HStack(spacing: 12) {
                            if let dur = workout.lastWorkoutDuration {
                                HStack(spacing: 3) {
                                    Image(systemName: "clock")
                                        .font(.caption2)
                                    Text("\(Int(dur)) min")
                                        .font(.caption.monospacedDigit())
                                }
                                .foregroundStyle(.secondary)
                            }

                            if let cal = workout.lastWorkoutCalories {
                                HStack(spacing: 3) {
                                    Image(systemName: "flame.fill")
                                        .font(.caption2)
                                    Text("\(Int(cal)) kcal")
                                        .font(.caption.monospacedDigit())
                                }
                                .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Spacer()

                    if let ts = workout.lastWorkoutTimestamp {
                        Text(ts, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(DS.cardPadding)
                .cardStyle()
                .padding(.horizontal)
                .onTapGesture {
                    AppAnalytics.shared.trackBlockTap(
                        title: "Last Workout",
                        type: .lastWorkoutCard,
                        screen: .live,
                        metadata: [
                            "workout_type": type,
                            "duration_min": Int(workout.lastWorkoutDuration ?? 0),
                            "calories": Int(workout.lastWorkoutCalories ?? 0)
                        ]
                    )
                    workoutTracker.tapped(target: "last_workout")
                }
            }
            .onAppear { workoutTracker.appeared(); maxScrollDepth = max(maxScrollDepth, 90) }
            .onDisappear { workoutTracker.disappeared() }
        }
    }
}

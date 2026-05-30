import SwiftUI

struct LiveWorkoutSection: View {
    let workout: LiveViewModel.WorkoutData
    var workoutTracker: SectionTracker
    @Binding var maxScrollDepth: Int

    var body: some View {
        if let type = workout.lastWorkoutType {
            VStack(alignment: .leading, spacing: DS.itemSpacing) {
                Text(Copy.Live.lastWorkout)
                    .font(DS.Typography.headline)
                    .padding(.horizontal)

                Button {
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
                } label: {
                    HStack(spacing: DS.itemSpacing) {
                        // Workout icon
                        Image(systemName: "figure.run")
                            .font(DS.Typography.title2)
                            .foregroundStyle(AppColour.success)
                            .frame(width: DS.iconSize, height: DS.iconSize)
                            .background(AppColour.success.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.iconRadius))

                        VStack(alignment: .leading, spacing: DS.space1) {
                            Text(type)
                                .font(DS.Typography.subheadlineSemibold)

                            HStack(spacing: DS.itemSpacing) {
                                if let dur = workout.lastWorkoutDuration {
                                    HStack(spacing: 3) {
                                        Image(systemName: "clock")
                                            .font(DS.Typography.caption2)
                                        Text(Copy.Live.minText(Int(dur)))
                                            .font(DS.Typography.caption.monospacedDigit())
                                    }
                                    .foregroundStyle(AppColour.textSecondary)
                                }

                                if let cal = workout.lastWorkoutCalories {
                                    HStack(spacing: 3) {
                                        Image(systemName: "flame.fill")
                                            .font(DS.Typography.caption2)
                                        Text(Copy.Live.kcalText(Int(cal)))
                                            .font(DS.Typography.caption.monospacedDigit())
                                    }
                                    .foregroundStyle(AppColour.textSecondary)
                                }
                            }
                        }

                        Spacer()

                        if let ts = workout.lastWorkoutTimestamp {
                            Text(ts, style: .relative)
                                .font(DS.Typography.caption2)
                                .foregroundStyle(AppColour.textTertiary)
                        }
                    }
                    .padding(DS.cardPadding)
                    .cardStyle()
                }
                .buttonStyle(.dsPress)
                .padding(.horizontal)
            }
            .onAppear { workoutTracker.appeared(); maxScrollDepth = max(maxScrollDepth, 90) }
            .onDisappear { workoutTracker.disappeared() }
        }
    }
}

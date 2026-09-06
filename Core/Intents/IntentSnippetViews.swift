import SwiftUI

/// Rich Siri snippet views displayed inline in Siri/Shortcuts responses
enum IntentSnippetViews {

    // MARK: - Health Score Snippet

    struct ScoreSnippet: View {
        let score: Int
        let summary: String
        var readinessScore: Int? = nil

        private var scoreColor: Color {
            switch score {
            case 80...100: return AppColour.scoreOptimal
            case 60..<80: return AppColour.scoreGood
            case 40..<60: return AppColour.scoreFair
            default: return AppColour.scorePoor
            }
        }

        private var readinessColor: Color {
            switch readinessScore ?? 0 {
            case 80...100: return AppColour.scoreOptimal
            case 60..<80: return AppColour.scoreGood
            case 40..<60: return AppColour.scoreFair
            default: return AppColour.scorePoor
            }
        }

        var body: some View {
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    // Health score gauge
                    scoreGauge(
                        value: score,
                        color: scoreColor,
                        caption: "Health"
                    )

                    // Recovery gauge (if available)
                    if let readiness = readinessScore {
                        scoreGauge(
                            value: readiness,
                            color: readinessColor,
                            caption: "Recovery"
                        )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(Copy.Common.healthScore)
                            .font(DS.Typography.headline)
                        Text(summary)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
            }
            .padding()
        }

        private func scoreGauge(value: Int, color: Color, caption: String) -> some View {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(AppColour.trackNeutral, lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: Double(value) / 100.0)
                        .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(Copy.Common.xText(value))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                }
                .frame(width: 60, height: 60)
                Text(caption)
                    .font(DS.Typography.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Sleep Snippet

    struct SleepSnippet: View {
        let totalHours: Double
        let deepHours: Double
        let remHours: Double
        let qualityLabel: String

        private var qualityColor: Color {
            switch qualityLabel {
            case "Great": return AppColour.scoreOptimal
            case "Good": return AppColour.scoreGood
            case "Fair": return AppColour.scoreFair
            default: return AppColour.scorePoor
            }
        }

        var body: some View {
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    // Sleep duration bar
                    VStack(spacing: 4) {
                        Image(systemName: "bed.double.fill")
                            .font(DS.Typography.title2)
                            .foregroundStyle(AppColour.categorySleep)
                        Text(formatHours(totalHours))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        Text(qualityLabel)
                            .font(DS.Typography.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(qualityColor.opacity(0.2))
                            .foregroundStyle(qualityColor)
                            .clipShape(Capsule())
                    }
                    .frame(width: 80)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(Copy.Common.lastNightSSleep)
                            .font(DS.Typography.headline)

                        if deepHours > 0 || remHours > 0 {
                            HStack(spacing: 12) {
                                sleepStageItem(label: "Deep", hours: deepHours, color: AppColour.categorySleep)
                                sleepStageItem(label: "REM", hours: remHours, color: AppColour.accent)
                            }
                        }
                    }
                }

                // Duration bar
                if totalHours > 0 {
                    GeometryReader { geometry in
                        let targetWidth = geometry.size.width
                        let fillRatio = min(totalHours / 9.0, 1.0)
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppColour.trackNeutral)
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppColour.categorySleep)
                                .frame(width: targetWidth * fillRatio, height: 8)
                        }
                    }
                    .frame(height: 8)
                }
            }
            .padding()
        }

        private func sleepStageItem(label: String, hours: Double, color: Color) -> some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(DS.Typography.caption2)
                    .foregroundStyle(.secondary)
                Text(formatHours(hours))
                    .font(.subheadline.bold())
                    .foregroundStyle(color)
            }
        }

        private func formatHours(_ hours: Double) -> String {
            let clamped = max(0, hours)
            let h = Int(clamped)
            let m = max(0, Int((clamped - Double(h)) * 60))
            if h == 0 { return "\(m)m" }
            if m == 0 { return "\(h)h" }
            return "\(h)h \(m)m"
        }
    }

    // MARK: - Readiness Snippet

    struct ReadinessSnippet: View {
        let readinessScore: Int
        /// Nil until the personal baselines stress is scored against exist.
        /// The ring then draws empty rather than a green zero.
        let stressLevel: Int?
        let stressLabel: String

        private var readinessColor: Color {
            switch readinessScore {
            case 80...100: return AppColour.scoreOptimal
            case 60..<80: return AppColour.scoreGood
            case 40..<60: return AppColour.scoreFair
            default: return AppColour.scorePoor
            }
        }

        private var stressColor: Color {
            guard let stressLevel else { return AppColour.trackNeutral }
            switch stressLevel {
            case 0..<20: return AppColour.scoreOptimal
            case 20..<40: return AppColour.scoreGood
            case 40..<60: return AppColour.scoreFair
            default: return AppColour.scorePoor
            }
        }

        var body: some View {
            VStack(spacing: 12) {
                HStack(spacing: 20) {
                    // Readiness gauge
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .stroke(AppColour.trackNeutral, lineWidth: 6)
                            Circle()
                                .trim(from: 0, to: Double(readinessScore) / 100.0)
                                .stroke(readinessColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text(Copy.Common.intentReadinessScoreText(readinessScore))
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                        }
                        .frame(width: 64, height: 64)
                        Text(Copy.Common.readiness)
                            .font(DS.Typography.caption2)
                            .foregroundStyle(.secondary)
                    }

                    // Stress indicator
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .stroke(AppColour.trackNeutral, lineWidth: 6)
                            Circle()
                                .trim(from: 0, to: Double(stressLevel ?? 0) / 100.0)
                                .stroke(stressColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Image(systemName: "waveform.path.ecg")
                                .font(.system(size: 16))
                                .foregroundStyle(stressColor)
                        }
                        .frame(width: 64, height: 64)
                        Text(stressLabel)
                            .font(DS.Typography.caption2)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(Copy.Common.recoveryStatus)
                            .font(DS.Typography.headline)
                        Text(readinessAdvice(readinessScore))
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
            }
            .padding()
        }

        private func readinessAdvice(_ score: Int) -> String {
            switch score {
            case 80...100: return "Great day for a hard workout."
            case 60..<80: return "Good for moderate activity."
            case 40..<60: return "Light activity recommended."
            default: return "Focus on rest and recovery."
            }
        }
    }

    // MARK: - Water Logged Snippet

    struct WaterSnippet: View {
        let liters: Double

        var body: some View {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AppColour.surfaceSubtle)
                        .frame(width: 56, height: 56)
                    Image(systemName: "drop.fill")
                        .font(DS.Typography.title2)
                        .foregroundStyle(AppColour.info)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(Copy.Common.waterLogged)
                        .font(DS.Typography.headline)
                    Text("\(Int(liters * 1000)) mL (\(String(format: "%.1f", liters)) L)")
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                    Text(Copy.Common.savedToAppleHealth)
                        .font(DS.Typography.caption)
                        .foregroundStyle(AppColour.success)
                }
            }
            .padding()
        }
    }

    // MARK: - Workout Logged Snippet

    struct WorkoutSnippet: View {
        let workoutType: WorkoutTypeAppEnum
        let durationMinutes: Double

        var body: some View {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AppColour.surfaceSubtle)
                        .frame(width: 56, height: 56)
                    Image(systemName: workoutType.systemImageName)
                        .font(DS.Typography.title2)
                        .foregroundStyle(AppColour.success)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(Copy.Common.loggedText(workoutType.rawValue.capitalized))
                        .font(DS.Typography.headline)
                    Text(formatDuration(durationMinutes))
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                    Text(Copy.Common.savedToAppleHealth2)
                        .font(DS.Typography.caption)
                        .foregroundStyle(AppColour.success)
                }
            }
            .padding()
        }

        private func formatDuration(_ minutes: Double) -> String {
            if minutes < 60 {
                return "\(Int(minutes)) minutes"
            }
            let h = Int(minutes / 60)
            let m = Int(minutes.truncatingRemainder(dividingBy: 60))
            if m == 0 {
                return "\(h) hour\(h == 1 ? "" : "s")"
            }
            return "\(h)h \(m)m"
        }
    }

    // MARK: - Error Snippet

    struct ErrorSnippet: View {
        let message: String

        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(DS.Typography.title3)
                    .foregroundStyle(AppColour.warning)
                Text(message)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}

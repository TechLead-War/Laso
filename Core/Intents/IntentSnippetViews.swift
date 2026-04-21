import SwiftUI

/// Rich Siri snippet views displayed inline in Siri/Shortcuts responses
enum IntentSnippetViews {

    // MARK: - Health Score Snippet

    struct ScoreSnippet: View {
        let score: Int
        let grade: String
        let summary: String
        var readinessScore: Int? = nil
        var readinessLabel: String? = nil

        private var scoreColor: Color {
            switch score {
            case 80...100: return .green
            case 60..<80: return .yellow
            case 40..<60: return .orange
            default: return .red
            }
        }

        private var readinessColor: Color {
            switch readinessScore ?? 0 {
            case 80...100: return .green
            case 60..<80: return .blue
            case 40..<60: return .yellow
            default: return .orange
            }
        }

        var body: some View {
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    // Health score gauge
                    scoreGauge(
                        value: score,
                        label: grade,
                        color: scoreColor,
                        caption: "Health"
                    )

                    // Recovery gauge (if available)
                    if let readiness = readinessScore {
                        scoreGauge(
                            value: readiness,
                            label: readinessLabel ?? "",
                            color: readinessColor,
                            caption: "Recovery"
                        )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Health Score")
                            .font(.headline)
                        Text(summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
            }
            .padding()
        }

        private func scoreGauge(value: Int, label: String, color: Color, caption: String) -> some View {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: Double(value) / 100.0)
                        .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(value)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                }
                .frame(width: 60, height: 60)
                Text(caption)
                    .font(.caption2)
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
            case "Great": return .green
            case "Good": return .blue
            case "Fair": return .yellow
            default: return .orange
            }
        }

        var body: some View {
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    // Sleep duration bar
                    VStack(spacing: 4) {
                        Image(systemName: "bed.double.fill")
                            .font(.title2)
                            .foregroundStyle(.indigo)
                        Text(formatHours(totalHours))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        Text(qualityLabel)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(qualityColor.opacity(0.2))
                            .foregroundStyle(qualityColor)
                            .clipShape(Capsule())
                    }
                    .frame(width: 80)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last Night's Sleep")
                            .font(.headline)

                        if deepHours > 0 || remHours > 0 {
                            HStack(spacing: 12) {
                                sleepStageItem(label: "Deep", hours: deepHours, color: .indigo)
                                sleepStageItem(label: "REM", hours: remHours, color: .cyan)
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
                                .fill(Color.gray.opacity(0.15))
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.indigo)
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
                    .font(.caption2)
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
        let stressLevel: Int
        let stressLabel: String

        private var readinessColor: Color {
            switch readinessScore {
            case 80...100: return .green
            case 60..<80: return .blue
            case 40..<60: return .yellow
            default: return .orange
            }
        }

        private var stressColor: Color {
            switch stressLevel {
            case 0..<20: return .green
            case 20..<40: return .green
            case 40..<60: return .yellow
            case 60..<80: return .orange
            default: return .red
            }
        }

        var body: some View {
            VStack(spacing: 12) {
                HStack(spacing: 20) {
                    // Readiness gauge
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                            Circle()
                                .trim(from: 0, to: Double(readinessScore) / 100.0)
                                .stroke(readinessColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text("\(readinessScore)%")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                        }
                        .frame(width: 64, height: 64)
                        Text("Readiness")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    // Stress indicator
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                            Circle()
                                .trim(from: 0, to: Double(stressLevel) / 100.0)
                                .stroke(stressColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Image(systemName: "waveform.path.ecg")
                                .font(.system(size: 16))
                                .foregroundStyle(stressColor)
                        }
                        .frame(width: 64, height: 64)
                        Text(stressLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recovery Status")
                            .font(.headline)
                        Text(readinessAdvice(readinessScore))
                            .font(.subheadline)
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
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: "drop.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Water Logged")
                        .font(.headline)
                    Text("\(Int(liters * 1000)) mL (\(String(format: "%.1f", liters)) L)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Saved to Apple Health")
                        .font(.caption)
                        .foregroundStyle(.green)
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
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: workoutType.systemImageName)
                        .font(.title2)
                        .foregroundStyle(.green)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(workoutType.rawValue.capitalized) Logged")
                        .font(.headline)
                    Text(formatDuration(durationMinutes))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Saved to Apple Health")
                        .font(.caption)
                        .foregroundStyle(.green)
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
                    .font(.title3)
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}

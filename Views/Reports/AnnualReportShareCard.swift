import SwiftUI

struct ShareSheetRepresentable: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ShareableAnnualReportCard: View {
    let year: Int
    let overallScore: Int
    let totalActiveDays: Int
    let totalExerciseHours: Double
    let averageSleepHours: Double
    let streakRecord: Int

    private var scoreColor: Color {
        DS.scoreColor(overallScore)
    }

    private var gradientColors: [Color] {
        switch overallScore {
        case 80...100: return [Color(red: 0.1, green: 0.2, blue: 0.15), Color(red: 0.05, green: 0.12, blue: 0.08)]
        case 60..<80: return [Color(red: 0.2, green: 0.18, blue: 0.08), Color(red: 0.12, green: 0.1, blue: 0.04)]
        case 40..<60: return [Color(red: 0.22, green: 0.14, blue: 0.06), Color(red: 0.14, green: 0.08, blue: 0.03)]
        default: return [Color(red: 0.22, green: 0.08, blue: 0.08), Color(red: 0.14, green: 0.04, blue: 0.04)]
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                HStack {
                    Text(Copy.Labels.appName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text(Copy.Reports.yearInReview(year))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)

                Spacer()

                ZStack {
                    Circle()
                        .fill(scoreColor.opacity(0.08))
                        .frame(width: 180, height: 180)

                    Circle()
                        .stroke(scoreColor.opacity(0.2), lineWidth: 12)
                        .frame(width: 140, height: 140)

                    Circle()
                        .trim(from: 0, to: Double(overallScore) / 100.0)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 140, height: 140)

                    VStack(spacing: 2) {
                        Text("\(overallScore)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(Copy.Reports.annualScore)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                Spacer().frame(height: 24)

                HStack(spacing: 16) {
                    shareStatBadge(icon: "checkmark.circle.fill", value: "\(totalActiveDays)", label: Copy.Reports.activeDays)
                    shareStatBadge(icon: "flame.fill", value: String(format: "%.0f", totalExerciseHours), label: Copy.Reports.exerciseHrs)
                    shareStatBadge(icon: "bed.double.fill", value: String(format: "%.1f", averageSleepHours), label: Copy.Reports.avgSleep)
                }

                if streakRecord > 0 {
                    Spacer().frame(height: 16)

                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text(Copy.Reports.streakDayRecord(streakRecord))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.15), in: Capsule())
                }

                Spacer()

                Text(Copy.Reports.trackHealthWithLaso)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 28)
            }
        }
        .frame(width: 390, height: 520)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func shareStatBadge(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

import SwiftUI
import WidgetKit

struct AnalysisWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: AnalysisWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallView
            case .systemMedium:
                mediumView
            case .accessoryRectangular:
                rectangularView
            case .accessoryCircular:
                circularView
            case .accessoryInline:
                inlineView
            default:
                mediumView
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    WidgetStyle.readinessColor(score: entry.readiness.score).opacity(0.18),
                    AppColour.surfaceBase
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Readiness")
                        .font(.caption2)
                        .foregroundStyle(AppColour.textSecondary)
                    Text("\(entry.readiness.score)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetStyle.readinessColor(score: entry.readiness.score))
                }

                Spacer()

                Text(entry.readiness.grade)
                    .font(.headline.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(WidgetStyle.readinessColor(score: entry.readiness.score).opacity(0.16), in: Capsule())
            }

            Text(entry.readiness.dayType)
                .font(.headline)
                .lineLimit(1)

            Text(entry.action.headline)
                .font(.caption)
                .foregroundStyle(AppColour.textSecondary)
                .lineLimit(3)

            Spacer(minLength: 0)

            Text("Updated \(WidgetStyle.timeString(from: entry.lastUpdate))")
                .font(.caption2)
                .foregroundStyle(AppColour.textTertiary)
        }
        .padding()
    }

    private var mediumView: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(WidgetStyle.readinessColor(score: entry.readiness.score).opacity(0.18), lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: min(Double(entry.readiness.score) / 100, 1))
                            .stroke(WidgetStyle.readinessColor(score: entry.readiness.score), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 56, height: 56)
                    .overlay {
                        Text("\(entry.readiness.score)")
                            .font(.headline.weight(.bold).monospacedDigit())
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.readiness.dayType)
                            .font(.headline)
                            .lineLimit(2)
                        Text(entry.action.headline)
                            .font(.caption)
                            .foregroundStyle(AppColour.textSecondary)
                            .lineLimit(2)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Label("\(String(format: "%.1f", entry.sleep.hoursSlept))h sleep", systemImage: "bed.double.fill")
                    Label(entry.recoveryDebt.detail, systemImage: "moon.zzz.fill")
                }
                .font(.caption)
                .foregroundStyle(AppColour.textSecondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Latest analysis")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColour.textSecondary)
                    .textCase(.uppercase)

                Text(entry.intelligence.headline)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(3)

                HStack(spacing: 6) {
                    Circle()
                        .fill(WidgetStyle.severityColor(entry.intelligence.severityRaw))
                        .frame(width: 8, height: 8)
                    Text(entry.intelligence.cardType.capitalized)
                        .font(.caption)
                        .foregroundStyle(AppColour.textSecondary)
                }

                Spacer(minLength: 0)

                Text("Updated \(WidgetStyle.timeString(from: entry.lastUpdate))")
                    .font(.caption2)
                    .foregroundStyle(AppColour.textTertiary)
            }
        }
        .padding()
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Readiness \(entry.readiness.score)")
                    .font(.headline.weight(.semibold))
                Spacer()
                Text(entry.readiness.grade)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WidgetStyle.readinessColor(score: entry.readiness.score))
            }
            Text(entry.readiness.dayType)
                .font(.caption)
                .foregroundStyle(AppColour.textSecondary)
            Text(entry.action.headline)
                .font(.caption2)
                .lineLimit(2)
        }
    }

    private var circularView: some View {
        ZStack {
            Circle()
                .stroke(WidgetStyle.readinessColor(score: entry.readiness.score).opacity(0.2), lineWidth: 7)
            Circle()
                .trim(from: 0, to: min(Double(entry.readiness.score) / 100, 1))
                .stroke(WidgetStyle.readinessColor(score: entry.readiness.score), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(entry.readiness.score)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .padding(6)
    }

    private var inlineView: some View {
        Text("Readiness \(entry.readiness.score) • \(entry.readiness.dayType)")
    }
}

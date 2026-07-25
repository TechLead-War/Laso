import SwiftUI
import WidgetKit

struct AnalysisWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: AnalysisWidgetEntry

    var body: some View {
        Group {
            if let readiness = entry.readiness {
                dataView(readiness)
            } else {
                emptyView
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    (entry.readiness.map { WidgetStyle.readinessColor(score: $0.score) } ?? AppColour.textTertiary)
                        .opacity(0.18),
                    AppColour.surfaceBase
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    @ViewBuilder
    private func dataView(_ readiness: WidgetReadinessSnapshot) -> some View {
        switch family {
        case .systemSmall:
            smallView(readiness)
        case .systemMedium:
            mediumView(readiness)
        case .accessoryRectangular:
            rectangularView(readiness)
        case .accessoryCircular:
            circularView(readiness)
        case .accessoryInline:
            inlineView(readiness)
        default:
            mediumView(readiness)
        }
    }

    // MARK: - No Data

    /// Shown before the first sync and after the user deletes their data. The
    /// accessory families have no room for a sentence, so they carry the same
    /// blank marker the watch complication uses.
    @ViewBuilder
    private var emptyView: some View {
        switch family {
        case .accessoryCircular:
            Text("--")
                .font(.system(size: 14, weight: .bold, design: .rounded))

        case .accessoryInline:
            Text("Readiness --")

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Readiness --")
                    .font(.headline.weight(.semibold))
                Text("Open Laso to sync")
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        default:
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "arrow.clockwise")
                    .font(.title3)
                    .foregroundStyle(AppColour.textSecondary)
                Text("No readings yet")
                    .font(.headline)
                Text("Open Laso to sync your latest health data.")
                    .font(.caption)
                    .foregroundStyle(AppColour.textSecondary)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding()
        }
    }

    // MARK: - With Data

    private func smallView(_ readiness: WidgetReadinessSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Readiness")
                        .font(.caption2)
                        .foregroundStyle(AppColour.textSecondary)
                    Text("\(readiness.score)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetStyle.readinessColor(score: readiness.score))
                }

                Spacer()

                Text(readiness.grade)
                    .font(.headline.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(WidgetStyle.readinessColor(score: readiness.score).opacity(0.16), in: Capsule())
            }

            if !readiness.dayType.isEmpty {
                Text(readiness.dayType)
                    .font(.headline)
                    .lineLimit(1)
            }

            if let action = entry.action {
                Text(action.headline)
                    .font(.caption)
                    .foregroundStyle(AppColour.textSecondary)
                    .lineLimit(3)
            }

            Spacer(minLength: 0)

            updatedLabel
        }
        .padding()
    }

    private func mediumView(_ readiness: WidgetReadinessSnapshot) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(WidgetStyle.readinessColor(score: readiness.score).opacity(0.18), lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: min(Double(readiness.score) / 100, 1))
                            .stroke(WidgetStyle.readinessColor(score: readiness.score), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 56, height: 56)
                    .overlay {
                        Text("\(readiness.score)")
                            .font(.headline.weight(.bold).monospacedDigit())
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        if !readiness.dayType.isEmpty {
                            Text(readiness.dayType)
                                .font(.headline)
                                .lineLimit(2)
                        }
                        if let action = entry.action {
                            Text(action.headline)
                                .font(.caption)
                                .foregroundStyle(AppColour.textSecondary)
                                .lineLimit(2)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    if let sleep = entry.sleep {
                        Label("\(String(format: "%.1f", sleep.hoursSlept))h sleep", systemImage: "bed.double.fill")
                    }
                    if let recoveryDebt = entry.recoveryDebt {
                        Label(recoveryDebt.detail, systemImage: "moon.zzz.fill")
                    }
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

                if let intelligence = entry.intelligence {
                    Text(intelligence.headline)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(3)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(WidgetStyle.severityColor(intelligence.severityRaw))
                            .frame(width: 8, height: 8)
                        Text(intelligence.cardType.capitalized)
                            .font(.caption)
                            .foregroundStyle(AppColour.textSecondary)
                    }
                } else {
                    Text("Nothing new today")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColour.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                updatedLabel
            }
        }
        .padding()
    }

    private func rectangularView(_ readiness: WidgetReadinessSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Readiness \(readiness.score)")
                    .font(.headline.weight(.semibold))
                Spacer()
                Text(readiness.grade)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WidgetStyle.readinessColor(score: readiness.score))
            }
            if !readiness.dayType.isEmpty {
                Text(readiness.dayType)
                    .font(.caption)
                    .foregroundStyle(AppColour.textSecondary)
            }
            if let action = entry.action {
                Text(action.headline)
                    .font(.caption2)
                    .lineLimit(2)
            }
        }
    }

    private func circularView(_ readiness: WidgetReadinessSnapshot) -> some View {
        ZStack {
            Circle()
                .stroke(WidgetStyle.readinessColor(score: readiness.score).opacity(0.2), lineWidth: 7)
            Circle()
                .trim(from: 0, to: min(Double(readiness.score) / 100, 1))
                .stroke(WidgetStyle.readinessColor(score: readiness.score), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(readiness.score)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .padding(6)
    }

    private func inlineView(_ readiness: WidgetReadinessSnapshot) -> some View {
        Text(readiness.dayType.isEmpty
             ? "Readiness \(readiness.score)"
             : "Readiness \(readiness.score) • \(readiness.dayType)")
    }

    @ViewBuilder
    private var updatedLabel: some View {
        if let lastUpdate = entry.lastUpdate {
            Text("Updated \(WidgetStyle.timeString(from: lastUpdate))")
                .font(.caption2)
                .foregroundStyle(AppColour.textTertiary)
        }
    }
}

import SwiftUI
import WidgetKit

/// Readiness score on the watch face.
///
/// The extension has no connectivity session of its own; it can only render what
/// the watch app last cached in the shared App Group. The watch app reloads these
/// timelines when a new payload arrives, so this provider never polls for data.
struct ReadinessComplication: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LasoReadinessComplication", provider: ReadinessProvider()) { entry in
            ReadinessComplicationView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName(WatchStrings.Complication.name)
        .description(WatchStrings.Complication.description)
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline, .accessoryRectangular])
    }
}

struct ReadinessEntry: TimelineEntry {
    let date: Date
    let payload: WatchPayload?

    var isStale: Bool {
        guard let payload else { return true }
        return payload.isStale(now: date)
    }
}

struct ReadinessProvider: TimelineProvider {

    func placeholder(in context: Context) -> ReadinessEntry {
        ReadinessEntry(date: Date(), payload: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (ReadinessEntry) -> Void) {
        completion(ReadinessEntry(date: Date(), payload: WatchPayloadCache.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadinessEntry>) -> Void) {
        let now = Date()
        let entry = ReadinessEntry(date: now, payload: WatchPayloadCache.load())
        // Reloads are driven by the watch app when the phone pushes. This wake-up
        // only exists so a payload that stopped arriving starts rendering as stale
        // instead of showing yesterday's number forever.
        let next = now.addingTimeInterval(WatchBridge.stalePayloadInterval)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct ReadinessComplicationView: View {

    @Environment(\.widgetFamily) private var family

    let entry: ReadinessEntry

    private var scoreText: String {
        guard let payload = entry.payload, !entry.isStale else { return "--" }
        return "\(payload.readinessScore)"
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("\(WatchStrings.Home.readinessLabel) \(scoreText)")

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(WatchStrings.Home.readinessLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(scoreText)
                    .font(.title2.weight(.semibold))
                if let dayType = entry.payload?.dayType, !dayType.isEmpty, !entry.isStale {
                    Text(dayType)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .accessoryCorner:
            Text(scoreText)
                .font(.title3.weight(.semibold))
                .widgetLabel(WatchStrings.Home.readinessLabel)

        default:
            VStack(spacing: 0) {
                Text(scoreText)
                    .font(.title2.weight(.semibold))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(WatchStrings.Home.readinessLabel)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

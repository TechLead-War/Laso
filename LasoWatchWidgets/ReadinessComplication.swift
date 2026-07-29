import SwiftUI
import WidgetKit

/// Today's word on the watch face.
///
/// The extension has no connectivity session and no HealthKit of its own; it renders
/// what the watch app last cached in the shared App Group. The app reloads these
/// timelines when a new payload arrives, so this provider never polls.
///
/// It renders the app's cached verdict rather than recomputing one. Running the ladder
/// here without live heart rate or exercise minutes would reach a different rung from
/// the same payload, and a face that disagrees with the app it opens is the fastest way
/// to lose the slot.
struct ReadinessComplication: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LasoReadinessComplication", provider: ReadinessProvider()) { entry in
            ReadinessComplicationView(entry: entry)
                .containerBackground(.clear, for: .widget)
                // The app hides this word when the wrist drops, so the face must too:
                // Apple's rule to hide health data in the Always On state applies to
                // whatever is on screen, not to whichever process drew it.
                .privacySensitive()
        }
        .configurationDisplayName(WatchStrings.Complication.verdictName)
        .description(WatchStrings.Complication.verdictDescription)
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline, .accessoryRectangular])
    }
}

struct ReadinessEntry: TimelineEntry {
    let date: Date
    let payload: WatchPayload?
    let verdict: CachedWatchVerdict?

    /// A word is only dropped when it describes a different day.
    ///
    /// It is deliberately NOT aged out by the clock. Only `train` is freshness-gated in
    /// this design; every other word is still true an hour later. Blanking the face to
    /// `--` because the app has not run for an hour is the exact failure the redesign set
    /// out to remove, and Apple warns that a complication showing nothing useful is the
    /// one most likely to lose its slot.
    var isForAnotherDay: Bool {
        verdict?.isForAnotherDay(now: date) ?? true
    }
}

struct ReadinessProvider: TimelineProvider {

    func placeholder(in context: Context) -> ReadinessEntry {
        ReadinessEntry(date: Date(), payload: nil, verdict: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (ReadinessEntry) -> Void) {
        completion(current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadinessEntry>) -> Void) {
        let entry = current()
        // Reloads are driven by the watch app when the phone pushes. This wake-up only
        // exists so a word that stopped arriving starts reading as ageing instead of
        // sitting on the face as today's answer forever.
        let next = entry.date.addingTimeInterval(WatchBridge.stalePayloadInterval)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func current() -> ReadinessEntry {
        ReadinessEntry(date: Date(), payload: WatchPayloadCache.load(), verdict: WatchVerdictCache.load())
    }
}

struct ReadinessComplicationView: View {

    @Environment(\.widgetFamily) private var family

    let entry: ReadinessEntry

    private var current: CachedWatchVerdict? {
        guard let verdict = entry.verdict, !entry.isForAnotherDay else { return nil }
        return verdict
    }

    private var word: String? {
        current.map { WatchStrings.Verdict.word($0.word) }
    }

    private var tint: Color {
        guard let verdict = current else { return WatchTheme.tertiary }
        switch verdict.word {
        case .breathe, .sleep: return WatchTheme.neutral
        default: return WatchTheme.color(for: verdict.band)
        }
    }

    /// Both halves come from the same cached computation, so the gauge can never pair a
    /// headroom from one moment with a ceiling from another.
    private var spentFraction: Double? { current?.spentFraction }

    var body: some View {
        switch family {
        case .accessoryInline:
            // One tap target, one line. The headroom is dropped here rather than
            // truncated: a clipped number is worse than no number.
            Text(word ?? WatchStrings.Complication.verdictName)
                .widgetURL(URL(string: "laso-watch://now"))

        case .accessoryRectangular:
            // The rectangular family carries the reason, so it opens the page that
            // explains it. Each family below links somewhere different on purpose.
            VStack(alignment: .leading, spacing: 1) {
                Text(word ?? WatchStrings.Complication.verdictName)
                    .font(.headline)
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let verdict = current {
                    Text(verdict.headroomLineForFace)
                        .font(.caption2)
                        .foregroundStyle(WatchTheme.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(URL(string: "laso-watch://why"))

        case .accessoryCorner:
            // "Recovering" is ten characters against a corner content box that fits far
            // fewer, so it scales rather than clips like every other family here.
            Text(word ?? WatchStrings.Complication.verdictName)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .widgetLabel(WatchStrings.Complication.verdictName)
                .widgetURL(URL(string: "laso-watch://today"))

        default:
            // Circular. The gauge is the point of this family: a ring is readable from
            // the face at a glance where two digits are not. The word rides inside it so
            // the meaning survives the accented rendering mode, where the system tints
            // everything to the face colour and colour alone carries nothing.
            ZStack {
                if let spentFraction {
                    Circle()
                        .stroke(WatchTheme.track, lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: spentFraction)
                        .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                Text(word ?? WatchStrings.Complication.verdictName)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(6)
            }
            .widgetURL(URL(string: "laso-watch://now"))
        }
    }
}

private extension CachedWatchVerdict {


    /// Shorter than the app's line, because the rectangular family fits about one line.
    /// Falls back to the reason so the slot is never blank, which would waste the one
    /// piece of face real estate a wearer has agreed to give up.
    var headroomLineForFace: String {
        guard let headroomMinutes else { return reason }
        return headroomMinutes > 0
            ? WatchStrings.Verdict.room(minutes: headroomMinutes)
            : WatchStrings.Verdict.ceilingReached
    }
}

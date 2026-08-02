import SwiftUI
import WidgetKit

// Widget target has no Firebase by design, so user-facing strings here are
// inline, matching the other widgets in this bundle.

struct MirrorWidgetEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let capturedToday: Bool
    let hasData: Bool

    static let placeholder = MirrorWidgetEntry(date: Date(), streak: 6, capturedToday: true, hasData: true)
}

struct MirrorWidgetProvider: TimelineProvider {
    private let store = WidgetDataStore.shared

    func placeholder(in context: Context) -> MirrorWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (MirrorWidgetEntry) -> Void) {
        completion(context.isPreview ? .placeholder : loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MirrorWidgetEntry>) -> Void) {
        // Refresh just after midnight so "done today" resets honestly even if
        // the app never opens; the app also pushes a reload on every capture.
        // Calendar day math, not +86400s: a DST day is 23 or 25 hours long.
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let nextMidnight = (calendar.date(byAdding: .day, value: 1, to: startOfToday)
            ?? startOfToday.addingTimeInterval(86_400)).addingTimeInterval(60)
        completion(Timeline(entries: [loadEntry()], policy: .after(nextMidnight)))
    }

    private func loadEntry() -> MirrorWidgetEntry {
        guard let snapshot = store.loadMirror() else {
            return MirrorWidgetEntry(date: Date(), streak: 0, capturedToday: false, hasData: false)
        }
        // The streak number is whatever the app last computed. The captured
        // flag must never leak across midnight, and a snapshot old enough
        // that the streak is provably dead must not keep asserting it.
        let age = snapshot.ageInDays() ?? 0
        let streakAlive = age <= WidgetMirrorSnapshot.staleAfterDays
        return MirrorWidgetEntry(
            date: Date(),
            streak: streakAlive ? snapshot.streak : 0,
            capturedToday: age == 0 && snapshot.capturedToday,
            hasData: true
        )
    }
}

struct MirrorStreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MirrorStreakWidget", provider: MirrorWidgetProvider()) { entry in
            MirrorWidgetView(entry: entry)
        }
        .configurationDisplayName("Daily Mirror")
        .description("Your capture streak, and whether today is on the record.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

struct MirrorWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: MirrorWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                circularView
            default:
                smallView
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [AppColour.primary.opacity(0.16), AppColour.surfaceBase],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("DAILY MIRROR")
                .font(.system(size: 10, weight: .bold))
                .kerning(1.0)
                .foregroundStyle(AppColour.primary)

            Spacer(minLength: 0)

            if entry.hasData && entry.streak > 0 {
                Text("\(entry.streak)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AppColour.textPrimary)
                    .contentTransition(.numericText())
                Text("day streak")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColour.textSecondary)
            } else {
                Image(systemName: "camera.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(AppColour.primary)
                Text("Start your mirror")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColour.textSecondary)
            }

            Spacer(minLength: 0)

            if entry.capturedToday {
                Label("Done today", systemImage: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColour.success)
            } else {
                Label("Not yet today", systemImage: "circle.dashed")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColour.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Same rule as smallView: a broken streak is never shown as a zero,
    /// the number simply disappears and the glyph carries the state.
    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            if entry.hasData && entry.streak > 0 {
                VStack(spacing: 0) {
                    Image(systemName: entry.capturedToday ? "checkmark.circle.fill" : "camera.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text("\(entry.streak)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
            } else {
                Image(systemName: entry.capturedToday ? "checkmark.circle.fill" : "camera.fill")
                    .font(.system(size: 22, weight: .semibold))
            }
        }
    }
}

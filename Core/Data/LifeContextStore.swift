import Foundation
import Observation

/// What the person has told us is going on in their life right now.
///
/// The body signals say how recovery is going; they cannot say the user is three
/// days into a sprained ankle. Without that, a high readiness score produces
/// "push a little harder" to someone who must not, which is the fastest way to
/// lose their trust in the advice.
///
/// A context never expires on a timer. An earlier version switched itself off
/// after a fixed number of days per context (injured 14, unwell 5), which is a
/// claim about how long an injury or an illness lasts, and this app has no basis
/// for making it. Instead the context stays on until the user says otherwise,
/// and we ask them to confirm on a fixed cadence so it cannot quietly sit there
/// suppressing advice for months.
@Observable
final class LifeContextStore {
    enum Context: String, CaseIterable, Codable {
        case injured, unwell, travelling, poorSleepWeek

        var displayName: String {
            switch self {
            case .injured:       return Copy.Home.contextInjured
            case .unwell:        return Copy.Home.contextUnwell
            case .travelling:    return Copy.Home.contextTravelling
            case .poorSleepWeek: return Copy.Home.contextPoorSleepWeek
            }
        }

        var systemImage: String {
            switch self {
            case .injured:       return "bandage.fill"
            case .unwell:        return "thermometer.medium"
            case .travelling:    return "airplane"
            case .poorSleepWeek: return "moon.zzz.fill"
            }
        }

        /// True when the context means the day's advice must not ask for load.
        var requiresRest: Bool {
            switch self {
            case .injured, .unwell:           return true
            case .travelling, .poorSleepWeek: return false
            }
        }
    }

    /// How often we ask the user whether a context still applies. This is a
    /// reminder cadence, not a statement about recovery time: whatever the
    /// answer, only the user changes the state.
    static let confirmationInterval: TimeInterval = 3 * 24 * 3600

    /// How far back finished spans are kept, so the month calendar can mark a
    /// stretch the user has already come out of. Beyond this they are dropped:
    /// the calendar cannot page back further, so keeping them only grows the
    /// defaults blob.
    static let historyRetentionDays = 400

    private static let storageKey = "Laso.LifeContext.spans"
    private static let legacyStorageKey = "Laso.LifeContext.state"

    /// One stretch of a context. `endedAt` nil means it is still on.
    ///
    /// Switching a context off used to delete it, which threw away the only
    /// record that the bad week had a reason. The span survives so a past day
    /// can still show what was going on.
    private struct Span: Codable {
        var startedAt: Date
        /// When the user last said it still applies. Starts equal to `startedAt`.
        var confirmedAt: Date
        var endedAt: Date?

        func covers(day: Date) -> Bool {
            let dayStart = Date.cal.startOfDay(for: day)
            guard Date.cal.startOfDay(for: startedAt) <= dayStart else { return false }
            guard let endedAt else { return true }
            return dayStart <= Date.cal.startOfDay(for: endedAt)
        }
    }

    private let defaults: UserDefaults

    private var spans: [Context: [Span]] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        spans = Self.load(from: defaults)
    }

    /// Increments whenever any span changes. See `persist(now:)`.
    private(set) var revision: Int = 0

    var active: Set<Context> { Set(spans.keys.filter { openSpan($0) != nil }) }

    var requiresRest: Bool { active.contains { $0.requiresRest } }

    func isActive(_ context: Context) -> Bool { openSpan(context) != nil }

    /// The day the user turned this on. Shown on the chip, because it is a fact
    /// we actually know, unlike an end date.
    func startDate(for context: Context) -> Date? { openSpan(context)?.startedAt }

    /// Every context that was switched on for that calendar day, finished ones
    /// included. This is what lets a past day explain its own score.
    func contexts(on day: Date) -> [Context] {
        spans
            .filter { $0.value.contains { $0.covers(day: day) } }
            .keys
            .sorted { $0.rawValue < $1.rawValue }
    }

    /// Contexts we have not heard about for longer than the reminder cadence.
    func needingConfirmation(now: Date = Date()) -> [Context] {
        Context.allCases.filter { context in
            guard let open = openSpan(context) else { return false }
            return now.timeIntervalSince(open.confirmedAt) >= Self.confirmationInterval
        }
    }

    /// Turns a context on, or closes the open stretch when it is already on.
    func toggle(_ context: Context, now: Date = Date()) {
        if let index = openSpanIndex(context) {
            spans[context]?[index].endedAt = now
        } else {
            spans[context, default: []].append(Span(startedAt: now, confirmedAt: now, endedAt: nil))
        }
        persist(now: now)
    }

    /// The user said it still applies. Resets the reminder clock, nothing else.
    func confirm(_ context: Context, now: Date = Date()) {
        guard let index = openSpanIndex(context) else { return }
        spans[context]?[index].confirmedAt = now
        persist(now: now)
    }

    private func openSpanIndex(_ context: Context) -> Int? {
        spans[context]?.firstIndex { $0.endedAt == nil }
    }

    private func openSpan(_ context: Context) -> Span? {
        openSpanIndex(context).flatMap { spans[context]?[$0] }
    }

    private func persist(now: Date) {
        prune(now: now)
        // Bumped on every change. The spans are private and a context covers a
        // whole date range, so anything caching data derived from this store
        // compares this number instead of trying to diff the spans themselves.
        revision &+= 1
        let encodable = spans.reduce(into: [String: [Span]]()) { $0[$1.key.rawValue] = $1.value }
        guard let data = try? JSONEncoder().encode(encodable) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private func prune(now: Date) {
        guard let cutoff = Date.cal.date(byAdding: .day, value: -Self.historyRetentionDays, to: now) else { return }
        for (context, list) in spans {
            let kept = list.filter { $0.endedAt.map { $0 >= cutoff } ?? true }
            if kept.isEmpty { spans[context] = nil } else { spans[context] = kept }
        }
    }

    private static func load(from defaults: UserDefaults) -> [Context: [Span]] {
        if let data = defaults.data(forKey: storageKey),
           let raw = try? JSONDecoder().decode([String: [Span]].self, from: data) {
            return raw.reduce(into: [Context: [Span]]()) { result, pair in
                guard let context = Context(rawValue: pair.key), !pair.value.isEmpty else { return }
                result[context] = pair.value
            }
        }
        return migrateLegacy(from: defaults)
    }

    /// Anyone already carrying a context from the pre-history format keeps it,
    /// as one still-open span. Dropping it would silently switch off a rest
    /// context someone is relying on.
    private static func migrateLegacy(from defaults: UserDefaults) -> [Context: [Span]] {
        struct LegacyState: Codable {
            var startedAt: Date
            var confirmedAt: Date
        }
        guard let data = defaults.data(forKey: legacyStorageKey),
              let raw = try? JSONDecoder().decode([String: LegacyState].self, from: data) else { return [:] }
        return raw.reduce(into: [Context: [Span]]()) { result, pair in
            guard let context = Context(rawValue: pair.key) else { return }
            result[context] = [Span(startedAt: pair.value.startedAt,
                                    confirmedAt: pair.value.confirmedAt,
                                    endedAt: nil)]
        }
    }
}

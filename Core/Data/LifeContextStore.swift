import Foundation
import Observation

/// What the person has told us is going on in their life right now.
///
/// The body signals say how recovery is going; they cannot say the user is three
/// days into a sprained ankle. Without that, a high readiness score produces
/// "push a little harder" to someone who must not, which is the fastest way to
/// lose their trust in the advice.
///
/// Each context expires on its own so the app never carries a stale state
/// forever; the user sets it once and does not have to remember to turn it off.
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

        /// How long the context stays on before it expires by itself. Chosen to
        /// be shorter than the real thing usually lasts, so the app under claims
        /// rather than silently suppressing advice for weeks.
        var defaultDays: Int {
            switch self {
            case .injured:       return 14
            case .unwell:        return 5
            case .travelling:    return 7
            case .poorSleepWeek: return 7
            }
        }

        /// True when the context means the day's advice must not ask for load.
        var requiresRest: Bool {
            switch self {
            case .injured, .unwell:          return true
            case .travelling, .poorSleepWeek: return false
            }
        }
    }

    private static let storageKey = "Laso.LifeContext.active"

    private let defaults: UserDefaults

    /// Active contexts and the day each one stops applying.
    private(set) var activeUntil: [Context: Date] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        activeUntil = Self.load(from: defaults)
        pruneExpired()
    }

    var active: Set<Context> { Set(activeUntil.keys) }

    var requiresRest: Bool { active.contains { $0.requiresRest } }

    func isActive(_ context: Context) -> Bool { activeUntil[context] != nil }

    func endDate(for context: Context) -> Date? { activeUntil[context] }

    /// Turns a context on for its default window, or off when it is already on.
    func toggle(_ context: Context, now: Date = Date()) {
        if activeUntil[context] != nil {
            activeUntil[context] = nil
        } else {
            let end = Date.cal.date(byAdding: .day, value: context.defaultDays, to: Date.cal.startOfDay(for: now))
            activeUntil[context] = end ?? now
        }
        persist()
    }

    /// Drops contexts whose window has passed. Called on init and on every
    /// foreground read, so a context can never outlive its own end date.
    func pruneExpired(now: Date = Date()) {
        let live = activeUntil.filter { $0.value > now }
        guard live.count != activeUntil.count else { return }
        activeUntil = live
        persist()
    }

    private func persist() {
        let encodable = activeUntil.reduce(into: [String: Date]()) { $0[$1.key.rawValue] = $1.value }
        guard let data = try? JSONEncoder().encode(encodable) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private static func load(from defaults: UserDefaults) -> [Context: Date] {
        guard let data = defaults.data(forKey: storageKey),
              let raw = try? JSONDecoder().decode([String: Date].self, from: data) else { return [:] }
        return raw.reduce(into: [Context: Date]()) { result, pair in
            guard let context = Context(rawValue: pair.key) else { return }
            result[context] = pair.value
        }
    }
}

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

    private static let storageKey = "Laso.LifeContext.state"

    private struct State: Codable {
        /// When the user switched it on.
        var startedAt: Date
        /// When the user last said it still applies. Starts equal to `startedAt`.
        var confirmedAt: Date
    }

    private let defaults: UserDefaults

    private var states: [Context: State] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        states = Self.load(from: defaults)
    }

    var active: Set<Context> { Set(states.keys) }

    var requiresRest: Bool { active.contains { $0.requiresRest } }

    func isActive(_ context: Context) -> Bool { states[context] != nil }

    /// The day the user turned this on. Shown on the chip, because it is a fact
    /// we actually know, unlike an end date.
    func startDate(for context: Context) -> Date? { states[context]?.startedAt }

    /// Contexts we have not heard about for longer than the reminder cadence.
    func needingConfirmation(now: Date = Date()) -> [Context] {
        states
            .filter { now.timeIntervalSince($0.value.confirmedAt) >= Self.confirmationInterval }
            .keys
            .sorted { $0.rawValue < $1.rawValue }
    }

    /// Turns a context on, or off when it is already on.
    func toggle(_ context: Context, now: Date = Date()) {
        if states[context] != nil {
            states[context] = nil
        } else {
            states[context] = State(startedAt: now, confirmedAt: now)
        }
        persist()
    }

    /// The user said it still applies. Resets the reminder clock, nothing else.
    func confirm(_ context: Context, now: Date = Date()) {
        guard var state = states[context] else { return }
        state.confirmedAt = now
        states[context] = state
        persist()
    }

    private func persist() {
        let encodable = states.reduce(into: [String: State]()) { $0[$1.key.rawValue] = $1.value }
        guard let data = try? JSONEncoder().encode(encodable) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private static func load(from defaults: UserDefaults) -> [Context: State] {
        guard let data = defaults.data(forKey: storageKey),
              let raw = try? JSONDecoder().decode([String: State].self, from: data) else { return [:] }
        return raw.reduce(into: [Context: State]()) { result, pair in
            guard let context = Context(rawValue: pair.key) else { return }
            result[context] = pair.value
        }
    }
}

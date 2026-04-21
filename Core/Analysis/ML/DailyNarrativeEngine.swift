import Foundation

/// Plain-Swift signals struct consumed by DailyNarrativeEngine. Lives outside
/// any iOS 26 availability block so callers on older OSes can still build the
/// payload — they'll just skip the actual generation.
struct DailyNarrativeSignals {
    let userFirstName: String?
    let readinessScore: Int?
    let weakestPillar: String?
    let hrvMs: Int?
    let sleepHours: Double?
    let streakDays: Int
}

#if canImport(FoundationModels)
import FoundationModels

/// Generates a proactive one-paragraph daily narrative using Apple's on-device
/// Foundation Models framework (iOS 26+). Cached per calendar day so we only
/// spend compute once per day and the user sees the same story until tomorrow.
///
/// Why this matters: research on Oura Advisor (60% weekly active, 87% found
/// remembered context helpful) shows proactive narrative beats reactive chat
/// for wellness engagement. On-device also preserves Laso's privacy moat —
/// no server LLM bill, no health data leaving the phone.
@available(iOS 26, *)
final class DailyNarrativeEngine {
    static let shared = DailyNarrativeEngine()

    private init() {}

    /// Returns today's narrative (cached if already generated today), or `nil`
    /// if generation failed. Callers should treat nil as "silent fallback" —
    /// no card shown, no error surfaced.
    func narrativeForToday(signals: DailyNarrativeSignals) async -> String? {
        if let cached = cachedNarrativeToday(), !cached.isEmpty {
            return cached
        }

        do {
            let session = LanguageModelSession {
                """
                You are the user's personal health companion inside Laso. Write ONE short paragraph, two sentences max, under 40 words, that proactively tells the user what today looks like for their body.

                Voice:
                - Direct, warm, second-person ("you", "your").
                - Never start with "Today", "Your", "Based on", or "Good morning". Vary openers.
                - Ground the paragraph in the single most important signal. Don't list numbers.
                - If readiness is low, lead with a gentle nudge to go easy. If high, lead with what they can go for.
                - Use the user's first name at most once, naturally.
                - No questions, no sign-off, no bullets.
                """
            }
            let response = try await session.respond(to: buildPrompt(signals: signals))
            let narrative = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !narrative.isEmpty else { return nil }
            cacheNarrativeToday(narrative)
            return narrative
        } catch {
            return nil
        }
    }

    // MARK: - Prompt

    private func buildPrompt(signals: DailyNarrativeSignals) -> String {
        var parts: [String] = []
        if let s = signals.userFirstName { parts.append("User's first name: \(s).") }
        if let r = signals.readinessScore { parts.append("Readiness: \(r)/100.") }
        if let w = signals.weakestPillar { parts.append("Weakest pillar right now: \(w).") }
        if let h = signals.hrvMs { parts.append("HRV: \(h) ms.") }
        if let sh = signals.sleepHours {
            parts.append("Sleep last night: \(String(format: "%.1f", sh)) hours.")
        }
        if signals.streakDays > 0 {
            parts.append("Current streak: \(signals.streakDays) days.")
        }
        let hour = Calendar.current.component(.hour, from: Date())
        let timeOfDay: String
        switch hour {
        case 5..<11:  timeOfDay = "morning"
        case 11..<17: timeOfDay = "midday"
        case 17..<22: timeOfDay = "evening"
        default:      timeOfDay = "late night"
        }
        parts.append("Time of day: \(timeOfDay).")
        return "Signals:\n" + parts.joined(separator: "\n") + "\n\nWrite the paragraph."
    }

    // MARK: - Per-day cache

    private static let cachePrefix = "laso.daily_narrative."

    private var todayKey: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return Self.cachePrefix + formatter.string(from: Date())
    }

    private func cachedNarrativeToday() -> String? {
        UserDefaults.standard.string(forKey: todayKey)
    }

    private func cacheNarrativeToday(_ narrative: String) {
        UserDefaults.standard.set(narrative, forKey: todayKey)
        // Sweep stale keys from previous days so UserDefaults doesn't grow unboundedly.
        pruneStaleCacheKeys()
    }

    private func pruneStaleCacheKeys() {
        let defaults = UserDefaults.standard
        let all = defaults.dictionaryRepresentation()
        let today = todayKey
        for key in all.keys where key.hasPrefix(Self.cachePrefix) && key != today {
            defaults.removeObject(forKey: key)
        }
    }
}

#endif

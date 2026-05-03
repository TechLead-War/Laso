import Foundation

extension Copy {
    enum Common {

        // MARK: - Shared UI Tokens

        static let notEnoughData = "Not enough data yet"
        static let avg = "Avg"
        static let thisWeek = "This Week"
        static let lastWeek = "Last Week"
        static let improved = "Improved"
        static let increased = "Increased"

        // MARK: - Shared Accessibility Labels

        static let continueAnyway = "Continue anyway"
        static let sendingFeedback = "Sending feedback"
        static let quickQuestion = "Quick question"
        static let shareHealthCard = "Share health card"

        static func dataConfidence(tier: String) -> String {
            "Data confidence: \(tier) tier"
        }

        /// Caption shown above detail screens — "Updated 2 minutes ago" style.
        /// Returns nil when the data is less than 60 seconds old, so callers can
        /// hide the caption entirely instead of showing "Updated 0 sec ago" noise
        /// on a fresh snapshot.
        static func relativeUpdated(_ date: Date) -> String? {
            guard Date().timeIntervalSince(date) >= 60 else { return nil }
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Updated \(formatter.localizedString(for: date, relativeTo: Date()))"
        }
    }
}

import Foundation

extension Copy {
    enum MetricDetail {

        // MARK: - Log Sheet

        static let loggingNotSupported = "Logging not supported for this metric."
        static let bodyWeightHeader = "Body Weight"
        static let waterIntakeHeader = "Water Intake"
        static let sessionDurationHeader = "Session Duration"

        // MARK: - Discard Confirmation (Pass 8 Q)

        static let discardChangesTitle = "Discard changes?"
        static let discardButton = "Discard"
        static let keepEditingButton = "Keep editing"
        static let unsavedEntryMessage = "Your unsaved entry will be lost."

        // MARK: - Toolbar (Pass 8 Q)

        static let cancel = "Cancel"
        static let save = "Save"
        static func logTitle(_ metricName: String) -> String { "Log \(metricName)" }
        static func saveFailed(_ description: String) -> String { "Failed to save: \(description)" }
    }
}

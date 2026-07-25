import Foundation

extension Copy {
    enum MetricDetail {

        // MARK: - Log Sheet

        static var loggingNotSupported: String { RemoteConfigManager.shared.copyString("copy_metric_detail_metric_detail_logging_not_supported", default: "Logging not supported for this metric.") }
        static var bodyWeightHeader: String { RemoteConfigManager.shared.copyString("copy_metric_detail_metric_detail_body_weight_header", default: "Body Weight") }
        static var waterIntakeHeader: String { RemoteConfigManager.shared.copyString("copy_metric_detail_metric_detail_water_intake_header", default: "Water Intake") }
        static var sessionDurationHeader: String { RemoteConfigManager.shared.copyString("copy_metric_detail_metric_detail_session_duration_header", default: "Session Duration") }

        // MARK: - Toolbar

        static var cancel: String { RemoteConfigManager.shared.copyString("copy_metric_detail_metric_detail_cancel", default: "Cancel") }
        static var save: String { RemoteConfigManager.shared.copyString("copy_metric_detail_metric_detail_save", default: "Save") }
        static func logTitle(_ metricName: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_metric_detail_metric_detail_log_title", default: "Log %@"), metricName) }
        static func saveFailed(_ description: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_metric_detail_metric_detail_save_failed", default: "Failed to save: %@"), description) }

        // MARK: - Lifted interpolated view literals
        static func logMenuLabel(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_metricdetail_log_menu_label", default: "Log %@"), p0) }
        static func mlText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_metricdetail_ml_text", default: "%d mL"), p0) }
        static func xText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_metricdetail_x_text", default: "%d"), p0) }
        static func minText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_metricdetail_min_text", default: "%d min"), p0) }
    }
}

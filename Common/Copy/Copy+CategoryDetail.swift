import Foundation

extension Copy {
    enum CategoryDetail {

        // MARK: - Section Headers

        static var fromYourHistory: String { RemoteConfigManager.shared.copyString("copy_category_detail_category_detail_from_your_history", default: "From Your History") }
        static var insights: String { RemoteConfigManager.shared.copyString("copy_category_detail_category_detail_insights", default: "Insights") }
        static var metrics: String { RemoteConfigManager.shared.copyString("copy_category_detail_category_detail_metrics", default: "Metrics") }
    }
}

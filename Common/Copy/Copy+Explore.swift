import Foundation

extension Copy {
    enum Explore {

        // MARK: - Day Sheet

        static var dayClose: String { RemoteConfigManager.shared.copyString("copy_explore_day_close", default: "Close") }
    }
}

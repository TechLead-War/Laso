import Foundation

extension Copy {
    enum Strain {

        // MARK: - Coach Zone Display Names

        static var zoneRestoring: String { RemoteConfigManager.shared.copyString("copy_strain_strain_zone_restoring", default: "Recovery Focus") }
        static var zoneMaintaining: String { RemoteConfigManager.shared.copyString("copy_strain_strain_zone_maintaining", default: "Maintain Fitness") }
        static var zoneBuilding: String { RemoteConfigManager.shared.copyString("copy_strain_strain_zone_building", default: "Progressive Overload") }
        static var zoneOverreaching: String { RemoteConfigManager.shared.copyString("copy_strain_strain_zone_overreaching", default: "Functional Overreach") }

        // MARK: - Simplified Drivers

        static func targetRange(_ low: String, _ high: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_strain_target_range", default: "Aim for %@ to %@"), low, high) }

        // MARK: - Strain Levels

        static var strainLevelLow: String { RemoteConfigManager.shared.copyString("copy_strain_strain_level_low", default: "Low") }
        static var strainLevelLight: String { RemoteConfigManager.shared.copyString("copy_strain_strain_level_light", default: "Light") }
        static var strainLevelModerate: String { RemoteConfigManager.shared.copyString("copy_strain_strain_level_moderate", default: "Moderate") }
        static var strainLevelHigh: String { RemoteConfigManager.shared.copyString("copy_strain_strain_level_high", default: "High") }
        static var strainLevelPeak: String { RemoteConfigManager.shared.copyString("copy_strain_strain_level_peak", default: "Peak") }
        static var strainLevelAllOut: String { RemoteConfigManager.shared.copyString("copy_strain_strain_level_all_out", default: "All Out") }
    }
}

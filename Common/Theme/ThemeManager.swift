import SwiftUI
import UIKit

/// The user's appearance choice.
///
/// Raw values are persisted, so they are part of the storage contract: renaming a
/// case silently resets everyone who chose it back to `.system`.
enum ThemePreference: String, CaseIterable, Identifiable {
    case light
    case dark
    case system

    var id: String { rawValue }

    /// `nil` means "follow the device", which is what `overrideUserInterfaceStyle`
    /// expresses as `.unspecified`.
    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .light:  return .light
        case .dark:   return .dark
        case .system: return .unspecified
        }
    }

    var title: String {
        switch self {
        case .light:  return Copy.Settings.themeLight
        case .dark:   return Copy.Settings.themeDark
        case .system: return Copy.Settings.themeSystem
        }
    }

    var symbol: String {
        switch self {
        case .light:  return "sun.max"
        case .dark:   return "moon"
        case .system: return "iphone"
        }
    }
}

/// Owns the appearance choice and pushes it onto the window.
///
/// This applies the style at `UIWindow.overrideUserInterfaceStyle` rather than
/// SwiftUI's `.preferredColorScheme`. `.preferredColorScheme(nil)` does not
/// actually return control to the system once an explicit value has been set
/// (FB8383053, still reproducing on iOS 18), so a "System" option built that way
/// stays stuck on the last explicit choice until the app is relaunched. Setting
/// `.unspecified` on the window does return control immediately.
///
/// Driving the window also covers UIKit-backed surfaces SwiftUI does not reach:
/// share sheets, `SFSafariViewController`, photo pickers and alerts.
@Observable
@MainActor
final class ThemeManager {

    static let shared = ThemeManager()

    private(set) var preference: ThemePreference {
        didSet { apply() }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: AppKeys.App.themePreference)
        preference = raw.flatMap(ThemePreference.init(rawValue:)) ?? .system
    }

    func set(_ next: ThemePreference) {
        guard next != preference else { return }
        UserDefaults.standard.set(next.rawValue, forKey: AppKeys.App.themePreference)
        preference = next
    }

    /// Applies the appearance to every window that currently exists.
    ///
    /// It has to walk the live windows. `UIWindow.appearance()` is a proxy that only
    /// affects windows created AFTER it is set, so by the time any SwiftUI lifecycle
    /// hook runs the app's window already exists and the proxy silently does nothing.
    ///
    /// Call once at launch, after the scene exists. `didSet` handles every change
    /// after that.
    ///
    /// - Parameter override: forces a style regardless of the stored preference.
    ///   Used by UI tests so snapshots stay deterministic.
    func apply(override: UIUserInterfaceStyle? = nil) {
        let style = override ?? preference.interfaceStyle
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}

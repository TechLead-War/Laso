import Foundation
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "100" asset catalog image resource.
    static let _100 = DeveloperToolsSupport.ImageResource(name: "100", bundle: resourceBundle)

    /// The "1024" asset catalog image resource.
    static let _1024 = DeveloperToolsSupport.ImageResource(name: "1024", bundle: resourceBundle)

    /// The "114" asset catalog image resource.
    static let _114 = DeveloperToolsSupport.ImageResource(name: "114", bundle: resourceBundle)

    /// The "120" asset catalog image resource.
    static let _120 = DeveloperToolsSupport.ImageResource(name: "120", bundle: resourceBundle)

    /// The "144" asset catalog image resource.
    static let _144 = DeveloperToolsSupport.ImageResource(name: "144", bundle: resourceBundle)

    /// The "152" asset catalog image resource.
    static let _152 = DeveloperToolsSupport.ImageResource(name: "152", bundle: resourceBundle)

    /// The "167" asset catalog image resource.
    static let _167 = DeveloperToolsSupport.ImageResource(name: "167", bundle: resourceBundle)

    /// The "180" asset catalog image resource.
    static let _180 = DeveloperToolsSupport.ImageResource(name: "180", bundle: resourceBundle)

    /// The "20" asset catalog image resource.
    static let _20 = DeveloperToolsSupport.ImageResource(name: "20", bundle: resourceBundle)

    /// The "29" asset catalog image resource.
    static let _29 = DeveloperToolsSupport.ImageResource(name: "29", bundle: resourceBundle)

    /// The "40" asset catalog image resource.
    static let _40 = DeveloperToolsSupport.ImageResource(name: "40", bundle: resourceBundle)

    /// The "50" asset catalog image resource.
    static let _50 = DeveloperToolsSupport.ImageResource(name: "50", bundle: resourceBundle)

    /// The "57" asset catalog image resource.
    static let _57 = DeveloperToolsSupport.ImageResource(name: "57", bundle: resourceBundle)

    /// The "58" asset catalog image resource.
    static let _58 = DeveloperToolsSupport.ImageResource(name: "58", bundle: resourceBundle)

    /// The "60" asset catalog image resource.
    static let _60 = DeveloperToolsSupport.ImageResource(name: "60", bundle: resourceBundle)

    /// The "72" asset catalog image resource.
    static let _72 = DeveloperToolsSupport.ImageResource(name: "72", bundle: resourceBundle)

    /// The "76" asset catalog image resource.
    static let _76 = DeveloperToolsSupport.ImageResource(name: "76", bundle: resourceBundle)

    /// The "80" asset catalog image resource.
    static let _80 = DeveloperToolsSupport.ImageResource(name: "80", bundle: resourceBundle)

    /// The "87" asset catalog image resource.
    static let _87 = DeveloperToolsSupport.ImageResource(name: "87", bundle: resourceBundle)

    /// The "LaunchIcon" asset catalog image resource.
    static let launchIcon = DeveloperToolsSupport.ImageResource(name: "LaunchIcon", bundle: resourceBundle)

}


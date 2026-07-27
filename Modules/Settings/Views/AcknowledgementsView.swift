import SwiftUI

/// Lists the open source libraries Laso depends on, with the license they
/// ship under and a link to their public source repository.
///
/// Required by the Apache 2.0 and MIT licenses many of these libraries use.
/// The list mirrors `Package.resolved` — keep both in sync when adding or
/// removing a Swift Package dependency.
struct AcknowledgementsView: View {

    struct Library: Identifiable {
        // `libraries` is a stored property initializer, so it re-runs each time
        // SwiftUI recreates the view value. Package names are unique.
        var id: String { name }
        let name: String
        let license: String
        let url: URL
    }

    private let libraries: [Library] = [
        Library(
            name: "Firebase iOS SDK",
            license: "Apache 2.0",
            url: URL(string: "https://github.com/firebase/firebase-ios-sdk")!
        ),
        Library(
            name: "GoogleAppMeasurement",
            license: "Apache 2.0",
            url: URL(string: "https://github.com/google/GoogleAppMeasurement")!
        ),
        Library(
            name: "GoogleDataTransport",
            license: "Apache 2.0",
            url: URL(string: "https://github.com/google/GoogleDataTransport")!
        ),
        Library(
            name: "GoogleUtilities",
            license: "Apache 2.0",
            url: URL(string: "https://github.com/google/GoogleUtilities")!
        ),
        Library(
            name: "Google App Check",
            license: "Apache 2.0",
            url: URL(string: "https://github.com/google/app-check")!
        ),
        Library(
            name: "Interop for Google SDKs",
            license: "Apache 2.0",
            url: URL(string: "https://github.com/google/interop-ios-for-google-sdks")!
        ),
        Library(
            name: "GTM Session Fetcher",
            license: "Apache 2.0",
            url: URL(string: "https://github.com/google/gtm-session-fetcher")!
        ),
        Library(
            name: "Google Promises",
            license: "Apache 2.0",
            url: URL(string: "https://github.com/google/promises")!
        ),
        Library(
            name: "Google Ads On-Device Conversion iOS SDK",
            license: "Apache 2.0",
            url: URL(string: "https://github.com/googleads/google-ads-on-device-conversion-ios-sdk")!
        ),
        Library(
            name: "gRPC (binary)",
            license: "Apache 2.0",
            url: URL(string: "https://github.com/google/grpc-binary")!
        ),
        Library(
            name: "Abseil C++ (binary)",
            license: "Apache 2.0",
            url: URL(string: "https://github.com/google/abseil-cpp-binary")!
        ),
        Library(
            name: "SwiftProtobuf",
            license: "Apache 2.0",
            url: URL(string: "https://github.com/apple/swift-protobuf")!
        ),
        Library(
            name: "nanopb",
            license: "zlib",
            url: URL(string: "https://github.com/firebase/nanopb")!
        ),
        Library(
            name: "LevelDB",
            license: "BSD-3-Clause",
            url: URL(string: "https://github.com/firebase/leveldb")!
        ),
        Library(
            name: "PostHog iOS",
            license: "MIT",
            url: URL(string: "https://github.com/PostHog/posthog-ios")!
        ),
        Library(
            name: "PLCrashReporter",
            license: "MIT",
            url: URL(string: "https://github.com/microsoft/plcrashreporter")!
        )
    ]

    var body: some View {
        List {
            Section {
                ForEach(libraries) { library in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(library.name)
                            .font(DS.Typography.subheadlineMedium)
                            .foregroundStyle(.primary)
                        Text(library.license)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                        Link(destination: library.url) {
                            HStack(spacing: 4) {
                                Text(Copy.Settings.viewSource)
                                Image(systemName: "arrow.up.right")
                            }
                            .font(DS.Typography.caption)
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Copy.Settings.libraryLicense(name: library.name, license: library.license))
                    .accessibilityHint(Copy.Settings.viewSource)
                }
            } footer: {
                Text(Copy.Settings.acknowledgementsFooter)
            }
        }
        .listStyle(.insetGrouped)
        .background(AppColour.surfaceBase.ignoresSafeArea())
        .navigationTitle(Copy.Settings.acknowledgements)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("screen.acknowledgements")
    }
}

#Preview {
    NavigationStack {
        AcknowledgementsView()
    }
}

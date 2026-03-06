import XCTest

enum ScreenshotStore {
    static func capture(
        app: XCUIApplication,
        theme: String,
        profile: String,
        step: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let screenshot = app.screenshot()
        let outputURL = outputDirectory().appendingPathComponent(fileName(theme: theme, profile: profile, step: step))
        do {
            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try screenshot.pngRepresentation.write(to: outputURL, options: .atomic)
        } catch {
            XCTFail("Failed to write screenshot at \(outputURL.path): \(error)", file: file, line: line)
        }

        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = outputURL.lastPathComponent
        attachment.lifetime = .keepAlways
        XCTContext.runActivity(named: "Captured \(outputURL.lastPathComponent)") { _ in
            // Keep attachment in xcresult for quick inspection in Xcode.
        }
    }

    private static func outputDirectory() -> URL {
        if let env = ProcessInfo.processInfo.environment["HP_SCREENSHOT_OUTPUT_DIR"], !env.isEmpty {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        // Derive project root from source file: UITests/ScreenshotStore.swift -> project root
        let sourceFile = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceFile.deletingLastPathComponent().deletingLastPathComponent()
        return projectRoot.appendingPathComponent("visual-regression/current", isDirectory: true)
    }

    private static func fileName(theme: String, profile: String, step: String) -> String {
        let runtime = sanitize(ProcessInfo.processInfo.environment["SIMULATOR_RUNTIME_VERSION"] ?? "ios")
        let device = sanitize(ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "simulator")
        let locale = sanitize(Locale.current.identifier)
        let themePart = sanitize(theme)
        let profilePart = sanitize(profile)
        let stepPart = sanitize(step)
        return "ios\(runtime)-\(device)-\(themePart)-\(locale)-\(profilePart)-\(stepPart).png"
    }

    private static func sanitize(_ raw: String) -> String {
        let lower = raw.lowercased()
        let pattern = "[^a-z0-9]+"
        let replaced = lower.replacingOccurrences(of: pattern, with: "_", options: .regularExpression)
        let trimmed = replaced.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return trimmed.isEmpty ? "value" : trimmed
    }
}

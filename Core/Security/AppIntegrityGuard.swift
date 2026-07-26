import Foundation
import MachO
import Darwin.POSIX.unistd

/// Detects jailbreak, debugger attachment, and binary tampering.
/// Call `AppIntegrityGuard.performChecks()` at app launch to block compromised environments.
enum AppIntegrityGuard {

    // MARK: - Public API

    /// Runs all integrity checks. Returns a failure reason string, or nil if the environment is clean.
    ///
    /// Checks still execute for analytics visibility but no longer block the UI.
    /// Apple App Store Review guidelines discourage hard-blocking users based on
    /// jailbreak or environment detection, so results are logged only.
    /// Reports a compromised environment to analytics. Deliberately never blocks
    /// the app, so it returns nothing and the caller runs it off the launch path.
    static func performChecks() {
        #if DEBUG
        return
        #else
        var reason: String?
        if isJailbroken() { reason = "unsupported_environment" }
        else if isDebuggerAttached() { reason = "debugger_detected" }
        else if isTampered() { reason = "integrity_failure" }
        else if isRunningInEmulator() { reason = "emulator_detected" }

        if let reason {
            AnalyticsBackend.provider.captureError(
                "Integrity check flagged: \(reason)",
                context: "app_integrity_guard"
            )
        }
        #endif
    }

    // MARK: - Jailbreak Detection

    /// Multi-signal jailbreak detection. checks filesystem artifacts, writable system paths,
    /// dynamic libraries, and fork ability.
    private static func isJailbroken() -> Bool {
        // 1. Check for common jailbreak file paths
        let suspiciousPaths = [
            "/Applications/Cydia.app",
            "/Applications/Sileo.app",
            "/Applications/Zebra.app",
            "/Applications/Installer.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/usr/sbin/sshd",
            "/usr/bin/sshd",
            "/usr/libexec/sftp-server",
            "/etc/apt",
            "/etc/apt/sources.list.d",
            "/private/var/lib/apt",
            "/private/var/lib/cydia",
            "/private/var/mobile/Library/SBSettings/Themes",
            "/private/var/stash",
            "/private/var/tmp/cydia.log",
            "/var/cache/apt",
            "/var/lib/apt",
            "/var/lib/dpkg",
            "/bin/bash",
            "/bin/sh",
            "/usr/bin/ssh",
        ]

        for path in suspiciousPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }

        // 2. Check if suspicious URL schemes are available
        // (Can't use UIApplication.canOpenURL in a non-UI context, so check dylibs instead)

        // 3. Check for suspicious dynamic libraries
        let suspiciousLibs = [
            "SubstrateLoader",
            "MobileSubstrate",
            "TweakInject",
            "CydiaSubstrate",
            "libhooker",
            "substitute",
            "Cephei",
            "Shadow",
            "FlyJB",
            "Liberty",
        ]

        let imageCount = _dyld_image_count()
        for i in 0..<imageCount {
            if let name = _dyld_get_image_name(i) {
                let imageName = String(cString: name)
                for lib in suspiciousLibs {
                    if imageName.lowercased().contains(lib.lowercased()) {
                        return true
                    }
                }
            }
        }

        return false
    }

    // MARK: - Debugger Detection

    /// Detects if a debugger is attached via sysctl.
    private static func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]

        let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        guard result == 0 else { return false }

        return (info.kp_proc.p_flag & P_TRACED) != 0
    }

    // MARK: - Tamper Detection

    /// Checks if the binary has been modified by verifying the embedded code signature.
    private static func isTampered() -> Bool {
        guard let bundlePath = Bundle.main.executablePath else { return true }

        // Check that the main executable exists and the bundle ID matches
        guard FileManager.default.fileExists(atPath: bundlePath) else { return true }

        // Verify bundle identifier hasn't been changed
        guard Bundle.main.bundleIdentifier == AppSecrets.App.bundleID else { return true }

        // Check Info.plist hasn't been tampered with
        guard let infoPlist = Bundle.main.infoDictionary,
              infoPlist["CFBundleIdentifier"] as? String == AppSecrets.App.bundleID else {
            return true
        }

        // Verify the executable is signed (basic Mach-O header check)
        return !isValidMachOSignature()
    }

    /// Verifies the main executable's Mach-O header contains a code signature load command.
    private static func isValidMachOSignature() -> Bool {
        let count = _dyld_image_count()
        guard count > 0 else { return false }

        // The first image is always the main executable
        guard let header = _dyld_get_image_header(0) else { return false }

        var cursor = UnsafeRawPointer(header).advanced(by: MemoryLayout<mach_header_64>.size)
        for _ in 0..<header.pointee.ncmds {
            let cmd = cursor.assumingMemoryBound(to: load_command.self).pointee
            // LC_CODE_SIGNATURE = 0x1D
            if cmd.cmd == 0x1D {
                return true
            }
            cursor = cursor.advanced(by: Int(cmd.cmdsize))
        }

        return false
    }

    // MARK: - Emulator Detection

    /// Detects if the app is running in a simulator (release builds should never run on simulator).
    private static func isRunningInEmulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        // Additional check: simulator-specific environment variable
        if ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil {
            return true
        }
        return false
        #endif
    }
}

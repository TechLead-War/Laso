import SwiftUI
import LocalAuthentication

/// Gates the app behind Face ID / Touch ID / passcode so health data stays
/// private on a shared or borrowed phone.
///
/// The lock UI lives in its own UIWindow above the app's window instead of a
/// SwiftUI overlay: fullScreenCovers and sheets present in a separate UIKit
/// layer that a ZStack overlay can never cover, so an overlay would leak an
/// open sheet on relock. The same window doubles as the privacy cover that
/// hides content in the app switcher snapshot.
@Observable
@MainActor
final class AppLockManager {
    static let shared = AppLockManager()

    enum LockTiming: String, CaseIterable {
        case immediately = "immediately"
        case afterOneMinute = "after_1_min"
        case afterFiveMinutes = "after_5_min"

        var gracePeriod: TimeInterval {
            switch self {
            case .immediately: return 0
            case .afterOneMinute: return 60
            case .afterFiveMinutes: return 300
            }
        }

        var title: String {
            switch self {
            case .immediately: return Copy.Settings.lockRightAway
            case .afterOneMinute: return Copy.Settings.lockAfterOneMinute
            case .afterFiveMinutes: return Copy.Settings.lockAfterFiveMinutes
            }
        }
    }

    enum EnableResult { case enabled, failed, noPasscode }

    /// Read by Siri App Intents, which run without a scene and possibly off the
    /// main actor, so they cannot touch the shared instance.
    nonisolated static var isLockActive: Bool {
        UserDefaults.standard.bool(forKey: AppKeys.App.appLockEnabled)
    }

    private(set) var isEnabled: Bool
    private(set) var isLocked: Bool
    private(set) var timing: LockTiming

    /// True while an LAContext prompt is up. The system sheet makes the app
    /// inactive, so without this flag the privacy cover would stack over the
    /// Face ID prompt mid-unlock.
    private var isAuthenticating = false
    /// True between a real background visit and the next activation. A return
    /// to .active always steps through .inactive, so the old phase alone
    /// cannot distinguish "came back from the background" from "dismissed the
    /// Face ID sheet".
    private var returningFromBackground = false
    private var leftForegroundAt: Date?
    private var lockWindow: UIWindow?
    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let enabled = defaults.bool(forKey: AppKeys.App.appLockEnabled)
        isEnabled = enabled
        isLocked = enabled
        timing = LockTiming(rawValue: defaults.string(forKey: AppKeys.App.appLockTiming) ?? "") ?? .immediately
    }

    // MARK: - Unlock Method

    /// Valid only after canEvaluatePolicy has run on the context, hence the throwaway call.
    private var biometryType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        return context.biometryType
    }

    var hasBiometry: Bool { biometryType != .none }

    /// User-facing name of the strongest available unlock method on this device.
    var unlockMethodName: String {
        switch biometryType {
        case .faceID: return Copy.Settings.faceID
        case .touchID: return Copy.Settings.touchID
        default: return Copy.Settings.passcode
        }
    }

    /// Stable analytics key for the same method.
    var unlockMethodKey: String {
        switch biometryType {
        case .faceID: return "face_id"
        case .touchID: return "touch_id"
        default: return "passcode"
        }
    }

    var lockSymbolName: String {
        switch biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        default: return "lock.fill"
        }
    }

    // MARK: - Settings Actions

    /// Confirms the lock works once before persisting it, so a user can never
    /// enable a lock they cannot open.
    func enable() async -> EnableResult {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return .noPasscode
        }
        isAuthenticating = true
        defer { isAuthenticating = false }
        do {
            guard try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: Copy.Settings.appLockAuthReason
            ) else { return .failed }
        } catch {
            return .failed
        }
        isEnabled = true
        defaults.set(true, forKey: AppKeys.App.appLockEnabled)
        defaults.set(Date().timeIntervalSince1970, forKey: AppKeys.App.appLockEnabledAt)
        AppAnalytics.shared.trackAppLockEnabled(timing: timing.rawValue, method: unlockMethodKey)
        return .enabled
    }

    func disable() {
        let enabledAt = defaults.double(forKey: AppKeys.App.appLockEnabledAt)
        let daysActive = enabledAt > 0
            ? Int(Date().timeIntervalSince1970 - enabledAt) / 86_400
            : 0
        isEnabled = false
        isLocked = false
        leftForegroundAt = nil
        defaults.set(false, forKey: AppKeys.App.appLockEnabled)
        defaults.removeObject(forKey: AppKeys.App.appLockEnabledAt)
        AppAnalytics.shared.trackAppLockDisabled(daysActive: daysActive)
    }

    func setTiming(_ newTiming: LockTiming) {
        timing = newTiming
        defaults.set(newTiming.rawValue, forKey: AppKeys.App.appLockTiming)
    }

    /// "Delete All My Data" wipes the account; a lock left armed would wall the
    /// next onboarding behind the previous owner's Face ID.
    func resetForAccountWipe() {
        isEnabled = false
        isLocked = false
        leftForegroundAt = nil
        defaults.removeObject(forKey: AppKeys.App.appLockEnabled)
        defaults.removeObject(forKey: AppKeys.App.appLockTiming)
        defaults.removeObject(forKey: AppKeys.App.appLockEnabledAt)
        hideLockWindow()
    }

    // MARK: - Scene Lifecycle (driven by LasoApp)

    func onLaunch() {
        guard isLocked else { return }
        showLockWindow()
    }

    func sceneWillResignActive() {
        guard isEnabled, !isAuthenticating else { return }
        // Cover only: the app switcher snapshot is taken from the live view
        // while inactive, so waiting for .background would leak health data.
        showLockWindow()
    }

    func sceneDidEnterBackground() {
        guard isEnabled else { return }
        showLockWindow()
        returningFromBackground = true
        if !isLocked && leftForegroundAt == nil {
            leftForegroundAt = Date()
        }
    }

    func sceneDidActivate() {
        guard isEnabled else { return }
        if !isLocked, let left = leftForegroundAt {
            let elapsed = Date().timeIntervalSince(left)
            // A backward clock jump makes elapsed negative; treat it as expired
            // so a date rollback in Settings can never skip the relock.
            if elapsed < 0 || elapsed >= timing.gracePeriod {
                isLocked = true
            }
        }
        leftForegroundAt = nil
        let promptAgain = returningFromBackground
        returningFromBackground = false
        if isLocked {
            showLockWindow()
            // The lock view auto-prompts once when it first appears; a return
            // from the background needs a fresh prompt. An inactive-only
            // excursion (a cancelled Face ID sheet) must not re-prompt, or
            // cancelling would loop forever.
            if promptAgain {
                Task { await requestUnlock() }
            }
        } else {
            hideLockWindow()
        }
    }

    // MARK: - Unlocking

    func requestUnlock() async {
        guard isLocked, !isAuthenticating else { return }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // The device passcode was removed after the lock was enabled, so no
            // policy can ever succeed. Anyone holding an unsecured phone could
            // reach the data regardless, so failing open beats locking the
            // owner out of their own health data forever.
            isLocked = false
            hideLockWindow()
            return
        }
        isAuthenticating = true
        defer { isAuthenticating = false }
        let unlocked = (try? await context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: Copy.Settings.appLockAuthReason
        )) ?? false
        if unlocked {
            isLocked = false
            hideLockWindow()
        }
    }

    // MARK: - Lock Window

    private func showLockWindow() {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let foreground = scenes.first { scene in
            scene.activationState == .foregroundActive || scene.activationState == .foregroundInactive
        }
        guard let scene = foreground ?? scenes.first else { return }
        if let existing = lockWindow {
            if existing.windowScene === scene { return }
            // Window from a disconnected scene renders nowhere; rebuild on the
            // live scene or isLocked would be true with no visible cover.
            existing.isHidden = true
            lockWindow = nil
        }
        // Drop the keyboard before covering: it lives in its own system window
        // above any app window, so a focused field would float its QuickType
        // bar over the cover and keep receiving keystrokes while locked.
        scene.keyWindow?.endEditing(true)
        let window = UIWindow(windowScene: scene)
        window.windowLevel = UIWindow.Level.alert + 1
        window.rootViewController = UIHostingController(rootView: AppLockScreenView(manager: self))
        window.makeKeyAndVisible()
        lockWindow = window
        // ThemeManager sets overrideUserInterfaceStyle by walking live windows,
        // so a window created after that pass needs a re-apply to match a
        // forced light/dark choice.
        ThemeManager.shared.apply()
    }

    private func hideLockWindow() {
        guard let window = lockWindow else { return }
        let scene = window.windowScene
        window.isHidden = true
        lockWindow = nil
        // Hand key status back to the app window, or hardware key events keep
        // landing on the dead lock window.
        scene?.windows.first(where: { !$0.isHidden })?.makeKey()
    }
}

/// Full-screen content of the lock window. Shows the unlock UI while locked
/// and a bare brand mark while merely covering for the app switcher.
struct AppLockScreenView: View {
    var manager: AppLockManager

    var body: some View {
        ZStack {
            AppColour.surfaceBase.ignoresSafeArea()
            if manager.isLocked {
                VStack(spacing: DS.space4) {
                    Image(systemName: manager.lockSymbolName)
                        .font(DS.Typography.heroIcon)
                        .foregroundStyle(AppColour.accent)
                        .padding(.bottom, DS.space2)
                    Text(Copy.Settings.lockedTitle)
                        .font(DS.Typography.title2)
                        .foregroundStyle(AppColour.textPrimary)
                    Text(Copy.Settings.lockedSubtitle)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(AppColour.textSecondary)
                        .multilineTextAlignment(.center)
                    Button {
                        Task { await manager.requestUnlock() }
                    } label: {
                        Text(Copy.Settings.unlockWith(manager.unlockMethodName))
                            .font(DS.Typography.bodySemibold)
                            .foregroundStyle(AppColour.textOnAccent)
                            .padding(.horizontal, DS.space6)
                            .padding(.vertical, DS.space3)
                            .background(AppColour.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, DS.space4)
                    .accessibilityIdentifier("appLock.unlockButton")
                }
                .padding(DS.space7)
            } else {
                Image("LaunchIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .task { await manager.requestUnlock() }
    }
}

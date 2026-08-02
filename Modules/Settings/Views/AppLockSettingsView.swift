import SwiftUI

/// App Lock detail screen: one toggle plus the relock timing choice.
struct AppLockSettingsView: View {
    private var manager: AppLockManager { AppLockManager.shared }

    // Local mirror of manager.isEnabled: the toggle must snap back when the
    // confirmation prompt fails, and SwiftUI only re-reads a binding after a
    // state change it can observe.
    @State private var lockOn = false
    @State private var showNoPasscodeAlert = false

    var body: some View {
        Form {
            Section {
                Toggle(Copy.Settings.requireUnlock(manager.unlockMethodName), isOn: $lockOn)
                    .accessibilityIdentifier("settings.appLock.toggle")
            } footer: {
                Text(
                    manager.hasBiometry
                        ? Copy.Settings.appLockFooterBiometric(manager.unlockMethodName)
                        : Copy.Settings.appLockFooterPasscode
                )
            }

            if manager.isEnabled {
                Section {
                    ForEach(AppLockManager.LockTiming.allCases, id: \.self) { option in
                        Button {
                            guard option != manager.timing else { return }
                            manager.setTiming(option)
                            AppAnalytics.shared.trackSettingChanged(name: "app_lock_timing", value: option.rawValue)
                        } label: {
                            HStack {
                                Text(option.title)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if option == manager.timing {
                                    Image(systemName: "checkmark")
                                        .font(DS.Typography.subheadlineSemibold)
                                        .foregroundStyle(AppColour.accent)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                    }
                } header: {
                    Text(Copy.Settings.lockAfterLeaving)
                } footer: {
                    Text(Copy.Settings.lockTimingFooter)
                }
            }
        }
        .navigationTitle(Copy.Settings.appLock)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            lockOn = manager.isEnabled
            AppAnalytics.shared.trackFeatureOpen(.appLock)
        }
        .onDisappear { AppAnalytics.shared.trackFeatureClose(.appLock) }
        .onChange(of: lockOn) { _, wantOn in
            guard wantOn != manager.isEnabled else { return }
            if wantOn {
                Task {
                    let result = await manager.enable()
                    if result != .enabled { lockOn = false }
                    if result == .noPasscode { showNoPasscodeAlert = true }
                }
            } else {
                manager.disable()
            }
        }
        .alert(Copy.Settings.appLockNoPasscodeTitle, isPresented: $showNoPasscodeAlert) {
        } message: {
            Text(Copy.Settings.appLockNoPasscodeMessage)
        }
    }
}

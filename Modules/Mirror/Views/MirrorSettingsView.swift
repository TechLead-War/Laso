import SwiftUI

/// Archive stats and deletion for Daily Mirror, pushed from Settings. The
/// numbers here are the honest cost of the on-device promise: what is stored,
/// how much space it takes, and the one-tap way to remove all of it.
struct MirrorSettingsView: View {
    private let store = MirrorPhotoStore.shared
    private let manager = MirrorMomentManager.shared
    @State private var confirmDeleteAll = false
    @State private var deleteFailed = false

    @State private var reminderOn = MirrorReminderScheduler.isEnabled
    @State private var reminderDenied = false
    @State private var windowStart = Self.date(fromMinutes: MirrorReminderScheduler.windowStartMinutes)
    @State private var windowEnd = Self.date(fromMinutes: MirrorReminderScheduler.windowEndMinutes)

    var body: some View {
        List {
            promptSection
            reminderSection
            if store.photoCount == 0 {
                Text(Copy.Mirror.settingsEmpty)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(AppColour.textSecondary)
            } else {
                Section {
                    LabeledContent(Copy.Mirror.settingsPhotos, value: "\(store.photoCount)")
                    if let firstDay = store.allDays.first {
                        LabeledContent(Copy.Mirror.settingsSince, value: firstDay.formatted(.dateTime.day().month(.abbreviated).year()))
                    }
                    LabeledContent(Copy.Mirror.settingsStreak, value: Copy.Mirror.streakDays(store.longestStreak))
                    // The MB figure stays: the on-device privacy promise includes
                    // never surprising the user about what the archive costs.
                    LabeledContent(Copy.Mirror.settingsSpace, value: ByteCountFormatter.string(fromByteCount: store.diskBytes, countStyle: .file))
                }

                Section {
                    ForEach(store.allDays.reversed(), id: \.self) { day in
                        HStack {
                            Text(day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year()))
                                .font(DS.Typography.subheadline)
                            Spacer()
                            if let score = store.meta(on: day)?.score {
                                Text("\(score)")
                                    .font(DS.Typography.subheadlineSemibold)
                                    .monospacedDigit()
                                    .foregroundStyle(DS.scoreColor(score))
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                delete(day)
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        confirmDeleteAll = true
                    } label: {
                        Text(Copy.Mirror.settingsDeleteAll)
                    }
                } footer: {
                    Text(Copy.Mirror.settingsFooter)
                }
            }
        }
        .navigationTitle(Copy.Mirror.settingsTitle)
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(AppColour.surfaceBase)
        .confirmationDialog(
            Copy.Mirror.settingsDeleteConfirmTitle,
            isPresented: $confirmDeleteAll,
            titleVisibility: .visible
        ) {
            Button(Copy.Mirror.settingsDeleteAction, role: .destructive) {
                let count = store.photoCount
                do {
                    try store.deleteAll()
                    AppAnalytics.shared.trackBlockTap(
                        title: "Delete mirror archive",
                        type: .mirrorArchiveDeleted,
                        screen: .settings,
                        metadata: ["scope": "all", "photo_count": count]
                    )
                } catch {
                    deleteFailed = true
                }
            }
            Button(Copy.Buttons.cancel, role: .cancel) {}
        } message: {
            Text(Copy.Mirror.settingsFooter)
        }
        .alert(Copy.Mirror.saveFailed, isPresented: $deleteFailed) {
            Button(Copy.Buttons.done, role: .cancel) {}
        }
    }

    // MARK: - Prompt and reminder

    /// The permanent, guilt-free opt-out the daily prompt promises. Flipping
    /// it back on is equally one tap.
    private var promptSection: some View {
        Section {
            Toggle(Copy.Mirror.settingsPromptToggle, isOn: Binding(
                get: { !manager.optedOut },
                set: { enabled in
                    manager.optedOut = !enabled
                    AppAnalytics.shared.trackBlockTap(
                        title: "Mirror prompt toggle",
                        type: .mirrorPromptToggled,
                        screen: .settings,
                        metadata: ["enabled": enabled]
                    )
                }
            ))
        } footer: {
            Text(Copy.Mirror.settingsPromptFooter)
        }
    }

    private var reminderSection: some View {
        Section {
            Toggle(Copy.Mirror.settingsReminderToggle, isOn: Binding(
                get: { reminderOn },
                set: { enabled in setReminder(enabled) }
            ))
            if reminderOn {
                DatePicker(Copy.Mirror.settingsReminderStart, selection: $windowStart, displayedComponents: .hourAndMinute)
                DatePicker(Copy.Mirror.settingsReminderEnd, selection: $windowEnd, displayedComponents: .hourAndMinute)
            }
        } footer: {
            Text(Copy.Mirror.settingsReminderFooter)
        }
        .onChange(of: windowStart) { _, _ in pushWindow() }
        .onChange(of: windowEnd) { _, _ in pushWindow() }
        .alert(Copy.Mirror.settingsReminderDenied, isPresented: $reminderDenied) {
            Button(Copy.Buttons.done, role: .cancel) {}
        }
    }

    private func setReminder(_ enabled: Bool) {
        AppAnalytics.shared.trackBlockTap(
            title: "Mirror reminder toggle",
            type: .mirrorReminderToggled,
            screen: .settings,
            metadata: ["enabled": enabled]
        )
        guard enabled else {
            reminderOn = false
            MirrorReminderScheduler.disable()
            return
        }
        // Optimistic: the permission dialog resigning the app re-renders the
        // toggle, and a still-false backing value would snap the switch off
        // while the dialog is up. Denial reverts it below.
        reminderOn = true
        Task { @MainActor in
            let granted = await MirrorReminderScheduler.enable(
                startMinutes: Self.minutes(from: windowStart),
                endMinutes: Self.minutes(from: windowEnd)
            )
            reminderOn = granted
            if !granted { reminderDenied = true }
        }
    }

    private func pushWindow() {
        let start = Self.minutes(from: windowStart)
        var end = Self.minutes(from: windowEnd)
        // The pickers happily produce end-before-start; the scheduler cannot
        // represent an overnight window, so the UI keeps the pickers honest
        // instead of silently scheduling outside what they display.
        let minimumEnd = min(start + MirrorReminderScheduler.minimumWindowMinutes, 24 * 60 - 1)
        if end < minimumEnd {
            end = minimumEnd
            windowEnd = Self.date(fromMinutes: end)
        }
        MirrorReminderScheduler.updateWindow(startMinutes: start, endMinutes: end)
    }

    private static func date(fromMinutes minutes: Int) -> Date {
        Date.cal.date(byAdding: .minute, value: minutes, to: Date().startOfDay) ?? Date()
    }

    private static func minutes(from date: Date) -> Int {
        let comps = Date.cal.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }

    private func delete(_ day: Date) {
        do {
            try store.delete(on: day)
            AppAnalytics.shared.trackBlockTap(
                title: "Delete mirror photo",
                type: .mirrorArchiveDeleted,
                screen: .settings,
                metadata: ["scope": "single"]
            )
        } catch {
            deleteFailed = true
        }
    }
}

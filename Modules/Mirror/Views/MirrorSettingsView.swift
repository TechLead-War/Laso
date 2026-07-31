import SwiftUI

/// Archive stats and deletion for Daily Mirror, pushed from Settings. The
/// numbers here are the honest cost of the on-device promise: what is stored,
/// how much space it takes, and the one-tap way to remove all of it.
struct MirrorSettingsView: View {
    private let store = MirrorPhotoStore.shared
    @State private var confirmDeleteAll = false
    @State private var deleteFailed = false

    var body: some View {
        List {
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

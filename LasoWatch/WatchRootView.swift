import SwiftUI

/// Everything the wrist shows, in one scroll.
///
/// Deliberately not a port of the Home screen: a 40mm watch is 162 points wide, so
/// there is room for one number, one action and two buttons. Type comes from the
/// system font, matching the widget target's precedent, rather than the app's
/// custom faces which are not bundled here.
struct WatchRootView: View {

    let store: WatchStore

    @State private var showCheckIn = false
    @State private var showJournal = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if let payload = store.payload {
                        readiness(payload)
                        if payload.isStale() {
                            hint(WatchStrings.Home.stale)
                        }
                        if let rejection = store.rejection {
                            hint(WatchStrings.Write.message(for: rejection))
                        }
                        action(payload)
                        if payload.checkInAvailable {
                            Button(WatchStrings.CheckIn.greeting) { showCheckIn = true }
                                .buttonStyle(.bordered)
                        }
                        Button(WatchStrings.Journal.title) { showJournal = true }
                            .buttonStyle(.bordered)
                    } else {
                        hint(store.hasCompanion
                             ? WatchStrings.Home.stale
                             : WatchStrings.Home.notPaired)
                    }
                }
                .padding(.horizontal, 4)
            }
            .navigationTitle("Laso")
            .sheet(isPresented: $showCheckIn) {
                WatchCheckInView(store: store)
            }
            .sheet(isPresented: $showJournal) {
                WatchJournalView(store: store)
            }
        }
    }

    // MARK: - Sections

    private func readiness(_ payload: WatchPayload) -> some View {
        VStack(spacing: 0) {
            Text("\(payload.readinessScore)")
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(WatchStrings.Home.readinessLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
            if !payload.dayType.isEmpty {
                Text(payload.dayType)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func action(_ payload: WatchPayload) -> some View {
        if let headline = payload.actionHeadline {
            VStack(alignment: .leading, spacing: 6) {
                Text(WatchStrings.Home.todaysAction)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(headline)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    store.markActionDone()
                } label: {
                    Label(
                        store.isActionDoneToday ? WatchStrings.Home.markedDone : WatchStrings.Home.markDone,
                        systemImage: store.isActionDoneToday ? "checkmark.circle.fill" : "checkmark"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isActionDoneToday || !store.pendingCommands.isEmpty)
            }
        } else {
            hint(WatchStrings.Home.noAction)
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

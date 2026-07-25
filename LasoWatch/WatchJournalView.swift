import SwiftUI

/// One tap journal logging.
///
/// Each tap records one unit of that category, which is what the wrist can honestly
/// offer. Entering an exact amount stays on the phone, where there is room for a
/// stepper.
struct WatchJournalView: View {

    let store: WatchStore

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(WatchQuickTag.all) { tag in
            Button {
                store.logQuickTag(tag)
                dismiss()
            } label: {
                Label(tag.label, systemImage: tag.systemImage)
            }
        }
        .navigationTitle(WatchStrings.Journal.title)
    }
}

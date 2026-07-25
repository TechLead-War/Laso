import SwiftUI

/// Morning check-in on the wrist.
///
/// The phone owns whether a check-in is offered at all; this view only collects the
/// three answers. Same five point scale and same emoji order as the phone card, so
/// a 3 here means exactly what a 3 means there.
struct WatchCheckInView: View {

    let store: WatchStore

    @Environment(\.dismiss) private var dismiss

    @State private var sleepQuality = 0
    @State private var energyLevel = 0
    @State private var soreness = 0

    private var isComplete: Bool {
        sleepQuality > 0 && energyLevel > 0 && soreness > 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text(WatchStrings.CheckIn.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                row(WatchStrings.CheckIn.sleepQuality, WatchStrings.CheckInScale.sleepQuality, $sleepQuality)
                row(WatchStrings.CheckIn.energyLevel, WatchStrings.CheckInScale.energyLevel, $energyLevel)
                row(WatchStrings.CheckIn.soreness, WatchStrings.CheckInScale.soreness, $soreness)

                Button(WatchStrings.CheckIn.done) {
                    store.submitCheckIn(
                        sleepQuality: sleepQuality,
                        energyLevel: energyLevel,
                        soreness: soreness
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isComplete)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle(WatchStrings.CheckIn.greeting)
    }

    private func row(_ label: String, _ emojis: [String], _ selection: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 2) {
                ForEach(Array(emojis.enumerated()), id: \.offset) { index, emoji in
                    let value = index + 1
                    Button {
                        selection.wrappedValue = value
                    } label: {
                        Text(emoji)
                            .font(.footnote)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(
                                selection.wrappedValue == value ? Color.accentColor.opacity(0.35) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 6)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(label) \(value)")
                }
            }
        }
    }
}

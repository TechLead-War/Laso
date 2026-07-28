import SwiftUI

/// Picks the one wake time the whole app will hold to.
///
/// No weekday/weekend variant by design: offering one would ship the exact
/// social-jetlag pattern the anchor exists to prevent.
struct WakeAnchorSetterSheet: View {

    let initial: (hour: Int, minute: Int)
    /// Used only to preview the bedtime this anchor implies.
    let hoursNeeded: Double
    let onConfirm: ((hour: Int, minute: Int)) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var picked: Date = Date()

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.space5) {
                DatePicker(
                    Copy.WakeAnchor.setterTitle,
                    selection: $picked,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()

                VStack(spacing: DS.space2) {
                    if let bedtime = bedtimePreview {
                        Text(Copy.WakeAnchor.setterBedtimePreview(bedtime))
                            .font(DS.Typography.subheadlineSemibold)
                    }
                    Text(Copy.WakeAnchor.setterRangeNote)
                        .font(DS.Typography.footnote)
                        .foregroundStyle(AppColour.textTertiary)
                }

                Text(Copy.WakeAnchor.setterFooter)
                    .font(DS.Typography.footnote)
                    .foregroundStyle(AppColour.textTertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                Button(Copy.WakeAnchor.setterConfirm) {
                    onConfirm(clampedSelection)
                    dismiss()
                }
                .buttonStyle(.dsPrimary)
            }
            .padding(DS.space5)
            .background(AppColour.surfaceElevated.ignoresSafeArea())
            .navigationTitle(Copy.WakeAnchor.setterTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Copy.Buttons.cancel) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            var comps = DateComponents()
            comps.hour = initial.hour
            comps.minute = initial.minute
            picked = Date.cal.date(from: comps) ?? Date()
        }
    }

    /// The wheel cannot be range-limited, so the selection is clamped to the
    /// same 5–11 band every scheduler enforces. Outside it, the morning
    /// reminder is a repeating trigger that quiet hours drops silently.
    private var clampedSelection: (hour: Int, minute: Int) {
        let comps = Date.cal.dateComponents([.hour, .minute], from: picked)
        return WakeUpTimeDetector.clamped(
            hour: comps.hour ?? WakeUpTimeDetector.fallbackHour,
            minute: comps.minute ?? WakeUpTimeDetector.fallbackMinute,
            origin: "anchor_picker"
        )
    }

    private var bedtimePreview: String? {
        var comps = DateComponents()
        comps.hour = clampedSelection.hour
        comps.minute = clampedSelection.minute
        guard let wake = Date.cal.date(from: comps) else { return nil }
        return wake
            .addingTimeInterval(-hoursNeeded * 3600)
            .formatted(date: .omitted, time: .shortened)
    }
}

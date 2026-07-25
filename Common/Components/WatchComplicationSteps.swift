import SwiftUI

/// The three steps for putting the readiness complication on the watch face.
///
/// Shared so the Home card and the Apple Watch device screen can never drift apart.
/// The numbers are load bearing here, the order is the instruction.
struct WatchComplicationSteps: View {

    var body: some View {
        VStack(alignment: .leading, spacing: DS.space2) {
            step(1, Copy.Devices.WatchComplication.stepOne)
            step(2, Copy.Devices.WatchComplication.stepTwo)
            step(3, Copy.Devices.WatchComplication.stepThree)
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: DS.space2) {
            Text("\(number)")
                .font(DS.Typography.caption2)
                .foregroundStyle(AppColour.textSecondary)
                .frame(width: 16, alignment: .center)

            Text(text)
                .font(DS.Typography.footnote)
                .foregroundStyle(AppColour.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

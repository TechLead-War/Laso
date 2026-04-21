import SwiftUI

struct StatBoxView: View {
    let label: String
    let value: String
    let color: Color
    var suffix: String? = nil

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let suffix {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(color)
                        .postHogMask()

                    Text(suffix)
                        .font(.caption2.weight(.medium).monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            } else {
                Text(value)
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(color)
                    .postHogMask()
            }
        }
        .frame(maxWidth: .infinity)
    }
}

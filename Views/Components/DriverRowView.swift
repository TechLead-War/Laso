import SwiftUI

struct DriverRowView: View {
    let label: String
    let icon: String
    let value: Double
    let color: Color
    var isEstimate: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(label)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)

                        if isEstimate {
                            Text(Copy.BrainHealth.estimated)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color(.systemGray5), in: Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text("\(Int(min(max(value, 0), 1.0) * 100))%")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(color)
                        .frame(minWidth: 40, alignment: .trailing)
                        .postHogMask()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ProgressBarView(
                    fraction: value,
                    color: isEstimate ? color.opacity(0.5) : color,
                    height: 6
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

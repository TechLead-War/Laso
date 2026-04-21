import SwiftUI

/// Grid displaying key statistics for a metric
struct StatisticsGrid: View {
    let stats: [(label: String, value: String)]

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                VStack(spacing: 4) {
                    Text(stat.value)
                        .font(.title3.weight(.semibold).monospacedDigit())

                    Text(stat.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    StatisticsGrid(stats: [
        (label: "Current", value: "68"),
        (label: "Average", value: "65"),
        (label: "Min", value: "58"),
        (label: "Max", value: "74"),
        (label: "Std Dev", value: "4.2"),
        (label: "WoW", value: "+3.1%"),
    ])
    .padding()
}

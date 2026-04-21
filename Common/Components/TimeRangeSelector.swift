import SwiftUI

/// Segmented picker for selecting time range (7d, 30d, 90d)
struct TimeRangeSelector: View {
    @Binding var selectedDays: Int

    private let options: [(label: String, days: Int)] = [
        ("7D", 7),
        ("30D", 30),
        ("3M", 90),
        ("6M", 180)
    ]

    var body: some View {
        Picker("Time Range", selection: $selectedDays) {
            ForEach(options, id: \.days) { option in
                Text(option.label).tag(option.days)
            }
        }
        .pickerStyle(.segmented)
    }
}

#Preview {
    TimeRangeSelector(selectedDays: .constant(30))
        .padding()
}

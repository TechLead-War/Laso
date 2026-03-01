import SwiftUI

/// Greeting header with time-based salutation, date, and settings button
struct CoachGreetingView: View {
    let showSettings: Binding<Bool>

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.title2.weight(.bold))

                Text(dateString)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                AppAnalytics.shared.trackBlockTap(title: "Settings", type: .settingsGear, screen: .home)
                showSettings.wrappedValue = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<22: return "Good Evening"
        default: return "Good Night"
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    private var dateString: String {
        Self.dateFormatter.string(from: Date())
    }
}

#Preview {
    CoachGreetingView(
        showSettings: .constant(false)
    )
}

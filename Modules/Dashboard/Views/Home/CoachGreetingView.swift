import SwiftUI

/// Compact greeting header. Shows "Good morning, {Name}" + the full date,
/// matching the Apple-style header the user requested. Name is read from
/// `UserProfileStore.shared.storedName()`, populated from Sign In with Apple
/// on first authorization. If no name is available, the comma is dropped.
struct CoachGreetingView: View {

    @State private var firstName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(greetingTitle)
                .font(DS.Typography.title2)
                .fontWeight(.bold)
                .foregroundStyle(AppColour.textPrimary)
            Text(dateLine)
                .font(DS.Typography.body)
                .foregroundStyle(AppColour.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.screenPadding)
        .padding(.top, 2)
        .onAppear { firstName = Self.loadFirstName() }
    }

    // MARK: - Strings

    private var greetingTitle: String {
        if let name = firstName, !name.isEmpty {
            return "\(contextGreeting), \(name)"
        }
        return contextGreeting
    }

    /// Locale-aware "Tuesday, April 26" style line.
    private var dateLine: String {
        Date().formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    // MARK: - Time-of-day

    private var timeOfDay: TimeOfDay {
        let hour = Date.cal.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return .morning
        case 12..<17: return .afternoon
        case 17..<22: return .evening
        default:      return .night
        }
    }

    private enum TimeOfDay {
        case morning, afternoon, evening, night
    }

    private var contextGreeting: String {
        switch timeOfDay {
        case .morning:   return Copy.Home.Greeting.goodMorning
        case .afternoon: return Copy.Home.Greeting.goodAfternoon
        case .evening:   return Copy.Home.Greeting.goodEvening
        case .night:     return Copy.Home.Greeting.goodNight
        }
    }

    // MARK: - Name lookup

    /// Reads the encrypted display name and returns just the first whitespace
    /// segment so "Aman Kumar" renders as "Aman" in the greeting. Honors the
    /// `--ui-test-override-name=` launch flag so screenshot tooling can pin the
    /// rendered name without going through Sign In with Apple.
    private static func loadFirstName() -> String? {
        let raw: String?
        if let override = UITestMode.overrideName, !override.isEmpty {
            raw = override
        } else {
            raw = UserProfileStore.shared.storedName()
        }
        guard let stored = raw else { return nil }
        let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.split(separator: " ").first.map(String.init)
    }
}

#Preview {
    VStack(spacing: 20) {
        CoachGreetingView()
        Divider()
        CoachGreetingView()
    }
}

import SwiftUI

/// The last seven days as dials, so a week of history is readable without
/// leaving Home. Biology still owns the full month; this is the glance.
///
/// Ends on today rather than running Monday to Sunday: a fixed calendar week
/// leaves most of the row empty on a Monday, and the useful question is "how
/// have the last seven days gone", not "how is this calendar week going".
struct WeekScoreStrip: View {
    /// Daily scores keyed by start-of-day, exactly as the month calendar reads
    /// them, so the two surfaces can never disagree about the same day.
    let scoresByDay: [Date: Int]
    var onTap: (() -> Void)?

    private static let dayCount = 7

    private var days: [Date] {
        let today = Date.cal.startOfDay(for: Date())
        return (0..<Self.dayCount)
            .compactMap { Date.cal.date(byAdding: .day, value: -$0, to: today) }
            .reversed()
    }

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { day in
                    dayColumn(day)
                }
            }
            .padding(DS.cardPadding)
            .cardStyle()
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("home.weekStrip")
        .accessibilityLabel(Copy.Home.weekStripAccessibility)
    }

    private func dayColumn(_ day: Date) -> some View {
        let isToday = Date.cal.isDateInToday(day)

        return VStack(spacing: DS.space1) {
            Text(Self.weekdayInitial(day))
                .font(DS.Typography.caption2)
                .foregroundStyle(isToday ? AppColour.textPrimary : AppColour.textTertiary)

            DayScoreDial(score: scoresByDay[day])
                .frame(width: 26, height: 26)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.space1)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .fill(isToday ? AppColour.surfaceSubtle : Color.clear)
        )
    }

    /// Locale's own very-short symbol, so this reads correctly outside English.
    private static func weekdayInitial(_ day: Date) -> String {
        let index = Date.cal.component(.weekday, from: day) - 1
        let symbols = Date.cal.veryShortStandaloneWeekdaySymbols
        guard symbols.indices.contains(index) else { return "" }
        return symbols[index]
    }
}

#Preview {
    let today = Date.cal.startOfDay(for: Date())
    let scores: [Date: Int] = Dictionary(
        uniqueKeysWithValues: (0..<5).compactMap { offset in
            Date.cal.date(byAdding: .day, value: -offset, to: today).map { ($0, 90 - offset * 9) }
        }
    )
    return WeekScoreStrip(scoresByDay: scores)
        .padding()
        .background(AppColour.surfaceSunken)
}

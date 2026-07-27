import SwiftUI

/// A month of daily scores, one cell per day, coloured by the same three band
/// model the home ring uses. This is the only surface that answers "is anything
/// actually getting better", so it never invents a day: a date with no stored
/// snapshot renders empty rather than as a zero.
struct ExploreMonthCalendarSection: View {
    /// Score per day, keyed by `startOfDay`.
    let scoresByDay: [Date: Int]

    @State private var selectedDay: Date?

    private var today: Date { Date.cal.startOfDay(for: Date()) }

    /// Every day of the current month, plus leading blanks so the first day
    /// lands under its real weekday column.
    private var cells: [Date?] {
        guard let interval = Date.cal.dateInterval(of: .month, for: today) else { return [] }
        let firstDay = interval.start
        let dayCount = Date.cal.range(of: .day, in: .month, for: firstDay)?.count ?? 0
        // `firstWeekday` is 1-based and locale dependent, so a Monday-first
        // locale must not be hard coded to Sunday's offset.
        let weekdayOfFirst = Date.cal.component(.weekday, from: firstDay)
        let leading = (weekdayOfFirst - Date.cal.firstWeekday + 7) % 7

        let days = (0..<dayCount).compactMap {
            Date.cal.date(byAdding: .day, value: $0, to: firstDay)
        }
        return Array(repeating: nil, count: leading) + days.map { Optional($0) }
    }

    private var scoredThisMonth: Int {
        cells.compactMap { $0 }.filter { scoresByDay[$0] != nil }.count
    }

    private var daysElapsed: Int {
        cells.compactMap { $0 }.filter { $0 <= today }.count
    }

    /// Consecutive scored days ending today or yesterday. Counting from
    /// yesterday too means the streak does not read as broken before the day's
    /// own score has been written.
    private var streak: Int {
        var count = 0
        var cursor = scoresByDay[today] != nil
            ? today
            : (Date.cal.date(byAdding: .day, value: -1, to: today) ?? today)
        while scoresByDay[cursor] != nil {
            count += 1
            guard let previous = Date.cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            header
            weekdayHeader
            grid
            Divider().overlay(AppColour.borderLow)
            selectedDayRow
            streakRow
        }
        .padding(DS.cardPadding)
        .cardStyle()
        .accessibilityIdentifier("explore.monthCalendar")
    }

    private var header: some View {
        HStack {
            Text(Copy.Explore.monthTitle)
                .font(DS.Typography.headline)
                .foregroundStyle(AppColour.textPrimary)
            Spacer()
            Text(selectedDay == nil ? Copy.Explore.monthTapHint : Copy.Explore.monthToday)
                .font(DS.Typography.caption)
                .foregroundStyle(AppColour.textTertiary)
                .onTapGesture { selectedDay = nil }
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 6) {
            ForEach(orderedWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(DS.Typography.caption2)
                    .foregroundStyle(AppColour.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    /// Calendar symbols rotated to the locale's first weekday, so the column
    /// headings line up with the leading blanks computed above.
    private var orderedWeekdaySymbols: [String] {
        let symbols = Date.cal.veryShortStandaloneWeekdaySymbols
        let offset = Date.cal.firstWeekday - 1
        return Array(symbols[offset...] + symbols[..<offset])
    }

    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 34)
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let score = scoresByDay[day]
        let isFuture = day > today
        let tint: Color = score.map { DashboardViewModel.RecoveryState(score: $0).color }
            ?? AppColour.textTertiary.opacity(isFuture ? 0.12 : 0.28)

        return Button {
            selectedDay = (selectedDay == day) ? nil : day
        } label: {
            Text("\(Date.cal.component(.day, from: day))")
                .font(DS.Typography.caption)
                .foregroundStyle(score == nil ? AppColour.textTertiary : AppColour.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(tint.opacity(score == nil ? 0.0 : 0.14), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .strokeBorder(tint, lineWidth: selectedDay == day ? 2 : 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(accessibilityLabel(day: day, score: score))
    }

    private func accessibilityLabel(day: Date, score: Int?) -> String {
        let date = day.formatted(.dateTime.weekday(.wide).day().month(.wide))
        guard let score else { return "\(date). \(Copy.Explore.monthNoScore)" }
        return "\(date). \(Copy.Explore.monthDayScore(score, DashboardViewModel.RecoveryState(score: score).plainName))"
    }

    /// The tapped day, or today when nothing is selected, so the row always
    /// carries a real reading instead of sitting empty.
    private var selectedDayRow: some View {
        let day = selectedDay ?? today
        let score = scoresByDay[day]
        return HStack(alignment: .firstTextBaseline) {
            Text(day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(DS.Typography.subheadline)
                .foregroundStyle(AppColour.textSecondary)
            Spacer(minLength: 8)
            if let score {
                Text(Copy.Explore.monthDayScore(score, DashboardViewModel.RecoveryState(score: score).plainName))
                    .font(DS.Typography.headline)
                    .foregroundStyle(DashboardViewModel.RecoveryState(score: score).color)
            } else {
                Text(Copy.Explore.monthNoScore)
                    .font(DS.Typography.footnote)
                    .foregroundStyle(AppColour.textTertiary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var streakRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(Copy.Explore.monthStreakDays(streak))
                    .font(DS.Typography.headline)
                    .foregroundStyle(AppColour.textPrimary)
                Text(Copy.Explore.monthStreakLabel)
                    .font(DS.Typography.caption)
                    .foregroundStyle(AppColour.textTertiary)
            }
            Spacer(minLength: 8)
            Text(Copy.Explore.monthScoredDays(scoredThisMonth, daysElapsed))
                .font(DS.Typography.caption)
                .foregroundStyle(AppColour.textTertiary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

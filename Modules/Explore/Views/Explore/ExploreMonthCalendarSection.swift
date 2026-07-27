import SwiftUI

/// A month of daily scores, one dial per day, coloured by the same three band
/// model the home ring uses. This is the only surface that answers "is anything
/// actually getting better", so it never invents a day: a date with no stored
/// snapshot renders as an empty dial rather than as a zero.
///
/// The dial reads as a quantity, not just a band. A filled tile said only which
/// of three buckets a day fell in, so 52 and 74 looked identical; the arc shows
/// how far into the band the day actually was.
struct ExploreMonthCalendarSection: View, Equatable {
    /// Score per day, keyed by `startOfDay`.
    let scoresByDay: [Date: Int]
    /// The life contexts switched on for a given day, finished ones included.
    /// A dip explains itself when the calendar can say it was the injured week.
    /// A value rather than a closure so the whole input can be compared.
    let contextsByDay: [Date: [LifeContextStore.Context]]
    /// Everything the app can honestly say about one past day.
    let detailForDay: (Date) -> DashboardViewModel.DayDetail

    /// This card is the most expensive thing the app draws: 31 day dials in one
    /// view, measured at 88 ms to rasterize. Comparing its inputs lets SwiftUI
    /// skip it entirely when a parent rebuilds for an unrelated reason, which is
    /// what used to repaint it mid-scroll.
    ///
    /// `detailForDay` is excluded on purpose: it runs only when a day is tapped
    /// and reads live view-model state at that moment, so it cannot go stale.
    /// Everything actually drawn comes from the two dictionaries above.
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.scoresByDay == rhs.scoresByDay && lhs.contextsByDay == rhs.contextsByDay
    }

    @State private var monthAnchor: Date = Date.cal.startOfDay(for: Date())
    @State private var selectedDay: SelectedDay?

    private var today: Date { Date.cal.startOfDay(for: Date()) }

    /// Every day of the anchored month, plus leading blanks so the first day
    /// lands under its real weekday column.
    private var cells: [Date?] {
        guard let interval = Date.cal.dateInterval(of: .month, for: monthAnchor) else { return [] }
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

    private var isViewingCurrentMonth: Bool {
        Date.cal.isDate(monthAnchor, equalTo: today, toGranularity: .month)
    }

    private var scoredThisMonth: Int {
        cells.compactMap { $0 }.filter { scoresByDay[$0] != nil }.count
    }

    private var daysElapsed: Int {
        cells.compactMap { $0 }.filter { $0 <= today }.count
    }

    /// Consecutive scored days ending today or yesterday. Counting from
    /// yesterday too means the streak does not read as broken before the day's
    /// own score has been written. Always measured from today, not from the
    /// month being viewed, so paging back cannot appear to change it.
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
            footerRow
        }
        .padding(DS.cardPadding)
        .cardStyle()
        .accessibilityIdentifier("explore.monthCalendar")
        .sheet(item: $selectedDay) { selection in
            ExploreDaySheet(detail: detailForDay(selection.date))
        }
    }

    private var header: some View {
        HStack {
            Text(monthAnchor.formatted(.dateTime.month(.wide).year()))
                .font(DS.Typography.headline)
                .foregroundStyle(AppColour.textPrimary)
            Spacer()
            HStack(spacing: 6) {
                monthButton(step: -1, systemImage: "chevron.left", label: Copy.Explore.monthPrevious)
                monthButton(step: 1, systemImage: "chevron.right", label: Copy.Explore.monthNext)
            }
        }
    }

    private func monthButton(step: Int, systemImage: String, label: String) -> some View {
        // Forward is dead on the current month: there is nothing recorded ahead
        // of today, so paging into it would only show an empty grid.
        let disabled = step > 0 && isViewingCurrentMonth
        return Button {
            guard let moved = Date.cal.date(byAdding: .month, value: step, to: monthAnchor) else { return }
            AppAnalytics.shared.trackBlockTap(
                title: "Month Step",
                type: .exploreCalendarMonthStep,
                screen: .explore,
                metadata: ["step": step]
            )
            monthAnchor = moved
        } label: {
            Image(systemName: systemImage)
                .font(DS.Typography.footnoteMedium)
                .foregroundStyle(disabled ? AppColour.textQuaternary : AppColour.textSecondary)
                .frame(width: 30, height: 30)
                .background(AppColour.surfaceRaised, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(label)
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
                    Color.clear.frame(height: Self.cellHeight)
                }
            }
        }
    }

    private static let cellHeight: CGFloat = 58

    private func dayCell(_ day: Date) -> some View {
        let score = scoresByDay[day]
        let isFuture = day > today
        let isToday = day == today
        let contexts = contextsByDay[day] ?? []

        return Button {
            AppAnalytics.shared.trackBlockTap(
                title: "Calendar Day",
                type: .exploreCalendarDay,
                screen: .explore,
                metadata: ["has_score": score != nil, "is_today": isToday]
            )
            selectedDay = SelectedDay(date: day)
        } label: {
            VStack(spacing: 1) {
                DayScoreDial(score: isFuture ? nil : score)
                    .frame(width: 26, height: 26)
                Text("\(Date.cal.component(.day, from: day))")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(dayNumberColour(isToday: isToday, isFuture: isFuture, hasScore: score != nil))
                if let context = contexts.first {
                    Image(systemName: context.systemImage)
                        .font(.system(size: 7))
                        .foregroundStyle(AppColour.accent)
                } else {
                    // Holds the row height steady so marked and unmarked days
                    // do not shift each other around the grid.
                    Color.clear.frame(height: 8)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: Self.cellHeight)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(isToday ? AppColour.surfaceRaised : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityIdentifier("explore.monthCalendar.day")
        .accessibilityLabel(accessibilityLabel(day: day, score: score, contexts: contexts))
    }

    private func dayNumberColour(isToday: Bool, isFuture: Bool, hasScore: Bool) -> Color {
        if isToday { return AppColour.accent }
        if isFuture || !hasScore { return AppColour.textTertiary }
        return AppColour.textPrimary
    }

    private func accessibilityLabel(day: Date, score: Int?, contexts: [LifeContextStore.Context]) -> String {
        let date = day.formatted(.dateTime.weekday(.wide).day().month(.wide))
        var parts = [date]
        if let score {
            parts.append(Copy.Explore.monthDayScore(score, DashboardViewModel.RecoveryState(score: score).plainName))
        } else {
            parts.append(Copy.Explore.monthNoScore)
        }
        if let context = contexts.first {
            parts.append(Copy.Explore.dayContext(context.displayName.lowercasedFirst))
        }
        return parts.joined(separator: ". ")
    }

    private var footerRow: some View {
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
            if isViewingCurrentMonth {
                Text(Copy.Explore.monthScoredDays(scoredThisMonth, daysElapsed))
                    .font(DS.Typography.caption)
                    .foregroundStyle(AppColour.textTertiary)
                    .multilineTextAlignment(.trailing)
                    .accessibilityIdentifier("explore.monthCalendar.scoredDays")
            } else {
                Button {
                    AppAnalytics.shared.trackBlockTap(
                        title: "Today",
                        type: .exploreCalendarToday,
                        screen: .explore
                    )
                    monthAnchor = today
                } label: {
                    Text(Copy.Explore.monthToday)
                        .font(DS.Typography.footnoteMedium)
                        .foregroundStyle(AppColour.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppColour.accent.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// A ring of ticks, filled in proportion to the day's score and tinted by its
/// band. An empty dial means the day was never scored, which is a different
/// thing from a low score and has to look different.
private struct DayScoreDial: View {
    let score: Int?

    private static let tickCount = 20

    private static func litTickCount(for score: Int?) -> Int {
        guard let score else { return 0 }
        let fraction = Double(score) / 100
        return Int((Double(tickCount) * fraction).rounded())
    }

    private static func tickPath(index: Int, in size: CGSize) -> Path {
        let angle: Double = (Double(index) / Double(tickCount)) * 2 * .pi - .pi / 2
        let centreX: Double = size.width / 2
        let centreY: Double = size.height / 2
        let inner: Double = size.width * 0.30
        let outer: Double = size.width * 0.48
        let cosine: Double = cos(angle)
        let sine: Double = sin(angle)

        var path = Path()
        path.move(to: CGPoint(x: centreX + inner * cosine, y: centreY + inner * sine))
        path.addLine(to: CGPoint(x: centreX + outer * cosine, y: centreY + outer * sine))
        return path
    }

    var body: some View {
        Canvas { context, size in
            let lit: Int = Self.litTickCount(for: score)
            let tint: Color = score.map { DashboardViewModel.RecoveryState(score: $0).color } ?? AppColour.borderLow

            for index in 0..<Self.tickCount {
                let path = Self.tickPath(index: index, in: size)
                let colour: Color = index < lit ? tint : AppColour.borderLow
                context.stroke(path, with: .color(colour), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
            }
        }
        .accessibilityHidden(true)
    }
}

/// Lets a tapped day drive `.sheet(item:)`. A wrapper rather than a retroactive
/// `Identifiable` on `Date`, which would apply to every date in the app.
private struct SelectedDay: Identifiable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSince1970 }
}

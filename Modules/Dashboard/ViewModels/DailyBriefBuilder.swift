import Foundation

/// Turns one refresh's worth of engine output into the Today tab.
///
/// Pure on purpose: every input arrives in `Snapshot`, so a test can hand it a
/// morning and read the brief back without HealthKit, SwiftData or the
/// analysis engine, and the dashboard can diff two briefs to skip a republish.
struct DailyBriefBuilder {

    struct Snapshot {
        var now: Date
        var readiness: Int?
        /// Morning locks, oldest first. `build` sorts them; the static pieces assume it.
        var readinessHistory: [(date: Date, score: Int)]
        var trajectory: TrendDirection?
        var anomalies: [AnomalyDetector.AnomalyResult]
        var restDeficit: RecoveryAnalyzer.RestDeficit?
        /// Rest taken whether or not it is short. The focus KPI reads this so it keeps
        /// moving after the deficit clears, which is exactly when it matters most.
        var restSummary: RecoveryAnalyzer.RestDeficit? = nil
        var sleepDebt: SleepDebtTracker.SleepDebtInfo?
        var sleepDebtTrend: SleepDebtTracker.DebtTrend
        var hrr: (current: Double, baseline: UserBaseline)?
        var strainLast6: [Double]
        var strainTarget: StrainCoach.StrainTarget?
        var baselines: [HealthMetric: UserBaseline]
        var latest: [HealthMetric: Double]
        var stressLevel: Int?
        /// Already computed with `daytimeOnly: true`, so a bedtime can never be the day move.
        var advisor: DashboardSmartActionAdvisor.Recommendation
        var exerciseMinutes: Double
        var exerciseGoal: Double
        var sleepNeed: SleepNeed?
        var restContext: LifeContextStore.Context?
        var dayDone: Bool
        var nightDone: Bool
        var nightDoneYesterday: Bool
        var dayReminderFire: Date?
        var nightReminderFire: Date?
        var focus: FocusStore.FocusRecord?
        var verdict: DailyBrief.Verdict?
    }

    private static let daysPerWeek = 7
    /// One week of morning locks is the least the brief needs before it names
    /// drivers or starts a focus; under it the person's usual is unknown.
    private static let learningDays = daysPerWeek
    /// `RecoveryAnalyzer.RestDeficit` counts rest over 28 days (`restDays28`).
    private static let restWindowDays = 28
    private static let restWindowWeeks = restWindowDays / daysPerWeek
    /// `ReadinessScorer.stressLabel` starts "High" at 60 inline, with no named
    /// constant to share, so this mirrors it.
    private static let stressHighFloor = 60
    /// A driver scoring this high reads red; the ranking table puts a four-week
    /// rest deficit or a growing sleep balance there.
    private static let poorToneScore = 4.0
    /// Mirrors `WindDownScheduler.leadMinutes`, private there: the night
    /// reminder label must name the time the existing wind-down push fires.
    private static let nightReminderLeadMinutes = 60
    /// "In bed now" stays tappable this long after the target so a late night
    /// still logs against it, without letting a 3am tap count.
    private static let inBedWindowAfterMinutes = 120

    private static let dayOverrideBlockedSources: Set<String> = ["life_context", "recovery_gate"]
    private static let headlineMoveNotPushDrivers: Set<DriverKind> = [.restDays, .heartRateBounceBack, .strainHigh]

    func build(_ input: Snapshot) -> DailyBrief {
        var s = input
        s.readinessHistory.sort { $0.date < $1.date }
        let thin = s.readinessHistory.count < Self.learningDays
        let drivers = thin ? [] : Self.rankDrivers(s, limit: DailyBriefConfig.driverCount)
        let focus: DailyBrief.FocusView? = thin ? nil : s.focus.map { record in
            Self.focusView(record, now: s.now,
                           driverLine: drivers.first { $0.kind == record.driver }?.sentence)
        }
        let footer = s.verdict == nil
            ? Copy.DailyBrief.footerTomorrow
            : Copy.DailyBrief.footerNextVerdict(Date.cal.weekdaySymbols[0])
        return DailyBrief(
            status: Self.status(s, topDrivers: drivers),
            drivers: drivers,
            dayMove: Self.dayMove(s, drivers: drivers),
            nightMove: Self.nightMove(s),
            focus: focus,
            verdict: s.verdict,
            footer: footer
        )
    }

    // MARK: - Drivers

    private struct Scored {
        let score: Double
        let kind: DriverKind
        let title: String
        let valueText: String
        let sentence: String
        let band: UsualBand?
    }

    /// Deterministic: score descending, then the ranking table's own order.
    static func rankDrivers(_ s: Snapshot, limit: Int) -> [DailyBrief.Driver] {
        var candidates: [Scored] = []

        if let rest = s.restDeficit {
            let need = rest.recommendedPerWeek
            candidates.append(Scored(
                score: 3 + Double(need * restWindowWeeks - rest.restDays28) / Double(restWindowWeeks),
                kind: .restDays,
                title: Copy.DailyBrief.Driver.restDaysTitle,
                valueText: Copy.DailyBrief.Driver.restDaysValue(rest.restDays28, restWindowDays),
                sentence: Copy.DailyBrief.Driver.restDaysSentence(rest.workoutDays28, rest.restDays28, need),
                band: UsualBand(low: Double(need), high: Double(need + 1), value: rest.restPerWeek,
                                rangeText: Copy.DailyBrief.Detail.restUsualStatus(need))
            ))
        }

        if let debt = s.sleepDebt?.totalDebtHours, debt >= DailyBriefConfig.sleepBalanceDriverHours {
            let growing = s.sleepDebtTrend == .increasing
            let nights = SleepDebtTracker.nightsToClear(debtHours: debt)
            candidates.append(Scored(
                score: 2 + debt / 2 + (growing ? 1 : 0),
                kind: .sleepBalance,
                title: Copy.DailyBrief.Driver.sleepBalanceTitle,
                valueText: debt.hoursAsClock,
                sentence: growing
                    ? Copy.DailyBrief.Driver.sleepBalanceGrowing(nights)
                    : Copy.DailyBrief.Driver.sleepBalanceSentence(nights),
                band: usualBand(metric: .sleepDuration, value: s.latest[.sleepDuration], baseline: s.baselines[.sleepDuration])
            ))
        }

        if let hrr = s.hrr, hrr.baseline.mean > 0,
           hrr.current < hrr.baseline.mean * (1 - DailyBriefConfig.hrrOffUsualPercent / 100) {
            let pctOff = (1 - hrr.current / hrr.baseline.mean) * 100
            candidates.append(Scored(
                // Lower base than rest days on purpose: a missed rest day has a lever the
                // person controls today, so bounce-back only leads when it is far off.
                score: 1.5 + pctOff / 5,
                kind: .heartRateBounceBack,
                title: Copy.DailyBrief.Driver.hrrTitle,
                valueText: Copy.DailyBrief.Driver.hrrValue(Int(pctOff.rounded())),
                sentence: Copy.DailyBrief.Driver.hrrSentence,
                band: usualBand(metric: .heartRateRecovery, value: hrr.current, baseline: hrr.baseline)
            ))
        }

        if let target = s.strainTarget {
            let days = s.strainLast6.filter { $0 > target.maxStrain }.count
            if days >= DailyBriefConfig.strainHighDaysOfSix {
                candidates.append(Scored(
                    score: 2,
                    kind: .strainHigh,
                    title: Copy.DailyBrief.Driver.strainTitle,
                    valueText: Copy.DailyBrief.Driver.strainValue(days),
                    sentence: Copy.DailyBrief.Driver.strainSentence(Int(target.minStrain), Int(target.maxStrain), days),
                    band: usualBand(metric: .activeCalories, value: s.latest[.activeCalories], baseline: s.baselines[.activeCalories])
                ))
            }
        }

        if let stress = s.stressLevel, stress >= stressHighFloor {
            candidates.append(Scored(
                score: 1.5,
                kind: .stressHigh,
                title: Copy.DailyBrief.Driver.stressTitle,
                valueText: String(stress),
                sentence: Copy.DailyBrief.Driver.stressSentence,
                band: usualBand(metric: .heartRateVariability, value: s.latest[.heartRateVariability], baseline: s.baselines[.heartRateVariability])
            ))
        }

        // A metric a named driver already explains must not appear a second
        // time as a bare anomaly, and one metric gets one row.
        var covered = Set(candidates.map(\.kind.metric))
        for anomaly in s.anomalies where anomaly.severity >= .warning && !covered.contains(anomaly.metric) {
            covered.insert(anomaly.metric)
            let reading = anomaly.metric.formatWithUnit(anomaly.currentValue)
            let verdict = MetricVerdict.make(metric: anomaly.metric, value: anomaly.currentValue, baseline: s.baselines[anomaly.metric])
            candidates.append(Scored(
                score: 1 + abs(anomaly.zScore) + (anomaly.severity == .critical ? 1 : 0),
                kind: .anomaly(anomaly.metric),
                title: Copy.DailyBrief.Driver.anomalyTitle(
                    anomaly.metric.displayName,
                    anomaly.isAboveBaseline ? Copy.DailyBrief.Driver.above : Copy.DailyBrief.Driver.below),
                valueText: Copy.DailyBrief.Driver.anomalyValue(Int(abs(anomaly.deviationPercent).rounded())),
                sentence: verdict.map { Copy.DailyBrief.Driver.anomalySentence(reading, $0.rangeText) }
                    ?? Copy.DailyBrief.Driver.anomalySentencePlain(reading),
                band: verdict.map { UsualBand(low: $0.low, high: $0.high, value: anomaly.currentValue, rangeText: $0.rangeText) }
            ))
        }

        return candidates.enumerated()
            .sorted { a, b in
                a.element.score != b.element.score ? a.element.score > b.element.score : a.offset < b.offset
            }
            .prefix(max(0, limit))
            .map { entry in
                let c = entry.element
                return DailyBrief.Driver(
                    kind: c.kind, title: c.title, valueText: c.valueText, sentence: c.sentence,
                    tone: c.score >= poorToneScore ? .poor : .fair, band: c.band
                )
            }
    }

    private static func usualBand(metric: HealthMetric, value: Double?, baseline: UserBaseline?) -> UsualBand? {
        guard let value,
              let verdict = MetricVerdict.make(metric: metric, value: value, baseline: baseline) else { return nil }
        return UsualBand(low: verdict.low, high: verdict.high, value: value, rangeText: verdict.rangeText)
    }

    // MARK: - Status

    static func status(_ s: Snapshot, topDrivers: [DailyBrief.Driver]) -> DailyBrief.Status {
        let history = s.readinessHistory
        let score = s.readiness ?? history.last?.score
        let tier = score.map(DS.recoveryTier(for:))
        let sparkline = history.suffix(DailyBriefConfig.readinessWindowDays)
            .map { TrendSparkPoint(date: $0.date, value: Double($0.score)) }
        let band = PersonalBand.make(from: history.suffix(DailyBriefConfig.readinessBandDays).map { Double($0.score) })
        var chips: [DailyBrief.Chip] = []
        if let tier { chips.append(tierChip(tier)) }

        guard history.count >= learningDays, let score, let tier else {
            return DailyBrief.Status(
                chips: chips,
                headline: Copy.DailyBrief.Status.learning,
                sentence: Copy.DailyBrief.Status.learningSentence(max(0, learningDays - history.count)),
                readiness: score, sparkline: sparkline, band: band
            )
        }

        let top = topDrivers.first
        if let top {
            chips.append(DailyBrief.Chip(
                text: top.kind == .restDays ? Copy.DailyBrief.Status.chipUnderRested(restWindowWeeks) : top.title,
                tone: .fair
            ))
        }

        let headline: String
        if s.restContext != nil {
            headline = Copy.DailyBrief.Status.headlineRest
        } else if s.verdict != nil, tier != .poor {
            headline = Copy.DailyBrief.Status.headlineRecovered
        } else {
            switch tier {
            case .optimal:
                headline = top.map { headlineMoveNotPushDrivers.contains($0.kind) } == true
                    ? Copy.DailyBrief.Status.headlineMoveNotPush
                    : Copy.DailyBrief.Status.headlinePush
            case .fair: headline = Copy.DailyBrief.Status.headlineEasy
            case .poor: headline = Copy.DailyBrief.Status.headlineRest
            }
        }

        let readinessClause: String
        if let band {
            switch band.status(for: Double(score)) {
            case .aboveUsual: readinessClause = Copy.DailyBrief.Status.readinessAbove(score, Int(band.low), Int(band.high))
            case .usual: readinessClause = Copy.DailyBrief.Status.readinessInside(score)
            case .belowUsual: readinessClause = Copy.DailyBrief.Status.readinessBelow(score, Int(band.low), Int(band.high))
            }
        } else {
            readinessClause = Copy.DailyBrief.Status.readinessPlain(score)
        }

        let driverClause: String?
        let hasRest = topDrivers.contains { $0.kind == .restDays }
        let hasSleep = topDrivers.contains { $0.kind == .sleepBalance }
        if let rest = s.restDeficit, hasRest {
            let clause = Copy.DailyBrief.Status.restClause(rest.restDays28, restWindowDays)
            if let debt = s.sleepDebt?.totalDebtHours, hasSleep {
                driverClause = clause + Copy.DailyBrief.Status.clauseJoin + Copy.DailyBrief.Status.balanceClause(debt.hoursAsClock)
            } else {
                driverClause = clause + Copy.DailyBrief.Status.clauseEnd
            }
        } else {
            driverClause = top?.sentence
        }

        let trajectory = trajectory(s)
        let trajectoryWord: String
        switch trajectory {
        case .improving: trajectoryWord = Copy.DailyBrief.Status.improving
        case .holding: trajectoryWord = Copy.DailyBrief.Status.holding
        case .slipping: trajectoryWord = Copy.DailyBrief.Status.slipping
        }

        return DailyBrief.Status(
            chips: chips,
            headline: headline,
            sentence: [readinessClause, driverClause, trajectoryWord].compactMap { $0 }.joined(separator: " "),
            readiness: score, sparkline: sparkline, band: band
        )
    }

    private static func tierChip(_ tier: DS.RecoveryTier) -> DailyBrief.Chip {
        switch tier {
        case .optimal: return DailyBrief.Chip(text: Copy.DailyBrief.Status.chipStrong, tone: .good)
        case .fair: return DailyBrief.Chip(text: Copy.DailyBrief.Status.chipSteady, tone: .fair)
        case .poor: return DailyBrief.Chip(text: Copy.DailyBrief.Status.chipLow, tone: .poor)
        }
    }

    private static func trajectory(_ s: Snapshot) -> DailyBrief.Trajectory {
        switch s.trajectory {
        case .improving: return .improving
        case .declining: return .slipping
        case .stable: return .holding
        case nil: return trajectory(history: s.readinessHistory, deadBand: DailyBriefConfig.trajectoryDeadBand)
        }
    }

    /// Last week's mean against the week before. Fewer than two weeks reads as
    /// holding rather than guessing from a partial week.
    static func trajectory(history: [(date: Date, score: Int)], deadBand: Double) -> DailyBrief.Trajectory {
        let scores = history.map { Double($0.score) }
        guard scores.count >= 2 * daysPerWeek else { return .holding }
        let recent = Array(scores.suffix(daysPerWeek)).mean
        let prior = Array(scores.suffix(2 * daysPerWeek).prefix(daysPerWeek)).mean
        let delta = recent - prior
        if delta > deadBand { return .improving }
        if delta < -deadBand { return .slipping }
        return .holding
    }

    // MARK: - Moves

    static func dayMove(_ s: Snapshot, drivers: [DailyBrief.Driver]) -> DailyBrief.Move {
        let advisor = s.advisor
        var title = advisor.title
        var reason = advisor.subtitle
        var icon = advisor.icon
        var source = advisor.source
        // Under-rested and short of the goal: a walk closes the goal without
        // costing the rest day. A rest context or the recovery gate already
        // said "do not push", so they keep their own words.
        if s.exerciseMinutes < s.exerciseGoal, drivers.first?.kind == .restDays,
           !dayOverrideBlockedSources.contains(advisor.source) {
            title = Copy.DailyBrief.Day.walkTitle
            reason = Copy.DailyBrief.Day.walkReason(Int(s.exerciseGoal - s.exerciseMinutes))
            icon = "figure.walk"
            source = "rest_walk"
        }

        let reminderLabel: String
        if s.dayDone {
            reminderLabel = Copy.DailyBrief.Day.done
        } else if let fire = s.dayReminderFire {
            reminderLabel = Copy.DailyBrief.Day.reminderSet(timeText(fire))
        } else {
            reminderLabel = Copy.DailyBrief.Day.remindAt(ActionReminderScheduler.timeLabel(
                hour: DailyBriefConfig.dayReminderHour, minute: ActionReminderScheduler.defaultMinute))
        }

        return DailyBrief.Move(
            kind: .day, title: title, reason: reason, icon: icon, source: source,
            isDone: s.dayDone, reminderLabel: reminderLabel, reminderFire: s.dayReminderFire,
            bedtime: nil, canMarkDoneNow: true
        )
    }

    /// Nil without a computed bedtime: the app never invents one.
    static func nightMove(_ s: Snapshot) -> DailyBrief.Move? {
        guard let need = s.sleepNeed, let bedtime = need.recommendedBedtime,
              let wake = need.recommendedWakeTime, isPlausibleBedtime(bedtime) else { return nil }
        let bedText = timeText(bedtime)
        let title = s.nightDoneYesterday
            ? Copy.DailyBrief.Night.titleAgain(bedText)
            : Copy.DailyBrief.Night.title(bedText)

        let reason: String
        if s.nightDoneYesterday {
            reason = Copy.DailyBrief.Night.twoNights
        } else if let debt = s.sleepDebt?.totalDebtHours, debt >= DailyBriefConfig.sleepBalanceDriverHours {
            reason = Copy.DailyBrief.Night.paysBack(
                Copy.DailyBrief.KPI.minutes(Int(SleepDebtTracker.paybackExtraMinutes)),
                of: debt.hoursAsClock,
                wake: timeText(wake))
        } else {
            reason = Copy.DailyBrief.Night.keepRhythm(wake: timeText(wake))
        }

        let windowStart = Date.cal.date(byAdding: .minute, value: -nightReminderLeadMinutes, to: bedtime) ?? bedtime
        let windowEnd = Date.cal.date(byAdding: .minute, value: inBedWindowAfterMinutes, to: bedtime) ?? bedtime
        let reminderLabel = s.nightReminderFire.map { Copy.DailyBrief.Night.reminderSet(timeText($0)) }
            ?? Copy.DailyBrief.Night.remindAt(timeText(windowStart))

        return DailyBrief.Move(
            kind: .night, title: title, reason: reason, icon: "bed.double.fill", source: "sleep_need",
            isDone: s.nightDone, reminderLabel: reminderLabel, reminderFire: s.nightReminderFire,
            bedtime: bedtime, canMarkDoneNow: (windowStart...windowEnd).contains(s.now)
        )
    }

    /// One clock label for every time on the brief, through the scheduler's
    /// formatter so the card names the same time the push fires at.
    static func timeText(_ date: Date) -> String {
        let parts = Date.cal.dateComponents([.hour, .minute], from: date)
        return ActionReminderScheduler.timeLabel(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }

    // MARK: - Focus

    static func focusView(_ record: FocusStore.FocusRecord, now: Date, driverLine: String? = nil) -> DailyBrief.FocusView {
        let totalDays = DailyBriefConfig.focusDays
        let dayIndex = record.dayIndex(now: now)
        let totalWeeks = Int((Double(totalDays) / Double(daysPerWeek)).rounded(.up))
        let week = min(totalWeeks, (dayIndex - 1) / daysPerWeek + 1)
        let kpis = record.kpis.map { kpi in
            DailyBrief.FocusView.KPICell(
                value: kpi.kind.format(kpi.day1),
                // Under the floor the move is noise, so the cell shows one number, not a swing.
                to: abs(kpi.latest - kpi.day1) >= kpi.kind.floor ? kpi.kind.format(kpi.latest) : nil,
                improved: (kpi.latest - kpi.day1) * (kpi.kind.higherIsBetter ? 1 : -1) > 0,
                label: kpi.kind.label
            )
        }
        return DailyBrief.FocusView(
            record: record,
            title: Copy.DailyBrief.Focus.title(for: record.driver),
            weekLabel: Copy.DailyBrief.Focus.week(week, of: totalWeeks),
            kpis: kpis, dayIndex: dayIndex, totalDays: totalDays, driverLine: driverLine
        )
    }

    /// Today's value for every KPI the snapshot can answer. Missing keys mean
    /// "no reading", so the store keeps the last one rather than writing a zero.
    /// Whether the driver is off usual today, or nil when today's data cannot
    /// say. A missing reading must not count as "back to usual", or a week
    /// without the watch would close a focus as worked.
    static func isDriverOff(_ kind: DriverKind, _ s: Snapshot) -> Bool? {
        let canJudge: Bool
        switch kind {
        case .restDays:            canJudge = s.restSummary != nil || s.restDeficit != nil
        case .sleepBalance:        canJudge = s.sleepDebt != nil
        case .heartRateBounceBack: canJudge = s.hrr != nil
        case .strainHigh:          canJudge = s.strainTarget != nil && s.strainLast6.count >= 6
        case .stressHigh:          canJudge = s.stressLevel != nil
        case .anomaly(let metric): canJudge = s.baselines[metric] != nil
        }
        guard canJudge else { return nil }
        return rankDrivers(s, limit: .max).contains { $0.kind == kind }
    }

    /// A bedtime has to fall in the evening or small hours. The sleep-need
    /// engine estimates wake time from sample timestamps when no wake anchor
    /// exists, and daily samples stamped mid-day turn that into "in bed by
    /// 9 AM". Telling someone that is worse than showing no night move.
    static func isPlausibleBedtime(_ bedtime: Date) -> Bool {
        let hour = Date.cal.component(.hour, from: bedtime)
        return hour >= earliestBedtimeHour || hour < latestBedtimeHour
    }
    private static let earliestBedtimeHour = 18
    private static let latestBedtimeHour = 4

    static func kpiValues(_ s: Snapshot) -> [FocusStore.KPIKind: Double] {
        var values: [FocusStore.KPIKind: Double] = [:]
        if let rest = s.restSummary ?? s.restDeficit { values[.restDaysPerWeek] = rest.restPerWeek }
        if let debt = s.sleepDebt?.totalDebtHours { values[.sleepBalanceHours] = -debt }
        if let hrr = s.hrr, hrr.baseline.mean > 0 {
            values[.hrrPercentOffUsual] = (1 - hrr.current / hrr.baseline.mean) * 100
        }
        values[.vo2Max] = s.latest[.vo2Max]
        values[.hrvMs] = s.latest[.heartRateVariability]
        values[.restingHR] = s.latest[.restingHeartRate]
        values[.deepSleepMinutes] = s.latest[.sleepDeep]
        values[.steps] = s.latest[.steps]
        if let stress = s.stressLevel { values[.stressScore] = Double(stress) }
        return values
    }
}

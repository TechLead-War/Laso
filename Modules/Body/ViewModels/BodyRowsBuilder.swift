import Foundation

/// Turns one refresh's worth of engine output into the Body tab: every signal
/// sorted into "off your usual" or "at your usual".
///
/// Pure on purpose: every input arrives in `Snapshot`, so a test can hand it a
/// morning and read the rows back without HealthKit or the analysis engine.
struct BodyRowsBuilder {

    struct Snapshot {
        var now: Date
        var baselines: [HealthMetric: UserBaseline]
        /// Latest reading per metric. Steps and mindful minutes are today's running totals.
        var latest: [HealthMetric: Double]
        var sleepDebtHours: Double?
        var restDeficit: RecoveryAnalyzer.RestDeficit?
        var hrr: (current: Double, baseline: UserBaseline)?
        /// The six completed days before today, oldest first.
        var strainLast6: [Double]
        var strainTarget: StrainCoach.StrainTarget?
        var stressLevel: Int?
        /// Zero until the vitality scorer has run.
        var vitalityAge: Int
        var chronologicalAge: Int
        var cycle: (day: Int, phase: String)?
        var heartRateNow: Double?
        var isHeartRateCalm: Bool
        var isWearingWatch: Bool
        var notSynced: [String]
    }

    struct Row: Identifiable, Equatable {
        let id: String
        let title: String
        let valueText: String
        let band: UsualBand?
        let status: String
        let tone: DailyBrief.Tone
        let route: Route?
        let metric: HealthMetric?
    }

    struct LiveRow: Equatable {
        let bpm: Int
        let isCalm: Bool
        let watchOn: Bool
    }

    struct BodyRows {
        let live: LiveRow?
        let off: [Row]
        let usual: [Row]
        let notSynced: [String]
    }

    /// `ReadinessScorer.stressLabel` starts "High" at 60 inline, with no named
    /// constant to share, so this mirrors it (as `DailyBriefBuilder` does).
    private static let stressHighFloor = 60
    /// A value inside the last tenth of its band, at the healthy end, reads as
    /// "top of your range" rather than a bare "usual".
    private static let topOfRangeFraction = 0.1
    private static let secondsPerDay = 86_400.0
    /// The steps pace projection needs at least an hour of the day, or a few
    /// steps at 00:05 project to a marathon.
    private static let minimumDayFractionForPace = 1.0 / 24

    /// `DashboardViewModel.usualComparison` is main-actor bound, so this is too.
    @MainActor
    static func build(_ s: Snapshot) -> BodyRows {
        var off: [Row] = []
        var usual: [Row] = []
        func place(_ row: Row, isOff: Bool) {
            if isOff { off.append(row) } else { usual.append(row) }
        }

        if let debt = s.sleepDebtHours {
            let isOff = debt >= DailyBriefConfig.sleepBalanceDriverHours
            place(Row(
                id: "sleepBalance", title: Copy.Body.Row.sleepBalance, valueText: debt.hoursAsClock,
                band: usualBand(.sleepDuration, value: s.latest[.sleepDuration], baseline: s.baselines[.sleepDuration]),
                status: isOff ? Copy.Body.Status.behindNights(SleepDebtTracker.nightsToClear(debtHours: debt)) : Copy.Body.Status.usual,
                tone: isOff ? .fair : .good, route: .driverDetail(.sleepBalance), metric: nil
            ), isOff: isOff)
        }

        if let hrr = s.hrr, hrr.baseline.mean > 0 {
            let pctOff = (1 - hrr.current / hrr.baseline.mean) * 100
            let isOff = hrr.current < hrr.baseline.mean * (1 - DailyBriefConfig.hrrOffUsualPercent / 100)
            place(Row(
                id: "heartRateBounceBack", title: Copy.Body.Row.bounceBack,
                valueText: isOff ? Copy.DailyBrief.Driver.hrrValue(Int(pctOff.rounded())) : HealthMetric.heartRateRecovery.formatWithUnit(hrr.current),
                band: usualBand(.heartRateRecovery, value: hrr.current, baseline: hrr.baseline),
                status: isOff ? Copy.Body.Status.bounceBackBelow : Copy.Body.Status.usual,
                tone: isOff ? .poor : .good, route: .driverDetail(.heartRateBounceBack), metric: nil
            ), isOff: isOff)
        }

        // `RecoveryAnalyzer.restDeficit` is nil both when rest is fine and when
        // there is too little training to judge, and the rest needed is only
        // known with a deficit, so the row exists only as an off-usual finding.
        if let rest = s.restDeficit {
            let need = rest.recommendedPerWeek
            off.append(Row(
                id: "restDays", title: Copy.Body.Row.restDays,
                valueText: Copy.Body.restPerWeek(rest.restPerWeek.formatted(.number.precision(.fractionLength(0...1)))),
                band: UsualBand(low: Double(need), high: Double(need + 1), value: rest.restPerWeek,
                                rangeText: Copy.DailyBrief.Detail.restUsualStatus(need)),
                status: Copy.Body.Status.restBelow(need),
                tone: .fair, route: .driverDetail(.restDays), metric: nil
            ))
        }

        if let hrv = metricRow("hrv", Copy.Body.Row.hrv, .heartRateVariability, s) { place(hrv.row, isOff: hrv.isOff) }
        if let rhr = metricRow("restingHR", Copy.Body.Row.restingHR, .restingHeartRate, s) { place(rhr.row, isOff: rhr.isOff) }

        let younger = s.vitalityAge > 0 && s.vitalityAge < s.chronologicalAge
        if let vo2 = metricRow("vo2Max", Copy.Body.Row.vo2Max, .vo2Max, s,
                               statusOverride: younger ? Copy.Body.Status.yearsYounger(s.chronologicalAge - s.vitalityAge, s.chronologicalAge) : nil) {
            place(vo2.row, isOff: vo2.isOff)
        }

        if let target = s.strainTarget, !s.strainLast6.isEmpty {
            let days = s.strainLast6.filter { $0 > target.maxStrain }.count
            let isOff = days >= DailyBriefConfig.strainHighDaysOfSix
            let avg = s.strainLast6.reduce(0, +) / Double(s.strainLast6.count)
            place(Row(
                id: "strain", title: Copy.Body.Row.strainRecent,
                valueText: Copy.Body.strainAvg(String(format: "%.1f", avg)),
                band: UsualBand(low: target.minStrain, high: target.maxStrain, value: avg,
                                rangeText: Copy.Strain.targetRange(String(format: "%.1f", target.minStrain), String(format: "%.1f", target.maxStrain))),
                status: isOff ? Copy.Body.Status.strainAbove(Int(target.minStrain), Int(target.maxStrain), days) : Copy.Body.Status.strainInRange,
                tone: isOff ? .fair : .good, route: .driverDetail(.strainHigh), metric: nil
            ), isOff: isOff)
        }

        if let stress = s.stressLevel {
            let isOff = stress >= stressHighFloor
            place(Row(
                id: "stress", title: Copy.Body.Row.stressNow,
                valueText: isOff ? Copy.Body.elevated : Copy.Body.calm, band: nil,
                status: isOff ? Copy.DailyBrief.Driver.stressTitle : Copy.Body.Status.usual,
                tone: isOff ? .fair : .good, route: .driverDetail(.stressHigh), metric: nil
            ), isOff: isOff)
        }

        // Steps and mindful minutes are running totals, partial until midnight,
        // so today's count is never called off usual; the status says how it
        // compares so far.
        if let mindful = s.latest[.mindfulMinutes] {
            usual.append(partialDayRow("mindful", Copy.Body.Row.mindful, .mindfulMinutes, value: mindful, s,
                                       status: s.baselines[.mindfulMinutes].map {
                                           DashboardViewModel.usualComparison(current: mindful, baseline: $0.mean, unit: HealthMetric.mindfulMinutes.unit)
                                       }))
        }

        if let steps = s.latest[.steps] {
            let dayFraction = max(s.now.timeIntervalSince(Date.cal.startOfDay(for: s.now)) / secondsPerDay, minimumDayFractionForPace)
            usual.append(partialDayRow("steps", Copy.Body.Row.steps, .steps, value: steps, s,
                                       status: s.baselines[.steps].map { usualTotal in
                                           steps / dayFraction >= usualTotal.mean
                                               ? Copy.Body.Status.stepsOnPace(HealthMetric.steps.formatWithUnit(usualTotal.mean))
                                               : DashboardViewModel.usualComparison(current: steps, baseline: usualTotal.mean, unit: HealthMetric.steps.unit)
                                       }))
        }

        if let cycle = s.cycle {
            usual.append(Row(
                id: "cycle", title: Copy.Body.Row.cycle, valueText: Copy.CycleTracking.dayOfCycle(cycle.day),
                band: nil, status: cycle.phase, tone: .good, route: .cycleDetail, metric: nil
            ))
        }

        let live = s.heartRateNow.map {
            LiveRow(bpm: Int($0.rounded()), isCalm: s.isHeartRateCalm, watchOn: s.isWearingWatch)
        }
        return BodyRows(live: live, off: off, usual: usual, notSynced: s.notSynced)
    }

    // MARK: - Rows read straight off one metric

    /// Off or usual is `MetricVerdict`'s call against the person's own band, so
    /// this can never disagree with the metric detail screen. No band lands
    /// the row at usual.
    @MainActor
    private static func metricRow(_ id: String, _ title: String, _ metric: HealthMetric, _ s: Snapshot,
                                  statusOverride: String? = nil) -> (row: Row, isOff: Bool)? {
        guard let value = s.latest[metric] else { return nil }
        let verdict = personalVerdict(metric, value: value, baseline: s.baselines[metric])
        // Off means worse than usual. HRV above its band is good news and belongs
        // with the signals that are fine, not in the list of things to act on.
        let standing = verdict?.standing ?? .normal
        let isOff = metric.higherIsBetter ? standing == .belowNormal : standing == .aboveNormal
        let isBetter = standing != .normal && !isOff

        let status: String
        if let statusOverride {
            status = statusOverride
        } else if isOff || isBetter, let baseline = s.baselines[metric] {
            status = DashboardViewModel.usualComparison(current: value, baseline: baseline.mean, unit: metric.unit)
        } else if let verdict, isAtHealthyEnd(value, of: verdict, metric: metric) {
            status = Copy.Body.Status.topOfRange
        } else {
            status = Copy.Body.Status.usual
        }

        let row = Row(
            id: id, title: title, valueText: metric.formatWithUnit(value),
            band: verdict.map { UsualBand(low: $0.low, high: $0.high, value: value, rangeText: $0.rangeText) },
            status: status, tone: isOff ? .fair : .good, route: nil, metric: metric
        )
        return (row, isOff)
    }

    private static func partialDayRow(_ id: String, _ title: String, _ metric: HealthMetric, value: Double,
                                      _ s: Snapshot, status: String?) -> Row {
        Row(
            id: id, title: title, valueText: metric.formatWithUnit(value),
            band: usualBand(metric, value: value, baseline: s.baselines[metric]),
            status: status ?? Copy.Body.Status.usual, tone: .good, route: nil, metric: metric
        )
    }

    /// The healthy end is the top for a higher-is-better metric and the bottom
    /// otherwise: a resting heart rate at the low edge of its band is the win.
    private static func isAtHealthyEnd(_ value: Double, of verdict: MetricVerdict, metric: HealthMetric) -> Bool {
        let margin = (verdict.high - verdict.low) * topOfRangeFraction
        return metric.higherIsBetter ? value >= verdict.high - margin : value <= verdict.low + margin
    }

    /// The tab reads every signal against the person's own usual, so the
    /// population table `MetricVerdict` falls back to is not a band here: a
    /// thin history shows no band rather than someone else's.
    private static func personalVerdict(_ metric: HealthMetric, value: Double, baseline: UserBaseline?) -> MetricVerdict? {
        guard let baseline,
              let verdict = MetricVerdict.make(metric: metric, value: value, baseline: baseline),
              verdict.source == .personalBaseline else { return nil }
        return verdict
    }

    private static func usualBand(_ metric: HealthMetric, value: Double?, baseline: UserBaseline?) -> UsualBand? {
        guard let value, let verdict = personalVerdict(metric, value: value, baseline: baseline) else { return nil }
        return UsualBand(low: verdict.low, high: verdict.high, value: value, rangeText: verdict.rangeText)
    }
}

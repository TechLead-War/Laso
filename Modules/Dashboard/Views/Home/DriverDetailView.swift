import SwiftUI

/// One driver, explained: the evidence behind it, why it matters, what moves
/// it, and the person's own usual. Reads the same snapshot the brief is built
/// from so the numbers here match the row that opened it.
struct DriverDetailView: View {
    let kind: DriverKind
    let viewModel: DashboardViewModel
    let liveViewModel: LiveViewModel
    @Binding var navigationPath: NavigationPath

    @State private var snapshot: DailyBriefBuilder.Snapshot?
    @State private var showBreathwork = false

    /// The rest-day grid covers the same window `RecoveryAnalyzer.RestDeficit` counts.
    private static let restWindowDays = 28
    private static let restGridColumns = 7
    private static let restCellHeight: CGFloat = 22
    private static let chartDays = 14

    private struct MoveRow {
        let title: String
        let value: String
        let note: String
    }

    private var driver: DailyBrief.Driver? {
        viewModel.dailyBrief?.drivers.first { $0.kind == kind }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.sectionSpacing) {
                if let snapshot {
                    header(snapshot)
                    evidence(snapshot)
                    section(Copy.DailyBrief.Detail.whyItMatters) {
                        Text(why(snapshot))
                            .font(DS.Typography.body)
                            .foregroundStyle(AppColour.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(DS.cardPadding)
                            .cardStyle()
                    }
                    let moves = moveRows(snapshot)
                    if !moves.isEmpty {
                        section(Copy.DailyBrief.Detail.whatMovesIt) { movesCard(moves) }
                    }
                    if let usual = usual(snapshot) {
                        section(Copy.DailyBrief.Detail.yourUsual) { usualCard(usual) }
                    }
                    actions
                    footerLinks
                } else {
                    LoadingView(Copy.Home.analyzingHealthData)
                }
            }
            .padding(.horizontal, DS.screenPadding)
            .padding(.bottom, DS.space7)
        }
        .background(AppColour.surfaceSunken.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showBreathwork) { BreathworkView() }
        .onAppear {
            snapshot = viewModel.briefSnapshot(liveVM: liveViewModel)
            AppAnalytics.shared.trackFeatureOpen(.driverDetail, metadata: ["driver": kind.id])
        }
    }

    // MARK: - Header

    private func header(_ s: DailyBriefBuilder.Snapshot) -> some View {
        VStack(alignment: .leading, spacing: DS.space1) {
            Text(driver?.title ?? Self.fallbackTitle(kind))
                .font(DS.Typography.largeTitle)
                .foregroundStyle(AppColour.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle = subtitle(s) {
                Text(subtitle)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(AppColour.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, DS.space2)
    }

    private static func fallbackTitle(_ kind: DriverKind) -> String {
        switch kind {
        case .restDays: return Copy.DailyBrief.Driver.restDaysTitle
        case .sleepBalance: return Copy.DailyBrief.Driver.sleepBalanceTitle
        case .heartRateBounceBack: return Copy.DailyBrief.Driver.hrrTitle
        case .strainHigh: return Copy.DailyBrief.Driver.strainTitle
        case .stressHigh: return Copy.DailyBrief.Driver.stressTitle
        case .anomaly(let metric): return metric.displayName
        }
    }

    /// The driver's own value text when it is on today's brief; otherwise the
    /// detail copy built from the same numbers, so a deep link still reads.
    private func subtitle(_ s: DailyBriefBuilder.Snapshot) -> String? {
        if kind == .restDays, let rest = s.restSummary ?? s.restDeficit {
            return Copy.DailyBrief.Detail.restSubtitle(rest.restDays28, Self.restWindowDays)
        }
        if let driver { return driver.valueText }
        switch kind {
        case .sleepBalance:
            return s.sleepDebt.map { Copy.DailyBrief.Detail.sleepSubtitle($0.totalDebtHours.hoursAsClock) }
        case .heartRateBounceBack:
            return hrrPercentOff(s).map(Copy.DailyBrief.Detail.hrrSubtitle)
        case .strainHigh:
            return s.strainTarget.map { target in
                Copy.DailyBrief.Detail.strainSubtitle(s.strainLast6.filter { $0 > target.maxStrain }.count)
            }
        case .stressHigh:
            return Copy.DailyBrief.Detail.stressSubtitle
        case .restDays, .anomaly:
            return nil
        }
    }

    /// Whole percent under the usual bounce-back, nil when there is no baseline.
    private func hrrPercentOff(_ s: DailyBriefBuilder.Snapshot) -> Int? {
        guard let hrr = s.hrr, hrr.baseline.mean > 0 else { return nil }
        return max(0, Int(((1 - hrr.current / hrr.baseline.mean) * 100).rounded()))
    }

    // MARK: - Evidence

    @ViewBuilder
    private func evidence(_ s: DailyBriefBuilder.Snapshot) -> some View {
        if kind == .restDays {
            restGrid(s)
        } else {
            let series = viewModel.healthKitManager.timeSeries[kind.metric]
            let samples = series?.completedDaySamples(lastDays: Self.chartDays) ?? []
            if !samples.isEmpty {
                let baseline = s.baselines[kind.metric]
                MetricChartView(
                    samples: samples,
                    metric: kind.metric,
                    periodDays: Self.chartDays,
                    baseline: baseline?.mean,
                    verdict: samples.last.flatMap { MetricVerdict.make(metric: kind.metric, value: $0.value, baseline: baseline) }
                )
                .padding(DS.cardPadding)
                .cardStyle()
            }
        }
    }

    /// One cell per day of the window, today last and left empty: the day is
    /// not over, so it is neither a workout day nor a rest day yet.
    private func restGrid(_ s: DailyBriefBuilder.Snapshot) -> some View {
        let workoutDays = viewModel.healthKitManager.timeSeries[.workoutDuration].map(RecoveryAnalyzer.workoutDays) ?? []
        let today = Date.cal.startOfDay(for: s.now)
        let days: [Date] = (0..<Self.restWindowDays).compactMap {
            Date.cal.date(byAdding: .day, value: $0 - (Self.restWindowDays - 1), to: today)
        }
        let rest = s.restSummary ?? s.restDeficit
        return VStack(alignment: .leading, spacing: DS.space3) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DS.space2 - 2), count: Self.restGridColumns),
                      spacing: DS.space2 - 2) {
                ForEach(days, id: \.self) { day in
                    RoundedRectangle(cornerRadius: DS.Radius.xs, style: .continuous)
                        .fill(day == today ? AppColour.trackNeutral
                              : workoutDays.contains(day) ? AppColour.scoreFair
                              : AppColour.scoreGood)
                        .frame(height: Self.restCellHeight)
                }
            }
            if let rest {
                HStack(spacing: DS.space4) {
                    legend(AppColour.scoreFair, Copy.DailyBrief.Detail.legendWorkout(rest.workoutDays28))
                    legend(AppColour.scoreGood, Copy.DailyBrief.Detail.legendRest(rest.restDays28))
                }
            }
        }
        .padding(DS.cardPadding)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: DS.space1 + 2) {
            Circle().fill(color).frame(width: DS.space2, height: DS.space2)
            Text(text)
                .font(DS.Typography.caption)
                .foregroundStyle(AppColour.textSecondary)
        }
    }

    // MARK: - Why

    private func why(_ s: DailyBriefBuilder.Snapshot) -> String {
        switch kind {
        case .restDays:
            if let vo2 = s.latest[.vo2Max], let rhr = s.latest[.restingHeartRate], let pct = hrrPercentOff(s) {
                return Copy.DailyBrief.Detail.restWhy(HealthMetric.vo2Max.formatValue(vo2), Int(rhr.rounded()), pct)
            }
            return driver?.sentence ?? Copy.DailyBrief.Driver.restDaysTitle
        case .sleepBalance: return Copy.DailyBrief.Detail.sleepWhy
        case .heartRateBounceBack: return Copy.DailyBrief.Detail.hrrWhy
        case .strainHigh: return Copy.DailyBrief.Detail.strainWhy
        case .stressHigh: return Copy.DailyBrief.Detail.stressWhy
        case .anomaly: return driver?.sentence ?? Self.fallbackTitle(kind)
        }
    }

    // MARK: - What moves it

    private func moveRows(_ s: DailyBriefBuilder.Snapshot) -> [MoveRow] {
        typealias D = Copy.DailyBrief.Detail
        switch kind {
        case .restDays:
            let debt = (s.sleepDebt?.totalDebtHours ?? 0).hoursAsClock
            return [
                MoveRow(title: D.restMove1Title, value: D.restMove1Value, note: D.restMove1Note),
                MoveRow(title: D.restMove2Title, value: D.restMove2Value(debt), note: D.restMove2Note),
                MoveRow(title: D.restMove3Title, value: D.restMove3Value, note: D.restMove3Note)
            ]
        case .sleepBalance:
            return [
                MoveRow(title: D.sleepMove1Title, value: D.sleepMove1Value, note: D.sleepMove1Note),
                MoveRow(title: D.sleepMove2Title, value: D.sleepMove2Value, note: D.sleepMove2Note),
                MoveRow(title: D.sleepMove3Title, value: D.sleepMove3Value, note: D.sleepMove3Note)
            ]
        case .heartRateBounceBack:
            return [
                MoveRow(title: D.hrrMove1Title, value: D.hrrMove1Value, note: D.hrrMove1Note),
                MoveRow(title: D.hrrMove2Title, value: D.hrrMove2Value, note: D.hrrMove2Note),
                MoveRow(title: D.hrrMove3Title, value: D.hrrMove3Value, note: D.hrrMove3Note)
            ]
        case .strainHigh:
            return [
                MoveRow(title: D.strainMove1Title, value: D.strainMove1Value, note: D.strainMove1Note),
                MoveRow(title: D.strainMove2Title, value: D.strainMove2Value, note: D.strainMove2Note),
                MoveRow(title: D.strainMove3Title, value: D.strainMove3Value, note: D.strainMove3Note)
            ]
        case .stressHigh:
            return [
                MoveRow(title: D.stressMove1Title, value: D.stressMove1Value, note: D.stressMove1Note),
                MoveRow(title: D.stressMove2Title, value: D.stressMove2Value, note: D.stressMove2Note),
                MoveRow(title: D.stressMove3Title, value: D.stressMove3Value, note: D.stressMove3Note)
            ]
        case .anomaly:
            return []
        }
    }

    private func movesCard(_ rows: [MoveRow]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 { Divider().overlay(AppColour.borderLow) }
                VStack(alignment: .leading, spacing: DS.space1) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.title)
                            .font(DS.Typography.bodySemibold)
                            .foregroundStyle(AppColour.textPrimary)
                        Spacer(minLength: DS.space2)
                        Text(row.value)
                            .font(DS.Typography.subheadlineMedium.monospacedDigit())
                            .foregroundStyle(AppColour.textSecondary)
                    }
                    Text(row.note)
                        .font(DS.Typography.footnote)
                        .foregroundStyle(AppColour.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, DS.space3)
            }
        }
        .padding(.horizontal, DS.cardPadding)
        .padding(.vertical, DS.space1)
        .cardStyle()
    }

    // MARK: - Your usual

    private struct Usual {
        let title: String
        let value: String
        let band: UsualBand
    }

    private func usual(_ s: DailyBriefBuilder.Snapshot) -> Usual? {
        typealias D = Copy.DailyBrief.Detail
        if kind == .restDays {
            guard let rest = s.restSummary ?? s.restDeficit else { return nil }
            let need = rest.recommendedPerWeek
            let band = driver?.band ?? UsualBand(low: Double(need), high: Double(need + 1), value: rest.restPerWeek,
                                                 rangeText: D.restUsualStatus(need))
            return Usual(title: D.restUsualTitle, value: D.restUsualValue(rest.restPerWeek), band: band)
        }
        let metric = kind.metric
        let value = kind == .heartRateBounceBack ? s.hrr?.current : s.latest[metric]
        guard let value,
              let band = driver?.band ?? MetricVerdict.make(metric: metric, value: value, baseline: s.baselines[metric])
                .map({ UsualBand(low: $0.low, high: $0.high, value: value, rangeText: $0.rangeText) }) else { return nil }
        let title: String
        switch kind {
        case .sleepBalance: title = D.sleepUsualTitle
        case .heartRateBounceBack: title = D.hrrUsualTitle
        case .strainHigh: title = D.strainUsualTitle
        case .stressHigh: title = D.stressUsualTitle
        case .restDays, .anomaly: title = metric.displayName
        }
        return Usual(title: title, value: metric.formatWithUnit(value), band: band)
    }

    private func usualCard(_ usual: Usual) -> some View {
        VStack(alignment: .leading, spacing: DS.space2) {
            HStack(alignment: .firstTextBaseline) {
                Text(usual.title)
                    .font(DS.Typography.bodySemibold)
                    .foregroundStyle(AppColour.textPrimary)
                Spacer(minLength: DS.space2)
                Text(usual.value)
                    .font(DS.Typography.subheadlineMedium.monospacedDigit())
                    .foregroundStyle(AppColour.textSecondary)
            }
            UsualBandBar(band: usual.band, tone: driver?.tone ?? .fair)
            Text(usual.band.rangeText)
                .font(DS.Typography.footnote)
                .foregroundStyle(AppColour.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }

    // MARK: - Actions and footer

    @ViewBuilder
    private var actions: some View {
        if kind == .stressHigh {
            Button {
                AppAnalytics.shared.trackBlockTap(
                    title: Copy.DailyBrief.Detail.breathe, type: .smartAction, screen: .driverDetail,
                    metadata: ["driver": kind.id, "destination": "breathwork"])
                showBreathwork = true
            } label: {
                Label(Copy.DailyBrief.Detail.breathe, systemImage: "wind")
                    .font(DS.Typography.bodySemibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("driverDetail.breathe")
        }
        if viewModel.focusStore.active == nil, !kind.focusKPIs.isEmpty {
            Button {
                viewModel.startFocus(kind, liveVM: liveViewModel)
            } label: {
                Text(Copy.DailyBrief.Focus.startButton)
                    .font(DS.Typography.bodySemibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("driverDetail.startFocus")
        }
    }

    private var footerLinks: some View {
        HStack(spacing: DS.space4) {
            footerLink(Copy.DailyBrief.Detail.allInsights, route: .insightsDetail, destination: "insights_detail")
            footerLink(Copy.DailyBrief.Detail.connections, route: .correlationsDetail, destination: "correlations_detail")
            Spacer()
        }
    }

    private func footerLink(_ title: String, route: Route, destination: String) -> some View {
        Button {
            AppAnalytics.shared.trackBlockTap(
                title: title, type: .smartAction, screen: .driverDetail,
                metadata: ["driver": kind.id, "destination": destination])
            navigationPath.append(route)
        } label: {
            Text(title)
                .font(DS.Typography.footnoteMedium)
                .foregroundStyle(AppColour.accent)
        }
        .buttonStyle(.plain)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.space3) {
            Text(title)
                .font(DS.Typography.captionSemibold)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(AppColour.textTertiary)
            content()
        }
    }
}

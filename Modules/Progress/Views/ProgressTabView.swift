import SwiftUI

/// The Progress tab: the running focus, the ones already closed, and the one
/// number that only moves over months. Reads `FocusStore` and `VitalityScorer`
/// directly; there is nothing to derive that the store does not already hold.
struct ProgressTabView: View {
    let focusStore: FocusStore
    let vitalityScorer: VitalityScorer
    @Binding var navigationPath: NavigationPath

    @State private var focusTracker = SectionTracker(section: .progressFocus, tab: .progress)
    @State private var pastTracker = SectionTracker(section: .progressPast, tab: .progress)
    @State private var slowTracker = SectionTracker(section: .progressSlow, tab: .progress)

    init(focusStore: FocusStore, vitalityScorer: VitalityScorer, navigationPath: Binding<NavigationPath>) {
        self.focusStore = focusStore
        self.vitalityScorer = vitalityScorer
        _navigationPath = navigationPath
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.space5) {
                Text(Copy.Progress.subtitle)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(AppColour.textSecondary)

                focusSection
                    .onAppear { focusTracker.appeared() }
                    .onDisappear { focusTracker.disappeared() }

                if !focusStore.past.isEmpty {
                    pastSection
                        .onAppear { pastTracker.appeared() }
                        .onDisappear { pastTracker.disappeared() }
                }

                if vitalityScorer.isReady {
                    slowSection
                        .onAppear { slowTracker.appeared() }
                        .onDisappear { slowTracker.disappeared() }
                }

                Button(Copy.Progress.achievements) {
                    navigationPath.append(Route.achievements)
                }
                .buttonStyle(.dsTertiary)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, DS.screenPadding)
            .padding(.vertical)
        }
        .background(AppColour.surfaceBase.ignoresSafeArea())
        .accessibilityIdentifier("screen.progress")
        .navigationTitle(Copy.Progress.title)
        .navigationBarTitleDisplayMode(.large)
        .onAppear { AppAnalytics.shared.trackFeatureOpen(.progress) }
        .onDisappear { AppAnalytics.shared.trackFeatureClose(.progress) }
    }

    // MARK: - Active focus

    @ViewBuilder
    private var focusSection: some View {
        if let record = focusStore.active {
            let focus = DailyBriefBuilder.focusView(record, now: Date(), driverLine: bounceBackLine(for: record))
            VStack(alignment: .leading, spacing: DS.space2) {
                Text(Copy.Progress.since(record.startedAt.formatted(date: .abbreviated, time: .omitted)))
                    .font(DS.Typography.caption)
                    .foregroundStyle(AppColour.textTertiary)
                FocusCard(focus: focus) {
                    AppAnalytics.shared.trackBlockTap(title: focus.title, type: .focusCard, screen: .progress)
                    navigationPath.append(Route.driverDetail(record.driver))
                }
            }
        } else {
            DSEmptyState(icon: "target", title: Copy.Progress.emptyTitle, message: Copy.Progress.emptyMessage)
                .cardStyle()
        }
    }

    /// Bounce-back is stored as percent under usual, so only a drop of at least
    /// the floor is "moving back toward usual"; a rise or noise gets no line.
    private func bounceBackLine(for record: FocusStore.FocusRecord) -> String? {
        guard let hrr = record.kpis.first(where: { $0.kind == .hrrPercentOffUsual }),
              hrr.day1 - hrr.latest >= hrr.kind.floor else { return nil }
        return Copy.Progress.driverLineBounceBack(hrr.kind.format(hrr.day1), hrr.kind.format(hrr.latest))
    }

    // MARK: - Past focuses

    private var pastSection: some View {
        VStack(alignment: .leading, spacing: DS.space2) {
            Text(Copy.Progress.pastFocuses)
                .font(DS.Typography.headline)
                .foregroundStyle(AppColour.textPrimary)
            VStack(spacing: DS.space3) {
                ForEach(focusStore.past) { record in
                    pastRow(record)
                    if record.id != focusStore.past.last?.id {
                        Divider()
                    }
                }
            }
            .padding(DS.cardPadding)
            .cardStyle()
        }
    }

    private func pastRow(_ record: FocusStore.FocusRecord) -> some View {
        let title = Copy.DailyBrief.Focus.title(for: record.driver)
        let outcome = record.outcome ?? FocusStore.outcome(for: record)
        let tint = outcome == .improved ? AppColour.scoreGood : AppColour.textTertiary
        return Button {
            AppAnalytics.shared.trackBlockTap(title: title, type: .pastFocusRow, screen: .progress)
            navigationPath.append(Route.driverDetail(record.driver))
        } label: {
            HStack(alignment: .top, spacing: DS.space3) {
                Image(systemName: outcome == .improved ? "checkmark" : "minus")
                    .font(DS.Typography.captionSemibold)
                    .foregroundStyle(tint)
                    .frame(width: DS.space6, height: DS.space6)
                    .background(AppColour.surfaceSubtle, in: Circle())
                VStack(alignment: .leading, spacing: DS.space1) {
                    Text(title)
                        .font(DS.Typography.bodySemibold)
                        .foregroundStyle(AppColour.textPrimary)
                    if let endedAt = record.endedAt {
                        Text(Copy.Progress.dateRange(
                            record.startedAt.formatted(.dateTime.day().month()),
                            endedAt.formatted(.dateTime.day().month())
                        ))
                        .font(DS.Typography.caption)
                        .foregroundStyle(AppColour.textTertiary)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: DS.space1) {
                        Text(outcomeWord(outcome))
                            .font(DS.Typography.footnoteMedium)
                            .foregroundStyle(tint)
                        if let primary = record.kpis.first {
                            Text(Copy.Progress.outcomeLine(
                                primary.kind.label,
                                primary.kind.format(primary.day1),
                                primary.kind.format(primary.latest)
                            ))
                            .font(DS.Typography.footnote)
                            .foregroundStyle(AppColour.textSecondary)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.dsPress)
        .accessibilityIdentifier("progress.past.\(record.driver.id)")
    }

    private func outcomeWord(_ outcome: FocusStore.Outcome) -> String {
        switch outcome {
        case .improved: return Copy.DailyBrief.Focus.closedImproved
        case .held:     return Copy.DailyBrief.Focus.closedHeld
        case .noChange: return Copy.DailyBrief.Focus.closedNoChange
        }
    }

    // MARK: - Changes slowly

    private var slowSection: some View {
        VStack(alignment: .leading, spacing: DS.space2) {
            Text(Copy.Progress.changesSlowly)
                .font(DS.Typography.headline)
                .foregroundStyle(AppColour.textPrimary)
            Button {
                navigationPath.append(Route.vitalityDetail)
            } label: {
                VStack(alignment: .leading, spacing: DS.space1) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(Copy.Progress.vitalityRow(vitalityScorer.vitalityAge))
                            .font(DS.Typography.bodySemibold)
                            .foregroundStyle(AppColour.textPrimary)
                        Spacer(minLength: DS.space2)
                        Text(Copy.Progress.vitalityYouAre(vitalityScorer.chronologicalAge))
                            .font(DS.Typography.subheadline.monospacedDigit())
                            .foregroundStyle(AppColour.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(DS.Typography.captionSemibold)
                            .foregroundStyle(AppColour.textTertiary)
                    }
                    Text(paceLine)
                        .font(DS.Typography.footnote)
                        .foregroundStyle(vitalityPaceTint(for: vitalityScorer))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(DS.cardPadding)
                .cardStyle()
                .contentShape(Rectangle())
            }
            .buttonStyle(.dsPress)
            .accessibilityIdentifier("progress.vitalityRow")
        }
    }

    private var paceLine: String {
        if vitalityScorer.hasPaceEstimate {
            return Copy.Progress.vitalityPace(vitalityPaceStateText(for: vitalityScorer))
        }
        // The approved reference dates the next check to the first of next month.
        guard let nextCheck = Date.cal.nextDate(after: Date(), matching: DateComponents(day: 1), matchingPolicy: .nextTime) else {
            return Copy.Vitality.paceNeedsDays(VitalityScorer.minimumPaceDays)
        }
        return Copy.Progress.vitalityNeedsHistory(
            days: VitalityScorer.minimumPaceDays,
            nextCheck: nextCheck.formatted(.dateTime.day().month(.wide))
        )
    }
}

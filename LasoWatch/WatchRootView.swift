import SwiftUI

/// Three vertical pages: the answer, why, and today.
///
/// Page 1 is the whole product. It carries one word, the fact behind it, and how much
/// movement is left in today's ceiling. The readiness number is deliberately on page 2:
/// every app in the category that ships a bare number pairs it with words, and the
/// number on its own is the thing a wrist glance cannot use.
///
/// Vertical pages rather than a `NavigationStack` because Apple asks apps to anchor
/// navigation to the Digital Crown and to minimise hierarchy. No `handGestureShortcut`
/// is set anywhere in this view: Apple says to avoid a primary action "in views with
/// lists, scroll views, or vertical tabs", and this is all three.
/// https://developer.apple.com/design/human-interface-guidelines/digital-crown
struct WatchRootView: View {

    let store: WatchStore
    let health: WatchHealthStore

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.scenePhase) private var scenePhase

    @State private var showCheckIn = false
    @State private var showJournal = false

    /// Which page is showing.
    ///
    /// Bound rather than implicit because each complication family deep links to its own
    /// page. Apple: "If all the complications you support open the same area in your app,
    /// they can seem less useful."
    @State private var page: WatchPage = .initialPage

    private var verdict: WatchVerdict? {
        WatchVerdict.evaluate(store.verdictInput(health: health))
    }

    var body: some View {
        TabView(selection: $page) {
            NowPage(verdict: verdict, store: store, isDimmed: isLuminanceReduced)
                .tag(WatchPage.now)
            WhyPage(store: store, health: health, isDimmed: isLuminanceReduced)
                .tag(WatchPage.why)
            TodayPage(
                store: store,
                health: health,
                verdict: verdict,
                isDimmed: isLuminanceReduced,
                showCheckIn: $showCheckIn,
                showJournal: $showJournal
            )
            .tag(WatchPage.today)
        }
        .tabViewStyle(.verticalPage)
        .onOpenURL { url in
            guard let destination = WatchPage(url: url) else { return }
            page = destination
        }
        .sheet(isPresented: $showCheckIn) { WatchCheckInView(store: store) }
        .sheet(isPresented: $showJournal) { WatchJournalView(store: store) }
        .task {
            if health.isAuthorized == nil {
                await health.requestAuthorization()
            } else {
                await health.refresh()
            }
        }
        .onChange(of: verdict, initial: true) { _, new in
            // The face renders what the app computed, so the cache is written whenever
            // the answer changes rather than on a timer. `initial: true` matters: without
            // it a wearer whose word never changes during a session never seeds the cache
            // at all, and the complication sits on its placeholder forever.
            store.cache(verdict: new)
        }
        .onChange(of: scenePhase) { _, phase in
            // Streaming only while the app is in front. watchOS gives background work a
            // few seconds at most, so a stream that claimed to run all day would cost
            // battery and still be wrong.
            if phase == .active {
                health.startHeartRateStream()
                Task { await health.refresh() }
            } else {
                health.stopHeartRateStream()
            }
        }
    }
}

/// The three pages, and the deep link that opens each one.
enum WatchPage: String, Hashable, CaseIterable {
    case now
    case why
    case today

    /// Host of the complication deep links, e.g. `laso-watch://why`.
    static let scheme = "laso-watch"

    var url: URL { URL(string: "\(Self.scheme)://\(rawValue)")! }

    init?(url: URL) {
        guard url.scheme == Self.scheme,
              let page = WatchPage(rawValue: url.host() ?? "") else { return nil }
        self = page
    }

    /// Always the answer in a shipping build. The environment override exists so a
    /// screenshot pass can reach pages the simulator cannot be scrolled to; it is
    /// compiled out of Release.
    static var initialPage: WatchPage {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["LASO_WATCH_PAGE"],
           let page = WatchPage(rawValue: raw) {
            return page
        }
        #endif
        return .now
    }
}

// MARK: - Page 1, the answer

private struct NowPage: View {

    let verdict: WatchVerdict?
    let store: WatchStore
    let isDimmed: Bool

    var body: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)

            if let verdict {
                if isDimmed {
                    // Apple: "always hide any highly sensitive information, such as
                    // financial information or health data". A recovery word is health
                    // data and anyone behind the wearer can read a dimmed screen, so it
                    // is replaced, not merely dimmed. The layout keeps its shape so
                    // nothing jumps on wrist raise.
                    RedactedBlock()
                } else {
                    Text(WatchStrings.Verdict.word(verdict.word))
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(WatchTheme.color(for: verdict))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    // Wraps to two lines rather than truncating. A clipped reason is
                    // worse than a smaller one: the word alone cannot be acted on.
                    Text(verdict.reason)
                        .font(.footnote)
                        .foregroundStyle(WatchTheme.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)

                    if let headroomLine = verdict.headroomLine {
                        Text(headroomLine)
                            .font(.footnote)
                            .foregroundStyle(WatchTheme.tertiary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                }
            } else {
                HealthOffBlock()
            }

            Spacer(minLength: 0)
            FreshnessFooter(store: store, isDimmed: isDimmed)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
    }
}

/// The one state in the design with no word, because the wrist genuinely measured
/// nothing. It names the exact switch to turn on rather than sending anyone to a phone.
private struct HealthOffBlock: View {
    var body: some View {
        VStack(spacing: 4) {
            Text(WatchStrings.State.healthOffTitle)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
            Text(WatchStrings.State.healthOffDetail)
                .font(.caption2)
                .foregroundStyle(WatchTheme.secondary)
            Text(WatchStrings.State.healthOffHint)
                .font(.caption2)
                .foregroundStyle(WatchTheme.tertiary)
        }
        .multilineTextAlignment(.center)
    }
}

private struct RedactedBlock: View {
    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .stroke(WatchTheme.track, lineWidth: 2)
                .frame(height: 34)
            RoundedRectangle(cornerRadius: 6)
                .stroke(WatchTheme.track, lineWidth: 2)
                .frame(height: 14)
        }
        .padding(.horizontal, 18)
    }
}

/// Freshness is always on screen.
///
/// The wrist can only refresh a few times an hour, so it will disagree with the phone.
/// Competitors that hide that fact collect "the watch is wrong" reports; this states the
/// age instead.
private struct FreshnessFooter: View {

    let store: WatchStore
    let isDimmed: Bool

    var body: some View {
        Group {
            if isDimmed {
                Text(" ")
            } else if let payload = store.payload, payload.dayKey == WatchBridge.dayKey(for: Date()) {
                Text("\(WatchStrings.Verdict.fromPhone) · \(WatchStrings.Verdict.freshMinutes(Int(payload.ageMinutes())))")
            } else {
                Text(WatchStrings.Verdict.liveNow)
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(WatchTheme.tertiary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

// MARK: - Page 2, why

private struct WhyPage: View {

    let store: WatchStore
    let health: WatchHealthStore
    let isDimmed: Bool

    private var payload: WatchPayload? {
        store.payload.flatMap { $0.dayKey == WatchBridge.dayKey(for: Date()) ? $0 : nil }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(WatchStrings.Why.title)
                    .font(.caption2)
                    .foregroundStyle(WatchTheme.tertiary)

                if isDimmed {
                    RedactedBlock()
                } else if let payload, payload.readinessScore > 0 {
                    Text("\(payload.readinessScore)")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(WatchTheme.color(for: WatchBand.of(score: payload.readinessScore)))

                    // Bars, not rings. Reading a comparison off a bar takes a fraction of
                    // the time a radial encoding needs, and a 5 second glance cannot
                    // afford the difference.
                    BaselineBar(
                        label: WatchStrings.Why.hrv,
                        value: health.heartRateVariability,
                        baseline: payload.hrvBaselineFloor,
                        unit: "ms"
                    )
                    BaselineBar(
                        label: WatchStrings.Why.restingHeartRate,
                        value: health.restingHeartRate,
                        baseline: payload.restingHeartRateBaseline,
                        unit: "bpm"
                    )
                    BaselineBar(
                        label: WatchStrings.Why.exercise,
                        value: Double(health.exerciseMinutesToday),
                        baseline: payload.exerciseCeilingMinutes.map(Double.init),
                        unit: "min"
                    )

                    Text("| \(WatchStrings.Verdict.yourUsual)")
                        .font(.system(size: 11))
                        .foregroundStyle(WatchTheme.tertiary)
                } else {
                    Text(WatchStrings.Why.noScore)
                        .font(.footnote)
                        .foregroundStyle(WatchTheme.secondary)
                    Text(WatchStrings.State.noPhoneYet)
                        .font(.caption2)
                        .foregroundStyle(WatchTheme.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
    }
}

/// One measured value against this wearer's own reference, with a tick marking the
/// reference. A number with no reference frame cannot drive a decision.
private struct BaselineBar: View {

    let label: String
    let value: Double?
    let baseline: Double?
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(WatchTheme.secondary)
                Spacer()
                Text(value.map { "\(Int($0.rounded())) \(unit)" } ?? "--")
                    .font(.caption2.weight(.semibold))
            }
            GeometryReader { geometry in
                let scale = max(value ?? 0, baseline ?? 0) * 1.35
                ZStack(alignment: .leading) {
                    Capsule().fill(WatchTheme.track)
                    if let value, scale > 0 {
                        Capsule()
                            .fill(WatchTheme.secondary)
                            .frame(width: geometry.size.width * min(1, value / scale))
                    }
                    if let baseline, scale > 0 {
                        Rectangle()
                            .fill(WatchTheme.tertiary)
                            .frame(width: 2)
                            .offset(x: geometry.size.width * min(1, baseline / scale))
                    }
                }
            }
            .frame(height: 7)
        }
    }
}

// MARK: - Page 3, today

private struct TodayPage: View {

    let store: WatchStore
    let health: WatchHealthStore
    let verdict: WatchVerdict?
    let isDimmed: Bool

    @Binding var showCheckIn: Bool
    @Binding var showJournal: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(WatchStrings.Next.title)
                    .font(.caption2)
                    .foregroundStyle(WatchTheme.tertiary)

                if isDimmed {
                    RedactedBlock()
                } else {
                    row(WatchStrings.Next.exercise, "\(health.exerciseMinutesToday) min")
                    row(WatchStrings.Next.steps, "\(health.stepsToday)")
                    if let headroom = verdict?.headroomMinutes {
                        row(WatchStrings.Next.ceiling, "\(headroom) min")
                    }

                    if let rejection = store.rejection {
                        Text(WatchStrings.Write.message(for: rejection))
                            .font(.caption2)
                            .foregroundStyle(WatchTheme.poor)
                    }

                    action

                    if store.payload?.checkInAvailable == true {
                        Button(WatchStrings.CheckIn.greeting) { showCheckIn = true }
                            .buttonStyle(.bordered)
                    }
                    Button(WatchStrings.Journal.title) { showJournal = true }
                        .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private var action: some View {
        if let headline = store.payload?.actionHeadline {
            Text(headline)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                store.markActionDone()
                WatchHaptics.success()
            } label: {
                Label(
                    store.isActionDoneToday ? WatchStrings.Home.markedDone : WatchStrings.Home.markDone,
                    systemImage: store.isActionDoneToday ? "checkmark.circle.fill" : "checkmark"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isActionDoneToday || store.hasPendingWrite)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundStyle(WatchTheme.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
        }
    }
}

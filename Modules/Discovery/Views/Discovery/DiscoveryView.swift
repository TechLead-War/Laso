import SwiftUI

/// Full-screen paged reveal of personalized health discoveries shown once after first data import.
struct DiscoveryView: View {
    let discoveries: [Discovery]
    let dataDepth: (metricsTracked: Int, totalDataPoints: Int, daysOfData: Int)
    let onDismiss: () -> Void

    @State private var currentPage = 0
    @State private var appeared = false
    @State private var maxPageViewed = 0
    @State private var flowTracker = SectionTracker(section: .discoveryFlow, tab: .discovery)

    /// When true, all repeating animations are suppressed to reduce GPU load.
    private var thermallyConstrained: Bool {
        let state = ProcessInfo.processInfo.thermalState
        return state == .serious || state == .critical
    }

    /// Total pages: opening + discoveries + CTA
    private var totalPages: Int {
        1 + discoveries.count + 1
    }

    var body: some View {
        ZStack {
            AppColour.surfaceBase.ignoresSafeArea()

            TabView(selection: $currentPage) {
                openingPage.tag(0)

                ForEach(Array(discoveries.enumerated()), id: \.element.id) { index, discovery in
                    discoveryPage(discovery, index: index + 1)
                        .tag(index + 1)
                }

                ctaPage.tag(discoveries.count + 1)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
        .interactiveDismissDisabled()
        .sensoryFeedback(.selection, trigger: currentPage)
        .onChange(of: currentPage) { _, newValue in
            maxPageViewed = max(maxPageViewed, newValue)
            trackPageView(newValue)
        }
        .onAppear {
            if thermallyConstrained {
                // Skip to final values without animation to save GPU under thermal pressure
                appeared = true
            } else {
                withAnimation(.easeInOut(duration: 0.6)) {
                    appeared = true
                }
            }
            let types = discoveries.map(\.type.rawValue)
            AppAnalytics.shared.trackFeatureOpen(.discovery, metadata: [
                "discovery_count": discoveries.count,
                "days_of_data": dataDepth.daysOfData
            ])
            AppAnalytics.shared.trackDiscoveryShown(count: discoveries.count, types: types)
            flowTracker.appeared()
        }
        .onDisappear {
            AppAnalytics.shared.trackFeatureClose(.discovery, metadata: [
                "max_page_viewed": maxPageViewed,
                "total_pages": totalPages
            ])
            flowTracker.disappeared()
        }
    }

    // MARK: - Opening Stats Page

    private var openingPage: some View {
        VStack(spacing: DS.sectionSpacing) {
            Spacer()

            // Animated icon
            ZStack {
                Circle()
                    .fill(AppColour.primary.opacity(0.08))
                    .frame(width: 140, height: 140)
                    .scaleEffect(appeared ? 1.2 : 0.8)
                    .animation(
                        thermallyConstrained
                            ? .easeInOut(duration: 0.6)
                            : .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: appeared
                    )

                Circle()
                    .fill(AppColour.primary.opacity(0.04))
                    .frame(width: 180, height: 180)
                    .scaleEffect(appeared ? 1.4 : 0.9)
                    .animation(.easeInOut(duration: 1.0), value: appeared)

                Image(systemName: "waveform.path.ecg")
                    .font(DS.Typography.largeIcon)
                    .foregroundStyle(AppColour.primary)
                    .frame(width: 90, height: 90)
                    .background(AppColour.primary.opacity(0.12), in: Circle())
            }

            VStack(spacing: DS.itemSpacing) {
                Text("We analyzed your health history")
                    .font(DS.Typography.title3)
                    .multilineTextAlignment(.center)

                // Stats
                VStack(spacing: DS.space2) {
                    statRow(value: formatMonths(dataDepth.daysOfData), label: "of health data")
                    statRow(value: formatNumber(dataDepth.totalDataPoints), label: "data points")
                    statRow(value: "\(dataDepth.metricsTracked)", label: "health metrics")
                }
                .padding(.top, DS.space2)
            }

            Text("Here is what we found")
                .font(DS.Typography.headline)
                .foregroundStyle(AppColour.primary)
                .padding(.top, DS.space2)

            // Swipe hint
            VStack(spacing: DS.space1) {
                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption2Semibold)
                    .foregroundStyle(AppColour.textTertiary)
                Text("Swipe to explore")
                    .font(DS.Typography.caption)
                    .foregroundStyle(AppColour.textTertiary)
            }
            .padding(.top, DS.space1)

            Spacer()
        }
        .padding(.horizontal, DS.space7)
    }

    // MARK: - Discovery Page

    private func discoveryPage(_ discovery: Discovery, index: Int) -> some View {
        VStack(spacing: DS.space7) {
            Spacer()

            // Icon with glow
            ZStack {
                Circle()
                    .fill(discovery.accentColor.opacity(0.08))
                    .frame(width: 130, height: 130)
                    .scaleEffect(appeared ? 1.15 : 0.9)
                    .animation(.easeInOut(duration: 0.8), value: appeared)

                Image(systemName: discovery.icon)
                    .font(DS.Typography.mediumIcon)
                    .foregroundStyle(discovery.accentColor)
                    .frame(width: 80, height: 80)
                    .background(discovery.accentColor.opacity(0.12), in: Circle())
            }

            VStack(spacing: DS.space4) {
                // Headline
                Text(discovery.headline)
                    .font(DS.Typography.title3)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)

                // Detail
                Text(discovery.detail)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(AppColour.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)

                // Evidence badge
                Text(discovery.evidence)
                    .font(DS.Typography.caption2Medium)
                    .foregroundStyle(AppColour.textSecondary)
                    .padding(.horizontal, DS.space3)
                    .padding(.vertical, 6)
                    .background(AppColour.surfaceElevated, in: Capsule())
            }

            Spacer()
        }
        .padding(.horizontal, DS.space7)
    }

    // MARK: - CTA Page

    private var ctaPage: some View {
        VStack(spacing: DS.sectionSpacing) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColour.success.opacity(0.08))
                    .frame(width: 130, height: 130)
                    .scaleEffect(appeared ? 1.15 : 0.9)
                    .animation(.easeInOut(duration: 0.8), value: appeared)

                Image(systemName: "checkmark.seal.fill")
                    .font(DS.Typography.largeIcon)
                    .foregroundStyle(AppColour.success)
                    .frame(width: 80, height: 80)
                    .background(AppColour.success.opacity(0.12), in: Circle())
            }

            VStack(spacing: DS.space2) {
                Text("Your Dashboard is Ready")
                    .font(DS.Typography.title3)

                Text("Track these patterns and more. Updated every time you open the app.")
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(AppColour.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                AppAnalytics.shared.trackBlockTap(
                    title: "Continue",
                    type: .discoveryContinue,
                    screen: .discovery,
                    metadata: [
                        "pages_viewed": maxPageViewed + 1,
                        "total_pages": totalPages
                    ]
                )
                flowTracker.tapped(target: "continue")
                AppAnalytics.shared.trackDiscoveryCompleted(
                    pagesViewed: maxPageViewed + 1,
                    totalPages: totalPages
                )
                onDismiss()
            } label: {
                Text("Continue")
            }
            .buttonStyle(.dsPrimary)
            .accessibilityLabel("Continue to dashboard")
            .accessibilityHint("Closes discovery and opens your dashboard")
            .padding(.horizontal, DS.space6)

            Spacer()
        }
        .padding(.horizontal, DS.space7)
    }

    // MARK: - Helpers

    private func statRow(value: String, label: String) -> some View {
        HStack(spacing: DS.space2) {
            Text(value)
                .font(DS.Typography.headline)
                .foregroundStyle(AppColour.textPrimary)
            Text(label)
                .font(DS.Typography.subheadline)
                .foregroundStyle(AppColour.textSecondary)
        }
    }

    private func formatMonths(_ days: Int) -> String {
        if days >= 365 {
            let years = days / 365
            return "\(years) year\(years == 1 ? "" : "s")"
        } else {
            let months = max(1, days / 30)
            return "\(months) month\(months == 1 ? "" : "s")"
        }
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1000 {
            return String(format: "%.1fK", Double(n) / 1000)
        }
        return "\(n)"
    }

    private func trackPageView(_ page: Int) {
        if page == 0 { return } // Opening page tracked via onAppear
        let discoveryIndex = page - 1
        if discoveryIndex < discoveries.count {
            let discovery = discoveries[discoveryIndex]
            AppAnalytics.shared.trackDiscoveryPageViewed(type: discovery.type.rawValue, index: discoveryIndex)
        }
    }
}

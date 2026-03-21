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
            Color(.systemBackground).ignoresSafeArea()

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
        VStack(spacing: 32) {
            Spacer()

            // Animated icon
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.08))
                    .frame(width: 140, height: 140)
                    .scaleEffect(appeared ? 1.2 : 0.8)
                    .animation(
                        thermallyConstrained
                            ? .easeInOut(duration: 0.6)
                            : .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: appeared
                    )

                Circle()
                    .fill(.blue.opacity(0.04))
                    .frame(width: 180, height: 180)
                    .scaleEffect(appeared ? 1.4 : 0.9)
                    .animation(.easeInOut(duration: 1.0), value: appeared)

                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(.blue)
                    .frame(width: 90, height: 90)
                    .background(.blue.opacity(0.12), in: Circle())
            }

            VStack(spacing: 12) {
                Text("We analyzed your health history")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                // Stats
                VStack(spacing: 8) {
                    statRow(value: formatMonths(dataDepth.daysOfData), label: "of health data")
                    statRow(value: formatNumber(dataDepth.totalDataPoints), label: "data points")
                    statRow(value: "\(dataDepth.metricsTracked)", label: "health metrics")
                }
                .padding(.top, 8)
            }

            Text("Here's what we found")
                .font(.headline)
                .foregroundStyle(.blue)
                .padding(.top, 8)

            // Swipe hint
            VStack(spacing: 4) {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
                Text("Swipe to explore")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 4)

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Discovery Page

    private func discoveryPage(_ discovery: Discovery, index: Int) -> some View {
        VStack(spacing: 28) {
            Spacer()

            // Icon with glow
            ZStack {
                Circle()
                    .fill(discovery.accentColor.opacity(0.08))
                    .frame(width: 130, height: 130)
                    .scaleEffect(appeared ? 1.15 : 0.9)
                    .animation(.easeInOut(duration: 0.8), value: appeared)

                Image(systemName: discovery.icon)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(discovery.accentColor)
                    .frame(width: 80, height: 80)
                    .background(discovery.accentColor.opacity(0.12), in: Circle())
            }

            VStack(spacing: 14) {
                // Headline
                Text(discovery.headline)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)

                // Detail
                Text(discovery.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)

                // Evidence badge
                Text(discovery.evidence)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.quaternary.opacity(0.5), in: Capsule())
            }

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - CTA Page

    private var ctaPage: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.green.opacity(0.08))
                    .frame(width: 130, height: 130)
                    .scaleEffect(appeared ? 1.15 : 0.9)
                    .animation(.easeInOut(duration: 0.8), value: appeared)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(.green)
                    .frame(width: 80, height: 80)
                    .background(.green.opacity(0.12), in: Circle())
            }

            VStack(spacing: 10) {
                Text("Your Dashboard is Ready")
                    .font(.title3.weight(.semibold))

                Text("Track these patterns and more. updated every time you open the app.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.blue, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Helpers

    private func statRow(value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(.primary)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
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

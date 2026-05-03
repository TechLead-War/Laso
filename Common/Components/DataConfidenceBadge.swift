import SwiftUI

/// Subtle inline indicator showing AI model training progress.
/// Tappable to expand tier details. Designed to be unobtrusive.
struct DataConfidenceBadge: View {
    let daysOfData: Int
    let metricsTracked: Int

    @State private var showDetail = false

    private var tier: Tier {
        Tier.from(days: daysOfData)
    }

    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.25)) {
                showDetail.toggle()
            }
            AppAnalytics.shared.trackBlockTap(
                title: "Data Confidence",
                type: .dataConfidenceBadge,
                screen: .home,
                metadata: ["tier": tier.name, "days": daysOfData]
            )
        } label: {
            VStack(spacing: showDetail ? 10 : 0) {
                compactPill
                if showDetail {
                    tierTimeline
                        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Copy.Common.dataConfidence(tier: tier.name))
        .accessibilityValue("\(daysOfData) days of data tracked")
        .accessibilityHint(showDetail ? "Tap to collapse tier timeline" : "Tap to show tier progression details")
    }

    // MARK: - Compact Pill

    private var compactPill: some View {
        HStack(spacing: 6) {
            Image(systemName: tier.icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tier.color)

            Text(tier.name)
                .font(.caption2.weight(.semibold))

            // Inline progress dots
            HStack(spacing: 3) {
                ForEach(Tier.allCases, id: \.self) { t in
                    Circle()
                        .fill(daysOfData >= t.minDays ? t.color : Color(.systemGray4))
                        .frame(width: 4, height: 4)
                }
            }

            if let next = tier.nextUnlock {
                Text(next)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Image(systemName: showDetail ? "chevron.up" : "chevron.down")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tier.color.opacity(0.08), in: Capsule())
    }

    // MARK: - Expanded Timeline

    private var tierTimeline: some View {
        HStack(spacing: 0) {
            ForEach(Array(Tier.allCases.enumerated()), id: \.element) { index, t in
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(daysOfData >= t.minDays ? t.color : Color(.systemGray5))
                            .frame(width: 20, height: 20)
                        if daysOfData >= t.minDays {
                            Image(systemName: "checkmark")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }

                    Text(t.name)
                        .font(.caption2.weight(daysOfData >= t.minDays ? .semibold : .regular))
                        .foregroundStyle(daysOfData >= t.minDays ? .primary : .secondary)

                    Text(t.shortLabel)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)

                if index < Tier.allCases.count - 1 {
                    Rectangle()
                        .fill(daysOfData > t.maxDays ? t.color : Color(.systemGray5))
                        .frame(height: 2)
                        .frame(maxWidth: 24)
                        .padding(.bottom, DS.space6)
                }
            }
        }
        .padding(.horizontal, DS.space1)
        .padding(.vertical, 6)
        .background(Color(.systemGray6).opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Tier Definition

private enum Tier: String, CaseIterable, Hashable {
    case starter, building, growing, mature, expert

    var name: String {
        switch self {
        case .starter:  return "Starter"
        case .building: return "Building"
        case .growing:  return "Growing"
        case .mature:   return "Mature"
        case .expert:   return "Expert"
        }
    }

    var minDays: Int {
        switch self {
        case .starter: 0; case .building: 7; case .growing: 21; case .mature: 60; case .expert: 90
        }
    }

    var maxDays: Int {
        switch self {
        case .starter: 6; case .building: 20; case .growing: 59; case .mature: 89; case .expert: Int.max
        }
    }

    var icon: String {
        switch self {
        case .starter, .building: return "brain"
        case .growing, .mature: return "brain.head.profile"
        case .expert: return "sparkles"
        }
    }

    var color: Color {
        switch self {
        case .starter: .gray; case .building: .blue; case .growing: .purple; case .mature: .orange; case .expert: .yellow
        }
    }

    var nextUnlock: String? {
        switch self {
        case .starter:  return "Insights at 7d"
        case .building: return "Correlations at 21d"
        case .growing:  return "Unusual patterns at 60d"
        case .mature:   return "Predictions at 90d"
        case .expert:   return nil
        }
    }

    var shortLabel: String {
        switch self {
        case .starter: "0-6d"; case .building: "7-20d"; case .growing: "21-59d"; case .mature: "60-89d"; case .expert: "90d+"
        }
    }

    static func from(days: Int) -> Tier {
        switch days {
        case 0...6: .starter; case 7...20: .building; case 21...59: .growing; case 60...89: .mature; default: .expert
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        DataConfidenceBadge(daysOfData: 3, metricsTracked: 8)
        DataConfidenceBadge(daysOfData: 14, metricsTracked: 12)
        DataConfidenceBadge(daysOfData: 75, metricsTracked: 18)
        DataConfidenceBadge(daysOfData: 120, metricsTracked: 20)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

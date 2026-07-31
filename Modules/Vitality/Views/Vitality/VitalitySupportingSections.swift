import SwiftUI

// MARK: - Improvements

struct VitalityImprovementSection: View {
    let scorer: VitalityScorer

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            vitalitySectionHeader(icon: "lightbulb.fill", title: Copy.Vitality.topImprovements)

            VStack(spacing: 10) {
                ForEach(scorer.topImprovementOpportunities) { component in
                    improvementCard(component)
                }
            }
            .padding(.horizontal)
        }
    }

    private func improvementCard(_ component: VitalityComponent) -> some View {
        // Same label as the contributions row: a clamped metric age has no year
        // gap behind it, so the badge must not print one either.
        let impact = vitalityMetricDeltaLabel(component, chronologicalAge: scorer.chronologicalAge)
        let icon = component.healthMetric?.systemImageName ?? "arrow.up.circle.fill"

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(DS.Typography.caption.weight(.semibold))
                    .foregroundStyle(AppColour.warning)
                    .frame(width: 30, height: 30)
                    .background(AppColour.warning.opacity(0.14), in: RoundedRectangle(cornerRadius: DS.Radius.sm))

                Text(component.metric)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text(impact)
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(AppColour.textOnAccent)
                    .padding(.horizontal, DS.badgeH + 2)
                    .padding(.vertical, DS.badgeV + 1)
                    .background(AppColour.warning, in: Capsule())
            }

            Text(component.improvementSuggestion)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.cardPadding)
        .cardStyle(tint: AppColour.warning)
    }
}

// MARK: - Data Maturity Banner

struct VitalityDataMaturityBanner: View {
    let scorer: VitalityScorer

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: vitalityPersonalizationIcon(for: scorer))
                    .font(DS.Typography.body.weight(.semibold))
                    .foregroundStyle(vitalityPersonalizationTint(for: scorer))

                VStack(alignment: .leading, spacing: 2) {
                    Text(bannerTitle)
                        .font(.subheadline.weight(.semibold))

                    Text(dataMaturityDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            let days = scorer.availableDays
            let target = VitalityScorer.minimumDaysRequired
            let progress = min(1.0, Double(days) / Double(target))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: DS.Radius.xs)
                        .fill(AppColour.trackNeutral)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: DS.Radius.xs)
                        .fill(vitalityWhoopGreen)
                        .frame(width: geo.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)

            HStack {
                Text(Copy.Vitality.dataProgress(days: days, target: target))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Copy.Vitality.progressPercent(Int(progress * 100)))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(vitalityWhoopGreen)
            }
        }
        .padding(DS.cardPadding)
        .background(vitalityWhoopGreen.opacity(0.08), in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .strokeBorder(vitalityWhoopGreen.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    private var dataMaturityDescription: String {
        if scorer.personalizationStatus == .buildingProfile {
            return Copy.Vitality.buildingProfileDescription
        }
        return Copy.Vitality.earlyEstimateDescription
    }

    private var bannerTitle: String {
        if scorer.personalizationStatus == .buildingProfile {
            return Copy.Vitality.profileProgressTitle
        }
        return scorer.personalizationStatus.rawValue
    }
}

// MARK: - Methodology

struct VitalityMethodologySection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            vitalitySectionHeader(icon: "info.circle.fill", title: Copy.Vitality.howThisWorks)

            Text(Copy.Vitality.methodology)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(DS.cardPadding)
                .cardStyle()
                .padding(.horizontal)
        }
    }
}

import SwiftUI

struct VitalityHeroSection: View {
    let scorer: VitalityScorer
    let orbPhase: CGFloat

    private var paceTint: Color { vitalityPaceTint(for: scorer) }

    var body: some View {
        VStack(spacing: 14) {
            GeometryReader { geo in
                let containerW = geo.size.width
                let orbW = containerW * 0.95
                let orbH = orbW * 0.95
                let chipW = containerW * 0.46
                let chipOffsetX = (containerW - chipW) / 2 - 4

                ZStack {
                    OrganicParticleOrbView(phase: orbPhase, tint: paceTint)
                        .frame(width: orbW, height: orbH)

                    VStack(spacing: 6) {
                        Text("\(scorer.vitalityAge)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)

                        Text(Copy.Vitality.vitalityAgeLabel)
                            .font(.system(size: 13, weight: .semibold))
                            .tracking(2)
                            .foregroundStyle(.white.opacity(0.8))

                        Text(deltaBadgeText)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(vitalityDeltaColor(for: scorer.delta))
                            .monospacedDigit()
                    }

                    if heroComponents.indices.contains(0) {
                        OrbMetricChip(
                            component: heroComponents[0],
                            chronologicalAge: scorer.chronologicalAge,
                            healthyTint: vitalityWhoopGreen,
                            cautionTint: vitalityPaceYellow,
                            riskTint: vitalityPaceRed,
                            chipWidth: chipW
                        )
                        .offset(x: -chipOffsetX, y: -orbH * 0.40)
                    }

                    if heroComponents.indices.contains(1) {
                        OrbMetricChip(
                            component: heroComponents[1],
                            chronologicalAge: scorer.chronologicalAge,
                            healthyTint: vitalityWhoopGreen,
                            cautionTint: vitalityPaceYellow,
                            riskTint: vitalityPaceRed,
                            chipWidth: chipW
                        )
                        .offset(x: -chipOffsetX, y: orbH * 0.40)
                    }

                    if heroComponents.indices.contains(2) {
                        OrbMetricChip(
                            component: heroComponents[2],
                            chronologicalAge: scorer.chronologicalAge,
                            healthyTint: vitalityWhoopGreen,
                            cautionTint: vitalityPaceYellow,
                            riskTint: vitalityPaceRed,
                            chipWidth: chipW
                        )
                        .offset(x: chipOffsetX, y: orbH * 0.28)
                    }
                }
                .frame(width: containerW, height: geo.size.height)
            }
            .aspectRatio(0.92, contentMode: .fit)

            HStack(spacing: 8) {
                badge(text: Copy.Vitality.actualAge(scorer.chronologicalAge), tint: .white.opacity(0.36), foreground: .white)

                if scorer.personalizationStatus == .personalized {
                    badge(
                        text: Copy.Vitality.ninetyDayPace(scorer.paceLabel),
                        tint: paceTint.opacity(0.26),
                        foreground: paceTint,
                        icon: vitalityPaceIcon(for: scorer)
                    )

                    badge(
                        text: vitalityPaceStateText(for: scorer),
                        tint: paceTint.opacity(0.26),
                        foreground: paceTint
                    )
                } else {
                    badge(
                        text: scorer.personalizationStatus.rawValue,
                        tint: vitalityPersonalizationTint(for: scorer).opacity(0.24),
                        foreground: vitalityPersonalizationTint(for: scorer),
                        icon: vitalityPersonalizationIcon(for: scorer)
                    )
                }
            }

            Text(heroNarrative)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.95), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(paceTint.opacity(0.42), lineWidth: 1)
        )
        .shadow(color: paceTint.opacity(0.22), radius: 16, y: 8)
        .padding(.horizontal)
    }

    private func badge(text: String, tint: Color, foreground: Color, icon: String? = nil) -> some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption2.weight(.bold))
            }
            Text(text)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, DS.badgeH + 3)
        .padding(.vertical, DS.badgeV + 2)
        .background(tint, in: Capsule())
    }

    private var heroNarrative: String {
        if scorer.personalizationStatus == .buildingProfile {
            return Copy.Vitality.buildingProfileNarrative
        }
        if scorer.personalizationStatus == .earlyEstimate {
            if scorer.delta < 0 {
                return Copy.Vitality.earlyYoungerNarrative(delta: abs(scorer.delta))
            }
            if scorer.delta > 0 {
                return Copy.Vitality.earlyOlderNarrative(delta: scorer.delta)
            }
            return Copy.Vitality.earlyAlignedNarrative
        }

        if scorer.delta < 0 {
            return Copy.Vitality.personalYoungerNarrative(delta: abs(scorer.delta))
        }
        if scorer.delta > 0 {
            return Copy.Vitality.personalOlderNarrative(delta: scorer.delta)
        }
        return Copy.Vitality.personalAlignedNarrative
    }

    private var heroComponents: [VitalityComponent] {
        if scorer.personalizationStatus == .buildingProfile {
            return []
        }
        return Array(
            scorer.componentAges
                .sorted {
                    abs($0.delta(chronologicalAge: scorer.chronologicalAge)) >
                    abs($1.delta(chronologicalAge: scorer.chronologicalAge))
                }
                .prefix(3)
        )
    }

    private var deltaBadgeText: String {
        if scorer.personalizationStatus == .buildingProfile {
            return Copy.Vitality.buildingProfile
        }
        if scorer.delta < 0 { return Copy.Vitality.yearsYounger(abs(scorer.delta)) }
        if scorer.delta > 0 { return Copy.Vitality.yearsOlder(scorer.delta) }
        return Copy.Vitality.onTrack
    }
}

// MARK: - Orb Metric Chip

struct OrbMetricChip: View {
    let component: VitalityComponent
    let chronologicalAge: Int
    let healthyTint: Color
    let cautionTint: Color
    let riskTint: Color
    var chipWidth: CGFloat = 176

    private var metricDelta: Int { component.delta(chronologicalAge: chronologicalAge) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(component.metric.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)

            HStack(spacing: 6) {
                Text(valueText)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text(deltaText)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(deltaTint)
                    .monospacedDigit()
            }

            chipGauge
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .frame(width: chipWidth)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }

    private var chipGauge: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let markerX = max(0, min(width - 6, width * gaugePosition))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [riskTint.opacity(0.8), cautionTint.opacity(0.8), healthyTint.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 4)

                Circle()
                    .fill(.white.opacity(0.92))
                    .frame(width: 6, height: 6)
                    .offset(x: markerX, y: -1)
            }
        }
        .frame(height: 7)
    }

    private var gaugePosition: Double {
        vitalityMetricGaugePosition(component)
    }

    private var valueText: String {
        vitalityFormatMetricValue(component.currentValue, unit: component.unit, metric: component.healthMetric)
    }

    private var deltaText: String {
        if metricDelta < 0 { return "\(abs(metricDelta))y" }
        if metricDelta > 0 { return "+\(metricDelta)y" }
        return "0y"
    }

    private var deltaTint: Color {
        if metricDelta <= 0 { return healthyTint }
        if metricDelta <= 2 { return cautionTint }
        return riskTint
    }
}

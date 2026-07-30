import SwiftUI

struct VitalityHeroSection: View {
    let scorer: VitalityScorer
    let orbPhase: CGFloat
    let orbPaused: Bool

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
                    OrganicParticleOrbView(phase: orbPhase, tint: paceTint, paused: orbPaused)
                        .frame(width: orbW, height: orbH)

                    VStack(spacing: 6) {
                        Text(scorer.vitalityAge > 0 ? "\(scorer.vitalityAge)" : "—")
                            .font(DS.Typography.displayXL)
                            .monospacedDigit()
                            .foregroundStyle(AppColour.textOnInverse)
                            .postHogMask()

                        Text(Copy.Vitality.vitalityAgeLabel)
                            .font(DS.Typography.caption.weight(.semibold))
                            .tracking(2)
                            .foregroundStyle(AppColour.textOnInverseSecondary)

                        if scorer.personalizationStatus != .buildingProfile {
                            Text(deltaBadgeText)
                                .font(DS.Typography.title3.weight(.bold))
                                .foregroundStyle(vitalityDeltaColor(for: scorer.delta))
                                .monospacedDigit()
                                .postHogMask()
                        }
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

            // Two rows, not one. Three pills of this copy do not fit the card
            // width on the smallest phones, and the pace state pill was the one
            // that truncated.
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    if scorer.chronologicalAge > 0 {
                        badge(text: Copy.Vitality.actualAge(scorer.chronologicalAge), tint: AppColour.surfaceInverseRaised, foreground: AppColour.textOnInverse)
                    }

                    if scorer.personalizationStatus == .personalized && scorer.hasPaceEstimate {
                        badge(
                            text: Copy.Vitality.paceOverDays(days: scorer.historySpanDays, label: scorer.paceLabel),
                            tint: paceTint.opacity(0.26),
                            foreground: paceTint,
                            icon: vitalityPaceIcon(for: scorer)
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

                if scorer.personalizationStatus == .personalized {
                    // The waiting-for-history tint is tuned for the light trend
                    // card, and it disappears against this dark hero. On here it
                    // reads as white like the sibling badge instead.
                    let stateTint = scorer.hasPaceEstimate ? paceTint : AppColour.textOnInverse
                    badge(
                        text: vitalityPaceStateText(for: scorer),
                        tint: stateTint.opacity(0.26),
                        foreground: stateTint
                    )
                }
            }

            Text(heroNarrative)
                .font(.subheadline)
                .foregroundStyle(AppColour.textOnInverseSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, DS.space2)
        }
        .padding(DS.cardPadding)
        .frame(maxWidth: .infinity)
        // Stays dark in light mode too: the orb inside paints with .plusLighter /
        // .screen, which are arithmetic no-ops against a light destination, and every
        // label on this card is an on-inverse token. Hence surfaceInverse, not a
        // theme-following surface.
        .background(
            RoundedRectangle(cornerRadius: DS.cardRadius, style: .continuous)
                .fill(AppColour.surfaceInverse)
                // Shadow sits on the opaque fill and BEFORE the gradient overlay.
                // Hung on the composed card instead, its source is the animating
                // particle orb, so it re-blurs offscreen every frame; hung after
                // the overlay it becomes a composite shadow and caches no better.
                .shadow(color: AppColour.shadowAmbient, radius: 16, y: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.cardRadius, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [Color.clear, paceTint.opacity(0.20)],
                                center: .center,
                                startRadius: 60,
                                endRadius: 320
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.cardRadius, style: .continuous)
                .strokeBorder(paceTint.opacity(0.42), lineWidth: 1)
        )
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
                .font(DS.Typography.caption2.weight(.bold))
                .foregroundStyle(AppColour.textOnInverseSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            HStack(spacing: 6) {
                Text(valueText)
                    .font(DS.Typography.caption2.weight(.semibold))
                    .foregroundStyle(AppColour.textOnInverse)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .postHogMask()

                Spacer(minLength: 4)

                Text(deltaText)
                    .font(DS.Typography.caption2.weight(.bold))
                    .foregroundStyle(deltaTint)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .postHogMask()
            }

            chipGauge
        }
        .padding(.horizontal, DS.space3)
        .padding(.vertical, DS.space2)
        .frame(width: chipWidth)
        // The chip floats on the always-dark hero, so its surface and hairline are
        // the fixed-polarity pair, not the theme-following ones.
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(AppColour.surfaceInverseRaised.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .strokeBorder(AppColour.borderOnInverse, lineWidth: 0.5)
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
                    .fill(AppColour.markerOnInverse)
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
        vitalityMetricDeltaLabel(component, chronologicalAge: chronologicalAge)
    }

    private var deltaTint: Color {
        // Beating the youngest reference row is a good result even for a user
        // below that age, where the clamped delta still reads positive.
        if component.isBeyondYoungestReference { return healthyTint }
        if metricDelta <= 0 { return healthyTint }
        if metricDelta <= 2 { return cautionTint }
        return riskTint
    }
}

import SwiftUI

struct VitalityMetricContributionSection: View {
    let scorer: VitalityScorer

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            vitalitySectionHeader(icon: "chart.bar.fill", title: Copy.Vitality.metricContributions)

            VStack(spacing: 0) {
                ForEach(Array(scorer.componentAges.enumerated()), id: \.element.id) { index, component in
                    metricRow(component)

                    if index < scorer.componentAges.count - 1 {
                        Divider()
                            .padding(.leading, DS.cardPadding + 40 + 10)
                    }
                }
            }
            .cardStyle()
            .padding(.horizontal)
        }
    }

    private func metricRow(_ component: VitalityComponent) -> some View {
        let metricDelta = component.delta(chronologicalAge: scorer.chronologicalAge)
        // Beating the youngest reference row is a good result even for a user
        // below that age, where the clamped delta still reads positive.
        let tint = component.isBeyondYoungestReference
            ? vitalityWhoopGreen
            : vitalityDeltaColor(for: metricDelta)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: component.healthMetric?.systemImageName ?? "heart.fill")
                    .font(DS.Typography.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: DS.Radius.md))

                VStack(alignment: .leading, spacing: 2) {
                    Text(component.metric)
                        .font(.subheadline.weight(.semibold))

                    Text(metricSubtitle(for: component))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .postHogMask()
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(Copy.Vitality.ageLabel(component.metricAge))
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(tint)
                        .postHogMask()

                    Text(vitalityMetricDeltaLabel(component, chronologicalAge: scorer.chronologicalAge))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(tint.opacity(0.85))
                        .postHogMask()
                }
            }

            metricValueBar(component: component, tint: tint)
        }
        .padding(.horizontal, DS.cardPadding)
        .padding(.vertical, DS.space2)
    }

    private func metricValueBar(component: VitalityComponent, tint: Color) -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            let markerX = max(0, min(width - 8, width * vitalityMetricGaugePosition(component)))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(
                        // Opaque stops: at 28% alpha the three hues composite into
                        // near-identical pastels on a light card and the red-to-green
                        // ramp stops reading as a ramp.
                        LinearGradient(
                            colors: [AppColour.danger, AppColour.warning, vitalityWhoopGreen],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 5)

                Circle()
                    .fill(tint)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(AppColour.markerOnSurface, lineWidth: 1))
                    .offset(x: markerX, y: -1.5)
            }
        }
        .frame(height: 8)
    }

    private func metricSubtitle(for component: VitalityComponent) -> String {
        let current = vitalityFormatMetricValue(component.currentValue, unit: component.unit, metric: component.healthMetric)
        let expected = vitalityFormatMetricValue(component.referenceValue, unit: component.unit, metric: component.healthMetric)
        return component.referenceIsTarget
            ? Copy.Vitality.metricTargetSubtitle(current: current, expected: expected)
            : Copy.Vitality.metricSubtitle(current: current, expected: expected)
    }
}

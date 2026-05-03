import SwiftUI

// MARK: - Today Briefing View

/// Horizontal scroll strip of intelligence cards. non-obvious health findings
/// surfaced by the on-device ML engine. Each card is a compact, information-dense
/// tile showing a single predictive or analytical finding the user could not
/// derive from raw metrics alone.
struct TodayBriefingView: View {
    let cards: [IntelligenceCard]
    @State private var selectedCard: IntelligenceCard?

    var body: some View {
        if !cards.isEmpty {
            briefingSection
                .sheet(item: $selectedCard) { card in
                    BriefingDetailSheet(card: card)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
        }
    }

    // MARK: - Section Layout

    @ViewBuilder
    private var briefingSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            sectionHeader
                .padding(.horizontal, DS.screenPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(cards) { card in
                        BriefingCardView(card: card) {
                            selectedCard = card
                        }
                    }
                }
                .padding(.leading)
                .padding(.trailing, 40)
            }
        }
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        HStack(spacing: DS.space1) {
            Image(systemName: "brain.head.profile.fill")
                .font(DS.Typography.calloutSemibold)
                .foregroundStyle(AppColour.textSecondary)
            Text(Copy.Home.bodyIntelligence)
                .font(DS.Typography.calloutSemibold)
                .foregroundStyle(AppColour.textSecondary)
        }
    }
}

// MARK: - Individual Briefing Card

private struct BriefingCardView: View {
    let card: IntelligenceCard
    let onTap: () -> Void

    @State private var tapped = false

    private var accent: Color {
        card.accentColor.resolved
    }

    private var severityDotColor: Color {
        switch card.severity {
        case .critical: AppColour.danger
        case .warning: AppColour.warning
        case .notable: AppColour.scoreFair
        case .info: AppColour.success
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Accent bar
            Rectangle()
                .fill(accent)
                .frame(height: 3)

            VStack(alignment: .leading, spacing: DS.space2) {
                // Label
                Text(card.label)
                    .font(DS.Typography.captionSemibold)
                    .foregroundStyle(accent)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                // Headline
                Text(card.headline)
                    .font(DS.Typography.bodySemibold)
                    .foregroundStyle(AppColour.textPrimary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                // Detail
                Text(card.detail)
                    .font(DS.Typography.callout)
                    .foregroundStyle(AppColour.textSecondary)
                    .lineLimit(2)

                Spacer(minLength: 0)

                // Bottom row: confidence pill + severity dot
                HStack(spacing: DS.space1) {
                    Text(Copy.Briefing.confidenceBadge(percent: Int(card.confidence * 100)))
                        .font(DS.Typography.footnote.monospaced())
                        .foregroundStyle(accent)
                        .padding(.horizontal, DS.badgeH)
                        .padding(.vertical, DS.badgeV)
                        .background(accent.opacity(DS.badgeBg), in: Capsule())

                    Spacer(minLength: 0)

                    Circle()
                        .fill(severityDotColor)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(DS.cardPadding)
        }
        .frame(width: 220)
        .frame(minHeight: 120)
        .background(accent.opacity(DS.tintBg), in: RoundedRectangle(cornerRadius: DS.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cardRadius)
                .strokeBorder(accent.opacity(DS.strokeAlpha), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        .clipShape(RoundedRectangle(cornerRadius: DS.cardRadius))
        .sensoryFeedback(.impact(flexibility: .soft), trigger: tapped)
        .contentShape(Rectangle())
        .onTapGesture {
            tapped.toggle()
            onTap()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(card.label): \(card.headline)")
        .accessibilityHint("Opens the full insight")
    }
}

// MARK: - Detail Sheet

/// Full insight reveal — opened when a briefing card is tapped. Eliminates
/// the strip's text trimming and gives the card's accent colour, severity,
/// confidence, and full body the room they need.
private struct BriefingDetailSheet: View {
    let card: IntelligenceCard
    @Environment(\.dismiss) private var dismiss

    private var accent: Color {
        card.accentColor.resolved
    }

    private var severityLabel: String {
        switch card.severity {
        case .critical: return "Critical"
        case .warning:  return "Warning"
        case .notable:  return "Notable"
        case .info:     return "Insight"
        }
    }

    private var severityColor: Color {
        switch card.severity {
        case .critical: return AppColour.danger
        case .warning:  return AppColour.warning
        case .notable:  return AppColour.scoreFair
        case .info:     return AppColour.success
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Hero — accent-tinted icon, label kicker, full headline (no trim).
                    VStack(alignment: .leading, spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(accent.opacity(0.18))
                                .frame(width: 72, height: 72)
                            Image(systemName: card.icon)
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(accent)
                        }

                        Text(card.label.uppercased())
                            .font(DS.Typography.captionSemibold)
                            .tracking(1.4)
                            .foregroundStyle(accent)

                        Text(card.headline)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppColour.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Detail body (no trim) + inline data chips.
                    VStack(alignment: .leading, spacing: 16) {
                        Text(card.detail)
                            .font(.body)
                            .foregroundStyle(AppColour.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            chip(label: severityLabel, color: severityColor, icon: "circle.fill")
                            chip(
                                label: "\(Int((card.confidence * 100).rounded()))% confidence",
                                color: accent,
                                icon: "checkmark.seal.fill"
                            )
                        }
                    }

                    Spacer(minLength: 16)

                    // Footer — quiet attribution.
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                        Text(Copy.Home.Cards.generatedByLasoIntelligence)
                            .font(.caption2)
                    }
                    .foregroundStyle(AppColour.textTertiary)
                }
                .padding(.horizontal, DS.screenPadding)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(AppColour.surfaceBase.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(Copy.Buttons.done) { dismiss() }
                }
            }
        }
    }

    private func chip(label: String, color: Color, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2.weight(.bold))
            Text(label)
                .font(DS.Typography.caption.weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15), in: Capsule())
    }
}

// MARK: - Accent Color Resolution

extension IntelligenceCard.AccentColor {
    var resolved: Color {
        switch self {
        case .red: AppColour.danger
        case .orange: AppColour.warning
        case .yellow: AppColour.scoreFair
        case .green: AppColour.success
        case .blue: AppColour.info
        case .purple: AppColour.categoryStress
        }
    }
}

// MARK: - Preview

#Preview("Body Intelligence Strip") {
    let sampleCards: [IntelligenceCard] = [
        IntelligenceCard(
            type: .predictiveRisk,
            icon: "exclamationmark.triangle.fill",
            label: Copy.Briefing.Labels.headsUp,
            headline: "Your HRV has been dropping since Friday. The last time this happened, it was because you had less deep sleep for 3 nights in a row. You bounced back after 2 good nights.",
            detail: "This is mainly because your resting heart rate has been off. Based on how your body has responded before, getting extra sleep tonight could help.",
            severity: .warning,
            confidence: 0.87,
            priority: 0.92,
            accentColor: .orange
        ),
        IntelligenceCard(
            type: .regimeShift,
            icon: "chart.line.uptrend.xyaxis",
            label: Copy.Briefing.Labels.somethingChanged,
            headline: "Your deep sleep has been lower since last Tuesday, shifting by 45 min.",
            detail: "It went from 1h 30min to 45min. Your resting heart rate changed around the same time, which is probably connected.",
            severity: .notable,
            confidence: 0.74,
            priority: 0.78,
            accentColor: .purple
        ),
        IntelligenceCard(
            type: .hiddenDriver,
            icon: "link.circle.fill",
            label: Copy.Briefing.Labels.whyThisIsHappening,
            headline: "Your weekend activity pushes down your Monday recovery about 2 days later. This connection has been consistent in your data.",
            detail: "Even after accounting for other factors, this link holds up (strength: 0.64). Based on 90 days of data.",
            severity: .info,
            confidence: 0.81,
            priority: 0.65,
            accentColor: .blue
        ),
        IntelligenceCard(
            type: .autonomicBalance,
            icon: "waveform.path.ecg",
            label: Copy.Briefing.Labels.nervousSystem,
            headline: "Your nervous system has not fully recovered. Your HRV is 28 ms and resting heart rate is 72 bpm, which suggests your body is still under stress. Consider going easy today.",
            detail: "HRV: 28 ms, resting heart rate: 72 bpm.",
            severity: .critical,
            confidence: 0.93,
            priority: 0.95,
            accentColor: .red
        ),
        IntelligenceCard(
            type: .bodyClockStatus,
            icon: "clock.arrow.circlepath",
            label: Copy.Briefing.Labels.yourBodyClock,
            headline: "Your body is at its best for exercise between 4:00 PM and 7:00 PM.",
            detail: "Your ideal bedtime based on your patterns is around 10:30 PM. Your body tends to be most recovered around 6:00 AM.",
            severity: .info,
            confidence: 0.68,
            priority: 0.52,
            accentColor: .yellow
        )
    ]

    ScrollView {
        VStack(spacing: DS.sectionSpacing) {
            TodayBriefingView(cards: sampleCards)

            TodayBriefingView(cards: [])
        }
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Detail Sheet") {
    Color(.systemGroupedBackground)
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            // Reuse the first sample card's shape for visual review.
            TodayBriefingView(cards: [
                IntelligenceCard(
                    type: .predictiveRisk,
                    icon: "exclamationmark.triangle.fill",
                    label: Copy.Briefing.Labels.headsUp,
                    headline: "Your HRV has been dropping since Friday. The last time this happened, it was because you had less deep sleep for 3 nights in a row. You bounced back after 2 good nights.",
                    detail: "This is mainly because your resting heart rate has been off. Based on how your body has responded before, getting extra sleep tonight could help.",
                    severity: .warning,
                    confidence: 0.87,
                    priority: 0.92,
                    accentColor: .orange
                )
            ])
            .presentationDetents([.medium, .large])
        }
}

#Preview("Single Card") {
    TodayBriefingView(cards: [
        IntelligenceCard(
            type: .systemCoherence,
            icon: "circle.hexagonpath.fill",
            label: Copy.Briefing.Labels.everythingLooksGood,
            headline: "Your body's systems are working well together. 12 strong connections across 8 health measures.",
            detail: "12 connections across 8 tracked measures.",
            severity: .info,
            confidence: 0.91,
            priority: 0.70,
            accentColor: .green
        )
    ])
    .padding(.vertical)
    .background(Color(.systemGroupedBackground))
}

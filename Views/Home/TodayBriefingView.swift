import SwiftUI

// MARK: - Today Briefing View

/// Horizontal scroll strip of intelligence cards — non-obvious health findings
/// surfaced by the on-device ML engine. Each card is a compact, information-dense
/// tile showing a single predictive or analytical finding the user could not
/// derive from raw metrics alone.
struct TodayBriefingView: View {
    let cards: [IntelligenceCard]

    var body: some View {
        if !cards.isEmpty {
            briefingSection
        }
    }

    // MARK: - Section Layout

    @ViewBuilder
    private var briefingSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            sectionHeader
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(cards) { card in
                        BriefingCardView(card: card)
                    }
                }
                .padding(.leading)
                .padding(.trailing, 40)
            }
        }
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        HStack(spacing: 5) {
            Image(systemName: "brain.head.profile.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(Copy.Home.bodyIntelligence)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Individual Briefing Card

private struct BriefingCardView: View {
    let card: IntelligenceCard

    @State private var tapped = false

    private var accent: Color {
        card.accentColor.resolved
    }

    private var severityDotColor: Color {
        switch card.severity {
        case .critical: .red
        case .warning: .orange
        case .notable: .yellow
        case .info: .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Accent bar
            Rectangle()
                .fill(accent)
                .frame(height: 3)

            VStack(alignment: .leading, spacing: 8) {
                // Label
                Text(card.label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(accent)
                    .textCase(.uppercase)
                    .lineLimit(1)

                // Headline
                Text(card.headline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                // Detail
                Text(card.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Spacer(minLength: 0)

                // Bottom row: confidence pill + severity dot
                HStack(spacing: 6) {
                    Text("\(Int(card.confidence * 100))% conf")
                        .font(.system(.caption2, design: .monospaced))
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
        .onTapGesture {
            tapped.toggle()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(card.label): \(card.headline)")
        .accessibilityHint(card.detail)
    }
}

// MARK: - Accent Color Resolution

extension IntelligenceCard.AccentColor {
    var resolved: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .blue: .blue
        case .purple: .purple
        }
    }
}

// MARK: - Preview

#Preview("Body Intelligence Strip") {
    let sampleCards: [IntelligenceCard] = [
        IntelligenceCard(

            type: .predictiveRisk,
            icon: "exclamationmark.triangle.fill",
            label: "PREDICTIVE RISK",
            headline: "HRV trending 18% below your 14-day baseline",
            detail: "Correlates with elevated resting HR over the past 3 nights",
            severity: .warning,
            confidence: 0.87,
            priority: 0.92,
            accentColor: .orange
        ),
        IntelligenceCard(

            type: .regimeShift,
            icon: "arrow.triangle.swap",
            label: "REGIME SHIFT",
            headline: "Your sleep architecture shifted to a new pattern 5 days ago",
            detail: "Deep sleep ratio dropped from 22% to 15% — monitoring",
            severity: .notable,
            confidence: 0.74,
            priority: 0.78,
            accentColor: .purple
        ),
        IntelligenceCard(

            type: .hiddenDriver,
            icon: "eye.trianglebadge.exclamationmark.fill",
            label: "HIDDEN DRIVER",
            headline: "Weekend activity spikes are suppressing Monday recovery by ~12%",
            detail: "Granger causality detected with 2-day lag",
            severity: .info,
            confidence: 0.81,
            priority: 0.65,
            accentColor: .blue
        ),
        IntelligenceCard(

            type: .autonomicBalance,
            icon: "waveform.path.ecg",
            label: "AUTONOMIC BALANCE",
            headline: "Sympathetic dominance detected for 3 consecutive days",
            detail: "Consider active recovery or breathwork today",
            severity: .critical,
            confidence: 0.93,
            priority: 0.95,
            accentColor: .red
        ),
        IntelligenceCard(

            type: .bodyClockStatus,
            icon: "clock.arrow.2.circlepath",
            label: "BODY CLOCK",
            headline: "Circadian phase delayed by ~40 minutes vs your norm",
            detail: "Light exposure timing may be a factor",
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

#Preview("Single Card") {
    TodayBriefingView(cards: [
        IntelligenceCard(

            type: .systemCoherence,
            icon: "circle.hexagongrid.fill",
            label: "SYSTEM COHERENCE",
            headline: "All major biomarkers aligned within optimal range today",
            detail: "Highest coherence score in 30 days",
            severity: .info,
            confidence: 0.91,
            priority: 0.70,
            accentColor: .green
        )
    ])
    .padding(.vertical)
    .background(Color(.systemGroupedBackground))
}

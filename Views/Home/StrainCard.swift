import SwiftUI

// MARK: - Strain Card

/// Compact card for the Home tab showing today's strain score with HR zone breakdown.
/// Matches the accent-bar card style used by SleepCard, VitalityCard, PatternCard.
/// Uses `StrainLevel` from StrainScorer.swift as the source of truth.
struct StrainCard: View {
    let strainValue: Double
    let strainLevel: StrainLevel
    let zoneMinutes: [Int: Double]
    let onTap: () -> Void

    /// Max strain on the 0-21 scale
    private let maxStrain: Double = 21.0

    private var progress: Double {
        min(strainValue / maxStrain, 1.0)
    }

    @State private var animatedProgress: Double = 0

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Left accent bar
                RoundedRectangle(cornerRadius: DS.accentRadius)
                    .fill(strainLevel.color)
                    .frame(width: 4)
                    .padding(.vertical, 6)

                VStack(spacing: 10) {
                    // Main row: ring + text + chevron
                    HStack(spacing: 12) {
                        strainRing

                        // Center text
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Today's Strain")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            HStack(spacing: 8) {
                                Text(String(format: "%.1f", strainValue))
                                    .font(.title2.weight(.bold).monospacedDigit())
                                    .postHogMask()

                                Text(strainLevel.displayName)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(strainLevel.color)
                                    .padding(.horizontal, DS.badgeH)
                                    .padding(.vertical, DS.badgeV)
                                    .background(strainLevel.color.opacity(DS.badgeBg), in: Capsule())
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }

                    // HR zone mini bar chart
                    zoneBarChart
                }
                .padding(.leading, DS.accentLeading)
                .padding(.trailing, DS.accentTrailing)
                .padding(.vertical, DS.accentVertical)
            }
            .cardStyle(tint: strainLevel.color)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Today's strain \(String(format: "%.1f", strainValue)), \(strainLevel.displayName)")
        .accessibilityHint("View strain details")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("home.strainCard")
    }

    // MARK: - Strain Icon

    private var strainRing: some View {
        ZStack {
            // Gauge-style arc background
            Circle()
                .trim(from: 0.15, to: 0.85)
                .stroke(strainLevel.color.opacity(0.15), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: DS.iconSize + 12, height: DS.iconSize + 12)
                .rotationEffect(.degrees(90))

            // Filled arc showing progress
            Circle()
                .trim(from: 0.15, to: 0.15 + animatedProgress * 0.7)
                .stroke(strainLevel.color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: DS.iconSize + 12, height: DS.iconSize + 12)
                .rotationEffect(.degrees(90))
                .animation(.easeInOut(duration: 0.8), value: animatedProgress)

            Image(systemName: "flame.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(strainLevel.color)
                .offset(y: -1)
        }
        .onAppear { animatedProgress = progress }
        .onChange(of: strainValue) { animatedProgress = progress }
    }

    // MARK: - Zone Bar Chart

    private var zoneBarChart: some View {
        let maxMinutes = max((1...5).compactMap { zoneMinutes[$0] }.max() ?? 1, 1)

        return VStack(spacing: 4) {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(1...5, id: \.self) { zone in
                    let minutes = zoneMinutes[zone] ?? 0
                    let fraction = minutes / maxMinutes

                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(zoneColor(zone))
                            .frame(height: max(CGFloat(fraction) * 24, 2))

                        Text("\(Int(minutes))")
                            .font(.caption2.weight(.medium).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .postHogMask()
                    }
                }
            }
            .frame(height: 36)

            // Zone labels
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { zone in
                    Text("Z\(zone)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func zoneColor(_ zone: Int) -> Color {
        switch zone {
        case 1: return .blue
        case 2: return .green
        case 3: return .yellow
        case 4: return .orange
        case 5: return .red
        default: return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        StrainCard(
            strainValue: 14.2,
            strainLevel: .high,
            zoneMinutes: [1: 45, 2: 30, 3: 22, 4: 15, 5: 8],
            onTap: {}
        )

        StrainCard(
            strainValue: 6.3,
            strainLevel: .light,
            zoneMinutes: [1: 60, 2: 20, 3: 5, 4: 0, 5: 0],
            onTap: {}
        )

        StrainCard(
            strainValue: 19.5,
            strainLevel: .allOut,
            zoneMinutes: [1: 20, 2: 25, 3: 35, 4: 30, 5: 18],
            onTap: {}
        )
    }
    .padding(.horizontal)
    .background(Color(.systemGroupedBackground))
}

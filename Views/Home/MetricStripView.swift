import SwiftUI

// MARK: - Metric Tile Model

struct MetricTile: Identifiable {
    let id: String
    let icon: String
    let label: String
    let value: String
    let badge: String?
    let color: Color
    let route: Route
}

// MARK: - Metric Strip View

/// Horizontally scrollable strip of compact metric tiles replacing the 6 vertical cards.
/// Each tile is ~100pt wide, showing icon + value + label + optional badge.
/// Reduces ~700px of vertical scroll to ~120px.
struct MetricStripView: View {
    let tiles: [MetricTile]
    let onTap: (MetricTile) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(tiles) { tile in
                    MetricTileView(tile: tile) {
                        onTap(tile)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Individual Tile

private struct MetricTileView: View {
    let tile: MetricTile
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: tile.icon)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(tile.color, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(tile.value)
                    .font(.headline.weight(.bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .postHogMask()

                Text(tile.label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let badge = tile.badge {
                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(tile.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .postHogMask()
                } else {
                    // Placeholder to keep consistent height
                    Text(" ")
                        .font(.caption2)
                }
            }
            .frame(width: 96)
            .padding(.vertical, 10)
            .background(.background, in: RoundedRectangle(cornerRadius: DS.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DS.cardRadius)
                    .strokeBorder(tile.color.opacity(DS.strokeAlpha), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tile.label) \(tile.value)")
        .accessibilityHint("View \(tile.label) details")
    }
}

// MARK: - Preview

#Preview {
    MetricStripView(
        tiles: [
            MetricTile(id: "vitality", icon: "figure.run", label: "Vitality", value: "32", badge: "3y younger", color: .green, route: .vitalityDetail),
            MetricTile(id: "sleep", icon: "moon.fill", label: "Sleep", value: "7h 12m", badge: "Good", color: .indigo, route: .sleepCoach),
            MetricTile(id: "strain", icon: "flame.fill", label: "Strain", value: "14.2", badge: "High", color: .orange, route: .strainDetail),
            MetricTile(id: "brain", icon: "brain", label: "Brain", value: "85", badge: "Sharp", color: .green, route: .brainHealth),
            MetricTile(id: "stress", icon: "waveform.path.ecg", label: "Stress", value: "1.2", badge: "Mild", color: .yellow, route: .stressMonitor),
        ],
        onTap: { _ in }
    )
    .padding(.vertical)
    .background(Color(.systemGroupedBackground))
}

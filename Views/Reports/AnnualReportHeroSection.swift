import SwiftUI

struct AnnualReportHeroSection: View {
    let year: Int
    let overallScore: Int
    let vitalityAgeStart: Int?
    let vitalityAgeEnd: Int?
    let streakRecord: Int

    var body: some View {
        VStack(spacing: 16) {
            Text(Copy.Reports.yearInReview(year))
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1.2)

            HealthScoreRing(
                score: overallScore,
                label: Copy.Reports.annualScore,
                size: 160,
                lineWidth: 14
            )

            if let start = vitalityAgeStart, let end = vitalityAgeEnd {
                vitalityAgeRow(start: start, end: end)
            }

            if streakRecord > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.orange)
                    Text(Copy.Reports.streakDayRecord(streakRecord))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private func vitalityAgeRow(start: Int, end: Int) -> some View {
        let delta = start - end
        let improved = delta > 0

        return HStack(spacing: 16) {
            VStack(spacing: 2) {
                Text(Copy.Reports.jan)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("\(start)")
                    .font(.title3.weight(.bold).monospacedDigit())
            }

            Image(systemName: "arrow.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)

            VStack(spacing: 2) {
                Text(Copy.Reports.dec)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("\(end)")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(improved ? .green : (delta < 0 ? .red : .primary))
            }

            Spacer()

            if delta != 0 {
                Text(improved ? Copy.Reports.yearsYounger(delta) : Copy.Reports.yearsOlder(abs(delta)))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(improved ? .green : .red)
                    .padding(.horizontal, DS.badgeH + 4)
                    .padding(.vertical, DS.badgeV + 2)
                    .background((improved ? Color.green : Color.red).opacity(DS.badgeBg), in: Capsule())
            }
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }
}

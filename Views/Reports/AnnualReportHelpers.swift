import SwiftUI

enum AnnualReportHelpers {

    static func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.headline)
            Spacer()
        }
    }

    static func monthAbbreviation(_ month: Int) -> String {
        let formatter = DateFormatter()
        guard month >= 1, month <= 12 else { return "" }
        return formatter.shortMonthSymbols[month - 1]
    }

    static func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        guard month >= 1, month <= 12 else { return "" }
        return formatter.monthSymbols[month - 1]
    }

    static func formatHours(_ hours: Double) -> String {
        if hours >= 1000 { return "\(Int(hours / 100) * 100)h" }
        if hours >= 100 { return "\(Int(hours))h" }
        return String(format: "%.0fh", hours)
    }

    static func formatDistance(_ km: Double) -> String {
        if km >= 10_000 { return String(format: "%.0fk", km / 1000) }
        if km >= 1_000 { return String(format: "%.1fk", km / 1000) }
        return String(format: "%.0f", km)
    }

    static func formatSteps(_ steps: Int) -> String {
        if steps >= 10_000 { return String(format: "%.0fk", Double(steps) / 1000) }
        if steps >= 1_000 { return String(format: "%.1fk", Double(steps) / 1000) }
        return "\(steps)"
    }

    static func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 10_000 { return String(format: "%.0fk", Double(count) / 1000) }
        if count >= 1_000 { return String(format: "%.1fk", Double(count) / 1000) }
        return "\(count)"
    }

    static func opportunityMessage(for score: Int) -> String {
        switch score {
        case 80...100: return Copy.Reports.keepUpGreatWork
        case 60..<80: return Copy.Reports.smallImprovements
        case 40..<60: return Copy.Reports.significantRoom
        default: return Copy.Reports.priorityArea
        }
    }
}

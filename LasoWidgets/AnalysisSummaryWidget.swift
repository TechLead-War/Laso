import SwiftUI
import WidgetKit

struct AnalysisSummaryWidget: Widget {
    private let kind = "AnalysisSummaryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AnalysisWidgetProvider()) { entry in
            AnalysisWidgetView(entry: entry)
        }
        .configurationDisplayName("Last Analysis")
        .description("Shows your latest readiness, sleep, and insight summary.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryInline
        ])
    }
}

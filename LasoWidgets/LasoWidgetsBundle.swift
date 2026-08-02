import SwiftUI
import WidgetKit

@main
struct LasoWidgetsBundle: WidgetBundle {
    var body: some Widget {
        AnalysisSummaryWidget()
        MirrorStreakWidget()
        BreathworkLiveActivityWidget()
        TodayScoreLiveActivityWidget()
    }
}

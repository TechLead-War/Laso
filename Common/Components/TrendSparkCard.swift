import SwiftUI

struct TrendSparkPoint: Identifiable {
    let date: Date
    let value: Double

    var id: Date { date }
}

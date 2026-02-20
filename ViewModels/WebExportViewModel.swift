import Foundation
import Observation

/// ViewModel that orchestrates HTML report generation
@Observable
final class WebExportViewModel {
    let healthKitManager: HealthKitManager
    let analysisEngine: AnalysisEngine

    var isExporting = false
    var exportedURL: URL?
    var error: String?

    init(healthKitManager: HealthKitManager, analysisEngine: AnalysisEngine) {
        self.healthKitManager = healthKitManager
        self.analysisEngine = analysisEngine
    }

    /// Generate and save the HTML report
    func exportReport() {
        isExporting = true
        defer { isExporting = false }

        let html = HTMLReportGenerator.generate(
            overallScore: analysisEngine.overallScore,
            categoryScores: analysisEngine.categoryScores,
            insights: analysisEngine.insights,
            timeSeries: healthKitManager.timeSeries,
            baselines: analysisEngine.baselines
        )

        // Save to temp directory
        let fileName = "HealthPulse_Report_\(Date().shortDateString.replacingOccurrences(of: "/", with: "-")).html"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try html.write(to: fileURL, atomically: true, encoding: .utf8)
            exportedURL = fileURL
        } catch {
            self.error = "Failed to save report: \(error.localizedDescription)"
        }
    }
}

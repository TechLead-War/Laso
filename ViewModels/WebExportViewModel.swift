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
            // Apply complete file protection so the file is encrypted at rest
            try (fileURL as NSURL).setResourceValue(URLFileProtection.complete, forKey: .fileProtectionKey)
            exportedURL = fileURL

            AppAnalytics.shared.trackReportExported(
                score: analysisEngine.overallScore.score,
                metricsCount: healthKitManager.timeSeries.count,
                insightsCount: analysisEngine.insights.count
            )
        } catch {
            self.error = "Failed to save report: \(error.localizedDescription)"
        }
    }

    /// Clean up exported file after sharing is complete
    func cleanupExport() {
        guard let url = exportedURL else { return }
        try? FileManager.default.removeItem(at: url)
        exportedURL = nil
    }
}

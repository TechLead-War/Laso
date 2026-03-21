import Foundation
import SwiftData

/// Persisted ECG feature extraction results for longitudinal tracking
@Model
final class StoredECGFeatures {
    @Attribute(.unique) var ecgID: String
    var ecgDate: Date
    var classificationRawValue: Int
    var averageHeartRate: Double

    // R-R interval features
    var rrSDNN: Double       // Standard deviation of R-R intervals (ms)
    var rmssd: Double        // Root mean square of successive differences (ms)
    var pnn50: Double        // Percentage of successive intervals differing > 50ms

    // Waveform features (optional. may not be derivable from all recordings)
    var qrsWidth: Double?        // QRS complex width (ms)
    var qtcInterval: Double?     // Corrected QT interval (ms, Bazett)

    // Frequency domain (optional)
    var lfPower: Double?         // Low frequency power (sympathetic)
    var hfPower: Double?         // High frequency power (parasympathetic)
    var lfHfRatio: Double?       // LF/HF ratio (autonomic balance)

    // AFib tracking
    var isAFib: Bool

    // Raw features JSON for future analysis
    var featuresJSON: Data?

    init(
        ecgID: String,
        ecgDate: Date,
        classificationRawValue: Int,
        averageHeartRate: Double,
        rrSDNN: Double,
        rmssd: Double,
        pnn50: Double,
        qrsWidth: Double? = nil,
        qtcInterval: Double? = nil,
        lfPower: Double? = nil,
        hfPower: Double? = nil,
        lfHfRatio: Double? = nil,
        isAFib: Bool,
        featuresJSON: Data? = nil
    ) {
        self.ecgID = ecgID
        self.ecgDate = ecgDate
        self.classificationRawValue = classificationRawValue
        self.averageHeartRate = averageHeartRate
        self.rrSDNN = rrSDNN
        self.rmssd = rmssd
        self.pnn50 = pnn50
        self.qrsWidth = qrsWidth
        self.qtcInterval = qtcInterval
        self.lfPower = lfPower
        self.hfPower = hfPower
        self.lfHfRatio = lfHfRatio
        self.isAFib = isAFib
        self.featuresJSON = featuresJSON
    }
}

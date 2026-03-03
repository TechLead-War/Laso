import Foundation
import Accelerate

/// Signal processing and feature extraction from raw ECG voltage data.
/// Uses Accelerate framework for performant DSP operations.
struct ECGFeatureExtractor {

    struct ECGFeatures {
        // Time-domain R-R features
        let rrIntervals: [Double]    // R-R intervals in ms
        let meanRR: Double           // Mean R-R interval
        let sdnn: Double             // Standard deviation of R-R intervals
        let rmssd: Double            // Root mean square of successive differences
        let pnn50: Double            // % of successive intervals > 50ms apart

        // Waveform morphology
        let rPeakIndices: [Int]      // Indices of detected R-peaks
        let qrsWidth: Double?        // Estimated QRS complex width (ms)
        let qtInterval: Double?      // Q-T interval (ms)
        let qtcInterval: Double?     // Corrected QT (Bazett: QT/√RR in seconds)

        // Frequency domain (from R-R intervals)
        let lfPower: Double?         // Low frequency (0.04-0.15 Hz)
        let hfPower: Double?         // High frequency (0.15-0.40 Hz)
        let lfHfRatio: Double?       // Autonomic balance
    }

    // MARK: - Main Entry Point

    /// Extract features from raw ECG voltage data
    static func extract(voltages: [Double], samplingFrequency: Double) -> ECGFeatures? {
        guard voltages.count >= Int(samplingFrequency * 2) else { return nil }  // Need at least 2 seconds

        // Step 1: Bandpass filter (0.5-40 Hz)
        let filtered = bandpassFilter(signal: voltages, fs: samplingFrequency, lowCut: 0.5, highCut: 40.0)

        // Step 2: R-peak detection (Pan-Tompkins simplified)
        let rPeaks = detectRPeaks(signal: filtered, fs: samplingFrequency)
        guard rPeaks.count >= 3 else { return nil }

        // Step 3: R-R intervals
        let rrIntervals = computeRRIntervals(rPeaks: rPeaks, fs: samplingFrequency)
        guard rrIntervals.count >= 2 else { return nil }

        // Step 4: Time-domain HRV
        let meanRR = rrIntervals.reduce(0, +) / Double(rrIntervals.count)
        let sdnn = standardDeviation(rrIntervals)
        let rmssd = computeRMSSD(rrIntervals)
        let pnn50 = computePNN50(rrIntervals)

        // Step 5: QRS width estimation
        let qrsWidth = estimateQRSWidth(signal: filtered, rPeaks: rPeaks, fs: samplingFrequency)

        // Step 6: QT interval estimation
        let qtInterval = estimateQTInterval(signal: filtered, rPeaks: rPeaks, fs: samplingFrequency)
        let qtcInterval: Double?
        if let qt = qtInterval, meanRR > 0 {
            // Bazett correction: QTc = QT / √(RR in seconds)
            let rrSeconds = meanRR / 1000.0
            qtcInterval = qt / sqrt(rrSeconds)
        } else {
            qtcInterval = nil
        }

        // Step 7: Frequency domain (from R-R interpolated series)
        let (lfPower, hfPower) = computeFrequencyDomain(rrIntervals: rrIntervals)
        let lfHfRatio: Double?
        if let lf = lfPower, let hf = hfPower, hf > 0 {
            lfHfRatio = lf / hf
        } else {
            lfHfRatio = nil
        }

        return ECGFeatures(
            rrIntervals: rrIntervals,
            meanRR: meanRR,
            sdnn: sdnn,
            rmssd: rmssd,
            pnn50: pnn50,
            rPeakIndices: rPeaks,
            qrsWidth: qrsWidth,
            qtInterval: qtInterval,
            qtcInterval: qtcInterval,
            lfPower: lfPower,
            hfPower: hfPower,
            lfHfRatio: lfHfRatio
        )
    }

    // MARK: - Signal Processing

    /// Simple bandpass filter using FFT (zero-phase)
    private static func bandpassFilter(signal: [Double], fs: Double, lowCut: Double, highCut: Double) -> [Double] {
        let n = signal.count
        // Pad to next power of 2
        let fftSize = 1 << Int(ceil(log2(Double(n))))

        var paddedSignal = signal + Array(repeating: 0.0, count: fftSize - n)

        // Forward FFT
        guard let fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD) else {
            return signal
        }
        defer { vDSP_DFT_DestroySetup(fftSetup) }

        var realIn = paddedSignal
        var imagIn = [Double](repeating: 0.0, count: fftSize)
        var realOut = [Double](repeating: 0.0, count: fftSize)
        var imagOut = [Double](repeating: 0.0, count: fftSize)

        vDSP_DFT_ExecuteD(fftSetup, &realIn, &imagIn, &realOut, &imagOut)

        // Apply bandpass: zero out frequencies outside [lowCut, highCut]
        let freqResolution = fs / Double(fftSize)
        let lowBin = Int(lowCut / freqResolution)
        let highBin = min(Int(highCut / freqResolution), fftSize / 2)

        for i in 0..<fftSize {
            let bin = i <= fftSize / 2 ? i : fftSize - i
            if bin < lowBin || bin > highBin {
                realOut[i] = 0.0
                imagOut[i] = 0.0
            }
        }

        // Inverse FFT
        guard let ifftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .INVERSE) else {
            return signal
        }
        defer { vDSP_DFT_DestroySetup(ifftSetup) }

        var realResult = [Double](repeating: 0.0, count: fftSize)
        var imagResult = [Double](repeating: 0.0, count: fftSize)

        vDSP_DFT_ExecuteD(ifftSetup, &realOut, &imagOut, &realResult, &imagResult)

        // Normalize
        let scale = 1.0 / Double(fftSize)
        var normalized = [Double](repeating: 0.0, count: fftSize)
        vDSP_vsmulD(&realResult, 1, [scale], &normalized, 1, vDSP_Length(fftSize))

        return Array(normalized.prefix(n))
    }

    /// Simplified Pan-Tompkins R-peak detection
    private static func detectRPeaks(signal: [Double], fs: Double) -> [Int] {
        let n = signal.count
        guard n > 0 else { return [] }

        // Step 1: Differentiate
        var diff = [Double](repeating: 0.0, count: n)
        for i in 1..<n {
            diff[i] = signal[i] - signal[i - 1]
        }

        // Step 2: Square
        var squared = [Double](repeating: 0.0, count: n)
        vDSP_vsqD(diff, 1, &squared, 1, vDSP_Length(n))

        // Step 3: Moving average (window = 150ms)
        let windowSize = max(1, Int(0.15 * fs))
        var integrated = [Double](repeating: 0.0, count: n)
        var runningSum = 0.0
        for i in 0..<n {
            runningSum += squared[i]
            if i >= windowSize {
                runningSum -= squared[i - windowSize]
            }
            integrated[i] = runningSum / Double(min(i + 1, windowSize))
        }

        // Step 4: Adaptive threshold
        var maxVal = 0.0
        vDSP_maxvD(integrated, 1, &maxVal, vDSP_Length(n))
        var threshold = maxVal * 0.3

        // Step 5: Find peaks above threshold with minimum R-R distance (200ms)
        let minDistance = Int(0.2 * fs)
        var peaks: [Int] = []

        var i = 0
        while i < n {
            if integrated[i] > threshold {
                // Find local maximum in this region
                var peakIdx = i
                var peakVal = integrated[i]
                let regionEnd = min(i + minDistance, n)
                for j in i..<regionEnd {
                    if integrated[j] > peakVal {
                        peakVal = integrated[j]
                        peakIdx = j
                    }
                }
                peaks.append(peakIdx)
                i = peakIdx + minDistance
                // Adapt threshold
                threshold = 0.3 * peakVal + 0.7 * threshold
            } else {
                i += 1
            }
        }

        return peaks
    }

    // MARK: - R-R Interval Analysis

    private static func computeRRIntervals(rPeaks: [Int], fs: Double) -> [Double] {
        guard rPeaks.count >= 2 else { return [] }
        var intervals: [Double] = []
        for i in 1..<rPeaks.count {
            let rr = Double(rPeaks[i] - rPeaks[i - 1]) / fs * 1000.0  // ms
            // Filter physiologically plausible R-R intervals (300-2000 ms = 30-200 bpm)
            if rr >= 300 && rr <= 2000 {
                intervals.append(rr)
            }
        }
        return intervals
    }

    private static func standardDeviation(_ values: [Double]) -> Double {
        let n = Double(values.count)
        guard n > 1 else { return 0 }
        let mean = values.reduce(0, +) / n
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / (n - 1)
        return sqrt(variance)
    }

    private static func computeRMSSD(_ rrIntervals: [Double]) -> Double {
        guard rrIntervals.count >= 2 else { return 0 }
        var sumSquaredDiff = 0.0
        for i in 1..<rrIntervals.count {
            let diff = rrIntervals[i] - rrIntervals[i - 1]
            sumSquaredDiff += diff * diff
        }
        return sqrt(sumSquaredDiff / Double(rrIntervals.count - 1))
    }

    private static func computePNN50(_ rrIntervals: [Double]) -> Double {
        guard rrIntervals.count >= 2 else { return 0 }
        var count = 0
        for i in 1..<rrIntervals.count {
            if abs(rrIntervals[i] - rrIntervals[i - 1]) > 50.0 {
                count += 1
            }
        }
        return Double(count) / Double(rrIntervals.count - 1) * 100.0
    }

    // MARK: - QRS & QT Estimation

    /// Estimate QRS complex width from R-peak neighborhoods
    private static func estimateQRSWidth(signal: [Double], rPeaks: [Int], fs: Double) -> Double? {
        guard rPeaks.count >= 3 else { return nil }
        let searchWindow = Int(0.06 * fs)  // ±60ms around R-peak

        var widths: [Double] = []
        for peak in rPeaks {
            let start = max(0, peak - searchWindow)
            let end = min(signal.count - 1, peak + searchWindow)
            guard start < end else { continue }

            let peakVal = signal[peak]
            let halfPeak = abs(peakVal) * 0.5

            // Find half-maximum crossings
            var leftCrossing: Int?
            var rightCrossing: Int?

            for i in stride(from: peak, through: start, by: -1) {
                if abs(signal[i]) < halfPeak {
                    leftCrossing = i
                    break
                }
            }
            for i in peak...end {
                if abs(signal[i]) < halfPeak {
                    rightCrossing = i
                    break
                }
            }

            if let left = leftCrossing, let right = rightCrossing {
                let widthMs = Double(right - left) / fs * 1000.0
                if widthMs >= 40 && widthMs <= 200 {  // Physiologically plausible
                    widths.append(widthMs)
                }
            }
        }

        guard !widths.isEmpty else { return nil }
        return widths.reduce(0, +) / Double(widths.count)
    }

    /// Estimate QT interval (R-peak onset to T-wave end)
    private static func estimateQTInterval(signal: [Double], rPeaks: [Int], fs: Double) -> Double? {
        guard rPeaks.count >= 3 else { return nil }
        // Simplified: search for T-wave end approximately 300-500ms after R-peak
        let searchStart = Int(0.25 * fs)
        let searchEnd = Int(0.55 * fs)

        var qtIntervals: [Double] = []
        for peak in rPeaks {
            let windowStart = peak + searchStart
            let windowEnd = min(peak + searchEnd, signal.count - 1)
            guard windowStart < windowEnd else { continue }

            // Find where signal returns to baseline (near zero crossing after T-wave)
            var tWaveEnd: Int?
            let segment = Array(signal[windowStart...windowEnd])

            // Look for the point where derivative crosses zero going down (T-wave end)
            for i in 1..<segment.count {
                if segment[i - 1] > 0 && segment[i] <= 0 {
                    tWaveEnd = windowStart + i
                    break
                }
            }

            // Fallback: find minimum absolute value in the latter half
            if tWaveEnd == nil {
                let latterHalf = segment.suffix(segment.count / 2)
                if let minIdx = latterHalf.indices.min(by: { abs(segment[$0]) < abs(segment[$1]) }) {
                    tWaveEnd = windowStart + minIdx
                }
            }

            if let end = tWaveEnd {
                let qt = Double(end - peak) / fs * 1000.0
                if qt >= 300 && qt <= 600 {  // Physiologically plausible
                    qtIntervals.append(qt)
                }
            }
        }

        guard !qtIntervals.isEmpty else { return nil }
        return qtIntervals.reduce(0, +) / Double(qtIntervals.count)
    }

    // MARK: - Frequency Domain

    /// Compute LF and HF power from R-R interval series using FFT
    private static func computeFrequencyDomain(rrIntervals: [Double]) -> (lf: Double?, hf: Double?) {
        guard rrIntervals.count >= 32 else { return (nil, nil) }

        // Resample R-R intervals to uniform 4 Hz
        let resampledRate = 4.0
        let totalTimeMs = rrIntervals.reduce(0, +)
        let nResampled = Int(totalTimeMs / 1000.0 * resampledRate)
        guard nResampled >= 32 else { return (nil, nil) }

        // Linear interpolation to uniform grid
        var cumTime = 0.0
        var rrTimes: [Double] = [0]
        for rr in rrIntervals {
            cumTime += rr
            rrTimes.append(cumTime)
        }

        var resampled = [Double](repeating: 0.0, count: nResampled)
        for i in 0..<nResampled {
            let t = Double(i) / resampledRate * 1000.0  // time in ms
            // Find bracketing R-R values
            var j = 0
            while j < rrTimes.count - 1 && rrTimes[j + 1] < t { j += 1 }
            if j < rrIntervals.count {
                resampled[i] = rrIntervals[j]
            }
        }

        // Remove mean
        let mean = resampled.reduce(0, +) / Double(nResampled)
        for i in 0..<nResampled { resampled[i] -= mean }

        // FFT
        let fftSize = 1 << Int(ceil(log2(Double(nResampled))))
        var padded = resampled + Array(repeating: 0.0, count: fftSize - nResampled)

        guard let fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD) else {
            return (nil, nil)
        }
        defer { vDSP_DFT_DestroySetup(fftSetup) }

        var imagIn = [Double](repeating: 0.0, count: fftSize)
        var realOut = [Double](repeating: 0.0, count: fftSize)
        var imagOut = [Double](repeating: 0.0, count: fftSize)

        vDSP_DFT_ExecuteD(fftSetup, &padded, &imagIn, &realOut, &imagOut)

        // Compute power spectrum
        let freqRes = resampledRate / Double(fftSize)
        var lfPower = 0.0
        var hfPower = 0.0

        for i in 0..<(fftSize / 2) {
            let freq = Double(i) * freqRes
            let power = (realOut[i] * realOut[i] + imagOut[i] * imagOut[i]) / Double(fftSize * fftSize)

            if freq >= 0.04 && freq < 0.15 {
                lfPower += power
            } else if freq >= 0.15 && freq <= 0.40 {
                hfPower += power
            }
        }

        return (lfPower > 0 ? lfPower : nil, hfPower > 0 ? hfPower : nil)
    }
}

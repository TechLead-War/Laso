import Foundation
import Accelerate

/// High-performance vectorized operations using Apple's Accelerate framework (vDSP + BLAS)
enum AccelerateML {

    // MARK: - Normalization

    /// Z-score normalize an array: (x - mean) / stdDev. Returns normalized values plus (mean, stdDev).
    static func zScoreNormalize(_ values: [Double]) -> (normalized: [Double], mean: Double, stdDev: Double) {
        guard values.count > 1 else {
            return (values, values.first ?? 0, 0)
        }

        var mean: Double = 0
        var stdDev: Double = 0
        var result = [Double](repeating: 0, count: values.count)

        // vDSP_normalizeD computes (x - mean) / stdDev in one pass
        vDSP_normalizeD(values, 1, &result, 1, &mean, &stdDev, vDSP_Length(values.count))

        // vDSP returns 0 stdDev if all values are the same
        if stdDev == 0 {
            return (Array(repeating: 0, count: values.count), mean, 0)
        }

        return (result, mean, stdDev)
    }

    // MARK: - Basic Vector Operations

    /// Dot product of two vectors
    static func dotProduct(_ a: [Double], _ b: [Double]) -> Double {
        let n = Swift.min(a.count, b.count)
        guard n > 0 else { return 0 }
        var result: Double = 0
        vDSP_dotprD(a, 1, b, 1, &result, vDSP_Length(n))
        return result
    }

    /// Element-wise multiply: result[i] = a[i] * b[i]
    static func multiply(_ a: [Double], _ b: [Double]) -> [Double] {
        let n = Swift.min(a.count, b.count)
        var result = [Double](repeating: 0, count: n)
        vDSP_vmulD(a, 1, b, 1, &result, 1, vDSP_Length(n))
        return result
    }

    /// Element-wise subtract: result[i] = a[i] - b[i]
    static func subtract(_ a: [Double], _ b: [Double]) -> [Double] {
        let n = Swift.min(a.count, b.count)
        var result = [Double](repeating: 0, count: n)
        // vDSP_vsubD computes B - A, so swap order
        vDSP_vsubD(b, 1, a, 1, &result, 1, vDSP_Length(n))
        return result
    }

    /// Sum of all elements
    static func sum(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        var result: Double = 0
        vDSP_sveD(values, 1, &result, vDSP_Length(values.count))
        return result
    }

    /// Sum of squares of all elements
    static func sumOfSquares(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        var result: Double = 0
        vDSP_svesqD(values, 1, &result, vDSP_Length(values.count))
        return result
    }

    /// Mean of values
    static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        var result: Double = 0
        vDSP_meanvD(values, 1, &result, vDSP_Length(values.count))
        return result
    }

    /// Scalar multiply: result[i] = a[i] * scalar
    static func scalarMultiply(_ a: [Double], _ scalar: Double) -> [Double] {
        var s = scalar
        var result = [Double](repeating: 0, count: a.count)
        vDSP_vsmulD(a, 1, &s, &result, 1, vDSP_Length(a.count))
        return result
    }

    /// Scalar add: result[i] = a[i] + scalar
    static func scalarAdd(_ a: [Double], _ scalar: Double) -> [Double] {
        var s = scalar
        var result = [Double](repeating: 0, count: a.count)
        vDSP_vsaddD(a, 1, &s, &result, 1, vDSP_Length(a.count))
        return result
    }

    // MARK: - FFT

    /// Compute magnitude spectrum via real-to-complex FFT with Hanning window.
    /// Returns magnitudes for frequencies 0..N/2 (N/2+1 values).
    static func fftMagnitude(_ signal: [Double]) -> [Double] {
        let n = signal.count
        guard n >= 4 else { return [] }

        // Round down to nearest power of 2
        let log2n = vDSP_Length(floor(log2(Double(n))))
        let fftLength = Int(1 << log2n)
        guard fftLength >= 4 else { return [] }

        // Apply Hanning window
        var windowed = [Double](repeating: 0, count: fftLength)
        var window = [Double](repeating: 0, count: fftLength)
        vDSP_hann_windowD(&window, vDSP_Length(fftLength), Int32(vDSP_HANN_NORM))
        vDSP_vmulD(Array(signal.prefix(fftLength)), 1, window, 1, &windowed, 1, vDSP_Length(fftLength))

        // Setup FFT
        guard let fftSetup = vDSP_create_fftsetupD(log2n, FFTRadix(kFFTRadix2)) else { return [] }
        defer { vDSP_destroy_fftsetupD(fftSetup) }

        // Pack into split complex
        let halfN = fftLength / 2
        var realPart = [Double](repeating: 0, count: halfN)
        var imagPart = [Double](repeating: 0, count: halfN)

        // Convert real signal to split complex (even/odd interleave)
        realPart.withUnsafeMutableBufferPointer { realBuf in
            imagPart.withUnsafeMutableBufferPointer { imagBuf in
                var splitComplex = DSPDoubleSplitComplex(
                    realp: realBuf.baseAddress!,
                    imagp: imagBuf.baseAddress!
                )
                windowed.withUnsafeBufferPointer { buf in
                    let dspBuf = UnsafeRawPointer(buf.baseAddress!).bindMemory(
                        to: DSPDoubleComplex.self, capacity: halfN
                    )
                    vDSP_ctozD(dspBuf, 2, &splitComplex, 1, vDSP_Length(halfN))
                }
            }
        }

        // Perform FFT + compute magnitudes
        var magnitudes = [Double](repeating: 0, count: halfN)
        realPart.withUnsafeMutableBufferPointer { realBuf in
            imagPart.withUnsafeMutableBufferPointer { imagBuf in
                var splitComplex = DSPDoubleSplitComplex(
                    realp: realBuf.baseAddress!,
                    imagp: imagBuf.baseAddress!
                )
                vDSP_fft_zripD(fftSetup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))
                vDSP_zvmagsD(&splitComplex, 1, &magnitudes, 1, vDSP_Length(halfN))
            }
        }

        // Scale and sqrt for magnitude spectrum
        var scale = 1.0 / Double(fftLength)
        var scaled = [Double](repeating: 0, count: halfN)
        vDSP_vsmulD(magnitudes, 1, &scale, &scaled, 1, vDSP_Length(halfN))

        var sqrtResult = [Double](repeating: 0, count: halfN)
        vForce.sqrt(scaled, result: &sqrtResult)

        return sqrtResult
    }

    // MARK: - Sigmoid

    /// Sigmoid function: 1 / (1 + exp(-x)) applied element-wise
    static func sigmoid(_ values: [Double]) -> [Double] {
        let n = values.count
        guard n > 0 else { return [] }

        // Negate
        var negated = [Double](repeating: 0, count: n)
        var minusOne = -1.0
        vDSP_vsmulD(values, 1, &minusOne, &negated, 1, vDSP_Length(n))

        // Exp
        var expResult = [Double](repeating: 0, count: n)
        vForce.exp(negated, result: &expResult)

        // Add 1
        var onePlusExp = [Double](repeating: 0, count: n)
        var one = 1.0
        vDSP_vsaddD(expResult, 1, &one, &onePlusExp, 1, vDSP_Length(n))

        // Reciprocal: 1 / (1 + exp(-x))
        var result = [Double](repeating: 0, count: n)
        vForce.reciprocal(onePlusExp, result: &result)

        return result
    }

    /// Single value sigmoid
    static func sigmoid(_ x: Double) -> Double {
        1.0 / (1.0 + exp(-x))
    }

    // MARK: - Matrix-Vector Multiply

    /// Matrix-vector multiply: result = A * x, where A is (rows x cols) stored row-major
    static func matVecMultiply(matrix: [Double], vector: [Double], rows: Int, cols: Int) -> [Double] {
        guard matrix.count >= rows * cols, vector.count >= cols else { return [] }
        var result = [Double](repeating: 0, count: rows)
        // Manual row-major matrix-vector multiply using vDSP
        for r in 0..<rows {
            let rowStart = r * cols
            let row = Array(matrix[rowStart..<(rowStart + cols)])
            var dot: Double = 0
            vDSP_dotprD(row, 1, vector, 1, &dot, vDSP_Length(cols))
            result[r] = dot
        }
        return result
    }

    // MARK: - Distance & Similarity

    /// Euclidean distance between two vectors
    static func euclideanDistance(_ a: [Double], _ b: [Double]) -> Double {
        let diff = subtract(a, b)
        return sumOfSquares(diff).squareRoot()
    }

    /// Squared Euclidean distance (avoids sqrt for clustering)
    static func squaredDistance(_ a: [Double], _ b: [Double]) -> Double {
        let diff = subtract(a, b)
        return sumOfSquares(diff)
    }

    // MARK: - Statistical Helpers

    /// Compute variance using Welford's online algorithm (numerically stable)
    static func welfordVariance(_ values: [Double]) -> (mean: Double, variance: Double) {
        guard !values.isEmpty else { return (0, 0) }
        var mean: Double = 0
        var m2: Double = 0

        for (n, x) in values.enumerated() {
            let delta = x - mean
            mean += delta / Double(n + 1)
            let delta2 = x - mean
            m2 += delta * delta2
        }

        let variance = values.count > 1 ? m2 / Double(values.count) : 0
        return (mean, variance)
    }

    /// Autocorrelation at a specific lag
    static func autocorrelation(_ values: [Double], lag: Int) -> Double {
        let n = values.count
        guard lag > 0, lag < n else { return 0 }

        let meanVal = mean(values)
        var numerator: Double = 0
        var denominator: Double = 0

        for i in 0..<n {
            let diff = values[i] - meanVal
            denominator += diff * diff
            if i + lag < n {
                numerator += diff * (values[i + lag] - meanVal)
            }
        }

        guard denominator > 0 else { return 0 }
        return numerator / denominator
    }
}

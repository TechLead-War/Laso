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

        // In-place processing to avoid multiple memory allocations
        var result = [Double](repeating: 0, count: n)
        var minusOne = -1.0
        
        // 1. Negate: result = -x
        vDSP_vsmulD(values, 1, &minusOne, &result, 1, vDSP_Length(n))
        // 2. Exp: result = exp(-x)
        vForce.exp(result, result: &result)
        // 3. Add 1: result = 1 + exp(-x)
        var one = 1.0
        vDSP_vsaddD(result, 1, &one, &result, 1, vDSP_Length(n))
        // 4. Reciprocal: result = 1 / (1 + exp(-x))
        vForce.reciprocal(result, result: &result)

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

    // MARK: - Matrix Multiply (BLAS)

    /// Matrix multiplication using vDSP: C = A * B
    /// A is (rows x cols), B is (cols x n), result C is (rows x n). All row-major.
    static func matrixMultiply(A: [Double], B: [Double], rows: Int, cols: Int, n: Int) -> [Double] {
        guard A.count >= rows * cols, B.count >= cols * n else { return [] }
        var C = [Double](repeating: 0, count: rows * n)
        vDSP_mmulD(A, 1, B, 1, &C, 1, vDSP_Length(rows), vDSP_Length(n), vDSP_Length(cols))
        return C
    }

    // MARK: - Softmax

    /// Numerically stable softmax: exp(x - max(x)) / sum(exp(x - max(x)))
    static func softmax(_ values: [Double]) -> [Double] {
        let n = values.count
        guard n > 0 else { return [] }

        // Find max for numerical stability
        var maxVal: Double = 0
        vDSP_maxvD(values, 1, &maxVal, vDSP_Length(n))

        // In-place processing
        var result = [Double](repeating: 0, count: n)
        var negMax = -maxVal
        
        // 1. Subtract max: result = x - max
        vDSP_vsaddD(values, 1, &negMax, &result, 1, vDSP_Length(n))
        // 2. Exp: result = exp(x - max)
        vForce.exp(result, result: &result)

        // 3. Sum
        var total: Double = 0
        vDSP_sveD(result, 1, &total, vDSP_Length(n))

        // 4. Normalize in-place
        guard total > 0 else { return [Double](repeating: 1.0 / Double(n), count: n) }
        var invTotal = 1.0 / total
        vDSP_vsmulD(result, 1, &invTotal, &result, 1, vDSP_Length(n))

        return result
    }

    // MARK: - Log-Sum-Exp

    /// Numerically stable log-sum-exp: log(sum(exp(x))) = max(x) + log(sum(exp(x - max(x))))
    static func logSumExp(_ values: [Double]) -> Double {
        let n = values.count
        guard n > 0 else { return -.infinity }

        var maxVal: Double = 0
        vDSP_maxvD(values, 1, &maxVal, vDSP_Length(n))

        var negMax = -maxVal
        var workBuffer = [Double](repeating: 0, count: n)
        
        // 1. Subtract max
        vDSP_vsaddD(values, 1, &negMax, &workBuffer, 1, vDSP_Length(n))
        // 2. Exp in-place
        vForce.exp(workBuffer, result: &workBuffer)

        var total: Double = 0
        vDSP_sveD(workBuffer, 1, &total, vDSP_Length(n))

        return maxVal + log(total)
    }

    // MARK: - Cumulative Sum

    /// Cumulative sum using vDSP_vrsumD
    static func cumulativeSum(_ values: [Double]) -> [Double] {
        let n = values.count
        guard n > 0 else { return [] }
        var result = [Double](repeating: 0, count: n)
        var one = 1.0
        // vDSP_vrsumD computes running sum; input is multiplied by scalar
        vDSP_vrsumD(values, 1, &one, &result, 1, vDSP_Length(n))
        return result
    }

    // MARK: - Argmax / Argmin

    /// Index of maximum value via vDSP_maxviD
    static func argmax(_ values: [Double]) -> Int {
        guard !values.isEmpty else { return 0 }
        var maxVal: Double = 0
        var maxIdx: vDSP_Length = 0
        vDSP_maxviD(values, 1, &maxVal, &maxIdx, vDSP_Length(values.count))
        return Int(maxIdx)
    }

    /// Index of minimum value via vDSP_minviD
    static func argmin(_ values: [Double]) -> Int {
        guard !values.isEmpty else { return 0 }
        var minVal: Double = 0
        var minIdx: vDSP_Length = 0
        vDSP_minviD(values, 1, &minVal, &minIdx, vDSP_Length(values.count))
        return Int(minIdx)
    }

    // MARK: - Multivariate Normal (Diagonal Covariance)

    /// Log-likelihood of x under a multivariate normal with diagonal covariance.
    /// diagVariance contains the diagonal elements of the covariance matrix.
    /// Formula: -0.5 * [d*ln(2pi) + sum(ln(var_i)) + sum((x_i - mu_i)^2 / var_i)]
    static func diagonalMVNLogLikelihood(x: [Double], mean: [Double], diagVariance: [Double]) -> Double {
        let d = x.count
        guard d == mean.count, d == diagVariance.count, d > 0 else { return -.infinity }

        // (x - mean)
        var diff = [Double](repeating: 0, count: d)
        vDSP_vsubD(mean, 1, x, 1, &diff, 1, vDSP_Length(d))

        // diff^2
        var diffSquared = [Double](repeating: 0, count: d)
        vDSP_vsqD(diff, 1, &diffSquared, 1, vDSP_Length(d))

        // diff^2 / variance
        var scaledDiff = [Double](repeating: 0, count: d)
        vDSP_vdivD(diagVariance, 1, diffSquared, 1, &scaledDiff, 1, vDSP_Length(d))

        // sum(diff^2 / variance)
        var mahalanobis: Double = 0
        vDSP_sveD(scaledDiff, 1, &mahalanobis, vDSP_Length(d))

        // log(variance) for each dimension
        var logVar = [Double](repeating: 0, count: d)
        vForce.log(diagVariance, result: &logVar)

        // sum(log(variance))
        var logDetSum: Double = 0
        vDSP_sveD(logVar, 1, &logDetSum, vDSP_Length(d))

        let logLikelihood = -0.5 * (Double(d) * log(2.0 * .pi) + logDetSum + mahalanobis)
        return logLikelihood
    }

    // MARK: - Weighted Mean

    /// Weighted mean: sum(values * weights) / sum(weights)
    static func weightedMean(_ values: [Double], weights: [Double]) -> Double {
        let n = Swift.min(values.count, weights.count)
        guard n > 0 else { return 0 }

        var dotResult: Double = 0
        vDSP_dotprD(values, 1, weights, 1, &dotResult, vDSP_Length(n))

        var weightSum: Double = 0
        vDSP_sveD(weights, 1, &weightSum, vDSP_Length(n))

        guard weightSum > 0 else { return 0 }
        return dotResult / weightSum
    }

    // MARK: - Outer Product

    /// Outer product: result[i*b.count + j] = a[i] * b[j]. Returns flat row-major matrix.
    static func outerProduct(_ a: [Double], _ b: [Double]) -> [Double] {
        let m = a.count
        let n = b.count
        guard m > 0, n > 0 else { return [] }

        // result[i*n + j] = a[i] * b[j]
        var result = [Double](repeating: 0, count: m * n)
        result.withUnsafeMutableBufferPointer { buf in
            for i in 0..<m {
                var scalar = a[i]
                vDSP_vsmulD(b, 1, &scalar, buf.baseAddress! + i * n, 1, vDSP_Length(n))
            }
        }
        return result
    }

    // MARK: - Linear System Solver (LAPACK)

    /// Solve Ax = b for x using Gaussian elimination with partial pivoting.
    /// A is n x n (row-major), b is length n. Returns x, or nil if singular.
    static func solveLinearSystem(A: [Double], b: [Double], n: Int) -> [Double]? {
        guard A.count >= n * n, b.count >= n, n > 0 else { return nil }

        // Augmented matrix [A|b] — work in-place
        var aug = [Double](repeating: 0, count: n * (n + 1))
        for i in 0..<n {
            for j in 0..<n {
                aug[i * (n + 1) + j] = A[i * n + j]
            }
            aug[i * (n + 1) + n] = b[i]
        }

        // Forward elimination with partial pivoting
        for col in 0..<n {
            // Find pivot
            var maxVal = abs(aug[col * (n + 1) + col])
            var maxRow = col
            for row in (col + 1)..<n {
                let val = abs(aug[row * (n + 1) + col])
                if val > maxVal { maxVal = val; maxRow = row }
            }
            guard maxVal > 1e-12 else { return nil } // Singular

            // Swap rows
            if maxRow != col {
                for j in col...(n) {
                    let tmp = aug[col * (n + 1) + j]
                    aug[col * (n + 1) + j] = aug[maxRow * (n + 1) + j]
                    aug[maxRow * (n + 1) + j] = tmp
                }
            }

            // Eliminate below
            let pivot = aug[col * (n + 1) + col]
            for row in (col + 1)..<n {
                let factor = aug[row * (n + 1) + col] / pivot
                for j in col...(n) {
                    aug[row * (n + 1) + j] -= factor * aug[col * (n + 1) + j]
                }
            }
        }

        // Back substitution
        var x = [Double](repeating: 0, count: n)
        for i in stride(from: n - 1, through: 0, by: -1) {
            var sum = aug[i * (n + 1) + n]
            for j in (i + 1)..<n {
                sum -= aug[i * (n + 1) + j] * x[j]
            }
            x[i] = sum / aug[i * (n + 1) + i]
        }
        return x
    }

    // MARK: - Pearson Correlation

    /// Pearson correlation coefficient between x and y using vDSP.
    static func pearsonCorrelation(_ x: [Double], _ y: [Double]) -> Double {
        let n = Swift.min(x.count, y.count)
        guard n > 1 else { return 0 }

        // Means
        var meanX: Double = 0
        var meanY: Double = 0
        vDSP_meanvD(x, 1, &meanX, vDSP_Length(n))
        vDSP_meanvD(y, 1, &meanY, vDSP_Length(n))

        // Center: xc = x - meanX, yc = y - meanY
        var negMeanX = -meanX
        var negMeanY = -meanY
        var xc = [Double](repeating: 0, count: n)
        var yc = [Double](repeating: 0, count: n)
        vDSP_vsaddD(x, 1, &negMeanX, &xc, 1, vDSP_Length(n))
        vDSP_vsaddD(y, 1, &negMeanY, &yc, 1, vDSP_Length(n))

        // Dot product of centered vectors
        var numerator: Double = 0
        vDSP_dotprD(xc, 1, yc, 1, &numerator, vDSP_Length(n))

        // Sum of squares
        var ssX: Double = 0
        var ssY: Double = 0
        vDSP_svesqD(xc, 1, &ssX, vDSP_Length(n))
        vDSP_svesqD(yc, 1, &ssY, vDSP_Length(n))

        let denominator = (ssX * ssY).squareRoot()
        guard denominator > 0 else { return 0 }

        return numerator / denominator
    }
}

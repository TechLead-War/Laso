import Foundation
import Accelerate

/// High-performance vectorized operations using Apple's Accelerate framework (vDSP + BLAS)
enum AccelerateML {

    // MARK: - Basic Vector Operations

    /// Dot product of two vectors
    static func dotProduct(_ a: [Double], _ b: [Double]) -> Double {
        let n = Swift.min(a.count, b.count)
        guard n > 0 else { return 0 }
        var result: Double = 0
        vDSP_dotprD(a, 1, b, 1, &result, vDSP_Length(n))
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

    /// Single value sigmoid
    static func sigmoid(_ x: Double) -> Double {
        1.0 / (1.0 + exp(-x))
    }

    // MARK: - Distance & Similarity

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

    // MARK: - Argmax

    /// Index of maximum value via vDSP_maxviD
    static func argmax(_ values: [Double]) -> Int {
        guard !values.isEmpty else { return 0 }
        var maxVal: Double = 0
        var maxIdx: vDSP_Length = 0
        vDSP_maxviD(values, 1, &maxVal, &maxIdx, vDSP_Length(values.count))
        return Int(maxIdx)
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

    // MARK: - Linear System Solver (LAPACK)

    /// Solve Ax = b for x using LAPACK's LU factorization with partial pivoting
    /// (dgesv) — Apple's blocked, SIMD-vectorized solver. A is n x n (row-major),
    /// b is length n. Returns x, or nil if singular.
    static func solveLinearSystem(A: [Double], b: [Double], n: Int) -> [Double]? {
        guard A.count >= n * n, b.count >= n, n > 0 else { return nil }

        // LAPACK is column-major; transpose the row-major A into column-major.
        // n is tiny here (<= ~15), so the copy is negligible.
        var a = [Double](repeating: 0, count: n * n)
        for i in 0..<n {
            for j in 0..<n { a[j * n + i] = A[i * n + j] }
        }
        var rhs = Array(b[0..<n])                 // dgesv overwrites this with the solution
        var nDim = __CLPK_integer(n)
        var nrhs = __CLPK_integer(1)
        var lda = nDim
        var ldb = nDim
        var ipiv = [__CLPK_integer](repeating: 0, count: n)
        var info = __CLPK_integer(0)

        dgesv_(&nDim, &nrhs, &a, &lda, &ipiv, &rhs, &ldb, &info)

        guard info == 0 else { return nil }       // info != 0 => singular / bad arg
        return rhs
    }

    /// Solve Ax = b where A is symmetric positive definite, via Cholesky (dposv) —
    /// the fastest, most stable solver for normal equations (X'X). A is n x n
    /// (symmetric, so layout-agnostic), b is length n. Returns nil if A is not
    /// positive definite (caller should fall back to a general solver).
    static func solveSPD(A: [Double], b: [Double], n: Int) -> [Double]? {
        guard A.count >= n * n, b.count >= n, n > 0 else { return nil }
        var a = Array(A[0..<n * n])               // symmetric: row-major == column-major
        var rhs = Array(b[0..<n])                 // overwritten with the solution
        var uplo = Int8(UInt8(ascii: "U"))
        var nDim = __CLPK_integer(n)
        var nrhs = __CLPK_integer(1)
        var lda = nDim
        var ldb = nDim
        var info = __CLPK_integer(0)

        dposv_(&uplo, &nDim, &nrhs, &a, &lda, &rhs, &ldb, &info)

        guard info == 0 else { return nil }       // info > 0 => not positive definite
        return rhs
    }
}

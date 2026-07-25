import Foundation

/// Clamps `value` into the inclusive range `lower...upper` using labeled arguments.
@inlinable
func clamp<T: Comparable>(_ value: T, min lower: T, max upper: T) -> T {
    min(max(value, lower), upper)
}

extension Double {
    /// Clamps the value into `[0, 1]`.
    @inlinable
    var clamped01: Double {
        Swift.min(Swift.max(self, 0.0), 1.0)
    }
}

/// Free-function alias for `Double.clamped01` so call sites can write `clamp01(x)`.
@inlinable
func clamp01(_ value: Double) -> Double {
    value.clamped01
}

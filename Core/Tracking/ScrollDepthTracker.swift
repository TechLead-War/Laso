import Foundation

/// Holds a view's furthest scroll depth without invalidating it.
///
/// Under a `LazyVStack` a section's `onAppear` fires every time it scrolls back
/// into view, and depth was `@State`, so each of those writes re-ran the whole
/// screen's body mid-scroll and re-rendered everything visible. Nothing reads
/// the value during a body pass, only on disappear, so a reference box keeps
/// the analytics identical with no invalidation.
final class ScrollDepthTracker {
    private(set) var maxDepth: Int = 0

    func reset() { maxDepth = 0 }

    func record(_ depth: Int) {
        maxDepth = max(maxDepth, depth)
    }
}

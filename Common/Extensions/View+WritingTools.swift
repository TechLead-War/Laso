import SwiftUI

extension View {
    /// Enable the full Apple Intelligence Writing Tools experience (proofread,
    /// rewrite, summarize) on a text field, where the OS supports it. No-op on
    /// versions or devices without Writing Tools.
    @ViewBuilder
    func writingToolsFull() -> some View {
        if #available(iOS 18.0, *) {
            self.writingToolsBehavior(.complete)
        } else {
            self
        }
    }
}

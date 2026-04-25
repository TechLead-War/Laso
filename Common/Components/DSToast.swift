import SwiftUI

/// Toast kinds — match AppColour semantic state tokens.
enum DSToastKind {
    case success, warning, danger, info

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .danger:  return "xmark.circle.fill"
        case .info:    return "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .success: return AppColour.success
        case .warning: return AppColour.warning
        case .danger:  return AppColour.danger
        case .info:    return AppColour.info
        }
    }
}

/// A single toast payload. Drive presentation via `@State var toast: DSToast?`
/// and the `.dsToast(_:)` modifier.
struct DSToast: Identifiable, Equatable {
    let id = UUID()
    let kind: DSToastKind
    let message: String
    var duration: TimeInterval = 3.0
}

struct DSToastView: View {
    let toast: DSToast

    var body: some View {
        HStack(spacing: DS.space3) {
            Image(systemName: toast.kind.icon)
                .font(DS.Typography.bodySemibold)
                .foregroundStyle(toast.kind.tint)

            Text(toast.message)
                .font(DS.Typography.callout)
                .foregroundStyle(AppColour.textPrimary)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.space4)
        .padding(.vertical, DS.space3)
        .background(
            AppColour.surfaceElevated,
            in: RoundedRectangle(cornerRadius: DS.Radius.md)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .strokeBorder(AppColour.borderMedium, lineWidth: 1)
        )
        .shadow(
            color: .black.opacity(DS.Elevation.shadowMedium.opacity),
            radius: DS.Elevation.shadowMedium.radius,
            y: DS.Elevation.shadowMedium.y
        )
        .padding(.horizontal, DS.space4)
    }
}

/// Attach `.dsToast($toast)` to a root view; set `toast` to present, clear to dismiss.
/// Auto-dismisses after `toast.duration`.
struct DSToastModifier: ViewModifier {
    @Binding var toast: DSToast?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let toast {
                    DSToastView(toast: toast)
                        .padding(.bottom, DS.space6)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task(id: toast.id) {
                            try? await Task.sleep(for: .seconds(toast.duration))
                            withAnimation(DS.Motion.toast) { self.toast = nil }
                        }
                }
            }
            .animation(DS.Motion.toast, value: toast)
    }
}

extension View {
    /// Present transient toast feedback from the bottom of the screen.
    func dsToast(_ toast: Binding<DSToast?>) -> some View {
        modifier(DSToastModifier(toast: toast))
    }
}

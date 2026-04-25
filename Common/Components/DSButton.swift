import SwiftUI

/// App-wide button styles.
///
/// - `.dsPrimary`: solid brand fill — the single hero action per screen (Von Restorff).
/// - `.dsSecondary`: outlined neutral — alternate paths.
/// - `.dsTertiary`: text-only — low-priority inline actions.
/// - `.dsDestructive`: red-tinted — delete / reset.
/// - `.dsPress`: chrome-free press feedback — wrap tappable rows / cards.
///
/// All chrome styles enforce min 44pt tap height (Apple HIG), press-state
/// feedback (scale + opacity) via `DS.Motion`. Selection haptic should be
/// applied at the call site with `.sensoryFeedback(.selection, trigger:)`.

// MARK: - Primary

struct DSPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Typography.bodySemibold)
            .foregroundStyle(.white)
            .padding(.horizontal, DS.space6)
            .padding(.vertical, DS.space3)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity)
            .background(
                Color(uiColor: .systemBlue),
                in: RoundedRectangle(cornerRadius: DS.Radius.md)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(
                configuration.isPressed ? DS.Motion.pressIn : DS.Motion.pressOut,
                value: configuration.isPressed
            )
    }
}

// MARK: - Secondary

struct DSSecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Typography.bodySemibold)
            .foregroundStyle(AppColour.textPrimary)
            .padding(.horizontal, DS.space6)
            .padding(.vertical, DS.space3)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity)
            .background(
                AppColour.surfaceRaised,
                in: RoundedRectangle(cornerRadius: DS.Radius.md)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .strokeBorder(AppColour.borderMedium, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(
                configuration.isPressed ? DS.Motion.pressIn : DS.Motion.pressOut,
                value: configuration.isPressed
            )
    }
}

// MARK: - Tertiary

struct DSTertiaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Typography.bodyMedium)
            .foregroundStyle(Color(uiColor: .systemBlue))
            .padding(.horizontal, DS.space4)
            .padding(.vertical, DS.space2)
            .frame(minHeight: 44)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .animation(DS.Motion.pressOut, value: configuration.isPressed)
    }
}

// MARK: - Destructive

struct DSDestructiveButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Typography.bodySemibold)
            .foregroundStyle(AppColour.danger)
            .padding(.horizontal, DS.space6)
            .padding(.vertical, DS.space3)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity)
            .background(
                AppColour.danger.opacity(0.10),
                in: RoundedRectangle(cornerRadius: DS.Radius.md)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .strokeBorder(AppColour.danger.opacity(0.30), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(
                configuration.isPressed ? DS.Motion.pressIn : DS.Motion.pressOut,
                value: configuration.isPressed
            )
    }
}

// MARK: - Press-only (chrome-free)

struct DSPressButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(
                configuration.isPressed ? DS.Motion.pressIn : DS.Motion.pressOut,
                value: configuration.isPressed
            )
    }
}

// MARK: - Call-site sugar

extension ButtonStyle where Self == DSPrimaryButton {
    static var dsPrimary: DSPrimaryButton { DSPrimaryButton() }
}
extension ButtonStyle where Self == DSSecondaryButton {
    static var dsSecondary: DSSecondaryButton { DSSecondaryButton() }
}
extension ButtonStyle where Self == DSTertiaryButton {
    static var dsTertiary: DSTertiaryButton { DSTertiaryButton() }
}
extension ButtonStyle where Self == DSDestructiveButton {
    static var dsDestructive: DSDestructiveButton { DSDestructiveButton() }
}
extension ButtonStyle where Self == DSPressButton {
    static var dsPress: DSPressButton { DSPressButton() }
}

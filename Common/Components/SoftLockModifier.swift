import SwiftUI

/// Blurs a card for paywall decliners and routes any tap to the unlock sheet.
/// Whole-card blur is deliberate; per-element granularity is skipped.
struct SoftLockModifier: ViewModifier {
    let isLocked: Bool
    /// Names the blocked surface, so each wall stays separable instead of
    /// collapsing into one paywall_viewed(source: "soft_lock_home").
    let feature: String
    let screen: AppFeature
    let onTap: () -> Void

    func body(content: Content) -> some View {
        if isLocked {
            content
                .blur(radius: 10)
                .allowsHitTesting(false)
                .overlay(
                    HStack(spacing: DS.space1) {
                        Image(systemName: "lock.fill")
                        Text(Copy.Home.softLockBadge)
                    }
                    .font(DS.Typography.captionSemibold)
                    .foregroundStyle(AppColour.textSecondary)
                    .padding(.horizontal, DS.badgeH)
                    .padding(.vertical, DS.badgeV)
                    .background(Color.accentColor.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.Radius.full))
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    AppAnalytics.shared.trackPremiumFeatureAttempted(feature: feature, screen: screen)
                    onTap()
                }
        } else {
            content
        }
    }
}

extension View {
    func softLocked(_ isLocked: Bool, feature: String, screen: AppFeature, onTap: @escaping () -> Void) -> some View {
        modifier(SoftLockModifier(isLocked: isLocked, feature: feature, screen: screen, onTap: onTap))
    }
}

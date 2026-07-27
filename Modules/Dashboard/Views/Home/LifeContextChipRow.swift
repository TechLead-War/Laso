import SwiftUI

/// The row of what-is-going-on chips under the greeting. Tapping one turns it on
/// for its own window; tapping again turns it off. An active rest context is a
/// hard constraint on the day's action, so this row sits above the action card
/// rather than buried in settings.
struct LifeContextChipRow: View {
    let store: LifeContextStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.space2) {
                ForEach(LifeContextStore.Context.allCases, id: \.self) { context in
                    chip(context)
                }
            }
            .padding(.horizontal, DS.screenPadding)
        }
        .accessibilityIdentifier("home.lifeContextChips")
    }

    private func chip(_ context: LifeContextStore.Context) -> some View {
        let isOn = store.isActive(context)
        let tint = context.requiresRest ? AppColour.danger : AppColour.accent

        return Button {
            store.toggle(context)
            AppAnalytics.shared.trackBlockTap(
                title: context.rawValue,
                type: .homeDailyAction,
                screen: .home,
                metadata: ["life_context": context.rawValue, "turned_on": !isOn]
            )
        } label: {
            HStack(spacing: 6) {
                Image(systemName: context.systemImage)
                    .font(DS.Typography.caption)
                Text(label(for: context, isOn: isOn))
                    .font(DS.Typography.footnoteMedium)
                    .lineLimit(1)
            }
            .foregroundStyle(isOn ? tint : AppColour.textSecondary)
            .padding(.horizontal, DS.space3)
            .padding(.vertical, DS.space2)
            .background(
                Capsule().fill(isOn ? tint.opacity(DS.badgeBg) : AppColour.surfaceRaised)
            )
            .overlay(
                Capsule().strokeBorder(isOn ? tint.opacity(0.45) : AppColour.borderLow, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label(for: context, isOn: isOn))
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
        .accessibilityHint(Copy.Home.contextAddHint)
    }

    /// An active chip carries its own end date, so the person can see when the
    /// app will stop holding them back without opening anything.
    private func label(for context: LifeContextStore.Context, isOn: Bool) -> String {
        guard isOn, let end = store.endDate(for: context) else { return context.displayName }
        return Copy.Home.contextUntil(context.displayName, end.formatted(.dateTime.day().month(.abbreviated)))
    }
}

import SwiftUI

/// Floating Liquid Glass tab bar. Renders a capsule pill that hovers above
/// content so the scrolling body visibly refracts through the glass on iOS 26,
/// with an `ultraThinMaterial` pill fallback on iOS 17–25.
struct CustomTabBar: View {
    @Binding var selectedTab: AppTab
    @Namespace private var tabNamespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .glassChrome(in: Capsule())
        .overlay(Capsule().strokeBorder(AppColour.borderLow, lineWidth: 0.5))
        .background { shadowHalo }
        .padding(.horizontal, DS.space6)
        .padding(.bottom, DS.space1)
        .sensoryFeedback(.selection, trigger: selectedTab)
    }

    /// Outside-only drop shadow for the floating bar.
    ///
    /// As a whole-view `.shadow` its input was the composed bar, whose glass
    /// backdrop changes on every scroll frame, so it re-rasterized and re-blurred
    /// offscreen each frame. Hanging it on a backing capsule and masking the bar's
    /// own area out keeps just the halo: the glass still samples live scrolling
    /// content, and the mask depends only on size so it rasterizes once at layout.
    /// An opaque capsule instead of the mask would kill that refraction.
    private var shadowHalo: some View {
        Capsule()
            .fill(AppColour.surfaceRaised)
            .shadow(color: AppColour.shadowFloating, radius: 14, y: 4)
            .mask {
                // A mask clips to its own drawn area, so the rectangle has to reach
                // past the blur spread or it cuts off the halo it exists to keep.
                Rectangle()
                    .padding(-40)
                    .overlay(Capsule().blendMode(.destinationOut))
                    .compositingGroup()
            }
    }

    @ViewBuilder
    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selectedTab == tab

        Button {
            let fromTab = selectedTab
            // Written bare: inside a `withAnimation` the tab root's structural
            // switch got the default opacity transition, so both screen trees
            // stayed mounted and composited for the full 0.32 s and the outgoing
            // tab lost its state. The spring is scoped to the button below.
            selectedTab = tab
            AppAnalytics.shared.trackBlockTap(
                title: tab.label,
                type: blockType(for: tab),
                screen: feature(for: fromTab),
                metadata: [
                    "from_tab": fromTab.rawValue,
                    "to_tab": tab.rawValue
                ]
            )
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.systemImageName)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .symbolVariant(isSelected ? .fill : .none)

                Text(tab.label)
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.space2)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.primary.opacity(0.10))
                        .matchedGeometryEffect(id: "selectedTab", in: tabNamespace)
                }
            }
            .animation(.spring(duration: 0.32, bounce: 0.18), value: selectedTab)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.label)
        .accessibilityHint(Copy.Common.switchToTabHint(tab.label))
        .accessibilityIdentifier("tab.\(tab.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func feature(for tab: AppTab) -> AppFeature {
        switch tab {
        case .home: return .home
        case .live: return .live
        case .explore: return .explore
        case .settings: return .settings
        }
    }

    private func blockType(for tab: AppTab) -> BlockType {
        switch tab {
        case .home: return .tabHome
        case .live: return .tabLive
        case .explore: return .tabExplore
        case .settings: return .tabSettings
        }
    }
}

#Preview {
    VStack {
        Spacer()
        CustomTabBar(selectedTab: .constant(.home))
    }
}

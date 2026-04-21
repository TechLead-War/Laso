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
        .overlay(Capsule().strokeBorder(.primary.opacity(0.08), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.22), radius: 14, y: 4)
        .padding(.horizontal, DS.space6)
        .padding(.bottom, DS.space1)
        .sensoryFeedback(.selection, trigger: selectedTab)
    }

    @ViewBuilder
    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selectedTab == tab

        Button {
            let fromTab = selectedTab
            withAnimation(.spring(duration: 0.32, bounce: 0.18)) {
                selectedTab = tab
            }
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
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.label)
        .accessibilityHint("Switch to \(tab.label) tab")
        .accessibilityIdentifier("tab.\(tab.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func feature(for tab: AppTab) -> AppFeature {
        switch tab {
        case .home: return .home
        case .live: return .live
        case .explore: return .explore
        }
    }

    private func blockType(for tab: AppTab) -> BlockType {
        switch tab {
        case .home: return .tabHome
        case .live: return .tabLive
        case .explore: return .tabExplore
        }
    }
}

#Preview {
    VStack {
        Spacer()
        CustomTabBar(selectedTab: .constant(.home))
    }
}

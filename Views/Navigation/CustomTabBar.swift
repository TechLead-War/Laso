import SwiftUI

/// Custom bottom navigation bar with ultra-thin material background extending into safe area
struct CustomTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack {
                ForEach(AppTab.allCases) { tab in
                    Button {
                        let fromTab = selectedTab
                        withAnimation(.easeInOut(duration: 0.2)) {
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
                        VStack(spacing: 4) {
                            Image(systemName: tab.systemImageName)
                                .font(.system(size: 20, weight: selectedTab == tab ? .semibold : .regular))
                                .symbolVariant(selectedTab == tab ? .fill : .none)

                            Text(tab.label)
                                .font(.caption2.weight(selectedTab == tab ? .semibold : .regular))
                        }
                        .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)
                        .padding(.bottom, 2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.label)
                    .accessibilityHint("Switch to \(tab.label) tab")
                    .accessibilityIdentifier("tab.\(tab.rawValue)")
                    .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
                }
            }
            .padding(.horizontal)
        }
        .background(.ultraThinMaterial)
        .sensoryFeedback(.selection, trigger: selectedTab)
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

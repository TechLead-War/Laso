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
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
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
                    .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
                }
            }
            .padding(.horizontal)
        }
        .background(.ultraThinMaterial)
        .sensoryFeedback(.selection, trigger: selectedTab)
    }
}

#Preview {
    VStack {
        Spacer()
        CustomTabBar(selectedTab: .constant(.home))
    }
}

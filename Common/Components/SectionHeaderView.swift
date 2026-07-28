import SwiftUI

struct SectionHeaderView: View {
    let icon: String
    let title: String
    var trailingTitle: String? = nil
    var trailingAction: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(AppColour.primary)
            Text(title)
                .font(.headline)

            if trailingTitle != nil {
                Spacer()
                if let trailingTitle, let trailingAction {
                    Button(trailingTitle, action: trailingAction)
                        .buttonStyle(.dsTertiary)
                }
            }
        }
        .padding(.horizontal)
    }
}

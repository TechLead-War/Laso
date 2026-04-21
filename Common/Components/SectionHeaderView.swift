import SwiftUI

struct SectionHeaderView: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.tint)
            Text(title)
                .font(.headline)
        }
        .padding(.horizontal)
    }
}

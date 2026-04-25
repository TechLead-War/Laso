import SwiftUI

/// Empty state surface for day-zero, no-data, and filtered-empty screens.
/// Follows NN/g pattern: communicate status, teach inline, offer a single clear CTA.
struct DSEmptyState: View {
    let icon: String          // SF Symbol name
    let title: String
    let message: String
    var ctaTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: DS.space4) {
            Image(systemName: icon)
                .font(DS.Typography.largeIcon)
                .foregroundStyle(AppColour.textSecondary)
                .frame(height: 64)

            VStack(spacing: DS.space2) {
                Text(title)
                    .font(DS.Typography.title3)
                    .foregroundStyle(AppColour.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(DS.Typography.callout)
                    .foregroundStyle(AppColour.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let ctaTitle, let action {
                Button(ctaTitle, action: action)
                    .buttonStyle(.dsPrimary)
                    .padding(.horizontal, DS.space8)
                    .padding(.top, DS.space2)
            }
        }
        .padding(DS.space6)
        .frame(maxWidth: .infinity)
    }
}

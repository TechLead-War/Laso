import SwiftUI

/// Shown when the master kill switch is enabled via Remote Config.
/// When an `onContinue` closure is provided the user can dismiss the notice
/// and keep using the app. Without the closure it behaves as an informational banner.
struct MaintenanceView: View {
    let message: String
    var onContinue: (() -> Void)?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)

            Text(Copy.Common.underMaintenance)
                .font(.title.bold())

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.space7)

            if let onContinue {
                Text(Copy.Common.someFeaturesMayNotWorkAs)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.space7)

                Button {
                    onContinue()
                } label: {
                    Text(Copy.Common.continueAnyway)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.orange)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .accessibilityLabel(Copy.Common.continueAnyway)
                .accessibilityHint(Copy.Common.dismissesTheMaintenanceNoticeAndContinuesHint)
                .padding(.horizontal, DS.space7)
            }

            Spacer()
        }
    }
}

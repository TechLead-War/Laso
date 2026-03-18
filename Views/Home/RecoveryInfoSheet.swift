import SwiftUI

/// One-time tutorial sheet explaining how Recovery & Readiness is calculated.
struct RecoveryInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var contentTracker = SectionTracker(section: .recoveryInfoContent, tab: .recoveryInfo)

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: "bolt.heart.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.purple)

                    Text(Copy.Home.RecoveryInfo.title)
                        .font(.title3.weight(.semibold))

                    Text(Copy.Home.RecoveryInfo.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .padding(.top, 8)

                VStack(spacing: 0) {
                    factorRow(
                        icon: "waveform.path.ecg",
                        color: .purple,
                        name: Copy.Home.RecoveryInfo.hrvName,
                        detail: Copy.Home.RecoveryInfo.hrvDetail
                    )
                    Divider().padding(.leading, 52)
                    factorRow(
                        icon: "heart.fill",
                        color: .red,
                        name: Copy.Home.RecoveryInfo.restingHRName,
                        detail: Copy.Home.RecoveryInfo.restingHRDetail
                    )
                }
                .background(.background, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                Text(DeviceMessaging.wearOvernightMessage)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // When does it update?
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 16))
                            .foregroundStyle(.blue)
                        Text(Copy.Home.RecoveryInfo.whenItUpdatesTitle)
                            .font(.subheadline.weight(.medium))
                    }

                    Text(Copy.Home.RecoveryInfo.whenItUpdatesBody)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.background, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                Spacer()
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(Copy.Buttons.done) {
                        AppAnalytics.shared.trackBlockTap(
                            title: "Done",
                            type: .recoveryInfoDone,
                            screen: .recoveryInfo,
                            metadata: [
                                "destination": "dismiss_recovery_info"
                            ]
                        )
                        contentTracker.tapped(target: "done")
                        dismiss()
                    }
                        .font(.subheadline.weight(.medium))
                }
            }
        }
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.recoveryInfo)
            contentTracker.appeared()
        }
        .onDisappear {
            AppAnalytics.shared.trackFeatureClose(.recoveryInfo)
            contentTracker.disappeared()
        }
    }

    private func factorRow(icon: String, color: Color, name: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

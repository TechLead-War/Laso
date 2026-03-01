import SwiftUI

/// One-time tutorial sheet explaining how Recovery & Readiness is calculated.
struct RecoveryInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: "bolt.heart.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.purple)

                    Text("How Recovery Works")
                        .font(.title3.weight(.semibold))

                    Text("Your Readiness score (0\u{2013}100) tells you how recovered your body is, based on two signals measured while you sleep.")
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
                        name: "Heart Rate Variability",
                        detail: "Higher HRV means better recovery and lower stress."
                    )
                    Divider().padding(.leading, 52)
                    factorRow(
                        icon: "heart.fill",
                        color: .red,
                        name: "Resting Heart Rate",
                        detail: "Lower resting HR means your heart is recovering well."
                    )
                }
                .background(.background, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                Text("Wear your Apple Watch overnight so we can update your readiness each morning.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.subheadline.weight(.medium))
                }
            }
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

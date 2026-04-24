import SwiftUI

/// Optional onboarding step where users can enter a referral code.
struct ReferralCodeStep: View {
    let onContinue: () -> Void

    @State private var codeText = ""
    @State private var isRedeeming = false
    @State private var redeemResult: RedeemResult?
    @State private var buttonTapCount = 0

    private enum RedeemResult {
        case success
        case error(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Branding
            Text("Laso")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.bottom, DS.space7)

            // Icon
            Image(systemName: "gift.fill")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.purple)
                .frame(width: 88, height: 88)
                .background(AppColour.categoryStress.opacity(0.12), in: Circle())
                .padding(.bottom, 28)

            // Title + Subtitle
            VStack(spacing: 10) {
                Text("Have a Referral Code?")
                    .font(.title2.weight(.bold))

                Text("If a friend shared their code with you, enter it below. You\u{2019}ll both get 1 month of Pro free when you subscribe.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.space7)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, DS.space6)

            // Code field
            VStack(spacing: 0) {
                HStack {
                    Text("Referral Code")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Spacer()
                    TextField("e.g. HEALTH-A7X3K2", text: $codeText)
                        .font(.subheadline)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .frame(width: 180)
                }
                .padding(.horizontal, DS.space4)
                .padding(.vertical, DS.space3)
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            // Result feedback
            if let result = redeemResult {
                Group {
                    switch result {
                    case .success:
                        Label("Code applied! Subscribe to unlock your free month.", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .error(let message):
                        Label(message, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
                .font(.caption)
                .padding(.top, DS.space2)
                .padding(.horizontal, DS.space6)
            }

            if isRedeeming {
                ProgressView()
                    .padding(.top, DS.space3)
            }

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                // Apply button
                Button {
                    buttonTapCount += 1
                    guard !codeText.trimmingCharacters(in: .whitespaces).isEmpty else {
                        redeemResult = .error("Please enter a referral code.")
                        return
                    }
                    Task {
                        isRedeeming = true
                        let success = await ReferralManager.shared.redeemCode(codeText)
                        isRedeeming = false
                        if success {
                            redeemResult = .success
                            try? await Task.sleep(for: .seconds(1.5))
                            onContinue()
                        } else {
                            redeemResult = .error(ReferralManager.shared.redeemError ?? "Invalid code.")
                        }
                    }
                } label: {
                    Text("Apply Code")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .font(.headline)
                .disabled(isRedeeming)

                // Skip
                Button {
                    onContinue()
                } label: {
                    Text("Skip")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .disabled(isRedeeming)
            }
            .padding(.horizontal, DS.space6)
            .padding(.bottom, DS.space8)
            .sensoryFeedback(.selection, trigger: buttonTapCount)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

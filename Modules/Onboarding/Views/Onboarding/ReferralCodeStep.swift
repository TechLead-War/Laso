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
                .font(DS.Typography.subheadlineMedium)
                .foregroundStyle(AppColour.textSecondary)
                .padding(.bottom, DS.space7)

            // Icon
            Image(systemName: "gift.fill")
                .font(DS.Typography.largeIcon)
                .foregroundStyle(AppColour.accent)
                .frame(width: 88, height: 88)
                .background(AppColour.accent.opacity(DS.badgeBg), in: Circle())
                .padding(.bottom, DS.space7)

            // Title + Subtitle
            VStack(spacing: DS.itemSpacing) {
                Text("Have a Referral Code?")
                    .font(DS.Typography.title2)

                Text("If a friend shared their code with you, enter it below. You\u{2019}ll both get 1 month of Pro free when you subscribe.")
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(AppColour.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.space7)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, DS.space6)

            // Code field
            VStack(spacing: 0) {
                HStack {
                    Text("Referral Code")
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(AppColour.textPrimary)
                    Spacer()
                    TextField("e.g. HEALTH-A7X3K2", text: $codeText)
                        .font(DS.Typography.subheadline)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .frame(width: 180)
                }
                .padding(.horizontal, DS.space4)
                .padding(.vertical, DS.space3)
            }
            .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
            .padding(.horizontal)

            // Result feedback
            if let result = redeemResult {
                Group {
                    switch result {
                    case .success:
                        Label("Code applied! Subscribe to unlock your free month.", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(AppColour.success)
                    case .error(let message):
                        Label(message, systemImage: "xmark.circle.fill")
                            .foregroundStyle(AppColour.danger)
                    }
                }
                .font(DS.Typography.caption)
                .padding(.top, DS.space2)
                .padding(.horizontal, DS.space6)
            }

            if isRedeeming {
                ProgressView()
                    .padding(.top, DS.space3)
            }

            Spacer()

            // Buttons
            VStack(spacing: DS.itemSpacing) {
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
                }
                .buttonStyle(.dsPrimary)
                .disabled(isRedeeming)

                // Skip
                Button {
                    onContinue()
                } label: {
                    Text("Skip")
                }
                .buttonStyle(.dsTertiary)
                .disabled(isRedeeming)
            }
            .padding(.horizontal, DS.space6)
            .padding(.bottom, DS.space8)
            .sensoryFeedback(.selection, trigger: buttonTapCount)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

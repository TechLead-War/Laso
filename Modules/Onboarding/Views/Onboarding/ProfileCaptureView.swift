import SwiftUI
import UIKit

/// Screen 2: About You.
/// Warm conversational capture of age and gender. One field visible at a time, Clinical calm tone.
struct ProfileCaptureView: View {
    let onComplete: (_ name: String?, _ email: String?, _ gender: Gender, _ age: Int?) -> Void

    @State private var gender: Gender?
    @State private var ageText = ""
    @State private var buttonTapCount = 0
    @State private var showValidationErrors = false
    @FocusState private var isAgeFieldFocused: Bool

    private var parsedAge: Int? {
        guard let value = Int(ageText), value >= 13, value <= 120 else { return nil }
        return value
    }

    private var shouldShowAgeError: Bool {
        (showValidationErrors || !ageText.isEmpty) && parsedAge == nil
    }

    private var shouldShowGenderError: Bool {
        showValidationErrors && gender == nil
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "person.crop.circle")
                .font(DS.Typography.mediumIcon)
                .foregroundStyle(AppColour.textPrimary)
                .frame(width: 80, height: 80)
                .background(AppColour.surfaceRaised, in: Circle())
                .padding(.bottom, DS.space6)

            VStack(spacing: DS.itemSpacing) {
                Text(Copy.Onboarding.aboutTitle)
                    .font(DS.Typography.title2)

                Text(Copy.Onboarding.aboutSubtitle)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(AppColour.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.space7)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, DS.space7)

            VStack(spacing: 0) {
                fieldRow {
                    HStack {
                        Text(Copy.Onboarding.aboutAgeLabel)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(AppColour.textPrimary)
                        Spacer()
                        TextField(Copy.Onboarding.aboutAgePlaceholder, text: $ageText)
                            .font(DS.Typography.subheadline)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .focused($isAgeFieldFocused)
                            .frame(width: 80)
                            .accessibilityIdentifier("onboarding.profileAge")
                    }
                }

                Divider().padding(.leading, DS.space4)

                fieldRow {
                    Picker(Copy.Onboarding.aboutGenderPrompt, selection: $gender) {
                        Text(Copy.Onboarding.aboutGenderPrompt).tag(Optional<Gender>.none)
                        ForEach(Gender.allCases) { option in
                            Text(option.displayName)
                                .tag(Optional(option))
                                .accessibilityIdentifier("onboarding.profileGender.\(option.rawValue)")
                        }
                    }
                    .font(DS.Typography.subheadline)
                    .pickerStyle(.menu)
                    .accessibilityLabel(Copy.Onboarding.genderLabel)
                    .accessibilityValue(gender?.displayName ?? "Not selected")
                    .accessibilityHint(Copy.Onboarding.chooseYourGenderForPersonalizedAnalysisHint)
                    .accessibilityIdentifier("onboarding.profileGender")
                }
            }
            .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
            .padding(.horizontal)

            if shouldShowAgeError || shouldShowGenderError {
                VStack(alignment: .leading, spacing: 4) {
                    if shouldShowAgeError {
                        Text(Copy.Onboarding.aboutAgeError)
                    }
                    if shouldShowGenderError {
                        Text(Copy.Onboarding.aboutGenderError)
                    }
                }
                .font(DS.Typography.caption)
                .foregroundStyle(AppColour.danger)
                .padding(.top, DS.space2)
                .padding(.horizontal, DS.space6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            Button {
                buttonTapCount += 1
                showValidationErrors = true
                let requiredGender = gender
                let requiredAge = parsedAge

                AppAnalytics.shared.trackBlockTap(
                    title: "Continue Profile",
                    type: .onboardingProfileContinue,
                    screen: .onboarding,
                    metadata: [
                        "step_name": "profile",
                        "gender": requiredGender?.rawValue ?? "missing",
                        "has_age": requiredAge != nil ? 1 : 0
                    ]
                )

                guard let requiredGender, let requiredAge else { return }

                isAgeFieldFocused = false
                saveDeviceIdSilently()
                onComplete(nil, nil, requiredGender, requiredAge)
            } label: {
                Text(Copy.Onboarding.aboutContinue)
            }
            .buttonStyle(.dsPrimary)
            .accessibilityLabel(Copy.Onboarding.aboutContinue)
            .accessibilityHint(Copy.Onboarding.savesYourAgeAndGenderAndHint)
            .padding(.horizontal, DS.space6)
            .padding(.bottom, DS.space8)
            .sensoryFeedback(.selection, trigger: buttonTapCount)
            .accessibilityIdentifier("onboarding.profileContinue")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func fieldRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, DS.space4)
            .padding(.vertical, DS.space3)
    }

    private func saveDeviceIdSilently() {
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserProfileStore.shared.persistDeviceId(deviceId)
    }
}

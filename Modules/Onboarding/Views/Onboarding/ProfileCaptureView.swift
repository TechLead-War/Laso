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
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(.primary)
                .frame(width: 80, height: 80)
                .background(Color.primary.opacity(0.06), in: Circle())
                .padding(.bottom, DS.space6)

            VStack(spacing: 10) {
                Text(Copy.Onboarding.aboutTitle)
                    .font(.title2.weight(.bold))

                Text(Copy.Onboarding.aboutSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.space7)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 28)

            VStack(spacing: 0) {
                fieldRow {
                    HStack {
                        Text(Copy.Onboarding.aboutAgeLabel)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField(Copy.Onboarding.aboutAgePlaceholder, text: $ageText)
                            .font(.subheadline)
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
                    .font(.subheadline)
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("onboarding.profileGender")
                }
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
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
                .font(.caption)
                .foregroundStyle(.red)
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
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .font(.headline)
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

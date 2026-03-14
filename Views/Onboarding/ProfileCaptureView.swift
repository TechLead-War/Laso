import SwiftUI
import UIKit

// MARK: - ProfileCaptureView

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

            // Branding
            Text("Laso")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)

            // Icon
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.teal)
                .frame(width: 88, height: 88)
                .background(Color.teal.opacity(0.12), in: Circle())
                .padding(.bottom, 28)

            // Title + Subtitle
            VStack(spacing: 10) {
                Text("About You")
                    .font(.title2.weight(.bold))

                Text("Heart rate, sleep, and recovery norms vary by age and gender. This helps compare your data to what\u{2019}s normal for you.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 24)

            // Form fields
            VStack(spacing: 0) {
                // Age
                fieldRow {
                    HStack {
                        Text("Age *")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField("e.g. 28", text: $ageText)
                            .font(.subheadline)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .focused($isAgeFieldFocused)
                            .frame(width: 80)
                    }
                }

                Divider().padding(.leading, 16)

                // Gender
                fieldRow {
                    Picker("Gender *", selection: $gender) {
                        Text("Select gender").tag(Optional<Gender>.none)
                        ForEach(Gender.allCases) { option in
                            Text(option.displayName).tag(Optional(option))
                        }
                    }
                    .font(.subheadline)
                    .pickerStyle(.menu)
                }
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            if shouldShowAgeError || shouldShowGenderError {
                VStack(alignment: .leading, spacing: 4) {
                    if shouldShowAgeError {
                        Text("Enter a valid age between 13 and 120.")
                    }
                    if shouldShowGenderError {
                        Text("Select a gender to continue.")
                    }
                }
                .font(.caption)
                .foregroundStyle(.red)
                .padding(.top, 8)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            // Continue button
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
                        "step_name": "profile_capture",
                        "gender": requiredGender?.rawValue ?? "missing",
                        "has_age": requiredAge != nil ? 1 : 0
                    ]
                )

                guard let requiredGender, let requiredAge else { return }

                isAgeFieldFocused = false
                saveDeviceIdSilently()
                onComplete(
                    nil,
                    nil,
                    requiredGender,
                    requiredAge
                )
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .font(.headline)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
            .sensoryFeedback(.selection, trigger: buttonTapCount)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func fieldRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }

    /// Silently persist device ID without any user-facing prompt
    private func saveDeviceIdSilently() {
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(deviceId, forKey: AppKeys.Profile.deviceId)
    }
}

import SwiftUI

// MARK: - ProfileCaptureView

struct ProfileCaptureView: View {
    let onComplete: (_ name: String?, _ email: String?, _ gender: Gender, _ dateOfBirth: Date?) -> Void

    @State private var name = ""
    @State private var email = ""
    @State private var gender: Gender = .preferNotToSay
    @State private var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    @State private var hasSelectedDateOfBirth = false
    @State private var buttonTapCount = 0

    private var minDate: Date {
        Calendar.current.date(byAdding: .year, value: -100, to: Date()) ?? Date()
    }

    private var maxDate: Date {
        Calendar.current.date(byAdding: .year, value: -13, to: Date()) ?? Date()
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

                Text("This helps us personalize insights for your body. Everything stays private.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 24)

            // Form fields
            VStack(spacing: 0) {
                // First name
                fieldRow {
                    HStack {
                        Text("Name")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField("Optional", text: $name)
                            .font(.subheadline)
                            .multilineTextAlignment(.trailing)
                            .textContentType(.givenName)
                            .autocorrectionDisabled()
                    }
                }

                Divider().padding(.leading, 16)

                // Email
                fieldRow {
                    HStack {
                        Text("Email")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField("Optional", text: $email)
                            .font(.subheadline)
                            .multilineTextAlignment(.trailing)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                Divider().padding(.leading, 16)

                // Gender
                fieldRow {
                    Picker("Gender", selection: $gender) {
                        ForEach(Gender.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .font(.subheadline)
                }

                Divider().padding(.leading, 16)

                // Date of birth
                fieldRow {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date of Birth")
                            .font(.subheadline)
                            .foregroundStyle(.primary)

                        DatePicker(
                            "Date of Birth",
                            selection: $dateOfBirth,
                            in: minDate...maxDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(height: 120)
                        .clipped()
                        .onChange(of: dateOfBirth) { _, _ in
                            hasSelectedDateOfBirth = true
                        }
                    }
                }
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            Spacer()

            // Skip button
            Button {
                AppAnalytics.shared.trackBlockTap(
                    title: "Skip Profile",
                    type: .onboardingProfileSkip,
                    screen: .onboarding,
                    metadata: [
                        "step_name": "profile_capture"
                    ]
                )
                onComplete(nil, nil, .preferNotToSay, nil)
            } label: {
                Text("Skip")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 12)

            // Continue button
            Button {
                buttonTapCount += 1
                AppAnalytics.shared.trackBlockTap(
                    title: "Continue Profile",
                    type: .onboardingProfileContinue,
                    screen: .onboarding,
                    metadata: [
                        "step_name": "profile_capture",
                        "has_name": name.trimmingCharacters(in: .whitespaces).isEmpty ? 0 : 1,
                        "has_email": email.trimmingCharacters(in: .whitespaces).isEmpty ? 0 : 1,
                        "gender": gender.rawValue,
                        "has_dob": hasSelectedDateOfBirth ? 1 : 0
                    ]
                )
                let trimmedName = name.trimmingCharacters(in: .whitespaces)
                let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
                onComplete(
                    trimmedName.isEmpty ? nil : trimmedName,
                    trimmedEmail.isEmpty ? nil : trimmedEmail,
                    gender,
                    hasSelectedDateOfBirth ? dateOfBirth : nil
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
}

import SwiftUI

/// Non-annoying feedback form. feels collaborative, not like a survey.
/// Serves three entry points: general feedback, bug reports, and support requests.
/// The entry point decides the headline copy, visible categories, and whether we collect an email.
struct FeedbackSheet: View {
    enum EntryPoint: String, Identifiable {
        case idea
        case bug
        case support

        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss

    @State private var feedbackText = ""
    @State private var selectedCategory: FeedbackCategory
    @State private var contactEmail: String
    @State private var submitted = false
    @State private var isSending = false

    private let entryPoint: EntryPoint

    init(entryPoint: EntryPoint = .idea) {
        self.entryPoint = entryPoint
        let initialCategory: FeedbackCategory = switch entryPoint {
        case .idea: .feature
        case .bug: .bug
        case .support: .support
        }
        self._selectedCategory = State(initialValue: initialCategory)
        self._contactEmail = State(initialValue: Self.savedEmail())
    }

    var body: some View {
        NavigationStack {
            if submitted {
                thankYouView
            } else {
                formView
            }
        }
    }

    // MARK: - Entry Point Config

    private var headline: String {
        switch entryPoint {
        case .idea: return "What should we build next?"
        case .bug: return "Report a bug"
        case .support: return "Contact support"
        }
    }

    private var subheadline: String {
        switch entryPoint {
        case .idea: return "Tell us the feature you want most. We will build it for you."
        case .bug: return "Describe what went wrong. We will get back to you on the email below."
        case .support: return "Ask us anything. We will reply on the email below."
        }
    }

    private var textFieldPrompt: String {
        switch entryPoint {
        case .idea: return "What feature do you want to see next in Laso?"
        case .bug: return "What went wrong? Steps to reproduce, what you expected, what you saw."
        case .support: return "How can we help?"
        }
    }

    private var submitButtonTitle: String {
        switch entryPoint {
        case .idea: return "Send Feedback"
        case .bug: return "Send Bug Report"
        case .support: return "Send Message"
        }
    }

    private var showsCategoryPicker: Bool {
        entryPoint == .idea
    }

    private var needsEmail: Bool {
        selectedCategory.needsContactEmail
    }

    private var isSubmitDisabled: Bool {
        if feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        if needsEmail, !Self.isValidEmail(contactEmail) { return true }
        return isSending
    }

    private var thankYouTitle: String {
        switch entryPoint {
        case .idea: return "Thank You!"
        case .bug: return "Bug report received"
        case .support: return "Message received"
        }
    }

    private var thankYouBody: String {
        switch entryPoint {
        case .idea: return "We will get to work on it. Your input shapes what comes next."
        case .bug: return "Thanks for the details. We will investigate and reply on the email you shared."
        case .support: return "We will read this soon and get back to you on the email you shared."
        }
    }

    // MARK: - Form

    private var formView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(headline)
                        .font(.title2.weight(.bold))

                    Text(subheadline)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Category picker (only for idea entry)
                if showsCategoryPicker {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What is this about?")
                            .font(.subheadline.weight(.medium))

                        HStack(spacing: 8) {
                            ForEach(FeedbackCategory.ideaCategories) { category in
                                Button {
                                    AppAnalytics.shared.trackBlockTap(
                                        title: category.displayName,
                                        type: .feedbackCategory,
                                        screen: .feedback,
                                        metadata: [
                                            "feedback_category": category.rawValue
                                        ]
                                    )
                                    selectedCategory = category
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: category.icon)
                                            .font(.caption)
                                        Text(category.displayName)
                                            .font(.caption.weight(.medium))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        selectedCategory == category
                                            ? Color.blue
                                            : Color(.systemGray5),
                                        in: Capsule()
                                    )
                                    .foregroundStyle(selectedCategory == category ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Email field (only for bug/support)
                if needsEmail {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your email")
                            .font(.subheadline.weight(.medium))

                        TextField("you@example.com", text: $contactEmail)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.never)
                    }
                }

                // Text input
                VStack(alignment: .leading, spacing: 8) {
                    Text(entryPoint == .idea ? "Your idea or feedback" : "Details")
                        .font(.subheadline.weight(.medium))

                    TextField(textFieldPrompt, text: $feedbackText, axis: .vertical)
                        .lineLimit(3...8)
                        .textFieldStyle(.roundedBorder)
                }

                // Submit
                Button {
                    AppAnalytics.shared.trackBlockTap(
                        title: submitButtonTitle,
                        type: .feedbackSubmit,
                        screen: .feedback,
                        metadata: [
                            "feedback_category": selectedCategory.rawValue,
                            "text_length": feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).count,
                            "entry_point": entryPointAnalytics
                        ]
                    )
                    submitFeedback()
                } label: {
                    if isSending {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .accessibilityLabel("Sending feedback")
                    } else {
                        Text(submitButtonTitle)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSubmitDisabled)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear { AppAnalytics.shared.trackFeatureOpen(.feedback) }
        .onDisappear { AppAnalytics.shared.trackFeatureClose(.feedback) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Skip") {
                    AppAnalytics.shared.trackBlockTap(
                        title: "Skip",
                        type: .feedbackSkip,
                        screen: .feedback,
                        metadata: [
                            "feedback_category": selectedCategory.rawValue,
                            "text_length": feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).count
                        ]
                    )
                    dismiss()
                }
                .font(.subheadline)
            }
        }
    }

    // MARK: - Thank You

    private var thankYouView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "heart.circle.fill")
                .font(DS.Typography.heroIcon)
                .foregroundStyle(.green)

            Text(thankYouTitle)
                .font(.title2.weight(.bold))

            Text(thankYouBody)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.space7)

            Spacer()

            Button("Done") {
                AppAnalytics.shared.trackBlockTap(
                    title: "Done After Submit",
                    type: .feedbackDoneAfterSubmit,
                    screen: .feedback,
                    metadata: [
                        "feedback_category": selectedCategory.rawValue
                    ]
                )
                dismiss()
            }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, DS.space7)
        }
        .onAppear {}
    }

    // MARK: - Submit

    private func submitFeedback() {
        let trimmed = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let emailTrimmed = contactEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        if needsEmail, !Self.isValidEmail(emailTrimmed) { return }

        isSending = true

        // Persist email so future bug/support sheets prefill it.
        if needsEmail, !emailTrimmed.isEmpty {
            UserDefaults.standard.set(emailTrimmed, forKey: Self.contactEmailDefaultsKey)
        }

        FeedbackPromptManager.shared.submitFeedback(
            category: selectedCategory.rawValue,
            text: trimmed,
            contactEmail: needsEmail ? emailTrimmed : nil
        ) {
            finishSubmission(trimmed: trimmed)
        }
    }

    private func finishSubmission(trimmed: String) {
        // Derive sentiment: feature/metric requests = positive (user wants more),
        // bug reports = negative, support/design/other = neutral.
        let sentiment: String = switch selectedCategory {
        case .feature, .metric: "positive"
        case .bug: "negative"
        case .design, .support, .other: "neutral"
        }

        AppAnalytics.shared.trackFeedbackSubmitted(
            category: selectedCategory.rawValue,
            textLength: trimmed.count,
            sentiment: sentiment
        )
        FeedbackPromptManager.shared.markFeedbackSubmitted()

        isSending = false
        withAnimation {
            submitted = true
        }
    }

    // MARK: - Helpers

    private var entryPointAnalytics: String {
        switch entryPoint {
        case .idea: return "idea"
        case .bug: return "bug"
        case .support: return "support"
        }
    }

    private static let contactEmailDefaultsKey = "laso.feedback.contact_email"

    private static func savedEmail() -> String {
        UserDefaults.standard.string(forKey: contactEmailDefaultsKey) ?? ""
    }

    private static func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let pattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return trimmed.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}

// MARK: - Feedback Categories

enum FeedbackCategory: String, CaseIterable, Identifiable {
    var id: String { rawValue }

    case feature
    case metric
    case design
    case bug
    case support
    case other

    var displayName: String {
        switch self {
        case .feature: return "Feature"
        case .metric: return "Metrics"
        case .design: return "Design"
        case .bug: return "Bug"
        case .support: return "Support"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .feature: return "sparkles"
        case .metric: return "heart.text.square"
        case .design: return "paintbrush"
        case .bug: return "ladybug"
        case .support: return "questionmark.bubble"
        case .other: return "ellipsis.circle"
        }
    }

    /// Categories offered when the sheet is opened from the ambient "What should we build next?" nudge.
    /// Bug reports and support requests are entry points with their own dedicated copy and email capture.
    static var ideaCategories: [FeedbackCategory] {
        [.feature, .metric, .design, .other]
    }

    /// True when we should ask the user for a return email so support can reply.
    var needsContactEmail: Bool {
        switch self {
        case .bug, .support: return true
        default: return false
        }
    }
}

#Preview {
    FeedbackSheet()
}

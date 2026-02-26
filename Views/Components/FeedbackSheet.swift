import SwiftUI

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Non-annoying feedback form — feels collaborative, not like a survey.
/// "Help us build what you need next."
struct FeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var feedbackText = ""
    @State private var selectedCategory: FeedbackCategory = .feature
    @State private var submitted = false
    @State private var isSending = false

    var body: some View {
        NavigationStack {
            if submitted {
                thankYouView
            } else {
                formView
            }
        }
    }

    // MARK: - Form

    private var formView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("What should we build next?")
                        .font(.title2.weight(.bold))

                    Text("Tell us the feature you want most — we'll build it for you.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Category picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("What's this about?")
                        .font(.subheadline.weight(.medium))

                    HStack(spacing: 8) {
                        ForEach(FeedbackCategory.allCases) { category in
                            Button {
                                AppAnalytics.shared.trackBlockTap(title: category.displayName, type: .feedbackCategory, screen: .feedback)
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

                // Text input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your idea or feedback")
                        .font(.subheadline.weight(.medium))

                    TextField("What feature do you want to see next in Laso?", text: $feedbackText, axis: .vertical)
                        .lineLimit(3...8)
                        .textFieldStyle(.roundedBorder)
                }

                // Submit
                Button {
                    submitFeedback()
                } label: {
                    if isSending {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    } else {
                        Text("Send Feedback")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear { AppAnalytics.shared.trackFeatureOpen(.feedback) }
        .onDisappear { AppAnalytics.shared.trackFeatureClose(.feedback) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Skip") {
                    AppAnalytics.shared.trackBlockTap(title: "Skip", type: .feedbackSkip, screen: .feedback)
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
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("Thank You!")
                .font(.title2.weight(.bold))

            Text("We'll get to work on it. Your input shapes what comes next.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button("Done") {
                AppAnalytics.shared.trackBlockTap(title: "Done After Submit", type: .feedbackDoneAfterSubmit, screen: .feedback)
                dismiss()
            }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 32)
        }
        .onAppear {
            AppAnalytics.shared.trackAction("feedback_thank_you_shown")
        }
    }

    // MARK: - Submit

    private func submitFeedback() {
        let trimmed = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSending = true

        // 1. Save locally as backup
        var allFeedback = UserDefaults.standard.stringArray(forKey: AppKeys.Feedback.entries) ?? []
        let entry = "[\(selectedCategory.rawValue)] \(trimmed) — \(Date().formatted(.dateTime.month().day().year()))"
        allFeedback.append(entry)
        UserDefaults.standard.set(allFeedback, forKey: AppKeys.Feedback.entries)

        // 2. Send to Firebase Firestore (collective feedback)
        let feedbackData: [String: Any] = [
            "category": selectedCategory.rawValue,
            "text": trimmed,
            "timestamp": Date().timeIntervalSince1970,
            "days_since_install": FeedbackPromptManager.shared.daysSinceInstall,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ]

#if canImport(FirebaseFirestore)
        Firestore.firestore().collection("feedback").addDocument(data: feedbackData) { _ in
            finishSubmission(trimmed: trimmed)
        }
#else
        print("[Feedback] Would send to Firestore: \(feedbackData)")
        finishSubmission(trimmed: trimmed)
#endif
    }

    private func finishSubmission(trimmed: String) {
        // 3. Fire analytics event
        AppAnalytics.shared.trackFeedbackSubmitted(
            category: selectedCategory.rawValue,
            textLength: trimmed.count
        )
        FeedbackPromptManager.shared.markFeedbackSubmitted()

        isSending = false
        withAnimation {
            submitted = true
        }
    }
}

// MARK: - Feedback Categories

enum FeedbackCategory: String, CaseIterable, Identifiable {
    var id: String { rawValue }

    case feature
    case metric
    case design
    case other

    var displayName: String {
        switch self {
        case .feature: return "Feature"
        case .metric: return "Metrics"
        case .design: return "Design"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .feature: return "sparkles"
        case .metric: return "heart.text.square"
        case .design: return "paintbrush"
        case .other: return "ellipsis.circle"
        }
    }
}

#Preview {
    FeedbackSheet()
}

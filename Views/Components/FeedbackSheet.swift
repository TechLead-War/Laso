import SwiftUI

/// Non-annoying feedback form — feels collaborative, not like a survey.
/// "Help us build what you need next."
struct FeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var feedbackText = ""
    @State private var selectedCategory: FeedbackCategory = .feature
    @State private var submitted = false

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
                    Text("Send Feedback")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Skip") {
                    AnalyticsManager.shared.track(.feedbackDismissed)
                    AnalyticsManager.shared.recordFeedbackInteraction()
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

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 32)
        }
    }

    // MARK: - Submit

    private func submitFeedback() {
        let trimmed = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Store locally via analytics
        AnalyticsManager.shared.track(.feedbackSubmitted(
            category: selectedCategory.rawValue,
            hasText: true
        ))
        AnalyticsManager.shared.recordFeedbackInteraction()

        // Also store the actual text in UserDefaults for retrieval
        var allFeedback = UserDefaults.standard.stringArray(forKey: "laso.feedback.entries") ?? []
        let entry = "[\(selectedCategory.rawValue)] \(trimmed) — \(Date().formatted(.dateTime.month().day().year()))"
        allFeedback.append(entry)
        UserDefaults.standard.set(allFeedback, forKey: "laso.feedback.entries")

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

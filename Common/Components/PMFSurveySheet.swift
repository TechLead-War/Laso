import SwiftUI

/// Sean Ellis PMF survey. The canonical product-market fit measurement.
/// >40% "very disappointed" = PMF achieved.
///
/// Flow: disappointment question → segment → benefit → improvement (optional text)
/// Shown once after 14+ days AND 10+ sessions (configurable via Remote Config).
struct PMFSurveySheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var step: Step = .disappointment
    @State private var disappointmentAnswer: String?
    @State private var segmentAnswer = ""
    @State private var benefitAnswer = ""
    @State private var improvementText = ""
    @State private var submitted = false

    private enum Step: Int {
        case disappointment
        case segment
        case benefit
        case improvement
        case done
    }

    var body: some View {
        NavigationStack {
            if submitted {
                thankYouView
            } else {
                surveyContent
            }
        }
    }

    // MARK: - Survey Content

    private var surveyContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                switch step {
                case .disappointment:
                    disappointmentStep
                case .segment:
                    segmentStep
                case .benefit:
                    benefitStep
                case .improvement:
                    improvementStep
                case .done:
                    EmptyView()
                }
            }
            .padding(DS.space6)
        }
        .navigationTitle(Copy.Common.quickQuestion)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(Copy.Common.skipButton) {
                    AppAnalytics.shared.trackBlockTap(
                        title: "PMF Survey Skip",
                        type: .feedbackSkip,
                        screen: .feedback,
                        metadata: ["step": "\(step.rawValue)"]
                    )
                    dismiss()
                }
            }
        }
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.feedback, metadata: ["subscreen": "pmf_survey"])
        }
        .onDisappear {
            AppAnalytics.shared.trackFeatureClose(.feedback, metadata: ["subscreen": "pmf_survey"])
        }
    }

    // MARK: - Step 1: Disappointment

    private var disappointmentStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(Copy.Common.howWouldYouFeelIfYou)
                .font(.title3.weight(.bold))

            VStack(spacing: 10) {
                responseButton(Copy.Common.pmfVeryDisappointed, value: "very_disappointed")
                responseButton(Copy.Common.pmfSomewhatDisappointed, value: "somewhat_disappointed")
                responseButton(Copy.Common.pmfNotDisappointed, value: "not_disappointed")
            }
        }
    }

    private func responseButton(_ label: String, value: String) -> some View {
        Button {
            disappointmentAnswer = value
            AppAnalytics.shared.trackPMFSurveyResponse(response: value, source: "pmf_survey")
            withAnimation(.smooth(duration: 0.3)) { step = .segment }
        } label: {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                if disappointmentAnswer == value {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(disappointmentAnswer == value ? Color.accentColor.opacity(0.1) : Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 2: Segment

    private var segmentStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(Copy.Common.whatTypeOfPersonDoYou)
                .font(.title3.weight(.bold))

            TextField("e.g., fitness enthusiast, someone with a chronic condition...", text: $segmentAnswer, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(2...4)
                .padding(DS.space3)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))

            Button {
                AppAnalytics.shared.trackPMFSegmentResponse(segment: segmentAnswer)
                withAnimation(.smooth(duration: 0.3)) { step = .benefit }
            } label: {
                Text(Copy.Common.continueLabel)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.space3)
            }
            .buttonStyle(.borderedProminent)
            .disabled(segmentAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    // MARK: - Step 3: Benefit

    private var benefitStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(Copy.Common.whatIsTheMainBenefitYou)
                .font(.title3.weight(.bold))

            TextField("e.g., understanding my recovery, sleep insights...", text: $benefitAnswer, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(2...4)
                .padding(DS.space3)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))

            Button {
                AppAnalytics.shared.trackPMFBenefitResponse(benefit: benefitAnswer)
                withAnimation(.smooth(duration: 0.3)) { step = .improvement }
            } label: {
                Text(Copy.Common.continueLabel2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.space3)
            }
            .buttonStyle(.borderedProminent)
            .disabled(benefitAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    // MARK: - Step 4: Improvement

    private var improvementStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(Copy.Common.howCanWeImproveLasoFor)
                .font(.title3.weight(.bold))

            TextField("Optional — anything you'd change or add", text: $improvementText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(2...6)
                .padding(DS.space3)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))

            Button {
                if !improvementText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    AppAnalytics.shared.trackPMFImprovementResponse(improvement: improvementText)
                }
                submitSurvey()
            } label: {
                Text(improvementText.isEmpty ? "Done" : "Submit")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.space3)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Thank You

    private var thankYouView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "heart.fill")
                .font(.system(size: 48))
                .foregroundStyle(.pink)
            Text(Copy.Common.thankYou)
                .font(.title2.weight(.bold))
            Text(Copy.Common.yourFeedbackShapesWhatWeBuild)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button(Copy.Common.doneButton) { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, DS.space6)
        }
        .padding()
    }

    // MARK: - Submit

    private func submitSurvey() {
        PMFSurveyManager.shared.markSurveyCompleted()
        withAnimation(.smooth(duration: 0.3)) { submitted = true }
    }
}

// MARK: - PMF Survey Manager

/// Controls when the PMF survey should be shown.
/// Criteria: 14+ days since install, 10+ sessions, not shown in last 90 days.
@MainActor
final class PMFSurveyManager {
    static let shared = PMFSurveyManager()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let lastSurveyDate = "laso.pmf.last_survey_date"
        static let surveyCount = "laso.pmf.survey_count"
    }

    /// Cooldown between surveys (90 days)
    private let cooldownDays = 90

    /// Minimum sessions before first survey
    private let minSessions = 10

    /// Minimum days since install before first survey
    private let minDaysSinceInstall = 14

    private init() {}

    func shouldShowSurvey() -> Bool {
        let daysSinceInstall = SessionTracker.shared.daysSinceInstall
        let totalSessions = SessionTracker.shared.totalSessions

        guard daysSinceInstall >= minDaysSinceInstall else { return false }
        guard totalSessions >= minSessions else { return false }

        if let lastDate = defaults.object(forKey: Key.lastSurveyDate) as? Date {
            let daysSinceLast = Date.cal.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
            return daysSinceLast >= cooldownDays
        }

        return true // Never shown before, criteria met
    }

    func markSurveyCompleted() {
        defaults.set(Date(), forKey: Key.lastSurveyDate)
        let count = defaults.integer(forKey: Key.surveyCount) + 1
        defaults.set(count, forKey: Key.surveyCount)
    }
}

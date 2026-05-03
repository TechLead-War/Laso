import Foundation

extension Copy {
    enum Onboarding {

        // MARK: - Snapshot Cards

        static let restingHRLabel = "Resting HR"
        static let last7NightsLabel = "Last 7 nights"
        static let noNightsRecorded = "No nights recorded yet"
        static let hrvWeeklyAverage = "HRV · weekly average"
        static let notEnoughHRVSamples = "Not enough HRV samples across the week"
        static func dayLabel(_ day: Int) -> String { "DAY \(day)" }

        // MARK: - Pulse (Screen 1)

        static let pulseHeadline = "See what your body has been telling you."
        static let pulseBegin = "Begin"

        // MARK: - About You (Screen 2)

        static let aboutTitle = "Start with you"
        static let aboutSubtitle = "Heart, sleep, and recovery change at every life stage. Yours are yours alone."
        static let aboutAgeLabel = "Age"
        static let aboutAgePlaceholder = "e.g. 28"
        static let aboutGenderPrompt = "Select gender"
        static let aboutAgeError = "Enter a valid age between 13 and 120."
        static let aboutGenderError = "Select a gender to continue."
        static let aboutContinue = "Continue"

        // MARK: - Connect Apple Health (Screen 3)

        static let connectTitle = "Your numbers, made simple."
        static let connectSubtitle = "Laso turns your Apple Health history into the story of your body."
        static let connectPrivacyNote = "Stays on your iPhone."
        static let connectAllow = "Connect Apple Health"
        static let connectUnavailable = "Apple Health is not available on this device."
        static let connectContinueAnyway = "Continue without Apple Health"

        static func personalizedConnectNote(age: Int?) -> String? {
            guard let age else { return nil }
            switch age {
            case ..<25:
                return "Starting early means a lifetime of knowing what is normal for your body."
            case 25..<35:
                return "At your age, heart and recovery patterns say a lot about how you are doing."
            case 35..<45:
                return "At your age, watching heart health and recovery really pays off."
            case 45..<55:
                return "At your age, tracking heart, sleep, and mobility shows you important changes."
            default:
                return "Your data will be compared to what is typical for your age."
            }
        }

        // MARK: - Priority (Screen 4)

        static let priorityTitle = "What should Laso look at first?"
        static let prioritySubtitle = "Your pick shapes the insights you see."
        static let priorityContinue = "Continue"

        static func priorityCardSubtitle(for focus: HealthFocus) -> String {
            switch focus {
            case .sleep: "Overnight recovery and patterns"
            case .fitness: "Movement, workouts, and effort"
            case .heartHealth: "Resting rate, HRV, cardio fitness"
            case .weightBody: "Trends in body shape and vitals"
            case .recovery: "How ready your body is each day"
            }
        }

        // MARK: - Mirror Moment (Screen 5)

        static let mirrorCalibratingTitle = "Reading your signal"
        static let mirrorCalibratingMessage = "Laso is building your personal baseline from Apple Health. This only happens once."
        static let mirrorCompleteTitle = "Here is what I found"
        static func mirrorCompleteSubtitle(_ span: String) -> String {
            "\(span) of your health, understood."
        }
        static let mirrorNoDataMessage = "No data yet. Laso will build your baseline as data comes in."
        static let mirrorContinue = "Show me more"
        static let mirrorRetry = "Try again"
        static let mirrorSkip = "Skip for now"
        static let mirrorIncomplete = "Still syncing"

        /// Priority aware, soft pattern observation. Never predicts outcomes.
        static func mirrorObservation(for focuses: Set<HealthFocus>, metricsWithData: Int) -> String? {
            guard metricsWithData > 0 else { return nil }
            if focuses.contains(.heartHealth) || focuses.contains(.recovery) {
                return "Heart and recovery signals are in. Laso can start finding your rhythms."
            }
            if focuses.contains(.sleep) {
                return "Your sleep history gives Laso a strong signal to work with."
            }
            if focuses.contains(.fitness) {
                return "Activity patterns are in. Laso can see how your body handles effort."
            }
            if focuses.contains(.weightBody) {
                return "Body measurements will anchor the trends you see over time."
            }
            return "Your baseline is in. Laso can start finding patterns."
        }

        static let calibrationReassurance: [String] = [
            "Reading your Apple Watch history",
            "Finding patterns in your heart rate",
            "Looking at sleep cycles",
            "Building your personal baseline",
            "Large histories take a moment",
            "Almost there"
        ]

        // MARK: - Promise (Screen 6)

        static let promiseTitle = "Your first 7 days"
        static func promiseBody(patternCount: Int, span: String?) -> String {
            let countPart = "Laso will surface \(patternCount) pattern\(patternCount == 1 ? "" : "s") from your"
            if let span {
                return "\(countPart) \(span) of history."
            }
            return "\(countPart) health data."
        }
        static let promiseFallback = "Laso will start building your baseline as data comes in."
        static let promiseSignInHelper = "We use Apple Sign In so your subscription stays with you across devices."
        static let promiseDisclaimerFooter = "Not a medical device. Laso is for information, not diagnosis."
        static let promiseDisclaimerLearnMore = "Full disclaimer"

        // MARK: - Trial (Screen 7)

        static let trialTitle = "Start your 7-day free trial"
        static let trialSubtitle = "Full access to insights, alerts, and trends. Cancel any time in Settings before day 7."
        static let trialCTA = "Start 7-day Free Trial"
        static let trialFooterNote = "No charge today. Apple will remind you before your trial ends."

        // MARK: - Siri tip

        static let worksWithSiri = "Works with Siri"
        static let siriTip = "Try saying \"Hey Siri, what's my health score in Laso\""

        // MARK: - Mirror Moment Calibration

        static let mirrorStartingCalibration = "Starting calibration\u{2026}"

        // MARK: - Referral Code Step

        enum ReferralCode {
            static let brand = "Laso"
            static let title = "Have a Referral Code?"
            static let subtitle = "If a friend shared their code with you, enter it below. You\u{2019}ll both get 1 free month of Pro when you subscribe."
            static let fieldLabel = "Referral Code"
            static let fieldPlaceholder = "e.g. HEALTH-A7X3K2"
            static let verifying = "Verifying code\u{2026}"
            static let apply = "Apply Code"
            static let skip = "Skip"
            static let codeApplied = "Code applied! Subscribe to unlock your free month."
            static let emptyCodeError = "Please enter a referral code."
            static let invalidCodeFallback = "Invalid code."
        }
    }
}

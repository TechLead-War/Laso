import SwiftUI

// All user-facing copy for the 16-screen V2 onboarding flow. Every string
// resolves through Firebase Remote Config (admin override → RC → bundled
// English default) so operators can edit onboarding copy live without a
// release. Icons, colours, and enum keys stay in the structs — only text is
// remote. Grammatical unit words (year/years, mo, etc.) inside the footnote
// helpers stay inline: they are language rules, not brand copy.
extension Copy {
    enum OnboardingV2 {

        private static func s(_ key: String, _ fallback: String) -> String {
            RemoteConfigManager.shared.copyString(key, default: fallback)
        }

        // MARK: - Screen 1 — Welcome
        static var s1Eyebrow: String { s("copy_onboardingv2_s1_eyebrow", "LASO") }
        static var s1Title: String   { s("copy_onboardingv2_s1_title", "You deserve\nto feel understood.") }
        static var s1Lede: String    { s("copy_onboardingv2_s1_lede", "Your body has been telling you something for years. Laso helps you finally understand it.") }
        static var s1CTA: String     { s("copy_onboardingv2_s1_cta", "Begin") }

        // MARK: - Screen 2 — Promise
        static var s2Title: String      { s("copy_onboardingv2_s2_title", "A few things,\nbefore we start.") }
        static var s2Lede: String       { s("copy_onboardingv2_s2_lede", "What we promise you, in plain words.") }
        static var s2Card1Title: String { s("copy_onboardingv2_s2_card1_title", "No noise. No panic.") }
        static var s2Card1Body: String  { s("copy_onboardingv2_s2_card1_body", "We won't bury you in numbers. Just what matters, in words you'll actually use.") }
        static var s2Card2Title: String { s("copy_onboardingv2_s2_card2_title", "Yours, and only yours.") }
        static var s2Card2Body: String  { s("copy_onboardingv2_s2_card2_body", "Your health data stays on your phone. We never sell it. We never share it.") }
        static var s2Card3Title: String { s("copy_onboardingv2_s2_card3_title", "You're not alone in this.") }
        static var s2Card3Body: String  { s("copy_onboardingv2_s2_card3_body", "Whether you're tired, off, or hopeful, we meet you where you are.") }
        static var s2CTA: String        { s("copy_onboardingv2_s2_cta", "I'm ready") }
        static var s2Caption: String    { s("copy_onboardingv2_s2_caption", "Takes about 2 minutes") }

        // MARK: - Screen 3 — About you
        static var s3Title: String     { s("copy_onboardingv2_s3_title", "First, the basics.") }
        static var s3Lede: String      { s("copy_onboardingv2_s3_lede", "Heart, sleep, and recovery shift at every life stage. Yours are yours alone.") }
        static var s3AgeLabel: String  { s("copy_onboardingv2_s3_age_label", "How old are you?") }
        static var s3SexLabel: String  { s("copy_onboardingv2_s3_sex_label", "Sex assigned at birth") }
        static var s3Microcopy: String { s("copy_onboardingv2_s3_microcopy", "We use this only to set healthy ranges for things like resting heart rate. Never shared.") }
        static var s3CTA: String       { s("copy_onboardingv2_s3_cta", "Continue") }

        // MARK: - Screen 4 — Goals
        static var s4Title: String     { s("copy_onboardingv2_s4_title", "What brought you here?") }
        static var s4Lede: String      { s("copy_onboardingv2_s4_lede", "Pick anything that fits today. You can change it later.") }
        static var s4CTA: String       { s("copy_onboardingv2_s4_cta", "Continue") }
        static var s4ZeroCount: String { s("copy_onboardingv2_s4_zero_count", "Pick one or a few") }

        struct GoalCopy {
            let icon: String
            let title: String
            let subtitle: String
            let accent: Color
        }
        static var goalCopy: [OnbV2Goal: GoalCopy] {
            [
                .sleep:     .init(icon: "moon.fill",          title: s("copy_onboardingv2_goal_sleep_title", "Sleep better"),             subtitle: s("copy_onboardingv2_goal_sleep_sub", "Wake up rested. Stop tossing."),        accent: OnbV2.purple),
                .energy:    .init(icon: "bolt.fill",          title: s("copy_onboardingv2_goal_energy_title", "More steady energy"),      subtitle: s("copy_onboardingv2_goal_energy_sub", "Even out the highs and crashes."),      accent: OnbV2.amber),
                .training:  .init(icon: "figure.run",         title: s("copy_onboardingv2_goal_training_title", "Train smarter"),         subtitle: s("copy_onboardingv2_goal_training_sub", "Push hard, recover faster."),         accent: OnbV2.green),
                .stress:    .init(icon: "brain.head.profile", title: s("copy_onboardingv2_goal_stress_title", "Manage stress"),           subtitle: s("copy_onboardingv2_goal_stress_sub", "Notice it before it builds."),          accent: OnbV2.teal),
                .longevity: .init(icon: "heart",              title: s("copy_onboardingv2_goal_longevity_title", "Stay healthy long-term"), subtitle: s("copy_onboardingv2_goal_longevity_sub", "Spot small changes before they grow."), accent: OnbV2.rose),
                .weight:    .init(icon: "scalemass.fill",     title: s("copy_onboardingv2_goal_weight_title", "Move toward a weight goal"), subtitle: s("copy_onboardingv2_goal_weight_sub", "Without obsessing over it."),          accent: OnbV2.blue)
            ]
        }

        // MARK: - Screen 5 — Symptoms
        static var s5Title: String     { s("copy_onboardingv2_s5_title", "What's been bugging you?") }
        static var s5Lede1: String     { s("copy_onboardingv2_s5_lede1", "Pick ") }
        static var s5LedeBold: String  { s("copy_onboardingv2_s5_lede_bold", "any that ring true") }
        static var s5Lede2: String     { s("copy_onboardingv2_s5_lede2", ", you can choose more than one. We'll watch for them.") }
        static var s5CTA: String       { s("copy_onboardingv2_s5_cta", "Continue") }
        static var s5ZeroCount: String { s("copy_onboardingv2_s5_zero_count", "Pick any. Or none.") }

        struct SymptomCopy {
            let icon: String
            let label: String
        }
        static var symptomCopy: [OnbV2Symptom: SymptomCopy] {
            [
                .tiredMorning:  .init(icon: "battery.25",    label: s("copy_onboardingv2_symptom_tired_morning", "Tired mornings")),
                .restless:      .init(icon: "moon.zzz",      label: s("copy_onboardingv2_symptom_restless", "Restless nights")),
                .foggy:         .init(icon: "cloud.fog",     label: s("copy_onboardingv2_symptom_foggy", "Foggy thinking")),
                .anxious:       .init(icon: "waveform.path", label: s("copy_onboardingv2_symptom_anxious", "Nervous energy")),
                .lowMotivation: .init(icon: "cloud",         label: s("copy_onboardingv2_symptom_low_motivation", "Low motivation")),
                .sore:          .init(icon: "figure.run",    label: s("copy_onboardingv2_symptom_sore", "Slow recovery")),
                .moody:         .init(icon: "drop",          label: s("copy_onboardingv2_symptom_moody", "Mood swings")),
                .none:          .init(icon: "sparkles",      label: s("copy_onboardingv2_symptom_none", "Nothing major. Just curious."))
            ]
        }

        // MARK: - Screen 6 — Activity
        static var s6Title: String { s("copy_onboardingv2_s6_title", "How active are you, usually?") }
        static var s6Lede: String  { s("copy_onboardingv2_s6_lede", "Helps us read your recovery in context.") }
        static var s6CTA: String   { s("copy_onboardingv2_s6_cta", "Continue") }

        struct ActivityCopy {
            let icon: String
            let title: String
            let subtitle: String
        }
        static var activityCopy: [OnbV2Activity: ActivityCopy] {
            [
                .low:   .init(icon: "figure.walk", title: s("copy_onboardingv2_activity_low_title", "Mostly desk-bound"), subtitle: s("copy_onboardingv2_activity_low_sub", "A walk here and there.")),
                .mod:   .init(icon: "figure.walk", title: s("copy_onboardingv2_activity_mod_title", "On my feet"),        subtitle: s("copy_onboardingv2_activity_mod_sub", "Walks, light workouts most weeks.")),
                .high:  .init(icon: "figure.run",  title: s("copy_onboardingv2_activity_high_title", "Train regularly"),  subtitle: s("copy_onboardingv2_activity_high_sub", "3 to 5 sessions a week.")),
                .elite: .init(icon: "figure.run",  title: s("copy_onboardingv2_activity_elite_title", "Athlete"),         subtitle: s("copy_onboardingv2_activity_elite_sub", "Daily, structured training."))
            ]
        }

        // MARK: - Screen 7 — Wearable
        static var s7Title: String { s("copy_onboardingv2_s7_title", "Do you wear anything?") }
        static var s7Lede: String  { s("copy_onboardingv2_s7_lede", "We don't connect to your watch directly. We read whatever it shares with Apple Health. Most modern wearables do.") }
        static var s7CTA: String   { s("copy_onboardingv2_s7_cta", "Continue") }

        struct WearableCopy {
            let icon: String
            let title: String
            let subtitle: String
        }
        static var wearableCopy: [OnbV2Wearable: WearableCopy] {
            [
                .apple:  .init(icon: "applewatch", title: s("copy_onboardingv2_wearable_apple_title", "Apple Watch"),          subtitle: s("copy_onboardingv2_wearable_apple_sub", "Best fit. Deepest signal.")),
                .whoop:  .init(icon: "heart",      title: s("copy_onboardingv2_wearable_whoop_title", "Whoop"),                subtitle: s("copy_onboardingv2_wearable_whoop_sub", "Strain, sleep, recovery.")),
                .oura:   .init(icon: "circle",     title: s("copy_onboardingv2_wearable_oura_title", "Oura Ring"),             subtitle: s("copy_onboardingv2_wearable_oura_sub", "Sleep, HRV, body temp.")),
                .garmin: .init(icon: "applewatch", title: s("copy_onboardingv2_wearable_garmin_title", "Garmin / Polar"),     subtitle: s("copy_onboardingv2_wearable_garmin_sub", "Training-focused devices.")),
                .fitbit: .init(icon: "applewatch", title: s("copy_onboardingv2_wearable_fitbit_title", "Fitbit"),             subtitle: s("copy_onboardingv2_wearable_fitbit_sub", "Steps, sleep, heart rate.")),
                .other:  .init(icon: "sparkles",   title: s("copy_onboardingv2_wearable_other_title", "Something else"),       subtitle: s("copy_onboardingv2_wearable_other_sub", "If it syncs to Apple Health, we'll read it.")),
                .none:   .init(icon: "iphone",     title: s("copy_onboardingv2_wearable_none_title", "Just my iPhone for now"), subtitle: s("copy_onboardingv2_wearable_none_sub", "That's plenty to start."))
            ]
        }

        // MARK: - Screen 8 — Bridge
        static var s8Title: String       { s("copy_onboardingv2_s8_title", "Now Laso can read\nyour story.") }
        static var s8DefaultLede: String { s("copy_onboardingv2_s8_default_lede", "We'll learn the rhythms only you have.") }
        static var s8PrivacyChip: String { s("copy_onboardingv2_s8_privacy_chip", "Your data never leaves your phone.") }
        static var s8CTA: String         { s("copy_onboardingv2_s8_cta", "Connect Apple Health") }

        static func bridgeLede(for goal: OnbV2Goal?) -> String {
            switch goal {
            case .sleep:     return s("copy_onboardingv2_bridge_lede_sleep", "We'll learn how your nights shape your days.")
            case .energy:    return s("copy_onboardingv2_bridge_lede_energy", "We'll find where your energy goes.")
            case .training:  return s("copy_onboardingv2_bridge_lede_training", "We'll see how you push and how you recover.")
            case .stress:    return s("copy_onboardingv2_bridge_lede_stress", "We'll catch the strain before you feel it.")
            case .longevity: return s("copy_onboardingv2_bridge_lede_longevity", "We'll track the small shifts that add up.")
            case .weight:    return s("copy_onboardingv2_bridge_lede_weight", "We'll connect what's beyond the scale.")
            case .none:      return s8DefaultLede
            }
        }

        // MARK: - Screen 10 — Scan
        static var s10Eyebrow: String     { s("copy_onboardingv2_s10_eyebrow", "READING") }
        static var s10Title: String       { s("copy_onboardingv2_s10_title", "Laso is listening to your body.") }
        static var s10Found1: String      { s("copy_onboardingv2_s10_found1", "Heart rate") }
        static var s10Found2: String      { s("copy_onboardingv2_s10_found2", "Sleep cycles") }
        static var s10Found3: String      { s("copy_onboardingv2_s10_found3", "Workouts") }
        static var s10Found4: String      { s("copy_onboardingv2_s10_found4", "HRV") }
        static var s10Found5: String      { s("copy_onboardingv2_s10_found5", "Recovery patterns") }
        static var s10NotRecorded: String { s("copy_onboardingv2_s10_not_recorded", "Not recorded") }
        static func s10Status(_ pct: Int, longestDuration: String?) -> String {
            if let longestDuration {
                return String(format: s("copy_onboardingv2_s10_status_history", "Reading %1$@ of history · %2$d%%"), longestDuration, pct)
            }
            return String(format: s("copy_onboardingv2_s10_status_default", "Reading from Apple Health · %d%%"), pct)
        }

        // MARK: - Screen 11 — Heart reveal
        static var s11Eyebrow: String     { s("copy_onboardingv2_s11_eyebrow", "HEART") }
        static var s11TitleHasData: String { s("copy_onboardingv2_s11_title_has_data", "Your heart beats steadily.") }
        static var s11TitleEmpty: String   { s("copy_onboardingv2_s11_title_empty", "We'll learn your heart's rhythm.") }
        static var s11BodyHasData: String  { s("copy_onboardingv2_s11_body_has_data", "We'll watch for changes. They often mean something.") }
        static var s11BodyEmpty: String    { s("copy_onboardingv2_s11_body_empty", "No resting heart rate recorded yet. Wear your Apple Watch and we'll start tracking from your next quiet moment.") }
        static var s11Unit: String         { s("copy_onboardingv2_s11_unit", "BPM") }
        static var s11CTA: String          { s("copy_onboardingv2_s11_cta", "Tell me more") }
        static func s11Footnote(months: Int) -> String {
            String(format: s("copy_onboardingv2_s11_footnote", "Based on %@ of resting heart rate data"), durationPhrase(months: months))
        }

        // MARK: - Screen 12 — Sleep reveal
        static var s12Eyebrow: String      { s("copy_onboardingv2_s12_eyebrow", "SLEEP") }
        static var s12TitleHasData: String { s("copy_onboardingv2_s12_title_has_data", "Your body is asking for more.") }
        static var s12TitleEmpty: String   { s("copy_onboardingv2_s12_title_empty", "We'll learn how you sleep.") }
        static var s12BodyPrefix: String   { s("copy_onboardingv2_s12_body_prefix", "You've been averaging ") }
        static var s12BodySuffix: String   { s("copy_onboardingv2_s12_body_suffix", ". Most adults need 7 to 8. We'll watch the gap and help you close it.") }
        static var s12BodyEmpty: String    { s("copy_onboardingv2_s12_body_empty", "No sleep data recorded yet. Wear your Apple Watch to bed and we'll learn your nightly rhythm.") }
        static var s12CTA: String          { s("copy_onboardingv2_s12_cta", "What else?") }
        static func s12Footnote(months: Int) -> String {
            String(format: s("copy_onboardingv2_s12_footnote", "%@ of nightly data"), durationPhrase(months: months))
        }

        // MARK: - Screen 13 — HRV reveal
        static var s13EyebrowPattern: String { s("copy_onboardingv2_s13_eyebrow_pattern", "A PATTERN WE NOTICED") }
        static var s13EyebrowEmpty: String   { s("copy_onboardingv2_s13_eyebrow_empty", "STILL LEARNING") }
        static var s13TitleEmpty: String     { s("copy_onboardingv2_s13_title_empty", "Your patterns are still emerging.") }
        static var s13BodyBold: String       { s("copy_onboardingv2_s13_body_bold", "Most people miss it.") }
        static var s13BodySuffix: String     { s("copy_onboardingv2_s13_body_suffix", " We won't.") }
        static var s13BodyEmpty: String      { s("copy_onboardingv2_s13_body_empty", "Not enough HRV data yet to spot a clear weekly pattern. Keep wearing your watch overnight and we'll surface yours within a couple of weeks.") }
        static var s13CTA: String            { s("copy_onboardingv2_s13_cta", "Show me the rest") }
        static func s13Title(weekday: String) -> String {
            String(format: s("copy_onboardingv2_s13_title", "%@s land harder than the rest."), weekday)
        }
        static func s13BodyPrefix(weekday: String) -> String {
            String(format: s("copy_onboardingv2_s13_body_prefix", "Your HRV dips most %@ nights, a quiet sign of stress catching up. "), weekday)
        }
        static func s13Footnote(weeks: Int) -> String {
            let unit = weeks == 1 ? "week" : "weeks"
            return String(format: s("copy_onboardingv2_s13_footnote", "Pattern detected across %@"), "\(weeks) \(unit)")
        }

        // MARK: - Screen 14 — Preview
        static var s14Eyebrow: String { s("copy_onboardingv2_s14_eyebrow", "YOUR FIRST WEEK") }
        static var s14Title: String   { s("copy_onboardingv2_s14_title", "Here's what comes next.") }
        static var s14Lede: String    { s("copy_onboardingv2_s14_lede", "A gentle plan for your first 7 days with Laso.") }
        static var s14CTA: String     { s("copy_onboardingv2_s14_cta", "Continue") }

        struct PreviewDay {
            let day: Int
            let title: String
            let body: String
        }
        static var previewDays: [PreviewDay] {
            [
                .init(day: 1, title: s("copy_onboardingv2_preview_d1_title", "Your baseline"),           body: s("copy_onboardingv2_preview_d1_body", "We set what 'normal' looks like for you.")),
                .init(day: 2, title: s("copy_onboardingv2_preview_d2_title", "Your sleep window"),        body: s("copy_onboardingv2_preview_d2_body", "When your body actually wants to rest.")),
                .init(day: 3, title: s("copy_onboardingv2_preview_d3_title", "Stress signals"),           body: s("copy_onboardingv2_preview_d3_body", "The ones your body has been hiding.")),
                .init(day: 5, title: s("copy_onboardingv2_preview_d5_title", "Recovery rhythm"),          body: s("copy_onboardingv2_preview_d5_body", "How long it really takes to bounce back.")),
                .init(day: 7, title: s("copy_onboardingv2_preview_d7_title", "Your first weekly read"),   body: s("copy_onboardingv2_preview_d7_body", "What changed. What it means. What to try."))
            ]
        }

        // MARK: - Screen 15 — Sign in
        static var s15Title: String    { s("copy_onboardingv2_s15_title", "Save your read.") }
        static var s15Lede: String     { s("copy_onboardingv2_s15_lede", "Sign in so your insights stay with you — across iPhone, iPad, and Watch. No password to remember.") }
        static var s15CTA: String      { s("copy_onboardingv2_s15_cta", "Sign in with Apple") }
        static var s15Footnote: String { s("copy_onboardingv2_s15_footnote", "We never see your email. Apple keeps it private.") }

        // MARK: - Screen 16 — Paywall
        static var s16Eyebrow: String      { s("copy_onboardingv2_s16_eyebrow", "YOUR LASO PLAN") }
        // Insight-driven framing: sell the next pattern, not feature bullets.
        static var s16Title: String        { s("copy_onboardingv2_s16_title", "You unlocked your first pattern.\nWant a new one every week?") }
        static var s16AnnualTitle: String  { s("copy_onboardingv2_s16_annual_title", "Annual") }
        static var s16MonthlyTitle: String { s("copy_onboardingv2_s16_monthly_title", "Monthly") }
        static var s16MonthlySub: String   { s("copy_onboardingv2_s16_monthly_sub", "Cancel anytime") }
        static var s16CTA: String          { s("copy_onboardingv2_s16_cta", "Start free trial") }
        static var s16CTAFallback: String  { s("copy_onboardingv2_s16_cta_fallback", "Continue") }
        static var s16Restore: String      { s("copy_onboardingv2_s16_restore", "Restore") }
        static var s16Terms: String        { s("copy_onboardingv2_s16_terms", "Terms") }
        static var s16Privacy: String      { s("copy_onboardingv2_s16_privacy", "Privacy") }
        static var s16NoProducts: String   { s("copy_onboardingv2_s16_no_products", "Loading plans...") }
        static func s16AnnualSub(perMonth: String, trialDays: String) -> String {
            String(format: s("copy_onboardingv2_s16_annual_sub", "That's about %1$@/month · %2$@-day free trial"), perMonth, trialDays)
        }

        struct WatchListRow: Identifiable {
            let id: String
            let icon: String
            let color: Color
            let label: String
            let sub: String
        }
        // Generic sub line for a goal-derived or symptom-derived watch row. The
        // user's own goal / symptom label is the row title, so the sub stays a
        // short shared reassurance rather than restating the metric.
        static var watchRowGoalSub: String   { s("copy_onboardingv2_watch_goal_sub", "We keep an eye on this for you, every day.") }
        // Worst-weekday row: the one concrete pattern the read already surfaced.
        static func watchWeekdayLabel(weekday: String) -> String {
            String(format: s("copy_onboardingv2_watch_weekday_label", "Your %@ dip"), weekday)
        }
        static var watchWeekdaySub: String   { s("copy_onboardingv2_watch_weekday_sub", "The day your recovery runs lowest.") }
        // Always-on closing row: the weekly cadence the subscription buys.
        static var watchWeeklyLabel: String  { s("copy_onboardingv2_watch_weekly_label", "A fresh pattern every week") }
        static var watchWeeklySub: String    { s("copy_onboardingv2_watch_weekly_sub", "Quiet alerts the moment something shifts.") }

        // MARK: - Screen 16 — Trial timeline
        static var s16TimelineToday: String  { s("copy_onboardingv2_s16_timeline_today", "Today") }
        static var s16TimelineTodaySub: String { s("copy_onboardingv2_s16_timeline_today_sub", "Full access opens.") }
        static var s16TimelineRemind: String { s("copy_onboardingv2_s16_timeline_remind", "We remind you") }
        static var s16TimelineRemindSub: String { s("copy_onboardingv2_s16_timeline_remind_sub", "Two days before the trial ends.") }
        static var s16TimelineRenew: String  { s("copy_onboardingv2_s16_timeline_renew", "Renews") }
        static var s16TimelineRenewSub: String { s("copy_onboardingv2_s16_timeline_renew_sub", "Cancel anytime before this.") }
        static func s16TimelineDay(_ day: Int) -> String {
            day == 0 ? s("copy_onboardingv2_s16_timeline_day0", "Day 1") : String(format: s("copy_onboardingv2_s16_timeline_dayn", "Day %d"), day + 1)
        }

        // MARK: - Metric phrases (used to build claim + watch copy)
        /// The "claim" half of the prediction, the suspected driver in plain
        /// words. Keyed by PredictionMetric so Core types stay out of Copy.
        static func metricClaimPhrase(_ metric: PredictionMetric) -> String {
            switch metric {
            case .sleepDuration:        return s("copy_onboardingv2_metric_claim_sleep", "shorter nights")
            case .heartRateVariability: return s("copy_onboardingv2_metric_claim_hrv", "lower recovery")
            case .restingHeartRate:     return s("copy_onboardingv2_metric_claim_rhr", "a higher resting heart rate")
            }
        }
        /// Short label for the metric we will keep watching (refuted pivot and
        /// side discoveries).
        static func metricWatchLabel(_ metric: PredictionMetric) -> String {
            switch metric {
            case .sleepDuration:        return s("copy_onboardingv2_metric_label_sleep", "sleep")
            case .heartRateVariability: return s("copy_onboardingv2_metric_label_hrv", "recovery")
            case .restingHeartRate:     return s("copy_onboardingv2_metric_label_rhr", "resting heart rate")
            }
        }

        // MARK: - Prediction (pre-registered claim screen)
        static var predictionEyebrow: String { s("copy_onboardingv2_prediction_eyebrow", "YOUR FIRST CHECK") }
        static var predictionCTA: String     { s("copy_onboardingv2_prediction_cta", "Let's find out") }
        static var predictionFootnote: String { s("copy_onboardingv2_prediction_footnote", "We decide this from your own data. Not a guess.") }
        /// The pre-registered claim, built from the user's own goal + symptom
        /// words. No timing promise: the data branch decides when the answer is
        /// ready.
        static func predictionTitle(claim: String, outcome: String) -> String {
            String(format: s("copy_onboardingv2_prediction_title", "We will check the link between %1$@ and your %2$@."), claim, outcome)
        }

        // MARK: - Verdict (rich branch)
        static var verdictConfirmedEyebrow: String { s("copy_onboardingv2_verdict_confirmed_eyebrow", "YOUR ANSWER") }
        static var verdictRefutedEyebrow: String   { s("copy_onboardingv2_verdict_refuted_eyebrow", "GOOD NEWS") }
        static var verdictInconclusiveEyebrow: String { s("copy_onboardingv2_verdict_inconclusive_eyebrow", "ALMOST THERE") }
        static var verdictCTA: String { s("copy_onboardingv2_verdict_cta", "Continue") }
        /// Confirmed: the claim held. `metric` is the driver we watch,
        /// `magnitude` a banded phrase, `weekday` the day it lands hardest,
        /// `outcome` the user's own words. Phrasing stays neutral so it reads
        /// right whether the metric goes up or down.
        static func verdictConfirmedBody(metric: String, magnitude: String, weekday: String, outcome: String) -> String {
            String(format: s("copy_onboardingv2_verdict_confirmed_body", "On %1$@s your %2$@ shifts by %3$@, and that lines up with your %4$@. Now you know where to look."), weekday, metric, magnitude, outcome)
        }
        static var verdictConfirmedTitle: String { s("copy_onboardingv2_verdict_confirmed_title", "You were right.") }
        /// Refuted: the predicted cause is not the driver. Honest pivot to the
        /// metric we will keep watching.
        static func verdictRefutedBody(outcome: String, watch: String) -> String {
            String(format: s("copy_onboardingv2_verdict_refuted_body", "Your %1$@ did not line up with the data here. That rules out a dead end. We will keep watching your %2$@ instead."), outcome, watch)
        }
        static var verdictRefutedTitle: String { s("copy_onboardingv2_verdict_refuted_title", "We can rule that out.") }
        /// Inconclusive in the rich branch: enough data to run, not enough to
        /// be sure yet. `nights` is verdict.nightsRemaining.
        static func verdictInconclusiveBody(nights: Int) -> String {
            let unit = nights == 1 ? s("copy_onboardingv2_night_singular", "night") : s("copy_onboardingv2_night_plural", "nights")
            return String(format: s("copy_onboardingv2_verdict_inconclusive_body", "The pattern is forming but not certain. About %1$d more %2$@ and we will know for sure."), nights, unit)
        }
        static var verdictInconclusiveTitle: String { s("copy_onboardingv2_verdict_inconclusive_title", "We are close.") }
        /// Mandatory label for side discoveries. They never replace the answer.
        static func verdictSideDiscovery(metric: String, weekday: String) -> String {
            String(format: s("copy_onboardingv2_verdict_side_discovery", "While checking, we also noticed your %1$@ shifts most on %2$@s."), metric, weekday)
        }

        // MARK: - Cliffhanger (sparse branch)
        static var cliffhangerEyebrow: String { s("copy_onboardingv2_cliffhanger_eyebrow", "ALMOST READY") }
        static var cliffhangerTitle: String   { s("copy_onboardingv2_cliffhanger_title", "Your answer is on its way.") }
        static func cliffhangerBody(nights: Int) -> String {
            let unit = nights == 1 ? s("copy_onboardingv2_night_singular", "night") : s("copy_onboardingv2_night_plural", "nights")
            return String(format: s("copy_onboardingv2_cliffhanger_body", "We have a strong start. About %1$d more %2$@ of sleep and we can give you a real answer."), nights, unit)
        }
        static var cliffhangerNotifyTitle: String { s("copy_onboardingv2_cliffhanger_notify_title", "Want us to tell you the moment your answer is ready?") }
        static var cliffhangerNotifyYes: String   { s("copy_onboardingv2_cliffhanger_notify_yes", "Yes, tell me") }
        static var cliffhangerSkip: String        { s("copy_onboardingv2_cliffhanger_skip", "Not now") }

        // MARK: - Journal first (denied branch)
        static var journalFirstEyebrow: String { s("copy_onboardingv2_journal_first_eyebrow", "ANOTHER WAY IN") }
        static var journalFirstTitle: String   { s("copy_onboardingv2_journal_first_title", "You can still get answers.") }
        static var journalFirstBody: String    { s("copy_onboardingv2_journal_first_body", "Even without Health data, a quick morning check in builds your picture. Log how you feel and we will find the patterns with you.") }
        static var journalFirstCTA: String     { s("copy_onboardingv2_journal_first_cta", "Start with a check in") }

        // MARK: - Verdict magnitude band words
        /// Turns a banded magnitude into copy. Hour bands ignore the raw value
        /// so the screen never shows false precision; minute / percent / bpm
        /// bands carry the rounded value.
        static func bandPhrase(band: VerdictMagnitude.Band, value: Int) -> String {
            switch band {
            case .roughlyAnHour: return s("copy_onboardingv2_band_roughly_an_hour", "roughly an hour")
            case .overAnHour:    return s("copy_onboardingv2_band_over_an_hour", "more than an hour")
            case .minutes:       return String(format: s("copy_onboardingv2_band_minutes", "about %d minutes"), value)
            case .percent:       return String(format: s("copy_onboardingv2_band_percent", "about %d percent"), value)
            case .bpm:           return String(format: s("copy_onboardingv2_band_bpm", "about %d bpm"), value)
            }
        }

        // MARK: - Done
        static var sDoneTitle: String { s("copy_onboardingv2_done_title", "Welcome to Laso.") }
        static var sDoneLede: String  { s("copy_onboardingv2_done_lede", "Your first insights are ready. Let's take a look.") }
        static var sDoneCTA: String   { s("copy_onboardingv2_done_cta", "Open my dashboard") }

        // MARK: - Helpers

        /// Builds a human duration phrase ("3 years", "1y 2mo", "5 months")
        /// from a month count. Unit words are grammar, not brand copy, so they
        /// stay inline rather than living in Remote Config.
        private static func durationPhrase(months: Int) -> String {
            if months >= 12 {
                let years = months / 12
                let rem = months % 12
                if rem == 0 { return "\(years) year\(years == 1 ? "" : "s")" }
                return "\(years)y \(rem)mo"
            }
            return "\(months) month\(months == 1 ? "" : "s")"
        }
    }
}

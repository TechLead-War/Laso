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
        // One idea: the user's own Vitality Age is the hero. The name leads in
        // blue, one plain explainer line sits under it, and the orb plus a single
        // first-person CTA carry the rest.
        static var s1Title: String { s("copy_onboardingv2_s1_title", "Vitality Age.") }
        static var s1Lede: String  { s("copy_onboardingv2_s1_lede", "Your watch already knows how old your body really is. We read it in 30 seconds, then tell you the one thing to do next.") }
        static var s1CTA: String   { s("copy_onboardingv2_s1_cta", "See my Vitality Age") }

        // MARK: - Screen 3 — About you
        static var s3Eyebrow: String   { s("copy_onboardingv2_s3_eyebrow", "ABOUT YOU") }
        static var s3Title: String     { s("copy_onboardingv2_s3_title", "First, the basics.") }
        static var s3Lede: String      { s("copy_onboardingv2_s3_lede", "Heart, sleep, and recovery shift at every life stage. Yours are yours alone.") }
        static var s3AgeLabel: String  { s("copy_onboardingv2_s3_age_label", "How old are you?") }
        static var s3SexLabel: String  { s("copy_onboardingv2_s3_sex_label", "Sex assigned at birth") }
        static var s3Microcopy: String { s("copy_onboardingv2_s3_microcopy", "We use this only to set healthy ranges for things like resting heart rate. Never shared.") }
        static var s3CTA: String       { s("copy_onboardingv2_s3_cta", "Continue") }

        // MARK: - Screen 4 — Goals
        static var s4Eyebrow: String     { s("copy_onboardingv2_s4_eyebrow", "YOUR COMMITMENT") }
        static var s4Title: String       { s("copy_onboardingv2_s4_title", "What are you ready to focus on?") }
        // The word inside s4Title that renders blue. Must appear verbatim in s4Title.
        static var s4TitleAccent: String { s("copy_onboardingv2_s4_title_accent", "focus") }
        static var s4Lede: String        { s("copy_onboardingv2_s4_lede", "Choose what you actually want to work on. Pick as many as fit.") }
        static var s4CTA: String       { s("copy_onboardingv2_s4_cta", "Continue") }
        static var s4ZeroCount: String { s("copy_onboardingv2_s4_zero_count", "Pick one or a few") }

        struct GoalCopy {
            let icon: String
            let title: String
            let subtitle: String
            let accent: Color
            // Forward-looking promise for the paywall's no-insights fallback: when
            // the scan found no data yet, sell the question we'll answer, not a
            // result we don't have.
            let chase: String
        }
        static var goalCopy: [OnbV2Goal: GoalCopy] {
            [
                .sleep:     .init(icon: "moon.fill",          title: s("copy_onboardingv2_goal_sleep_title", "Sleep better"),             subtitle: s("copy_onboardingv2_goal_sleep_sub", "Wake up rested. Stop tossing."),        accent: OnbV2.purple, chase: s("copy_onboardingv2_goal_sleep_chase", "Find what's cutting your deep sleep")),
                .energy:    .init(icon: "bolt.fill",          title: s("copy_onboardingv2_goal_energy_title", "More steady energy"),      subtitle: s("copy_onboardingv2_goal_energy_sub", "Even out the highs and crashes."),      accent: OnbV2.amber, chase: s("copy_onboardingv2_goal_energy_chase", "Catch what drains you by afternoon")),
                .training:  .init(icon: "figure.run",         title: s("copy_onboardingv2_goal_training_title", "Train smarter"),         subtitle: s("copy_onboardingv2_goal_training_sub", "Push hard, recover faster."),         accent: OnbV2.green, chase: s("copy_onboardingv2_goal_training_chase", "Learn when you're ready to push")),
                .stress:    .init(icon: "brain.head.profile", title: s("copy_onboardingv2_goal_stress_title", "Manage stress"),           subtitle: s("copy_onboardingv2_goal_stress_sub", "Notice it before it builds."),          accent: OnbV2.teal, chase: s("copy_onboardingv2_goal_stress_chase", "Spot what's quietly winding you up")),
                .longevity: .init(icon: "heart",              title: s("copy_onboardingv2_goal_longevity_title", "Stay healthy long-term"), subtitle: s("copy_onboardingv2_goal_longevity_sub", "Spot small changes before they grow."), accent: OnbV2.rose, chase: s("copy_onboardingv2_goal_longevity_chase", "Track the slow shifts before they grow")),
                .weight:    .init(icon: "scalemass.fill",     title: s("copy_onboardingv2_goal_weight_title", "Move toward a weight goal"), subtitle: s("copy_onboardingv2_goal_weight_sub", "Without obsessing over it."),          accent: OnbV2.blue, chase: s("copy_onboardingv2_goal_weight_chase", "Find what's stalling your progress"))
            ]
        }

        // MARK: - Screen 5 — Symptoms
        static var s5Eyebrow: String     { s("copy_onboardingv2_s5_eyebrow", "BUILD YOUR READ") }
        static var s5Title: String       { s("copy_onboardingv2_s5_title", "What's been bugging you?") }
        // The word inside s5Title that renders rose. Must appear verbatim in s5Title.
        static var s5TitleAccent: String { s("copy_onboardingv2_s5_title_accent", "bugging") }
        static var s5Lede1: String     { s("copy_onboardingv2_s5_lede1", "Pick ") }
        static var s5LedeBold: String  { s("copy_onboardingv2_s5_lede_bold", "any that ring true") }
        static var s5Lede2: String     { s("copy_onboardingv2_s5_lede2", ", you can choose more than one. We'll watch for them.") }
        static var s5CTA: String       { s("copy_onboardingv2_s5_cta", "Continue") }
        static var s5ZeroCount: String { s("copy_onboardingv2_s5_zero_count", "Pick any. Or none.") }
        // Count chip shown on the multi-select screens once at least one is picked.
        static func countSelected(_ n: Int) -> String { String(format: s("copy_onboardingv2_count_selected", "%d selected"), n) }

        struct SymptomCopy {
            let icon: String
            let label: String
            // Paywall no-insights promise; see GoalCopy.chase.
            let chase: String
        }
        static var symptomCopy: [OnbV2Symptom: SymptomCopy] {
            [
                .tiredMorning:  .init(icon: "battery.25",    label: s("copy_onboardingv2_symptom_tired_morning", "Tired mornings"), chase: s("copy_onboardingv2_symptom_tired_morning_chase", "Find why your mornings feel heavy")),
                .restless:      .init(icon: "moon.zzz",      label: s("copy_onboardingv2_symptom_restless", "Restless nights"), chase: s("copy_onboardingv2_symptom_restless_chase", "Find what's breaking your sleep")),
                .foggy:         .init(icon: "cloud.fog",     label: s("copy_onboardingv2_symptom_foggy", "Foggy thinking"), chase: s("copy_onboardingv2_symptom_foggy_chase", "Find what's clouding your focus")),
                .anxious:       .init(icon: "waveform.path", label: s("copy_onboardingv2_symptom_anxious", "Anxiety/restlessness"), chase: s("copy_onboardingv2_symptom_anxious_chase", "Find what keeps you on edge")),
                .lowMotivation: .init(icon: "cloud",         label: s("copy_onboardingv2_symptom_low_motivation", "Low motivation"), chase: s("copy_onboardingv2_symptom_low_motivation_chase", "Find what's draining your drive")),
                .sore:          .init(icon: "figure.run",    label: s("copy_onboardingv2_symptom_sore", "Slow recovery"), chase: s("copy_onboardingv2_symptom_sore_chase", "Find what's slowing your recovery")),
                .moody:         .init(icon: "drop",          label: s("copy_onboardingv2_symptom_moody", "Mood swings"), chase: s("copy_onboardingv2_symptom_moody_chase", "Find what's swinging your mood")),
                .none:          .init(icon: "sparkles",      label: s("copy_onboardingv2_symptom_none", "Nothing major. Just curious."), chase: s("copy_onboardingv2_symptom_none_chase", "We'll surface whatever stands out"))
            ]
        }

        // MARK: - Screen 6 — Bridge
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
        static var s10Found1: String      { s("copy_onboardingv2_s10_found1", "Your true resting rate") }
        static var s10Found2: String      { s("copy_onboardingv2_s10_found2", "Your deepest sleep window") }
        static var s10Found3: String      { s("copy_onboardingv2_s10_found3", "How hard you push") }
        static var s10Found4: String      { s("copy_onboardingv2_s10_found4", "When stress catches up") }
        static var s10Found5: String      { s("copy_onboardingv2_s10_found5", "When you're really recovered") }
        static var s10NotRecorded: String { s("copy_onboardingv2_s10_not_recorded", "Not recorded") }
        static func s10Status(_ pct: Int, longestDuration: String?) -> String {
            if let longestDuration {
                return String(format: s("copy_onboardingv2_s10_status_history", "Reading %1$@ of history · %2$d%%"), longestDuration, pct)
            }
            return String(format: s("copy_onboardingv2_s10_status_default", "Reading from Apple Health · %d%%"), pct)
        }

        // MARK: - Screen 11 — Heart reveal
        static var s11Eyebrow: String     { s("copy_onboardingv2_s11_eyebrow", "HEART") }
        static var s11TitleHasData: String { s("copy_onboardingv2_s11_title_has_data", "This is your\nheart, right now.") }
        static var s11TitleEmpty: String   { s("copy_onboardingv2_s11_title_empty", "We'll learn your heart's rhythm.") }
        // Heart reveal body adapts to the resting-HR band (anchors live in
        // BiologicalAgeConfig), so an elevated rate never reads "quiet and strong".
        static var s11BodyAthletic: String { s("copy_onboardingv2_s11_body_athletic", "Impressively low. That is the resting rate of a well trained heart, and now it is your baseline.") }
        static var s11BodyNormal: String   { s("copy_onboardingv2_s11_body_normal", "Quiet and strong. This is the first time you have seen your own baseline in one place.") }
        static var s11BodyElevated: String { s("copy_onboardingv2_s11_body_elevated", "A little warm at rest. Nothing alarming, and now you have a baseline to watch it from.") }
        static var s11BodyEmpty: String    { s("copy_onboardingv2_s11_body_empty", "No resting heart rate recorded yet. Wear your Apple Watch and we'll start tracking from your next quiet moment.") }
        static var s11Unit: String         { s("copy_onboardingv2_s11_unit", "BPM") }
        static var s11SubAthletic: String { s("copy_onboardingv2_s11_sub_athletic", "low, strong, athletic") }
        static var s11SubNormal: String   { s("copy_onboardingv2_s11_sub_normal", "resting, calm, steady") }
        static var s11SubElevated: String { s("copy_onboardingv2_s11_sub_elevated", "a little high at rest") }
        static var s11CTA: String          { s("copy_onboardingv2_s11_cta", "Tell me more") }
        static func s11Footnote(months: Int) -> String {
            String(format: s("copy_onboardingv2_s11_footnote", "Based on %@ of resting heart rate data"), durationPhrase(months: months))
        }

        // MARK: - Screen 12 — Sleep reveal
        static var s12Eyebrow: String      { s("copy_onboardingv2_s12_eyebrow", "SLEEP") }
        // Sleep title is dynamic: the gap to the goal, with the gap phrase tinted.
        // A sleeper already at the goal gets the on-target variant instead.
        static func s12TitleGap(gap: String) -> String {
            String(format: s("copy_onboardingv2_s12_title_gap", "You are %@ short of where you want to be."), gap)
        }
        static var s12TitleOnTarget: String { s("copy_onboardingv2_s12_title_on_target", "You are right where you want to be.") }
        /// Gap phrase ("48 minutes", "1h 20m", "2 hours"). Unit words are grammar.
        static func sleepGapPhrase(minutes: Int) -> String {
            if minutes < 60 { return "\(minutes) \(minutes == 1 ? "minute" : "minutes")" }
            let h = minutes / 60, m = minutes % 60
            if m == 0 { return "\(h) \(h == 1 ? "hour" : "hours")" }
            return "\(h)h \(m)m"
        }
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

        // MARK: - Vitality Age reveal
        static var revealHeader: String { s("copy_onboardingv2_reveal_header", "YOUR VITALITY AGE") }
        static var revealYearsUnit: String { s("copy_onboardingv2_reveal_years_unit", "years") }
        static var revealPayoffOnAge: String { s("copy_onboardingv2_reveal_payoff_on_age", "right on your real age") }
        static func revealPayoffYounger(_ years: Int) -> String { String(format: s("copy_onboardingv2_reveal_payoff_younger", "%d years younger"), years) }
        static func revealPayoffOlder(_ years: Int) -> String { String(format: s("copy_onboardingv2_reveal_payoff_older", "%d years older"), years) }
        static func revealThanRealAge(_ age: Int) -> String { String(format: s("copy_onboardingv2_reveal_than_real_age", "than your real age of %d"), age) }
        static var revealSubYounger: String { s("copy_onboardingv2_reveal_sub_younger", "Now let's make it even younger.") }
        static var revealSubOlder: String { s("copy_onboardingv2_reveal_sub_older", "Let's start bringing this down.") }
        static var revealOrbYourAge: String { s("copy_onboardingv2_reveal_orb_your_age", "YOUR AGE") }
        static var revealOrbCalculating: String { s("copy_onboardingv2_reveal_orb_calculating", "CALCULATING") }
        static var revealOrbYears: String { s("copy_onboardingv2_reveal_orb_years", "YEARS") }
        static var revealCTA: String { s("copy_onboardingv2_reveal_cta", "Continue") }
        // Rich branch: caption above the CTA that seeds the morning notification.
        static var notifPrimer: String { s("copy_onboardingv2_notif_primer", "Tomorrow morning we will tell you how tonight went.") }

        // Next-step card on the reveal: the pathway starts with the user's
        // weakest metric. Keys match the producer names emitted by
        // VitalityScorer.onboardingEstimate ("RESTING HR", "HRV", ...).
        static var revealNextStepHeader: String { s("copy_onboardingv2_reveal_next_step_header", "YOUR NEXT STEP") }
        static var revealNextStepMaintain: String { s("copy_onboardingv2_reveal_next_step_maintain", "Everything looks strong. Tonight: keep your usual bedtime and we will confirm it tomorrow.") }
        static func revealNextStep(forMetric name: String) -> String {
            switch name {
            case "RESTING HR": return s("copy_onboardingv2_reveal_next_step_rhr", "Your resting heart rate is your weakest link. Tonight: a 10 minute wind down walk after dinner.")
            case "HRV": return s("copy_onboardingv2_reveal_next_step_hrv", "Your HRV is your weakest link. Tonight: screens off 30 minutes before bed.")
            case "STEPS": return s("copy_onboardingv2_reveal_next_step_steps", "Your step count is your weakest link. Today: a 15 minute walk after lunch.")
            case "VO2 MAX": return s("copy_onboardingv2_reveal_next_step_vo2", "Your fitness level is your weakest link. This week: two brisk 20 minute walks.")
            case "EXERCISE": return s("copy_onboardingv2_reveal_next_step_exercise", "Your exercise minutes are your weakest link. Today: 20 minutes of anything that raises your heart rate.")
            case "WALK SPEED": return s("copy_onboardingv2_reveal_next_step_walk", "Your walking pace is your weakest link. Today: walk your usual route slightly faster.")
            default: return s("copy_onboardingv2_reveal_next_step_generic", "Tonight: screens off 30 minutes before bed. Small steps move your Vitality Age.")
            }
        }

        // MARK: - Screen 15 — Sign in
        static var s15Title: String    { s("copy_onboardingv2_s15_title", "Save your read.") }
        static var s15Lede: String     { s("copy_onboardingv2_s15_lede", "Sign in so your insights stay with you across iPhone, iPad, and Watch. No password to remember.") }
        static var s15CTA: String      { s("copy_onboardingv2_s15_cta", "Sign in with Apple") }
        static var s15Footnote: String { s("copy_onboardingv2_s15_footnote", "We never see your email. Apple keeps it private.") }

        // MARK: - Screen 16 — Paywall
        static var s16Eyebrow: String      { s("copy_onboardingv2_s16_eyebrow", "KEEP YOUR PATHWAY") }
        static var watchPathwayLabel: String { s("copy_onboardingv2_watch_pathway_label", "A next step every morning") }
        static var watchPathwaySub: String { s("copy_onboardingv2_watch_pathway_sub", "We tell you what to do and prove it worked the next day.") }
        // Headline keyed to the vitality delta band. Deltas within 2 years fold
        // into the "same" variant, which also avoids the singular year problem
        // in the templates.
        static func s16TitleYounger(_ years: Int) -> String {
            String(format: s("copy_onboardingv2_s16_title_younger", "Your body is %d years younger than your age. Keep it that way."), years)
        }
        static func s16TitleOlder(_ years: Int) -> String {
            String(format: s("copy_onboardingv2_s16_title_older", "Your body is %d years older than your age. Your plan closes the gap."), years)
        }
        static var s16TitleSame: String    { s("copy_onboardingv2_s16_title_same", "Your body matches your age. Your plan keeps you ahead.") }
        // Shown instead of the delta headlines when the scan found no data: don't
        // claim a read we didn't get; sell the hunt built on what they told us.
        static var s16TitleNoData: String  { s("copy_onboardingv2_s16_title_no_data", "You told us what matters.\nNow let's go find it.") }
        static var s16AnnualTitle: String  { s("copy_onboardingv2_s16_annual_title", "Annual") }
        static var s16MonthlyTitle: String { s("copy_onboardingv2_s16_monthly_title", "Monthly") }
        static var s16MonthlySub: String   { s("copy_onboardingv2_s16_monthly_sub", "Cancel anytime") }
        static var s16CTA: String          { s("copy_onboardingv2_s16_cta", "Start free trial") }
        static var s16CTAFallback: String  { s("copy_onboardingv2_s16_cta_fallback", "Continue") }
        static var s16Decline: String      { s("copy_onboardingv2_s16_decline", "Continue without Pro") }
        static var s16Restore: String      { s("copy_onboardingv2_s16_restore", "Restore") }
        static var s16Terms: String        { s("copy_onboardingv2_s16_terms", "Terms") }
        static var s16Privacy: String      { s("copy_onboardingv2_s16_privacy", "Privacy") }
        static var s16NoProducts: String   { s("copy_onboardingv2_s16_no_products", "Loading plans...") }
        static func s16AnnualSub(perMonth: String, trialDays: String) -> String {
            String(format: s("copy_onboardingv2_s16_annual_sub", "That's about %1$@/month · %2$@-day free trial"), perMonth, trialDays)
        }
        /// Annual subline when no intro trial is offered.
        static func s16AnnualSubNoTrial(perMonth: String) -> String {
            String(format: s("copy_onboardingv2_s16_annual_sub_no_trial", "That's about %@ per month"), perMonth)
        }
        /// Discount badge on the annual plan, e.g. "Save 58%".
        static func s16SaveBadge(percent: Int) -> String {
            String(format: s("copy_onboardingv2_s16_save_badge", "Save %d%%"), percent)
        }
        /// CTA when an intro free trial of `days` is offered.
        static func s16CTATrial(days: Int) -> String {
            String(format: s("copy_onboardingv2_s16_cta_trial", "Start %d day free trial"), days)
        }

        struct WatchListRow: Identifiable {
            let id: String
            let icon: String
            let color: Color
            let label: String
            let sub: String
        }
        // Data-insight rows (shown only when the scan found a real value).
        // Worst-weekday row: the one concrete pattern the read surfaced.
        static func watchWeekdayLabel(weekday: String) -> String {
            String(format: s("copy_onboardingv2_watch_weekday_label", "Your %@ dip"), weekday)
        }
        static var watchWeekdaySub: String   { s("copy_onboardingv2_watch_weekday_sub", "The day your recovery runs lowest.") }
        static var watchRestingHRLabel: String { s("copy_onboardingv2_watch_rhr_label", "Your resting heart rate") }
        static func watchRestingHRSub(bpm: Int) -> String {
            String(format: s("copy_onboardingv2_watch_rhr_sub", "%d bpm, your true baseline"), bpm)
        }
        static var watchSleepLabel: String   { s("copy_onboardingv2_watch_sleep_label", "Your sleep average") }
        static func watchSleepSub(hours: Int, mins: Int) -> String {
            String(format: s("copy_onboardingv2_watch_sleep_sub", "%dh %dm a night"), hours, mins)
        }

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

        // MARK: - Metric phrases (used to build watch copy)
        /// Short label for the metric we will keep watching (refuted pivot and
        /// side discoveries).
        static func metricWatchLabel(_ metric: PredictionMetric) -> String {
            switch metric {
            case .sleepDuration:        return s("copy_onboardingv2_metric_label_sleep", "sleep")
            case .heartRateVariability: return s("copy_onboardingv2_metric_label_hrv", "recovery")
            case .restingHeartRate:     return s("copy_onboardingv2_metric_label_rhr", "resting heart rate")
            }
        }

        // MARK: - Verdict (rich branch)
        static var verdictConfirmedEyebrow: String { s("copy_onboardingv2_verdict_confirmed_eyebrow", "NOW YOU KNOW WHERE TO LOOK") }
        static var verdictRefutedEyebrow: String   { s("copy_onboardingv2_verdict_refuted_eyebrow", "GOOD NEWS") }
        static var verdictInconclusiveEyebrow: String { s("copy_onboardingv2_verdict_inconclusive_eyebrow", "ALMOST THERE") }
        static var verdictCTA: String { s("copy_onboardingv2_verdict_cta", "Continue") }
        static var verdictConfirmedCTA: String { s("copy_onboardingv2_verdict_confirmed_cta", "Where do I start?") }
        static var verdictChartCaption: String { s("copy_onboardingv2_verdict_chart_caption", "Recovery by weekday, from your own Health data") }
        /// Confirmed: the claim held. `metric` is the driver we watch,
        /// `magnitude` a banded phrase, `weekday` the day it lands hardest,
        /// `outcome` the user's own words. Phrasing stays neutral so it reads
        /// right whether the metric goes up or down.
        static func verdictConfirmedBody(metric: String, magnitude: String, weekday: String, outcome: String) -> String {
            String(format: s("copy_onboardingv2_verdict_confirmed_body", "On %1$@s your %2$@ shifts by %3$@, and that lines up with your %4$@. That is a small, specific thing you can change."), weekday, metric, magnitude, outcome)
        }
        static var verdictConfirmedTitle: String { s("copy_onboardingv2_verdict_confirmed_title", "One pattern. Yours to move.") }
        // The word in verdictConfirmedTitle tinted blue. Must appear verbatim in it.
        static var verdictConfirmedTitleAccent: String { s("copy_onboardingv2_verdict_confirmed_title_accent", "Yours") }
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
        static var journalFirstEyebrow: String { s("copy_onboardingv2_journal_first_eyebrow", "BUILT BY YOU") }
        static var journalFirstTitle: String   { s("copy_onboardingv2_journal_first_title", "Your answers\nbecome a trend.") }
        static var journalFirstBody: String    { s("copy_onboardingv2_journal_first_body", "A week of quick check ins reads just like this. You make the picture, we find the pattern.") }
        static var journalFirstChartCaption: String { s("copy_onboardingv2_journal_first_chart_caption", "Energy from your morning check ins") }
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
        static var sDoneTitle: String { s("copy_onboardingv2_done_title", "Your pathway starts now.") }
        static var sDoneLede: String  { s("copy_onboardingv2_done_lede", "Tonight brings your first step. Tomorrow morning we tell you if it worked. One new step every day after.") }
        static var sDoneCTA: String   { s("copy_onboardingv2_done_cta", "Start my pathway") }
        static var sDoneDisclaimer: String { s("copy_onboardingv2_sdone_disclaimer", "Laso is not a medical device and does not diagnose or treat any condition. By continuing you confirm you understand.") }

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

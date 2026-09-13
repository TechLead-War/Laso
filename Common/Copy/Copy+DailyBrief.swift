import Foundation

extension Copy {
    /// Every string on the Today tab, the driver detail, and the morning-after
    /// verdict. Defaults are the approved reference strings from
    /// `LASO_DIRECTION_PROPOSAL.html`.
    enum DailyBrief {

        static var tabToday: String { RemoteConfigManager.shared.copyString("copy_daily_brief_tab_today", default: "Today") }
        static var tabBody: String { RemoteConfigManager.shared.copyString("copy_daily_brief_tab_body", default: "Body") }
        static var tabProgress: String { RemoteConfigManager.shared.copyString("copy_daily_brief_tab_progress", default: "Progress") }

        static var sectionAffecting: String { RemoteConfigManager.shared.copyString("copy_daily_brief_section_affecting", default: "What's affecting you") }
        static var sectionToDo: String { RemoteConfigManager.shared.copyString("copy_daily_brief_section_to_do", default: "What to do today") }
        static var sectionWorking: String { RemoteConfigManager.shared.copyString("copy_daily_brief_section_working", default: "Is it working") }
        static var sectionYesterday: String { RemoteConfigManager.shared.copyString("copy_daily_brief_section_yesterday", default: "Yesterday") }

        static var footerTomorrow: String { RemoteConfigManager.shared.copyString("copy_daily_brief_footer_tomorrow", default: "Tomorrow morning: did the walk and the bedtime count?") }
        /// %@ is a weekday name, e.g. "Sunday".
        static func footerNextVerdict(_ day: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_footer_next_verdict", default: "%@: first verdict on bounce-back."), day)
        }

        // MARK: - Status

        enum Status {
            static var chipStrong: String { RemoteConfigManager.shared.copyString("copy_daily_brief_status_chip_strong", default: "Strong today") }
            static var chipSteady: String { RemoteConfigManager.shared.copyString("copy_daily_brief_status_chip_steady", default: "Steady today") }
            static var chipLow: String { RemoteConfigManager.shared.copyString("copy_daily_brief_status_chip_low", default: "Low today") }
            static func chipUnderRested(_ weeks: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_status_chip_under_rested", default: "Under-rested · %d weeks"), weeks)
            }

            static var headlineMoveNotPush: String { RemoteConfigManager.shared.copyString("copy_daily_brief_status_headline_move_not_push", default: "Good day to move. Not a day to push.") }
            static var headlinePush: String { RemoteConfigManager.shared.copyString("copy_daily_brief_status_headline_push", default: "Good day to push.") }
            static var headlineEasy: String { RemoteConfigManager.shared.copyString("copy_daily_brief_status_headline_easy", default: "Steady. Keep it easy.") }
            static var headlineRest: String { RemoteConfigManager.shared.copyString("copy_daily_brief_status_headline_rest", default: "Rest day.") }
            static var headlineRecovered: String { RemoteConfigManager.shared.copyString("copy_daily_brief_status_headline_recovered", default: "Recovered well.") }

            static func readinessAbove(_ score: Int, _ low: Int, _ high: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_status_readiness_above", default: "Readiness %d, above your usual %d to %d."), score, low, high)
            }
            static func readinessInside(_ score: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_status_readiness_inside", default: "Readiness %d, inside your usual."), score)
            }
            static func readinessBelow(_ score: Int, _ low: Int, _ high: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_status_readiness_below", default: "Readiness %d, below your usual %d to %d."), score, low, high)
            }
            static func readinessPlain(_ score: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_status_readiness_plain", default: "Readiness %d."), score)
            }
            /// No trailing stop: `balanceClause` may continue the sentence.
            static func restClause(_ rest: Int, _ of: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_status_rest_clause", default: "But you've had %d rest days in %d"), rest, of)
            }
            static func balanceClause(_ clock: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_status_balance_clause", default: "and your sleep balance is %@ behind."), clock)
            }
            /// Joins `restClause` to `balanceClause`, or closes `restClause` on its own.
            static var clauseJoin: String { RemoteConfigManager.shared.copyString("copy_daily_brief_status_clause_join", default: ", ") }
            static var clauseEnd: String { RemoteConfigManager.shared.copyString("copy_daily_brief_status_clause_end", default: ".") }

            static var holding: String { RemoteConfigManager.shared.copyString("copy_daily_brief_status_holding", default: "Holding, not improving.") }
            static var improving: String { RemoteConfigManager.shared.copyString("copy_daily_brief_status_improving", default: "Improving.") }
            static var slipping: String { RemoteConfigManager.shared.copyString("copy_daily_brief_status_slipping", default: "Slipping.") }

            static var sparkUsual: String { RemoteConfigManager.shared.copyString("copy_daily_brief_status_spark_usual", default: "your usual") }
            static var sparkStart: String { RemoteConfigManager.shared.copyString("copy_daily_brief_status_spark_start", default: "2 weeks ago") }
            static func sparkToday(_ score: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_status_spark_today", default: "today · %d"), score)
            }

            static var learning: String { RemoteConfigManager.shared.copyString("copy_daily_brief_status_learning", default: "Learning your usual.") }
            static func learningSentence(_ days: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_status_learning_sentence", default: "%d more days of readings and Laso can tell you what is off."), days)
            }
        }

        // MARK: - Drivers

        enum Driver {
            static var restDaysTitle: String { RemoteConfigManager.shared.copyString("copy_daily_brief_driver_rest_days_title", default: "Not enough rest days") }
            static func restDaysValue(_ rest: Int, _ of: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_driver_rest_days_value", default: "%d of %d"), rest, of)
            }
            static func restDaysSentence(_ workout: Int, _ rest: Int, _ need: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_driver_rest_days_sentence", default: "%d workout days to %d rest days. You need about %d rest days a week for the load you carry."), workout, rest, need)
            }

            static var sleepBalanceTitle: String { RemoteConfigManager.shared.copyString("copy_daily_brief_driver_sleep_balance_title", default: "Sleep balance behind") }
            static func sleepBalanceSentence(_ nights: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_driver_sleep_balance_sentence", default: "%d nights at your usual would clear it. You are stable, not paying it back."), nights)
            }
            static func sleepBalanceGrowing(_ nights: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_driver_sleep_balance_growing", default: "%d nights at your usual would clear it, and it is still growing."), nights)
            }

            static var hrrTitle: String { RemoteConfigManager.shared.copyString("copy_daily_brief_driver_hrr_title", default: "Heart rate bounce-back below usual") }
            static func hrrValue(_ pct: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_driver_hrr_value", default: "%d%% off"), pct)
            }
            static var hrrSentence: String { RemoteConfigManager.shared.copyString("copy_daily_brief_driver_hrr_sentence", default: "Your heart takes longer to settle after effort than it did. The earliest sign of under-recovery.") }

            static var strainTitle: String { RemoteConfigManager.shared.copyString("copy_daily_brief_driver_strain_title", default: "Strain running high") }
            static func strainValue(_ days: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_driver_strain_value", default: "%d of 6"), days)
            }
            static func strainSentence(_ low: Int, _ high: Int, _ days: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_driver_strain_sentence", default: "Above your %d to %d target on %d of the last 6 days."), low, high, days)
            }

            static var stressTitle: String { RemoteConfigManager.shared.copyString("copy_daily_brief_driver_stress_title", default: "Stress running high") }
            static var stressSentence: String { RemoteConfigManager.shared.copyString("copy_daily_brief_driver_stress_sentence", default: "Your body has been under pressure most of today.") }

            /// %1$@ metric name, %2$@ `above` or `below`.
            static func anomalyTitle(_ metric: String, _ direction: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_driver_anomaly_title", default: "%@ %@ usual"), metric, direction)
            }
            static func anomalyValue(_ pct: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_driver_anomaly_value", default: "%d%% off"), pct)
            }
            /// %1$@ today's reading with unit, %2$@ the usual-range sentence from `MetricVerdict.rangeText`.
            static func anomalySentence(_ value: String, _ range: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_driver_anomaly_sentence", default: "%@ today. %@."), value, range)
            }
            /// Used when neither a personal nor a population range exists for the metric.
            static func anomalySentencePlain(_ value: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_driver_anomaly_sentence_plain", default: "%@ today."), value)
            }
            static var above: String { RemoteConfigManager.shared.copyString("copy_daily_brief_driver_above", default: "above") }
            static var below: String { RemoteConfigManager.shared.copyString("copy_daily_brief_driver_below", default: "below") }
        }

        // MARK: - Day move

        enum Day {
            static var label: String { RemoteConfigManager.shared.copyString("copy_daily_brief_day_label", default: "Day") }
            static var walkTitle: String { RemoteConfigManager.shared.copyString("copy_daily_brief_day_walk_title", default: "Close your goal with a walk, not a workout") }
            static func walkReason(_ minutes: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_day_walk_reason", default: "You are %d min from today's goal. A brisk walk closes it and counts as a rest day for your heart."), minutes)
            }
            static func remindAt(_ time: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_day_remind_at", default: "Remind me at %@"), time)
            }
            static func reminderSet(_ time: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_day_reminder_set", default: "Reminder set · %@"), time)
            }
            static var done: String { RemoteConfigManager.shared.copyString("copy_daily_brief_day_done", default: "Done") }
        }

        // MARK: - Night move

        enum Night {
            static var label: String { RemoteConfigManager.shared.copyString("copy_daily_brief_night_label", default: "Night") }
            static func title(_ time: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_night_title", default: "In bed by %@"), time)
            }
            static func titleAgain(_ time: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_night_title_again", default: "In bed by %@ again"), time)
            }
            /// %1$@ minutes paid back as a clock string, %2$@ the balance as a clock string, %3$@ wake time.
            static func paysBack(_ minutes: String, of balance: String, wake: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_night_pays_back", default: "Pays back %@ of the %@. Based on your %@ wake."), minutes, balance, wake)
            }
            static var twoNights: String { RemoteConfigManager.shared.copyString("copy_daily_brief_night_two_nights", default: "Two nights in a row is what clears the balance.") }
            static func keepRhythm(wake: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_night_keep_rhythm", default: "Keeps your %@ wake steady."), wake)
            }
            static func remindAt(_ time: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_night_remind_at", default: "Remind me at %@"), time)
            }
            static func reminderSet(_ time: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_night_reminder_set", default: "Reminder set · %@"), time)
            }
            static var inBedNow: String { RemoteConfigManager.shared.copyString("copy_daily_brief_night_in_bed_now", default: "In bed now") }
        }

        // MARK: - Focus

        enum Focus {
            static var titleRest: String { RemoteConfigManager.shared.copyString("copy_daily_brief_focus_title_rest", default: "Recover without losing fitness") }
            static var titleSleep: String { RemoteConfigManager.shared.copyString("copy_daily_brief_focus_title_sleep", default: "Clear the sleep balance") }
            static var titleHRR: String { RemoteConfigManager.shared.copyString("copy_daily_brief_focus_title_hrr", default: "Bring bounce-back back") }
            static var titleStrain: String { RemoteConfigManager.shared.copyString("copy_daily_brief_focus_title_strain", default: "Bring strain back in range") }
            static var titleStress: String { RemoteConfigManager.shared.copyString("copy_daily_brief_focus_title_stress", default: "Calming stress") }
            static func titleAnomaly(_ metric: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_focus_title_anomaly", default: "Bring %@ back to usual"), metric)
            }
            static func title(for driver: DriverKind) -> String {
                switch driver {
                case .restDays: return titleRest
                case .sleepBalance: return titleSleep
                case .heartRateBounceBack: return titleHRR
                case .strainHigh: return titleStrain
                case .stressHigh: return titleStress
                case .anomaly(let metric): return titleAnomaly(metric.displayName)
                }
            }
            static func week(_ n: Int, of total: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_focus_week", default: "Week %d of %d"), n, total)
            }
            static func day(_ n: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_focus_day", default: "Day %d"), n)
            }
            static var startButton: String { RemoteConfigManager.shared.copyString("copy_daily_brief_focus_start_button", default: "Start a 3-week focus") }
            static var closedImproved: String { RemoteConfigManager.shared.copyString("copy_daily_brief_focus_closed_improved", default: "Worked") }
            static var closedHeld: String { RemoteConfigManager.shared.copyString("copy_daily_brief_focus_closed_held", default: "Held") }
            static var closedNoChange: String { RemoteConfigManager.shared.copyString("copy_daily_brief_focus_closed_no_change", default: "Did not move") }
        }

        // MARK: - Verdict (the morning after)

        enum Verdict {
            static var bothCounted: String { RemoteConfigManager.shared.copyString("copy_daily_brief_verdict_both_counted", default: "Both counted.") }
            static var oneCounted: String { RemoteConfigManager.shared.copyString("copy_daily_brief_verdict_one_counted", default: "One counted.") }
            static var neither: String { RemoteConfigManager.shared.copyString("copy_daily_brief_verdict_neither", default: "Not yet.") }
            static func firstRestIn(_ days: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_verdict_first_rest_in", default: "Your first proper rest day in %d."), days)
            }
            static func walkLine(_ minutes: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_verdict_walk_line", default: "Walk, %d min · goal closed"), minutes)
            }
            static func walkDetail(_ before: Int, _ after: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_verdict_walk_detail", default: "Counted as a rest day. %d → %d this week."), before, after)
            }
            static func bedLine(_ time: String, _ duration: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_verdict_bed_line", default: "In bed %@ · %@"), time, duration)
            }
            static func bedDetail(_ before: String, _ after: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_verdict_bed_detail", default: "Sleep balance %@ → %@."), before, after)
            }
        }

        // MARK: - Driver detail

        enum Detail {
            static var whyItMatters: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_why_it_matters", default: "Why it matters") }
            static var whatMovesIt: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_what_moves_it", default: "What moves it") }
            static var yourUsual: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_your_usual", default: "Your usual") }
            static var allInsights: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_all_insights", default: "All insights") }
            static var connections: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_connections", default: "Connections") }
            static var breathe: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_breathe", default: "Breathe 2 min") }

            // Rest days
            static func restSubtitle(_ rest: Int, _ of: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_detail_rest_subtitle", default: "%d rest days in the last %d"), rest, of)
            }
            static func legendWorkout(_ n: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_detail_legend_workout", default: "workout day · %d"), n)
            }
            static func legendRest(_ n: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_detail_legend_rest", default: "rest day · %d"), n)
            }
            static func restWhy(_ vo2: String, _ restingHR: Int, _ hrrPct: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_detail_rest_why", default: "Your fitness numbers are excellent: VO2 max %@, resting heart rate %d. Rest is where those numbers get banked. Without it, the first thing to slip is heart rate bounce-back, which is already %d%% below your usual."), vo2, restingHR, hrrPct)
            }
            static var restMove1Title: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_rest_move1_title", default: "Two rest days a week") }
            static var restMove1Value: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_rest_move1_value", default: "target") }
            static var restMove1Note: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_rest_move1_note", default: "A brisk walk counts. A run does not.") }
            static var restMove2Title: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_rest_move2_title", default: "Sleep balance back to zero") }
            static func restMove2Value(_ clock: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_detail_rest_move2_value", default: "%@ to go"), clock)
            }
            static var restMove2Note: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_rest_move2_note", default: "Rest days work better when the balance is clear.") }
            static var restMove3Title: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_rest_move3_title", default: "Watch bounce-back") }
            static var restMove3Value: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_rest_move3_value", default: "weekly") }
            static var restMove3Note: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_rest_move3_note", default: "When it returns to usual, this driver closes.") }
            static var restUsualTitle: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_rest_usual_title", default: "Rest days, last 3 months") }
            static func restUsualValue(_ perWeek: Double) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_detail_rest_usual_value", default: "%.1f a week"), perWeek)
            }
            static func restUsualStatus(_ need: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_detail_rest_usual_status", default: "Below the %d a week your load needs"), need)
            }

            // Sleep balance
            static func sleepSubtitle(_ clock: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_detail_sleep_subtitle", default: "%@ behind over the last 14 nights"), clock)
            }
            static var sleepWhy: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_sleep_why", default: "A balance that sits still is not paid back. Every night short of your usual keeps readiness and bounce-back below where your fitness says they should be.") }
            static var sleepMove1Title: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_sleep_move1_title", default: "In bed by the target") }
            static var sleepMove1Value: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_sleep_move1_value", default: "tonight") }
            static var sleepMove1Note: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_sleep_move1_note", default: "The bedtime is built from your own wake time.") }
            static var sleepMove2Title: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_sleep_move2_title", default: "Two nights in a row") }
            static var sleepMove2Value: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_sleep_move2_value", default: "this week") }
            static var sleepMove2Note: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_sleep_move2_note", default: "One early night holds the line. Two start clearing it.") }
            static var sleepMove3Title: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_sleep_move3_title", default: "Keep the wake time") }
            static var sleepMove3Value: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_sleep_move3_value", default: "daily") }
            static var sleepMove3Note: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_sleep_move3_note", default: "Sleeping in moves the balance for one day and the rhythm for a week.") }
            static var sleepUsualTitle: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_sleep_usual_title", default: "Sleep, last 30 nights") }

            // Heart rate bounce-back
            static func hrrSubtitle(_ pct: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_detail_hrr_subtitle", default: "%d%% below your usual"), pct)
            }
            static var hrrWhy: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_hrr_why", default: "How fast your heart settles after effort is the first number to move when recovery falls behind, days before resting heart rate or HRV show it.") }
            static var hrrMove1Title: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_hrr_move1_title", default: "Rest days") }
            static var hrrMove1Value: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_hrr_move1_value", default: "two a week") }
            static var hrrMove1Note: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_hrr_move1_note", default: "Bounce-back recovers on the days you do not train.") }
            static var hrrMove2Title: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_hrr_move2_title", default: "Sleep balance") }
            static var hrrMove2Value: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_hrr_move2_value", default: "to zero") }
            static var hrrMove2Note: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_hrr_move2_note", default: "Short nights slow the settle the next day.") }
            static var hrrMove3Title: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_hrr_move3_title", default: "Keep hard sessions short") }
            static var hrrMove3Value: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_hrr_move3_value", default: "under 45 min") }
            static var hrrMove3Note: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_hrr_move3_note", default: "Long hard days are what pushed it down.") }
            static var hrrUsualTitle: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_hrr_usual_title", default: "Bounce-back, last 30 days") }

            // Strain
            static func strainSubtitle(_ days: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_detail_strain_subtitle", default: "Above target on %d of the last 6 days"), days)
            }
            static var strainWhy: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_strain_why", default: "Strain above your target for days at a time is load your body has not yet absorbed. Readiness follows it down within the week.") }
            static var strainMove1Title: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_strain_move1_title", default: "One easy day") }
            static var strainMove1Value: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_strain_move1_value", default: "today") }
            static var strainMove1Note: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_strain_move1_note", default: "A walk keeps the streak without adding load.") }
            static var strainMove2Title: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_strain_move2_title", default: "Stay inside the target") }
            static var strainMove2Value: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_strain_move2_value", default: "this week") }
            static var strainMove2Note: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_strain_move2_note", default: "The target moves with your readiness each morning.") }
            static var strainMove3Title: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_strain_move3_title", default: "Watch readiness") }
            static var strainMove3Value: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_strain_move3_value", default: "daily") }
            static var strainMove3Note: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_strain_move3_note", default: "When it is back at your usual, this driver closes.") }
            static var strainUsualTitle: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_strain_usual_title", default: "Strain, last 6 days") }

            // Stress
            static var stressSubtitle: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_stress_subtitle", default: "Above your usual most of today") }
            static var stressWhy: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_stress_why", default: "Stress here is your heart rate and HRV against your own baseline. A day like this taxes recovery the same way a hard session does.") }
            static var stressMove1Title: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_stress_move1_title", default: "Breathe") }
            static var stressMove1Value: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_stress_move1_value", default: "2 min") }
            static var stressMove1Note: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_stress_move1_note", default: "Slow breathing brings HRV up within minutes.") }
            static var stressMove2Title: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_stress_move2_title", default: "Keep training light") }
            static var stressMove2Value: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_stress_move2_value", default: "today") }
            static var stressMove2Note: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_stress_move2_note", default: "A hard session on a stressed day costs two days of recovery.") }
            static var stressMove3Title: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_stress_move3_title", default: "Bed on time") }
            static var stressMove3Value: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_stress_move3_value", default: "tonight") }
            static var stressMove3Note: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_stress_move3_note", default: "Sleep is where a stressed day gets cleared.") }
            static var stressUsualTitle: String { RemoteConfigManager.shared.copyString("copy_daily_brief_detail_stress_usual_title", default: "Stress, last 14 days") }
        }

        // MARK: - Focus KPIs

        enum KPI {
            static func label(for kind: FocusStore.KPIKind) -> String {
                switch kind {
                case .restDaysPerWeek: return RemoteConfigManager.shared.copyString("copy_daily_brief_kpi_rest_days_per_week", default: "rest days a week")
                case .sleepBalanceHours: return RemoteConfigManager.shared.copyString("copy_daily_brief_kpi_sleep_balance_hours", default: "sleep balance, target 0")
                case .hrrPercentOffUsual: return RemoteConfigManager.shared.copyString("copy_daily_brief_kpi_hrr_percent_off_usual", default: "bounce-back vs usual")
                case .vo2Max: return RemoteConfigManager.shared.copyString("copy_daily_brief_kpi_vo2_max", default: "VO2 max, hold it")
                case .hrvMs: return RemoteConfigManager.shared.copyString("copy_daily_brief_kpi_hrv_ms", default: "HRV")
                case .restingHR: return RemoteConfigManager.shared.copyString("copy_daily_brief_kpi_resting_hr", default: "resting heart rate")
                case .deepSleepMinutes: return RemoteConfigManager.shared.copyString("copy_daily_brief_kpi_deep_sleep_minutes", default: "deep sleep")
                case .steps: return RemoteConfigManager.shared.copyString("copy_daily_brief_kpi_steps", default: "steps a day")
                case .stressScore: return RemoteConfigManager.shared.copyString("copy_daily_brief_kpi_stress_score", default: "stress")
                }
            }

            /// A balance still owed, e.g. "−2h 20m".
            static func behind(_ clock: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_kpi_behind", default: "−%@"), clock)
            }
            static func percent(_ value: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_kpi_percent", default: "%d%%"), value)
            }
            static func milliseconds(_ value: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_kpi_milliseconds", default: "%d ms"), value)
            }
            static func bpm(_ value: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_kpi_bpm", default: "%d bpm"), value)
            }
            /// Also the minutes an early night pays back in `Night.paysBack`.
            static func minutes(_ value: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_daily_brief_kpi_minutes", default: "%d min"), value)
            }
        }
    }
}

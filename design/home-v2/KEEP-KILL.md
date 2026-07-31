# Home Screen — Component Trial: Keep or Kill

## The one-paragraph answer
The home screen carries 22 tried components (18 render in the main stack per HomeView.swift:446-715, plus the empty state, two explainer sheets, the hero share entry, and one card — PersonalHealthForecastCard — that turned out to live on Explore, not Home). Verdicts: **0 KEEP, 12 FIX, 4 MERGE, 6 DELETE**. Nothing on this screen is right as shipped. The single biggest theme: the product's real value is one loop — do the action, mark it done, see next-morning proof, glance the score — and everything else is either engagement furniture borrowed from other apps (activation bar, streak card, greeting) or numbers dressed in precision the data cannot back (a fake "Conf 85%", an n=1 causal claim, a fabricated weekly score, a delta chip from a different series than the ring it decorates). Delete the furniture, strip the false precision, and the default morning lands at 5 blocks + footer — inside the 6-7 budget.

## Kill list — delete now

| Component | Why it dies | What migrates where |
|---|---|---|
| **CoachGreetingView** | Zero health info, zero taps; renders above even the we-know-nothing empty state (HomeView:450 vs :453), so the no-data screen is a blank page with your name on it. No usage number makes a name and a date answer Q1/Q2/Q3. | Nothing. ~60pt returns to the action card; its removal half-fixes the empty state for free. |
| **IntradayActivityCard** | FOUNDER DECISION 2026-07-31: kept. Overturned from DELETE with four conditions that make it actionable: (1) overlay a faint "your usual day up to this hour" trace so today reads against the user's own baseline; (2) one derived verdict line under the number ("Ahead of your usual Thursday" / "Quieter than usual so far"), computed, never typed; (3) when a long still gap is detected, the nudge routes through Next Up (the screen keeps exactly one instruction) — the card itself never instructs; (4) hidden before ~10am while the trace is empty, tappable into Activity detail. | Kept with fixes above. |
| **PersonalHealthForecastCard** | "Conf 85%" is a clamped display heuristic (0.5-0.95 from CI width) presented as measured certainty under a doc comment claiming statistical guarantees. Fabricated precision is disqualifying regardless of tap-through. Not on Home at all — sole render is ExploreView:142; the home-v2 research docs listing it are stale. | Nothing. Delete the Explore section, `healthForecasts`, both build paths, ForecastBuilder, tests — a verified closed subgraph. |
| **streakMilestoneCard** | An ask dressed as a reward: both Share and Dismiss fire the same shareCard analytics id to compute a decline rate (HomeView:291-300). masterStreak requires recovery goals the user cannot control, so it punishes biology. Occupies the above-the-fold moment slot to request distribution. | Streak share template stays reachable in ShareWinSheet via its own gate (ShareableCard:109). Delete card, store, and onChange (HomeView:157-161, 225-320). |
| **ActivationProgressBanner** | A progress bar toward the app becoming useful is an admission it is not yet; persuasive-mechanic count shows no efficacy relationship (92-RCT meta, psychology-research.md:196); dies at day 8 by design; 4-second auto-dismiss destroys its own reward. | Keep all trackActivationMilestone analytics events — verified independent of the banner, the funnel survives untouched. |
| **MorningCheckInView** | The trial's verified ask-then-ignore: readinessAdjustment is written (HomeView:119, DashboardViewModel:2879) and read nowhere; answering changes no pixel. 17 tap targets in the 5-11am window. Even the infrastructure defense is hollow — its one consumer, RepermissionScheduler, serves the NO-data journey but the card renders inside the hasData branch (HomeView:455), so its stated audience can never reach it. The critique's own line 520: "REMOVE, or wire it up and prove it. There is no third option." | Remove HomeView:29,116-120,596-609 and the dead adjustment fields. Repoint RepermissionScheduler:25 to journal entries; decide the watch check-in path (PhoneWatchSession:252 records equally unread data). A future ONE wired question is a new component, not this one. |

## Fix list — real job, failing execution

| Component | The job | The named fix | Effort |
|---|---|---|---|
| **primaryActionCard (Next Up)** | The one answer to "what should I do today" — the highest-scoring loop in the evidence (Harkin d=0.40). | Rungs 6-8 fallbacks must say "no strong signal today, default suggestion" — never dress the hardcoded default as personal advice. Benefit chip all-rungs or no-rungs. Hosts the merged life-context affordance. | S |
| **DailyActionResultCard** | Next-morning proof that makes the loop repeat. | Kill the n=1 causal claim: DailyActionResultStore declares a ±2 dead band, then Copy+Home:238 prints "+2 higher this morning" on the noise floor. Use the existing aggregated proof (RecommendationEvaluator) at n>=3; below that, fact only, no magnitude inside ±2. Kill the consolation copy. Hosts the merged share entry on up mornings. | S |
| **RecoveryHeroCard** | The daily score glance plus plain-word why. | Mostly deletion inside the card: delete the delta chip (always a different series than the readiness it decorates, HomeView:497), three of four confidence widgets, the Energy Why row, the share icon. Fix B3: in fallback, relabel ring and narration to Daily Health Score or show no ring (HomeView:189-196 swaps the number, never the label). Fix the green-glow-on-red mismatch. Absorbs the coverage line. Why rows: cap at the best 3, ranked by distance from the user's usual range (out-of-range signals first); the rest live behind the ring tap. | M |
| **WeekScoreStrip** | The only week-shape view — the minimum honest window for a noisy composite. | One caption: it renders cachedDailyScoresByDay under a ring labeled Readiness (HomeView:548). Feed it the ring's series or caption it "Daily score, last 7 days". | S |
| **ScoreGuideSheet + RecoveryInfoSheet** | The ring is indefensible without an explainer. | One source of truth: Home grades at 67/45, the sheet at 85/70/55. Drive both band tables from the ring's tier config; replace hardcoded weight strings with ReadinessScorerConfig or a ranked list; add "directional, not clinical". Zero home blocks — costs the budget nothing. | S |
| **MetricStripView + VITALS header** | Home's only navigation into five detail modules (verified: tile taps are the sole entries, HomeView:655). | FOUNDER DECISION 2026-07-31: tiles keep their five numbers exactly as shipped — the nav-row fix is overruled. No change to this component. | S |
| **SleepBankCard** | The only clinically grounded multi-day signal on the screen. | Raise actionableDebtHours (2.0h over 14 nights = 8.5 min/night — near-daily amber furniture, SleepDebtTracker:40) until appearance is a finding. Reframe from payable ledger to "running short" (Rupp 2009). Collapse to one tappable line; the advisor owns the instruction (verified same threshold at DashboardSmartActionAdvisor:76). | M |
| **WatchComplicationCard** | One-time ability-side habit support; complications never self-install. | Collapse the inline multi-step tutorial to a one-line dismissible banner linking Devices. Keep the gating and permanent dismissal. First marginal survivor if the budget ever tightens. | S |
| **compactAlertBanner** | The app's only real safety signal. | Promote to position 1 when a warning exists; full narrative (today: caption size, lineLimit(2), scaled to 0.75 — HomeView:770-774); remove .softLocked (HomeView:642) — never blur a health alert. Delete the risk rows: a near-open filter (>=15/100, includes overtraining with no reliable biomarker) must stop riding the strict illness gate's credibility in the same red card. | M |
| **WeeklyReviewEntryCard + REVIEW header** | The only door into the best-evidenced mechanic in the product (verified: ContentView:547 is the route handler, not a second entry — deleting orphans Weekly Review). | Delete all three fabricated numbers ("weekly" score is today's daily score; (+4) compares one arbitrary prior day; "wins" counts any 2% move). Render on review day only. Lead with the honest step sentence. | M |
| **Last-updated footer** | The staleness truth underneath every confident number. | Threshold it: quiet static caption when fresh (drop the ticking re-render); warning-tinted line at the TOP of the scroll when stale. | S |
| **connectHealthView empty state** | The state that decides whether new users keep the app — best-executed content in the file. | Make it the fallback for !hasData so the blank gap state is unreachable; delete the duplicate trackEmptyStateShown (HomeView:731) so the churn funnel stops double-counting. Greeting removal covers the rest. | S |

## Merge list
- **LifeContextChipRow → primaryActionCard.** The capability is load-bearing (verified: rung 0 of the advisor, cache invalidated on toggle) but ~95% of mornings show four grey capsules asking the user to declare a problem they do not have. Idle: one "Something going on?" affordance on the Next Up card. Active: "Adjusted for: Injured · since 12 Jul" chip plus the confirm row, on the card whose output it overrides. One block permanently removed from every morning.
- **Share entry → DailyActionResultCard.** The gating comment ("No earned win means no share icon") is false as shipped — everyday templates make the icon permanent furniture on the hero. Delete the icon and the everyday templates; ShareWinSheet survives, reached from the result card on up mornings only, with all earned templates (streak included) in that tray.
- **AskYourDataCard → nav-bar search affordance.** A door dressed as content, branded with banned vocabulary ("CONCIERGE"), fronting the most GPU-expensive component in the perf audit. Feature stays one tap away (soft-lock behavior kept); ship staticOrb; replace hardcoded per-intent "confidence" constants with an honest coverage statement.
- **DataCoverageCard → hero missing-signals line.** Two of five rows (steps, SpO2) feed no scorer input, and the CTA opens Laso's own settings pane, not Health access (HomeView:585) — the wrong door. The hero's line names scorer-fed signals only, becomes tappable, and opens a real Health-app instruction screen.

## The surviving screen
Default morning, render order, after the trial:

1. **compactAlertBanner** — episodic, position 1 only when a warning exists; the one surface saying several signals moved together for days (Q1).
2. **DailyActionResultCard** — when yesterday's action was marked done; the honest proof that makes today's action worth doing (Q2, Q3).
3. **primaryActionCard (Next Up)** — the screen's answer to Q2, now hosting the life-context affordance and honest fallback labeling.
4. **RecoveryHeroCard** (slimmed) — ring, Why rows, summary footer, one coverage line; the daily glance and the best comprehension device (Q1).
5. **WeekScoreStrip** — the only evidence-backed window width; self-comparison without streak downsides (Q1, Q3).
6. **MetricStripView** as labeled nav row — the only path into five detail modules; no longer pretends to be comprehension.
7. **Last-updated footer** — a caption, not a block; the precondition for trusting everything above.

Episodic, not on a default morning: SleepBankCard (genuinely bad stretches only), WeeklyReviewEntryCard (review day only), WatchComplicationCard one-liner (one-time, self-retiring). Non-block infrastructure: the two sheets behind the ring tap, the nav-bar Ask affordance, connectHealthView for the no-data state.

**Count: 5 blocks + footer** on a default morning. Inside the 6-7 budget — no further cut required. If it ever tightens, the named next-to-go order is: WatchComplication line moves to Devices entirely, MetricStrip becomes pure navigation, WeekScoreStrip folds to a hero footer row.

## What we could not decide without real data
Pull from Amplitude this week (all instrumented unless noted):

1. Mark-done rate split by action source rung (`metadata["source"]` on trackBlockTap) — fallback-vs-policy parity sizes the honesty-label urgency.
2. Repeat mark-done rate after first DailyActionResultCard exposure — quantifies the loop's actual lift.
3. Life-context chip activation rate (life_context trackBlockTap) — near-zero argues for contextual-trigger-only, no idle affordance.
4. Hero Why-row tap-through — tappable vs static rows.
5. Hero share tap-through and completion funnel — the one verdict analytics could flip: meaningful everyday-share volume would restore the hero entry behind a real gate.
6. Per-tile tap-through on MetricStripView (7-day, split by tenure) — settles nav-row vs verdict-tiles, and whether six tiles earn slots.
7. Real debtHours distribution — set the SleepBank threshold at roughly the worst ~20% of weeks.
8. Watch card shown-to-enabled conversion — near-zero after the fix sends it to Devices.
9. Ask Your Data tap-through and week-two repeat-query rate — near-zero flips the merge toward DELETE; heavy use promotes a persistent input.
10. illnessTracker vs risksTracker tap-through — whether risk rows earn any surface anywhere.
11. Share of DataCoverage triggers that are SpO2-only, and settings-tap-to-signal-appearing conversion.
12. Weekly Review entry tap-through, and whether Home-visible step targets are hit more often than review-only ones — the only case for a daily slot.
13. Day-3 retention by empty-state reason — readable only after the double-count fix.
14. Streak share-accept vs dismiss rate — could justify a Weekly Review relocation someday, never the above-the-fold slot.
15. Week-one retention A/B with the activation banner off — the only business argument for some future activation surface.

## Honest risks
- **Paywall surfaces shrink.** Removing .softLocked from the alert banner deliberately unpaywalls a health warning — right call, but home_alerts disappears as a conversion surface; Ask Your Data keeps its soft-lock on tap, and hero/vitals/weekly locks are untouched. Watch trackPremiumFeatureAttempted volume after ship.
- **Activation funnel.** The banner's deletion was verified not to touch the trackActivationMilestone events other teams read. The risk is week-one retention itself — if it dips, the answer is honest day-1 content from backfilled HealthKit history, not the bar's return.
- **Share loop narrows** to result-card up-mornings. Volume will drop; the funnel events exist to measure whether what remains converts better (earned moments) or the distribution loss hurts. Fix the recovery template's overallScore fallback before shipping shares.
- **RepermissionScheduler silently starves** when MorningCheckInView goes — repoint it to journal entries in the same commit or the journal-first re-permission journey never fires again.
- **Two orphan hazards verified:** WeeklyReviewEntryCard is the only route into Weekly Review (fix, never delete without a new entry point), and MetricStrip tiles are the only routes into five detail modules (drop numbers, never tiles).
- **Empty-state sequencing:** the greeting deletion and the connectHealthView fallback fix must land together, or the gap state renders literally nothing.
- **B3 vocabulary must move in lockstep** — ring label, narration, sheets, and share templates all follow the same fallback relabel, or the fix reintroduces the contradiction one surface over.

Confidence: 88/100 — all 22 verdicts, their citations, and the kill/fix/merge reasoning come from the trial verdicts supplied, and I re-verified the render order and key line claims (greeting outside the empty-state branch, share gating comment, softLocked alert, coverage card's wrong-door CTA, VITALS/REVIEW headers, footer) by reading HomeView.swift:440-720 this session; below 90 because I did not independently re-open the 21 component files, the three research docs, or DashboardViewModel/store files behind the verdicts' line citations (e.g. DailyActionResultStore:30-31, SleepDebtTracker:40, ContentView:547), so any error in those supplied citations would carry into this report. | Source: mixed: code+user-statement
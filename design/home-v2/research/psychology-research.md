# Behavioural Psychology for a Health App Home Screen

Research pass for Home V2. Every claim below is traceable to a source fetched or searched on 2026-07-29. Where I could only reach a summary and not the primary text, it is marked. Where the pop-science version of an idea does not survive contact with the literature, it is marked.

## How to read the evidence grades

| Grade | Meaning |
|---|---|
| **A** | Primary text read this session. Numbers quoted from the paper itself. |
| **B** | Peer-reviewed source, abstract or full text read via a fetched page. |
| **C** | Search-result summary only. Direction is probably right, exact numbers not independently confirmed. |
| **D** | Vendor blog, trade press, or single-study claim. Treat as a hypothesis, not a fact. |

The single most important framing for this project: **most of the psychology that product teams quote in Home Screen design reviews is either weaker than claimed or has been directly contradicted.** The parts that survive replication are boring and structural, not clever.

---

## 1. Fogg Behavior Model (B = MAP)

**Grade A.** Read the original 2009 Persuasive'09 paper in full ([PDF](https://www.demenzemedicinagenerale.net/images/mens-sana/Captology_Fogg_Behavior_Model.pdf)) plus Fogg's current site ([behaviormodel.org](https://www.behaviormodel.org/)).

The 2009 paper calls it **B = MAT** (motivation, ability, trigger). Fogg later renamed "trigger" to "prompt", giving the modern **B = MAP**. behaviormodel.org states it plainly: "Behavior happens when Motivation, Ability, and a Prompt come together at the same time. When a behavior does not occur, at least one of those three elements is missing."

What the paper actually argues, in his words:

- "The FBM makes clear that motivation alone, no matter how high, may not get people to perform a behavior if they don't have the ability."
- "In general, persuasive design succeeds faster when we focus on making the behavior simpler instead of trying to pile on motivation. Why? People often resist attempts at motivation, but we humans naturally love simplicity."
- "Simplicity is a function of a person's scarcest resource at the moment a behavior is triggered."

**The six elements of simplicity (ability)**, described as a chain that fails at its weakest link:
time, money, physical effort, **brain cycles**, social deviance, non-routine.

Two of these are directly designable on a Home Screen. Brain cycles: "if performing a target behavior causes us to think hard, that might not be simple... we overestimate how much everyday people want to think." Non-routine: "people tend to find behaviors simple if they are routine... In seeking simplicity, people will often stick to their routine."

**The three trigger types** and when each is correct:

| Type | Use when | Fogg's definition |
|---|---|---|
| **Spark** | Motivation low, ability high | "a trigger that motivates behavior" |
| **Facilitator** | Motivation high, ability low | "trigger the behavior while also making the behavior easier to do" |
| **Signal** | Both already high | "It just serves as a reminder" |

Fogg is explicit about the failure mode: for a user who already has motivation and ability, a spark or facilitator "would either be annoying or condescending." And: "As recipients, we'll be most tolerant of triggers when they are signals or facilitators. Sparks may annoy us because they will seek to motivate us to do something we didn't intend to do."

**Behavior activation threshold**: a curved line across the motivation/ability plane. Above it, a prompt produces behaviour. Below it, "a trigger will not lead to the target behavior" and produces annoyance or frustration instead.

**Honest limitation:** the FBM is a *design heuristic*, not an empirically validated causal model. Fogg himself calls it "conceptual, showing relationships of the components rather than precise values." It has no measurement instrument and no effect size. It is useful for diagnosing why a screen fails, not for predicting how well it will work. behaviormodel.org's claim of "over 1,900 academic publications" referencing it is a citation count, not evidence of validity.

### Home Screen implication
The Home Screen is a **signal machine for already-motivated users**. A returning user has opened the app: motivation and ability are already above the line. Spending Home Screen real estate on motivational persuasion (streak pressure, urgency copy, hype) targets the wrong axis and Fogg predicts it reads as condescending. Spend it on removing brain cycles instead.

---

## 2. Fogg on celebration, and the "emotions create habits" claim

**Grade B** (his own commercial site, [tinyhabits.com/rewire](https://tinyhabits.com/rewire/)) — but treat the *strength* of the claim as **D**.

Fogg's Tiny Habits position is that repetition is not the mechanism. His claims:

- "Emotions create habits."
- "The stronger the emotion, the more deeply your brain rewires."
- "You must feel the emotion while you are doing the behavior, or immediately after."
- "If you are very good at celebrating, then you start wiring habits into your brain quickly, sometimes in a day or two."

**Be honest about this.** The "sometimes in a day or two" claim is a trade-book assertion. I found no controlled trial supporting it. It sits in direct tension with Lally's data (section 3), where the median was 66 days and 48% of motivated volunteers never reached asymptote at all. The celebration idea is a plausible mechanism (immediate reinforcement beats delayed reinforcement, which is well supported in operant learning generally), but "a day or two" is not evidenced and should not drive a design decision.

What *is* defensible: immediate positive feedback at the moment of completion is cheap and low risk. Delayed or abstract reward is worse than immediate concrete acknowledgement.

### Home Screen implication
Acknowledge the action **at the moment it happens, on the screen where it happens**, not in a weekly summary or a notification the next morning. But do not build the product's habit strategy on celebration alone, because the evidence for it as the primary mechanism is one author's assertion.

---

## 3. Lally 2010: what the 66-day study actually found

**Grade A.** Read the full paper text (Lally, van Jaarsveld, Potts & Wardle, *Eur. J. Soc. Psychol.* 40, 998-1009, 2010; [DOI 10.1002/ejsp.674](https://onlinelibrary.wiley.com/doi/abs/10.1002/ejsp.674), full text via [PDF](https://emotionalfirstaidacademy.com/wp-content/uploads/2023/10/How-habits-are-formed.pdf)).

The popular version is "it takes 66 days to form a habit." The actual study is much more interesting and much more cautionary.

**What was done:** 96 UCL postgraduate students, mean age 27, paid £30, chose a self-selected healthy eating, drinking or exercise behaviour tied to an existing daily cue ("after breakfast"), and logged the Self-Report Habit Index automaticity subscale daily for 84 days.

**The attrition is the story nobody quotes:**

| Stage | N | Note |
|---|---|---|
| Enrolled | 96 | |
| Provided enough data | 82 | 14 dropped out before day 60 |
| Model could be fitted | 62 | 12 unfittable, 8 flat (no automaticity increase at all) |
| **Good curve fit** | **39 (48% of 82)** | The 66-day figure comes only from these 39 |

The authors' own words: "even in this study where the participants were motivated to create habits, approximately half did not perform the behaviour consistently enough to achieve habit status."

**The 66 days:** median time to reach 95% of the individual's automaticity asymptote, **range 18 to 254 days**, quartiles 39 to 102. Not a mean, not a target, not a promise. And note: reaching *your own* plateau is not the same as becoming highly habitual. Four participants plateaued below the "this is not a habit" cut-off.

**Missing a day is not catastrophic — this is the strongest practical finding.** 140 missed opportunities across 55 participants. Automaticity fell by 0.29 points on a 0-42 scale the next day, which was not significant. Over a three-day window, automaticity rose 0.55 points when a day was missed versus 0.79 points when it was not. The paper: "a missed opportunity did not materially affect the habit formation process." Also, timing did not matter (r = 0.099, p = 0.246) — missing early was no worse than missing late.

**But a missed week is different.** Lally contrasts with Armitage (2005), where a lapse was defined as a whole week of non-attendance and *did* predict worse future performance. Their reconciliation: "missing one opportunity does not preclude habit formation, but missing a week's worth of opportunities reduces the likelihood of future performance."

**Early repetitions matter more.** The asymptotic curve beat the linear model (median nonlinear R² = 0.88 vs linear 0.72 for good-fit participants, p < 0.001). "Early repetitions result in larger increases in automaticity than those later in the habit formation process, and there is a point at which the behaviour cannot become more automatic even with further repetition."

**Exercise took ~1.5x longer** than eating or drinking (median 91 vs 65 and 59 days), though not statistically significant and the study was not powered for it.

**No extrinsic rewards were given**, and habits still formed. The authors: "We provided no extrinsic rewards, indicating that they are not required for habit development."

**Limitations the authors state:** small good-fit sample, university postgraduates only, missing daily data, self-report automaticity rather than observed behaviour.

### Home Screen implication
Two hard consequences. First, a Home Screen that punishes a single missed day is contradicting the best real-world habit data available. Second, the first two to three weeks carry disproportionate weight, so onboarding-adjacent Home Screen states matter far more than steady-state states.

---

## 4. Wood & Neal: habits are cue-driven, not goal-driven

**Grade A.** Read Wood, Mazar & Neal (2021), *Perspectives on Psychological Science*, [PDF](https://dornsife.usc.edu/wendy-wood/wp-content/uploads/sites/183/2023/10/Wood.Mazar_.Neal_.2021.pdf). Also Wood & Neal (2007) *Psychological Review* [PDF](https://dornsife.usc.edu/wendy-wood/wp-content/uploads/sites/183/2023/10/wood.neal_.2007psychrev_a_new_look_at_habits_and_the_interface_between_habits_and_goals.pdf) (Grade C, search summary only).

From the 2021 abstract: "People automatically repeat behaviors that were frequently rewarded in the past in a given context... Once habits form, contexts directly activate the response in mind."

The core mechanism, in their words: "As people repeat a rewarded action in a stable context, they incrementally develop associations in procedural memory between the response and recurring cues in that context." And crucially: "Once formed, habits are directly brought to mind by context cues without the need for recruiting the goal that may have motivated initial learning (or any other goal)."

Two features of habit memory they identify: **rapid activation of specific responses** and **resistance to change**.

They also make a methodological point worth internalising: the claim that all behaviour is goal-driven "is not falsifiable" because researchers "could infer post hoc a near-endless supply of other goals." Beware the same trap in product reasoning — "the user must have wanted X" explains everything and therefore nothing.

From the 2007 work (Grade C): people with strong habits "repeated their past behavior regardless of their intentions, and the utility of intentions as predictors of behavior declined as habit strength increased."

**Note on cue-routine-reward:** this three-part framing is Charles Duhigg's popularisation, not a term from the primary literature. The academic version is context-cue → response association strengthened by reward *during learning*, after which reward is no longer required to trigger the response. The difference matters: the pop version implies you must keep delivering rewards forever. The research says reward builds the association, then the cue does the work.

### Home Screen implication
The strongest habit lever available to an app is **being the same thing in the same place at the same time**. A Home Screen whose layout, ordering, or hero content shuffles daily is actively destroying the cue-response associations it needs. Personalisation that reorders the screen is in direct tension with habit formation. Stability beats novelty.

---

## 5. Self-Determination Theory, and the gamification problem

**Grade A** for Ng et al. (2012), *Perspectives on Psychological Science* 7(4), 325-340, [PDF](https://selfdeterminationtheory.org/SDT/documents/2012-NgNtoumanis_PPS.pdf) — read the results section directly.

184 independent data sets in health care and health promotion. Meta-analysed correlations:

- Autonomy-supportive climate → basic need satisfaction: **ρ = .31 to .48**
- Autonomy-supportive climate → autonomous self-regulation: **ρ = .21 to .42**
- Needs and autonomous regulation → positive mental health: **ρ = .22 to .62**
- Needs and autonomous regulation → physical health indices: **ρ = .07 to .67**
- Controlled regulation and amotivation → poorer mental health: **ρ = .13 to .46**
- Autonomy-supportive climate → physical health: **ρ = .08 to .39** (small to moderate)

Two honest caveats from the paper itself. Need satisfaction → healthy diet had confidence intervals encompassing zero (ρ = .07 to .14), so diet is the weakest link. And the controlling-climate results rest on a single study, which the authors flag.

The practically important asymmetry: **autonomous motivation predicts good outcomes; controlled motivation (external pressure, introjected guilt) predicts worse mental health.** Pressure is not neutral. It is negatively valenced.

### Does gamification undermine intrinsic motivation?

**Grade C** for Deci, Koestner & Ryan (1999), *Psychological Bulletin* 125, 627-668 — search summary only, primary not fetched. 128 studies. Engagement-contingent, completion-contingent and performance-contingent rewards undermined free-choice intrinsic motivation at **d = −0.40, −0.36 and −0.28** respectively. Tangible expected rewards were the problem; the undermining effect is specific to *contingent, expected, tangible* rewards.

**Grade C** for the modern gamification meta-analytic picture ([Springer, ETR&D 2024](https://link.springer.com/article/10.1007/s11423-023-10337-7); [Educational Psychology Review 2020](https://link.springer.com/article/10.1007/s10648-019-09498-w)): overall effects are small and positive, but gamification "can both facilitate and undermine intrinsic motivation through supporting or thwarting the basic psychological needs for autonomy and competence." The two recurring failure modes identified are **lack of perceived competence** and **lack of perceived autonomy** in gamified conditions.

### The strongest counter-evidence: it does work, when it is not points-for-points' sake

**Grade B.** Two large RCTs from Patel's group:

**STEP UP** ([JAMA Internal Medicine 2019](https://jamanetwork.com/journals/jamainternalmedicine/fullarticle/2749761)), n = 602 overweight/obese adults, 24 weeks + 12-week follow-up. Mean daily steps vs control during intervention: support +689 (95% CI 267-977), collaboration +637 (258-1017), competition +920 (513-1328). During follow-up after the intervention stopped: support +428 (19-837), collaboration +126 (−235 to 488, not significant), competition +569 (142-996). Only competition remained clearly significant.

**BE ACTIVE** ([Circulation 2024](https://pmc.ncbi.nlm.nih.gov/articles/PMC11795842/)), n = 1,062 high cardiovascular risk patients, 12-month intervention + 6-month follow-up. Adjusted mean daily steps vs control during intervention: gamification +538.0 (186.2-889.9), financial incentives +491.8 (139.6-844.1), both +868.0 (516.3-1219.7). At 6-month follow-up after everything stopped: gamification +459.8 (82.0-837.6, still significant), financial incentives +327.9 (−50.2 to 706.0, **not** significant), both +576.2 (198.5-954.0).

Read that carefully. **Gamification survived withdrawal. Pure financial incentive did not.** That is the SDT prediction playing out in a cardiology trial: the controlled, externally contingent lever decayed; the socially and competence-oriented one held.

But also note the absolute size: roughly 500-900 extra steps a day. Real, clinically useful, and nowhere near the transformation that app marketing implies.

### Home Screen implication
Design for competence (visible, attainable, self-referenced progress) and autonomy (user chooses what is tracked and what is shown), and treat any points/badges/leaderboard mechanic as a controlled reward that carries a documented risk of undermining the motivation it was added to boost. Self-comparison over social ranking by default.

---

## 6. Dopamine, reward prediction error, and where the pop framing breaks

**Grade B.** Read [Understanding dopamine and reinforcement learning: the dopamine reward prediction error hypothesis](https://pmc.ncbi.nlm.nih.gov/articles/PMC3176615/) (PMC). Schultz's own reviews are behind paywalls I could not fetch ([Nature Reviews Neuroscience 2016](https://www.nature.com/articles/nrn.2015.26), [Dialogues Clin Neurosci 2016](https://www.tandfonline.com/doi/full/10.31887/DCNS.2016.18.1/wschultz) — both 403 or unfetchable, so **[UNVERIFIED]** for their exact wording).

What is solid: "The phasic activity of midbrain dopamine neurons encodes a reward prediction error used to guide learning." Dopamine neurons fire above baseline for better-than-predicted outcomes, stay at baseline for fully predicted outcomes, and dip below baseline for worse-than-predicted outcomes. After learning, the response shifts from the reward to the *cue* that predicts it.

What the review explicitly flags as unresolved:

- **Asymmetry.** Positive prediction errors produce much larger firing increases than negative errors produce decreases; "dopamine neurons seemed fairly insensitive to negative prediction errors."
- **Aversive responses.** Ungless et al. showed "some dopamine neurons in the VTA respond positively to aversive stimuli."
- **Non-RPE populations.** Matsumoto and Hikosaka documented dopamine neurons that "clearly do not encode a reward prediction error."
- **Tonic dopamine is barely modelled.** The theory covers phasic bursts almost exclusively.
- **Competing accounts exist**, notably Berridge's incentive salience (wanting ≠ liking) and Redgrave/Gurney's attention/novelty account.

And the one that matters most for product people: **the RPE hypothesis does not claim dopamine mediates pleasure.** It is a learning signal about value error, not a hedonic signal.

### The pop-science version to reject

"Dopamine loop", "dopamine hit", "hijack the reward circuit" are marketing language, not neuroscience. **Grade D** for the entire genre. Two specific things product teams say that are not supported:

1. **"Variable rewards create stronger habits than predictable ones, therefore randomise the reward."** Variable-ratio schedules do produce high, persistent response rates in operant conditioning — that part is real and old (Skinner). But the leap from pigeon key-pecking to "put a surprise in your health app" is unevidenced, and in health specifically it collides with the trust problem (section 10). I found no RCT showing variable rewards outperform fixed acknowledgement in a health app. The Hook-model framing traces to product literature, not to trials.
2. **"Anticipation feels better than the reward."** This is a garbled restatement of the cue-shift finding. The RPE signal moves to the predictive cue; that is a statement about a learning signal, not about subjective pleasure.

**Grade C** for the strongest available check on this: a [meta-analysis of persuasive design in 92 RCTs of mental health apps](https://pmc.ncbi.nlm.nih.gov/articles/PMC12041226/) found apps beat controls at Hedges' g = 0.43, but **no relationship between the number of persuasive design principles used and programme completion (r = 0.21, p = 0.43), and none between persuasive principles and efficacy (b = 0.01, p = 0.804).** Piling on persuasive mechanics did not help engagement or outcomes.

### Home Screen implication
Do not build a variable-reward surprise mechanic. There is no health-app evidence for it, and it directly damages the perceived reliability of a screen whose job is to report the user's real body data. Predictable, immediate, honest acknowledgement is the defensible choice.

---

## 7. Prospect Theory, loss aversion, and the size of the effect

**Grade C** across this section — I read search summaries and abstracts, not the primary meta-analyses.

Kahneman & Tversky's Prospect Theory posits that losses loom larger than equivalent gains, with the canonical coefficient λ ≈ 2.25 (Tversky & Kahneman 1992).

The replication debate has three positions and they are not the same claim:

**1. Gal & Rucker (2018)**, *Journal of Consumer Psychology* 28, 497-516, ["The Loss of Loss Aversion: Will It Loom Larger Than Its Gain?"](https://myscp.onlinelibrary.wiley.com/doi/abs/10.1002/jcpy.1047). Argue "current evidence does not support that losses, on balance, tend to be any more impactful than gains" and that the flagship supporting effects (endowment effect, status quo bias) have multiple alternative explanations. Note: this is a **re-interpretation argument, not a failed replication**. The basic risky-choice finding does replicate.

**2. Brown, Imai, Vieider & Camerer (2024)**, [*Journal of Economic Literature*](https://www.aeaweb.org/articles?id=10.1257%2Fjel.20221698). 607 estimates from 150 articles. Mean λ = **1.955**, 95% interval [1.820, 2.102]. Close to the classic 2.25. Losses weighted roughly twice gains.

**3. The re-analyses that cut it down.** [Yechiam & Zeif (2025)](https://yeldad.net.technion.ac.il/files/2025/02/YZ_2025.pdf), "Loss aversion is not robust: a re-meta-analysis", restrict Brown et al.'s dataset to symmetric gain/loss ranges with non-ordered presentation and get **λ ≈ 1.07**, not significantly different from 1. [Walasek, Mullett & Stewart (2024)](https://wrap.warwick.ac.uk/id/eprint/185745/13/1-s2.0-S0167487024000485-main.pdf) re-analysed raw data from 17 studies and report **median λ = 1.31, with only 6 of 19 studies showing statistically significant loss aversion.**

**Honest summary:** loss aversion probably exists, is context-dependent, and is somewhere between "barely there" and "about 2x" depending on how you measure it. It is not a reliable 2.25x multiplier you can design around.

### The health-message version is weaker still

**Grade C.** O'Keefe & Jensen's meta-analyses ([*Journal of Communication* 2009](https://onlinelibrary.wiley.com/doi/abs/10.1111/j.1460-2466.2009.01417.x), 53 studies, N = 9,145) find gain-framed appeals slightly more persuasive for *prevention* behaviours and loss-framed appeals slightly more persuasive for *detection* behaviours, but the effects are **small** and later syntheses describe framing effects as having "negligible direct effects when aggregated across diverse contexts."

### Home Screen implication
Do not lean on loss framing. The effect is contested, small in health messaging specifically, and — per SDT — the pressure it creates is a controlled motivator associated with worse mental health outcomes. A health app that says "you'll lose your progress" is trading a contested small persuasive gain for a documented motivational cost.

---

## 8. Goal gradient, endowed progress, streaks

**Grade C** for the primary marketing papers (search summaries).

**Goal gradient** — [Kivetz, Urminsky & Zheng (2006)](https://journals.sagepub.com/doi/abs/10.1509/jmkr.43.1.39), *Journal of Marketing Research* 43, 39-58. Café customers on a buy-10-get-1 card bought coffee more frequently as they approached the reward. Web users rated more songs per session and were less likely to quit a session as they neared the threshold. Critically: **participants slowed down after earning the first reward, then re-accelerated as they neared the second.** This "post-reward reset" is the part product teams forget.

**Endowed progress** — [Nunes & Drèze (2006)](https://academic.oup.com/jcr/article-abstract/32/4/504/1787425), *Journal of Consumer Research* 32(4), 504-512. Car wash field study, 300 loyalty cards. Group A: 8 stamps needed, start at 0/8. Group B: 10 stamps needed, start at 2/10 already stamped. Identical real effort. **Completion: 19% (A) vs 34% (B).** Reframing "not yet begun" as "already underway" nearly doubled completion.

**Streaks.** This is where the evidence gets thin and the product folklore gets loud.

**Grade D.** The widely repeated Duolingo claims — 600+ streak experiments over four years, streak freezes increasing DAU, "reducing user anxiety about streak loss appears to increase long-term engagement" — come from [vendor and trade blogs](https://trophy.so/blog/the-psychology-of-streaks-how-sylvi-weaponized-duolingos-best-feature-against-them), not published research. I could not find a peer-reviewed source. **[UNVERIFIED]** — do not cite these numbers as fact. But note the *direction* is consistent with everything else in this document: the mitigation (streak freeze) increased retention relative to the raw loss-aversion mechanic.

The recurring qualitative critique across those sources — "performative learning" where users open the app, tap the cheapest possible action, and leave — is a real design risk worth naming even if the citation is weak. It is the engagement-metric version of Goodhart's law.

**Grade A cross-check:** Lally's data (section 3) says a single missed day costs 0.29 points of automaticity out of 42 and recovers fully. A streak mechanic tells the user a single missed day costs everything. **The streak lies about the biology.**

### Home Screen implication
Endowed progress is the strongest, cheapest, best-evidenced mechanic here: never show a user an empty 0-of-N state if any prior signal can legitimately fill it. Goal gradient says the acceleration is real but resets after each reward, so favour continuous or rolling progress over discrete milestones that create a post-reward slump. And any streak needs a forgiveness mechanic built in from day one, because the unforgiving version contradicts the habit data.

---

## 9. Progress visualisation and the Zeigarnik effect

### Progress monitoring works. This is the best-evidenced item in the whole document.

**Grade A.** [Harkin et al. (2016)](https://www.apa.org/pubs/journals/releases/bul-bul0000025.pdf), "Does Monitoring Goal Progress Promote Goal Attainment? A Meta-Analysis of the Experimental Evidence", *Psychological Bulletin* 142(2), 198-229. **138 studies, N = 19,951**, all randomised.

- Interventions increased frequency of progress monitoring: **d+ = 1.98, 95% CI [1.71, 2.24]**
- Progress monitoring promoted goal attainment: **d+ = 0.40, 95% CI [0.32, 0.48]**
- The effect was **mediated** by change in monitoring frequency — the mechanism checks out.
- **Moderators:** larger effects when outcomes were **reported or made public**, and when the information was **physically recorded**.

That is a solid small-to-medium effect from a large, experimental, mediation-tested evidence base. Showing people their progress genuinely helps.

### The Zeigarnik effect does not replicate

**Grade C** ([2025 meta-analysis in *Humanities and Social Sciences Communications*](https://www.nature.com/articles/s41599-025-05000-w) — I could not fetch past the Nature paywall redirect, so the numbers below come from search summaries and are **[UNVERIFIED]** in detail).

The finding: **no memory advantage for unfinished tasks.** The Zeigarnik effect "lacks universal validity" and the recall advantage largely disappears once Zeigarnik's own original data is excluded. The related **Ovsiankina effect** — the tendency to *resume* interrupted tasks — did hold up as a general tendency.

This is a meaningful split for design. "Leave it incomplete so they remember it" is not supported. "Leave it incomplete and they will tend to come back and finish it" is better supported.

### Home Screen implication
Progress visualisation is not decoration, it is the intervention. But the Zeigarnik-flavoured pattern of deliberately leaving things unfinished to nag at people has no memory-based justification. Use incompleteness as a resumption cue (Ovsiankina), not as a memory trick.

---

## 10. Behaviour change techniques: which ones actually work digitally

**Grade B.** [Michie's BCT Taxonomy v1](https://www.ncbi.nlm.nih.gov/books/NBK327624/) defines 93 techniques in 16 clusters. The practical question is which of the 93 survive in digital trials.

**Grade A** for the key answer: [meta-analysis of BCTs for physical activity in adults with overweight/obesity](https://pmc.ncbi.nlm.nih.gov/articles/PMC8365685/), 62 studies, 5,671 participants (3,115 digital / 2,556 face-to-face).

Overall effects: **digital SMD = 0.42 (95% CI 0.28-0.57, k = 39)**; face-to-face SMD = 0.78 (0.51-1.01, k = 35). Digital works, and works about half as well as in-person.

Significant moderators **in digital interventions**:

| BCT | β | p | adj R² |
|---|---|---|---|
| Social incentive | +2.37 | <0.001 | 0.51 |
| Goal setting (behaviour) | +0.89 | 0.001 | 0.20 |
| Graded tasks | +0.87 | 0.008 | 0.17 |
| Goal setting (outcome) | +0.76 | 0.011 | 0.15 |
| **Self-monitoring of behaviour** | **−1.04** | **0.001** | **0.23** |

In multivariate analysis only **goal setting (behaviour)** and **social incentive** survived. In face-to-face, the winner was behavioural practice/rehearsal (β = 1.83).

**Do not skim past the negative coefficient.** Self-monitoring of behaviour was a *significant negative* moderator in digital interventions here. That is one meta-analysis in one behaviour domain and it contradicts Harkin's progress-monitoring result and Michie's earlier control-theory finding, so it is not settled. But it is a real, published, statistically significant warning that "add more self-tracking" is not automatically good in a digital context. My reading of the tension: Harkin studied *monitoring goal progress* (comparing state to goal), while this coded *self-monitoring of behaviour* (raw logging). Progress against a goal helps; raw data logging on its own may not.

**Grade C** for [Michie et al. (2009)](https://core.ac.uk/download/pdf/17050054.pdf): interventions combining self-monitoring with at least one other control-theory technique (intention formation, specific goal setting, feedback on performance, review of goals) were significantly more effective than those without. The review itself cautions that effects "may be overestimated due to publication bias and weak control conditions."

**Grade B** for what commercial apps actually ship: [Edwards et al. (2016), *BMJ Open*](https://pubmed.ncbi.nlm.nih.gov/27707829/). Of 1,680 health apps screened, only 64 (4%) had meaningful gamification. Median 14 BCTs per app (range 5-22). Most common: self-monitoring of behaviour (86%), **non-specific reward (82%), non-specific incentive (82%)**, social support unspecified (75%), focus on past success (73%). By cluster: feedback and monitoring 94%, reward and threat 81%, goals and planning 81%. **No correlation between user rating and game content or price.** In plain terms: the market ships vague rewards at scale, and there is no evidence it produces better apps.

### Home Screen implication
Goal setting on *behaviour* (not just outcome) and graded tasks are the two evidence-backed things a Home Screen can carry cheaply. Social incentive is the strongest moderator but is the hardest to do without triggering the SDT controlled-motivation problem — self-referential or supportive framing, not ranking. Raw data logging without a goal reference is not automatically beneficial and may be harmful.

---

## 11. Emotional design, trust, and algorithmic advice

### Norman's three levels

**Grade B.** [Don Norman, jnd.org](https://jnd.org/emotional-design-people-and-things/), his own words: "Visceral design refers primarily to that initial impact, to its appearance. Behavioral design is about look and feel — the total experience of using a product. And reflection is about ones thoughts afterwards, how it makes one feel, the image it portrays, the message it tells others about the owner's taste."

He also warns against reading this as "make it pretty": his Jacob Jensen clock example demonstrated "all of the conflicts in design: appearance, functionality, prestige, and price. Beautiful, prestigious, yet unusable." A tester said, "I'm dying to buy this, but I couldn't. I couldn't use it."

And: "Products differ in their appeal on the three design dimensions, but so too do people and situations."

**Grade C / [UNVERIFIED]** for the widely quoted "attractive things work better" mechanism (positive affect broadening problem-solving, anxiety narrowing focus) — this is from *Emotional Design* the book, which I did not fetch. The "trust formed in 50 milliseconds" claim I saw repeated in secondary sources traces to Lindgaard et al. on web page aesthetics, which I did not verify this session. **Do not cite the 50ms figure.**

### Trust in health tech is the actual constraint

**Grade C.** [Deloitte](https://www.deloitte.com/us/en/insights/industry/technology/wearable-technology-healthcare-data.html): among smartwatch/fitness tracker users, 40% are concerned about privacy of device-collected data, rising to 60% when they subscribe to a service that produces reports from that data. **The act of turning raw data into a score increases distrust.**

**Grade C.** [App review analysis (arXiv 2208.10705)](https://arxiv.org/pdf/2208.10705): trust concerns — accuracy, health efficacy, transparency and clarity, scientific reliability — account for roughly half of all user concerns about smart health components.

**Grade D** but pointed: [a critique of recovery scores](https://rachelepojednic.substack.com/p/should-you-trust-your-wearable-what) notes no major manufacturer discloses how their readiness/recovery score is calculated, and that Whoop and Oura can return contradictory verdicts on the same physiology. **[UNVERIFIED]** as a systematic claim, but the risk it names is real for any composite score.

### Algorithm aversion vs algorithm appreciation

**Grade C** for both sides, search summaries only.

- **Dietvorst et al. (2015)**: people abandon algorithms faster than humans after seeing them err, even when the algorithm outperforms.
- **Logg et al. (2019)**: people adhere *more* to advice labelled as algorithmic than the same advice labelled as human.

These are not actually contradictory. The reconciliation in the literature is that appreciation is the default for objective/numeric tasks with naive users, and aversion kicks in after **observed error** and in domains people consider subjective or personal. Health is exactly the domain where users feel expert about themselves.

### Calibrated trust

**Grade C.** From [work on appropriate reliance](https://www.tandfonline.com/doi/full/10.1080/12460125.2025.2593251) and [trust calibration reviews](https://pmc.ncbi.nlm.nih.gov/articles/PMC12562135/):

- Trust is the attitude; reliance is the behaviour. **Calibrated trust means trust matching actual system capability.**
- Automation bias "persists even among expert users and is not reliably eliminated by training."
- Communicating **both point estimates and confidence intervals** produces better decisions than point estimates alone.
- But **showing a confidence number alone is insufficient**, and explanations themselves can become trust heuristics that *worsen* over-reliance when the advice is wrong.

### Home Screen implication
A single opaque composite score is the highest-risk element you can put on a health Home Screen. It maximises the thing that drives distrust (opaque derivation), it is the exact case where algorithm aversion applies (personal domain, user feels expert), and one visibly wrong day poisons trust in everything else. If a score exists, it must show what it was built from and how confident it is, and it must degrade gracefully when input data is thin.

---

## 12. Choice architecture, defaults, and the nudge effect-size collapse

**Grade B.** [Mertens et al. (2022), PNAS](https://www.pnas.org/doi/10.1073/pnas.2204059119) meta-analysed 447 effect sizes and reported nudging works at **Cohen's d = 0.43 [0.38, 0.48]**. This is the number everyone quotes.

**Grade A** for the rebuttal: [Maier, Bartoš, Stanley, Shanks, Harris & Wagenmakers (2022), "No evidence for nudging after adjusting for publication bias", PNAS](https://pmc.ncbi.nlm.nih.gov/articles/PMC9351501/). Same 334 effect sizes, run through Robust Bayesian Meta-Analysis:

- Unadjusted: **d = 0.43 [0.38, 0.48]**
- Bias-adjusted: **d = 0.04 [0.00, 0.14]**
- Overall Bayes factor: BF₀₁ = 0.95 (absence of evidence, not evidence of absence)
- Egger coefficient b = 2.10, described as "severe publication bias"
- Strong evidence *against* an effect for information interventions (BF₀₁ = 33.84) and the finance domain (BF₀₁ = 41.23)
- Undecided for structure interventions (BF₀₁ = 1.12) and the food domain (BF₀₁ = 5.16)

Their conclusion: "after correcting for this bias, no evidence remains that nudges are effective as tools for behaviour change."

Read the domain breakdown carefully, because it is the actionable part. **Information nudges are the ones with strong evidence against them.** Structure nudges — changing defaults, changing what is physically or visually easiest — are the ones still undecided rather than refuted. That maps cleanly onto Fogg: changing the environment (ability) survives better than telling people things (motivation).

### Home Screen implication
Defaults and ordering are the legitimate levers because they are structural. Informational nudge copy — tips, facts, "did you know" — is the specific category the bias-corrected evidence argues hardest against. Cut it.

---

## 13. Self-tracking harms

**Grade B.** [Systematic review of 67 empirical studies (2013-2020), *JMIR*](https://pmc.ncbi.nlm.nih.gov/articles/PMC8493454/). Benefits are real: better understanding of sleep and activity, chronic disease management, increased patient agency. But the documented harms:

- "Depression and anxiety" when tracking data reveals health problems
- Emotional distress when data is "invisible or inaccurate", leading users to "refuse to use self-tracking devices"
- "Obsessive tracking" risk, flagged particularly in some clinical populations
- "Wrong and unreasonable usage of weight loss apps may contribute to and exacerbate eating disorders"
- Abandonment driven by perceived "inaccuracy and uselessness"
- Users deploying "resistance strategies" including selective tracking to escape perfectionism pressure

The authors explicitly note this is **understudied** and call for research on "the dark side of self-tracking" and "adverse psychosocial consequences." Absence of a large harms literature is not evidence of safety.

**Grade C** for the disordered-eating link ([National Alliance for Eating Disorders](https://www.allianceforeatingdisorders.com/health-tracking-apps-and-disordered-eating/), [BJPsych Open qualitative study](https://www.cambridge.org/core/journals/bjpsych-open/article/effects-of-diet-and-fitness-apps-on-eating-disorder-behaviours-qualitative-study/2D1EE739D97AB3EFC6573835E4C527BD), Simpson & Mazzeo 2017): app-based self-monitoring of diet and activity is associated with greater disordered eating behaviours in emerging adults. Participants described "a fixation on numbers, fuelled heavily by the app's quantification". The direction of causation is not established — people prone to disordered eating may select into tracking apps. The honest position: **association, plausible bidirectional, not proven causal.**

**Grade C** for attrition context: Eysenbach's "law of attrition" — substantial dropout is the norm in every eHealth trial. Reported ranges: attrition 5.3% to 87% (median 18.4%); roughly **71% of app users disengage within 90 days**. Notably, one narrative review reports attrition was lower in trials with reminders or human support **and in apps *without* gamification features** ([BMC Digital Health](https://link.springer.com/article/10.1186/s44247-024-00105-9)). That is a direct challenge to the assumption that gamification retains.

**Grade C** on habituation: the [JITAI literature](https://academic.oup.com/abm/article/52/6/446/4733473) defines habituation as "an objective decline in physiological and/or behavioral response to an intervention over repeated exposures" and treats it as a core design constraint — recommending message banks and varied signal types specifically to delay it.

### Home Screen implication
Assume some fraction of your users are harmed by the screen you are designing. Build the escape hatch: let people hide metrics, turn off scores, and see their own data without a verdict attached. This is not a nice-to-have; it is the only mitigation the literature actually offers.

---

## What survives: the short version

**Well evidenced, build on it:**
1. Progress monitoring against a goal (Harkin, d = 0.40, 138 RCTs, mediation confirmed)
2. Endowed progress (Nunes & Drèze, 19% → 34%)
3. Goal setting on behaviour, and graded tasks, in digital interventions
4. Context stability as the habit mechanism (Wood & Neal)
5. Autonomy and competence support (Ng et al., ρ = .21 to .62 across health outcomes)
6. Missing one day is genuinely fine (Lally, 0.29 of 42 points, fully recovered)

**Contested or small, do not build load-bearing structure on it:**
7. Loss aversion (λ somewhere between 1.07 and 2.0 depending on method)
8. Message framing (statistically significant, practically negligible)
9. Nudge in general (d = 0.43 → 0.04 after publication-bias correction)
10. Gamification (works in trials with social/competence design; undermines when it is contingent tangible reward)

**Not supported, stop citing it:**
11. Zeigarnik memory advantage for unfinished tasks (does not replicate)
12. "Dopamine loop" / variable reward as a health-app design principle (no health trial evidence)
13. "Habits form in 21 days" or "in a day or two" (Lally: median 66, range 18-254, and half never got there)
14. "More persuasive features = more engagement" (92 RCTs: r = 0.21, p = 0.43, no relationship)
15. Informational nudges (strong Bayesian evidence *against*, BF₀₁ = 33.84)

---

## Sources

Primary text read this session (Grade A):
- Fogg, B.J. (2009). A Behavior Model for Persuasive Design. Persuasive'09. https://www.demenzemedicinagenerale.net/images/mens-sana/Captology_Fogg_Behavior_Model.pdf
- Lally, P., van Jaarsveld, C.H.M., Potts, H.W.W. & Wardle, J. (2010). How are habits formed. *Eur. J. Soc. Psychol.* 40, 998-1009. https://emotionalfirstaidacademy.com/wp-content/uploads/2023/10/How-habits-are-formed.pdf
- Wood, W., Mazar, A. & Neal, D.T. (2021). Habits and Goals in Human Behavior. *Perspectives on Psychological Science*. https://dornsife.usc.edu/wendy-wood/wp-content/uploads/sites/183/2023/10/Wood.Mazar_.Neal_.2021.pdf
- Harkin, B. et al. (2016). Does Monitoring Goal Progress Promote Goal Attainment? *Psychological Bulletin* 142(2). https://www.apa.org/pubs/journals/releases/bul-bul0000025.pdf
- Ng, J.Y.Y. et al. (2012). Self-Determination Theory Applied to Health Contexts. *Perspectives on Psychological Science* 7(4). https://selfdeterminationtheory.org/SDT/documents/2012-NgNtoumanis_PPS.pdf
- Maier, M. et al. (2022). No evidence for nudging after adjusting for publication bias. *PNAS*. https://pmc.ncbi.nlm.nih.gov/articles/PMC9351501/
- Effective BCTs to promote physical activity (2021 meta-analysis). https://pmc.ncbi.nlm.nih.gov/articles/PMC8365685/

Fetched pages (Grade B):
- https://www.behaviormodel.org/
- https://tinyhabits.com/rewire/
- https://jnd.org/emotional-design-people-and-things/
- https://pmc.ncbi.nlm.nih.gov/articles/PMC3176615/ (dopamine RPE hypothesis and its limits)
- https://pmc.ncbi.nlm.nih.gov/articles/PMC12041226/ (persuasive design, 92 RCTs)
- https://pmc.ncbi.nlm.nih.gov/articles/PMC8493454/ (self-tracking systematic review, 67 studies)
- https://pmc.ncbi.nlm.nih.gov/articles/PMC11795842/ (BE ACTIVE trial)
- https://jamanetwork.com/journals/jamainternalmedicine/fullarticle/2749761 (STEP UP trial)
- https://pubmed.ncbi.nlm.nih.gov/27707829/ (Edwards 2016, gamification BCTs in apps)

Searched, summary only (Grade C):
- https://onlinelibrary.wiley.com/doi/abs/10.1002/ejsp.674 (Lally, publisher page — paywalled, 402)
- https://dornsife.usc.edu/wendy-wood/wp-content/uploads/sites/183/2023/10/wood.neal_.2007psychrev_a_new_look_at_habits_and_the_interface_between_habits_and_goals.pdf
- https://home.ubalt.edu/tmitch/642/articles%20syllabus/Deci%20Koestner%20Ryan%20meta%20IM%20psy%20bull%2099.pdf
- https://myscp.onlinelibrary.wiley.com/doi/abs/10.1002/jcpy.1047 (Gal & Rucker 2018)
- https://www.aeaweb.org/articles?id=10.1257%2Fjel.20221698 (Brown et al. 2024 loss aversion meta)
- https://yeldad.net.technion.ac.il/files/2025/02/YZ_2025.pdf (Yechiam & Zeif 2025)
- https://wrap.warwick.ac.uk/id/eprint/185745/13/1-s2.0-S0167487024000485-main.pdf (Walasek et al. 2024)
- https://academic.oup.com/jcr/article-abstract/32/4/504/1787425 (Nunes & Drèze 2006)
- https://journals.sagepub.com/doi/abs/10.1509/jmkr.43.1.39 (Kivetz et al. 2006)
- https://www.nature.com/articles/s41599-025-05000-w (Zeigarnik/Ovsiankina meta-analysis 2025 — paywall redirect, numbers unverified)
- https://onlinelibrary.wiley.com/doi/abs/10.1111/j.1460-2466.2009.01417.x (O'Keefe & Jensen 2009)
- https://www.ncbi.nlm.nih.gov/books/NBK327624/ (BCT Taxonomy v1)
- https://core.ac.uk/download/pdf/17050054.pdf (Michie et al. 2009)
- https://link.springer.com/article/10.1007/s11423-023-10337-7 (gamification and intrinsic motivation meta-analysis)
- https://link.springer.com/article/10.1007/s10648-019-09498-w (gamification of learning meta-analysis)
- https://www.pnas.org/doi/10.1073/pnas.2204059119 (Mertens et al. 2022)
- https://www.tandfonline.com/doi/full/10.1080/12460125.2025.2593251 (appropriate reliance on AI decision support)
- https://pmc.ncbi.nlm.nih.gov/articles/PMC12562135/ (trust in AI in healthcare, 30-year review)
- https://link.springer.com/article/10.1186/s44247-024-00105-9 (engagement and retention in digital mental health)
- https://academic.oup.com/abm/article/52/6/446/4733473 (JITAI design principles, habituation)
- https://www.deloitte.com/us/en/insights/industry/technology/wearable-technology-healthcare-data.html
- https://arxiv.org/pdf/2208.10705 (user concerns in mHealth app reviews)
- https://www.cambridge.org/core/journals/bjpsych-open/article/effects-of-diet-and-fitness-apps-on-eating-disorder-behaviours-qualitative-study/2D1EE739D97AB3EFC6573835E4C527BD
- https://www.allianceforeatingdisorders.com/health-tracking-apps-and-disordered-eating/

Weak sources, cited only to name a risk, not as evidence (Grade D):
- https://trophy.so/blog/the-psychology-of-streaks-how-sylvi-weaponized-duolingos-best-feature-against-them (Duolingo streak claims — unverified)
- https://rachelepojednic.substack.com/p/should-you-trust-your-wearable-what (recovery score opacity — unverified)

Could not fetch (paywalled or 403), so nothing in this document depends on them:
- Schultz, W. (2016). Dopamine reward prediction-error signalling. *Nature Reviews Neuroscience*. https://www.nature.com/articles/nrn.2015.26
- Schultz, W. (2016). Dopamine reward prediction error coding. *Dialogues in Clinical Neuroscience*. https://www.tandfonline.com/doi/full/10.31887/DCNS.2016.18.1/wschultz
- BE ACTIVE, publisher version. https://www.ahajournals.org/doi/10.1161/CIRCULATIONAHA.124.069531

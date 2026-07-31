# Laso Home v2 — Design Director's Recommendation

**Date:** 2026-07-29
**Decision:** build **08-the-band**, with seven named merges from the other nine concepts.
**Status:** this document supersedes the ten concept rationales. Where a concept `.md` and this
document disagree, this document is correct.

---

## 1. The scoreboard

### 1.1 Weighting, and why

| Lens | Weight | Justification |
|---|---:|---|
| **Behaviour change & 90-day retention** | **35%** | The brief's own defensible justification for everything it asks for is attrition, not cognition: ~53% of mHealth apps uninstalled within 30 days, mean engagement **4.1 days**, top abandonment reason declining motivation (31.6%) `[UX §12]`. A screen that does not close a behavioural loop cannot move that number no matter what it looks like. |
| **Comprehension under real conditions** | **35%** | The 5-second timeline in §6 is the only performance spec in the brief with a stated deadline. ~40% of US adults have inadequate graph literacy, ~1 in 3 have low graph literacy *and* low numeracy `[CL §11]`. If the 0-1s channel does not work at a squint on a 5.4" screen at 6:45am, nothing downstream matters. |
| **Craft and product feel** | **15%** | The brief opens with "**None of this is a styling problem. Do not solve it with a nicer card.**" Craft is the multiplier on a correct concept, not the concept. It is weighted enough to break ties, not enough to win one. |
| **Brief compliance** | **15% + a hard gate** | Compliance is scored low as a *number* because it is pass/fail in substance — the §3 bans say "a concept that violates one is rejected, not debated." Scoring it heavily would double-count the gate below. |

### 1.2 The gate

Two caps, applied to the **default loaded morning** (full wearable, moderate day, 390×844) — the
state the budgets govern:

- **Breach of a §3 ban → capped at 65.**
- **Breach of a §8 non-negotiable → capped at 70.**

Budget overruns (words, numbers, tap targets) are **not** gated. They are counted inside the
compliance score. A ban is a design decision; a budget is a dial.

### 1.3 The table

| # | Concept | Behaviour ×.35 | Comprehension ×.35 | Craft ×.15 | Compliance ×.15 | Raw | Gate | **Final** |
|---:|---|---:|---:|---:|---:|---:|---|---:|
| **1** | **08-the-band** | 58 | 87 | 88 | 78 | 75.7 | — | **75.7** |
| 2 | 10-tomorrow | 78 | 78 | 60 | 66 | 73.5 | — | **73.5** |
| 3 | 09-because | 64 | 71 | 85 | 68 | 70.2 | — | **70.2** |
| 4 | 07-coach | 70 | 91 | 71 | 71 | 77.7 | **N4 → 70** | **70.0** |
| 5 | 04-sleep-first | 54 | 79 | 76 | 65 | 67.7 | — | **67.7** |
| 6 | 02-daily-briefing | 76 | 80 | 86 | 46 | 74.4 | **F5 → 65** | **65.0** |
| 7 | 03-body-budget | 82 | 70 | 58 | 61 | 71.1 | **F12 → 65** | **65.0** |
| 8 | 06-todays-story | 72 | 60 | 64 | 57 | 64.4 | **N8 → 70** | **64.4** |
| 9 | 05-mission-control | 68 | 58 | 62 | 36 | 58.8 | — | **58.8** |
| 10 | 01-one-number | 37 | 72 | 68 | 69 | 58.7 | **F5 → 65** | **58.7** |

Ranked: **08 · 10 · 09 · 07 · 04 · 02 · 03 · 06 · 05 · 01.**

### 1.4 Gate rulings, with the evidence

I opened the HTML on every disputed call rather than averaging the judges.

**01-one-number — F5, capped.** `62` renders at 56px as the single largest element on the
screen, in amber, with no directional-summary label anywhere above the fold. Tier 3 is explicit:
if Readiness survives on Home it "must not be the largest number" and "must be labelled a
directional summary." Both conditions fail. This concept makes the least-validated element in the
codebase its entire hero. Confirmed in the render.

**02-daily-briefing — F5, capped.** `.headline` is `font-size:32px`; `.numline .v` is
`font-size:36px`. Readiness 62 is the largest number *and* the largest single glyph run on the
screen, and the directional-summary label lives inside the collapsed `Why` panel. The concept's
own defence — "the number is 36px but neutral-coloured" — restates the breach rather than fixing
it. This is the saddest cap in the set: 02 is the second-best-crafted screen here and has the best
behavioural card in the set. It loses on a 4px decision it could have reversed.

**03-body-budget — F12, capped.** `blockBar()` draws the block field encoding today's budget
**and** a dashed ruler carrying a tick labelled `usual 50`, and the expander names a third anchor
(60, "what your best-rested days reach"). The code comment at line 498 states the defence — "The
dashed rule is a ruler to 'your usual', not a second range" — which is exactly the substitution-vs-
addition distinction F12 was written against. In the render the two do not even share a coordinate
system: the blocks stop well short of where the dashed rail runs, so they read as two scales that
disagree. Separately, `Today's budget 30 min` is an undisclosed-weight composite (base 60 −20 sleep
−10 recent load) rendered at 84px, wearing a borrowed unit. That is F5's substance dressed as a
Tier-1 unit, and it is worse than an honest index because minutes *imply* measurement.

**06-todays-story — N8, capped.** `centreOnNow()` calls `scrollTo({behavior:"smooth"})` on the
scroll container, and `nowIndex()` returns 1/2/3 by time of day. It fires on first paint. At 7am
the screen scrolls past "Last night", so first paint is a decapitated card fragment. The hero
designation *and* the scroll position both move with the clock — that is whole-screen morphing,
the Oura pre-2025 pattern the brief names by name as the thing designers attacked, not the
single-slot morphing that survived.

**07-coach — N4, capped.** `S.ctxPick` is written at line 933 and read at line 757 only, where it
appends an acknowledgement paragraph. `content()` never consults it, so on the quiet day the
instruction still reads "Carry on. Nothing to change today." while the paragraph directly beneath
says "Got it, I've marked you as unwell. I'll keep today easy and I won't push you." That is the
`MorningCheckIn` failure the brief bans by name, plus a self-contradiction on one screen —
`CRIT §5` in miniature. Second finding: `content()` sets `sure:null` on the default morning; the
"How sure I am" line exists only inside the collapsed `Why` panel. **Uncertainty mechanisms visible
on the default loaded morning = 0, not the claimed 1.**

I capped 07 at 70 rather than 65 because the mechanism it depends on genuinely exists
(`LifeContextStore` + advisor rung 0, `[CAP §4]`) and the fix is one function call. The cap is on
the artefact, not the idea — and 07 contributes more merged ideas than any other loser.

### 1.5 Two judge claims I overturned

**05-mission-control does NOT breach F5.** The compliance judge stated `.cl-num` renders Readiness
62 as the largest number. It does not: `.cl-num` is `font-size:28px` and `.tile.big .t-val` is
`font-size:30px`. The borrowed units are larger than the composite, exactly as the concept claims.
05 loses on budgets (22 numbers vs 12, 8 above fold vs 5, 31 words vs 20) and on Dynamic Type
truncation at 320pt — not on a ban. Its compliance score of 36 is harsher than the evidence
supports, but the correction does not change its rank.

**06-todays-story does NOT breach F5 either.** Every `.val` on the thread is `font-size:34px`, so
Readiness 62 is the same size as `6h 12m`. The concept's claim is true. 06 is capped on N8, which
is a real and independently-confirmed breach, not on F5.

### 1.6 The two systematic lies across the field

Worth recording because they will recur in the build:

1. **"Exactly one uncertainty mechanism" is false for four concepts.** 03, 05, 07 and 09 all claim
   1 and render **0** on the default loaded morning, because the honesty sentence sits inside a
   collapsed panel. Only 08 (band width) and 10 (the tapered rail) ship a mechanism the user can
   see without tapping. A confidence statement you must ask for is not a confidence statement.

2. **Words above the fold is understated everywhere except 08 and 05.** 02 declares 24 and renders
   ~53. 10 declares 30 and renders ~46. 04 declares 19 and renders ~35. The error is always the
   same: counting only the top card. 08 declares 44 against a real ~46 and flags it ❌ itself, and
   05 declares 31 accurately. **Honesty about a broken budget was rarer than meeting it.**

---

## 2. The winner, and why it is superior

**08-the-band.** Not because it scored highest — it is second-lowest on behaviour change, which is
my heaviest lens. It wins because of an asymmetry no other concept has:

> **08's failures are additions. Every other top-half concept's failures are subtractions.**

08 is missing a reminder, a completion affordance and a proof line. Those are three components that
fit inside its existing structure — it runs 5 blocks against a limit of 7, 7 numbers against 12,
and 3 exits against 6. Adding them costs one tap target and roughly a dozen words below the fold,
and changes nothing about what the screen *is*.

Compare the alternatives. 03's behaviour win is real and structural, but its pre-attentive channel
is dead at 6:45am *by construction* — the green blocks encode minutes already spent, so on the
morning open they are all empty. You cannot fix that without abandoning the concept. 10's refusal
to answer "how am I" is its thesis, not a bug. 02's Readiness-at-36px is the whole reason the
headline block exists. 07's first-person persona is not removable without removing the concept.

That asymmetry is the decision. But it is not the whole argument. Here is what 08 understands that
the other nine do not.

### 2.1 It found a way to make the brief's own central rule affordable

The brief's Appendix names three sentences that must be true after the redesign. The second is:

> *"Every number on screen carries a verdict. Either the number says whether it is good or bad
> against the user's own baseline, or the number does not render. There is no third state."*

Eight of ten concepts satisfy that for their hero and then quietly break it for everything else —
by collapsing the other signals behind a tap (04's "Everything else"), by pushing them below the
fold (07, 09, 10), or by not showing them at all (01, 03). 05 is the only other concept that
honoured it across every signal, and it paid **22 numbers against a budget of 12 — 83% over.**

08 is the only concept that changed the *unit cost of a verdicted signal*. The mechanism is one
decision:

> **Draw the band at the identical x-position on every bar, and never print its endpoints.**

Because the band is a shape and not a pair of numbers, four fully-verdicted signals cost **four
numbers** above the fold instead of twelve. And because every band sits at the same place, the four
markers form a readable column — one left, one centre, two right — that is a genuine non-textual
0-1s read, which is what the 5-second timeline actually demands.

That is not a styling trick. It is the only structural answer in the set to the tension between
"every number carries a verdict" and "≤5 numbers above the fold," which are both non-negotiable and
which every other concept resolved by breaking one of them.

### 2.2 Honesty and degradation are the same object

`const BAND_HALF = { full:16, phone:24, new:36 };` — one constant, applied to every bar.

The band widens when confidence drops. That single control satisfies **N5** (degrade, never
disappear), **T9** (exactly one uncertainty mechanism), and the cold-start problem **C8**, and it
does so with zero extra pixels and zero apology copy. A day-3 user sees the same four bars, drawn
dashed and enormously wide, with "still learning it" per row.

Every other concept needs a separate sentence for confidence — 07's coach line, 09's limit line,
02's dateline, 04's source line, 01's basis line — and **four of them put that sentence somewhere
the default morning never renders it.** 08's mechanism cannot be hidden, because it *is* the
geometry.

The retention consequence is the thing nobody else built: a user who joins on a phone and later
buys a watch **watches the bands narrow**. That is a visible, felt return on continued use, and it
is not a streak, so F9 cannot touch it.

### 2.3 It makes the app's restraint visible

On the default morning, resting heart rate reads `58 bpm · above`, the marker sits outside the
band, and the clause reads **"one morning only."** Nothing fires. The N3 gate — ≥5 bpm or ≥10% over
baseline sustained **3+ consecutive nights** — is rendered as copy rather than enforced invisibly.

Every other concept implements that gate correctly and keeps it secret. 08 is the only one where
the user can *see the app decline to alarm them*.

This is worth more than it looks. It is simultaneously:
- the cheapest available answer to the category's #1 churn trigger ("the score doesn't match how I
  feel") — it demonstrates the model has a threshold and states it;
- the strongest available orthosomnia mitigation short of the escape hatch, because it teaches the
  anxious user that an out-of-range morning is not an event;
- the cheapest trust purchase with the data-literate user, who is the cohort that punishes
  hand-waving hardest.

09 says the same thing in prose and says it better — *"We do not call that a change until it is 5
or more above your average for three mornings"* is the single best sentence written in the ten. But
09 says it inside a collapsed ledger. 08 puts it on the face of the screen for four words.

### 2.4 The bans are enforced at the formatter layer, not by discipline

Line 385: `FORMATTERS — borrowed units only. No index anywhere.` The `F` object contains h:mm,
steps, clock time, bpm, km, flights — and nothing else. **F5, F3 and the Tier-3 demotion are
structurally unviolatable**, because there is no code path that can emit an index.

Contrast 02, which kept Readiness and then had to defend a 4px type difference, and lost. Contrast
01, which kept Readiness and made it 56px. A constraint enforced by the type system beats a
constraint enforced by a design review, every time, on a screen that will be edited by twenty
people over three years.

Similarly: `posWord()` derives *under / inside / above* from value-vs-band at render time. The
plain word and the picture cannot disagree — which is the class of bug `B8` describes (a size test
labelled as a direction) and which 05 openly flags as its own weakest point.

### 2.5 It is the best-built screen in the set

The craft lens scored it 88, the highest of the ten, on system integrity: eight type sizes, one
accent colour, zero decorative gradients, 13% off-grid spacing, one repeated row grammar that
survives day 3, iPhone-only and full data without changing structure. It is the only concept where
the entire hero **plus** the action card fit above the fold at a true 375×812 with nothing
squished — which is the brief's explicit "design the top cluster on a 5.4" viewport first"
requirement, and the requirement most of the field failed.

And "Short night. You showed up." is the best line of copy anyone wrote. It states the deficit and
closes the guilt loop in the same breath, on the morning the user is most likely to uninstall. Two
of the four judges named it independently.

### 2.6 The honest counter-argument, stated

08 as built has neither Fogg's prompt nor Harkin's mechanism. No reminder. No completion. No
aggregate proof anywhere on the screen. The brief's §5 table ranks "action + aggregated proof, in
one card" as **the highest-scoring single component available (2.5)** and progress monitoring as
the best-evidenced item in the entire psychology corpus (138 studies, N=19,951, d+=0.40, mediation
confirmed). 08 ships neither. Its own §11 names the consequence: *"a screen with no failure state
gives a user with low intrinsic motivation nothing to push against."*

That is a real hole and it is the reason its behaviour score is 58. **It is also the one hole in
the top half of the field that closes without changing the concept.** That is the whole case.

---

## 3. What must be merged into it

Nine losing concepts. Seven contribute. Two do not, and I say so plainly.

### M1 — From **02-daily-briefing**: the complete action card, wholesale · **lands in Slot 2**

The single most valuable component built in this exercise, and it renders entirely above the fold
in 02's own screenshot:

```
TODAY
In bed by 10:30 tonight.
[ Done ]   [ Remind me tonight ]
Done 6 times. Those mornings you slept 38 minutes longer than usual.
```

It carries goal setting on behaviour (β=+0.89), graded task (β=+0.87), progress monitoring
(d+=0.40) and immediate acknowledgement **simultaneously**. No other component in the ten carries
more than two of those. It closes every gap in 08's behaviour score in one card.

**Why it survives:** it is additive. 08's Slot 2 already exists, already holds exactly one
instruction, and already has a button. It gains a time anchor, a second button and one line.

**Exactly where:** Slot 2 replaces 08's `That works` single button. The instruction gains a clock
time so there is an hour to be reminded at. Proof line sits **below** the buttons, so the signifier
is adjacent to the instruction and the evidence reads as a footnote.

### M2 — From **10-tomorrow**: clock-arithmetic anchoring for the Bedtime band · **lands in Slot 1c, bar 3**

This is the most important merge in the document and neither the judges nor 08's author flagged its
severity. 08's own §11 states:

> *"A user whose bedtime has drifted an hour later over six months will eventually be 'inside'
> their range at 1:30am. Only the sleep band is anchored to a computed need rather than recent
> behaviour."*

Three of four bands are self-referential and can silently normalise a deteriorating habit. That is
a correctness defect, not a taste one.

10's hero is the fix: **wake time − sleep need − typical onset latency**. Pure clock arithmetic,
zero model risk. 10's own words: *"If it is wrong, it is wrong the way a kitchen timer is wrong."*

**Exactly where:** the Bedtime band's centre becomes the derived target rather than the 14-day
median, **conditionally** — see §4.3 for the shift-worker guard.

### M3 — From **10-tomorrow**: "Nothing new is building." · **lands in Slot 1b, the message row, on quiet days**

An explicit ruling-out sentence is the answer to the boring day, and the boring day is most days,
and most days are the retention test. No competitor in the corpus offers it. It costs four words
and it is the only line in the ten that turns an absence into a service.

**Why it survives:** 08's message row already morphs by day. This is one more variant.

### M4 — From **09-because**: word-first verdict sizing, and the "Not counted" list · **Slot 1c + the expander**

09's `Moderate` at 34px with `62` at 20px grey beside it is the single most correct typographic
decision in the set. The winner has no index to demote — but the *principle* transfers: **on the
one bar furthest outside its band, the position word gets the emphasis, not the numeral.** That
gives 08 the focal point the craft judge correctly says it lacks (four rows at identical weight
means the eye has no entry).

And **"How you feel. We do not measure it, so it is not in this number."** goes into the "How your
range is built" expander verbatim. One sentence that defuses the category's #1 churn trigger by
conceding rather than arguing. It is free.

### M5 — From **07-coach**: hero marker geometry, and the "everything else" sentence · **Slot 1c + Slot 3**

Two things.

**(a) Marker size and contrast.** 07 is the only concept in the ten whose verdict survives a 7px
Gaussian blur at 320pt. The reason is physical: a thick, high-contrast marker against a labelled
band, redundant across position, colour, size **and** shape. 08's markers are small white dots. At
a squint 08's column is weaker than 07's single marker. **Adopt 07's marker weight and contrast on
all four of 08's bars.** This is the highest-leverage change to 08's 0-1s channel and it costs
nothing but CSS.

**(b) The naming-what-was-checked sentence.** *"Your heart rate, breathing and temperature all sat
in your usual range last night."* This is what converts silence from "the app is thin" into "the
app looked" — the cheapest trust purchase available with the data-literate user, who is the cohort
08 explicitly fails. It lands as the caption under the 14-day chart on days when nothing fired.

### M6 — From **03-body-budget**: the aggregate-proof grammar · **lands in Slot 2, the proof line**

> *"What spending buys: 20 more minutes asleep, measured across your last eight weeks."*

Names the payoff, the size, **and** the window, with no n=1 claim and no causal verb. That is the
sentence shape every "did yesterday's action work" slot should use, and it is strictly better than
02's version because it states the measurement window. Merge the *grammar*, keep 02's structure:

> *"Done 6 times. Those mornings you slept 38 minutes longer than usual, measured across your last
> eight weeks."*

Note: 03's intra-day fill — the only honest reason to reopen at 3pm anywhere in the ten — is
**deferred, not rejected**. See §4.5.

### M7 — From **04-sleep-first**: derive every printed fact from one raw array · **build-level rule**

04's `deriveNights()` computes drift, inside-count, shortfall, wake shift and late-run from a single
bed/wake array, which is why its verdict word, its body sentence and its chart can never disagree.
08 already does this for bar-vs-chart (its assertion pass confirms the chart's last plotted point
equals the hero bar's value). **Extend the rule to every derived string on the screen**, including
the message row and the instruction. This is the class of bug `B8` and `B10` describe, and it is
cheaper to prevent than to test for.

### M8 — From **05-mission-control**: the trust paragraph · **lands in Slot 5, the footer**

> *"Every number here is compared with your own history, never with other people."*

The cheapest large trust win available (F2 stated as a promise rather than enforced silently), and
it is one line. 05's full version names Readiness as a directional summary; the winner has no
Readiness, so only the second sentence transfers.

### M9 — Concepts that contribute nothing worth taking

**01-one-number.** Nothing. Its one distinctive move — the warning *becoming* the hero rather than
sitting beside it — is already how 08's attention strip works (it consumes position 1 inside the
hero card rather than requesting a slot). Its other properties are absences: no reminder, no
completion, no proof, no evening state, a 56px unvalidated composite, and ~430px of dead black in
the hero. The behaviour lens scored it 37, the lowest number any concept received on any lens, and
that is the correct read: a bedtime instruction delivered at 9:41am with no way to be prompted at
10:30pm and no way to record it is a pure informational nudge, the one intervention class with
strong Bayesian evidence *against* it (BF₀₁=33.84).

**06-todays-story.** Nothing shippable. Its evening-dominance idea — the instruction slot becoming
the largest card with a completion affordance at the hour the behaviour happens — is genuinely the
best time-of-day mechanic in the set, and I considered merging it. I am not merging it, for one
reason: it is inseparable from the auto-scroll and the moving hero designation that breach N8, and
the value it adds over M1's simple reminder is small. The reminder gets the user to the screen at
10pm; making the card bigger once they are there is decoration. **Recorded as rejected, with the
reason, so it is not re-litigated.**

---

## 4. The compromises

Specific users, named, with the reason the trade is acceptable and the reason it might not be.

### 4.1 The power user who came for a number — **fails, permanently**

Someone tracking a training block wants `Readiness 72` and a delta. This screen refuses both, by
construction, at the formatter layer, forever. Whoop's 83% DAU/MAU — roughly 3-10× the category —
comes from exactly the density removed here.

**Why acceptable:** the number they want is the least-validated element in the codebase. In D1
swimmers WHOOP's Recovery score was *not* associated with perceived recovery, stress or resting
metabolic rate, while the raw HRV it measured **was** `[CL §4.2-4.3]`. The composite is worse than
its own inputs. **Why it might not be:** they are not wrong about what they want, and "the number
you want is bad" is not a satisfying thing to be told. Some fraction leaves. Explore must carry
them, and Explore is now load-bearing in a way it was not before.

### 4.2 The athlete deciding whether to train today — **fails**

No strain, no training load, no HR zones, no VO2max, no workout anywhere on Home. The entire answer
is the Steps bar's clause: *"room for a harder session if you want one."*

**Why acceptable:** the alternative is Strain 0-21 on a logarithmic scale rendered as equal steps,
where a one-question subjective rating (session-RPE) matches the sensor metric at r=0.79-0.86
`[CL §6.1-6.2]`. Putting that on Home is a comprehension hazard the brief bans. **This is the
largest cohort the screen loses** and it should be the first candidate for a pinned fifth bar
(§4.5).

### 4.3 The shift worker, new parent, carer, on-call — **partially protected, and this is a change from 08 as built**

08's bands are built from the user's own recent behaviour, so they do not accuse an irregular
sleeper the way 04's and 10's fixed bedtime targets do. That is a genuine advantage and M2
threatens it: anchoring the Bedtime band to `wake − need − onset` reintroduces the accusation.

**Mandatory guard, and it is part of the spec:** if the user's wake-time standard deviation over 14
days exceeds 60 minutes, the Bedtime band **stays anchored to their own 14-day median** and the
instruction switches from a bedtime to wake-time consistency. This decision does not exist in the
app today and is listed in §11.

Residual failure: someone with a stable wake time and an uncontrollable bedtime still gets an
instruction they cannot follow. The escape hatch is the only mitigation and it is a blunt one.

### 4.4 The low-motivation user — **fails**

No failure state means nothing to push against. Gentler Streak's own documented risk is the
*opposite* of anxiety. Gamification survived withdrawal in a 1,062-patient cardiology RCT
(+459.8 steps/day at 6-month follow-up); this screen forgoes that lever entirely.

**Why acceptable:** absolute effect sizes there are 500-900 steps/day, attrition was *lower* in
apps without gamification in one narrative review, and F9 bans compliance streaks outright. The
proof line (M1) is the substitute and it is a weaker one, but it is the one the evidence supports.

### 4.5 Anyone whose relevant metric is not one of the four — **fails, and this is deferred rather than solved**

T10 is resolved opinionated. A user tracking blood pressure, glucose, a menstrual cycle or training
load cannot put it on Home. 05 made the correct case that pinning **inside** a fixed hierarchy is
D9 and not C7, and SDT puts autonomy support at ρ=.21 to .48.

**Deferred, named:** a user-selectable **fourth bar** from a fixed candidate list, with the boundary
stated in words ("Pick one. The other three never change"). Not v1 — it adds a settings surface, a
persistence path, and a state where the user's Home no longer matches the documentation. Ship the
opinion first; add the pin only if fourth-bar requests concentrate on one signal.

Also deferred: **03's intra-day fill.** It is the only honest reason to reopen at 3pm in the entire
set, and 08's biggest engagement weakness is that it earns none. It is deferred because the
reminder (M1) already creates the evening session at lower cost, and because a steps-today bar is a
false negative at 6:45am. Add it as a thin "today so far" underline on the Steps bar, rendering
only after 12:00, **if the evening-session metric does not move.**

### 4.6 The user drifting *inside* the band — **not solved, and it cannot be**

Sliding from the top of your sleep range to the bottom reads "inside" both weeks. The 14-day chart
is the only place it shows and it is below the fold. This is Gentler Streak's exact documented
weakness, and solving it means a daily delta, which F1 bans outright.

**Partial mitigation added by this spec:** the new clause rule (§10) gives clauses only to bars
*outside* the band. So the first morning a bar crosses out, a clause appears where there was none —
the screen's word count itself becomes the event. That is a weaker signal than a delta and a much
more honest one.

### 4.7 Words above the fold — **33, against a budget of 20**

This is the winner's one budget breach and I am not going to argue it away. But I am going to
re-specify the budget, because the field proved it is mis-calibrated.

08's arithmetic is right: four bars each needing a name, a plain-word position (required by N2,
because ~1 in 3 users cannot read the graph) and a clause costs **23 words before a single word of
message, heading or instruction is written.** The floor for any four-bar N2-compliant screen is
~29. Only 07 and 03 landed at or under 20 in the whole field, and both did it by shipping one
signal.

**Finding, recorded for the brief's next revision:** the 20-word budget is calibrated against a
single-hero-number concept. Re-specify it as **≤20 words of prose (sentences), with labels, verdict
words and legends counted separately.** Under that rule the winner is at **20 prose words exactly**
(message 5 + clauses 10 + instruction 5) plus 13 words of label furniture. That is the honest
reconciliation, and it is the number the build should hold to.

---

## 5. The ten tensions, resolved

| # | Tension | **Final position** | Why, and who made the case |
|---|---|---|---|
| **T1** | Score-first or action-first | **State-first, where state is a position and not a grade. Action second, in its own slot.** | 08. T1's only hard rule is "do not do both at equal weight." Four bars describe and never instruct; one card instructs and shows no reading of its own. The `CRIT §5` contradiction is structurally impossible because exactly one component holds an imperative verb. |
| **T2** | One hero number, or a cluster of 3-6 | **Four bars sharing one grammar — which is neither.** | 08. The Welltory failure (three percentages that disagree and no rule for which to obey) cannot occur, because none of the four is a verdict about the whole body. Oura's "it dilutes the information" critique is answered because one band shape at one x-position makes four bars read as one object. |
| **T3** | A graded verdict, or a range you sit inside | **A range you sit inside, no failure state, taken all the way.** | 08, on Gentler Streak's D3. Below the sleep band is less in reserve, which is why the instruction gets *lighter*, never harder. Below the steps band is capacity. "No emotion is not the safe answer" is answered by the message row and the settle motion — **not** by colour, which is identical on every bar in every position. |
| **T4** | A borrowed unit, or a native index | **Borrowed only, enforced at the formatter layer.** | 08. `F` contains h:mm, steps, clock time, bpm, km, flights and nothing else. This is the single most portable enforcement decision in the set: F5 and F3 become unviolatable rather than merely obeyed. |
| **T5** | Explanation inline, one tap, or a paragraph | **One clause per out-of-band bar, inline. The model one tap down, in place, never navigating.** | 08 for the structure, **09 for the content**. 09 made the best case that explanation deserves a named permanent region; its "Not counted" list — including "How you feel. We do not measure it" — is merged into the expander verbatim. |
| **T6** | Celebration, or calm | **Calm, with acknowledgement for showing up, and evidence as the only reward.** | 08 for "Short night. You showed up."; **07 for the proof grammar**. The reward is stated in a borrowed unit ("38 minutes longer") rather than in index points, which survives the F1 delta ban and reads as competence rather than a score bump. No streak, no badge, no confetti, no personal best. |
| **T7** | Density, or scroll | **Sparse in numbers, dense in structure.** | 08. 6 blocks, 10 numbers — but the hero is four aligned bands, not whitespace. This is the resolution of the two failure modes the field demonstrated: 01's ~430px of dead black inside its own hero (Google Health's "why so much white wasted space") and 05's 22 numbers on six scales. |
| **T8** | Fixed slots, or contextual morphing | **Fixed absolutely. Morphing inside Slot 2 only.** | 08, with **06 as the counterexample that proves it**. 06's `centreOnNow()` moves both the scroll position and the hero designation by time of day — Oura's failed whole-screen morph. Single-slot morphing shipped; whole-screen morphing was attacked. |
| **T9** | Honest uncertainty, or confident simplicity | **One mechanism, geometric, visible on the default morning without a tap: band width.** | 08, decisively. This is the tension the field failed worst — 03, 05, 07 and 09 all claim one mechanism and render zero, because the sentence is inside a collapsed panel. 10's tapered rail is the only other visible mechanism, and 08's also does the N5 degradation job with the same control. |
| **T10** | An opinionated hierarchy, or user pinning | **Opinionated for v1. One pinning affordance specified and deferred.** | 08 for the position, **05 for the correct future shape**. 05 is right that pinning inside a fixed hierarchy is D9 and not C7, and right to state the boundary in words. Four bars is not enough surface to pin within today. Revisit only if fourth-bar requests concentrate. |

---

## 6. How it improves daily engagement — the mechanism

Not "users will love it." Five mechanisms, each with the thing it moves.

1. **The cost of opening drops to near zero.** Four markers against four identical bands is a
   sub-second read with no reading required. There is no dense scroll to explore, no second score
   to reconcile, three exits total. This is Athlytic's D1 bet — optimise for the version of the
   screen you barely open. **Moves:** open rate, by removing friction, not by adding a reason.

2. **The reminder creates a second, high-intent session at the hour of the behaviour.** This is the
   one mechanism 08 did not have and M1 adds. Every competitor's home screen is a morning object,
   stale by lunchtime. A prompt at 10pm that lands on a screen already holding the instruction is
   Fogg's B=MAP with the prompt placed at the moment of ability rather than 13 hours early.
   **Moves:** sessions per day from ~1 to ~2, and action-completion rate — which is the metric this
   design is actually built to move.

3. **Bad days stay openable, so the app is present on the days it has the most to add.** Every
   compliance streak eventually teaches users to stop opening on bad days `[P §6.7]`. There is no
   streak, no zero, no failure state, and the first line on a short night is *"Short night. You
   showed up."* **Moves:** the tail of the retention curve, which is where the 4.1-day median
   engagement figure comes from.

4. **Banner blindness is defeated without moving furniture.** Four markers change position daily,
   and the clause rule means a bar's clause *appears and disappears* as it crosses its band — so
   the screen's word count itself changes day to day. F17's 33× under-attention finding applies to
   regions whose content never appears to change; four independent markers plus a variable clause
   set cannot render identically two mornings running. **Moves:** fixation share on the hero region,
   without touching the cue-response stability habit formation needs.

5. **The bands narrow as history accumulates.** A user who joins on a phone and later buys a watch
   sees the interface visibly reward continuity. It is not a streak, so F9 does not apply, and it
   cannot be gamed. **Moves:** week-2 to week-4 retention, the window where "is this thing learning
   me?" is the live question.

**Honest ceiling, stated so nobody measures the wrong thing:** this will not produce Whoop's 83%
DAU/MAU and should not be benchmarked against it. Time-in-app should *fall*. Session count should
roughly double via the evening prompt. **The number to instrument is action-completion rate.**

---

## 7. How it increases perceived value

1. **It never pays the scoring tax.** Privacy concern among tracker users runs at 40%, **rising to
   60% when they subscribe to a service that produces reports from their data — the act of turning
   raw data into a score increases distrust** `[PSY §11]`. This screen never scores. Accuracy,
   efficacy, transparency and scientific reliability account for roughly half of all user concerns
   in mHealth reviews; three of those four are addressed by not making a claim the model cannot
   support.

2. **Visible restraint reads as competence.** `58 bpm · above · one morning only` and nothing fires.
   The user watches the app look at something out of range and decline to alarm them, with the
   threshold stated. That is the difference between a product that seems to be guessing and one
   that seems to have a rule.

3. **The removal is a feature users notice unprompted.** A Bevel user wrote an App Store review
   specifically to praise the absence: *"No calorie goals or you didn't hit your macro target or
   cyber guilting."* In a category whose primary complaint is score anxiety, that is a moat, and it
   is the only differentiator in the corpus that costs engineering nothing.

4. **The proof line converts a claim into a measurement.** *"Done 6 times. Those mornings you slept
   38 minutes longer than usual, measured across your last eight weeks."* Q5 is the question exactly
   one component on the current screen even attempts, and it attempts it as an n=1 delta the
   codebase's own dead band calls noise. This is the aggregate form, in a borrowed unit, with the
   window named.

5. **The escape hatch is itself a value signal.** A one-tap row that removes every band, every
   position word and the instruction, leaving raw readings with nothing said about them. It states,
   structurally, that the product does not need the user to accept its interpretation. It is also
   the only mitigation the self-tracking harms literature actually offers.

6. **Day 1 looks finished.** First sync pulls 10 years of HealthKit history, so a Watch-wearing new
   user gets four real bars immediately. A genuinely new user gets the same four bars drawn dashed
   and wide, with "still learning it." Nobody in the corpus ships a distinct first-14-days home
   screen and **every one of them pays for it in reviews** — this is the second open lane and it is
   taken for free by the band-width mechanic.

---

## 8. How it helps users understand their bodies — tied to the clinical research

Every claim here maps to a specific finding, because "helps users understand" is otherwise an
aspiration.

| Design decision | Finding it is built on |
|---|---|
| **Exactly one reference range per bar, and it is personal. No endpoints printed.** | N=6,766, three conditions: comprehension of a result's relative location goes standard-range-only **14.49%** → goal range added **35.92%** → **goal range only 43.45%** (χ²₂=126.9, p<.001). Comprehension of *expected future* location 22.97% → 37.39% → **46.97%**. **Substituting beats adding.** `[UX §11]` |
| **One bar grammar, learned once, reused four times.** | ~40% of US adults have inadequate graph literacy; ~1 in 3 have both low graph literacy *and* low numeracy `[CL §11]`. Four instances of one grammar is one learning cost, not four. This is the largest single comprehension win available and it survives 320pt and 1.3× text intact. |
| **Positional bars only. No pie, donut, gauge, treemap, 3D, or line chart.** | 39-study review, 27 with human subjects, mean n=369: line graphs are the most used (35%) and among the hardest to read; *"more patients understand the number lines and bar graphs compared with line graphs."* Horizontal line bars with coloured blocks scored **highest** on satisfaction and usability and **significantly reduced intention to contact a physician**. `[UX §10-11]` |
| **Colour identifies "your range". It never encodes magnitude and is never the sole channel.** | Colour is pre-attentive but people do not perceive colours as ordered. The band tint is identical on every bar in every position; position is the only magnitude channel, plus the plain word, plus marker shape. `[UX §10; HIG/WCAG]` |
| **Borrowed units only: h:mm, steps, clock time, bpm.** | *"The weakest home screens require the app to teach a scale before the number means anything, and the teaching never sticks."* `[N §12.2]` Clock time and h:mm are the top-ranked comprehension units in the clinical brief; devices exceed **90% sensitivity for sleep vs wake** `[CL §3.1]`, so these are also the numbers the hardware is actually right about. |
| **Every number carries a plain word derived from its own position.** | `posWord()` computes the word from value-vs-band at render time, so the word and the picture cannot disagree — the `B8` class of bug. And ~1 in 3 users cannot read the graph, so the word is not redundancy, it is the primary channel for them. |
| **Sleep regularity reaches Home for the first time, as a bedtime in clock time.** | UK Biobank, **n=60,977**, >10M hours of accelerometry, 7.8-year follow-up: all-cause mortality **HR 0.70 (0.59-0.83)** top vs bottom SRI quintile, cardiometabolic **HR 0.62**. Model comparison: regularity is a **stronger predictor of mortality than sleep duration**, and it uses only bedtime and waketime — the parts wearables get right. `[CL §3.3]` The brief calls it "the single biggest addition available." It is currently computed inside `CircadianAnalyzer` and surfaced nowhere. |
| **The persistence rule is printed on the face of the screen: "one morning only".** | RHR flags only at ≥5 bpm or ≥10% above personal baseline sustained **3+ consecutive nights**; one elevated night means almost nothing `[CL §2.3, §14]`. Nocturnal RHR MAE is 0.98-1.78 bpm, so the *measurement* is trustworthy and the *inference* is what needs a gate. Showing the gate teaches the user why the app is quiet. |
| **Every alarming element carries a harm anchor.** | N=1,618: adding *"many doctors are not concerned until here"* significantly reduced perceived urgency of close-to-normal results (p<.001) and substantially cut the number of people wanting to contact a doctor urgently. `[UX §11]` |
| **Zero facts to combine on every element.** | Element interactivity is the mechanism behind every extraneous-load effect. `Strain 14.2 · High` required a score seven cards away. Here the label, the value, the position word, the band and the clause are one visual element. `[UX §1]` |
| **No sleep stages, no HRV in ms, no vitality age, no stress score.** | Sleep staging κ 0.21-0.53, Apple Watch deep-sleep sensitivity 50.7% `[CL §3.1]`. Laso stores **SDNN**, which is not RMSSD and must never share an "HRV" label; healthy range 19-75 ms is a 4× spread `[CL §1.2-1.3]`. Age framing has **no effect on lifestyle intentions or behaviour** `[CL §9.3]`. Recall for psychological stress from wearable signals is **50.0%** `[CL §5.2]`. Understanding is improved by removing four things that cannot be understood. |

---

## 9. How it encourages healthier decisions without overwhelming

**The decision architecture, in order:**

1. **Exactly one instruction exists on the screen, pre-chosen, with a time attached.** Goal setting
   on *behaviour* β=+0.89 (p=0.001) and graded tasks β=+0.87 (p=0.008) are the two evidence-backed
   BCTs a home screen can carry cheaply; digital interventions overall SMD 0.42 `[PSY §10]`. Zero
   decisions before the first tap — C5, the pattern Headspace, Calm and Gentler Streak converged on
   independently.

2. **The instruction is graded to capacity and gets lighter, never harder, when the reading is
   under.** Below the band is capacity or reserve, never failure. This is D3, the inversion that won
   Gentler Streak a 2024 Apple Design Award for Social Impact, and it is what makes a small
   instruction on a bad day read as permission rather than as a reduced target.

3. **The prompt fires at the hour of the behaviour.** Fogg: a returning user is already above the
   activation threshold, so spend the screen on **ability**, not motivation. A reminder at 10pm is
   ability; a motivational sentence at 6:45am is a tax.

4. **The loop closes with an aggregate, in a borrowed unit, with its window named.** Progress
   monitoring against a goal: **138 studies, N=19,951, d+ = 0.40 (0.32-0.48), mediation confirmed**
   `[PSY §9]` — the best-evidenced item in the entire psychology corpus, currently computed by
   `RecommendationEvaluator.buildActionProof` and rendered only on a detail screen.

**What is deliberately absent, and the evidence for absence:**

- **No compliance streak.** Lally, n=96, 84 days: a missed day costs **0.29 points on a 0-42
  automaticity scale**, is not significant, recovers fully, and timing of the miss is irrelevant
  (r=0.099, p=0.246). A streak lies about the biology.
- **No loss framing.** λ is between 1.07 and 1.955, median 1.31, with only 6 of 19 studies
  significant. Health-message framing effects are "negligible when aggregated."
- **No informational nudge copy.** Nudging collapses **d=0.43 → d=0.04** after publication-bias
  correction on the same 334 effect sizes, with **strong evidence against information interventions
  specifically (BF₀₁ = 33.84)**. Only *structural* nudges — defaults and ordering — survive, and
  ordering is the only influence this screen uses.
- **No variable reward, no deliberate incompleteness.** Zeigarnik does not replicate. Across 92 RCTs
  of mental health apps there was **no relationship** between number of persuasive design principles
  and completion (r=0.21, p=0.43) or efficacy (b=0.01, p=0.804).
- **No pressure verbs.** SDT, 184 data sets: controlled regulation predicts **worse** mental health
  (ρ = .13 to .46); autonomy support predicts better (ρ = .21 to .48). The instruction is a fit, the
  confirmation is an acknowledgement, and the escape hatch is one tap and named without shame.

**Why it does not overwhelm:** the load ceiling is set by element interactivity, not item count.
Every element carries its own comparison and its own verdict, so four signals cost four glances, not
sixteen lookups. The brief's number budgets are proxies for that mechanism — 05 proved you can
satisfy the mechanism and still overwhelm by shipping 22 numbers; 08's band-shape decision is what
lets you satisfy both at once.

---

## 10. The final spec

**This is what the build implements. It is unambiguous by design; anything not stated here is a
question for the director, not a judgement call for the implementer.**

Base file: `design/home-v2/concepts/08-the-band.html`. All merges M1-M8 applied. All tokens from
`DESIGN-TOKENS.md` verbatim.

### 10.1 Slot order — identical every morning, in every data state, forever

| # | Slot | Always renders? |
|---|---|---|
| 0 | **Header** — `Today` + date, right-aligned. Zero tap targets. | Yes |
| 1 | **The card** (hero) — 1a attention strip · 1b message · 1c four bars · 1d legend · 1e state note | Yes |
| 2 | **Today** — the one instruction + Done + Remind me + proof line | Yes |
| 3 | **Your last 14 days** — sleep chart + "How your range is built" expander | Yes |
| 4 | **Just the numbers** — the escape-hatch row | Yes |
| 5 | **Footer** — updated stamp + trust line | Yes |
| — | Tab bar — Today · Live · Explore · Settings | Chrome |

**6 blocks** against a limit of 7. Nothing reorders, ever. Time-of-day variation happens inside
Slot 2 only.

### 10.2 Slot 1 — the card

**1a — Attention strip.** Conditional. Renders **inside** the hero card, above the message, at
position 1. Never blurred, never paywalled, never hedged, no badge, no colour-only signal. Fires
only on the existing `IllnessEarlyWarning` gate (≥2 of 5 signals, ≥1.0σ, ≥2 consecutive days,
14-day baseline). Carries: one plain sentence naming what was noticed with magnitudes and
persistence, one harm anchor, no instruction. **Absent on the default morning.**

**1b — The message.** One line, 20px semibold, ≤6 words. Written about the person, never the
performance. Variants:

| Day | Copy |
|---|---|
| Short night (default) | `Short night. You showed up.` |
| Quiet / all inside | `Nothing new is building.` *(M3)* |
| Attention | `Something has repeated. Read this first.` |

**1c — Four positional bars.** Fixed order: **Sleep · Steps · Bedtime · Resting heart rate.**

Every bar, identically:

```
[label, left]                    [value, right]  [position word]
[───── track with band drawn at the same x-position on every bar ─────]
[clause, left, 13px]   ← only if the marker is OUTSIDE the band
```

Rules that are not negotiable:
- The band is **drawn, never printed**. No endpoints render on any bar in any state.
- Band half-width is `BAND_HALF = { full:16, phone:24, new:36 }` percent either side of centre.
  One constant, every bar. On `new`, bands render **dashed**.
- Position word is derived by `posWord(value, band, key)` at render time. Never hard-coded.
  Vocabulary is locked to five words: `under` · `inside` · `above` · `earlier` · `later`.
- Band tint is the **same colour at the same opacity on every bar in every position.** Colour
  identifies "your range". It never says "good".
- **Marker: adopt 07's weight and contrast** *(M5a)* — a thick high-contrast mark, not a small dot,
  redundant across position, colour, size and shape. It must survive a 7px Gaussian blur at 320pt.
- **Marker position is set at first paint from the computed value.** Animation is a pure
  enhancement layered on top. See §11.9 — this is a defect fix, not a preference.
- **Clause rule (changed from 08 as built):** a bar **inside** its band gets **no clause**. A
  reading inside your own range has nothing to explain. This buys 3 words and creates a signal —
  the morning a clause appears where there was none is itself the event.
- **Focal point** *(M4)*: on the single bar furthest outside its band, the position word renders at
  17px semibold in the verdict colour instead of 13px tertiary, **and moves under the label,
  left-aligned.** Every other bar keeps 13px. This fixes both the craft judge's "no entry point"
  finding and the "meaning-critical content on the right edge" breach in one change.

Default-morning content, verbatim:

| Bar | Label | Value | Word | Clause |
|---|---|---|---|---|
| 1 | `Sleep` | `6h 12m` | `under` **(focal, 17px)** | `by about an hour` |
| 2 | `Steps` | `8,400` | `inside` | *(none)* |
| 3 | `Bedtime` | `12:35 am` | `later` | `later all week` |
| 4 | `Resting heart rate` | `58 bpm` | `above` | `one morning only` |

**Band anchoring** *(M2)*:
- **Sleep** — `SleepNeedCalculator` personal need (fixes **B6**). Never a flat 7.5h.
- **Steps** — personal 14-day range, anchored at 7,000 with the reason available in the expander
  (fixes **B7**). Never 10,000.
- **Bedtime** — **`wake time − sleep need − typical onset latency`**, clock arithmetic, zero model
  risk. **Guard:** if 14-day wake-time SD > 60 min, fall back to the user's own 14-day median and
  switch Slot 2's instruction to wake-time consistency. See §11.8.
- **Resting heart rate** — `BaselineCalculator` personal range.

**1d — Legend.** One swatch + `your range`. Two words. Renders once for all four bars.

**1e — State note.** One sentence, renders **only** in `phone` and `new`. Explains why the bands
got wider. It is a caption on the single uncertainty mechanism, not a second one.

### 10.3 Slot 2 — Today *(the M1 merge)*

```
TODAY
In bed by 10:30 tonight.
[ Done ]              [ Remind me tonight ]
Done 6 times. Those mornings you slept 38 minutes longer than usual,
measured across your last eight weeks.
```

- **Exactly one imperative verb exists on this screen and it is in this line.** Enforced by a build
  sweep across every rendered state.
- The instruction **always carries a clock time**, so there is an hour to be reminded at. On a rest
  day the capacity framing moves into the Steps bar's clause (`room to go easy today`), not into a
  second instruction.
- `Done` writes a completion record. The record feeds `buildActionProof`. **Nothing counts
  consecutive days.** D7: the streak is on the record-keeping, never on compliance.
- `Remind me tonight` states the time before the user commits, then reads `Reminder set for 10pm`.
- Proof line uses 03's grammar *(M6)*: payoff + size + window, in a **borrowed unit**, aggregate,
  never n=1, no causal verb. **Absent entirely** when no history exists — never fabricated.
- Time-of-day morphing lives here and nowhere else: after 18:00 the eyebrow reads `TONIGHT` and the
  instruction restates in the present tense. The slot does not move, resize, or auto-scroll.
- **After a life-context override the instruction text must change**, not merely gain an
  acknowledgement. See §11.7.

### 10.4 Slot 3 — Your last 14 days

Sleep only. One SVG chart: a filled band, one dot per day, **no connecting line**. Interpretation
sentence sits **above** the chart (D3). The chart's last plotted point must equal the Sleep bar's
value — assertion-tested, per M7.

Caption on days when nothing fired *(M5b)*:
`Your heart rate, breathing and temperature all sat in your usual range last night.`

Expander: **How your range is built.** Contains, in this order:
1. How each band is derived, in plain words.
2. The persistence rule stated out loud: *"We do not call that a change until it is 5 or more above
   your average for three mornings."*
3. **Not counted** *(M4)* — including verbatim: *"How you feel. We do not measure it, so it is not
   in this number."*
4. Why 7,000 is the steps anchor: *"That goal is the level where most of the health benefit has
   already arrived."*

08's four-metric chart cycle button is **cut**, to keep tap targets at 8. All four metrics remain
available in the escape hatch.

### 10.5 Slot 4 — Just the numbers

One designed row, in the thumb zone. Copy: `Just the numbers — turn off ranges and words. Nothing
gets judged.` One tap removes every band, every position word, the message and the instruction,
leaving raw readings with no verdict attached. This is the **only** place raw HRV appears, labelled
`Heart rate variability (SDNN)`. Reversible. State persists.

### 10.6 Slot 5 — Footer

Two lines, 12px tertiary:
```
Updated just now.
Every number here is compared with your own history, never with other people.   (M8)
```

### 10.7 The three data states, plus loading and empty

Same six slots, same four bars, same grammar. Only band width, values and one sentence change.

| | **A · Full wearable** | **B · iPhone only** | **C · Genuinely new (day 3)** |
|---|---|---|---|
| Band half-width | 16% | 24% | 36%, **dashed** |
| Bar 1 | Sleep `6h 12m` | Steps `8,400` | Steps, real same-day value |
| Bar 2 | Steps `8,400` | Distance | Distance |
| Bar 3 | Bedtime `12:35 am` | Stairs | Stairs |
| Bar 4 | Resting heart rate `58 bpm` | Walking pace | Walking pace |
| 1e state note | *(absent)* | `No wrist data, so these ranges are wider.` | `Still learning your usual. These ranges narrow at seven days.` |
| Per-row note | — | — | `still learning it` |
| Slot 2 instruction | Full personal | Personal where possible, else steps-anchored | WHO/7,000-anchored, with the anchor named |
| Slot 2 proof line | Present | Present if history exists | **Absent** — never fabricated |

**Loading:** the four bar shapes and all four labels render immediately; only values and marker
positions shimmer. The structure never flickers.

**Empty (no Health access):** the four bands render as **goal shapes, not blanks.** Copy:
`Nothing to read yet. The shapes are ready.` One `Connect Apple Health` button. An unfilled ring
says fill me; a blank tile says this app is broken.

**Rule that governs all five:** a day-1 screen and a day-200 screen differ in **band width, never in
structure.** Nothing that needs 7 days renders confidently before it has 7 days.

### 10.8 Literal budget counts — default morning, 390×844, full wearable, nothing expanded

| Constraint | Limit | **This spec** | |
|---|---|---|---|
| Cards above the fold | ≤ 3 | **2** | ✅ |
| Total blocks | ≤ 7 | **6** | ✅ |
| Numbers on screen | ≤ 12 | **10** — `6h 12m` `8,400` `12:35 am` `58 bpm` `10:30` `6` `38` `14` `8h 05m` `7h 15m` | ✅ |
| Numbers above the fold | ≤ 5 | **5** — `6h 12m` `8,400` `12:35 am` `58 bpm` `10:30` | ✅ at limit |
| Facts to combine per element | ≤ 2, target 0 | **0** | ✅ |
| Tap targets | ≤ 8 | **8** — Done · Remind me tonight · How your range is built · Just the numbers · 4 tabs | ✅ at ceiling |
| Distinct exits from Home | ≤ 6 | **3** — Live, Explore, Settings | ✅ |
| Disclosure levels below Home | ≤ 2 | **1** — one in-place expander, zero navigation | ✅ |
| Uncertainty mechanisms | 1 | **1** — band width, **visible without a tap** | ✅ |
| Reference ranges per number | exactly 1 | **1**, personal, endpoints never printed | ✅ |
| Components giving an instruction | 1 | **1** — Slot 2 | ✅ |
| Words above the fold — **prose** | ≤ 20 | **20** — message 5 + clauses 10 + instruction 5 | ✅ at limit |
| Words above the fold — all tokens | ≤ 20 | **33** | ❌ **see §4.7** |
| Smallest text | ≥ 11px | 11px, chart axis only | ✅ |
| Smallest tap target | ≥ 44px | 44px | ✅ |
| §3 bans breached | 0 | **0** | ✅ |
| §8 non-negotiables breached | 0 | **0** | ✅ |

### 10.9 Accessibility and Dynamic Type — mandatory, not aspirational

- At AX3 and above, each bar's **value and position word move to their own line under the label**.
  The band stays full width. The card grows. **Nothing truncates and nothing clips** — 05's
  two-column grid produced `6h 12r` and a clipped button at 320pt + 1.3×, and that outcome is
  banned.
- Every bar carries a plain-language `aria-label` stating value, band and position in a sentence.
- `prefers-reduced-motion`: markers place instantly, no settle animation, no stagger.
- Contrast ≥ 4.5:1 on every text token in both themes; ≥ 3:1 on every graphic pair.
- Verified at 320px, 375×812 and 430×932, light and dark.

---

## 11. What must be fixed in the app before this can ship honestly

### Bugs from brief §6, by blast radius

| Bug | Status under this design | Action |
|---|---|---|
| **B6** sleep goal hardcoded at 7.5h | **In the blast radius.** The Sleep band's anchor. | **Must fix.** Use `SleepNeedCalculator`'s personal need everywhere. |
| **B7** steps goal hardcoded at 10,000 | **In the blast radius.** The Steps band's anchor, and the Live Activity. | **Must fix.** Personal goal anchored at 7,000 with the reason stated. |
| **B9** widget and Home can show different numbers by design | **In the blast radius.** The widget must render the same four bars from the same derivation, or it recreates the contradiction this redesign exists to remove. | **Must fix.** One shared derivation, consumed by Home, the chart and the widget. |
| **B8** recovery-debt "trend" words are a size test labelled as a direction | Not rendered here, but the component must not be reintroduced. Direction on this screen is only ever position over 14 days. | Remove or relabel. |
| **B3** hero ring substitutes Daily Health Score under a "Readiness" label | **Dissolved.** No index renders, so nothing can be substituted. | No action; do not reintroduce. |
| **B5** circular Energy "Why" row | **Dissolved.** No Why rows, no index. | No action. |
| **B4** sparse user's score dominated by a constant 75 at full confidence | **Dissolved** — no Daily Health Score renders. But the *principle* is now load-bearing: **never render a band narrower than the data supports.** | Encode as an assertion on `BAND_HALF`. |
| **B11** heuristic vitality norms printed as fact | Vitality comes off Home entirely. | Remove from Home. |
| **B10** ±2% weekly moves labelled "wins" | No weekly wins block exists here. | Do not reintroduce. |
| **B1** blood oxygen filter (bounds should be 50-100, not 0.5-1.0) | **Out of the blast radius** — SpO2 does not render. | **Fix anyway.** It is one line, and SpO2 cannot ever be eligible for a bar until it is fixed. |
| **B2** sleep forecast divides hours by 3600 | **Out of the blast radius** — no forecast renders. | Fix before any forecast is ever promoted. |

### Capabilities this design depends on that do not exist or are not wired

**11.1 — Personal band derivation for Steps, Bedtime and Resting heart rate.**
`BaselineCalculator` covers RHR. Steps and bedtime need a 14-day rolling percentile band.
`CircadianAnalyzer` holds the bedtime ingredient and surfaces it nowhere. This must be built **once**
and consumed by Home, the chart and the widget so no two surfaces can disagree (see B9).

**11.2 — A single band-width parameter tied to data state.**
`BAND_HALF = {full:16, phone:24, new:36}` does not exist. It must be one function of (days of
history, signals present), applied by every bar, or T9 collapses back into four separate widgets and
the whole honesty argument fails.

**11.3 — Consecutive-out-of-band counts must be exposed.**
To print `one morning only`, the UI needs to know how many consecutive mornings a signal has sat
outside its band. `IllnessEarlyWarning` computes persistence internally and does not expose the
count. Without this, the single best trust mechanic on the screen cannot render.

**11.4 — `RecommendationEvaluator.buildActionProof` must reach Home, in borrowed units.**
It computes 24h/7d lift today and renders only on a detail screen `[CAP §9.8]`. **Blocking
question:** can it express lift as `38 minutes longer` rather than as readiness points? If it can
only emit index deltas, the proof line cannot ship in its designed form and Slot 2 loses its Q5
answer. Resolve before build starts.

**11.5 — A reminder scheduler bound to the instruction's clock time.**
`Remind me tonight` must create a real local notification at the stated hour and state the time
before the user commits. The app currently requests push permission as a side effect of the morning
check-in `[CRIT §4.10]`; that path is deleted and replaced by this one.

**11.6 — A completion record that cannot become a streak.**
`Done` writes a record; the record feeds `buildActionProof`; **nothing counts consecutive days** and
no surface may display a consecutive count. Enforce in the data model, not in the view.

**11.7 — The advisor must re-derive the instruction after a life-context override.**
This is 07-coach's N4 defect promoted to a requirement. If the user declares unwell / injured /
travelling, Slot 2's **instruction text must change**, not merely gain an acknowledgement.
`LifeContextStore` and advisor rung 0 both exist `[CAP §4]`; Home must consume the post-override
result. A screen that acknowledges an input and then contradicts it is worse than one that ignores
it.

**11.8 — The bedtime anchoring decision.**
Needs 14-day wake-time standard deviation. If SD > 60 min, the Bedtime band stays history-anchored
and Slot 2's instruction switches to wake-time consistency. This rule does not exist today and it is
the only thing standing between this design and accusing a night-shift nurse every morning.

**11.9 — Marker placement at first paint.** *(Highest-severity defect found in the whole exercise.)*
In `08-the-band.html`, `.mk` defaults to `left:50%` and is repositioned inside a
`requestAnimationFrame` + staggered `setTimeout`. **The supplied screenshot of the winning concept
shows all four markers dead-centre of their bands** — a screen that pre-attentively reads *"all four
signals inside your range"* on a morning when three of four are outside. It is a one-line fix
(position from the computed value at render; animate as enhancement only) and it must be covered by
a snapshot test, because the failure mode is silent and the wrong answer is a clean bill of health.

**11.10 — Copy migration.**
Every user-visible string on this screen into `Common/Copy/Copy+Home.swift`, resolving via Firebase
Remote Config with English defaults baked in, per the project standard. This includes the position
words, the clauses, the message variants and the proof-line template. The widget target has no
Firebase, so any string the widget shares must have a compile-time default.

---

## Appendix — the three sentences, verified against this design

1. **One answer to "what should I do today."** Slot 2 holds the only imperative verb on the screen,
   enforced by a build sweep across every rendered state. The four bars describe and never instruct.
   ✅
2. **Every number on screen carries a verdict.** All ten numbers ship a drawn band, a derived
   position word and — when outside the band — a plain clause, inside the same visual element. ✅
3. **Nothing on the screen asks the user for input that the app then ignores.** The screen asks for
   two things: `Done` (writes a record that feeds the proof line) and `Remind me tonight` (schedules
   a real notification). Both have visible downstream effects. The morning check-in is deleted. ✅

# UX and Information-Design Research for a Daily Health Home Screen

Compiled 2026-07-29. Every claim below is traceable to a source that was fetched or searched in
this session. Where a number could not be verified against a primary or first-party source it is
marked `[UNVERIFIED]`. Nothing here is invented.

Reading order: each section states **what the research actually claims**, **effect sizes** where
they exist, **what is contested**, and **the practical rule** for our Home Screen.

---

## 1. Cognitive load theory (Sweller)

**What it claims.** Cognitive Load Theory splits load into *intrinsic* (inherent element
interactivity of the material), *extraneous* (created by how the material is presented, and
therefore the only part a designer directly controls), and historically *germane* (effort spent
building schemas). Element interactivity — how many pieces you must hold simultaneously to make
sense of any one piece — is the mechanism behind every extraneous-load effect.
Source: [Cognitive Load Theory — ScienceDirect topic overview](https://www.sciencedirect.com/topics/psychology/cognitive-load-theory) (search summary; direct fetch returned 403),
[Cognitive Load Theory Revisited](https://wegrowteachers.com/cognitive-load-theory-revisited/),
[Huntington Research School](https://researchschool.org.uk/huntington/news/cognitive-load-theory-was-it-really-all-a-myth).

**Numbers.** Working memory is commonly summarised in the CLT literature as: duration roughly
20 seconds without rehearsal, storage of around seven chunks, and a *concurrent processing* limit
of only two to four chunks. The processing limit — not the storage limit — is the one that binds
when someone has to combine two numbers to reach a conclusion. `[UNVERIFIED against Sweller's
original paper — obtained from secondary summaries of Sweller, van Merriënboer & Paas (2019).]`

**What is contested.** In 2019 Sweller et al. themselves removed germane load as a separate,
additive source of load, folding it into intrinsic load, because intrinsic and germane were not
empirically separable. So the popular three-bucket diagram in design decks is out of date. CLT has
also been attacked more broadly for being hard to falsify, since "extraneous load" is often
inferred from the outcome rather than measured independently.

**Practical rule.** The Home Screen's job is to drive extraneous load to near zero. Every time the
user must hold one number in their head to interpret another (today's steps vs. their average,
sleep vs. their goal), we have created element interactivity. Put the comparison *inside* the same
visual element rather than making the user compute it. If a card requires combining more than
two on-screen facts, it is over-loaded regardless of how few pixels it uses.

---

## 2. Miller's 7±2, and why it is the most misapplied number in UI

**What Miller actually claimed.** Miller (1956) was about immediate recall of unidimensional
stimuli and about *chunking* as a way to beat that limit. Miller himself clarified that his work
concerned "discrimination of unidimensional stimuli" and "immediate recall," and that it had
"nothing to do with a person's capacity to comprehend printed text."
Source: [UX Myths #23](https://uxmyths.com/post/931925744/myth-23-choices-should-always-be-limited-to-seven).

**Why applying it to menus/cards is wrong.** NN/g is explicit: "the point of menus is reliance on
recognition rather than recall: users don't need to keep all of the menu items in their short-term
memory, because all the available options are continuously displayed on the screen." Therefore
"menus can still be easy to use with more than seven choices, as long as the options are structured
in a meaningful way." NN/g names the misuse directly — "confused designers will sometimes misuse
this finding to justify unnecessary design limitations."
Source: [NN/g — How Chunking Helps Content Processing](https://www.nngroup.com/articles/chunking/).

Tufte is quoted in the same vein: Miller's paper "neither states nor implies rules for information
presentation." Broad-and-shallow menu structures often outperform deep ones; Amazon's 90+ category
links are cited as a counterexample to the seven-item rule
([UX Myths #23](https://uxmyths.com/post/931925744/myth-23-choices-should-always-be-limited-to-seven)).

**The corrected number.** Cowan (2001), *The magical number 4 in short-term memory*, reviewed
verbal/non-verbal, visual/auditory, single/dual-task evidence and put the focus-of-attention
capacity at **about four chunks**, arguing Miller's seven was "more a rough estimate and a
rhetorical device than a real capacity limit."
Source: [Cowan 2001 via PhilPapers](https://philpapers.org/rec/COWTMN),
[Cambridge core PDF](https://www.cambridge.org/core/services/aop-cambridge-core/content/view/44023F1147D4A1D44BDC0AD226838496/S0140525X01003922a.pdf/the-magical-number-4-in-short-term-memory-a-reconsideration-of-mental-storage-capacity.pdf).

**What is contested.** Four is not settled either. A 2024 modelling review asks explicitly whether
the number is four, seven, or "depends on what you are counting."
Source: [Journal of Cognition](https://journalofcognition.org/articles/10.5334/joc.387).

**Practical rule.** Do **not** cap the number of Home Screen cards at seven "because Miller." The
correct constraint is different: cap the number of things the user must *hold in mind at once* to
interpret any single card at about **four**, and let the number of visible, self-describing,
scrollable cards be driven by content value and scroll cost instead. A visible card is recognition,
not recall, and does not consume the limit.

---

## 3. Hick's Law and choice overload

**Hick's Law.** RT = a + b·log₂(n): reaction time grows logarithmically with the number of equally
likely choices (Hick 1952, Hyman 1953).
Source: [Laws of UX](https://lawsofux.com/hicks-law/),
[Liu, Gori, Rioul, Beaudouin-Lafon & Guiard, CHI 2020, "How Relevant is Hick's Law for HCI?"](https://perso.telecom-paristech.fr/rioul/publis/202001liugoririoulbeaudouinlafonguiard.pdf).

**Why it usually does not apply to a UI.** The original paradigm required (a) well-practised,
direct stimulus–response mappings, (b) heavy training to automaticity, and (c) equiprobable
options. Real interfaces violate all three: options are not equiprobable, users are not trained,
and the dominant cost is **visual search**, not decision. Landauer & Nachbar (1985) deliberately
*eliminated* visual scanning by using well-practised, well-ordered choice sets — precisely the
condition a health dashboard does not meet. The CHI 2020 authors conclude that logarithmic growth
in observed timings "is not necessarily interpretable in terms of Hick's law," and that
"designers should be cautious about invoking Hick's law to justify reducing menu options."
Sources: [CHI 2020 paper](https://perso.telecom-paristech.fr/rioul/publis/202001liugoririoulbeaudouinlafonguiard.pdf),
[Proctor & Schneider 2018 review](https://web.ics.purdue.edu/~dws/pubs/ProctorSchneider_2018_QJEP.pdf).

**Choice overload / the jam study.** Iyengar & Lepper (2000): a supermarket tasting table showed
either **6** or **24** jams. Roughly **60%** of passers-by stopped at the 24-jam display vs. about
**40%** at the 6-jam display, but about **30%** of the small-display stoppers bought vs. about
**3%** of the large-display stoppers.
Source (secondary, numbers consistent across write-ups): [Atticus Li — The Jam Study and Choice Overload](https://atticusli.com/replication-crisis/choice-overload-jam-study/).

**Replication problems.** Scheibehenne, Greifeneder & Todd (2010, *JCR*) meta-analysed **63
conditions from 50 published and unpublished experiments, N = 5,036**, and found a **mean effect
size of virtually zero** with large between-study heterogeneity — some studies strongly positive,
some null, some reversed (more choice was better).
Source: [JCR abstract](https://academic.oup.com/jcr/article-abstract/37/3/409/1827647),
[ResearchGate copy](https://www.researchgate.net/publication/48210291_Can_There_Ever_be_Too_Many_Options_A_Meta-analytic_Review_of_Choice_Overload).
Gonzales (2013) additionally reported a decline effect: strong early results, failures later.

Chernev, Böckenholt & Goodman (2015) argued the effect is real but conditional on four moderators —
choice-set complexity, decision-task difficulty, preference uncertainty, and decision goal.
Source: [Chernev 2015 PDF](https://chernev.com/wp-content/uploads/2017/02/ChoiceOverload_JCP_2015.pdf) (PDF was not machine-readable via fetch; moderators confirmed via secondary sources).

**Unresolved conflict, flagged honestly.** Two sources fetched this session disagree about
Chernev's headline effect size: one secondary write-up reports **d ≈ 0.5–0.6 when all four
moderators are present and ~0 otherwise**
([Atticus Li](https://atticusli.com/replication-crisis/choice-overload-jam-study/)), while
["A Better Test of Choice Overload"](https://arxiv.org/pdf/2212.03931) reports Chernev's mean
effect as **≈ 0.14 SD** and concludes prior evidence for choice overload is weak and, if real,
"substantially smaller than commonly portrayed." Treat any specific Chernev number as
`[UNVERIFIED]` until the paper itself is read.

**Practical rule.** Do not use "Hick's Law" or "the jam study" as the justification for stripping
the Home Screen down. Both are weaker than the design-blog canon implies. The defensible version:
choice overload bites when the set is *complex, the task is hard, and the user is unsure what they
want* — which describes exactly a health screen offering 12 undifferentiated metrics with no
recommendation. The fix is not fewer items; it is one obvious default action plus a clear ranking,
so that the difficult decision is pre-made for the user.

---

## 4. Progressive disclosure, hierarchy, chunking

**What NN/g claims.** Progressive disclosure = "Initially, show users only a few of the most
important options" then "Offer a larger set of specialized options upon request." It improves
learnability, efficiency, and error rate: hiding advanced settings "helps novice users avoid
mistakes," and advanced users save the time of scanning past features they rarely use. NN/g also
rebuts the common objection that hiding things damages the user's mental model — "people understand
a system better when you help them prioritize features."
Source: [NN/g — Progressive Disclosure](https://www.nngroup.com/articles/progressive-disclosure/).

**Effect sizes.** NN/g's article gives **no percentage split** and no effect size. It says only that
you "must disclose everything that users frequently need up front," and recommends task analysis
plus frequency-of-use data to decide the split. Any "80/20" figure attributed to this article is
`[UNVERIFIED]`.

**The hard limit.** Designs with **more than two levels of disclosure** "typically show low
usability because users often get lost when moving between levels."

**Staged vs progressive.** Staged = linear wizard steps; progressive = hierarchical, on demand.
Staged breaks down when steps require going back and forth.

**Chunking.** NN/g's guidance: short paragraphs separated by whitespace, lines of **50–75
characters**, clear visual hierarchy with related items grouped, distinct groupings for strings
such as phone numbers and dates, headings and bulleted lists for scannability.
Source: [NN/g — How Chunking Helps Content Processing](https://www.nngroup.com/articles/chunking/).

**Practical rule.** Home Screen = level 0, metric detail = level 1, everything else = level 2 at the
deepest. Three taps to a number is a design failure. Group by *meaning to the user* (sleep, heart,
movement), never by data provenance (HealthKit vs. derived).

---

## 5. Recognition vs recall, and "what was my number yesterday?"

**What the research claims.** Recognition needs fewer retrieval cues than recall, so it is reliably
easier. Memory activation depends on practice, recency, and context; context spreads activation to
associated concepts, raising accessibility. Menus, search history, "recently viewed," and favourites
are recognition affordances; login forms, command lines, and unlabeled gestures force recall.
NN/g cites Adar, Teevan & Dumais (2008): users prefer to re-find pages by searching (recognition)
rather than recalling the URL.
Source: [NN/g — Memory Recognition and Recall in User Interfaces](https://www.nngroup.com/articles/recognition-and-recall/).

**Applied to yesterday's numbers — the important, non-obvious finding.** Across the patient-facing
literature, **presentation format did not significantly affect recall of test results** in any of
the three studies that measured memory.
Source: [Enhancing Patient Understanding of Laboratory Test Results: Systematic Review (18 studies, 12,225 participants)](https://pmc.ncbi.nlm.nih.gov/articles/PMC11347896/).
Translation: you cannot design a card that makes people *remember* their number better. You can
only design one that removes the need to remember it.

**Evaluability.** A single number in isolation is close to meaningless to a non-expert. Hsee's
evaluability hypothesis (1996) shows that attributes which are hard to evaluate in isolation carry
almost no weight until a comparison is present.
Source: [Hsee 1996, OBHDP 67:247-257](https://pages.ucsd.edu/~cmckenzie/Hsee1996OBHDP.pdf).

**Practical rule.** Never show a bare number. Ship the comparison with it, on the same line, in the
same glance: today vs. your 7-day norm, or today vs. your goal, or today vs. yesterday. Assume the
user remembers nothing from the last session — because the evidence says they don't, and no chart
type fixes that.

---

## 6. Visual scanning: F-pattern is not universal, layer-cake is the target

**What NN/g's eye tracking actually says.** There are several distinct scanning patterns, not one.
Sources: [NN/g — F-Shaped Pattern of Reading on the Web](https://www.nngroup.com/articles/f-shaped-pattern-reading-web-content/),
[NN/g — Text Scanning Patterns: Eyetracking Evidence](https://www.nngroup.com/articles/text-scanning-patterns-eyetracking/).

- **F-pattern** — two horizontal sweeps plus a vertical run down the left edge. It emerges only when
  three conditions co-occur: unformatted text with "no bolding, bullets, or subheadings"; a user
  optimising for efficiency; and low motivation to read thoroughly. NN/g's position is blunt:
  "The F-pattern is the default pattern when there are no strong cues to attract the eyes towards
  meaningful information," and it is "bad for users and businesses" because "users may skip
  important content simply because it appears on the right side of the page." NN/g's own 2006
  heatmaps aggregated 45+ participants; a recent confirmatory heatmap aggregated 47 people. In
  right-to-left languages the F is mirrored.
- **Layer-cake** — fixations land on headings and subheadings, with body text read selectively
  underneath. NN/g calls this "by far the most effective way" to scan a page. **This is the pattern
  to design for.**
- **Spotted** — the user skips prose hunting for a specific target (a link, a digit, a name).
  Triggered by visually distinct elements and by a specific goal.
- **Commitment** — near-exhaustive reading, seen only with high motivation, trust, or perceived
  relevance.
- **Marking** — eyes hold one position while the content scrolls past. NN/g notes this is more
  common on mobile.
- **Bypassing** — users skip the opening words of lines that all start with the same word.

**The myth.** "Users read in an F" is stated in design decks as a universal law. It is not. It is
the *failure mode* NN/g measured on unstructured text blocks, and NN/g explicitly recommends eight
interventions to prevent it. Treating F as a layout template — cramming everything into the top-left
L — is a misreading of the source.

**Z-pattern.** Widely repeated in design writing for sparse, poster-like layouts. No NN/g
eye-tracking study supporting a Z-pattern was found in this session. Treat "Z-pattern" as
`[UNVERIFIED]` folklore, not research.

**Practical rule.** Design the Home Screen as a layer cake: every card gets a short, front-loaded,
information-carrying heading; the number sits directly under or beside it; the interpretation sits
under that. Front-load the first two or three words of each heading (bypassing means "Your sleep
score", "Your step count", "Your heart rate" all read as "Your…"). Never place meaning-critical
content on the right edge of a card where F-scanning drops it.

---

## 7. Mobile: the fold, scrolling, screen cost, thumbs

**The fold still exists.** NN/g's eye-tracking corpus (130,000+ fixations, 120 participants,
1920×1080) found **57% of viewing time above the fold**, **74% within the first two screenfuls**,
and only **26%** beyond. Within the visible area, **more than 65% of above-fold viewing time
concentrated in the top half of the viewport**. The top 20% of a page took 42%+ of viewing time;
the top 40% took 65%+. In 2010 the above-fold share was 80%; users have adapted to longer pages,
"but they rarely scroll beyond the third screenful."
Source: [NN/g — Scrolling and Attention](https://www.nngroup.com/articles/scrolling-and-attention/).

Related NN/g figures: content 100 px above the fold got **102% more views** than content 100 px
below it; Google's own ad data showed **73% viewability above the fold vs 44% below**; NN/g's
summary figure is that **84% is the average difference in how users treat info above vs. below the
fold**.
Source: [NN/g — The Fold Manifesto](https://www.nngroup.com/articles/page-fold-manifesto/).

**Small screens cost real money.** NN/g: content that fits one screenful on a 30-inch monitor takes
**5 screenfuls on a 4-inch phone**; mobile sessions averaged **72 seconds** vs **150 seconds** on
desktop. Their guidance is a high "content-to-chrome ratio," ruthless prioritisation, and "the gist
before the minutiae." Study base: **151 participants** across six countries over seven years.
Source: [NN/g — Mobile UX](https://www.nngroup.com/articles/mobile-ux/).

**Comprehension is *not* much worse on mobile — but it costs more effort.** Across **1,629 reading
instances / 276+ participants**, NN/g measured mobile comprehension about **3 percentage points
higher** (CI 1–5%, p = 0.0006) — statistically significant, practically meaningless. The real
finding is the speed–accuracy tradeoff: on difficult content, mobile readers slowed by about
**30 ms per word** to reach the same comprehension. They worked harder for the same result.
Source: [NN/g — Mobile Content Is Twice as Difficult](https://www.nngroup.com/articles/mobile-content-is-twice-as-difficult/).

**Thumbs.** Hoober's field observation of **over 1,300 people**: **49% one-handed**, **36% cradled**
(hold in one hand, tap with the other), **15% two-handed**. **Thumbs drive ~75% of all phone
interactions.** On phablets, two hands are needed **70%** of the time; the most common phablet grip
(**35%**) is hold-in-one-hand / tap-with-index-finger, yet **60%** of phablet taps are still thumbs.
His design conclusion is to "always accommodate the most constrained grip."
Source: [Hoober — How Do Users Really Hold Mobile Devices, A List Apart](https://alistapart.com/article/how-we-hold-our-gadgets/).

**What is contested here.** Hoober's data is 2013 observational field data, collected before phones
grew to 6.5"+. The three-zone "green/yellow/red" thumb map is a design-community elaboration, not
a controlled study. Several 2024–2026 blog posts circulate specific conversion numbers
("55% less effort", "35–55% conversion lift", "62% abandon in three minutes"); none of these trace
to a peer-reviewed or first-party source and all are `[UNVERIFIED]` — do not quote them internally.

**Practical rule.** The first screenful is not "most of" the attention, it is the *only* screenful
we can rely on. Put the single most important health fact and the single most important action in
the top half of the first screen. Interactive controls belong in the lower two-thirds where the
thumb reaches; the top strip is for reading, not tapping. Assume everything below screen two is
optional.

---

## 8. Apple Human Interface Guidelines (first-party, fetched from Apple's docs API)

All quotes below are from Apple's live HIG content, retrieved via
`developer.apple.com/tutorials/data/design/human-interface-guidelines/*.json`.

### Widgets and glanceability — the density rule
> "**Balance information density.** Sparse layouts can make the widget seem unnecessary, while
> overly dense layouts are less glanceable. Create a layout that provides essential information at
> a glance and allows people to view additional details by taking a longer look. **If your layout is
> too dense, consider improving its clarity by using a larger widget size or replacing text with
> graphics.**"

Other load-bearing widget rules:
- "Display only the information that's directly related to the widget's main purpose."
- "Prefer dynamic information that changes throughout the day. If a widget's content never appears
  to change, people may not keep it in a prominent position."
- "Avoid very small font sizes. In general, display text using fonts at **11 points or larger**."
- Standard widget margin is **16 pt**; **11 pt** works for tighter internal content groupings.
- "Convey meaning without relying on specific colors to represent information… Use text and
  iconography in addition to color to express meaning."
- Widgets support Dynamic Type sizes **from Large to AX5**.

Source: [HIG — Widgets](https://developer.apple.com/design/human-interface-guidelines/widgets).

### Complications (the strictest glance budget Apple publishes)
- "Identify essential, dynamic content that people want to view at a glance."
- Gauge/ring styles: **closed** for a percentage of a whole; **open** for arbitrary min/max;
  **segmented** for rapidly changing values.
- "Generally use line widths of **two points or greater**. Thinner lines can be difficult to see at
  a glance, especially when the wearer is in motion."
- Privacy: with Always-On, "information on the watch face might be visible to people other than the
  wearer."

Source: [HIG — Complications](https://developer.apple.com/design/human-interface-guidelines/complications).

### Charting data — when a chart beats a sentence, per Apple
> "**Not every collection of data needs to be displayed in a chart.** If you simply need to provide
> data — and you don't need to convey information about it or help people analyze it — consider
> offering the data in other ways, such as in a list or table."

> "**Keep a chart simple**, letting people choose when they want additional details. Resist the
> temptation to pack as much data as possible into a chart."

> "**Aid comprehension by adding descriptive text to the chart.** Descriptive text titles,
> subtitles, and annotations help emphasize the most important information… For example, Weather
> displays text that summarizes the information people need right now — such as 'Chance of light
> rain in the next hour' — above the scrolling list of hourly forecasts."

Also: prefer common chart types; maintain visual continuity between a small preview chart and its
expanded version (Apple cites Health Trends as the model — the small trend chart and the expanded
chart share style, colours, marks, and annotations).

Source: [HIG — Charting Data](https://developer.apple.com/design/human-interface-guidelines/charting-data).

### Colour semantics
- "Avoid using the same color to mean different things."
- "Avoid relying solely on color to differentiate between objects, indicate interactivity, or
  communicate essential information."
- "Avoid hard-coding system color values… Use APIs like [semantic colors] to apply system colors."
- "Avoid redefining the semantic meanings of dynamic system colors."
- iOS defines background hierarchy as **primary → secondary → tertiary** (system and grouped sets)
  and label hierarchy as **label / secondaryLabel / tertiaryLabel / quaternaryLabel**.
- Culture matters and Apple calls it out with a health-adjacent example: green = positive trend in
  Stocks in English, **red = positive trend in Chinese**.

Source: [HIG — Color](https://developer.apple.com/design/human-interface-guidelines/color).

### Dark mode
- "Avoid offering an app-specific appearance setting."
- Dark-mode colours "aren't necessarily inversions of their light counterparts."
- Contrast: "At a minimum, make sure the contrast ratio between colors is no lower than **4.5:1**.
  For custom foreground and background colors, strive for a contrast ratio of **7:1**, especially
  in small text."
- Watch for the trap: turning on Increase Contrast *in* Dark Mode "can result in reduced visual
  contrast between dark text and a dark background."

Source: [HIG — Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode).

### Typography and Dynamic Type
- iOS default text size **17 pt**, minimum **11 pt**.
- "In general, avoid light font weights… prefer Regular, Medium, Semibold, or Bold."
- "**Prioritize important content when responding to text-size changes.** Not all content is equally
  important… they don't always want to increase the size of every word on the screen."
- "**Maintain a consistent information hierarchy regardless of the current font size.** For example,
  keep primary elements toward the top of a view even when the font size is very large."
- "Keep text truncation to a minimum as font size increases… aim to display as much useful text at
  the largest accessibility font size as you do at the largest standard font size."
- "Consider adjusting your layout at large font sizes" — stack text above secondary items; reduce
  column count.

Source: [HIG — Typography](https://developer.apple.com/design/human-interface-guidelines/typography).

### Accessibility contrast table (Apple's own, from WCAG AA)
| Text size | Weight | Minimum contrast |
|---|---|---|
| Up to 17 pt | All | **4.5:1** |
| 18 pt | All | **3:1** |
| Any | Bold | **3:1** |

Plus: support enlargement of at least **200%** (140% on watchOS); prefer system-defined colours
because they have accessible variants; "convey information with more than color alone" — red-green
and blue-orange pairings are called out specifically.

Source: [HIG — Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility).

---

## 9. Material Design 3 — what is usable for data-dense cards

The M3 site (`m3.material.io`) is a JavaScript app and could not be scraped this session; the
guidance below comes from Google's older static Material spec plus first-party Android docs. Treat
the M3-specific wording as `[UNVERIFIED]`, the underlying rules as sound.

**When a card is the wrong container.** Material's own do/don't is directly relevant to a health
Home Screen: use cards for content that "comprises multiple data types," "does not require direct
comparison," "supports content of highly variable length," or "contains interactive content."
And explicitly: "A quickly scannable list, instead of cards, is an appropriate way to represent
homogeneous content that doesn't have many actions," with the don't-case being "The use of cards
here distracts the user from being able to quickly scan."
Source: [Material — Cards (static spec)](https://m1.material.io/components/cards.html).

**M3 card types.** Elevated / filled / outlined. Per Google's own docs the three "provide the same
legibility and functionality, so the type you use depends on style alone" — i.e. card style carries
**no** semantic weight and must not be used to encode importance.
Source: [M3 Cards](https://m3.material.io/components/cards/guidelines) (via search snippet),
[material-components-android Card.md](https://github.com/material-components/material-components-android/blob/master/docs/components/Card.md).

**Touch and density.** Minimum touch target **48×48 dp** (~9 mm physical), with targets separated
by **8 dp or more** "to ensure balanced information density and usability." Text contrast 4.5:1
small / 3:1 large, matching WCAG.
Source: [Android Accessibility — Touch target size](https://support.google.com/accessibility/android/answer/7101858),
[Material accessibility (static)](https://m1.material.io/usability/accessibility.html).

**Practical rule.** If our six metrics are homogeneous and directly comparable, a **scannable list
or a compact grid beats six separate cards** — that is Google's own stated do/don't, and it also
solves the F-pattern risk. Reserve cards for heterogeneous, variable-length, actionable content
(an insight, a streak, a nudge). Do not use elevated-vs-outlined to signal "this one is important."

---

## 10. Dashboard design and data visualisation

**Few's definition and mistakes.** Stephen Few: a dashboard is "a visual display of the most
important information needed to achieve one or more objectives, consolidated and arranged on a
single screen so that the information can be monitored at a glance," and it "must be able to
condense a lot of information onto a single screen and present it at a glance without sacrificing
anything important or compromising clarity." His thirteen common mistakes include exceeding a
single screen, **supplying inadequate context for data**, displaying excessive detail or precision,
choosing a deficient measure, using inappropriate display media, meaningless variety, encoding
quantities inaccurately, poor layout, failing to highlight what matters, useless clutter, and
misusing colour.
Source: [UXmatters review of *Information Dashboard Design*](https://www.uxmatters.com/mt/archives/2007/04/book-review-information-dashboard-design.php),
[datarocks summary](https://www.datarocks.co.nz/post/data-viz-bookshelf_information-dashboard-design-stephen-few).

**Tufte's data-ink ratio — and the empirical pushback.** Tufte's minimalism ("max[data],
min[design]") is influential but was argued from his own aesthetic judgement, not experiments.
Inbar, Tractinsky et al. found a clear preference for *non-minimalist* bar graphs — low acceptance
of high data-ink minimalism. Bateman et al. (2010) "Useful Junk?" found embellished charts were
better recalled both short- and long-term and may raise engagement; later work (2013, 2015)
re-asserted that chartjunk is not always harmful. The literature's consensus is that "no simple
rule like data-ink ratio can suffice."
Sources: [Performance Magazine — How data-ink ratio imposed minimalism](https://www.performancemagazine.org/data-ink-ratio-minimalism-data-visualization/),
[Bateman et al. 2010 PDF](https://sites.stat.columbia.edu/gelman/communication/Bateman2010.pdf) (PDF not machine-readable via fetch; findings from the search corpus — treat exact Ns as `[UNVERIFIED]`),
[Inbar et al. — Minimalism in information visualization](https://www.researchgate.net/publication/220956267_Minimalism_in_information_visualization_Attitudes_towards_maximizing_the_data-ink_ratio),
[Frank Elavsky — the absurdity of the data-to-ink ratio](https://www.frank.computer/blog/2025/04/data-to-ink.html).

**Sparklines.** Tufte: "a small intense, simple, word-sized graphic with typographic resolution" —
"datawords: data-intense, design-simple, word-sized graphics" that "can be everywhere a word or
number can be." Design rules he states: bank slopes toward **45°** for a "lumpy" rather than spiky
or flat profile; use a **grey reference band for the normal range** so deviations pop; prefer
design minimisation over data minimisation.
Source: [Tufte — Sparkline theory and practice](https://www.edwardtufte.com/notebook/sparkline-theory-and-practice-edward-tufte/).

**Preattentive encoding — which marks are actually fast.** NN/g: length, area, angle, 2D position,
and colour are preattentive, but they are not equal.
- **Length and 2D position** let people "accurately estimate" values → best for quantitative data.
- **Area and angle** let people notice a difference but not judge its size → poor.
- **Colour** is preattentive but "should not be used to communicate quantitative values or
  magnitude," because people do not perceive colours as ordered.
- Explicitly avoid: pie charts, donut charts, **gauges**, treemaps, and all 3D.
Source: [NN/g — Preattentive Visual Properties and How to Use Them in Data Visualization](https://www.nngroup.com/articles/dashboards-preattentive/).

**Cairo's five qualities.** Truthful, functional, beautiful, insightful, enlightening — with
"enlightening" as the emergent product of the other four, and "functional" defined as choosing the
right form for the task.
Source: [The Data School — Cairo's five qualities](https://www.thedataschool.co.uk/laura-brylka/the-five-qualities-of-great-vizualizations-according-to-alberto-cairo/).

**When a chart beats a sentence.** Apple's rule: only when you need to *convey information about*
the data or help someone analyse it — otherwise a list is better. Few's rule: only when the display
medium actually fits the measure. The health-specific evidence (§11) is sharper still.

---

## 11. Health-dashboard-specific and patient-facing research — the strongest evidence we have

This is the most directly transferable body of work, and it contradicts several general dataviz
instincts.

**Line graphs are the most-used and among the hardest to read.** Systematic review of **39
articles (27 with human subjects), sample sizes 7 to 6,700+, mean N = 369**: line graphs **35%**,
number lines **25%**, bar graphs **16%**, icons **12%**. Finding: "More patients understand the
number lines and bar graphs compared with line graphs." Metaphorical icons backfired (people read
fruit icons literally as servings). **Medium-risk / borderline values were the hardest case across
every visualisation type**, and **confidence in interpretation did not track actual comprehension**.
Only **19%** of studies measured health literacy, **11%** numeracy, **7%** graph literacy; samples
skewed **60% female, 70% White, 77% college-educated**.
Source: [A Systematic Review of Patient-Facing Visualizations of Personal Health Data](https://pmc.ncbi.nlm.nih.gov/articles/PMC6785326/).

**Horizontal line bars with reference ranges win.** Systematic review of **18 studies, 12,225
participants** (72% US, 89% mock results). Most-examined formats: numeric with reference range
(12 studies), horizontal line bars with coloured blocks (12), and the two combined (8). Findings:
horizontal line bars with coloured blocks scored highest on satisfaction and usability; adding
evaluative labels or personalised goal ranges further improved understanding; **horizontal line
bars significantly reduced intention to contact a physician** vs numeric formats; and — critically —
**presentation format did not significantly affect recall in any of the three memory studies**.
Source: [Enhancing Patient Understanding of Laboratory Test Results: Systematic Review](https://pmc.ncbi.nlm.nih.gov/articles/PMC11347896/).

**A number in a table is invisible.** In an experiment with **1,817 US adults**, only **51%**
correctly identified a moderately elevated HbA1c of 8.4% as outside the reference range when it was
shown in a standard table.
Source: [BMC Med Inform Decis Mak — Presentation of laboratory test results in patient portals](https://link.springer.com/article/10.1186/s12911-018-0589-7) (paywall redirect; figure obtained via search corpus, `[UNVERIFIED against full text]`).

**Substitute context ranges, don't add them.** Scherer, Witteman, Solomon, Exe, Fagerlin &
Zikmund-Fisher (JMIR 2018), **N = 6,766**, three display conditions — standard range only, goal
range *added* to standard range, goal range *only*. Comprehension of the result's relative location
(HbA1c 6.2%, table format): **14.49% → 35.92% → 43.45%** (χ²₂ = 126.9, p < .001). Comprehension of
expected future location: **22.97% → 37.39% → 46.97%** (χ²₂ = 36.0, p < .001). Conclusion:
"Removing the standard range and substituting it with a single goal reference range seems superior
to simply adding goal range information" — multiple reference ranges create confusion about which
one is relevant.
Source: [JMIR 2018;20(10):e11027](https://www.jmir.org/2018/10/e11027/) · [PMC copy](https://pmc.ncbi.nlm.nih.gov/articles/PMC6231727/).

**Harm anchors reduce false alarm.** **N = 1,618** US adults. Visual line displays that added a
harm-anchor reference ("Many doctors are not concerned until here") **significantly reduced
perceived urgency of close-to-normal ALT and creatinine results (p < .001)** and substantially cut
the number of people wanting to contact a doctor urgently or go to hospital. It did not generalise
to platelet count.
Source: [JMIR 2018;20(3):e98 — Effect of Harm Anchors in Visual Displays of Test Results](https://www.jmir.org/2018/3/e98/PDF) · [PubMed](https://pubmed.ncbi.nlm.nih.gov/29581088/).

**What patients want from a health dashboard.** Scoping review of patient-generated health data
dashboards (**15 studies from 468 screened**; diabetes 4, hypertension 3, heart failure 1). Six
recurring wants: **longitudinal display over time; aggregation of multiple data types on one screen
to spot correlations; interpretation and actionability (largely absent from existing systems);
customisation; speed (<30 s to useful); and integration with existing workflow.** Line graphs
dominated nearly every dashboard.
Source: [Visualization of Patient-Generated Health Data: A Scoping Review of Dashboard Designs](https://pmc.ncbi.nlm.nih.gov/articles/PMC10665122/).
Broader dashboard scoping review: participatory/co-designed dashboards showed stronger usability;
co-designed ones favoured "targeted, high-resolution displays with **limited indicator sets**,"
while top-down public dashboards chased breadth with simplified visuals.
Source: [Design Practices for Data Dashboards in Health Care: Scoping Review](https://pmc.ncbi.nlm.nih.gov/articles/PMC12980066/).

**Graph literacy is not universal.** Galesic & Garcia-Retamero: nationally representative samples in
Germany (n = 495) and the US (n = 492), ages 25–69. **About one third of participants had low graph
literacy and numeracy.** Graph literacy and numeracy correlate — people with limited numeracy tend
to have limited graph literacy too. "Not everyone profits from standard visual displays."
Source: [Galesic & Garcia-Retamero, Medical Decision Making 2011](https://journals.sagepub.com/doi/abs/10.1177/0272989x10373805) · [MPG full text](https://pure.mpg.de/rest/items/item_2099200/component/file_3565339/content).

**Practical rule (this section outranks §10 where they conflict).**
1. A number gets a **positional bar with a range**, not a line chart, as its default representation.
2. Show **one** range — the user's personal goal band — not both a population "normal" band and a
   personal goal band.
3. Add an explicit "not a concern until here" boundary for anything that could read as alarming.
4. Always pair the visual with a **plain sentence** verdict, because a third of users cannot read
   the graph.
5. Never rely on the user recalling last week's value.

---

## 12. Attention economy, decision fatigue, notification fatigue

**The framing.** Herbert Simon, 1971: "In an information-rich world, the wealth of information means
a dearth of something else: a scarcity of whatever it is that information consumes. What information
consumes is rather obvious: it consumes the attention of its recipients. Hence a wealth of
information creates a poverty of attention."
Source: [Simon, "Designing Organizations for an Information-Rich World"](https://hapgood.us/2018/10/08/designing-organizations-for-an-information-rich-world/).

**Notification volume and cost.** Pielot & Rello: participants handled **63.5 notifications per day
on average**, mostly messengers and email; more notifications correlated with more negative emotion —
though more messages and social updates also made people feel more connected. In the Do Not Disturb
Challenge (24 hours with notifications off) people felt **both more productive and more anxious**,
with large individual differences.
Sources: [Pielot — The Do Not Disturb Challenge (CHI '15)](https://pielot.org/2015/04/the-do-not-disturb-challenge/),
[Productive, Anxious, Lonely — 24 Hours Without Push Notifications](https://arxiv.org/pdf/1612.02314).

Kushlev, Proulx & Dunn (CHI 2016), **N = 221**, within-subjects, one week alerts-on / one week
alerts-off: participants reported **higher inattention and hyperactivity when alerts were on**.
Source: [ACM DL — "Silence Your Phones"](https://dl.acm.org/doi/10.1145/2858036.2858359).

**Banner blindness — the habituation risk for a daily screen.** NN/g eye-tracking across 1997, 2007
and 2018 finds users systematically skip anything that looks like an ad — by **location** (top
banner, right rail), by **visual treatment** (animated, colourful, distinctly formatted), and by
**proximity** ("hot potato" avoidance of whole regions near an ad). In one case the right rail took
**0.8% of fixations while occupying 25% of the content area — 33× less attention than its size
warrants**. A 2018 study with 26 participants confirmed it persists.
Source: [NN/g — Banner Blindness: Old and New Findings](https://www.nngroup.com/articles/banner-blindness-old-and-new-findings/).

**Decision fatigue / ego depletion — heavily contested, do not build on it.**
- Hagger et al. (2016) Registered Replication Report: **23 labs, 2,141 participants**, preregistered.
  Result was **consistent with a null effect** for that paradigm.
  Source: [Perspectives on Psychological Science](https://journals.sagepub.com/doi/10.1177/1745691616652873),
  [PMC commentary](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4971805/).
- A later multi-site preregistered paradigmatic test again yielded "no evidence for or against."
  Source: [PMC8134656](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8134656/).
- The famous "hungry judges" study (Danziger, Levav & Avnaim-Pesso 2011, PNAS; **1,112 parole
  hearings, 8 judges, 10 months**, ~65% favourable right after a break falling to near 0% before
  one) is the single most-cited decision-fatigue result and is badly undermined: Weinshall-Margel &
  Shapard showed cases were **systematically ordered** (unrepresented prisoners typically go last
  and are less likely to be paroled), and simulation work found the effect magnitude
  **overestimated by roughly 2–3×** by unmodelled case sequencing.
  Sources: [The irrational hungry judge effect revisited (Judgment and Decision Making)](https://www.cambridge.org/core/journals/judgment-and-decision-making/article/irrational-hungry-judge-effect-revisited-simulations-reveal-that-the-magnitude-of-the-effect-is-overestimated/61CE825D4DC137675BB9CAD04571AE58),
  [Beware the Lure of Narratives (German Law Journal)](https://www.cambridge.org/core/journals/german-law-journal/article/beware-the-lure-of-narratives-hungry-judges-should-not-motivate-the-use-of-artificial-intelligence-in-law/734C6F05568636FE09A26D1C4D52D627).

**Health-app abandonment — the real attrition constraint.** Roughly **53% of mHealth apps are
uninstalled within 30 days**; in one large study mean engagement lasted **4.1 days**. Top stated
reason for abandonment: **lack of interest / declining motivation (31.6%)**; **21.5%** described
downloading several apps and deleting all but one.
Source: [User Engagement and Abandonment of mHealth: A Cross-Sectional Survey](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8872344/),
[JMIR — User Engagement and Attrition in an App-Based Physical Activity Intervention](https://www.jmir.org/2019/11/e14645/).

**Practical rule.** Do not justify a minimal Home Screen with "decision fatigue" — that literature
does not survive replication and citing it internally will not hold up. Justify it with attrition:
we have roughly a 30-day window and a 4-day median engagement to prove value. Separately, treat any
fixed, always-identical region of the Home Screen as a banner-blindness candidate: if a card shows
the same thing every day it will stop being seen, exactly as Apple warns for widgets ("if a widget's
content never appears to change, people may not keep it in a prominent position").

---

## Summary table — what to trust, how strongly

| Claim | Evidence strength | Use it? |
|---|---|---|
| Show a bar/number-line with a range, not a line chart, for a single value | Two systematic reviews, 12k+ and 6.7k participants | **Yes, strong** |
| Substitute one goal range; never show two ranges | RCT-style experiment, N = 6,766, p < .001 | **Yes, strong** |
| Add a "not concerning until here" anchor | Experiment, N = 1,618, p < .001 | **Yes, strong** |
| Format cannot improve recall of a number | 3 studies in a systematic review, all null | **Yes — plan around it** |
| ~1/3 of users have low graph literacy | 2 national samples, n≈1,000 | **Yes, strong** |
| Top half of first screen carries most attention | NN/g, 130k fixations, 120 participants | **Yes** |
| Layer-cake scanning is the design target; F-pattern is a failure mode | NN/g eye tracking, 45–47 participants per study | **Yes** |
| Working-memory concurrent limit ≈ 4, not 7 | Cowan 2001 review; still debated | **Yes, with caveat** |
| Thumb zone / 49% one-handed | 2013 field observation, n>1,300, pre-large-phone | **Directionally** |
| Hick's Law justifies fewer options | Refuted for HCI (CHI 2020) | **No** |
| Miller's 7±2 caps visible items | Refuted (NN/g, Miller himself) | **No** |
| Jam study proves less choice is better | Meta-analysis d ≈ 0, N = 5,036 | **No** |
| Decision fatigue / ego depletion | Failed 23-lab preregistered replication | **No** |
| Data-ink maximalism / kill all decoration | Contradicted by Bateman, Inbar | **No — use judgement** |
| Z-pattern | No eye-tracking source found | **No — folklore** |

---

## Sources fetched or searched in this session

Nielsen Norman Group: [F-shaped pattern](https://www.nngroup.com/articles/f-shaped-pattern-reading-web-content/) ·
[Text scanning patterns](https://www.nngroup.com/articles/text-scanning-patterns-eyetracking/) ·
[Progressive disclosure](https://www.nngroup.com/articles/progressive-disclosure/) ·
[Chunking](https://www.nngroup.com/articles/chunking/) ·
[Recognition and recall](https://www.nngroup.com/articles/recognition-and-recall/) ·
[Scrolling and attention](https://www.nngroup.com/articles/scrolling-and-attention/) ·
[The fold manifesto](https://www.nngroup.com/articles/page-fold-manifesto/) ·
[Mobile UX](https://www.nngroup.com/articles/mobile-ux/) ·
[Mobile content is twice as difficult](https://www.nngroup.com/articles/mobile-content-is-twice-as-difficult/) ·
[Banner blindness](https://www.nngroup.com/articles/banner-blindness-old-and-new-findings/) ·
[Preattentive properties](https://www.nngroup.com/articles/dashboards-preattentive/)

Apple HIG (fetched from Apple's docs API): [Widgets](https://developer.apple.com/design/human-interface-guidelines/widgets) ·
[Complications](https://developer.apple.com/design/human-interface-guidelines/complications) ·
[Charting data](https://developer.apple.com/design/human-interface-guidelines/charting-data) ·
[Color](https://developer.apple.com/design/human-interface-guidelines/color) ·
[Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode) ·
[Typography](https://developer.apple.com/design/human-interface-guidelines/typography) ·
[Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)

Material: [Cards (static spec)](https://m1.material.io/components/cards.html) ·
[M3 cards](https://m3.material.io/components/cards/guidelines) ·
[Android touch targets](https://support.google.com/accessibility/android/answer/7101858) ·
[Material accessibility](https://m1.material.io/usability/accessibility.html)

Health / patient-facing: [Patient-facing visualizations systematic review](https://pmc.ncbi.nlm.nih.gov/articles/PMC6785326/) ·
[Lab result presentation formats systematic review](https://pmc.ncbi.nlm.nih.gov/articles/PMC11347896/) ·
[Substituting goal ranges (JMIR)](https://www.jmir.org/2018/10/e11027/) · [PMC copy](https://pmc.ncbi.nlm.nih.gov/articles/PMC6231727/) ·
[Harm anchors (JMIR)](https://www.jmir.org/2018/3/e98/PDF) ·
[PGHD dashboard scoping review](https://pmc.ncbi.nlm.nih.gov/articles/PMC10665122/) ·
[Health-care dashboard design practices](https://pmc.ncbi.nlm.nih.gov/articles/PMC12980066/) ·
[Patient portal lab results interface design](https://link.springer.com/article/10.1186/s12911-018-0589-7) ·
[Graph literacy](https://journals.sagepub.com/doi/abs/10.1177/0272989x10373805) ·
[mHealth abandonment](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8872344/) ·
[App-based intervention attrition](https://www.jmir.org/2019/11/e14645/)

Psychology / HCI theory: [Cowan 2001](https://philpapers.org/rec/COWTMN) ·
[Cowan PDF](https://www.cambridge.org/core/services/aop-cambridge-core/content/view/44023F1147D4A1D44BDC0AD226838496/S0140525X01003922a.pdf/the-magical-number-4-in-short-term-memory-a-reconsideration-of-mental-storage-capacity.pdf) ·
[Modelling WM capacity: four, seven, or?](https://journalofcognition.org/articles/10.5334/joc.387) ·
[UX Myths #23](https://uxmyths.com/post/931925744/myth-23-choices-should-always-be-limited-to-seven) ·
[Laws of UX — Hick's Law](https://lawsofux.com/hicks-law/) ·
[How Relevant is Hick's Law for HCI? (CHI 2020)](https://perso.telecom-paristech.fr/rioul/publis/202001liugoririoulbeaudouinlafonguiard.pdf) ·
[Proctor & Schneider 2018](https://web.ics.purdue.edu/~dws/pubs/ProctorSchneider_2018_QJEP.pdf) ·
[Scheibehenne et al. 2010 (JCR)](https://academic.oup.com/jcr/article-abstract/37/3/409/1827647) ·
[Chernev et al. 2015](https://chernev.com/wp-content/uploads/2017/02/ChoiceOverload_JCP_2015.pdf) ·
[A Better Test of Choice Overload](https://arxiv.org/pdf/2212.03931) ·
[Jam study replication summary](https://atticusli.com/replication-crisis/choice-overload-jam-study/) ·
[Hsee 1996 evaluability](https://pages.ucsd.edu/~cmckenzie/Hsee1996OBHDP.pdf) ·
[Hagger et al. 2016 RRR](https://journals.sagepub.com/doi/10.1177/1745691616652873) ·
[Multi-site ego depletion test](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8134656/) ·
[Hungry judge effect revisited](https://www.cambridge.org/core/journals/judgment-and-decision-making/article/irrational-hungry-judge-effect-revisited-simulations-reveal-that-the-magnitude-of-the-effect-is-overestimated/61CE825D4DC137675BB9CAD04571AE58) ·
[Beware the Lure of Narratives](https://www.cambridge.org/core/journals/german-law-journal/article/beware-the-lure-of-narratives-hungry-judges-should-not-motivate-the-use-of-artificial-intelligence-in-law/734C6F05568636FE09A26D1C4D52D627) ·
[Cognitive load theory overview](https://www.sciencedirect.com/topics/psychology/cognitive-load-theory) ·
[CLT revisited](https://wegrowteachers.com/cognitive-load-theory-revisited/)

Mobile / attention: [Hoober — How we hold our gadgets](https://alistapart.com/article/how-we-hold-our-gadgets/) ·
[Smashing — The thumb zone](https://www.smashingmagazine.com/2016/09/the-thumb-zone-designing-for-mobile-users/) ·
[Simon 1971 on attention](https://hapgood.us/2018/10/08/designing-organizations-for-an-information-rich-world/) ·
[Pielot — Do Not Disturb Challenge](https://pielot.org/2015/04/the-do-not-disturb-challenge/) ·
[24 hours without push notifications](https://arxiv.org/pdf/1612.02314) ·
[Kushlev et al. 2016](https://dl.acm.org/doi/10.1145/2858036.2858359)

Data visualisation: [Tufte — Sparkline theory and practice](https://www.edwardtufte.com/notebook/sparkline-theory-and-practice-edward-tufte/) ·
[Few — Information Dashboard Design review](https://www.uxmatters.com/mt/archives/2007/04/book-review-information-dashboard-design.php) ·
[What isn't a dashboard (Few summary)](https://www.datarocks.co.nz/post/data-viz-bookshelf_information-dashboard-design-stephen-few) ·
[Data-ink ratio criticism](https://www.performancemagazine.org/data-ink-ratio-minimalism-data-visualization/) ·
[Bateman et al. — Useful Junk?](https://sites.stat.columbia.edu/gelman/communication/Bateman2010.pdf) ·
[Inbar et al. — Minimalism in infovis](https://www.researchgate.net/publication/220956267_Minimalism_in_information_visualization_Attitudes_towards_maximizing_the_data-ink_ratio) ·
[Elavsky — absurdity of data-to-ink](https://www.frank.computer/blog/2025/04/data-to-ink.html) ·
[Cairo's five qualities](https://www.thedataschool.co.uk/laura-brylka/the-five-qualities-of-great-vizualizations-according-to-alberto-cairo/)

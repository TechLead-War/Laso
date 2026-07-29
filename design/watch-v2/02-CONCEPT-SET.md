# The ten concepts

Each concept is a different **answer to "why would someone raise their wrist?"** — not a different
skin. They are deliberately in tension with each other. Several are mutually exclusive by design;
that is the point of running ten.

The differentiating axis for each is the **primary question it answers first**, which then forces
everything else: what the hero element is, what the navigation model is, which surface carries the
most weight, and how many times a day the design can honestly expect to be opened.

| # | Slug | Name | First question | Hero element | Primary surface | Philosophy in one line |
|---|---|---|---|---|---|---|
| 01 | `energy` | **Body Battery** | *How much have I got left?* | A depleting 0-100 charge | Complication (changes hourly) | Your body is a battery that drains and recharges in real time |
| 02 | `verdict` | **One Word** | *What should I do?* | A single word + colour | App screen | The watch should answer, not report — no numbers at all on the first screen |
| 03 | `pulse` | **Live Pulse** | *What is my body doing right now?* | Live BPM, updating | App screen (live) | The wrist owns *now*; the phone owns *history* |
| 04 | `compass` | **Recovery Compass** | *Am I in balance?* | A 2-axis dot: recovery vs strain | Smart Stack widget | One number cannot hold two forces; show the position, not the score |
| 05 | `timeline` | **Body Clock** | *What should I do in the next few minutes?* | A day timeline with a "now" marker and next window | Smart Stack widget | Health is a sequence of time windows, not a daily verdict |
| 06 | `radar` | **Health Radar** | *Is anything unusual happening?* | "All clear" — or the one thing that is not | Notification | A sentinel that is silent by default and earns trust by being right when it speaks |
| 07 | `mission` | **Daily Mission** | *Have I done my thing today?* | One objective, one progress arc, one streak | Complication | One job a day, closed with a tap, tracked as a chain |
| 08 | `coach` | **Ask** | *Why do I feel tired?* | A single sentence that explains today | App screen | The wrist is where the "why" is asked, because that is where the feeling happens |
| 09 | `rings` | **Fourth Ring** | *Have I moved enough, and can I afford more?* | Apple's three rings plus a recovery ring | Complication | Do not fight Apple's mental model — extend it |
| 10 | `calm` | **Autonomic** | *Is my stress increasing?* | A continuous nervous-system state line | Notification + Smart Stack | Stress is the only health signal that is actionable within 60 seconds |

---

## Why these ten, specifically

Each occupies a distinct position on three axes:

**Axis 1 — What is the atom of information?**
A resource (01), a decision (02), a live measurement (03), a position (04), a moment in time (05),
an exception (06), a goal (07), an explanation (08), a set of goals (09), a continuous state (10).

**Axis 2 — Where does the value live?**
Complication-first (01, 07, 09) · App-first (02, 03, 08) · Widget-first (04, 05) ·
Notification-first (06, 10).

**Axis 3 — What drives the next open?**
Continuous change (01, 03, 10) · A decision the user must make (02, 04) · A time trigger (05) ·
Trust in a sentinel (06) · Completion pressure (07, 09) · Curiosity (08).

**Deliberate conflicts to expose in evaluation:**

- **02 vs 01** — does removing the number entirely make the app more useful (decision delivered) or
  less sticky (nothing to watch change)?
- **03 vs 06** — is constant live data a reason to open, or noise that trains people to ignore?
- **07/09 vs 02** — does completion pressure drive healthy repeat opens, or the guilt spiral that
  Gentler Streak was explicitly built to escape?
- **05 vs everything** — is "the next 30 minutes" a more useful frame on a wrist than "today"?
- **09 vs all** — is competing with Apple's own Activity rings suicidal, or is extending them the
  only way to win a face slot?

---

## Non-negotiables every concept must honour

1. **Never say "open Laso on your iPhone."** Every concept must have something true and useful to
   show with the phone in another room. This forces native HealthKit on the wrist in all ten.
2. **Colour carries the verdict before the number does.**
3. **Under 5 seconds to a decision** on the entry screen. Anything slower belongs one level deeper.
4. **Every state-changing tap fires a haptic.**
5. **At least one complication family and at least one Smart Stack widget.** A watch app with no
   presence outside itself will not be opened.
6. **Maximum 4 lines of text per screen.**
7. **Honest data.** Nothing displayed that the split in `PROTOTYPE-SPEC.md` says the device cannot
   know.

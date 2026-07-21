# Laso ad concepts (winner first)

## 1. ASK THEM TOMORROW

**Idea:** What if the ad judged health advice the only honest way there is: by whether anyone comes back the next day to see if it worked? So the ad runs the same street twice, and the second morning is the whole point.

**Tagline:** Everyone gives advice. Laso gives proof. (End card: ASK THEM TOMORROW. They won't remember. Laso will.)

**Insight**

Advice is loud because it is free, and it is free because nobody is ever accountable for it. Not one person who has ever told you what to do with your body has come back the next morning to ask how you slept. That is why health noise never ends: every piece of advice is an open loop that nobody closes. The feeling this ad goes after is not reassurance, it is the relief of no longer having to referee. She stops trying to work out who is right, because she has an outcome. Note what the ad refuses to do: it never turns the crowd down. Apple's version silences the world, which is a lie, you cannot mute the internet. Here the crowd is exactly as loud in the last frame as the first. What changed is that it stopped being her job to sort it.

**Script**

FORMAT: 9:16 vertical primary, 42 seconds. Dry naturalistic sound, no music bed until 0:33. All on-screen text is post-production, never AI-rendered. The phone screen is never shown until the end card.

STRUCTURAL RULE THAT MAKES THE AD: Act 2 is Act 1's shot list, replayed. Same street, same strangers, same lines, same framing, same order. Only two things differ, she has slept, and one voice says a number that did not exist yesterday. The repetition is the argument. The audience gets it before any text explains it.

--- ACT 1: TUESDAY ---

0:00-0:02 HOOK, three slam cuts, no establishing shot.
CU man in gym gear, straight down the lens, mid-sentence: "You're not eating enough protein."
HARD CUT. CU woman with a green juice, straight to lens: "You're eating way too much protein."
HARD CUT. CU older man on a bench: "And cardio's eating your muscle."
Sound is dry and close, like they are standing inside your ear.

0:02-0:05 SNAP PULL-BACK. Reveal, they were all aimed at HER. She is walking a sidewalk on a normal Tuesday, coffee in hand, and every one of them is walking alongside, matching her pace, leaning in.
More voices join from off-frame: "Coffee before eight spikes your cortisol." "Sitting is destroying your hips." "You need eight hours." "Eight is outdated, it's cycles now." "Cold plunge." "Cold plunge blunts the adaptation."

0:05-0:11 The pile-up. Each line she hears prints on screen as small grey type where the speaker's mouth is, and none of it clears. Text stacks, overlaps, drifts across frame until the screen is a wall of advice and her face is genuinely hard to see under it. She stops walking. Audio is now a single flat wall, no individual word legible. She closes her eyes for one second.

0:11-0:14 THE BUZZ. One haptic, close and dry. Every voice drops to the far side of glass, muffled, not gone. The entire text wall wipes off in one frame. One line stands alone, centre, plain white:
"Your resting HR is 61 bpm, 4% above your 7-day average."
Beat. Then it replaces itself with one instruction:
"NEXT UP, TODAY. Lights out by ten."
That is all. It does not explain itself. It does not argue with anyone.

0:14-0:18 She starts walking again. She does not look at any of them. She does not win an argument. She just leaves. The crowd is still at full volume behind her, and as she exits frame the gym-gear man turns to a stranger walking the other way and starts again: "You're not eating enough protein." The loop does not need her.

0:18-0:23 NIGHT. Deliberately small and unglamorous. Kitchen, microwave clock reads 9:58. Her hand puts the phone face down on the counter. Lamp off. One shot, no triumph, no candles, no silk pyjamas. Cut to black for a full half second, the only silence in the film.

--- ACT 2: WEDNESDAY, SAME SHOT LIST ---

0:23-0:30 SAME STREET. Same framing, same three cuts, same order, same people, same words, only the light is cooler and she has a different jacket.
"You're not eating enough protein."
"You're eating way too much protein."
"And cardio's eating your muscle."
Nothing has moved for them. Small grey type, bottom of frame:
"Same street. Same advice."
Beat.
"Not one of them asked how she slept."

0:30-0:36 THE BUZZ, second time. Voices drop behind glass. One line, alone:
"Your recovery is +5 higher this morning."
CU on her face. Not a grin, not a montage smile. A very small private one, the look of somebody who has stopped needing a second opinion. She keeps walking. Crowd volume does not fall a single decibel. First and only music, one low sustained note under this shot.

0:36-0:40 END CARD, black.
"ASK THEM TOMORROW."
Beat.
"They won't remember. Laso will."

0:40-0:42 Two seconds of real screen recording, no motion graphics, just the actual Recovery ring with the +5 delta ticking in, then the Laso wordmark and App Store badge.

**How to produce with AI video**

EASY, these are exactly what Veo 3 class models are best at right now.
- The direct-to-lens talking heads. Four to six second single-character clips, one person, one sentence, static or slow push. Lip-sync on short declarative lines is the strongest current capability. Generate twelve, keep eight.
- Single subject walking a sidewalk, clean plate, no dialogue. Trivial.
- Night kitchen, hand places phone face down, lamp off. Single hand, single object, dark frame, very forgiving.
- The half second of black. Free.

MEDIUM, needs plates not one hero shot.
- The crowd walking in step with her. Do NOT prompt one shot containing eight consistent talking characters, it will melt. Shoot her walking clean, shoot each shouter separately in matched light and lens, and build the crowd in the cut and in sound design. The wall of voices does more work than the wall of bodies anyway.
- The pull-back reveal at 0:02. Either a single slow dolly-out on her alone with voices off-frame, or a match cut from CU to wide. Do not ask the model to invent the crowd during a camera move.

RISKY, and how each is neutralised.
- Hero character consistency across two days. Lock one reference image and one seed, keep hair and face identical, change only the jacket. Also favour CU of her face over matched wides, faces re-generate more reliably than full-body staging.
- The crowd repeating identically on day two. Do not regenerate it. Literally re-use the Act 1 clips, regraded cooler with a slightly different white balance and a touch more contrast. This is not a cheat, it is the idea, they have not changed. Act 2 costs almost nothing to produce, which is rare for a second-act payoff.
- Text. Never let the model render a single character of it. Everything, the advice pile-up, the two notification lines, the end card, is After Effects or CapCut over clean plates. This also satisfies the no-app-UI constraint by design, because the ad's entire mechanism is a buzz plus one line of type, not a screen.
- Continuity drift between generated clips of the same street. Embrace it, minor drift reads as "the next day" rather than as an error.

BUDGET NOTE: roughly eighteen generated clips, most under five seconds, one real screen recording, one afternoon of sound design. The advice lines can be written and cast to be recognisable archetypes without naming any brand, protocol, or real person.

**Why only Laso**

Swap in any competitor and Act 2 has nothing to put on screen, which kills the film. That is the test, and it is the whole design.

A tracker or a dashboard app can only ever make Act 1. It can show her the noise and hand her a chart. It cannot come back the next morning with a result, because it never told her to do one specific thing, so there is nothing to be right about. Generic wellness apps fail the test even harder, their advice is indistinguishable from the crowd's, they are another voice on the sidewalk.

Three things in the film are Laso's actual product, not ad language.
1. The single instruction. Home shows exactly one action for today, so the ad can show exactly one action for today. An app with a feed of tips cannot have this shot, its notification would be another wall of text and would join the crowd instead of cutting through it.
2. The number in the notification. "Your resting HR is 61 bpm, 4% above your 7-day average" is real Laso copy against her own baseline, not a population guideline. That is precisely what separates it from every shouter, they have opinions about bodies, it has a measurement of hers. Grepped and verified in Copy+Notifications.swift and Copy+Analysis.swift.
3. The second morning. "Your recovery is +5 higher this morning" is a shipped Home string, verified in Copy+Home.swift as copy_home_daily_result_up. The closed loop is the product and it is also the punchline, which is the rarest thing in advertising, the joke and the feature are the same object.

And the refusal to silence the crowd is a claim only Laso can honestly make. Nobody can quiet the world. What Laso does is make it irrelevant, and the ad says exactly that and nothing more.

---

## 2. The Hand on Your Chest

**Idea:** What if the ad was just one woman, alone, doing the thing everyone does at 1am and nobody ever mentions: putting a hand flat on her own chest to check if she is okay, and for the first time in her life something answers, and then proves it in the morning.

**Tagline:** You ask every night. Laso answers by morning.

**Insight**

The Apple ad is about noise. The real pain is the silence after it. Everyone on earth has an opinion about your body. Nobody ever tells you if you were right. You lie awake running the tape (the coffee at four, the second glass, the flight, "or maybe this is just what thirty-eight feels like"), you form a theory, you fall asleep, and you never once find out. You have been asking your body questions for years and never gotten a single answer back. That is the loneliest part of health and nobody says it out loud, because saying it out loud sounds like fear. So instead people do the small silent gesture: hand on chest in the dark, feeling their own heart, quietly asking "are you okay?" Every viewer has done this. None of them has ever seen it on screen. Laso is the only product in this category whose actual mechanic is an answer: one sentence at night, a number in the morning that says you were right. The film has to be about being answered, not about being told what to do.

**Script**

FORMAT: 9:16 vertical, 43 seconds. Primary camera is a locked overhead, straight down on the bed. Three setups total. No music until 0:31. The film is 50 percent sound design.

0:00 - 0:04 | BLACK. Sound only: a heartbeat. Close, wet, slightly too fast. Under it, room tone: fridge hum, one car passing far away. No music. Hold long enough that it gets uncomfortable.

0:04 - 0:09 | OVERHEAD, LOCKED. Straight down onto a bed in a dark bedroom. Streetlight bars from blinds across the duvet. A woman, late thirties, no makeup, plain grey t-shirt, on her back. Duvet at her waist. She is not sad-acting. She is just awake. She blinks. She swallows. Nothing happens. That is the shot.
NO TEXT.

0:09 - 0:14 | SAME OVERHEAD. Her hand comes out from under the duvet and settles flat on her chest. It stays there. Her fingers move very slightly, counting without meaning to. The heartbeat in the mix rises, because we are now hearing what she is feeling, not what the room sounds like.
TEXT ON SCREEN, small, plain, bottom third, low contrast: "You have been asking this question for years."

0:14 - 0:19 | CLOSE, PROFILE. Her face on the pillow, one third of it lit. Eyes open, looking at nothing. She is doing the arithmetic. We never say what it is. Her jaw sets. She exhales through her nose. That is the whole performance.
TEXT: "Nothing has ever answered."
Beat. Heartbeat alone for two full seconds. This is the bottom of the film.

0:19 - 0:24 | BACK TO OVERHEAD. The phone on the nightstand lights up. Cool light spills across the duvet and one side of her face. She does not grab it. She turns her head toward it. The screen is never shown, it is angled away, we only see its glow.
TEXT, styled distinctly (this is the only other voice in the film, and it is quiet): "HRV 41 ms, 22% below recent average. Take it easy and aim for an early night."

0:24 - 0:29 | SAME OVERHEAD. She reads it. A breath she did not know she was holding. Then the move the entire film is built on: she reaches over and turns the phone face down. And her hand comes off her chest, down onto the bed. Her eyes close. The heartbeat in the mix slows, four beats, five, settling. The glow goes out. Room goes dark.
NO TEXT. Do not put text on this beat.

0:29 - 0:31 | BLACK. Two seconds. One slow heartbeat. Let it land.

0:31 - 0:37 | SAME OVERHEAD FRAME, MORNING. Identical composition, grey-blue dawn warming. She is asleep on her side now, duvet kicked to one leg. The face-down phone buzzes once against wood. She surfaces, picks it up.
TEXT: "Your recovery is +5 higher this morning."
Her face: not triumph. A small, private, almost embarrassed smile. The specific look of being told you were right about something you never told anyone.
First music enters here. One sustained low note. Nothing more.

0:37 - 0:41 | WIDE, EYE LEVEL, THE ONLY THIRD SETUP. She sits on the edge of the bed, feet on the floor, back to us, morning light on the wall. She puts her hand flat on her chest one more time. Two seconds. It is not a check this time. It is a thank you. She stands and walks out of frame. Empty bed. Curtains moving.

0:41 - 0:45 | END CARD, BLACK.
Laso wordmark.
"You ask every night. Laso answers by morning."
Optional final 2 seconds: real screen recording, the score card ticking to +5, then cut to black on the last heartbeat.

**How to produce with AI video**

The concept was reverse engineered from what AI video is actually good at, which is a single human, barely moving, in low light, under a static camera.

EASY (high first-pass hit rate):
- Every overhead bed shot. A flat plane, no parallax, no camera move, no crowd, no hands manipulating small objects. This is the easiest possible prompt class.
- The black-frame beats at 0:00 and 0:29. Free, and they are load bearing.
- The empty bed at 0:41.
- Facial micro-performance in profile close-up. Current models do stillness and breath well. They fail at big emotion, and we are asking for none.

MEDIUM (generate 6 to 10 takes, pick one):
- The hand arriving on her chest. Have it enter from under the duvet at the bottom of the gesture rather than a full articulated reach. Fewer joints, fewer artifacts.
- The 0:24 phone flip. Keep it as a short push of the hand, not a pinch and rotate. If it never looks clean, cover the flip with the light going out and one frame of black.

RISKY, with the fix:
- Face consistency across night and morning. Do not text-to-video each shot. Generate one character still first, then run every shot as image-to-video from that same reference. Non-negotiable, the whole film dies if she is two different women.
- Exact frame match between the 0:24 night overhead and the 0:31 morning overhead. Fix: generate the night start-frame as a still, relight that same still to dawn in an image model, then image-to-video both. Same geometry, different light. Stabilize and crop-match in post to kill residual drift.
- Phone screen content. Solved structurally: the screen is never on camera. All we ever see is glow on skin and fabric. Every word in the film is post typography, so zero AI text rendering, which is the single most common way these ads look cheap.

AUDIO, all in post, do not use generated audio:
- The heartbeat must be a real contact-mic recording, not a stock kick. Tempo starts around 78 and settles to about 58 across 0:24 to 0:29. That deceleration is the emotional payload and it is a mixing decision, not a video one.
- Room tone: fridge, distant traffic, one radiator tick.
- One sustained note from 0:31 only, resolving on the end card.

ART DIRECTION GUARDRAIL: no fitness model, no styled bedroom, no silk. A messy nightstand, a half glass of water, a charger cable, a hair tie. Slightly imperfect skin. The realism is the entire currency, and generated video defaults hard toward glossy. Prompt against it explicitly every shot.

Eight clips, three to six seconds each, all inside standard single-generation limits.

**Why only Laso**

Swap any competitor in and the film collapses, because the film's structure is the product's mechanic.

1. The night beat is ONE sentence and then the product goes away. A ring, a band or a dashboard app cannot occupy that beat. Their honest version of 0:19 is a screen full of graphs, and a screen full of graphs at 1am is the problem the film just spent nineteen seconds establishing. Laso's "NEXT UP, exactly one action" is what makes a single line of type on screen truthful rather than an ad simplification.

2. The turn of the phone face down at 0:24 is the brand's whole posture. It says the product's ambition is to be used less. No engagement-driven health app can put that shot in its ad.

3. The second half only exists because Laso closes the loop. "Your recovery is +5 higher this morning" is the proof beat, and no other product in the category has one. Take that away and the film has nothing to be about after 0:29, which means the last twelve seconds are structurally unstealable.

4. Both on-screen lines are verbatim shipped app copy, verified in the repo (Common/Copy/Copy+Notifications.swift line 62, Common/Copy/Copy+Home.swift line 48). The ad is not describing the product, it is quoting it. Anyone who downloads after seeing this gets the exact sentence they saw, which is what turns a memorable film into retention.

5. Against the Apple reference specifically: Apple made noise the villain and reassurance the payoff. This makes silence the villain and evidence the payoff. That is a harder, truer, and more ownable position, and it is the only one Laso can actually deliver on.

---

## 3. 27 THINGS

**Idea:** What if a wellness influencer's perfect 27-step morning routine video kept recording after he thought he'd switched it off?

**Tagline:** One thing today. Proof tomorrow.

**Insight**

Health content has quietly replaced proof with effort. People now measure their health by how much they do: the plunge, the tape, the pills, the mask, the 5am. Nobody measures whether any of it moved anything. So the private feeling at 9pm is not laziness or guilt about skipping the gym — it is a much lonelier one: I am doing all of this and I have no idea if it is working. Everyone thinks that sentence. Nobody posts it. An ad that says it out loud, in a genre built entirely to hide it, is a gut-punch because it is a confession, not a claim. And the fix it implies is subtraction, which is the one thing no health brand ever offers. Every other ad in this category asks you to add: add a device, add a scan, add a supplement, add a dashboard. This one takes 26 things away and gives back the only thing missing — evidence, the next morning.

**Script**

FORMAT: Vertical 9:16. 43 seconds. One actor. One spoken line in the whole film.

0:00-0:03 — HOOK (influencer grammar, played completely straight)
Shot: Handheld phone framing. Bathroom, 4:58am. Man, early 30s, lit hard by a ring light, over-bright grin, whisper-shouting at the lens.
On screen: sticker caption slams in — "MY 27-STEP MORNING ROUTINE ☀️🧠"
Corner counter appears and stays for the whole film: "1 / 27"
Dialogue: (whispered, to camera) "Okay. Let's get into it."
Music: upbeat needle-drop, snappy, the exact track this genre uses.

0:03-0:13 — THE ROUTINE (snap cuts, ~1.2s each, whip pans, speed ramps)
- 3/27 — MOUTH TAPE: he peels it off, it stings, he grins through it.
- 7/27 — COLD PLUNGE: tight on face and shoulders in a plastic bin on a fire escape. Gasping. Forced thumbs-up to lens.
- 11/27 — SUPPLEMENTS: top-down on marble, fourteen pills in a row, hand enters frame and sweeps them up.
- 14/27 — GREEN JUICE: blender screaming, he drinks, grimaces, snaps back to a smile mid-swallow.
- 19/27 — RED LIGHT MASK: he sits motionless in red glow, hands on knees, like a hostage.
- 22/27 — GROUNDING: barefoot on a two-metre patch of city grass beside a parking meter, eyes closed, traffic behind him.
Captions keep sliding in with the same chirpy font. Counter keeps ticking.

0:13-0:20 — THE SAG (same grammar, joy draining out)
Music pitches down half a step. Cuts get longer. Time cut: it is now 9:40pm, same day.
Shot: dark bedroom, one lamp. Phone propped against a shoe. He is on the floor doing 26/27 — box breathing. Blue-light glasses. Counting on his fingers. His face is completely blank. The performance is gone but the camera is still on.
Counter hits "27 / 27". The caption font stops appearing.

0:20-0:24 — THE TURN
Shot: he leans forward, taps the phone to stop the recording, sits back against the bed frame. The framing does not change. It never stopped recording.
Long exhale. He stares at the wall. Then, flat, to nobody:
Dialogue: "I don't know if any of it's working."
Music: cuts dead on the word "working."

0:24-0:28 — THE CARD
Cut to black. Silence. Plain white type, no motion, one line at a time:
"27 things today."
(hold 1s)
"Zero proof."

0:28-0:34 — NEXT MORNING
Shot: no ring light. Real window light. Same bed, wide-ish, he is sitting on the edge of it, hair flat, phone loose in one hand. This frame is the film's anchor — remember it.
One soft buzz. We never see the screen. We watch his face read it. The words appear as clean type in the empty half of the frame:
"Your resting HR is 8% above your 7-day average."
(beat)
"One thing today: lights out by 10:30."
He reads it. Puts the phone face down. Sits there. That is the entire action.

0:34-0:40 — THE PROOF
Hard cut. IDENTICAL frame. Same bed, same window, same light, different t-shirt. One buzz. Type appears in the same empty half:
"Your recovery is +5 higher this morning."
He looks at it a second longer than he needs to. Then the first unperformed exhale in the whole film — barely a smile, mostly relief. Hold on his face 2 full seconds. One low sustained note under it, nothing triumphant.

0:40-0:43 — END
Cut to black. Laso mark. Type:
"One thing today. Proof tomorrow."
Optional final 2s: real screen recording of the Home screen NEXT UP · TODAY card, then App Store line.

**How to produce with AI video**

EASY (safe for Veo/Sora-class):
- Every shot is one person, indoors, handheld, short. Bathroom ring-light close-ups, red-light mask, blue-light glasses on a dark floor, sitting on a bed in window light. All bread-and-butter for current models.
- The two morning shots are the same generation prompt with a wardrobe word changed and the same seed/reference frame — the whole payoff is a match cut, which AI is actually good at because it is one static-ish framing repeated.
- All typography (step counter, chirpy stickers, the black cards, the two Laso lines) is done in After Effects. Zero AI risk, and it carries the entire narrative. This is why the film works without app UI.
- The music tape-stop at 0:20 is an edit, not a shot.

MEDIUM RISK (manageable):
- Face continuity across ~12 shots. Solve with one locked character reference image plus an identical prompt block per shot, and keep every clip under 1.5s in the montage so drift never has time to register. The genre's own whip-cut grammar hides it.
- The one line of dialogue. Lip-sync is the only sync-critical moment. Shoot it three ways: front-on, three-quarter with face partly shadowed, and from behind/over-shoulder. If sync looks rubbery, use the over-shoulder take and run the line as an in-room voice. It reads even more private that way — that is an upgrade, not a compromise.

RISKY — design around it, do not attempt:
- Full-body cold plunge water. Water plus body physics is where this class of model still turns to soup. Frame tight on face and shoulders, splash out of frame, 1.2s max.
- Counting individual pills with fingers. Small objects plus hands is the classic failure. Use a locked top-down of pills already laid out, hand enters once and sweeps. Do not ask for a count animation.
- Any legible phone screen. Never shown, by design. The hard constraint is the creative device: because we watch his face instead of a UI, the ad is about being told something rather than being shown a dashboard, which is exactly the product.

BUDGET NOTE: 14 AI clips, 4 typography cards, one licensed track. No location, no crew. If the two anchor morning shots are the only ones that must be perfect, spend the generation budget there.

**Why only Laso**

Two things in this film only Laso can pay off, and they are the two beats the whole thing is built on.

1. The number goes DOWN. 27 to 1. Every competitor's ad has to end by adding something to his life — a ring, a strap, a scan, a chart, another protocol. Their product is more information. Laso's product is one instruction. So the resolution of this ad, a man doing less and being told exactly what the less is, is unavailable to them. If you swap in Whoop, Oura, MyFitnessPal or Apple Health, the ending has to become a dashboard, and the moment you show a dashboard the confession at 0:20 goes unanswered — because a dashboard is just 27 things again, in a nicer font.

2. The match cut is the feature. Same bed, same window, same frame, one morning later, "+5 higher this morning." That is not a metaphor for the product, it is literally the Recovery score delta as shipped, and the diagnostic line before it ("resting HR 8% above your 7-day average") is literally the notification copy in Copy+Notifications.swift. No other app in the category promises next-morning evidence tied to one specific action taken yesterday. They tell you what happened. Laso tells you one thing to do, then shows you it worked.

The confession only lands as a gut-punch because there is an answer to it. "I don't know if any of it's working" is the exact hole the product fills, and the ad refuses to fill it with anything except proof.

---

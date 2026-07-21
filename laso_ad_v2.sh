#!/bin/bash
# Laso ad "ASK THEM TOMORROW" — 3 clips x 15s, anchor-locked, stitched to ~45s.
# Continuity: clip 2 starts on clip 1's LAST frame, clip 3 starts on clip 1's FIRST
# frame (same street and same people, one morning later).
# Needs: REPLICATE_API_TOKEN, jq, ffmpeg.
set -euo pipefail
OUT="${1:-./laso_ad}"; mkdir -p "$OUT"; cd "$OUT"

# ---------- anchor blocks, byte-identical in every clip ----------
ANCHOR='[PROTAGONIST ANCHOR]: Maya, a 28-year-old South Asian woman, medium warm olive skin, no makeup, faint under-eye shadows, dark wavy hair in a textured messy bun with loose wisps at her temples, slim build. Wardrobe, unchanged in every shot: oversized cobalt-blue cotton fleece crewneck sweatshirt, dark charcoal leggings, crimson-red canvas crossbody strap worn diagonally from left shoulder to right hip, plain white sneakers. Same face, same hair, same wardrobe in every frame.
[ENVIRONMENT ANCHOR]: New York SoHo cobblestone street, red brick brownstones, green cast-iron storefronts, parked cars, a metal coffee cart, wet asphalt reflecting skylight.
[PALETTE ANCHOR]: Muted urban charcoal, slate grey and aged red brick, held against Maya as the only high-saturation cobalt-blue and crimson in frame. No colour shift between shots.
[OPTICS ANCHOR]: 35mm spherical prime, f/2.8, 24fps, 180-degree shutter, subtle natural optical grain, handheld micro-shake, documentary realism, natural skin texture with visible pores, no beauty retouching.
[LIGHTING ANCHOR]: Flat overcast daylight locked at 5600K for every shot. No golden hour, no glamour lighting, no lens flare.
[HARD RULES]: Never render any text, caption, subtitle, logo, watermark, phone screen, smartwatch screen, app interface, dashboard or chart anywhere in frame. The crowd is never silenced and never fades out, it stays as loud and as busy in the last frame as in the first. No slow motion, no drone shot.'

NEG='on-screen text, captions, subtitles, watermark, logo, phone screen, smartwatch screen, app interface, dashboard, charts, slow motion, lens flare, drone shot, golden hour, glamour lighting, beauty retouching, plastic skin, teeth-showing smile to camera, crowd fading away, different face between shots, changing outfit, changing hairstyle, colour temperature shift'

# ---------- api ----------
req() { # req <json-input> <outfile>
  local url status out
  url=$(curl -s -X POST \
    -H "Authorization: Bearer $REPLICATE_API_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$1" \
    https://api.replicate.com/v1/models/pixverse/pixverse-v6/predictions \
    | tee "${2%.mp4}.json" | jq -r '.urls.get // empty')
  [ -n "$url" ] || { echo "request failed:"; cat "${2%.mp4}.json"; exit 1; }
  while :; do
    curl -s -H "Authorization: Bearer $REPLICATE_API_TOKEN" "$url" > "${2%.mp4}.json"
    status=$(jq -r '.status' "${2%.mp4}.json"); echo "$status" > "${2%.mp4}.status"
    case "$status" in
      succeeded) break ;;
      failed|canceled) echo; echo "$2 $status:"; jq -r '.error' "${2%.mp4}.json"; exit 1 ;;
      *) sleep 10 ;;
    esac
  done
  echo downloading > "${2%.mp4}.status"
  out=$(jq -r 'if (.output|type) == "array" then .output[0] else .output end' "${2%.mp4}.json")
  curl -sL "$out" -o "$2"
  echo done > "${2%.mp4}.status"
}

body() { # body <prompt> [start-image-data-uri]
  jq -n --arg p "$1" --arg n "$NEG" --arg img "${2:-}" '
    {input: {prompt:$p, negative_prompt:$n, quality:"1080p", duration:15,
             aspect_ratio:"9:16", generate_audio_switch:true, generate_multi_clip_switch:true}}
    | if $img != "" then .input.image = $img else . end'
}

progress() { # progress <label>... ; redraws one line until background jobs exit
  local start=$SECONDS labels=("$@") spin='|/-\' i=0
  tput civis 2>/dev/null || true
  while jobs -rp | grep -q .; do
    local mins=$(( (SECONDS-start)/60 )) secs=$(( (SECONDS-start)%60 )) line=""
    for l in "${labels[@]}"; do
      line+="$(printf '%s %-11s  ' "$l" "$(cat "$l.status" 2>/dev/null || echo starting)")"
    done
    printf '\r  %s %s  %02d:%02d elapsed   ' "${spin:i++%4:1}" "$line" "$mins" "$secs"
    sleep 1
  done
  tput cnorm 2>/dev/null || true; printf '\r%*s\r' 90 ''; wait
}

# ---------- clip prompts ----------
P1="$ANCHOR
SCENE 1, THE ONSET OF NOISE, 15 seconds.
Camera: hard cuts for the first three shots, then a backward tracking dolly at eye level matched to her walking speed, Maya locked dead centre.
00:00-00:04. Three hard cuts, strangers on the sidewalk talking straight down the lens, mid sentence, framed as tight close-ups. A MAN in his 30s in a green flannel, long brown hair. A WOMAN in her 40s in a brown blazer holding a green juice. An OLDER MAN sitting on a stoop.
00:04-00:10. Snap pull-back reveals all of them were aimed at Maya. She walks with a paper coffee cup in her right hand and they walk alongside, matching her pace, leaning toward her ear, mouths moving. More pedestrians peel off the sidewalk and join from both frame edges.
00:10-00:15. The crowd presses closer, six people now, all talking over each other. Maya looks straight ahead, jaw set, faintly overwhelmed. She stops walking and closes her eyes for one second. Slow push in to a medium close-up and hold on her face.
[VOICE DIRECTION] Conversational, fast, casual, never announcer-like. Natural vocal imperfections, quick audible inhalations, dynamic pitch. Overlapping by 00:10 into one flat wall where no single word is legible.
MAN IN FLANNEL, rushed, informal: \"You are not eating enough protein.\"
WOMAN IN BLAZER, cutting in mid-sentence, authoritative: \"You are eating way too much protein.\"
OLDER MAN, dry, amused: \"And cardio is eating your muscle.\"
[ACOUSTIC SPACE] Open exterior street, slight natural slap echo off brick, traffic, footsteps, one distant horn. No music."

P2="$ANCHOR
SCENE 2, SHE LEAVES, 15 seconds. Continues in the same second, same street, same crowd, identical framing and lighting as the shot it starts from.
00:00-00:04. Maya opens her eyes. A phone buzzes once in her hip pocket, the screen is never seen and she never takes it out. Her hand tightens on the coffee cup. She does not argue and does not look at anyone.
00:04-00:09. She simply starts walking and exits frame left. The camera stays behind on the crowd, and the man in the green flannel immediately turns to a different stranger walking the other way and starts the exact same sentence again. The loop does not need her.
00:09-00:15. Hard cut to night interior. A small plain kitchen lit by one warm lamp at 3200K, a microwave clock reading 9:58 pm. Maya's hand places the phone face down on the counter. She switches the lamp off. The frame falls to near darkness and holds.
[VOICE DIRECTION] Same casual overlapping street voices at the same volume as scene 1, no new lines from Maya, she never speaks in the film.
MAN IN FLANNEL, to a new stranger, identical delivery: \"You are not eating enough protein.\"
[ACOUSTIC SPACE] Full street noise until 00:09, then a hard drop into domestic quiet, fridge hum, one distant siren through glass. One dry haptic buzz at 00:02. No music."

P3="$ANCHOR
SCENE 3, THE NEXT MORNING, 15 seconds. The identical street, the identical strangers standing in the identical positions saying the identical words. Same framing, same lens, same 5600K overcast light, only very slightly cooler and cleaner. Maya wears the same cobalt-blue sweatshirt and crimson strap.
00:00-00:05. The same three strangers to lens again, same order, same lines, same energy. Nothing has moved for them.
00:05-00:10. Maya walks straight past all of them without breaking stride, not looking at any of them. The crowd is still at full volume around her, still talking at her, still overlapping.
00:10-00:15. Slow push in to a close-up of her face. A very small private closed-lip smile appears, the look of someone who has stopped needing a second opinion. Hold on her face for the last two seconds.
[VOICE DIRECTION] Identical delivery to scene 1, same three voices, same volume, no fade, no drop.
MAN IN FLANNEL: \"You are not eating enough protein.\"
WOMAN IN BLAZER: \"You are eating way too much protein.\"
OLDER MAN: \"And cardio is eating your muscle.\"
[ACOUSTIC SPACE] Same crowd wall at the same level throughout. At 00:11 one low sustained bass note enters underneath the voices. The crowd volume never drops."

# ---------- run ----------
echo "[1/3] clip 1  (clips 2 and 3 both start from its frames, so it runs alone)"
req "$(body "$P1")" clip1.mp4 & progress clip1

ffmpeg -y -v error -sseof -0.1 -i clip1.mp4 -frames:v 1 last1.jpg
ffmpeg -y -v error -i clip1.mp4 -frames:v 1 first1.jpg
LAST1="data:image/jpeg;base64,$(base64 -i last1.jpg | tr -d '\n')"
FIRST1="data:image/jpeg;base64,$(base64 -i first1.jpg | tr -d '\n')"

echo "[2/3] clips 2 and 3 in parallel"
req "$(body "$P2" "$LAST1")"  clip2.mp4 &
req "$(body "$P3" "$FIRST1")" clip3.mp4 &
progress clip2 clip3

echo "[3/3] stitching"
printf "file '%s'\n" clip1.mp4 clip2.mp4 clip3.mp4 > list.txt
# Stream copy is instant, but only works if all three clips share codec settings.
ffmpeg -y -v error -f concat -safe 0 -i list.txt -c copy laso_ad_full.mp4 \
  || ffmpeg -y -v error -f concat -safe 0 -i list.txt -c:v libx264 -crf 18 -c:a aac laso_ad_full.mp4
echo "done: $(pwd)/laso_ad_full.mp4"

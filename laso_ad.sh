#!/bin/bash
# Laso ad "ONE THING" — 3 quiet locked shots, 8s each, cut to 15s.
# insert: her phone, blank screen (the real Laso UI is composited in post)
# stop:   dressed to run, hand on the door, she reads it and stays in
# go:     same door next morning, she goes
# "go" seeds from "stop"'s first frame so the doorway matches exactly.
# Needs: REPLICATE_API_TOKEN, jq, ffmpeg.
set -euo pipefail
OUT="${1:-./laso_ad}"; mkdir -p "$OUT"; cd "$OUT"

# ---------- anchor, byte-identical in every clip ----------
# The phone screen is deliberately generated as a blank white rectangle: it is
# a clean tracking surface for the real Laso UI, which goes on in post.
# No numerals or slate headers anywhere, they make the model burn in lettering.
ANCHOR='Maya, a woman in her late twenties, South Asian, warm olive skin, minimal makeup, dark hair pulled back tight. Same in every shot: fitted cobalt-blue running jacket, black leggings, white running shoes, plain dark smartwatch on her left wrist with a matte black unlit face.
Home: a quiet modern apartment entryway, pale plaster walls, warm oak floor, one tall window off to the side. Uncluttered, expensive, calm, nobody else present.
Light: soft directional dawn light from the window, warm key and cool shadow, low contrast, still and calm.
Look: fifty millimetre lens, shallow depth of field, camera fixed on sticks, no camera movement, one continuous shot, fine grain, natural skin texture. Cobalt is the only saturated colour in frame.
Rules: no text, letters, numerals, signage or logos anywhere in frame. Her phone screen is a plain flat white rectangle, completely blank, nothing on it. She never speaks and nobody speaks.'

NEG='text, letters, numerals, captions, subtitles, watermark, logo, timestamp, app interface, icons, notification, garbled lettering, writing on screen, glowing screen glare, lit watch face, clutter, mess, crowd, other people, camera pan, camera tilt, camera zoom, dolly, handheld shake, drifting frame, reframing, warped hands, extra fingers, deformed face, morphing face, slow motion, lens flare, glamour lighting, plastic skin, beauty retouching, posed model smile, music, score, soundtrack, voiceover, narrator, dialogue, talking, singing, notification chime, phone ringtone'

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

# multi_clip stays off: each shot is one locked continuous take, and multi-clip
# would cut inside it and break the door match between "stop" and "go".
body() { # body <prompt> [start-image-data-uri]
  jq -n --arg p "$1" --arg n "$NEG" --arg img "${2:-}" '
    {input: {prompt:$p, negative_prompt:$n, quality:"1080p", duration:8,
             aspect_ratio:"9:16", generate_audio_switch:true,
             generate_multi_clip_switch:false}}
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

# ---------- shot prompts ----------
P_INSERT="$ANCHOR
Extreme close-up of her left hand holding a phone at chest height, the screen facing camera and filling most of the frame. The screen is a plain flat white rectangle, completely blank, nothing on it, evenly lit, no glare. Her thumb rests still against the edge of the phone. Everything behind the phone, the pale wall and the warm oak floor, falls completely out of focus. She holds the phone still and does not move it. Hold steady to the last frame.
audio: quiet room tone, one distant bird outside, no music, no voices."

P_STOP="$ANCHOR
Maya stands in the entryway in a medium-wide, side on to camera, dressed to run, keys in her right hand, her left hand already lifted to the door handle, the phone in her left hand with its screen a plain flat white blank rectangle.
She glances down at the phone. She stops. Her hand comes off the handle and drops to her side. She lowers her head a little and lets out one long breath, shoulders dropping.
Then she turns away from the door, sits down on the floor with her back against the wall, and slowly pulls one shoelace loose. She looks at nothing in particular, calm, not disappointed, a little relieved.
audio: quiet room tone, the faint click of keys, one soft breath, no music, no voices."

P_GO="$ANCHOR
The same fixed camera, the same entryway, the same dawn light, Maya standing in the same place by the same door in the same cobalt running jacket.
She glances down at the phone in her left hand, its screen a plain flat white blank rectangle. This time she does not stop. She pushes the handle down and pulls the door open, and a wide bar of bright morning light falls across the oak floor and across her.
She steps out through the doorway and is gone. The empty entryway holds, the open door, the light on the floor, nobody in frame. Hold to the last frame.
audio: quiet room tone, the door handle, the door opening, faint street sound outside, no music, no voices."

# ---------- run ----------
echo "[1/2] laso_01_insert + laso_02_stop in parallel"
req "$(body "$P_INSERT")" laso_01_insert.mp4 &
req "$(body "$P_STOP")"   laso_02_stop.mp4 &
progress laso_01_insert laso_02_stop

# "go" must open on the identical doorway, so it starts from "stop"'s frame one.
ffmpeg -y -v error -i laso_02_stop.mp4 -frames:v 1 door.jpg
DOOR="data:image/jpeg;base64,$(base64 -i door.jpg | tr -d '\n')"

echo "[2/2] laso_03_go, seeded from the door frame"
req "$(body "$P_GO" "$DOOR")" laso_03_go.mp4 & progress laso_03_go

# Rough preview stitch. NOT the final cut (that is an editor job with the screen
# comps, see LASO_AD_POST.md). Pixverse clips drift in fps, SAR and timebase, so
# `-c copy` concat desyncs video from audio; we normalise each clip and re-encode
# through the concat filter instead, which is the only stitch that holds.
echo "[stitch] laso_preview.mp4"
ffmpeg -y -v error \
  -i laso_01_insert.mp4 -i laso_02_stop.mp4 -i laso_03_go.mp4 \
  -filter_complex "[0:v]scale=1080:1920,setsar=1,fps=24[v0];[1:v]scale=1080:1920,setsar=1,fps=24[v1];[2:v]scale=1080:1920,setsar=1,fps=24[v2];[v0][0:a][v1][1:a][v2][2:a]concat=n=3:v=1:a=1[v][a]" \
  -map "[v]" -map "[a]" -c:v libx264 -crf 18 -pix_fmt yuv420p -c:a aac -movflags +faststart laso_preview.mp4

echo "done:"; ls -1 "$(pwd)"/laso_0*.mp4 "$(pwd)"/laso_preview.mp4
echo "next: see LASO_AD_POST.md for the 15 second cut and the screen comps"

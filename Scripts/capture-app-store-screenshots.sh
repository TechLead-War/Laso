#!/usr/bin/env bash
#
# capture-app-store-screenshots.sh
# Captures App Store screenshots in three marketing angles using a premium-showcase
# mock-data profile. Outputs to two places:
#
#   1. screenshots/<timestamp>/<angle>/<NN>_<screen>.png  (raw deliverable)
#   2. admin-panel/public/screenshots/<timestamp>/...     (so the admin dashboard
#      can list and display every past run with thumbnails + mock-data values)
#
# Also (re)writes admin-panel/public/screenshots/index.json so the dashboard
# screenshots page can render every dated run in chronological order.
#
# Usage:
#   ./Scripts/capture-app-store-screenshots.sh [options]
#
# Options (admin-dashboard customisation; all are optional):
#   --shots=csv         Comma-separated list of "<angle>/<filename>" entries to
#                       capture instead of the full 15. e.g.
#                       --shots=01_thriving/01_home,03_clinical/02_strain
#   --folder-suffix=s   Appended to the timestamp folder name (alphanumeric +
#                       dashes only). e.g. --folder-suffix=preview
#   --override-name="N" Profile display name. Default "Alex Taylor".
#   --override-overall-score=N    Force the home hero score (0-100).
#   --override-sleep-score=N      Force the Sleep category score (0-100).
#   --override-activity-score=N   Force the Activity category score (0-100).
#
set -euo pipefail

# ────────────────────────────────────────────────────────────────────────────
# Configuration
# ────────────────────────────────────────────────────────────────────────────
SIM_NAME="iPhone 17 Pro Max"
APP_BUNDLE_ID="com.lasohealth.fit"
APP_NAME="Laso"
SCHEME="Laso"
DERIVED_DATA="/tmp/laso-screenshots-build"
SHOT_SLEEP=8       # seconds to wait after each launch before capturing
COLD_BOOT_SLEEP=4  # extra wait after first install + boot

# ────────────────────────────────────────────────────────────────────────────
# Argument parsing
# ────────────────────────────────────────────────────────────────────────────
SHOT_FILTER=""
FOLDER_SUFFIX=""
OVERRIDE_NAME=""
OVERRIDE_OVERALL=""
OVERRIDE_SLEEP=""
OVERRIDE_ACTIVITY=""

for arg in "$@"; do
  case "$arg" in
    --shots=*)                  SHOT_FILTER="${arg#--shots=}";;
    --folder-suffix=*)          FOLDER_SUFFIX="${arg#--folder-suffix=}";;
    --override-name=*)          OVERRIDE_NAME="${arg#--override-name=}";;
    --override-overall-score=*) OVERRIDE_OVERALL="${arg#--override-overall-score=}";;
    --override-sleep-score=*)   OVERRIDE_SLEEP="${arg#--override-sleep-score=}";;
    --override-activity-score=*) OVERRIDE_ACTIVITY="${arg#--override-activity-score=}";;
    --help|-h)
      sed -n '2,18p' "$0"
      exit 0
      ;;
    *)
      echo "✘ Unknown flag: $arg"
      echo "  Run with --help to see available flags."
      exit 2
      ;;
  esac
done

# Sanitize folder suffix to safe characters only
if [[ -n "$FOLDER_SUFFIX" ]]; then
  FOLDER_SUFFIX="$(echo "$FOLDER_SUFFIX" | tr -cd 'A-Za-z0-9-_')"
fi

# Build the per-shot iOS override flags once
IOS_OVERRIDES=()
[[ -n "$OVERRIDE_NAME"     ]] && IOS_OVERRIDES+=("--ui-test-override-name=$OVERRIDE_NAME")
[[ -n "$OVERRIDE_OVERALL"  ]] && IOS_OVERRIDES+=("--ui-test-override-overall-score=$OVERRIDE_OVERALL")
[[ -n "$OVERRIDE_SLEEP"    ]] && IOS_OVERRIDES+=("--ui-test-override-sleep-score=$OVERRIDE_SLEEP")
[[ -n "$OVERRIDE_ACTIVITY" ]] && IOS_OVERRIDES+=("--ui-test-override-activity-score=$OVERRIDE_ACTIVITY")

# ────────────────────────────────────────────────────────────────────────────
# Paths
# ────────────────────────────────────────────────────────────────────────────
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TS="$(date +"%Y-%m-%d_%H-%M-%S")"
[[ -n "$FOLDER_SUFFIX" ]] && TS="${TS}_${FOLDER_SUFFIX}"
RAW_OUT="$ROOT/screenshots/$TS"
ADMIN_ROOT="$ROOT/admin-panel/public/screenshots"
ADMIN_OUT="$ADMIN_ROOT/$TS"

mkdir -p "$RAW_OUT" "$ADMIN_OUT"
echo "▶ Run timestamp: $TS"
echo "▶ Raw output:    $RAW_OUT"
echo "▶ Admin mirror:  $ADMIN_OUT"
[[ -n "$SHOT_FILTER" ]] && echo "▶ Shot filter:   $SHOT_FILTER"
[[ ${#IOS_OVERRIDES[@]} -gt 0 ]] && echo "▶ Overrides:     ${IOS_OVERRIDES[*]}"

# ────────────────────────────────────────────────────────────────────────────
# Shot list. Format:  angle_folder | filename | --extra-flag-1 --extra-flag-2 ...
# Angles intentionally overlap on a few screens because each marketing angle
# tells a different story even when the surface is the same.
# ────────────────────────────────────────────────────────────────────────────
SHOTS=(
  # Angle 1: Wake up thriving (outcome / transformation)
  "01_thriving|01_home|--ui-test-initial-tab=home"
  "01_thriving|02_sleep|--ui-test-initial-tab=home --ui-test-initial-route=sleepCoach"
  "01_thriving|03_weekly|--ui-test-initial-tab=home --ui-test-initial-route=weeklyReview"
  "01_thriving|04_state|--ui-test-initial-tab=home --ui-test-initial-route=healthStateTimeline"
  "01_thriving|05_vitality|--ui-test-initial-tab=home --ui-test-initial-route=vitalityDetail"

  # Angle 2: Your sleep coach in your pocket (companion)
  "02_coach|01_home|--ui-test-initial-tab=home --ui-test-force-morning-checkin"
  "02_coach|02_action|--ui-test-initial-tab=home --ui-test-initial-route=todaysAction"
  "02_coach|03_sleep|--ui-test-initial-tab=home --ui-test-initial-route=sleepCoach"
  "02_coach|04_insights|--ui-test-initial-tab=home --ui-test-initial-route=insightsDetail"
  "02_coach|05_ask|--ui-test-initial-tab=home --ui-test-initial-route=askYourData"

  # Angle 3: Clinical clarity, beautifully simple (depth)
  "03_clinical|01_live|--ui-test-initial-tab=live"
  "03_clinical|02_strain|--ui-test-initial-tab=home --ui-test-initial-route=strainDetail"
  "03_clinical|03_stress|--ui-test-initial-tab=home --ui-test-initial-route=stressMonitor"
  "03_clinical|04_brain|--ui-test-initial-tab=home --ui-test-initial-route=brainHealth"
  "03_clinical|05_correlations|--ui-test-initial-tab=home --ui-test-initial-route=correlationsDetail"
)

COMMON_FLAGS=(
  "--ui-test-mode"
  "--ui-test-premium-showcase"
  "--ui-test-subscribed"
)

# Apply --shots= filter to the shot list, preserving order. If the filter is
# empty all 15 shots run. A filter pointing at "<angle>/<filename>" matches the
# leading two pipe-separated fields of each SHOTS entry.
if [[ -n "$SHOT_FILTER" ]]; then
  IFS=',' read -r -a WANTED <<< "$SHOT_FILTER"
  FILTERED=()
  for shot in "${SHOTS[@]}"; do
    IFS='|' read -r a f _ <<< "$shot"
    key="$a/$f"
    for w in "${WANTED[@]}"; do
      if [[ "$w" == "$key" ]]; then FILTERED+=("$shot"); break; fi
    done
  done
  if [[ ${#FILTERED[@]} -eq 0 ]]; then
    echo "✘ --shots filter '$SHOT_FILTER' matched none of the 15 known shots."
    echo "  Available: $(printf '%s\n' "${SHOTS[@]}" | awk -F'|' '{print $1"/"$2}' | paste -sd, -)"
    exit 2
  fi
  SHOTS=("${FILTERED[@]}")
  echo "✔ Capturing ${#SHOTS[@]} of 15 shots after filter"
fi

# ────────────────────────────────────────────────────────────────────────────
# Build
# ────────────────────────────────────────────────────────────────────────────
echo "▶ Building $SCHEME for $SIM_NAME ..."
cd "$ROOT"
xcodebuild \
  -project Laso.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=$SIM_NAME" \
  -derivedDataPath "$DERIVED_DATA" \
  build > /tmp/laso-build.log 2>&1 || {
    echo "✘ Build failed. Tail of /tmp/laso-build.log:"
    tail -40 /tmp/laso-build.log
    exit 1
  }

APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/$APP_NAME.app"
[[ -d "$APP_PATH" ]] || { echo "✘ App not at $APP_PATH"; exit 1; }
echo "✔ Build succeeded: $APP_PATH"

# ────────────────────────────────────────────────────────────────────────────
# Boot simulator
# ────────────────────────────────────────────────────────────────────────────
SIM_UDID="$(xcrun simctl list devices available | grep -F "$SIM_NAME (" | head -1 | grep -Eo '[A-F0-9-]{36}' || true)"
if [[ -z "$SIM_UDID" ]]; then
  echo "✘ No available simulator named '$SIM_NAME'. Open Xcode → Window → Devices to add one."
  exit 1
fi
echo "▶ Simulator: $SIM_NAME ($SIM_UDID)"

xcrun simctl boot "$SIM_UDID" 2>/dev/null || true
xcrun simctl bootstatus "$SIM_UDID" -b > /dev/null

# Status-bar override: 9:41 / full battery / full signal — App Store standard
xcrun simctl status_bar "$SIM_UDID" override \
  --time "9:41" \
  --batteryState charged \
  --batteryLevel 100 \
  --cellularBars 4 \
  --wifiBars 3 \
  --dataNetwork wifi \
  > /dev/null 2>&1 || true

# Force dark appearance to match preferredColorScheme(.dark) in LasoApp
xcrun simctl ui "$SIM_UDID" appearance dark > /dev/null 2>&1 || true

# Reset app data so each run is clean
xcrun simctl uninstall "$SIM_UDID" "$APP_BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$SIM_UDID" "$APP_PATH"
echo "✔ Installed app on simulator"
sleep "$COLD_BOOT_SLEEP"

# ────────────────────────────────────────────────────────────────────────────
# Capture loop
# ────────────────────────────────────────────────────────────────────────────
SHOT_COUNT=${#SHOTS[@]}
CAPTURED=()
i=0
for shot in "${SHOTS[@]}"; do
  i=$((i + 1))
  IFS='|' read -r angle filename extras <<< "$shot"

  mkdir -p "$RAW_OUT/$angle"
  mkdir -p "$ADMIN_OUT/$angle"

  xcrun simctl terminate "$SIM_UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
  sleep 1

  read -r -a EXTRA_ARR <<< "$extras"
  echo "▶ [$i/$SHOT_COUNT] $angle/$filename ← ${EXTRA_ARR[*]}"

  # `${arr[@]+"${arr[@]}"}` is the bash-portable way to expand an array's
  # elements when set, or nothing when empty — keeps `set -u` happy on the
  # nights where the user passes no overrides / no extras.
  xcrun simctl launch "$SIM_UDID" "$APP_BUNDLE_ID" \
    "${COMMON_FLAGS[@]}" \
    ${IOS_OVERRIDES[@]+"${IOS_OVERRIDES[@]}"} \
    ${EXTRA_ARR[@]+"${EXTRA_ARR[@]}"} > /dev/null

  sleep "$SHOT_SLEEP"

  RAW_FILE="$RAW_OUT/$angle/$filename.png"
  xcrun simctl io "$SIM_UDID" screenshot --type=png "$RAW_FILE" > /dev/null

  cp "$RAW_FILE" "$ADMIN_OUT/$angle/$filename.png"
  SIZE_KB=$(($(stat -f%z "$RAW_FILE") / 1024))
  echo "   ✔ $RAW_FILE  (${SIZE_KB} KB)"

  CAPTURED+=("$angle/$filename")
done

xcrun simctl terminate "$SIM_UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl status_bar "$SIM_UDID" clear >/dev/null 2>&1 || true
echo "✔ Captured $SHOT_COUNT shots"

# ────────────────────────────────────────────────────────────────────────────
# Per-run meta.json (mock-data values + angle descriptions)
# ────────────────────────────────────────────────────────────────────────────
META_FILE="$ADMIN_OUT/meta.json"
META_NAME="${OVERRIDE_NAME:-Alex Taylor}"
META_OVERALL="${OVERRIDE_OVERALL:-92}"
META_SLEEP="${OVERRIDE_SLEEP:-92}"
META_ACTIVITY="${OVERRIDE_ACTIVITY:-94}"

# meta.json is built dynamically from CAPTURED so the admin page never tries
# to render a broken thumbnail when --shots filters out part of the catalog.
python3 - "$META_FILE" "$RAW_OUT/meta.json" "$TS" "$SIM_NAME" "$META_NAME" "$META_OVERALL" "$META_SLEEP" "$META_ACTIVITY" "${CAPTURED[@]}" <<'PY'
import json, sys, os

(admin_meta, raw_meta, ts, sim, name, overall, sleep_s, activity_s, *captured) = sys.argv[1:]
captured_set = set(captured)

CATALOG = [
    {
        "id": "01_thriving",
        "title": "Wake up thriving",
        "description": "Outcome / transformation focus. Sells the result: recovery climbing, sleep debt clearing, weekly wins stacking up.",
        "shots": [
            {"id": "01_home",     "screen": "Home dashboard",        "caption": "Recovery 87 GREEN with daily narrative"},
            {"id": "02_sleep",    "screen": "Sleep Coach",           "caption": "Debt cleared, 14-day chart healthy"},
            {"id": "03_weekly",   "screen": "Weekly Review",         "caption": "Score delta + wins of the week"},
            {"id": "04_state",    "screen": "Health State Timeline", "caption": "Optimal days dominate the calendar"},
            {"id": "05_vitality", "screen": "Vitality",              "caption": "High score with trend climbing"},
        ],
    },
    {
        "id": "02_coach",
        "title": "Your sleep coach in your pocket",
        "description": "Companion focus. Sells the personal AI: morning greeting, today's plan, ranked insights, ask anything.",
        "shots": [
            {"id": "01_home",     "screen": "Home with morning check-in", "caption": "Coach greeting + today's plan"},
            {"id": "02_action",   "screen": "Today's Action detail",      "caption": "Single contextual action with reasoning"},
            {"id": "03_sleep",    "screen": "Sleep Coach",                "caption": "Personalized tips and bedtime anchor"},
            {"id": "04_insights", "screen": "Insights",                   "caption": "Ranked, actionable insight cards"},
            {"id": "05_ask",      "screen": "Ask Your Data",              "caption": "Natural-language query of your health"},
        ],
    },
    {
        "id": "03_clinical",
        "title": "Clinical clarity, beautifully simple",
        "description": "Depth focus. Sells the intelligence: real-time vitals, training load, stress drivers, brain health, correlations.",
        "shots": [
            {"id": "01_live",         "screen": "Live tab",       "caption": "HR, HRV, SpO2, zones streaming"},
            {"id": "02_strain",       "screen": "Strain detail",  "caption": "0 to 21 ring with HR zone breakdown"},
            {"id": "03_stress",       "screen": "Stress Monitor", "caption": "Arc gauge + drivers + weekly comparison"},
            {"id": "04_brain",        "screen": "Brain Health",   "caption": "Score, 7-day trend, readiness factors"},
            {"id": "05_correlations", "screen": "Correlations",   "caption": "Causal chains and compound insights"},
        ],
    },
]

angles_out = []
for group in CATALOG:
    shots = []
    for s in group["shots"]:
        key = f"{group['id']}/{s['id']}"
        if key in captured_set:
            shots.append({"file": f"{group['id']}/{s['id']}.png", "screen": s["screen"], "caption": s["caption"]})
    if shots:
        angles_out.append({
            "id": group["id"],
            "title": group["title"],
            "description": group["description"],
            "shots": shots,
        })

meta = {
    "timestamp": ts,
    "device": sim,
    "device_resolution": "1320x2868",
    "theme": "dark",
    "mock_profile": "PremiumShowcase",
    "values": {
        "name": name,
        "overall_score": int(overall),
        "sleep_score": int(sleep_s),
        "activity_score": int(activity_s),
        "recovery_green_score": 87,
        "hrv_ms": 62,
        "rhr_bpm": 54,
        "vo2_max": 50,
        "sleep_hours": 7.6,
        "sleep_streak_days": 12,
        "steps_average": 11800,
        "active_calories_kcal": 600,
        "exercise_minutes_daily": 52,
        "workout_streak_weeks": 8,
        "mindful_minutes_daily": 18,
        "subscribed": True,
    },
    "angles": angles_out,
}

for path in (admin_meta, raw_meta):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(meta, f, indent=2)

total_shots = sum(len(a["shots"]) for a in angles_out)
print(f"Wrote meta.json with {total_shots} shots across {len(angles_out)} angle(s)")
PY

# ────────────────────────────────────────────────────────────────────────────
# Rebuild admin-panel/public/screenshots/index.json across every dated run
# ────────────────────────────────────────────────────────────────────────────
python3 - "$ADMIN_ROOT" <<'PY'
import json, os, sys
from pathlib import Path

root = Path(sys.argv[1])
runs = []
for d in sorted([p for p in root.iterdir() if p.is_dir()], key=lambda p: p.name, reverse=True):
    meta_path = d / "meta.json"
    meta = None
    if meta_path.exists():
        try:
            with open(meta_path) as f:
                meta = json.load(f)
        except Exception:
            meta = None
    runs.append({"timestamp": d.name, "meta": meta})

with open(root / "index.json", "w") as f:
    json.dump({"runs": runs, "generated_at": __import__("datetime").datetime.utcnow().isoformat() + "Z"}, f, indent=2)
print(f"✔ Wrote {root / 'index.json'} with {len(runs)} runs")
PY

# ────────────────────────────────────────────────────────────────────────────
# Done
# ────────────────────────────────────────────────────────────────────────────
echo
echo "✔ All done."
echo "  Raw deliverable: $RAW_OUT"
echo "  Admin mirror:    $ADMIN_OUT"
echo
echo "Open the admin panel locally to view:"
echo "  cd admin-panel && npx firebase serve --only hosting"
echo "  → http://localhost:5000/#screenshots"

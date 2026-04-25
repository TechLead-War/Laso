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
WORKERS=1

for arg in "$@"; do
  case "$arg" in
    --shots=*)                  SHOT_FILTER="${arg#--shots=}";;
    --folder-suffix=*)          FOLDER_SUFFIX="${arg#--folder-suffix=}";;
    --override-name=*)          OVERRIDE_NAME="${arg#--override-name=}";;
    --override-overall-score=*) OVERRIDE_OVERALL="${arg#--override-overall-score=}";;
    --override-sleep-score=*)   OVERRIDE_SLEEP="${arg#--override-sleep-score=}";;
    --override-activity-score=*) OVERRIDE_ACTIVITY="${arg#--override-activity-score=}";;
    --workers=*)                WORKERS="${arg#--workers=}";;
    --help|-h)
      sed -n '2,22p' "$0"
      exit 0
      ;;
    *)
      echo "✘ Unknown flag: $arg"
      echo "  Run with --help to see available flags."
      exit 2
      ;;
  esac
done

# Sanitize WORKERS (numeric, 1-6)
if ! [[ "$WORKERS" =~ ^[0-9]+$ ]]; then WORKERS=1; fi
if (( WORKERS < 1 )); then WORKERS=1; fi
if (( WORKERS > 6 )); then WORKERS=6; fi

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
  # ─── 01 Onboarding (first thing a user sees) ───
  "01_onboarding|01_pulse|--ui-test-show-onboarding --ui-test-initial-tab=home"
  "01_onboarding|02_profile|--ui-test-show-onboarding --ui-test-onboarding-step=profile --ui-test-initial-tab=home"
  "01_onboarding|03_connect|--ui-test-show-onboarding --ui-test-onboarding-step=connect --ui-test-initial-tab=home"
  "01_onboarding|04_priorities|--ui-test-show-onboarding --ui-test-onboarding-step=priority --ui-test-initial-tab=home"
  "01_onboarding|05_mirror|--ui-test-show-onboarding --ui-test-onboarding-step=mirror --ui-test-initial-tab=home"
  "01_onboarding|06_promise|--ui-test-show-onboarding --ui-test-onboarding-step=promise --ui-test-initial-tab=home"

  # ─── 02 Today (Home + morning + Today's Action + Weekly Review + Health State) ───
  "02_today|01_home|--ui-test-initial-tab=home"
  "02_today|02_home_morning|--ui-test-initial-tab=home --ui-test-force-morning-checkin"
  "02_today|03_todays_action|--ui-test-initial-tab=home --ui-test-initial-route=todaysAction"
  "02_today|04_weekly_review|--ui-test-initial-tab=home --ui-test-initial-route=weeklyReview"
  "02_today|05_health_state|--ui-test-initial-tab=home --ui-test-initial-route=healthStateTimeline"

  # ─── 03 Sleep ───
  "03_sleep|01_sleep_coach|--ui-test-initial-tab=home --ui-test-initial-route=sleepCoach"

  # ─── 04 Activity & Strain (Live tab, Strain, Stress) ───
  "04_activity|01_live_tab|--ui-test-initial-tab=live"
  "04_activity|02_strain|--ui-test-initial-tab=home --ui-test-initial-route=strainDetail"
  "04_activity|03_stress|--ui-test-initial-tab=home --ui-test-initial-route=stressMonitor"

  # ─── 05 Recovery & Vitality (Vitality, Brain Health, Cycle) ───
  "05_recovery|01_vitality|--ui-test-initial-tab=home --ui-test-initial-route=vitalityDetail"
  "05_recovery|02_brain_health|--ui-test-initial-tab=home --ui-test-initial-route=brainHealth"
  "05_recovery|03_cycle|--ui-test-initial-tab=home --ui-test-initial-route=cycleDetail"

  # ─── 06 Insights & Intelligence (Insights, Correlations, Ask Your Data, Journal) ───
  "06_insights|01_insights|--ui-test-initial-tab=home --ui-test-initial-route=insightsDetail"
  "06_insights|02_correlations|--ui-test-initial-tab=home --ui-test-initial-route=correlationsDetail"
  "06_insights|03_ask_your_data|--ui-test-initial-tab=home --ui-test-initial-route=askYourData"
  "06_insights|04_journal|--ui-test-initial-tab=home --ui-test-initial-route=journalEntry"

  # ─── 07 Settings (root + sub-pages) ───
  "07_settings|01_root|--ui-test-initial-tab=settings"
  "07_settings|02_notifications|--ui-test-initial-tab=settings --ui-test-settings-route=notifications"
  "07_settings|03_devices|--ui-test-initial-tab=settings --ui-test-settings-route=devices"
  "07_settings|04_siri|--ui-test-initial-tab=settings --ui-test-settings-route=siri"

  # ─── 08 Edge cases & states (transient overlays, paywalls, empty states, engagement) ───
  "08_states|01_disclaimer|--ui-test-show-disclaimer --ui-test-initial-tab=home"
  "08_states|02_paywall|--ui-test-show-paywall --ui-test-initial-tab=home"
  "08_states|03_pro_lock|--ui-test-force-pro-lock --ui-test-initial-tab=live"
  "08_states|04_connect_health_empty|--ui-test-no-watch --ui-test-initial-tab=home"
  "08_states|05_achievements|--ui-test-initial-tab=home --ui-test-initial-route=achievements"
  "08_states|06_explore_tab|--ui-test-initial-tab=explore"
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
# Simulator pool — WORKERS=1 reuses the existing "iPhone 17 Pro Max"; WORKERS>1
# creates that many ephemeral clones we delete at the end (no machine-specific
# UDIDs, runs on any Mac with Xcode + an iOS runtime installed).
# ────────────────────────────────────────────────────────────────────────────

SIM_UDIDS=()
EPHEMERAL_SIMS=()

if (( WORKERS == 1 )); then
  base_udid="$(xcrun simctl list devices available | grep -F "$SIM_NAME (" | head -1 | grep -Eo '[A-F0-9-]{36}' || true)"
  if [[ -z "$base_udid" ]]; then
    echo "✘ No available simulator named '$SIM_NAME'. Open Xcode → Window → Devices to add one."
    exit 1
  fi
  SIM_UDIDS=("$base_udid")
  echo "▶ Simulator: $SIM_NAME ($base_udid)"
else
  # Both identifiers follow the same shape — extract the full reverse-DNS string
  # so simctl create accepts them as-is. iPhone 17 Pro Max exists as a hard
  # fallback (current default device); the runtime fallback is the latest iOS
  # runtime present on this machine.
  device_type="$(xcrun simctl list devicetypes | grep -Eo 'com\.apple\.CoreSimulator\.SimDeviceType\.iPhone-17-Pro-Max' | head -1)"
  [[ -z "$device_type" ]] && device_type="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max"
  runtime="$(xcrun simctl list runtimes available | grep -Eo 'com\.apple\.CoreSimulator\.SimRuntime\.iOS-[0-9-]+' | tail -1)"
  if [[ -z "$runtime" ]]; then
    echo "✘ No iOS runtime available — open Xcode → Settings → Platforms to install one."
    exit 1
  fi
  echo "▶ Creating $WORKERS ephemeral simulators (device=$device_type runtime=$runtime)"
  for i in $(seq 1 "$WORKERS"); do
    name="Laso-Capture-$$-$i"
    udid="$(xcrun simctl create "$name" "$device_type" "$runtime")"
    SIM_UDIDS+=("$udid")
    EPHEMERAL_SIMS+=("$udid")
  done
fi

# Boot every sim in the pool. `simctl boot` is async; `bootstatus` blocks.
for udid in "${SIM_UDIDS[@]}"; do
  xcrun simctl boot "$udid" 2>/dev/null || true
done
for udid in "${SIM_UDIDS[@]}"; do
  xcrun simctl bootstatus "$udid" -b > /dev/null
done

# Configure each sim: status bar (App Store standard), dark mode, fresh app install.
for udid in "${SIM_UDIDS[@]}"; do
  xcrun simctl status_bar "$udid" override \
    --time "9:41" \
    --batteryState charged \
    --batteryLevel 100 \
    --cellularBars 4 \
    --wifiBars 3 \
    --dataNetwork wifi \
    > /dev/null 2>&1 || true
  xcrun simctl ui "$udid" appearance dark > /dev/null 2>&1 || true
  xcrun simctl uninstall "$udid" "$APP_BUNDLE_ID" 2>/dev/null || true
  xcrun simctl install "$udid" "$APP_PATH"
done
echo "✔ Booted and installed app on $WORKERS simulator(s)"
sleep "$COLD_BOOT_SLEEP"

# ────────────────────────────────────────────────────────────────────────────
# Capture function (called sequentially per worker; multiple workers run in
# parallel from independent sims)
# ────────────────────────────────────────────────────────────────────────────

capture_shot() {
  local sim_udid="$1"
  local shot="$2"
  local angle filename extras
  IFS='|' read -r angle filename extras <<< "$shot"

  mkdir -p "$RAW_OUT/$angle" "$ADMIN_OUT/$angle"

  xcrun simctl terminate "$sim_udid" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
  sleep 1

  local extra_arr=()
  read -r -a extra_arr <<< "$extras"
  echo "▶ [$sim_udid] $angle/$filename"

  xcrun simctl launch "$sim_udid" "$APP_BUNDLE_ID" \
    "${COMMON_FLAGS[@]}" \
    ${IOS_OVERRIDES[@]+"${IOS_OVERRIDES[@]}"} \
    ${extra_arr[@]+"${extra_arr[@]}"} > /dev/null

  sleep "$SHOT_SLEEP"

  local raw_file="$RAW_OUT/$angle/$filename.png"
  xcrun simctl io "$sim_udid" screenshot --type=png "$raw_file" > /dev/null
  cp "$raw_file" "$ADMIN_OUT/$angle/$filename.png"
  local size_kb=$(($(stat -f%z "$raw_file") / 1024))
  echo "   ✔ $angle/$filename  (${size_kb} KB)"
}

process_queue() {
  local sim_udid="$1"
  local queue_file="$2"
  while IFS= read -r shot; do
    [[ -z "$shot" ]] && continue
    capture_shot "$sim_udid" "$shot"
  done < "$queue_file"
}

# ────────────────────────────────────────────────────────────────────────────
# Dispatch — sequential when WORKERS=1, round-robin parallel otherwise.
# ────────────────────────────────────────────────────────────────────────────

SHOT_COUNT=${#SHOTS[@]}
CAPTURED=()
WORK_DIR="$(mktemp -d -t laso-capture)"

if (( WORKERS == 1 )); then
  for shot in "${SHOTS[@]}"; do
    capture_shot "${SIM_UDIDS[0]}" "$shot"
    IFS='|' read -r _angle _filename _ <<< "$shot"
    CAPTURED+=("$_angle/$_filename")
  done
else
  for i in "${!SHOTS[@]}"; do
    worker_idx=$((i % WORKERS))
    echo "${SHOTS[$i]}" >> "$WORK_DIR/queue-$worker_idx"
  done

  echo "▶ Dispatching $SHOT_COUNT shots across $WORKERS workers in parallel..."
  PIDS=()
  for i in $(seq 0 $((WORKERS - 1))); do
    [[ -s "$WORK_DIR/queue-$i" ]] || continue
    process_queue "${SIM_UDIDS[$i]}" "$WORK_DIR/queue-$i" &
    PIDS+=("$!")
  done

  for pid in "${PIDS[@]}"; do
    wait "$pid" || true
  done

  # Rebuild CAPTURED in canonical SHOTS order so meta.json renders thumbnails
  # in the same sequence as the catalog.
  for shot in "${SHOTS[@]}"; do
    IFS='|' read -r _angle _filename _ <<< "$shot"
    if [[ -f "$RAW_OUT/$_angle/$_filename.png" ]]; then
      CAPTURED+=("$_angle/$_filename")
    fi
  done
fi

rm -rf "$WORK_DIR"

# Per-sim cleanup (terminate app + clear status bar; delete ephemeral clones).
for udid in "${SIM_UDIDS[@]}"; do
  xcrun simctl terminate "$udid" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl status_bar "$udid" clear >/dev/null 2>&1 || true
done
for udid in ${EPHEMERAL_SIMS[@]+"${EPHEMERAL_SIMS[@]}"}; do
  xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
  xcrun simctl delete "$udid" >/dev/null 2>&1 || true
done

echo "✔ Captured ${#CAPTURED[@]} of $SHOT_COUNT shots"

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
python3 - "$META_FILE" "$RAW_OUT/meta.json" "$TS" "$SIM_NAME" "$META_NAME" "$META_OVERALL" "$META_SLEEP" "$META_ACTIVITY" ${CAPTURED[@]+"${CAPTURED[@]}"} <<'PY'
import json, sys, os

(admin_meta, raw_meta, ts, sim, name, overall, sleep_s, activity_s, *captured) = sys.argv[1:]
captured_set = set(captured)

CATALOG = [
    {
        "id": "01_onboarding",
        "title": "Onboarding",
        "description": "Full 6-step first-launch flow — Pulse welcome, profile capture, Apple Health connect, priorities, mirror moment, 7-day promise.",
        "shots": [
            {"id": "01_pulse",      "screen": "Onboarding · Pulse",          "caption": "First-launch welcome with calibration story"},
            {"id": "02_profile",    "screen": "Onboarding · Profile",        "caption": "Age, gender capture step"},
            {"id": "03_connect",    "screen": "Onboarding · Connect Health", "caption": "Apple Health authorization step"},
            {"id": "04_priorities", "screen": "Onboarding · Priorities",     "caption": "Health focus area selection"},
            {"id": "05_mirror",     "screen": "Onboarding · Mirror Moment",  "caption": "Calibration discovery reveal"},
            {"id": "06_promise",    "screen": "Onboarding · 7-Day Promise",  "caption": "Final hand-off to the main app"},
        ],
    },
    {
        "id": "02_today",
        "title": "Today",
        "description": "The Home tab and its primary daily surfaces — recovery, morning check-in, today's action, weekly review, health state timeline.",
        "shots": [
            {"id": "01_home",          "screen": "Home dashboard",             "caption": "Recovery + daily narrative"},
            {"id": "02_home_morning",  "screen": "Home with morning check-in", "caption": "Coach greeting + today's plan"},
            {"id": "03_todays_action", "screen": "Today's Action detail",      "caption": "Single contextual action with reasoning"},
            {"id": "04_weekly_review", "screen": "Weekly Review",              "caption": "Score delta + wins of the week"},
            {"id": "05_health_state",  "screen": "Health State Timeline",      "caption": "Optimal days dominate the calendar"},
        ],
    },
    {
        "id": "03_sleep",
        "title": "Sleep",
        "description": "Sleep Coach detail — debt, history, tips, bedtime anchor.",
        "shots": [
            {"id": "01_sleep_coach", "screen": "Sleep Coach", "caption": "Debt cleared, 14-day chart healthy"},
        ],
    },
    {
        "id": "04_activity",
        "title": "Activity & Strain",
        "description": "Real-time and training-load surfaces — Live tab, strain, stress.",
        "shots": [
            {"id": "01_live_tab", "screen": "Live tab",       "caption": "HR, HRV, SpO2, zones streaming"},
            {"id": "02_strain",   "screen": "Strain detail",  "caption": "0 to 21 ring with HR zone breakdown"},
            {"id": "03_stress",   "screen": "Stress Monitor", "caption": "Arc gauge + drivers + weekly comparison"},
        ],
    },
    {
        "id": "05_recovery",
        "title": "Recovery & Vitality",
        "description": "Slow-moving vitals — biological age, brain readiness, cycle phase.",
        "shots": [
            {"id": "01_vitality",     "screen": "Vitality",     "caption": "High score with trend climbing"},
            {"id": "02_brain_health", "screen": "Brain Health", "caption": "Score, 7-day trend, readiness factors"},
            {"id": "03_cycle",        "screen": "Cycle Detail", "caption": "Phase tracking with hormonal context"},
        ],
    },
    {
        "id": "06_insights",
        "title": "Insights & Intelligence",
        "description": "Generated insight surfaces — ranked insights, correlations, ask-your-data, journal.",
        "shots": [
            {"id": "01_insights",      "screen": "Insights",      "caption": "Ranked, actionable insight cards"},
            {"id": "02_correlations",  "screen": "Correlations",  "caption": "Causal chains and compound insights"},
            {"id": "03_ask_your_data", "screen": "Ask Your Data", "caption": "Natural-language query of your health"},
            {"id": "04_journal",       "screen": "Journal Entry", "caption": "Reflective journaling prompt"},
        ],
    },
    {
        "id": "07_settings",
        "title": "Settings",
        "description": "Settings tab and its deep-link sub-pages — Notifications, Devices, Siri & Shortcuts.",
        "shots": [
            {"id": "01_root",          "screen": "Settings (root)",        "caption": "Profile, preferences, and data controls"},
            {"id": "02_notifications", "screen": "Notifications Settings", "caption": "Daily summary, alerts, watch reminders"},
            {"id": "03_devices",       "screen": "Connected Devices",      "caption": "Active sources, scanning, device status"},
            {"id": "04_siri",          "screen": "Siri & Shortcuts",       "caption": "Voice shortcut setup hints"},
        ],
    },
    {
        "id": "08_states",
        "title": "Edge cases & states",
        "description": "Transient overlays, paywalls, empty states, and breadth screens — disclaimer, paywall, Pro lock, connect-health empty, achievements, Explore tab.",
        "shots": [
            {"id": "01_disclaimer",            "screen": "Medical Disclaimer",           "caption": "Pre-acknowledgement legal sheet"},
            {"id": "02_paywall",               "screen": "Paywall",                      "caption": "Pro upgrade with trial messaging"},
            {"id": "03_pro_lock",              "screen": "Pro Feature Overlay (Live)",   "caption": "Free user hitting a Pro-only tab"},
            {"id": "04_connect_health_empty",  "screen": "Connect Apple Health (empty)", "caption": "Home empty state when no watch / no data"},
            {"id": "05_achievements",          "screen": "Achievements",                 "caption": "Streaks, milestones and unlocked tiers"},
            {"id": "06_explore_tab",           "screen": "Explore tab",                  "caption": "Trends, categories and historical depth"},
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

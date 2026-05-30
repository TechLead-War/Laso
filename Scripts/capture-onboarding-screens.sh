#!/usr/bin/env bash
#
# capture-onboarding-screens.sh
# Captures every screen of the new 16-screen onboarding flow (OnboardingV2View)
# into a single folder. Each screen is reached directly via the DEBUG launch
# flag `--ui-test-onboarding-v2-screen=<case>` so no tap-through (or system
# HealthKit sheet) is needed. The four data screens (scan/heart/sleep/hrv) are
# seeded with realistic mock values by OnboardingHealthSnapshot.applyUITestMockData().
#
# Output:
#   screenshots/onboarding-flow-<timestamp>/NN_<screen>.png
#
# Usage:
#   ./Scripts/capture-onboarding-screens.sh
#
set -euo pipefail

SIM_NAME="iPhone 17 Pro Max"
APP_BUNDLE_ID="com.lasohealth.fit"
APP_NAME="Laso"
SCHEME="Laso"
DERIVED_DATA="/tmp/laso-onboarding-shots-build"
SHOT_SLEEP=5       # seconds after each launch before capture (covers entry animations)
COLD_BOOT_SLEEP=4

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TS="$(date +"%Y-%m-%d_%H-%M-%S")"
OUT="$ROOT/screenshots/onboarding-flow-$TS"
mkdir -p "$OUT"

# Screen list: "<filename> | <OnboardingV2View.Screen rawValue>"
SHOTS=(
  "01_welcome|welcome"
  "02_promise|promise"
  "03_about|about"
  "04_goal|goal"
  "05_symptoms|symptoms"
  "06_activity|activity"
  "07_wearable|wearable"
  "08_bridge|bridge"
  "09_scan|scan"
  "10_heart|heart"
  "11_sleep|sleep"
  "12_hrv|hrv"
  "13_preview|preview"
  "14_signin|signIn"
  "15_paywall|paywall"
  "16_done|done"
)

COMMON_FLAGS=(
  "--ui-test-mode"
  "--ui-test-show-onboarding"
)

echo "▶ Output: $OUT"

# ── Build ───────────────────────────────────────────────────────────────────
echo "▶ Building $SCHEME for $SIM_NAME ..."
cd "$ROOT"
xcodebuild \
  -project Laso.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=$SIM_NAME" \
  -derivedDataPath "$DERIVED_DATA" \
  build > /tmp/laso-onboarding-build.log 2>&1 || {
    echo "✘ Build failed. Tail of /tmp/laso-onboarding-build.log:"
    tail -40 /tmp/laso-onboarding-build.log
    exit 1
  }

APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/$APP_NAME.app"
[[ -d "$APP_PATH" ]] || { echo "✘ App not at $APP_PATH"; exit 1; }
echo "✔ Build succeeded"

# ── Simulator ───────────────────────────────────────────────────────────────
UDID="$(xcrun simctl list devices available | grep -F "$SIM_NAME (" | head -1 | grep -Eo '[A-F0-9-]{36}' || true)"
[[ -n "$UDID" ]] || { echo "✘ No available simulator named '$SIM_NAME'."; exit 1; }
echo "▶ Simulator: $SIM_NAME ($UDID)"

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b > /dev/null

xcrun simctl status_bar "$UDID" override \
  --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3 --dataNetwork wifi > /dev/null 2>&1 || true
xcrun simctl ui "$UDID" appearance dark > /dev/null 2>&1 || true
xcrun simctl uninstall "$UDID" "$APP_BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP_PATH"
echo "✔ Installed"
sleep "$COLD_BOOT_SLEEP"

# ── Capture ─────────────────────────────────────────────────────────────────
COUNT=0
for shot in "${SHOTS[@]}"; do
  IFS='|' read -r filename screen <<< "$shot"
  xcrun simctl terminate "$UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
  sleep 1
  echo "▶ $filename  ($screen)"
  xcrun simctl launch "$UDID" "$APP_BUNDLE_ID" \
    "${COMMON_FLAGS[@]}" "--ui-test-onboarding-v2-screen=$screen" > /dev/null
  sleep "$SHOT_SLEEP"
  xcrun simctl io "$UDID" screenshot --type=png "$OUT/$filename.png" > /dev/null
  size_kb=$(($(stat -f%z "$OUT/$filename.png") / 1024))
  echo "   ✔ $filename.png  (${size_kb} KB)"
  COUNT=$((COUNT + 1))
done

xcrun simctl terminate "$UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl status_bar "$UDID" clear >/dev/null 2>&1 || true

echo
echo "✔ Captured $COUNT onboarding screens"
echo "  Folder: $OUT"

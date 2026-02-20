# HealthPulse

A SwiftUI app that reads Apple Watch and iPhone health data via HealthKit to provide personalized health scores, trend analysis, anomaly detection, and actionable insights.

---

## What You Need Before Starting

| Requirement | Why |
|---|---|
| **A Mac** | Xcode only runs on macOS |
| **Xcode 15 or newer** | Apple's IDE — the only way to build and install iOS apps |
| **An iPhone** running iOS 17+ | The app must run on a real device (HealthKit does not work in the Simulator) |
| **An Apple Watch** paired to that iPhone | This is where your health data comes from |
| **An Apple ID** | Required to sign the app so it can be installed on your phone. A free Apple ID works — no paid developer account needed |
| **A USB cable** (Lightning or USB-C) | To connect your iPhone to your Mac for the first build |

---

## Step-by-Step: Install Xcode

If you already have Xcode installed, skip to the next section.

1. Open the **App Store** on your Mac (click the Apple logo in the top-left > App Store).
2. Search for **Xcode**.
3. Click **Get / Install**. It's a large download (~7 GB) — this will take a while.
4. Once installed, **open Xcode** from your Applications folder or Launchpad.
5. Xcode will prompt you to install **additional components** — click **Install** and wait for it to finish.
6. You may be asked to agree to a license — click **Agree**.

> **Tip:** You can check your Xcode version by opening Xcode and going to **Xcode > About Xcode** in the menu bar.

---

## Step-by-Step: Open the Project

1. In Finder, navigate to this folder: `HealthPulse/`
2. **Double-click** the file called **`HealthPulse.xcodeproj`** — it has a blue blueprint icon.
3. Xcode will open and load the project. You'll see a file navigator on the left and the editor on the right.

> **First time opening Xcode?** It may ask you to sign in with your Apple ID — do it now (see next section).

---

## Step-by-Step: Set Up Code Signing

Code signing tells Apple "I built this app" so your iPhone will allow it to be installed. Here's how:

1. In Xcode, look at the **left sidebar** (the file navigator). Click on the **blue `HealthPulse` icon** at the very top of the file list — this is the project file.
2. In the center panel, you'll see a list of targets. Click on the **`HealthPulse`** target (it should already be selected).
3. Click the **Signing & Capabilities** tab at the top of the center panel.
4. Check the box that says **"Automatically manage signing"** (if it isn't already checked).
5. Next to **Team**, click the dropdown:
   - If your Apple ID is already listed, select it.
   - If not, click **"Add an Account..."**, sign in with your Apple ID, then select it from the dropdown.
6. If you see a red error about the **Bundle Identifier** being taken, change it to something unique:
   - Find the field labeled **Bundle Identifier** (it says `com.lasohealth.com`).
   - Change it to something like `com.YOURNAME.healthpulse` (replace `YOURNAME` with your name, no spaces).
7. The error should disappear. You should see a message like **"Signing Certificate: Apple Development: your@email.com"** with a green checkmark.

---

## Step-by-Step: Connect Your iPhone & Build

1. **Plug your iPhone** into your Mac using a USB cable.
2. If your iPhone asks **"Trust This Computer?"** — tap **Trust** and enter your passcode.
3. In Xcode, look at the **top toolbar** — you'll see something like `HealthPulse > iPhone 15 Pro`. Click the device name on the right side.
4. A dropdown appears listing simulators and devices. Under **"iOS Devices"**, select **your iPhone** (it will show your phone's name).
   > If your phone doesn't appear, make sure it's unlocked, plugged in, and you tapped "Trust".
5. Press **`Cmd + R`** (or click the **Play button** ▶ in the top-left).
6. Xcode will compile the code. This takes 1–2 minutes the first time.

### First-time build errors you may see

**"Could not launch HealthPulse — Untrusted Developer"**

This is normal the first time. On your **iPhone**:
1. Open **Settings**
2. Go to **General > VPN & Device Management** (on older iOS: **Profiles & Device Management**)
3. Under "Developer App", tap on your Apple ID email
4. Tap **"Trust [your email]"**
5. Tap **Trust** again to confirm
6. Go back to Xcode and press **`Cmd + R`** again

**"Device is busy: Preparing debugger"**

Wait 30–60 seconds and try again. This happens the first time Xcode connects to your phone.

**"Developer Mode is not enabled"**

On your **iPhone**: Go to **Settings > Privacy & Security > Developer Mode**, toggle it **on**, then restart your phone. Then try building again.

---

## Step-by-Step: Approve HealthKit Permissions

When HealthPulse launches on your iPhone for the first time:

1. A HealthKit authorization screen appears showing all the health data categories the app wants to read.
2. Tap **"Turn On All"** at the top to select everything.
3. Tap **"Allow"** in the top-right corner.

> **Important:** If you skip or deny permissions, the app won't have data to show. You can change this later in **Settings > Privacy & Security > Health > HealthPulse**.

The app will then fetch up to 90 days of health data from your Apple Watch and display your dashboard.

---

## What the App Does

HealthPulse analyzes 90 days of health data across four categories:

| Category | Metrics |
|---|---|
| **Activity** | Steps, active energy, exercise minutes, stand hours, VO2 max, workouts |
| **Heart** | Resting heart rate, heart rate, walking HR average, HRV, blood oxygen |
| **Sleep** | Total sleep, REM, deep, core, and awake stages |
| **Body** | Weight, body fat %, BMI |

The app generates:
- An **overall health score** (0–100) with per-category breakdowns
- **Trend analysis** — is each metric improving, stable, or declining?
- **Anomaly detection** — flags unusual readings (e.g. sudden spike in resting heart rate)
- **Actionable insights** — personalized recommendations based on your data
- **Exportable HTML reports** — shareable web pages with interactive Chart.js charts

---

## Project Architecture

```
HealthPulse/
├── App/                  # App entry point, ContentView, AppDelegate
├── Models/               # Data types (HealthMetric, HealthScore, Insight, etc.)
├── Data/                 # HealthKitManager, PersistenceManager, SampleDataProvider
├── Analysis/             # AnalysisEngine, scorers, trend/anomaly detectors
├── Notifications/        # Daily/weekly summaries, alert evaluator
├── ViewModels/           # Dashboard, CategoryDetail, MetricDetail, WebExport
├── Views/
│   ├── Components/       # Reusable UI (score rings, charts, badges, cards)
│   ├── Dashboard/        # Main dashboard screen
│   ├── Category/         # Category detail drill-down
│   ├── MetricDetail/     # Individual metric charts & stats
│   ├── Insights/         # Full insights list
│   └── Settings/         # Notification preferences
└── WebExport/            # HTML report generation with Chart.js
```

**Key concepts if you're new to Swift/SwiftUI:**
- **SwiftUI** is Apple's declarative UI framework. Views are defined as structs that describe what the UI should look like. The `body` property returns the view hierarchy.
- **`@Observable`** is a macro that makes a class's properties automatically update the UI when they change. The ViewModels use this.
- **`async/await`** is Swift's way of handling asynchronous work (like fetching health data). When you see `await`, it means "wait for this to finish without blocking the UI".
- **HealthKit** is Apple's framework for reading/writing health data. It requires explicit user permission and only works on real devices.

---

## Troubleshooting

### "HealthKit is not available on this device"
You're running on the iOS Simulator. HealthPulse **must** run on a real iPhone. Connect your phone via USB and select it as the build target (see build steps above).

### Signing errors / "No signing certificate"
1. Make sure you selected a Team in Signing & Capabilities.
2. Make sure "Automatically manage signing" is checked.
3. Try changing the Bundle Identifier to something unique.
4. If none of that works: go to **Xcode > Settings > Accounts**, remove your Apple ID, re-add it, and try again.

### No data showing up / empty dashboard
- Make sure your **Apple Watch** is paired and has been syncing health data to your iPhone.
- HealthPulse reads the last **90 days**. If you just set up your Watch, there may not be much data yet.
- Open the **Health** app on your iPhone and verify data is there (e.g. check Steps under Browse > Activity).

### HealthKit permission denied
Go to **Settings > Privacy & Security > Health > HealthPulse** on your iPhone. Toggle on all the data categories.

### App expires after 7 days (free Apple ID)
With a free Apple ID (no paid Developer Program), apps you install expire after 7 days. To fix:
- Just open the project in Xcode again and press **`Cmd + R`** to reinstall.
- Or enroll in the [Apple Developer Program](https://developer.apple.com/programs/) ($99/year) for apps that don't expire.

### Build fails with "No such module 'HealthKit'"
Make sure the build target is your **real iPhone**, not a simulator. Select your phone from the device dropdown in the Xcode toolbar.

### Xcode says "Failed to prepare device for development"
1. Make sure your iPhone is updated to iOS 17 or newer.
2. Restart both your Mac and iPhone.
3. Try a different USB cable.
4. Try: Xcode menu bar > **Product > Clean Build Folder** (`Cmd + Shift + K`), then build again.

---

## Re-running After Code Changes

If you (or Claude) modify any Swift files:
1. Open `HealthPulse.xcodeproj` in Xcode (if not already open).
2. Connect your iPhone.
3. Press **`Cmd + R`** — Xcode will recompile only the changed files and reinstall.

## Regenerating the Xcode Project

If you add or remove files/folders from the project directory, you need to regenerate the `.xcodeproj` so Xcode knows about them:

```bash
cd /Users/primetrace/Desktop/RnD/HealthPulse
xcodegen generate
```

> `xcodegen` is already installed via Homebrew. If you need to reinstall: `brew install xcodegen`

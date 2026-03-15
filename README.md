# Laso

iOS health app. Reads HealthKit, scores metrics, surfaces insights, tracks risks, streams live vitals.

**Bundle ID:** `com.lasohealth.com` | **iOS 17+** | **Swift 5.9** | **Firebase:** `laso-health-v1`

---

## Prerequisites

- Xcode 15+
- Node.js 18+
- `npm install -g firebase-tools`
- iPhone with Apple Watch (HealthKit needs a real device)
- Firebase Blaze plan (for Cloud Functions)

---

## iOS App Setup

### 1. Open project

```bash
open Laso.xcodeproj
```

### 2. Add Firebase SPM

1. File > Add Package Dependencies
2. URL: `https://github.com/firebase/firebase-ios-sdk`
3. Version: Up to Next Major, minimum `11.0.0`
4. Select: **FirebaseAnalytics**, **FirebaseFirestore**
5. Add to `Laso` target
6. `Cmd+B` to verify build

### 3. Add GoogleService-Info.plist

1. [Firebase Console](https://console.firebase.google.com) > `laso-health-v1` > Project Settings > iOS app
2. Download `GoogleService-Info.plist`
3. Drag into Xcode project root > check "Copy items if needed" + `Laso` target

This file is gitignored. Every dev adds it manually.

### 4. Code signing

1. Click `Laso` project in sidebar > `Laso` target > Signing & Capabilities
2. Check "Automatically manage signing"
3. Select your Team (add Apple ID if needed)
4. If bundle ID conflict: change to `com.yourname.laso`

### 5. Build and run

1. Plug in iPhone via USB, trust the computer
2. Select your iPhone in the device dropdown
3. `Cmd+R`

First-time: approve HealthKit permissions when prompted (Turn On All > Allow).

---

## Firebase Setup

### 6. Enable Firestore

1. Firebase Console > Firestore Database > Create database
2. Location: `us-central1`
3. Production mode

### 7. Enable Authentication

1. Firebase Console > Authentication > Sign-in method > Enable **Email/Password**
2. Users tab > Add user (your admin email + password)

### 8. Get service account key

1. Firebase Console > Project Settings > Service accounts
2. Generate new private key
3. Save as `admin-panel/functions/serviceAccount.json`

This file is gitignored. Never commit it.

### 9. Set admin claim

```bash
cd admin-panel/functions && npm install
node -e "
const admin = require('firebase-admin');
const { initializeApp, cert } = require('firebase-admin/app');
initializeApp({ credential: cert(require('./serviceAccount.json')) });
admin.auth().getUserByEmail('YOUR_ADMIN_EMAIL')
  .then(u => admin.auth().setCustomUserClaims(u.uid, { admin: true }))
  .then(() => { console.log('Done'); process.exit(0); })
  .catch(e => { console.error(e); process.exit(1); });
"
```

Replace `YOUR_ADMIN_EMAIL` with the email from step 7.

### 10. Deploy admin panel + functions + rules

```bash
cd admin-panel
firebase login
firebase deploy
```

Deploys three things (`firebase.json`):
- **Hosting** - admin web dashboard at the printed URL
- **Cloud Functions** - `getRemoteConfig` + `updateRemoteConfig`
- **Firestore rules** - feedback: public write, admin-only read

Open the hosting URL, log in with admin email.

---

## Analytics Setup

### 11. Register custom dimensions

Firebase Console > Analytics > Custom Definitions > Create:

**Dimensions** (Event scope):

| Name | Parameter |
|---|---|
| screen | screen |
| tab | tab |
| block_title | block_title |
| block_type | block_type |
| feature | feature |
| category | category |
| from_screen | from_screen |
| to_screen | to_screen |
| from_tab | from_tab |
| session_id | session_id |
| day_of_week | day_of_week |

**Metrics** (Event scope):

| Name | Parameter | Unit |
|---|---|---|
| duration_sec | duration_sec | Seconds |
| streak_days | streak_days | Standard |
| screens_visited | screens_visited | Standard |
| max_depth | max_depth | Standard |
| hour_of_day | hour_of_day | Standard |

### 12. Enable DebugView

1. Xcode > Product > Scheme > Edit Scheme > Run > Arguments
2. Add: `-FIRDebugEnabled`
3. Run app, navigate around
4. Firebase Console > Analytics > DebugView

Remove `-FIRDebugEnabled` before App Store submission.

---

## Events Reference

| Event | Params | Answers |
|---|---|---|
| `session_start` | `session_id`, `hour_of_day`, `day_of_week`, `streak_days` | DAU, sessions, time-of-use |
| `session_end` | `duration_sec`, `screens_visited`, `max_depth` | Session depth, duration |
| `streak_updated` | `streak_days`, `is_longest` | Daily streak |
| `tab_switched` | `tab`, `from_tab` | Tab usage |
| `screen_viewed` | `screen`, `tab`, `depth` | Feature usage, frequency, retention |
| `screen_exited` | `screen`, `tab`, `duration_sec` | Time per section |
| `block_tapped` | `block_title`, `block_type`, `screen`, `tab` | What users tap |
| `nav_transition` | `from_screen`, `to_screen` | User flow |
| `feature_used` | `feature`, `duration_sec` | Engagement (30s+) |
| `feature_stuck` | `feature`, `short_sessions_15m` | Struggle points |
| `feedback_submitted` | `category`, `text_length` | User feedback |

---

## Secrets (gitignored, never commit)

| File | Source |
|---|---|
| `GoogleService-Info.plist` | Firebase Console > Project Settings > iOS app |
| `admin-panel/functions/serviceAccount.json` | Firebase Console > Project Settings > Service accounts |


---

## Quality Gate

This project uses [QualityGate](../QualityGate/) — an external framework for smoke builds, visual regression testing, and pre-commit hooks.

### First-time setup (once per clone)

```bash
# Link QualityGate (if qg symlink is missing)
ln -s ../QualityGate/bin/qg ./qg

# Install git hooks
./qg install-hooks
```

### Commands

```bash
./qg smoke       # validate project builds on simulator
./qg capture     # run UI tests, save screenshots to visual-regression/current/
./qg compare     # compare current screenshots against baseline
./qg approve     # promote current screenshots as new baseline
./qg gate        # full pipeline: smoke + capture + compare
```

### First-time baseline

```bash
./qg capture     # capture initial screenshots
./qg approve     # promote as baseline
```

After this, `./qg gate` catches visual regressions before release.

### Configuration

Project settings are in `.qualitygate`. See `QualityGate/README.md` for full docs.

---

## Website Deployment

Website is an Astro site hosted on Cloudflare Pages. Domain: **lasohealth.fit**

```bash
# Dev server (hot reload)
cd website && npm run dev

# Deploy to production
cd website && npm run build && npx wrangler pages deploy dist --project-name=laso --branch=main --commit-dirty=true

# List deployments
npx wrangler pages deployment list --project-name=laso

# Rollback to a previous deployment
curl -X POST "https://api.cloudflare.com/client/v4/accounts/<ACCOUNT_ID>/pages/projects/laso/deployments/<DEPLOYMENT_ID>/rollback" \
  -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json"
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| No data / empty dashboard | Apple Watch must be paired and syncing. Check Health app on iPhone for data. |
| "Untrusted Developer" | iPhone > Settings > General > VPN & Device Management > Trust your Apple ID |
| "Developer Mode not enabled" | iPhone > Settings > Privacy & Security > Developer Mode > On > Restart |
| HealthKit permissions denied | iPhone > Settings > Privacy & Security > Health > Laso > enable all |
| App expires after 7 days | Free Apple ID limitation. Re-run `Cmd+R` from Xcode, or join Apple Developer Program ($99/yr). |
| Build fails "No such module" | Make sure target is your real iPhone, not simulator. |
| Admin panel login fails | Verify admin claim was set (step 9). User must exist in Authentication (step 7). |

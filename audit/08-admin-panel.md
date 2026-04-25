# 08 — Admin Panel Audit

**Scope:** `admin-panel/` — Firebase Hosting (single-page HTML/JS) + Cloud Functions (`functions/index.js`) + Firestore rules (`firestore.rules`) + local dev runner (`dev-runner/server.js`).
**Stance:** read-only review of code as committed; no deploy / no live HTTP probes.
**Auditor stance:** principal full-stack engineer + cloud security auditor, pre-launch.
**Format:** every finding follows Severity / Issue / Why this exists / Impact / Evidence / How to verify fast / Fix / Priority / Confidence.

Project: `laso-health-v1` (`admin-panel/.firebaserc:4`). Hosting: `laso-health-v1.web.app` + `lasohealth.com` / `.fit` (`admin-panel/functions/index.js:42-48`). Tracked admin-panel files: 13 (verified via `git ls-files admin-panel/`).

---

## Executive verdict

The admin panel is **markedly above the average Firebase admin dashboard** in security posture: custom-claim admin gating, in-memory rate limiting, server-side Firestore rules, audit logging on writes, session inactivity timeout, CSP / HSTS / X-Frame-Options headers via `vercel.json`, and a defense-in-depth pattern where every callable re-verifies admin status. The default-deny rule at the bottom of `firestore.rules` (line 119-121) is correct.

That said, there are **real, named risks** before launch. The two that matter most:

1. **Stored XSS in the feedback dashboard** (HIGH). `e.category` and `e.app_version` are concatenated into `innerHTML` without `escapeHtml`, and the `feedback` Firestore rule does not constrain those fields' shape. Any iOS user can submit feedback with a `category` containing `<img onerror=…>` and execute JavaScript inside an admin's authenticated session — same origin as Remote Config writes, the master kill switch, and force-update. This is the single highest-impact bug in the panel.
2. **CORS bypass: claims-checked but origin-unenforced** (MEDIUM). `setCorsHeaders` writes `Access-Control-Allow-Origin: *` (line 62) instead of using the `getCorsOrigin(req)` helper defined right above it (line 55-59). The whitelist is dead code. Combined with `cors: false` on `onRequest`, public endpoints are reachable from any origin in a browser. The two public endpoints (`getSignupCount`, `earlyAccessSignup`) carry no auth, so this is exploitable for cost / spam, not data theft.

Other notable but secondary issues: list-all-profiles is open to any authenticated app user (referral lookup loophole), `firebase-debug.log` was left on disk (not committed — verified), and the panel is missing every standard product KPI (DAU/WAU/MAU, retention curves, MRR, ARPU, churn, paywall conversion, crash-free %, push delivery rate). The panel today is an **operations console + Remote Config editor**, not a business dashboard.

---

## Cloud Functions inventory + auth verdict

| # | Export | Type | Auth gate | Rate limit | Audit logged | PII / cost risk | Verdict |
|---|--------|------|-----------|------------|--------------|------------------|---------|
| 1 | `getSignupCount` (`index.js:123`) | `onRequest` GET | None (public) | 10/min/IP | No | Returns count only, no PII. `Cache-Control: max-age=60`. | OK |
| 2 | `earlyAccessSignup` (`index.js:150`) | `onRequest` POST | None (public) | 10/min/IP | No | Strict regex email, 256 char cap, dedup, silent-success on duplicate (avoids enumeration). | OK |
| 3 | `getRemoteConfig` (`index.js:220`) | `onCall` | `verifyAdmin` (custom claim) | 30/min/admin | No (read) | Returns RC parameters — RC is non-secret app config. | OK |
| 4 | `updateRemoteConfig` (`index.js:240`) | `onCall` | `verifyAdmin` | 30/min/admin | YES (`update_remote_config`) | Validates value length ≤1000, key length ≤100. Persists `from`/`to` diff, which is the right audit shape. | OK |
| 5 | `getUserStats` (`index.js:298`) | `onCall` | `verifyAdmin` | 30/min/admin | No (read) | **Reads ENTIRE `user_profiles` collection on every call.** No pagination, no caching layer. At 100K users this is ~100K reads per dashboard load → cost + latency spike. | DEGRADES AT SCALE |
| 6 | `getFeedbackStats` (`index.js:339`) | `onCall` | `verifyAdmin` | 30/min/admin | No (read) | Uses Firestore aggregate `count()` (cheap), plus a 500-row sample. Sound. | OK |
| 7 | `getAuditLog` (`index.js:385`) | `onCall` | `verifyAdmin` | 30/min/admin | No (read) | Limit 100. Sound. | OK |

Every admin function calls `verifyAdmin(request)` first, and `verifyAdmin` (line 100-116) does three things in order: confirm `request.auth`, fetch the user from Firebase Admin SDK and check `customClaims.admin === true`, then enforce rate limit. The custom-claim gate is **stronger than `request.auth.token.admin`** because it re-fetches from Firebase Auth on every call — token cannot lie. Good.

No Firestore `onWrite` / `onCreate` triggers exist. Zero recursion / fan-out risk.

---

## Firestore rules excerpts + verdict

| Collection | Read | Write | Verdict |
|------------|------|-------|---------|
| `feedback/{docId}` (`firestore.rules:8-17`) | Admin custom claim only (`request.auth.token.admin == true`) | `create` if authed + has `category, text, timestamp` + text 1-2000 chars + `category is string`. No update / delete. | **Schema gap.** `category` and `app_version` are not length-bounded or charset-bounded. Combined with the unescaped admin render, this is the XSS path (Finding A1). |
| `early_access/{docId}` (`firestore.rules:22-30`) | Admin only | Public `create` with strict email regex + length cap. No update / delete. Email harvesting blocked. | Strong. Note: clients write directly via SDK rules, AND there is a Functions endpoint `earlyAccessSignup` that does extra UTM capture + dedup. Two write paths is duplicate-source-of-truth (Finding A11). |
| `user_profiles/{deviceId}` (`firestore.rules:37-86`) | `get` if `firebaseUid == auth.uid`. Admin `get, list`. **`list` open to ANY authed user** (line 83). | `create` only by self (firebaseUid + deviceId match). `update` only by self. Cross-user `update` allowed if it changes ONLY `referralFreeUntil` (number). No delete. | **List-all by any authed user (Finding A3).** Comments concede this is "a small risk" for referral lookup. In practice it leaks the entire user table — region, gender, age bracket, health focuses, app version, firebaseUid, device id — to any signed-in iOS user with a debugger. |
| `referrals/{docId}` (`firestore.rules:90-108`) | Any authed user | Authed create with required fields, authed update of only `status, completedAt`. No delete. | Acceptable. Update guard correct. |
| `admin_audit_log/{docId}` (`firestore.rules:113-116`) | Admin only | `write: if false` (only Admin SDK from Functions can write). | Strong. Tamper-evident. |
| `/{document=**}` (line 119-121) | deny | deny | Default-deny is in place. |

Rules version `2`. Custom claim `admin` is the single source of truth for read access. Good.

---

## KPI coverage table

The dashboard renders five stat tiles (`stat-total-users`, `stat-recent-feedback`, `stat-total-feedback`, `stat-config-keys`, `stat-active-kills`), one health-indicators panel, an active-config snapshot, recent feedback (5 items), and recent admin audit (5 items). That is the entire `Dashboard` page. The `Users` page renders bar charts of demographic distributions only. No revenue, retention, conversion, crash, or push KPI is rendered anywhere.

| KPI | Present? | Evidence / Notes |
|-----|----------|------------------|
| Total users | YES | `stat-total-users` ← `getUserStats.total` (`app.js:651-658`) |
| DAU (daily active) | NO | No active-user query; `user_profiles` has no `lastSeenAt` field stamped. |
| WAU (weekly active) | NO | Same. |
| MAU (monthly active) | NO | Same. |
| D1 / D7 / D30 retention | NO | No cohort table, no install-date analysis. |
| Churn rate | NO | No subscription state in panel. |
| MRR / ARR | NO | No StoreKit / RevenueCat mirror. Subscription state is iOS-side only. |
| ARPU | NO | Same. |
| LTV | NO | Same. |
| Trial-to-paid % | NO | Same. |
| Paywall conversion % | NO | Same — and `feature_access_*` `pro` tier is the gate, not measured. |
| NPS | NO | Feedback page has `category` + `text`, no NPS field collected. |
| App Store rating | NO | No App Store Connect bridge. |
| Crash-free user % | NO | No Crashlytics-Web embed; admin panel has zero error monitoring of itself either. |
| Push delivery rate | NO | No FCM / APNs analytics. |
| HealthKit auth grant rate | NO | Onboarding event not surfaced to admin. |
| Feedback total | YES | `getFeedbackStats.total` |
| Feedback last 7 days | YES | Same callable. |
| Active kill switches | YES | Computed client-side from RC flags (`app.js:676-707`). |
| Feature flag matrix | YES | `Feature Flags` page renders tier checkboxes per feature key. |
| Active Remote Config snapshot | YES | `Active Configuration` card (`app.js:732-755`). |
| Demographics (gender / age / region / health-focus / app-version) | YES | `Users` page, five bar charts. |
| Audit log | YES | Last 100 admin actions, with diff. |
| Captured screenshot runs | YES | `App Screenshots` page reads `screenshots/index.json`. |

**Verdict:** the panel covers ~5 of ~22 KPIs an ops/business team needs at launch — it is a config console, not a business dashboard (Finding A14).

---

## A1 — STORED XSS via feedback `category` / `app_version` rendered into innerHTML

**Severity:** HIGH (admin session takeover).
**Issue:** Admin renders `e.category` and `e.app_version` from feedback docs into `innerHTML` template strings without `escapeHtml`. Firestore rules permit any string for `category` (only "is string" is enforced) and do not constrain `app_version` at all. An iOS app user can therefore embed an XSS payload in their feedback submission that fires when an admin opens the dashboard or feedback page.
**Why this exists:** The `escapeHtml` helper exists (`app.js:337-341`) and **is** used for `e.text` (lines 789, 977) — but the dev forgot the metadata fields, probably because they "feel safe" (look like enums / version strings). The Firestore rule comment claims category is "string" but never bounds shape.
**Impact:** Admin browser executes attacker JS with:
- `firebase.auth().currentUser` → can call any callable function with admin custom claim, including `updateRemoteConfig` (free year toggle, force-update version, kill switches),
- `firebase.firestore()` → can read full `user_profiles`, `feedback`, `admin_audit_log` (admin reads allowed),
- LocalStorage / cookies for the Firebase auth domain (`laso-health-v1.firebaseapp.com`) — token exfiltration possible via the open `connect-src` in CSP (it includes `*.googleapis.com`, but the attacker can also exfiltrate via image tag to any `data:` URI which CSP's `img-src 'self' data:` permits).

This means a user submitting feedback in the iOS app can, in effect, **toggle the master kill switch, change minimum app version (force-update users to a non-existent version, locking everyone out), or change pricing product IDs** the next time an admin loads the dashboard.

**Evidence:**
- `admin-panel/public/app.js:783-790` — Dashboard recent feedback:
  ```js
  div.innerHTML = `
    <div class="dash-feedback-header">
      <span class="feedback-category-badge">${e.category || "?"}</span>
      <span class="feedback-date">${date}</span>
      ${e.app_version ? `<span class="feedback-version">v${e.app_version}</span>` : ""}
    </div>
    <div class="dash-feedback-text">${UI.escapeHtml(e.text || "")}</div>
  `;
  ```
- `admin-panel/public/app.js:969-980` — Feedback page list:
  ```js
  <span class="feedback-category-badge">${e.category || "?"}</span>
  <span class="feedback-date">${date}</span>
  ${e.days_since_install != null ? `<span class="feedback-days">Day ${e.days_since_install}</span>` : ""}
  ${e.app_version ? `<span class="feedback-version">v${e.app_version}</span>` : ""}
  ```
- `admin-panel/public/app.js:892-893` — category is also rendered raw into the filter `<option>` list:
  ```js
  categoryFilter.innerHTML = '<option value="">All Categories</option>' +
    categories.map((c) => `<option value="${c}">${c}</option>`).join("");
  ```
- `admin-panel/public/app.js:902-909` — summary pills render `cat` (a category) into innerHTML unescaped.
- `admin-panel/firestore.rules:9-14` — only constrains `text`, leaves `category` shape open beyond `is string`, and never mentions `app_version` or `days_since_install`.

**How to verify fast:** in Firestore console, add a `feedback` document with `category` = `<img src=x onerror="alert(1)">`, `text` = "test", `timestamp` = now. Reload admin dashboard. Alert fires.

**Fix (smallest correct change):**
1. Wrap every interpolation: `${UI.escapeHtml(String(e.category || "?"))}` and same for `app_version`, `days_since_install`, `cat`, `c`, `key` in chart bars (line 1123 already does this — pattern exists).
2. Tighten Firestore rule: `request.resource.data.category.size() < 50 && request.resource.data.category.matches('^[a-zA-Z0-9_-]+$')`. This is defense in depth.
3. Same hardening for `app_version` (`^[0-9]+(\\.[0-9]+){0,2}$`) and `days_since_install` (`is int`).

**Priority:** P0 — fix before launch. Single iOS user can brick admin actions or seize the entire Remote Config.
**Confidence:** 95/100 — code paths verified by reading; unconfirmed only that no Firestore-side post-write sanitizer Cloud Function strips HTML (none exists in `index.js`).

---

## A2 — CORS allow-list is dead code; `*` is sent on public endpoints

**Severity:** MEDIUM (cost / abuse, not data theft).
**Issue:** The dev built an `ALLOWED_ORIGINS` whitelist + `getCorsOrigin(req)` helper, then in `setCorsHeaders` (`index.js:61-66`) wrote `res.set("Access-Control-Allow-Origin", "*")` and never called the helper. Both public `onRequest` endpoints declare `cors: false` (lines 123, 150) so Firebase's built-in CORS does not apply either. Net effect: any browser on any origin can call `getSignupCount` and `earlyAccessSignup`.
**Why this exists:** Looks like work-in-progress — helper written, then `*` left in to "unblock the landing page" and the call to `getCorsOrigin` was never wired in.
**Impact:**
- Public POST `earlyAccessSignup`: spam attacker can script email signups from any browser. Rate limit is per-IP (10/min), but a residential proxy network defeats that. Firestore writes pile up + email may end up tied to the user's primary marketing list.
- Public GET `getSignupCount`: minimal — count is a single number.
- Internal callable functions (`onCall`) have separate CORS handling and are NOT affected (they use `httpsCallable` which Firebase wires correctly).

**Evidence:**
- `admin-panel/functions/index.js:55-66` —
  ```js
  function getCorsOrigin(req) {
    const origin = req.headers.origin || "";
    if (ALLOWED_ORIGINS.includes(origin)) return origin;
    return ALLOWED_ORIGINS[0]; // Default — won't match attacker origin
  }
  function setCorsHeaders(req, res) {
    res.set("Access-Control-Allow-Origin", "*");        // ← bug
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    res.set("Access-Control-Max-Age", "3600");
  }
  ```
- `getCorsOrigin` is defined but never referenced — confirmed by grep: only one occurrence in the file.

**How to verify fast:** `curl -i -H "Origin: https://attacker.test" https://us-central1-laso-health-v1.cloudfunctions.net/getSignupCount` → response carries `Access-Control-Allow-Origin: *`.

**Fix:**
```js
function setCorsHeaders(req, res) {
  res.set("Access-Control-Allow-Origin", getCorsOrigin(req));
  res.set("Vary", "Origin");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
  res.set("Access-Control-Max-Age", "3600");
}
```
Add `Vary: Origin` so caches do not poison.

**Priority:** P1 — fix before launch. Limits abuse blast radius on the only two unauthenticated endpoints.
**Confidence:** 99/100 — direct read of `index.js:62` shows the literal `*`.

---

## A3 — Any authenticated app user can `list` the entire `user_profiles` collection

**Severity:** MEDIUM-HIGH (PII enumeration).
**Issue:** Rule line 83 grants `allow list: if request.auth != null` to support referral-code lookup. The rule comment acknowledges this is a "small risk: any authenticated user can list profiles. Client code only ever queries by referralCode." Firestore rules **cannot enforce a client-side WHERE clause** — only schema and resource conditions. Therefore any authed iOS user can list every profile in batches of 1000.
**Why this exists:** Shortcut to ship referral lookup without standing up a Cloud Function (`lookupReferralCode(code) → ownerDeviceId`).
**Impact:** Profile fields at line 41-46 include `gender, ageBracket, healthFocuses, region, firebaseUid, deviceId, referralCode, referralFreeUntil, redeemedReferralCode, appVersion, createdAt, updatedAt`. That is enough to:
- Build a marketing list (size, demographics, regions, health focuses).
- Map `firebaseUid → deviceId` for every user — useful for targeted account abuse / referral fraud (claim rewards by writing your code into thousands of profiles? No — rule line 68-71 limits cross-user updates to `referralFreeUntil` only, that path is safe).
- Enumerate the user base size before launch (competitive intel). Currently `user_profiles` size is the same number shown on the landing page's signup count, but post-launch user count is sensitive.

**Evidence:** `admin-panel/firestore.rules:80-83`:
```js
// Lookup by referral code (list query). Firestore rules cannot perfectly
// enforce WHERE constraints, so we accept a small risk: any authenticated
// user can list profiles. Client code only ever queries by referralCode.
allow list: if request.auth != null;
```

**How to verify fast:** sign into the iOS app, in Xcode debugger run `Firestore.firestore().collection("user_profiles").getDocuments { snap, _ in print(snap?.documents.count as Any) }` — full collection returned.

**Fix:** Replace the rule with a referral-lookup callable Cloud Function that takes a code, runs a server-side query, and returns only `{ ownerFirebaseUid, ownerDeviceId }`. Then change the rule to `allow list: if false`. The callable can rate-limit the lookup like the others.

**Priority:** P1 — fix before launch. A leaked user list pre-launch is a marketing-day disaster.
**Confidence:** 95/100 — rule text and comment are explicit; Firestore behavior with permissive `list` is well documented.

---

## A4 — `firebase-debug.log` (397 KB) sitting on disk uncommitted but unignored

**Severity:** LOW (developer-machine artifact, not in production).
**Issue:** `git status` in the project root shows `?? admin-panel/firebase-debug.log` (untracked). It is **not** committed (verified with `git ls-files admin-panel/firebase-debug.log` → empty). It is also **not** in `.gitignore`. Risk is purely future: any teammate who runs `git add -A` will commit it.
**Content:** 696 lines of Firebase CLI debug output including:
- Developer Google email (`ayushkapri.richard@gmail.com`) — the engineer's identity.
- OAuth scope set, IAM permission probes for `laso-health-v1`.
- Project ID, project number, hosting site URL, web API key (already public via `firebaseConfig`), measurement ID (already public).
- Hosting access logs with client IPs (`::1` localhost only — fine).

The web API key, project ID, project number, and `appId` are intentionally public (they appear in `firebaseConfig` in `app.js:6-14` and shipping Google web app config is normal). The **engineer's email** is the only identity leak.

**Why this exists:** `firebase serve` writes `firebase-debug.log` to cwd by default. No one removed it.

**Evidence:**
- `git status` shows `?? admin-panel/firebase-debug.log`.
- `git check-ignore admin-panel/firebase-debug.log` returns nothing → not ignored.
- `head -50 admin-panel/firebase-debug.log` shows the email at line 12 and OAuth flow.
- Root `.gitignore` (lines 38-39) ignores `.env` and `.claude/` but not `firebase-debug.log`, `firebase-debug.*.log`, `firestore-debug.log`, or `ui-debug.log`.

**How to verify fast:** `cat .gitignore | grep -i debug` returns nothing.

**Fix:** add to `.gitignore`:
```
# Firebase CLI local logs
firebase-debug.log
firebase-debug.*.log
firestore-debug.log
firestore-debug.*.log
ui-debug.log
ui-debug.*.log
```
Then `rm admin-panel/firebase-debug.log`. Also recommend the developer `git config --global push.default current` and only commit explicit paths.

**Priority:** P3 — no production data leaked, but housekeeping before someone else commits it.
**Confidence:** 99/100 — verified directly.

---

## A5 — `admin-panel/public/screenshots/` is huge, untracked, uningnored, deployable

**Severity:** MEDIUM (data leak risk + deploy bloat).
**Issue:** `admin-panel/public/screenshots/` contains 18 dated capture run folders + a 14 MB zip + 35 KB `index.json` + a `.DS_Store`. Verified with `git ls-files admin-panel/public/screenshots/` → empty (NOT committed). However:
1. The folder is **not in any `.gitignore`** — first `git add -A` will commit hundreds of MB of PNGs.
2. `firebase.json` (`hosting.public: "public"` + `rewrites: ** → /index.html`) means anything in `public/screenshots/` **is served on `laso-health-v1.web.app/screenshots/...`** (the rewrite to `/index.html` only fires after the static-file 404, so existing PNGs serve directly). If someone runs `firebase deploy --only hosting`, every captured screenshot goes live publicly.
3. The screenshots are **mock/showcase data** (filenames suggest `01_pulse`, `02_profile`, profile name "Alex Taylor") — not real user PII per the `dev-runner` comments and `ScreenshotsPage` flow. Risk is reputational (premature marketing leak) more than privacy.

**Why this exists:** The screenshot generation pipeline writes outputs under `admin-panel/public/screenshots/<timestamp>/` so the admin dashboard can render thumbnails via the static host. The mirror location IS inside the deploy artifact.

**Evidence:**
- `git ls-files admin-panel/public/screenshots/ | wc -l` → 0.
- `ls -la admin-panel/public/screenshots/` shows 18 timestamped folders + `2026-04-25_14-01-30.zip` (14 MB) + `index.json`.
- `admin-panel/firebase.json:3-4` — `"public": "public"` deploys the entire folder.
- `app.js:1626` — fetches `screenshots/index.json` from the same hosting origin.

**How to verify fast:** `firebase hosting:channel:deploy preview --only hosting --project laso-health-v1` and visit the preview URL `/screenshots/index.json` — file is served.

**Fix (two parts):**
1. **Stop deploying screenshots:** add `firebase.json` `hosting.ignore` entry: `"public/screenshots/**"`. The dashboard works locally because Firebase Hosting emulator serves them; production should not.
2. **Stop accidental commits:** add `.gitignore` entry `admin-panel/public/screenshots/`.
3. The screenshots dashboard becomes "local-dev only," which matches `dev-runner` behavior anyway. Long-term: move the index + thumbnails to a separate Firebase Storage bucket with admin-claim-gated read.

**Priority:** P2 — fix before next `firebase deploy`. This is one accidental command from leaking the entire premium-showcase mock set.
**Confidence:** 90/100 — file-system listing verified, deploy behavior reasoned from `firebase.json` semantics; not run live.

---

## A6 — `getUserStats` reads the entire `user_profiles` collection on every call

**Severity:** MEDIUM (cost + latency at scale).
**Issue:** `index.js:301` does `admin.firestore().collection("user_profiles").get()` — full table scan, every dashboard load. Result is iterated in JS to compute five distribution maps (gender/age/region/focus/version).
**Why this exists:** Simplest possible aggregation. Firestore aggregation queries do not support GROUP BY, so a table scan is the obvious approach.
**Impact:**
- 1K users × 1 admin × 1 dashboard refresh / hour = 24K reads/day = $0.014/day. Trivial.
- 100K users × 5 admins × 5 refreshes/day = 2.5M reads/day = $1.50/day = $45/mo. Still trivial.
- 1M users × refresh = full collection scan exceeds the 60s callable timeout. Hard fail.
- The `Dashboard` page calls this on every page open (`app.js:653-658`), AND the `Users` page calls it again (`app.js:1061`). Two scans per session.

**Evidence:**
- `admin-panel/functions/index.js:298-334`:
  ```js
  exports.getUserStats = onCall({ invoker: "public" }, async (request) => {
    await verifyAdmin(request);
    const snapshot = await admin.firestore().collection("user_profiles").get();
    const total = snapshot.size;
    // ... iterates and counts
  });
  ```
- No memoization, no caching, no scheduled aggregation doc.

**How to verify fast:** Firebase console → Firestore usage → Reads / day after a single dashboard load = current `user_profiles` size.

**Fix (incremental):**
- Short-term: in-memory cache with 5-minute TTL on the single Cloud Functions instance (good enough for low traffic).
- Medium-term: scheduled function (Pub/Sub `every 1 hours`) writes the aggregates into a single doc `analytics/user_profile_summary`, dashboard reads that one doc.
- Long-term: BigQuery export of Firestore + dashboard pulls aggregates from BQ.

**Priority:** P2 — fix before passing 50K users.
**Confidence:** 96/100 — code path direct; cost numbers per Firestore pricing.

---

## A7 — Public `setCorsHeaders` warning surface: `'unsafe-inline' 'unsafe-eval'` in CSP

**Severity:** LOW-MEDIUM (mitigates A1's exfil paths but still permissive).
**Issue:** `vercel.json:12` declares `script-src 'self' 'unsafe-inline' 'unsafe-eval' …`. `'unsafe-inline'` is required because the dashboard ships an inline `<script>` tag for Firebase init in some builds and uses inline event handlers via template strings. `'unsafe-eval'` is required by older Firebase SDK builds (the legacy `compat` SDKs in `index.html:584-587`).
**Why this exists:** Default permissive CSP to make Firebase compat SDKs work without nonce/hash plumbing.
**Impact:** Combined with A1, an injected payload runs without CSP friction. Fixing A1 is the real mitigation; tightening CSP is defense in depth.
**Evidence:** `admin-panel/vercel.json:11-12`. `firebase.json` does not set CSP itself, so the `vercel.json` policy applies on Vercel only — the Firebase Hosting copy at `laso-health-v1.web.app` ships **with no CSP at all** (no `headers` block in `firebase.json`). Two hosting paths, two security postures.

**Fix:**
1. Add equivalent `headers` block to `firebase.json` so the Firebase Hosting copy also has CSP / HSTS / X-Frame-Options. Today only Vercel deploys are hardened — `laso-health-v1.web.app` is wide open.
2. Migrate to modular Firebase v10 SDK (`firebase/app`, `firebase/auth`, `firebase/firestore` ESM imports) and drop `'unsafe-eval'`.
3. Replace inline event handlers with `addEventListener` + drop `'unsafe-inline'` (large refactor).

**Priority:** P2 — at minimum mirror `vercel.json` headers into `firebase.json` so both hosts are equally hardened.
**Confidence:** 90/100 — `firebase.json` lack of headers is direct evidence; SDK eval requirement is reasoned from `compat` shipping pattern, not directly inspected.

---

## A8 — Frontend auth gate is correctly implemented

**Severity:** none — flagged because the brief asked.
**Issue:** Standard auth-gate pattern is in place. `index.html:11-22` defines `<div id="login-screen">`, `app.js:1230-1244` switches between login screen and `app-shell` based on `auth.onAuthStateChanged`. If the user is null, `app-shell` is hidden and `DashboardPage.reset()` is called.
**Caveat:** Hidden ≠ unloaded. Anyone who opens DevTools could set `display: flex` on `#app-shell` and see the **layout**, but every data call goes through Firebase callables that re-verify admin claim server-side. So static UI exposure is harmless; data is gated server-side. This is correct.
**Inactivity timeout:** 30 minutes (`app.js:1197`). Bound to `mousemove, mousedown, keydown, scroll, touchstart`. Sound.
**Evidence:** `app.js:1186-1247` — full Auth module reviewed. No `firebase.auth().onAuthStateChanged` bypass; no admin-only data fetched before login.
**Fix:** none required. Optionally add `if (!user.emailVerified)` to the gate.
**Priority:** N/A.
**Confidence:** 95/100 — code path read end-to-end.

---

## A9 — No frontend error monitoring (Sentry/Rollbar) on the admin panel

**Severity:** LOW-MEDIUM (operational blindness).
**Issue:** No Sentry, Rollbar, Crashlytics-Web, or similar embedded in `index.html` / `app.js`. If the panel breaks for the on-call ops team during an incident — for example, after a Firebase SDK upgrade — there is no telemetry. The team finds out by being told by Slack.
**Evidence:** `grep -n "sentry\|rollbar\|crashlytics\|bugsnag\|tracker\|errorReporter" admin-panel/public/*.{html,js}` → empty (verified by reading files end-to-end).
**Fix:** add Sentry browser SDK with a tiny DSN before `app.js`:
```html
<script src="https://browser.sentry-cdn.com/7.x/bundle.tracing.min.js"></script>
<script>Sentry.init({ dsn: "...", environment: "admin", sampleRate: 1.0 });</script>
```
Roughly 30 KB gzipped, zero ongoing maintenance. Mandatory before relying on the panel for kill-switch operations.
**Priority:** P2.
**Confidence:** 95/100.

---

## A10 — Admin role model is single-tier (one `admin` claim) — no super-admin / finance / support split

**Severity:** LOW (organizational, not technical).
**Issue:** `verifyAdmin` checks `customClaims.admin === true`. There is no concept of a finance-only admin (read-only revenue), customer-support admin (search users + view feedback, no kill switches), or super-admin (Remote Config + force-update). All admin claim holders can flip the master kill switch.
**Why this exists:** v1 simplicity.
**Impact:** As the team grows past one engineer, **every** new admin account gets full kill-switch power. Audit log captures who, but does not prevent.
**Evidence:** `admin-panel/functions/index.js:100-116`. Single boolean claim.
**Fix:** introduce `customClaims.role ∈ {"super","ops","finance","support"}` and a per-function role gate. Map `verifyAdmin(request, requiredRole)` and call `verifyAdmin(request, "super")` from `updateRemoteConfig`. Backwards compatible: treat existing `admin: true` as `role: "super"`.
**Priority:** P3 — fine for one-engineer launch, mandatory before second admin onboarded.
**Confidence:** 99/100.

---

## A11 — Two write paths for `early_access` (rules-based create + Cloud Function) — duplicate source of truth

**Severity:** LOW.
**Issue:** Firestore rule `early_access/{docId}` (line 22-30) allows public unauthenticated writes with strict email regex. Cloud Function `earlyAccessSignup` (line 150) also writes to the same collection with extra UTM/source/UA fields. Both paths are exposed publicly. Whichever path the landing page calls, the other still works.
**Why this exists:** Likely the rule was written first, then the Function was added to capture marketing attribution. The rule was not updated to disallow direct creates.
**Impact:**
- A direct-rule writer cannot include UTM data → marketing attribution gaps.
- An attacker with one extra field can bypass dedup logic in the Function.
- Schema drift: Function writes `source, medium, campaign, referrer, landing_page, ...` but rule only requires `email, timestamp` (line 23-27). Anything in between sneaks in.

**Evidence:**
- `admin-panel/firestore.rules:22-30` — public create allowed.
- `admin-panel/functions/index.js:150-213` — Function adds richer fields and dedup.

**Fix:** Tighten the rule to block direct client creates: `allow create: if false;` (only the Function can write, since Admin SDK bypasses rules). Keep the Function as the single ingress.
**Priority:** P2.
**Confidence:** 95/100.

---

## A12 — `earlyAccessSignup` does not normalize email before dedup query

**Severity:** LOW (data quality).
**Issue:** `index.js:175-178` queries `where("email", "==", email.toLowerCase().trim())` for dedup, then writes `email: sanitizeString(email.toLowerCase().trim(), 256)`. Both sides lowercase + trim — looks correct. **However** the rule path (A11) lets any client write any-case email directly. Mixed-case `Alex@Lasohealth.com` and `alex@lasohealth.com` both succeed. Future dedup queries miss them.
**Evidence:** `admin-panel/firestore.rules:23-27` does not lowercase. Only the Function does.
**Fix:** the same fix as A11 — close the rule path.
**Priority:** P3.
**Confidence:** 90/100.

---

## A13 — `dev-runner/server.js` exec scope is bound to repo root with a flag whitelist — sound but worth noting

**Severity:** LOW.
**Issue:** `dev-runner/server.js` listens on `127.0.0.1:5099` only (line 97), accepts only the regex `^--(shots|folder-suffix|override-name|override-overall-score|override-sleep-score|override-activity-score|workers)=.*` (line 20), spawns `./Scripts/capture-app-store-screenshots.sh` from the repo root. Any browser tab on the same Mac can call it via the `Generate` button (the button only renders if `location.hostname` is localhost — `app.js:1462-1467`).
**Cross-site risk:** A malicious page in another browser tab on the same machine can `fetch('http://127.0.0.1:5099/api/generate-screenshots', ...)` because CORS is `*` (line 25). The flag whitelist limits damage to the screenshot script — but `--override-name=<malicious shell metacharacters>` is forwarded raw via `spawn` with an argv array (no shell), so command injection is blocked structurally (Node `spawn` with an array does not invoke a shell).
**Why this exists:** Accepted local-dev backdoor; clearly scoped.
**Evidence:** `dev-runner/server.js:60-66, 96-101`.
**Fix:** None required. Optionally add a per-process token in the response to `/health` and require it in subsequent POSTs to defeat drive-by attacks from other browser tabs. Or bind to a Unix socket.
**Priority:** P3.
**Confidence:** 90/100.

---

## A14 — Dashboard is missing every business KPI required at launch

**Severity:** HIGH (business / ops blindness).
**Issue:** See KPI table above. The dashboard renders:
- Total users, total feedback, recent feedback, # config keys, # active kill switches.
- Demographics distribution (5 bar charts).
- Active config snapshot.
- Recent admin audit (5 entries).

That is the **entire** dashboard. There is no DAU/WAU/MAU, no retention curves, no MRR/ARR/ARPU/LTV, no churn, no paywall conversion, no trial-to-paid, no NPS, no App Store rating, no crash-free %, no push delivery rate, no HealthKit grant rate. After launch the on-call team will watch user totals tick up and flying blind on everything that actually matters.
**Why this exists:** v1 panel was scoped to "Remote Config console + feedback viewer." Business KPIs were deferred.
**Impact:**
- Cannot detect a paywall conversion drop within 24 hours.
- Cannot tell if D1 retention craters after a release.
- Cannot tell if push delivery is broken (bridges to A2 in `02-security.md` re: APS environment).
- Cannot tell crash-free user % without opening Crashlytics in another tab.

**Evidence:** `admin-panel/public/index.html:69-176` (dashboard markup), `admin-panel/public/app.js:617-848` (DashboardPage module). Whole-page review.
**Fix (priority order):**
1. Mirror RevenueCat / StoreKit subscription events into Firestore (`subscriptions/{firebaseUid}` doc with `tier, status, started_at, ends_at, trial`). Render MRR / ARPU / churn from there.
2. Add `lastSeenAt` write on every iOS app open to `user_profiles`. Aggregate DAU / WAU / MAU server-side once an hour.
3. Embed Firebase Crashlytics's web dashboard via iframe with admin-only auth, OR pull crash-free % via the FCM REST API and tile it.
4. Pull App Store ratings from the App Store Connect API (`appStoreVersions`/`customerReviews`) into Firestore.
5. Wire NPS field into the feedback schema.

**Priority:** P1 for the launch panel — pick MRR + DAU + crash-free % as the minimum-viable trio for go-live. The rest can ship in v1.1.
**Confidence:** 99/100 — pages reviewed end-to-end.

---

## A15 — No backup strategy is documented or scripted

**Severity:** MEDIUM (recovery blindness).
**Issue:** No `firebase firestore:export` schedule, no GCS bucket reference, no Cloud Scheduler job, no backup mention anywhere in `admin-panel/`. If the Firestore project is wiped (admin error, billing freeze, malicious actor), there is no recovery point.
**Why this exists:** Backups are off by default on Firestore.
**Impact:** RTO/RPO undefined. Single-account compromise loses all user data.
**Evidence:** No `gcloud firestore export` references anywhere in the repo (verified by absence in `firebase.json`, `index.js`, no `cloud-scheduler` references).
**Fix:** enable Firestore Managed Backups (in console: Firestore → Backups → enable), or write a `gcloud firestore export gs://laso-backups/$(date +%F)` invocation behind a Cloud Scheduler + Cloud Function.
**Priority:** P1 — set this before launch. One config error wipes the user table otherwise.
**Confidence:** 95/100 — looked end-to-end, no backup wiring.

---

## A16 — Functions runtime is Node 20 (current) — OK

**Severity:** none.
**Evidence:** `admin-panel/functions/package.json:5` — `"node": "20"`. Node 20 is current LTS as of audit date (2026-04-25). Firebase Functions v2 (`firebase-functions/v2/https`, line 1 of `index.js`) is in use. `firebase-admin ^12.0.0` and `firebase-functions ^5.0.0` are recent majors.
**Note:** No `engines.npm` pin. Acceptable.
**Confidence:** 99/100.

---

## A17 — Audit log captures `update_remote_config` only — no read-action audit

**Severity:** LOW-MEDIUM (GDPR / internal trust).
**Issue:** `logAdminAction` is only invoked in `updateRemoteConfig`. Admin reads (`getUserStats`, `getFeedbackStats`, viewing user demographics, viewing feedback text) are NOT logged. If an admin browses `feedback` and sees a user's complaint, there is no record. Same for the `Users` page demographic dump.
**Why this exists:** Logging every read at the function level is unwritten work.
**Impact:** GDPR Article 30 requires a record of processing activities. "Admin support agent read user X's feedback at 14:32" is the expected resolution. Absent this, internal misuse is invisible.
**Evidence:** `admin-panel/functions/index.js:83-96` (logAdminAction). Only called from `updateRemoteConfig` (line 284). Confirmed by reading every callable.
**Fix:** call `logAdminAction(uid, email, "view_user_stats")` etc. inside each admin read function. Keep payload minimal (just the action verb, no PII).
**Priority:** P2 — needed for GDPR ROPA before EU launch.
**Confidence:** 95/100.

---

## A18 — Functions logs may bleed user emails / IDs

**Severity:** LOW.
**Issue:** `index.js:142, 210, 94` use `console.error("getSignupCount error:", err)` and friends. If `err` is a `HttpsError` carrying user input (e.g., the email that failed validation), it ends up in Cloud Logging where retention defaults to 30 days. The current code does not log the email itself, but **future maintenance** could regress.
**Evidence:** All three console calls reviewed. Only error messages are logged today (e.g., `err.message`), not user-controlled fields. Currently safe.
**Fix:** add a `logger.ts` wrapper that strips known-PII keys, or move to `firebase-functions/logger` with structured logging.
**Priority:** P3.
**Confidence:** 80/100 — code today is safe, but the pattern is fragile; `err.message` from Firestore can include resource paths that contain user IDs in some cases.

---

## A19 — Mobile responsiveness untested

**Severity:** LOW.
**Issue:** `admin-panel/public/index.html:5` declares `viewport`, but the layout is grid-heavy (`stats-grid-5`, `dashboard-grid` two-column, `charts-row`). On a 375 px iPhone screen, the on-call ops engineer will struggle to flip a kill switch.
**Why this exists:** Desktop-first design.
**Evidence:** `style.css` (34 KB) was not opened end-to-end; classes named for desktop layouts dominate. Inferred from `index.html` markup.
**Fix:** add CSS media queries for `<768px`: stack columns, full-width stat cards, sticky save bar.
**Priority:** P3 — the dashboard is for desks today; flag for later.
**Confidence:** 60/100 — `style.css` not fully read; rating is structural.

---

## A20 — `index.html` carries `<title>Laso Admin</title>` and `<button id="login-btn">Sign In</button>` with NO `meta name="robots" content="noindex"` — admin login page is search-indexable

**Severity:** LOW (discoverability).
**Issue:** No `<meta name="robots" content="noindex,nofollow">` in `index.html`. Google could index `https://laso-health-v1.web.app/` as "Laso Admin — Sign in to manage your app." This is harmless data (login page only), but it telegraphs that an admin panel exists at this URL.
**Why this exists:** Default markup.
**Evidence:** `admin-panel/public/index.html:1-9` — no robots meta.
**Fix:** add `<meta name="robots" content="noindex,nofollow,noarchive">` in `<head>`. Optionally serve `/robots.txt` via Hosting that disallows `/`.
**Priority:** P3.
**Confidence:** 99/100.

---

## Cross-cutting observations

- **Two-host deployment, one CSP.** `vercel.json` has hardened headers; `firebase.json` does not. Whichever host is "production" should be the one carrying the headers — and both should be identical. Today they are not.
- **Defense-in-depth pattern is mostly solid.** Custom claim re-checked from Firebase Auth on every call (not just `auth.token`), in-memory rate limit, server-side audit log, server-side input validation, Firestore default-deny tail rule. Above industry baseline.
- **The Remote Config admin surface is, in effect, a god-mode console for the iOS app.** `kill_switch_enabled = "true"` makes the entire app go dark. `minimum_app_version = "999.0"` force-updates everyone to a non-existent version. `free_year_active = "false"` flips paywalls back on. The current weakest link to that god-mode is A1 (XSS via feedback) — fix that first.
- **No payment / subscription state visible in the panel at all.** This is the largest functional gap for "pre-launch admin readiness" beyond the security findings.
- **No Sentry / no front-end error monitoring** on the panel itself — see A9.
- **Backups are not configured** — see A15.

## Suggested fix order (1-week sprint before launch)

1. (P0) A1 — escape every `${e.field}` in `app.js` + tighten `feedback` rule.
2. (P1) A2 — wire `getCorsOrigin` into `setCorsHeaders`, add `Vary: Origin`.
3. (P1) A3 — close `allow list` on `user_profiles`; add a `lookupReferralCode` callable.
4. (P1) A14 — at minimum tile `MRR + DAU + crash-free %` on the dashboard.
5. (P1) A15 — turn on Firestore Managed Backups.
6. (P2) A5 — `firebase.json` ignore `public/screenshots/**` + `.gitignore` it.
7. (P2) A6 — cache `getUserStats` with 5-min TTL.
8. (P2) A7 — mirror `vercel.json` headers into `firebase.json`.
9. (P2) A11 / A12 — single-source `early_access` ingress through the Cloud Function.
10. (P2) A17 — add audit-log calls to admin reads.
11. (P3) Everything else.

## Files cited

- `admin-panel/firestore.rules` (123 lines)
- `admin-panel/firebase.json`
- `admin-panel/vercel.json`
- `admin-panel/.firebaserc`
- `admin-panel/functions/index.js` (407 lines)
- `admin-panel/functions/package.json`
- `admin-panel/public/index.html` (591 lines)
- `admin-panel/public/app.js` (1771 lines)
- `admin-panel/dev-runner/server.js` (101 lines)
- Root `.gitignore`
- `git status`, `git ls-files admin-panel/`

---

**Confidence: 88/100** — every finding is grounded in a directly-read line; the score is below 90 because (a) `style.css` (34 KB) was inspected by reference only, so any CSS-side issues are not in scope here; (b) Firebase Hosting deploy behavior for `public/screenshots/` is reasoned from `firebase.json` semantics rather than a live preview deploy; (c) Firestore rule effectiveness for `list: if request.auth != null` was not exercised at runtime against the production project — the verdict is based on documented Firestore rule semantics, not a live curl against the database.

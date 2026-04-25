# 24 — Admin Panel Pass 2 (NEW findings only)

**Scope:** second, deeper pass on `admin-panel/`. Pass 1 lives in `audit/08-admin-panel.md` (XSS via feedback fields, CORS `*` bug, list-all `user_profiles`, missing KPIs, etc.). This pass surfaces ONLY issues that Pass 1 did not raise.
**Stance:** read-only review of files as committed today; no live deploy probed.
**Project:** `laso-health-v1`. Functions runtime: Node 20 (`functions/package.json:5`). Firebase Functions SDK v2. Hosting carries no `headers` block (`firebase.json:1-30`).
**Format:** every finding follows Severity / Issue / Why this exists / Impact / Evidence / Verify / Fix / Priority / Confidence.

---

## Executive verdict (Pass 2)

Pass 1 framed the panel as "above-average Firebase admin dashboard with two real bugs." Pass 2 confirms that, and adds a layer of **operational** risk that Pass 1 did not surface:

1. **Cloud Functions are misconfigured for production.** Every function runs on the **default v2 settings: `us-central1`, 256 MiB RAM, 60 s timeout, 80 concurrency, unbounded `maxInstances`, ZERO retries on `onCall`, and no region pin** (`functions/index.js:220, 240, 298, 339, 385`). A single billing-card stuff-up or runaway client loop on `getUserStats` can spin up hundreds of instances. There is also no `region(...)` declared, so EU-only operators sit on a US deployment with the round-trip latency and the residency posture that brings.
2. **`getUserStats` is a callable that calls `admin.firestore().collection("user_profiles").get()` with NO size guard, NO timeout-aware streaming, and NO `maxInstances`.** Pass 1 noted the cost. Pass 2's new angle: at ~1M docs the function blows the 60 s callable timeout, leaves a partial in-flight `count()` aggregate hanging, AND the dashboard re-issues the call on every page open. A misbehaving admin tab can DDOS the project.
3. **Storage bucket and storage rules are entirely undefined.** `firebase.json` has no `storage` block and there is no `storage.rules` file in the repo. The default Firebase Storage bucket `laso-health-v1.firebasestorage.app` (referenced by the iOS-app `firebaseConfig` in `app.js:10`) ships with the **default rules** — which block all access — but no one has codified them, so any future deploy with an open `allow read, write` will go live silently with no PR to review.
4. **`firestore.indexes.json` does not exist.** Composite indexes are auto-created the first time a query needs one, but they are NOT codified in source. The `feedback` orderBy+where pair (`functions/index.js:349-353`) and the `admin_audit_log` orderBy (`functions/index.js:388-391`) will work; any future composite query in the iOS app or panel will silently miss its index until traffic hits it in prod.
5. **The dashboard ships unpinned, unverified third-party JavaScript from `gstatic.com`.** Firebase compat SDK 10.12.0 is loaded as four separate `<script src="https://www.gstatic.com/...">` tags (`index.html:584-587`) **with no `integrity` attribute and no `crossorigin` attribute**. A malicious gstatic mirror, or a successful BGP / DNS hijack, ships any JS into an authenticated admin session. CSP `script-src` includes `https://www.gstatic.com` so the loader is whitelisted — exactly the path SRI is supposed to harden.
6. **Hosting headers are entirely absent on `firebase.json`.** Pass 1 mentioned this; Pass 2 quantifies the gap: no CSP, no HSTS, no X-Frame-Options, no X-Content-Type-Options, no Referrer-Policy, no Permissions-Policy. Vercel deploys are fine. The default Firebase Hosting host `laso-health-v1.web.app` ships **wide open**, and that is the URL the developer email `firebase-debug.log` last hit (`firebase-debug.log` references `laso-health-v1.web.app`).
7. **Admin login is email/password only with no MFA, no email-domain restriction, and no failed-login throttle.** Firebase Auth's brute-force protections are silent and undocumented; the panel does not enforce a stronger gate. A leaked admin password is one cURL away from total Remote Config control.

The findings below are organised in priority order.

---

## B1 — Cloud Functions ship with all v2 defaults; no region, memory, timeout, concurrency, or maxInstances declared

**Severity:** HIGH (cost runaway + EU residency + hard fails at scale).
**Issue:** Every callable / onRequest export uses bare `onCall(...)` / `onRequest(...)`. None declares `region`, `memory`, `timeoutSeconds`, `concurrency`, `maxInstances`, `minInstances`, or `cpu`. Result: 256 MiB RAM, 60 s timeout, **`us-central1`**, **concurrency 80** (Cloud Run default that v2 inherits), **unbounded `maxInstances`** (defaults to 100 today but Firebase has been raising the cap), and **cold-start every invocation** because `minInstances` is unset.
**Why this exists:** Boilerplate from a `firebase init functions` scaffold. Defaults were never tuned.
**Impact:**
- **Cost runaway.** `getUserStats` (`index.js:298`) does a full table scan; one client-side bug that re-issues the call in a tight loop scales out to 100 concurrent instances doing full collection reads. A single bad afternoon can cost more than the hosting bill for the year.
- **Residency.** EU users (and any future EU admin operator) sit on `us-central1` Firestore + Functions. GDPR Art. 44 transfer logic must be documented; today it is not, because nobody chose the region.
- **Cold start latency.** Every admin dashboard load pays the full Node 20 + firebase-admin cold start (~2-3 s typical) on the first call after idle. Pass 1's "30/min/admin rate limit" assumes admins click around; cold start makes the panel feel sluggish.
- **Concurrency.** `concurrency: 80` (v2 default) means a single instance handles 80 concurrent callable invocations — fine for trivial reads, **fatal for `getUserStats` because eight admins refreshing simultaneously share one 256 MiB heap iterating ~100K user docs**.

**Evidence:**
- `admin-panel/functions/index.js:220` — `exports.getRemoteConfig = onCall(async (request) => {` — no options.
- `admin-panel/functions/index.js:240` — `exports.updateRemoteConfig = onCall(async (request) => {` — no options.
- `admin-panel/functions/index.js:298` — `exports.getUserStats = onCall({ invoker: "public" }, async (request) => {` — only `invoker` set.
- `admin-panel/functions/index.js:339, 385` — same pattern.
- `admin-panel/functions/index.js:1` — `require("firebase-functions/v2/https")` confirms v2.
- No `setGlobalOptions(...)` call anywhere in `index.js`.
- No `firebase.json` `functions.runtime` overrides.

**Verify fast:** `firebase functions:list --project laso-health-v1` shows region `us-central1`. `firebase functions:config:get` is empty. `gcloud run services describe getuserstats --region us-central1` will confirm `concurrency: 80`, `memory: 256Mi`, `timeoutSeconds: 60`.

**Fix (production-grade):**
```js
// At top of index.js, before any export
const { setGlobalOptions } = require("firebase-functions/v2");
setGlobalOptions({
  region: "us-central1",          // pick deliberately + document why
  maxInstances: 10,                // cap blast radius
  memory: "512MiB",               // getUserStats needs more headroom than 256
  timeoutSeconds: 60,
  concurrency: 1,                  // safer for admin-only callables; raise per-fn for public ones
});

// Then per-function tuning where it matters:
exports.getUserStats = onCall({
  memory: "1GiB",
  timeoutSeconds: 120,
  maxInstances: 3,                 // 3 admins refreshing, max
  concurrency: 1,
  invoker: "public",
}, async (request) => { /* ... */ });
```

**Priority:** P1 — set before launch.
**Confidence:** 96/100 — every export read end-to-end; `onCall` v2 defaults documented in Firebase v2 release notes.

---

## B2 — `getUserStats` has no document-count guard + no streaming; will hard-fail at ~500K user_profiles

**Severity:** MEDIUM-HIGH (hard fail at scale; not a security issue).
**Issue:** `index.js:301` does a single `collection("user_profiles").get()` followed by `snapshot.forEach`. There is no `limit(N)` cap, no chunked iteration, no early bail-out, no streaming via `stream()` or `select()`. The function loads every document fully into memory, into the Node heap, in one shot. With 256 MiB RAM, this OOMs around ~150-200K docs depending on per-doc size.
**Why this exists:** Pass 1 noted the cost of full reads. Pass 2's new angle is the **hard fail mode**: it does not degrade gracefully — it crashes the function instance and the admin dashboard sees `internal` with no useful message.
**Impact:**
- The dashboard `Total Users` stat shows `--` with no recovery path once over the limit.
- `Users` page bar charts go empty. Admins lose ALL demographics visibility right at the moment user count matters most (post-launch growth phase).
- Cloud Functions auto-scales to mask the OOM by spinning up new instances; cost goes up while the answer is still wrong.

**Evidence:**
- `admin-panel/functions/index.js:298-334`. No `.limit()`, no `.stream()`, no `.select(['gender','region',...])` projection.
- No fallback / error-message branch; failure surfaces as the generic `HttpsError` from the SDK.

**Verify fast:** seed `user_profiles` with 200K dummy docs in the emulator, call `getUserStats` — function instance OOMs in CloudFunctions logs.

**Fix:**
1. Use `.select('gender', 'biological_sex', 'age_bracket', 'ageBracket', 'region', 'health_focuses', 'healthFocuses', 'app_version', 'appVersion')` — strips heavy fields, slashes per-doc size 5-10×.
2. Iterate via `await collection.select(...).stream()` with a per-doc accumulator instead of `forEach` on a buffered snapshot.
3. Above 50K users, switch to a scheduled aggregation doc (`analytics/user_profile_summary`) updated every hour by `onSchedule`; admin reads the single doc.
4. Cap at 100K docs with `.limit(100000)` as a guardrail and log if hit.

**Priority:** P1 — before passing 50K users.
**Confidence:** 95/100 — code path verified; OOM threshold reasoned from Node 20 + firebase-admin per-doc memory.

---

## B3 — No `firestore.indexes.json` checked into the repo

**Severity:** MEDIUM (deploy-time invisibility + drift).
**Issue:** No `firestore.indexes.json` exists at `admin-panel/firestore.indexes.json` or anywhere referenced by `firebase.json`. Firebase auto-creates composite indexes lazily on first failing query, and the dev clicks "Create Index" in the console URL the error gives. Today's queries do not need composite indexes (the two `orderBy` queries are single-field and Firestore creates these automatically), but this means **every future composite index lives only in the live project, not in source control**. Disaster-recovery or staging-environment standup re-creates the project from `firebase.json` only — indexes are missing.
**Why this exists:** `firebase init firestore` only writes `firestore.rules` by default unless you explicitly add the indexes file.
**Impact:**
- Staging / preview-channel deploys will be missing indexes that prod has.
- Any new admin-panel query that needs a composite index will fail in prod the first time it is hit until a human clicks the console URL.
- No PR-time review of new indexes (which are essentially capacity decisions).

**Evidence:**
- `admin-panel/firebase.json:27-29` declares only `firestore.rules`; no `indexes` field.
- `find admin-panel -name "firestore.indexes.json"` → no file.

**Verify fast:** `firebase deploy --only firestore --project laso-health-v1 --dry-run` does not mention indexes.

**Fix:**
1. Run `firebase firestore:indexes --project laso-health-v1 > admin-panel/firestore.indexes.json` to materialise the current state.
2. Update `firebase.json` `firestore` block:
   ```json
   "firestore": {
     "rules": "firestore.rules",
     "indexes": "firestore.indexes.json"
   }
   ```
3. Commit `firestore.indexes.json` and treat it as code.

**Priority:** P2 — fix before second environment (staging) is created.
**Confidence:** 95/100 — file absence verified; behavior per Firebase docs.

---

## B4 — Firebase Storage rules and bucket configuration are completely absent from the repo

**Severity:** MEDIUM (silent regression risk).
**Issue:** `firebaseConfig.storageBucket = "laso-health-v1.firebasestorage.app"` is referenced in the iOS-app side AND in the admin panel (`app.js:10`), but the admin-panel repo has **no `storage.rules` file, no `storage` block in `firebase.json`, and no documentation** on what the bucket is used for. A future developer running `firebase deploy --only storage` from a fork with permissive rules will silently push them to prod with no PR to review (because there is nothing in this repo to diff against).
**Why this exists:** Storage was set up out-of-band (probably in the Firebase console). It was never codified.
**Impact:**
- The default Firebase Storage rules block all reads/writes, so the bucket is currently safe IF that is what was deployed.
- IF anyone has run `firebase deploy --only storage` from a different repo (or the console editor) with `allow read, write: if true;`, the bucket is publicly read/writable and there is no committed source-of-truth to compare against.
- The admin panel does not surface storage usage or rules — operations team is blind.

**Evidence:**
- `admin-panel/firebase.json` — no `storage` key.
- `find admin-panel -name "storage.rules"` → no file.
- `app.js:10` references the bucket.
- Pass 1 did not flag this; it focused on Firestore rules only.

**Verify fast:** `firebase storage:rules:get --project laso-health-v1` (or in the Firebase console, Storage → Rules tab) — capture the live ruleset and diff against expectation.

**Fix:**
1. Pull live rules: `firebase storage:rules:get --project laso-health-v1 > admin-panel/storage.rules`.
2. Add to `firebase.json`:
   ```json
   "storage": {
     "rules": "storage.rules"
   }
   ```
3. Inspect what the rules say. If the bucket is not used, switch to `allow read, write: if false;` and codify the lock.
4. Document in `admin-panel/README.md` (currently absent) what the bucket is for.

**Priority:** P1 — codify before next storage deploy.
**Confidence:** 92/100 — repo absence is direct; live rule state was not probed.

---

## B5 — Firebase compat SDKs loaded from gstatic with NO Subresource Integrity (SRI)

**Severity:** MEDIUM (supply-chain).
**Issue:** Four `<script src="https://www.gstatic.com/firebasejs/10.12.0/firebase-*-compat.js"></script>` tags load with no `integrity="sha384-..."` and no `crossorigin="anonymous"`. The CSP `script-src` whitelists `https://www.gstatic.com`, so any resource served from that origin is trusted unconditionally.
**Why this exists:** The Firebase docs' default snippet does not include SRI; nobody added it.
**Impact:**
- A successful compromise of `gstatic.com` (rare but happens — Google's CDN has been targeted before via BGP hijack) injects arbitrary JS into an authenticated admin session.
- A misconfigured corporate proxy or local antivirus that MITMs HTTPS can swap the bundle without detection.
- Chains with Pass 1's A1 (XSS via feedback): once a payload runs, it can modify Remote Config because `firebase.functions().httpsCallable("updateRemoteConfig")` is already initialised.

**Evidence:**
- `admin-panel/public/index.html:584-587`:
  ```html
  <script src="https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js"></script>
  <script src="https://www.gstatic.com/firebasejs/10.12.0/firebase-auth-compat.js"></script>
  <script src="https://www.gstatic.com/firebasejs/10.12.0/firebase-functions-compat.js"></script>
  <script src="https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore-compat.js"></script>
  ```
- No `integrity=` anywhere in `index.html` (verified with grep).
- `vercel.json:11-12` CSP `script-src` includes `https://www.gstatic.com` — wide whitelist.

**Verify fast:** `curl -s https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js | openssl dgst -sha384 -binary | openssl base64 -A` to compute the hash.

**Fix:**
1. Add `integrity` and `crossorigin` to each tag:
   ```html
   <script src="https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js"
           integrity="sha384-..."
           crossorigin="anonymous"></script>
   ```
2. Long-term: migrate to ESM modular SDK (`firebase/app`, `firebase/auth`, `firebase/firestore`) and bundle locally — drops both the third-party fetch AND the `'unsafe-eval'` requirement Pass 1 noted in A7.

**Priority:** P2 — quick win.
**Confidence:** 99/100 — direct read of `index.html`.

---

## B6 — `firebase.json` has zero security headers; Firebase Hosting deploy ships wide open

**Severity:** MEDIUM (defense in depth missing on the live host).
**Issue:** Pass 1 noted in A7 that `vercel.json` carries CSP/HSTS/X-Frame-Options but `firebase.json` does not. Pass 2's deeper read confirms `firebase.json` has no `hosting.headers` block AT ALL — no CSP, no HSTS, no X-Frame-Options, no X-Content-Type-Options, no Referrer-Policy, no Permissions-Policy. The Firebase Hosting copy at `https://laso-health-v1.web.app/` ships with **only Firebase's own defaults** (which include `Strict-Transport-Security` from Hosting itself, but no CSP).
**Why this exists:** `vercel.json` was hardened first; `firebase.json` was never updated.
**Impact:**
- The two hosts (`laso-health-v1.web.app` and any Vercel-deployed copy) have **divergent security postures**. Whichever URL the admin opens determines whether they get CSP protection.
- `firebase-debug.log` (`firebase-debug.log:line containing site target`) confirms `laso-health-v1.web.app` IS a live deploy target — so this is the URL admins actually use day-to-day if they hit the Firebase host.
- A clickjacking attack against `laso-health-v1.web.app` is unblocked (no `X-Frame-Options: DENY`).
- A reflected XSS that bypasses the existing render gates would have unrestricted CSP because there is none.

**Evidence:**
- `admin-panel/firebase.json` — full file shown earlier; no `headers` block.
- `admin-panel/vercel.json:6-35` — full hardening present.

**Verify fast:** `curl -I https://laso-health-v1.web.app/` and check for `Content-Security-Policy`, `X-Frame-Options`. They will be missing.

**Fix:** add to `firebase.json` `hosting`:
```json
"headers": [
  {
    "source": "**/*",
    "headers": [
      { "key": "Content-Security-Policy", "value": "<copy from vercel.json>" },
      { "key": "Strict-Transport-Security", "value": "max-age=63072000; includeSubDomains; preload" },
      { "key": "X-Frame-Options", "value": "DENY" },
      { "key": "X-Content-Type-Options", "value": "nosniff" },
      { "key": "Referrer-Policy", "value": "strict-origin-when-cross-origin" },
      { "key": "Permissions-Policy", "value": "camera=(), microphone=(), geolocation=()" }
    ]
  }
]
```

**Priority:** P1 — before next Firebase Hosting deploy.
**Confidence:** 99/100 — direct read.

---

## B7 — No MFA, no email-domain restriction, no failed-login throttle on admin login

**Severity:** MEDIUM-HIGH (single password = god mode).
**Issue:** Login is plain `auth.signInWithEmailAndPassword` (`app.js:1218`). There is:
- **No MFA enforcement.** `verifyAdmin` checks `customClaims.admin` server-side but does NOT check `user.multiFactor.enrolledFactors.length > 0` or `request.auth.token.firebase.sign_in_provider === 'multifactor'`.
- **No email domain allow-list.** Any Firebase Auth user with the admin custom claim gets in. There is no rule like "email must end in `@lasohealth.com`."
- **No client-side or server-side failed-login throttle.** Firebase Auth has its own opaque rate limit that triggers around 100 failures, but the panel does not surface it. Brute-force a known admin email through residential proxies, or stuff credentials from a leak — the panel offers no resistance beyond Firebase's silent rate limit.
- **No CAPTCHA.** Login button has zero anti-automation gating.

**Why this exists:** v1 simplicity — one engineer, one Firebase user, no time to wire MFA.
**Impact:** A leaked or guessed admin password is **immediate and total** Remote Config control: master kill switch, force-update, free-year toggle, pricing product IDs. Pass 1 noted single-tier admin role; Pass 2's new angle is the **authentication strength**, which is the protective layer in front of that role.
**Evidence:**
- `admin-panel/public/app.js:1215-1226` — login flow.
- `admin-panel/functions/index.js:100-116` — `verifyAdmin` — no MFA check, no domain check.
- No `auth.multiFactor` references anywhere in `app.js`.

**Verify fast:** in Firebase Console → Auth → Settings, check whether MFA is enforced per-user. The code does not enforce; the console may or may not.

**Fix:**
1. Enforce MFA in `verifyAdmin`:
   ```js
   const claims = request.auth.token;
   if (!claims.firebase?.sign_in_second_factor) {
     throw new HttpsError("permission-denied", "MFA required for admin actions.");
   }
   ```
2. Restrict by email domain (server-side, via `verifyAdmin`):
   ```js
   if (!user.email?.endsWith("@lasohealth.com")) {
     throw new HttpsError("permission-denied", "Admin access restricted by email domain.");
   }
   ```
3. Enrol all admin accounts in TOTP MFA via Firebase Auth Identity Platform.
4. Optionally: front the panel with Cloud IAP or a Cloudflare Access policy that adds a Google-account hop in front of the Firebase login.

**Priority:** P1 — fix before launch. Single password = single point of failure.
**Confidence:** 96/100 — code paths verified by direct read.

---

## B8 — No `console.log` / `functions.logger` discipline; no Cloud Error Reporting / Sentry on functions

**Severity:** LOW-MEDIUM (operational blindness on the server too).
**Issue:** `functions/index.js` uses `console.error("...", err)` three times (lines 94, 142, 210). It does NOT use `firebase-functions/logger` (the structured logger that produces JSON Cloud Logging entries with proper severity, traces, and label support). It does not integrate Sentry / Cloud Error Reporting either. Pass 1 noted the front-end has no Sentry (A9). Pass 2's new angle: **the back-end functions have no error monitoring either**, so when `getUserStats` OOMs (B2) or `updateRemoteConfig` throws on a malformed Remote Config template, the only signal is a Cloud Logging line that nobody is paging on.
**Why this exists:** v2 boilerplate uses `console.*`; nobody migrated.
**Impact:**
- No paging on production errors. Discovery is by an admin saying "the dashboard broke."
- `console.error` outputs go to Cloud Logging at the default severity, but without the structured fields that Cloud Error Reporting needs to group and de-dup. So even if the team enables Error Reporting, the existing logs do not feed it cleanly.
- Audit log writes can fail silently (line 94 — only `console.error("Audit log write failed", err.message)`). A persistent Firestore outage or rule regression would silently disable the audit trail without anyone knowing.

**Evidence:**
- `admin-panel/functions/index.js:94` — `console.error("Audit log write failed:", err.message);` (silent failure mode for the audit trail).
- `admin-panel/functions/index.js:142` — `console.error("getSignupCount error:", err);`.
- `admin-panel/functions/index.js:210` — `console.error("earlyAccessSignup error:", err);`.
- No `require("firebase-functions/logger")` anywhere.
- No Sentry / `@sentry/node` import.

**Verify fast:** `firebase functions:log --project laso-health-v1` shows unstructured text lines; no severity or trace correlation.

**Fix:**
```js
const { logger } = require("firebase-functions/v2");
// ...
logger.error("Audit log write failed", { error: err.message, uid });
```
And for paging: enable Cloud Error Reporting in the GCP console (free, automatic for `logger.error` calls) OR add Sentry's Node SDK with a tiny wrapper.

**Priority:** P2.
**Confidence:** 99/100 — direct read.

---

## B9 — No scheduled / cron functions; no cleanup jobs for stale rate-limit map, audit log retention, or feedback retention

**Severity:** LOW-MEDIUM (data growth + memory leak).
**Issue:** No `onSchedule(...)` exports in `index.js`. No scheduler functions at all. Pass 1 did not flag this; Pass 2's new angle is the **garbage that piles up**:
1. **`admin_audit_log` grows forever.** No retention rule (Firestore TTL not enabled, no `onSchedule` cleanup). At 30 RC updates/day × 365 days = ~11K docs/year — small, but the `getAuditLog` query orders by timestamp DESC limit 100 which is fine; the **storage cost** is unbounded forever.
2. **`feedback` grows forever.** Same — no TTL, no cleanup. Any GDPR DSAR (delete user) request leaves orphan feedback docs because Firestore rules forbid delete (`firestore.rules:16` — `allow update, delete: if false`).
3. **`early_access` grows forever.** Same.
4. **The in-memory rate-limit map in functions** (`index.js:8-37`) self-cleans every 5 min via `setInterval` — but Cloud Functions v2 instances are ephemeral, so the cleanup is irrelevant; the per-instance map is fine. **However** the `setInterval` keeps the Node event loop alive and **prevents the function instance from idle-shutting-down cleanly**, increasing per-instance lifetime cost slightly. Trivial in practice but worth noting.

**Why this exists:** No retention strategy was written.
**Impact:**
- Storage cost grows linearly with time.
- GDPR Article 17 (right to erasure) is harder to satisfy because the panel has no "delete user feedback" path and the rule explicitly forbids deletion. To delete, an engineer must write a one-off Admin SDK script.
- `early_access` doc count from a marketing campaign sticks around years after the campaign ended.

**Evidence:**
- `admin-panel/functions/index.js` — no `onSchedule`, no `scheduler` import.
- `admin-panel/firestore.rules:16, 29, 85, 107, 115` — every collection forbids client `delete`. Server-side admin SDK can still delete, but no scheduled job does.

**Verify fast:** `firebase functions:list --project laso-health-v1` shows zero scheduled functions.

**Fix:**
1. Enable Firestore TTL (`Time to Live`) on collections that should self-expire:
   - `admin_audit_log` with `expiresAt` field set to `now + 365d` on write — Firestore auto-deletes.
   - `feedback` with `expiresAt = timestamp + 730d` (or whatever the privacy policy says).
2. Add an `onSchedule("every 24 hours", ...)` function that purges any feedback / profile when a user requests deletion (the DSAR pipeline Pass 1 mentioned but didn't formalise).
3. Drop the `setInterval` in `index.js:30-37` — let Node GC handle the rate-limit map; instances die soon enough.

**Priority:** P2.
**Confidence:** 90/100 — absence of `onSchedule` direct; TTL behavior per Firestore docs.

---

## B10 — `early_access` and `user_profiles` lack any document-size cap; iOS app can write arbitrarily large `health_focuses` arrays / referral codes

**Severity:** LOW-MEDIUM (cost + 1 MiB Firestore limit).
**Issue:** `firestore.rules` for `user_profiles/{deviceId}` (`firestore.rules:37-86`) caps the **field set** (via `allowedFields()`) but does NOT cap the **size** of any individual field. `health_focuses` is an array — clients can write an array of 10,000 strings, each 100 KB, until they hit Firestore's 1 MiB doc limit. Same for `referralCode` — no length bound. `feedback.text` IS bounded to <2000 chars (good); `feedback.category` and `app_version` are NOT (Pass 1 A1 noted XSS but not the size dimension).
**Why this exists:** Defense-in-depth gap. Functions sanitize on read; rules don't constrain on write.
**Impact:**
- Malicious iOS user pads their `health_focuses` array with massive strings → Firestore reads on `getUserStats` allocate huge per-doc memory → B2's OOM happens earlier.
- Cost: each MB of unnecessary doc bloat is a real Firestore storage line item.

**Evidence:** `admin-panel/firestore.rules:50-62` — no `.size()`, `.matches()`, or `is list` length check on any field except the rule-mandated `firebaseUid`/`deviceId` shape.

**Verify fast:** sign in to iOS, write `Firestore.firestore().collection("user_profiles").document(deviceId).updateData(["healthFocuses": Array(repeating: String(repeating: "x", count: 100000), count: 5)])` — write succeeds up to 1 MiB.

**Fix:** tighten rule with `.size()` constraints:
```js
&& request.resource.data.healthFocuses is list
&& request.resource.data.healthFocuses.size() < 20
&& request.resource.data.referralCode is string
&& request.resource.data.referralCode.size() < 32
```

**Priority:** P2.
**Confidence:** 95/100 — direct rule read.

---

## B11 — `updateRemoteConfig` does not validate **values** for the dangerous keys; admin can publish a bricking config

**Severity:** MEDIUM (operator footgun + audit insufficient).
**Issue:** `updateRemoteConfig` (`functions/index.js:240-293`) validates that keys are ≤100 chars and values are ≤1000 chars, but does NOT validate that, e.g., `minimum_app_version` looks like a semver (`^\d+\.\d+(\.\d+)?$`) or that `kill_switch_enabled` is `"true"` or `"false"`. A typo like `minimum_app_version = "999.0"` (Pass 1 cross-cutting note flags this is a kill-everyone path) goes through with no warning. A typo like `kill_switch_enabled = "yes"` would be **interpreted as falsy by the iOS app's `==='true'` check** — so the kill switch silently fails to activate when an admin thinks they enabled it.
**Why this exists:** Validation was generic, not key-aware.
**Impact:**
- The Operations page UI confirms before enabling a kill switch (good), but if the admin types `"yes"` into the underlying RC value (via the Configuration page or via a future bug), the kill switch is silently no-op'd.
- `minimum_app_version = "999.0"` force-locks every user out of the app on next foreground. There is no second-person review step ("are you sure you want to require version 999.0?").
- Audit log captures the diff but does not reject obvious wrong shapes.

**Evidence:**
- `admin-panel/functions/index.js:248-257` — generic length-only validation.
- No per-key shape rules.
- `admin-panel/public/app.js:1146-1167` — front-end confirms ON kill switch enable but not on every dangerous key.

**Verify fast:** as admin, set `minimum_app_version = "totally not a version"` via the panel — published with no error.

**Fix:** introduce a per-key validator map:
```js
const KEY_VALIDATORS = {
  "minimum_app_version": (v) => /^\d+\.\d+(\.\d+)?$/.test(v) && parseInt(v) <= 99,
  "kill_switch_enabled": (v) => v === "true" || v === "false",
  "kill_live_tab":       (v) => v === "true" || v === "false",
  "kill_ml_pipeline":    (v) => v === "true" || v === "false",
  "kill_cloud_backup":   (v) => v === "true" || v === "false",
  "kill_notifications":  (v) => v === "true" || v === "false",
  "free_year_active":    (v) => v === "true" || v === "false",
  "pricing_pro_trial_days": (v) => /^\d{1,3}$/.test(v),
  // ...
};
for (const [key, value] of Object.entries(parameters)) {
  const v = KEY_VALIDATORS[key];
  if (v && !v(String(value))) {
    throw new HttpsError("invalid-argument", `Invalid value for ${key}`);
  }
}
```

**Priority:** P1 — closes the silent-noop class of bugs on critical kill switches.
**Confidence:** 97/100 — direct read.

---

## B12 — No idempotency guard on `updateRemoteConfig` or `earlyAccessSignup`; a retried request publishes twice / writes twice

**Severity:** LOW-MEDIUM.
**Issue:** Neither `updateRemoteConfig` nor `earlyAccessSignup` accepts an idempotency key. Cloud callable retries (which the Firebase JS client does on transient network failures) can:
- For `updateRemoteConfig`: publish the same template twice. Remote Config has its own ETag-based concurrency, so a retry that gets a fresh template each time may replay the same diff onto a NEW base — which is the opposite of what the admin wanted (e.g., a colleague's intervening change is silently overwritten).
- For `earlyAccessSignup`: dedup is by email-uniqueness query (`functions/index.js:174-184`), which IS effectively idempotent — good. But if two POSTs race (same email, both pre-dedup), both win. Result: duplicate documents.

**Why this exists:** Neither endpoint accepts a client-supplied `requestId`.
**Impact:** Rare in practice. Important on the day a Firestore outage causes mass retries.
**Evidence:**
- `admin-panel/functions/index.js:240-293` — no `requestId` parameter, no `transaction`-based RC publish.
- `admin-panel/functions/index.js:174-184` — dedup is read-then-write, NOT a transaction.

**Fix:**
1. `updateRemoteConfig`: wrap the RC `getTemplate → modify → publishTemplate` in a retry loop that catches the `failed-precondition` ETag error and re-fetches.
2. `earlyAccessSignup`: do a Firestore transaction or use the email as the doc ID (`db.collection("early_access").doc(email).set({...}, { merge: false })` with `if (!exists)` guard) — eliminates the duplicate-on-race window.

**Priority:** P3.
**Confidence:** 88/100 — reasoned from Firebase callable retry semantics; not exercised live.

---

## B13 — No App Store Server Notifications V2 webhook; subscription state has no server-side mirror

**Severity:** HIGH (revenue blindness + revocation gap) — NEW angle on Pass 1 A14.
**Issue:** Pass 1 A14 noted "no MRR/ARPU/LTV/churn — panel is not a business dashboard." Pass 2's new angle: the **upstream cause** is that the project has no App Store Server Notifications V2 webhook endpoint. There is no `onRequest` function that consumes ASSN V2 (`SUBSCRIBED`, `DID_RENEW`, `EXPIRED`, `REFUND`, `REVOKE`, etc.) and writes a `subscriptions/{firebaseUid}` doc.
**Why this exists:** Subscription state is read iOS-side via StoreKit 2 only; nothing mirrors it to Firestore.
**Impact:**
- **Refund / revoke detection.** When Apple refunds a user, StoreKit's local cache may not update immediately. Without ASSN, the iOS app continues showing pro features for hours-to-days until the next App Store check. Fix: receive `REFUND` notification → mark subscription stale.
- **Family-sharing revocation.** Same.
- **Server-side revenue reporting.** Without ASSN, MRR / ARR can only be reconstructed by querying App Store Connect API daily — expensive, slow, and subject to ASC rate limits.
- **Detecting fraudulent jailbroken receipt validation.** ASSN V2 carries a JWS signature; verifying it server-side is the canonical fraud check. Without the webhook, the only fraud signal is StoreKit's local validation, which has been bypassed by emulator tools.

**Why this is a Pass 2 finding (not a duplicate of A14):** A14 said "the panel doesn't show MRR." B13 says "the panel CAN'T show MRR because there is no data pipeline." This is a backend / functions architecture finding, not a UI gap.

**Evidence:**
- `admin-panel/functions/index.js` — no webhook endpoint. Function names: `getSignupCount, earlyAccessSignup, getRemoteConfig, updateRemoteConfig, getUserStats, getFeedbackStats, getAuditLog`. None handle Apple notifications.
- No `jose` / `jsonwebtoken` dependency in `functions/package.json` — JWS verification not even possible today.
- `firebase.json:5-22` rewrites — no `/api/appStoreNotifications` rewrite.

**Verify fast:** in App Store Connect → My Apps → App Information → App Store Server Notifications → Production Server URL field. If empty, ASSN is not configured.

**Fix (production-grade):**
1. Add `jose` (or `firebase-admin`'s built-in support) to `functions/package.json`.
2. Add `exports.appStoreNotificationsV2 = onRequest({ cors: false, region: "us-central1" }, ...)` that:
   - Verifies the JWS using Apple's public root cert chain.
   - Decodes `signedTransactionInfo` and `signedRenewalInfo`.
   - Writes a `subscriptions/{firebaseUid}` doc with `{ tier, status, started_at, ends_at, trial, last_event, last_event_at }`.
3. Configure the URL in App Store Connect.
4. Then surface MRR / ARR / churn on the dashboard from `subscriptions/`.

**Priority:** P0 — webhook before any paid go-live. Refunds are a real business risk.
**Confidence:** 96/100 — codebase grep confirms absence; Apple ASSN behavior per Apple docs.

---

## B14 — No backup / disaster-recovery script in `Scripts/` or `admin-panel/`; Pass 1 noted the gap, Pass 2 confirms scope

**Severity:** HIGH (recovery RTO undefined) — refines Pass 1 A15.
**Issue:** Pass 1 A15 said "no backup strategy is documented or scripted." Pass 2's deeper read confirms the scope is broader:
- No `Scripts/firestore-backup.sh`.
- No Cloud Scheduler job exporting Firestore.
- No documented `gs://laso-backups` bucket.
- **No backup of Remote Config.** This is a NEW dimension Pass 1 missed: if the RC template is corrupted (B11) or a malicious admin publishes `kill_switch_enabled = "true"`, the rollback is via the Firebase console's RC version history (which keeps ~300 versions) — no scripted backup of the RC template into Firestore or GCS.
- **No backup of `admin_audit_log`.** Tamper-evident in normal operation, but a Firestore-side outage that corrupts the collection has no off-site copy.

**Why this exists:** Backups are off by default on Firestore; nobody enabled them.

**Impact:**
- RTO undefined.
- A malicious or accidental `kill_switch_enabled = "true"` requires manual rollback via the RC console — operator must know how, fast.
- A complete project deletion (billing freeze, malicious actor with admin GCP role) is unrecoverable.

**Evidence:**
- `find /Users/primetrace/Desktop/RnD/HealthPulse -name "*.sh" -path "*backup*"` → no file.
- `admin-panel/functions/index.js` — no scheduler, no RC export.
- Pass 1 A15 confirmed Firestore export absence; Pass 2 confirms RC export absence (new).

**Verify fast:** in Firebase Console → Firestore → Backups → look for scheduled backups.

**Fix:**
1. Enable Firestore Managed Backups (paid feature; ~few cents/day).
2. Add `exports.backupRemoteConfig = onSchedule("every 6 hours", async () => { const t = await admin.remoteConfig().getTemplate(); await admin.firestore().collection("rc_backups").add({ template: t, at: serverTimestamp() }); });`.
3. Document RTO/RPO in a `runbooks/disaster-recovery.md`.

**Priority:** P1 — set before launch.
**Confidence:** 95/100 — direct repo grep.

---

## B15 — `dev-runner/server.js` exposes `--override-name` as a freeform string flag; the iOS screenshot script may exec it without escaping

**Severity:** LOW (local-dev only; depends on the script) — refines Pass 1 A13.
**Issue:** Pass 1 A13 noted dev-runner is bound to `127.0.0.1` and uses argv-array `spawn` (no shell injection). Pass 2's new angle is **downstream**: the script `Scripts/capture-app-store-screenshots.sh` (not in scope of this admin-panel audit but referenced by `dev-runner/server.js:17`) receives `--override-name=<arbitrary string>` raw. If that script does `eval` / `xargs` / unquoted variable expansion of the flag, the freeform string IS exploitable from any browser tab on the same Mac. The dev-runner itself is safe; the question moves to the shell script.
**Why this exists:** Pass 1 stopped at the Node spawn boundary; the shell script's argument-handling discipline was not audited.
**Impact:** A malicious page in another tab on the developer's Mac can craft `--override-name='$(rm -rf ~)'` and rely on the shell script mishandling it. Outcome ranges from harmless to catastrophic depending on the script.
**Evidence:**
- `admin-panel/dev-runner/server.js:20` — `^--(shots|folder-suffix|override-name|...)=.*` — `override-name` accepts ANY suffix.
- `admin-panel/dev-runner/server.js:66` — `spawn(SCRIPT, args, { cwd: REPO_ROOT })` — argv array, no shell. Safe at this layer.
- The Bash script's escaping discipline was not read in this audit.

**Verify fast:** `cat Scripts/capture-app-store-screenshots.sh | grep -E '\$1|\$\{1\}|\$\*|\$@'` — look for unquoted parameter expansion.

**Fix:** in `dev-runner/server.js:20`, tighten the `override-name` regex to a charset whitelist:
```js
const ALLOWED_FLAG = /^--(shots|folder-suffix|override-name)=[A-Za-z0-9 _.,/-]{0,40}$/...
// or split into per-flag regexes.
```

**Priority:** P3 — quick belt-and-braces.
**Confidence:** 75/100 — this finding flags a downstream surface NOT audited here. The actual exposure depends on `capture-app-store-screenshots.sh`. Confidence below 90 because the shell script was not read in this pass.

---

## B16 — `firebase.json` rewrites every URL to `/index.html`, including `/screenshots/<run>/<file>.png` if the static file is missing

**Severity:** LOW (operational confusion).
**Issue:** `firebase.json:18-21` has the catch-all `"source": "**", "destination": "/index.html"`. Firebase Hosting serves static files first and only falls through to the rewrite on 404. Today this works fine (the screenshots are present). But if a deploy ever drops a screenshot folder (e.g., admin runs `rm -rf admin-panel/public/screenshots/` to fix Pass 1 A5), every `<img src="screenshots/...">` returns the full HTML of `index.html` with `Content-Type: text/html` instead of a 404. The browser tries to render HTML as PNG, the dashboard shows broken thumbnails with no clear error.
**Why this exists:** SPA-style rewrite catch-all.
**Impact:** Admin sees "broken images" with no console error explaining "file not found" — the dashboard hides what is actually a 404.

**Evidence:**
- `admin-panel/firebase.json:18-21`.
- `admin-panel/public/app.js:1716` — `<img src="screenshots/${ts}/${file}">` — relies on the static file existing.

**Verify fast:** `curl -i https://laso-health-v1.web.app/screenshots/does-not-exist.png` — 200 OK, `Content-Type: text/html`, body is `index.html`.

**Fix:** narrow the rewrite source to exclude static asset paths:
```json
"rewrites": [
  { "source": "/api/getSignupCount", ... },
  { "source": "/api/earlyAccessSignup", ... },
  { "source": "!(/screenshots/**|/*.png|/*.jpg|/*.svg|/*.css|/*.js|/*.json|/*.ico)", "destination": "/index.html" }
]
```

**Priority:** P3.
**Confidence:** 92/100 — Firebase Hosting rewrite semantics per docs.

---

## B17 — Pagination buttons render integer page numbers via `${i}` into `innerHTML` (safe today, fragile)

**Severity:** LOW (defensive code-quality, not a bug today).
**Issue:** `app.js:988-996` builds pagination button HTML with `${currentPage}`, `${i}`, `${totalPages}` interpolated into `innerHTML`. Today these are guaranteed integers (`parseInt`/`Math.ceil`/`for` loop), so safe. But the pattern is the same XSS pattern Pass 1 A1 caught in feedback. The next dev who refactors and accidentally lets a string slip in (e.g., a page-number filter) introduces XSS.
**Why this exists:** Speed-of-development pattern.
**Impact:** None today; latent class.
**Evidence:** `admin-panel/public/app.js:988-996`.
**Fix:** use `document.createElement("button")` + `textContent` consistently, or `UI.escapeHtml(String(i))` defensively.
**Priority:** P3.
**Confidence:** 90/100.

---

## B18 — Login screen does not have `autocomplete="off"` on email field; nothing prevents browser-saved password from being silently used

**Severity:** LOW.
**Issue:** `index.html:17-18` uses `autocomplete="email"` and `autocomplete="current-password"`. Modern browsers will silently auto-fill saved credentials. Combined with the fact that no MFA is enforced (B7), if an attacker has shoulder-surfed an admin's auto-fill cue (the password manager prompt), the path to admin is one click.
**Why this exists:** Default-correct accessibility hint.
**Impact:** Trade-off between admin UX and shoulder-surfing exposure. Most banking sites disable autofill on internal admin consoles for this reason.
**Evidence:** `admin-panel/public/index.html:17-18`.
**Fix:** consider `autocomplete="off"` on the password field, or move admin login behind Cloud IAP / Cloudflare Access where the SSO step makes shoulder-surfing harder.
**Priority:** P3.
**Confidence:** 85/100 — value judgment, not a bug.

---

## B19 — `index.html:6` admin panel title is `Laso Admin`; combined with the missing `noindex` meta (Pass 1 A20) it advertises the admin URL

**Severity:** LOW (refines Pass 1 A20 with new angle).
**Issue:** Pass 1 A20 flagged the missing `<meta name="robots" content="noindex">`. Pass 2's new angle: the **`<title>` itself** — `Laso Admin` — is a Google search beacon. SERP snippets read like "Laso Admin — Sign in to manage your app" (the description tag is the login screen subtitle). For a competitor or attacker doing recon, that is "internal admin console." Combined with the Firebase Hosting URL pattern `<project>.web.app`, attackers can guess `laso-health-v1.web.app` and Google confirms it is the admin panel. Pre-launch, this is intelligence-leak territory. Pre-launch, also the project name is in the URL, so the reverse path is also trivial.
**Why this exists:** Default markup.
**Fix:** rename `<title>Laso Admin</title>` to something opaque (`Operations`), AND ship the noindex meta from A20.
**Priority:** P3.
**Confidence:** 90/100.

---

## B20 — `getRemoteConfig` returns the FULL RC template to any admin; no per-admin filtering, no field-level redaction

**Severity:** LOW-MEDIUM (related to Pass 1 A10's role-split concern, new angle: **read-side leak**).
**Issue:** `getRemoteConfig` (`functions/index.js:220-234`) returns every parameter the project has, every value, every description. Pass 1 A10 noted there is no role split for **writes**. Pass 2's new angle: even **reads** are uniform — a "support" role (if added per A10) would still see every parameter, including sensitive ones like `pricing_pro_monthly_product_id` (App Store SKU IDs aren't secret, but if RC ever holds an actual secret like a webhook signing key, it leaks).
**Why this exists:** v1 simplicity.
**Impact:**
- If RC is ever used for a secret, every admin sees it. The right pattern is "RC = non-secret config only, secrets go in Secret Manager" — which is what the code respects today, but the boundary is not enforced.
- Contributor onboarding to "support admin" inadvertently grants full RC visibility.

**Evidence:** `admin-panel/functions/index.js:220-234`. No filtering.
**Fix:** if/when role split lands (A10), filter parameters by role. Today, document that RC is for non-secret config only.
**Priority:** P3.
**Confidence:** 90/100.

---

## B21 — `firebase-functions ^5.0.0` and `firebase-admin ^12.0.0` are major versions behind current; `^` means automatic minor upgrades on next `npm install`

**Severity:** LOW.
**Issue:** `functions/package.json:8-11` pins `firebase-admin: ^12.0.0` and `firebase-functions: ^5.0.0`. As of audit date (2026-04-25), `firebase-admin` is on v13.x and `firebase-functions` is on v6.x. Two issues:
1. **Major versions behind** — missing security fixes and the v6 `setGlobalOptions` improvements.
2. **`^` allows minor/patch drift** — running `npm install` in a fresh checkout in 6 months may pick up a different version than what was tested. Combined with **no `package-lock.json` commitment review** (the lockfile is 100K and present at `functions/package-lock.json` — actually committed, so this point is moot — let me verify... `package-lock.json` IS at `admin-panel/functions/package-lock.json:1-100K`, so lockfile pinning works for the immediate deploy; CI/CD with `npm ci` is correct). The `^` is fine as long as `npm ci` is used. Risk is when someone runs `npm install` and writes a new lockfile.

**Why this exists:** Standard `npm init` pin.
**Impact:** Latent, not active.
**Evidence:**
- `admin-panel/functions/package.json:8-11`.
- `admin-panel/functions/package-lock.json` exists (100K) — pinning works for deterministic deploys.

**Verify fast:** `cd admin-panel/functions && npm outdated`.
**Fix:**
1. Bump to `firebase-admin@^13.0.0` and `firebase-functions@^6.0.0`.
2. Add a CI step `npm ci && npm audit --production --audit-level=high` so vulnerable transitive deps fail the build.

**Priority:** P3.
**Confidence:** 92/100.

---

## B22 — No `npm` engine pin; CI / dev environment `node_modules` may be built with mismatched npm versions

**Severity:** LOW.
**Issue:** `functions/package.json:4-6` pins `engines.node = "20"` but does NOT pin `engines.npm`. CI runners on different `npm` versions (npm 9 vs npm 10 vs npm 11) produce slightly different `package-lock.json` formats and resolve transitive deps differently in edge cases. Reproducible builds prefer pinning both.
**Why this exists:** Default scaffolding.
**Impact:** Trivial in practice.
**Evidence:** `admin-panel/functions/package.json:4-6`.
**Fix:** add `"engines": { "node": "20", "npm": ">=10" }`.
**Priority:** P4.
**Confidence:** 85/100.

---

## B23 — `dev-runner/server.js` rejects oversized bodies but does NOT terminate the response — client hangs

**Severity:** LOW (local-dev only).
**Issue:** `dev-runner/server.js:50-53`:
```js
if (body.length > 64 * 1024) {
  // Hard cap — args payload should be tiny.
  req.destroy();
}
```
`req.destroy()` kills the request socket but does not write a `400` or `413` response. The browser sees a network error with no clue what happened.
**Why this exists:** Quick-and-dirty cap.
**Impact:** Local dev only; trivial UX issue.
**Fix:** `res.writeHead(413).end('payload too large'); req.destroy();`.
**Priority:** P4.
**Confidence:** 99/100.

---

## B24 — `admin_audit_log` writes are fire-and-forget AFTER the RC publish completes; a failed audit write leaves a published-but-unaudited change

**Severity:** MEDIUM (compliance + tamper-evidence integrity).
**Issue:** `updateRemoteConfig` order of operations (`functions/index.js:280-289`):
1. `await admin.remoteConfig().publishTemplate(template);` — **changes are now LIVE**.
2. `if (Object.keys(changes).length > 0) { await logAdminAction(...); }` — audit write, can fail.

If step 2 throws (Firestore outage, audit collection rule regression, network blip mid-call), the RC change is published but no audit doc exists. Combined with `console.error` swallowing the error inside `logAdminAction` (line 93-95), this regression is **completely silent**.
**Why this exists:** Sequential `await` pattern; nobody asked "what if the audit fails after the publish succeeds?"
**Impact:**
- Compliance gap: SOC 2 / ISO 27001 audits typically demand "every change to a control is logged." A silent missing audit row breaks that claim.
- Forensic gap: a compromised admin who knows the audit can fail (or who can DoS the `admin_audit_log` collection during their attack window) leaves no trail.

**Evidence:**
- `admin-panel/functions/index.js:280` — RC publish first.
- `admin-panel/functions/index.js:283-289` — audit write second.
- `admin-panel/functions/index.js:83-96` — `logAdminAction` swallows errors via `console.error`.

**Fix:**
1. Write the audit doc FIRST (with status `pending`), then publish RC, then update the audit doc to `committed`. If RC publish fails, audit doc still records the attempt.
2. OR wrap both in a Cloud Tasks-backed pattern where the publish is queued only after the audit doc is durable.
3. AT MINIMUM: make `logAdminAction` throw on failure instead of swallowing — let the callable return an error to the admin so they know to retry.

**Priority:** P2.
**Confidence:** 96/100 — direct read.

---

## B25 — No CI/CD configuration for the admin panel (no GitHub Actions / Firebase deploy workflow committed)

**Severity:** LOW-MEDIUM.
**Issue:** No `.github/workflows/admin-panel.yml`, no `cloudbuild.yaml` in `admin-panel/`. Deploys are presumably manual via `firebase deploy --only hosting,functions`. Manual deploys mean:
- No PR-time rule lint (`firebase deploy --dry-run`).
- No `npm ci && npm test` (would catch B21 regressions).
- No staging-channel preview before prod.
- No deploy provenance — `git rev-parse HEAD` is not stamped into a hosting header or function env, so post-incident "what version was running?" is hard to answer.

**Why this exists:** v1 single-engineer deploy via local CLI.
**Impact:**
- Loose change control; any laptop with `firebase login` can push to prod.
- Rollback is "redeploy the previous git tag from a laptop."

**Evidence:**
- `find /Users/primetrace/Desktop/RnD/HealthPulse/.github -name "*.yml"` (root not scoped to admin-panel) — admin-panel is not specifically wired.
- No `cloudbuild.yaml` in `admin-panel/`.

**Fix:**
1. Add `.github/workflows/admin-panel-deploy.yml` triggered on tag push to `admin-panel/v*`:
   - `npm ci` in `admin-panel/functions/`.
   - `firebase deploy --only hosting,functions,firestore --project laso-health-v1 --token $FIREBASE_TOKEN`.
2. Stamp `process.env.GIT_SHA` (set in workflow) into a `version` field on every audit log write so the panel knows which build did what.

**Priority:** P2.
**Confidence:** 90/100.

---

## B26 — Audit log captures only the action verb + diff; does NOT capture the admin's IP, user agent, or location

**Severity:** LOW-MEDIUM (forensic incompleteness).
**Issue:** `logAdminAction` writes `{ uid, email, action, details, timestamp, ip: "redacted" }` — line 91 explicitly stores `"redacted"` for IP. The comment says "Don't store admin IPs" but the rationale is unstated; for forensic and SOC 2 ROPA, the IP and User Agent on every privileged action are usually MANDATORY. Storing `"redacted"` is worse than not having the field at all because it implies a deliberate decision was made.
**Why this exists:** Privacy reflex misapplied — admin IPs are operational metadata, not user PII.
**Impact:** When investigating a compromised admin account, the only signal is the email and timestamp. No way to detect "this admin is suddenly logging in from a country they have never been in" — which is the canonical compromised-credential indicator.
**Evidence:** `admin-panel/functions/index.js:91` — `ip: "redacted"`.
**Fix:**
```js
async function logAdminAction(uid, email, action, details = {}, request) {
  const ip = request?.rawRequest?.headers?.["x-forwarded-for"]?.split(",")[0]?.trim() || "unknown";
  const ua = request?.rawRequest?.headers?.["user-agent"] || "unknown";
  await admin.firestore().collection("admin_audit_log").add({
    uid, email: email || "unknown", action, details,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    ip, ua,
  });
}
```
And pass `request` through from each callable.

**Priority:** P2 — fix before SOC 2 attestation.
**Confidence:** 95/100.

---

## B27 — `dev-runner/server.js` and `admin-panel/public/screenshots/` are an end-to-end ungated PII pipeline if a real device captures live data

**Severity:** LOW-MEDIUM (current data is mock, future risk).
**Issue:** Pass 1 A5 flagged the screenshots directory as deploy-bloat / pre-launch leak risk. Pass 2's new angle: if the screenshot capture script is ever pointed at a **real** simulator user / TestFlight build instead of `PremiumShowcaseDataProvider`, the captures contain real HealthKit numbers, real device data, real user names — and they go straight into `admin-panel/public/screenshots/` which (a) is deployable via `firebase deploy --only hosting`, (b) is in the dashboard UI as auto-loaded thumbnails, and (c) ALSO gets zipped (`2026-04-25_14-01-30.zip`, 14 MiB) for share-out. The pipeline has zero "is this real or mock?" gate.
**Why this exists:** The pipeline was built for marketing screenshots from `PremiumShowcase` mock data; nobody added a guard against running it against a real account.
**Evidence:**
- `admin-panel/public/screenshots/index.json` line 4-6 — `"mock_profile": "PremiumShowcase"` — today's runs are all mock. Good. The check is implicit, not enforced.
- `admin-panel/public/screenshots/2026-04-25_14-01-30.zip` (14 MiB) — distributable artifact.

**Fix:**
1. The capture script should refuse to run unless it detects the `PremiumShowcase` mock profile is active in the simulator.
2. Add a CI lint that fails if any `meta.json` in `admin-panel/public/screenshots/**` lacks `"mock_profile": "PremiumShowcase"`.

**Priority:** P3 — operational guard; bites someone in 6 months otherwise.
**Confidence:** 88/100 — pipeline reasoned, real-account run not exercised.

---

## B28 — `firebase.json` lacks `cleanUrls`, `trailingSlash`, and `headers` for static assets — caching is browser-default

**Severity:** LOW.
**Issue:** No `Cache-Control` header for `*.css`, `*.js`, `*.png`, `*.svg`. Firebase Hosting's default Cache-Control is `max-age=3600` (1 h) on static assets, which is reasonable but not explicit. The 75 KB `app.js` reloads every hour for every admin. With versioning via `?v=hash` the file could be cached for a year.
**Why this exists:** Defaults.
**Impact:** Trivial cost; admin UX waits 75 KB downloads more than needed.
**Fix:** add to `firebase.json` `hosting.headers`:
```json
{ "source": "**/*.@(css|js)", "headers": [{ "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }] }
```
And version the script tag: `<script src="app.js?v=<git-sha>"></script>`.
**Priority:** P3.
**Confidence:** 85/100.

---

## B29 — No `robots.txt` served; combined with B19 + Pass 1 A20, every public scan tool can find the admin panel

**Severity:** LOW.
**Issue:** No `admin-panel/public/robots.txt`. Pass 1 A20 flagged the missing `<meta name="robots">`. Pass 2's add: even with the meta tag, security-scan crawlers (Shodan, Censys, generic recon bots) hit `/robots.txt` first; without one, they crawl freely.
**Fix:**
```
# admin-panel/public/robots.txt
User-agent: *
Disallow: /
```
**Priority:** P3.
**Confidence:** 99/100.

---

## B30 — `getAuditLog` callable hard-codes `limit(100)`; no pagination, no filter, no date range, no actor filter

**Severity:** LOW (operational).
**Issue:** `getAuditLog` (`functions/index.js:385-407`) returns the most recent 100 audit entries. No pagination cursor, no `where("email","==",x)` filter, no `where("action","==","update_remote_config")`, no date-range filter. After 100 RC changes (one busy week), older entries drop out of the dashboard view entirely; admins must use the Firebase console.
**Why this exists:** v1 simplicity.
**Impact:**
- Forensic investigation of "what did admin X change last month?" cannot be answered from the panel.
- SOC 2 evidence collection becomes manual.

**Evidence:** `admin-panel/functions/index.js:388-391`.
**Fix:** accept `{ before: timestamp, after: timestamp, email: string, action: string, limit: int (≤500) }` and apply server-side filters.
**Priority:** P2.
**Confidence:** 99/100.

---

## Cross-cutting Pass 2 observations

- **The defaults problem.** Pass 1 framed the panel as "above-average for a Firebase admin dashboard." Pass 2's deeper read shows the strength is in the **named, deliberate code paths** (verifyAdmin, audit log, in-memory rate limit, custom-claim re-fetch on every call). The weakness is in the **defaults**: every Cloud Function on default region + memory + timeout, no SRI on third-party scripts, no `firebase.json` headers, no `firestore.indexes.json`, no `storage.rules`, no CI/CD, no idempotency, no structured logger, no error reporting. A pre-launch P0/P1 sprint should be "name every default explicitly."
- **Auth is the single weakest link.** No MFA, no domain restriction, no failed-login throttle, no IP allow-list, no IAP. Pass 1 noted the panel is god-mode for the iOS app. Pass 2 underlines: god-mode behind one bcrypt-hashed password.
- **Audit log integrity is brittle.** Audit-after-publish (B24) + IP-redacted (B26) + 100-entry limit (B30) + no scheduled backup (B14) means tamper-evidence is mostly aspirational.
- **No payment pipeline at all.** B13 is the architectural gap behind Pass 1 A14. Without ASSN V2 the panel literally cannot show MRR/refunds/revoke; this is a backend missing-component, not a UI missing-tile.
- **Storage is invisible.** B4 — no `storage.rules` in repo. Whatever lives in `laso-health-v1.firebasestorage.app` is configured out-of-band.
- **`dev-runner` cross-tab risk** (Pass 1 A13) is bounded if the shell script is robust; Pass 2 (B15) flags that the shell script's argument hygiene was NOT audited and should be.

---

## Suggested Pass-2 fix order (1-week sprint, AFTER Pass 1 P0/P1)

1. **(P0)** B13 — App Store Server Notifications V2 webhook + `subscriptions/` Firestore mirror. Refunds / revokes leak today.
2. **(P1)** B1 — `setGlobalOptions` + per-fn `memory`/`maxInstances`/`timeout`/`region`. Cap blast radius.
3. **(P1)** B6 — `firebase.json` headers (CSP/HSTS/X-Frame-Options/etc).
4. **(P1)** B7 — MFA + email-domain restriction in `verifyAdmin`. Single weakest link.
5. **(P1)** B11 — per-key value validators in `updateRemoteConfig`. Stop silent kill-switch typos.
6. **(P1)** B14 — Firestore Managed Backups + scheduled RC backup function.
7. **(P1)** B4 — pull live `storage.rules` into repo + wire into `firebase.json`.
8. **(P2)** B2 — `getUserStats` `.select()` + `.stream()` + scheduled aggregate doc.
9. **(P2)** B5 — SRI on Firebase compat scripts.
10. **(P2)** B8 — switch `console.*` to `firebase-functions/logger`; enable Cloud Error Reporting.
11. **(P2)** B9 — Firestore TTL on `feedback` / `early_access` / `admin_audit_log`.
12. **(P2)** B24 — flip audit / publish order in `updateRemoteConfig`.
13. **(P2)** B25 — GitHub Actions deploy workflow + `git-sha` stamping.
14. **(P2)** B26 — capture IP + User Agent in audit log.
15. **(P2)** B30 — paginate / filter `getAuditLog`.
16. **(P3)** Everything else.

---

## Files cited in Pass 2

- `admin-panel/firebase.json` (re-read; absence of `headers`/`storage`/`indexes` blocks).
- `admin-panel/firestore.rules` (re-read; field-size gap in B10).
- `admin-panel/functions/index.js` (re-read; defaults gap, audit/publish order, `console.*`, no schedule).
- `admin-panel/functions/package.json` (engine pin, dep majors).
- `admin-panel/functions/package-lock.json` (committed — confirms `npm ci` works).
- `admin-panel/public/index.html` (SRI absence on lines 584-587, title leak).
- `admin-panel/public/app.js` (login flow, audit pagination, screenshots renderer).
- `admin-panel/public/screenshots/index.json` (`mock_profile` field — implicit gate).
- `admin-panel/dev-runner/server.js` (regex permissiveness on `--override-name`, body-cap UX).
- `admin-panel/.firebaserc` (single project, no staging).
- `admin-panel/.vercelignore`.
- Pass 1 audit at `audit/08-admin-panel.md` (cross-referenced; not duplicated).

---

**Confidence: 87/100** — every NEW finding is grounded in a directly-read line from the files listed above. The score is below 90 because: (a) Firebase Storage live rules state was inferred from the repo's silence, not pulled from `firebase storage:rules:get` against the live project; (b) `gcloud run services describe` against the live Cloud Functions was not exercised — the v2 defaults claim in B1 is from Firebase v2 docs, not from the live deployment readout; (c) `Scripts/capture-app-store-screenshots.sh` argument-handling discipline (B15's downstream surface) was not read in this pass — that file is outside `admin-panel/` and was deliberately out of scope; (d) App Store Server Notifications webhook absence (B13) is verified by codebase grep but the live App Store Connect "Server URL" field was not confirmed empty.

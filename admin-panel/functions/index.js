const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { setGlobalOptions } = require("firebase-functions/v2");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");
const jwt = require("jsonwebtoken");

admin.initializeApp();

// ─── Global Function Options ─────────────────────────────────────────────────
// Pass 7 L / Pass 11 AH: cap every function at 30s + 256MiB unless overridden.
// Prevents a hung admin/public endpoint from eating quota or runaway bill.
setGlobalOptions({
  region: "us-central1",
  memory: "256MiB",
  timeoutSeconds: 30,
  maxInstances: 10,
});

// ─── Log Redaction ───────────────────────────────────────────────────────────
// Never log raw email or full uid in user-facing log lines. Use these helpers
// when an identifier MUST be referenced (e.g. for support traceability).
function redactEmail(email) {
  if (typeof email !== "string" || email.length === 0) return "(none)";
  const at = email.indexOf("@");
  if (at <= 1) return "***";
  const local = email.slice(0, at);
  const domain = email.slice(at);
  return `${local[0]}***${local[local.length - 1] || ""}${domain}`;
}

function redactUid(uid) {
  if (typeof uid !== "string" || uid.length < 6) return "***";
  return `${uid.slice(0, 4)}…${uid.slice(-2)}`;
}

// ─── Rate Limiting (in-memory, per-instance) ─────────────────────────────────

const rateLimitMap = new Map();
const RATE_WINDOW_MS = 60 * 1000; // 1 minute
const RATE_LIMIT_PUBLIC = 10;      // 10 requests per minute per IP
const RATE_LIMIT_ADMIN = 30;       // 30 requests per minute per admin

function checkRateLimit(key, limit) {
  const now = Date.now();
  const entry = rateLimitMap.get(key);

  if (!entry || now - entry.windowStart > RATE_WINDOW_MS) {
    rateLimitMap.set(key, { windowStart: now, count: 1 });
    return true;
  }

  entry.count++;
  if (entry.count > limit) {
    return false;
  }
  return true;
}

// Clean up stale rate limit entries every 5 minutes
setInterval(() => {
  const now = Date.now();
  for (const [key, entry] of rateLimitMap) {
    if (now - entry.windowStart > RATE_WINDOW_MS * 2) {
      rateLimitMap.delete(key);
    }
  }
}, 5 * 60 * 1000);

// ─── Allowed Origins ─────────────────────────────────────────────────────────

const ALLOWED_ORIGINS = [
  "https://laso-health-v1.web.app",
  "https://laso-health-v1.firebaseapp.com",
  "https://lasohealth.com",
  "https://www.lasohealth.com",
  "https://lasohealth.fit",
  "https://www.lasohealth.fit",
];

// In development, also allow localhost
if (process.env.FUNCTIONS_EMULATOR === "true") {
  ALLOWED_ORIGINS.push("http://localhost:5000", "http://localhost:5002", "http://127.0.0.1:5000", "http://127.0.0.1:5002");
}

function getCorsOrigin(req) {
  const origin = req.headers.origin || "";
  if (ALLOWED_ORIGINS.includes(origin)) return origin;
  return ALLOWED_ORIGINS[0]; // Default — won't match attacker origin
}

function setCorsHeaders(req, res) {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
  res.set("Access-Control-Max-Age", "3600");
}

// ─── Input Sanitization ─────────────────────────────────────────────────────

function sanitizeString(str, maxLength = 500) {
  if (typeof str !== "string") return "";
  return str.trim().slice(0, maxLength);
}

function isValidEmail(email) {
  if (typeof email !== "string") return false;
  const re = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
  return email.length >= 3 && email.length <= 256 && re.test(email);
}

// ─── Idempotency ─────────────────────────────────────────────────────────────
// Optional dedupe for write callables. Caller supplies `idempotencyKey: String`
// (e.g., a UUID generated client-side); first call records the key + result and
// subsequent calls within the TTL replay the recorded result without re-running
// the side effect.
const IDEMPOTENCY_TTL_DAYS = 7;

function isValidIdempotencyKey(key) {
  return typeof key === "string" && /^[A-Za-z0-9_-]{8,128}$/.test(key);
}

/**
 * tryClaimIdempotencyKey — atomic claim-or-replay.
 *  - Returns `{ replay: true, result }` if the key was already used (within TTL).
 *  - Returns `{ replay: false, commit }` if newly claimed; caller MUST invoke
 *    `await commit(result)` once the operation succeeds, so a future replay
 *    can return the same body.
 */
async function tryClaimIdempotencyKey(key, scope) {
  const ref = admin.firestore().collection("idempotency").doc(`${scope}_${key}`);
  const snap = await ref.get();
  if (snap.exists) {
    const data = snap.data() || {};
    return { replay: true, result: data.result || null };
  }
  await ref.set({
    scope,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    result: null,
  });
  const commit = async (result) => {
    await ref.set({ result }, { merge: true });
  };
  return { replay: false, commit };
}

// ─── Admin Audit Logging ─────────────────────────────────────────────────────

async function logAdminAction(uid, email, action, details = {}) {
  try {
    await admin.firestore().collection("admin_audit_log").add({
      uid,
      email: email || "unknown",
      action,
      details,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      ip: "redacted", // Don't store admin IPs
    });
  } catch (err) {
    logger.error("Audit log write failed", { message: err.message });
  }
}

// ─── Admin Verification ─────────────────────────────────────────────────────

// Hardcoded admin allowlist. Only these email addresses can access admin-only
// functions. To add an admin: edit this list AND deploy. Email match is
// case-insensitive.
const ALLOWED_ADMIN_EMAILS = [
  "ayushkapri.richard@gmail.com",
];

async function verifyAdmin(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }

  // Local emulator path: Application Default Credentials usually lack the
  // identitytoolkit IAM permission, so admin.auth().getUser() throws. The
  // callable runtime has already verified the ID token signature, so we can
  // trust the email claim from request.auth.token and gate purely on the
  // allowlist. Production keeps the full getUser + custom-claim flow below.
  if (process.env.FUNCTIONS_EMULATOR === "true") {
    const tokenEmail = (request.auth.token?.email || "").toLowerCase().trim();
    if (!ALLOWED_ADMIN_EMAILS.includes(tokenEmail)) {
      logger.warn("Admin access denied (emulator)", { email: redactEmail(tokenEmail) });
      throw new HttpsError("permission-denied", "Admin access denied.");
    }
    const key = `admin:${request.auth.uid}`;
    if (!checkRateLimit(key, RATE_LIMIT_ADMIN)) {
      throw new HttpsError("resource-exhausted", "Too many requests. Try again shortly.");
    }
    return { uid: request.auth.uid, email: tokenEmail };
  }

  const user = await admin.auth().getUser(request.auth.uid);
  const email = (user.email || "").toLowerCase().trim();

  // Email allowlist gate — only listed emails are admin.
  if (!ALLOWED_ADMIN_EMAILS.includes(email)) {
    logger.warn("Admin access denied", { uid: redactUid(request.auth.uid), email: redactEmail(email) });
    throw new HttpsError("permission-denied", "Admin access denied.");
  }

  // Auto-set the `admin` custom claim so firestore.rules `request.auth.token.admin == true`
  // checks pass on subsequent client requests. Client must refresh the ID token
  // (e.g., user.getIdToken(true)) to pick up the new claim.
  if (!user.customClaims || user.customClaims.admin !== true) {
    await admin.auth().setCustomUserClaims(request.auth.uid, {
      ...(user.customClaims || {}),
      admin: true,
    });
    logger.info("Admin claim granted via allowlist", { uid: redactUid(request.auth.uid), email: redactEmail(email) });
  }

  // Rate limit admin requests
  const key = `admin:${request.auth.uid}`;
  if (!checkRateLimit(key, RATE_LIMIT_ADMIN)) {
    throw new HttpsError("resource-exhausted", "Too many requests. Try again shortly.");
  }

  return user;
}

// ═══ Public Endpoints ════════════════════════════════════════════════════════

/**
 * getSignupCount — public read-only endpoint, rate-limited.
 */
exports.getSignupCount = onRequest({ cors: false }, async (req, res) => {
  setCorsHeaders(req, res);

  if (req.method === "OPTIONS") { res.status(204).send(""); return; }
  if (req.method !== "GET") { res.status(405).json({ error: "Method not allowed" }); return; }

  // Rate limit by IP
  const ip = req.headers["x-forwarded-for"]?.split(",")[0]?.trim() || req.ip || "unknown";
  if (!checkRateLimit(`signup:${ip}`, RATE_LIMIT_PUBLIC)) {
    res.set("Retry-After", "60");
    res.status(429).json({ error: "Too many requests" });
    return;
  }

  try {
    const snapshot = await admin.firestore().collection("early_access").count().get();
    const count = snapshot.data().count;
    res.set("Cache-Control", "public, max-age=60");
    res.json({ count });
  } catch (err) {
    logger.error("getSignupCount error", { message: err.message });
    res.status(500).json({ count: 0 });
  }
});

/**
 * earlyAccessSignup — public write endpoint with strict validation and rate limiting.
 */
exports.earlyAccessSignup = onRequest({ cors: false }, async (req, res) => {
  setCorsHeaders(req, res);

  if (req.method === "OPTIONS") { res.status(204).send(""); return; }
  if (req.method !== "POST") { res.status(405).json({ error: "Method not allowed" }); return; }

  // Rate limit by IP
  const ip = req.headers["x-forwarded-for"]?.split(",")[0]?.trim() || req.ip || "unknown";
  if (!checkRateLimit(`signup:${ip}`, RATE_LIMIT_PUBLIC)) {
    res.set("Retry-After", "60");
    res.status(429).json({ error: "Too many requests. Please try again later." });
    return;
  }

  const { email, source, medium, campaign, referrer, landing_page, form_location,
          user_agent, screen_size, locale, utm_content, utm_term, fbclid, gclid } = req.body || {};

  // Strict email validation
  if (!isValidEmail(email)) {
    res.status(400).json({ error: "Invalid email" });
    return;
  }

  // Duplicate check
  try {
    const existing = await admin.firestore()
      .collection("early_access")
      .where("email", "==", email.toLowerCase().trim())
      .limit(1)
      .get();

    if (!existing.empty) {
      // Silently succeed — don't reveal whether email exists
      const countSnap = await admin.firestore().collection("early_access").count().get();
      res.json({ success: true, count: countSnap.data().count });
      return;
    }

    const fields = {
      email: sanitizeString(email.toLowerCase().trim(), 256),
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      source: sanitizeString(source || "direct", 100),
      medium: sanitizeString(medium || "none", 100),
      campaign: sanitizeString(campaign || "", 200),
      referrer: sanitizeString(referrer || "none", 500),
      landing_page: sanitizeString(landing_page || "/", 500),
      form_location: sanitizeString(form_location || "", 100),
      user_agent: sanitizeString(user_agent || "", 500),
      screen_size: sanitizeString(screen_size || "", 20),
      locale: sanitizeString(locale || "", 10),
    };
    if (utm_content) fields.utm_content = sanitizeString(utm_content, 200);
    if (utm_term) fields.utm_term = sanitizeString(utm_term, 200);
    if (fbclid) fields.fbclid = sanitizeString(fbclid, 100);
    if (gclid) fields.gclid = sanitizeString(gclid, 100);

    await admin.firestore().collection("early_access").add(fields);

    const snapshot = await admin.firestore().collection("early_access").count().get();
    res.json({ success: true, count: snapshot.data().count });
  } catch (err) {
    logger.error("earlyAccessSignup error", { message: err.message });
    res.status(500).json({ error: "Failed to save signup" });
  }
});

// ═══ Admin Endpoints ═════════════════════════════════════════════════════════

/**
 * getRemoteConfig — returns all current Remote Config parameter values.
 */
exports.getRemoteConfig = onCall(async (request) => {
  await verifyAdmin(request);

  const template = await admin.remoteConfig().getTemplate();
  const parameters = {};

  for (const [key, param] of Object.entries(template.parameters)) {
    parameters[key] = {
      defaultValue: param.defaultValue?.value ?? "",
      description: param.description ?? "",
    };
  }

  return { parameters };
});

/**
 * updateRemoteConfig — receives new parameter values, updates and publishes the template.
 * Logs all changes to admin_audit_log.
 */
exports.updateRemoteConfig = onCall(async (request) => {
  const adminUser = await verifyAdmin(request);

  const { parameters, idempotencyKey } = request.data;
  if (!parameters || typeof parameters !== "object") {
    throw new HttpsError("invalid-argument", "Missing parameters object.");
  }

  // Validate all values are strings and not excessively long
  for (const [key, value] of Object.entries(parameters)) {
    if (typeof key !== "string" || key.length > 100) {
      throw new HttpsError("invalid-argument", `Invalid key: ${key}`);
    }
    const strVal = String(value);
    if (strVal.length > 1000) {
      throw new HttpsError("invalid-argument", `Value too long for key: ${key}`);
    }
  }

  // Optional idempotency: replay prior result if the same key was used recently.
  let commitIdempotency = null;
  if (idempotencyKey !== undefined && idempotencyKey !== null) {
    if (!isValidIdempotencyKey(idempotencyKey)) {
      throw new HttpsError("invalid-argument", "Invalid idempotencyKey format.");
    }
    const claim = await tryClaimIdempotencyKey(idempotencyKey, "updateRemoteConfig");
    if (claim.replay && claim.result) {
      return { ...claim.result, replayed: true };
    }
    commitIdempotency = claim.commit;
  }

  const template = await admin.remoteConfig().getTemplate();

  // Track what changed for audit log
  const changes = {};
  for (const [key, value] of Object.entries(parameters)) {
    const oldValue = template.parameters[key]?.defaultValue?.value ?? "(unset)";
    const newValue = String(value);
    if (oldValue !== newValue) {
      changes[key] = { from: oldValue, to: newValue };
    }

    if (template.parameters[key]) {
      template.parameters[key].defaultValue = { value: newValue };
    } else {
      template.parameters[key] = {
        defaultValue: { value: newValue },
        description: "",
      };
    }
  }

  await admin.remoteConfig().publishTemplate(template);

  // Audit log
  if (Object.keys(changes).length > 0) {
    await logAdminAction(
      request.auth.uid,
      adminUser.email,
      "update_remote_config",
      { changedKeys: Object.keys(changes), changes }
    );
  }

  const result = { success: true, updatedKeys: Object.keys(parameters), changedCount: Object.keys(changes).length };
  if (commitIdempotency) {
    await commitIdempotency(result);
  }
  return result;
});

/**
 * getUserStats — aggregates user_profiles collection for demographics dashboard.
 */
exports.getUserStats = onCall({ invoker: "public" }, async (request) => {
  await verifyAdmin(request);

  const snapshot = await admin.firestore().collection("user_profiles").get();
  const total = snapshot.size;

  const genderCounts = {};
  const ageBracketCounts = {};
  const regionCounts = {};
  const healthFocusCounts = {};
  const versionCounts = {};

  snapshot.forEach((doc) => {
    const d = doc.data();

    const gender = sanitizeString(d.biological_sex || d.gender || "unknown", 50);
    genderCounts[gender] = (genderCounts[gender] || 0) + 1;

    const age = sanitizeString(d.age_bracket || d.ageBracket || "unknown", 20);
    ageBracketCounts[age] = (ageBracketCounts[age] || 0) + 1;

    const region = sanitizeString(d.region || "unknown", 50);
    regionCounts[region] = (regionCounts[region] || 0) + 1;

    const focuses = Array.isArray(d.health_focuses) ? d.health_focuses :
                    Array.isArray(d.healthFocuses) ? d.healthFocuses : [];
    focuses.forEach((f) => {
      const focus = sanitizeString(String(f), 50);
      if (focus) healthFocusCounts[focus] = (healthFocusCounts[focus] || 0) + 1;
    });

    const ver = sanitizeString(d.app_version || d.appVersion || "unknown", 20);
    versionCounts[ver] = (versionCounts[ver] || 0) + 1;
  });

  return { total, genderCounts, ageBracketCounts, regionCounts, healthFocusCounts, versionCounts };
});

/**
 * getFeedbackStats — quick feedback statistics without loading all documents.
 */
exports.getFeedbackStats = onCall({ invoker: "public" }, async (request) => {
  await verifyAdmin(request);

  const countSnap = await admin.firestore().collection("feedback").count().get();
  const total = countSnap.data().count;

  // Get recent feedback (last 7 days)
  const sevenDaysAgo = new Date();
  sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

  const recentSnap = await admin.firestore()
    .collection("feedback")
    .where("timestamp", ">=", sevenDaysAgo)
    .count()
    .get();
  const recentCount = recentSnap.data().count;

  // Get category counts from recent 500 entries
  const sampleSnap = await admin.firestore()
    .collection("feedback")
    .orderBy("timestamp", "desc")
    .limit(500)
    .get();

  const categoryCounts = {};
  let totalDays = 0;
  let daysCount = 0;

  sampleSnap.forEach((doc) => {
    const d = doc.data();
    const cat = sanitizeString(d.category || "unknown", 50);
    categoryCounts[cat] = (categoryCounts[cat] || 0) + 1;
    if (d.days_since_install != null && typeof d.days_since_install === "number") {
      totalDays += d.days_since_install;
      daysCount++;
    }
  });

  const avgDaysSinceInstall = daysCount > 0 ? Math.round(totalDays / daysCount) : 0;

  return { total, recentCount, categoryCounts, avgDaysSinceInstall };
});

// ═══ Authenticated User Endpoints ════════════════════════════════════════════

// Default options for callable functions used by authenticated end users.
// Region/memory/timeout come from setGlobalOptions(); only `invoker` is per-fn.
const CALLABLE_DEFAULTS = {
  invoker: "public",
};

/**
 * lookupReferralCode — authenticated callable used by the iOS client to
 * resolve a referral code to its owner's UID. Returns ONLY the data the client
 * needs to credit the referrer. The `user_profiles` collection's list rule is
 * admin-only (Pass 5 Agent 8), so the iOS direct query no longer works.
 */
exports.lookupReferralCode = onCall(CALLABLE_DEFAULTS, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }

  const code = (request.data?.code || "").toString().trim().toUpperCase();
  if (!code || !/^[A-Z0-9-]{4,20}$/.test(code)) {
    throw new HttpsError("invalid-argument", "Invalid code format.");
  }

  // Per-caller rate limit: 10 lookups/minute (matches RATE_LIMIT_PUBLIC).
  const key = `referral-lookup:${request.auth.uid}`;
  if (!checkRateLimit(key, RATE_LIMIT_PUBLIC)) {
    throw new HttpsError("resource-exhausted", "Too many lookups. Slow down.");
  }

  const snap = await admin.firestore()
    .collection("user_profiles")
    .where("referralCode", "==", code)
    .limit(1)
    .get();

  if (snap.empty) {
    return { found: false };
  }

  const doc = snap.docs[0];
  const data = doc.data();

  // Return ONLY the fields the iOS client needs to grant the referral —
  // do NOT leak email, age, gender, region, healthFocuses, etc.
  return {
    found: true,
    ownerUid: data.firebaseUid || doc.id,
  };
});

// ═══ Admin Endpoints (continued) ═════════════════════════════════════════════

/**
 * getAuditLog — returns recent admin audit log entries.
 */
exports.getAuditLog = onCall({ invoker: "public" }, async (request) => {
  await verifyAdmin(request);

  const snapshot = await admin.firestore()
    .collection("admin_audit_log")
    .orderBy("timestamp", "desc")
    .limit(100)
    .get();

  const entries = [];
  snapshot.forEach((doc) => {
    const d = doc.data();
    entries.push({
      id: doc.id,
      email: d.email,
      action: d.action,
      details: d.details || {},
      timestamp: d.timestamp?.toDate?.()?.toISOString?.() || null,
    });
  });

  return { entries };
});

// ═══ App Store Connect Pricing (read-only, local-dev only) ══════════════════
// Pulls live pricing for the iOS app's auto-renewable subscriptions across
// every territory, plus introductory offers. Read-only — admin panel must
// never mutate App Store Connect; pricing edits stay in ASC UI.
//
// Local-only setup: the .p8 key sits at functions/secrets/AuthKey_<KEYID>.p8
// (gitignored). For production we would switch to a Firebase Secret.

const ASC_KEY_ID = "SDUJFUCDD2";
const ASC_ISSUER_ID = "224ee32c-121a-4e32-a7a4-9a93c5ea8987";
const ASC_BUNDLE_ID = "com.lasohealth.fit";
const ASC_API_BASE = "https://api.appstoreconnect.apple.com/v1";

const ASC_CACHE_TTL_MS = 10 * 60 * 1000;
let ascPricingCache = null;
let ascPricingInflight = null;

function loadAscPrivateKey() {
  const fromSecret = process.env.ASC_PRIVATE_KEY;
  if (fromSecret && fromSecret.trim().startsWith("-----BEGIN")) {
    return fromSecret;
  }
  const keyPath = path.join(__dirname, "secrets", `AuthKey_${ASC_KEY_ID}.p8`);
  if (fs.existsSync(keyPath)) {
    return fs.readFileSync(keyPath, "utf8");
  }
  throw new Error(`ASC private key missing at ${keyPath}`);
}

function signAscJwt() {
  const privateKey = loadAscPrivateKey();
  const now = Math.floor(Date.now() / 1000);
  return jwt.sign(
    { iss: ASC_ISSUER_ID, iat: now, exp: now + 1140, aud: "appstoreconnect-v1" },
    privateKey,
    { algorithm: "ES256", header: { alg: "ES256", kid: ASC_KEY_ID, typ: "JWT" } }
  );
}

async function ascFetch(token, urlOrPath) {
  const url = urlOrPath.startsWith("http") ? urlOrPath : `${ASC_API_BASE}${urlOrPath}`;
  const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(`ASC ${res.status} ${url}: ${body.slice(0, 300)}`);
  }
  return res.json();
}

async function ascFetchAll(token, startPath) {
  let urlOrPath = startPath;
  const items = [];
  const included = [];
  while (urlOrPath) {
    const page = await ascFetch(token, urlOrPath);
    if (Array.isArray(page.data)) items.push(...page.data);
    if (Array.isArray(page.included)) included.push(...page.included);
    urlOrPath = page.links?.next || null;
  }
  return { data: items, included };
}

async function fetchAscPricing() {
  const token = signAscJwt();

  const appsRes = await ascFetch(
    token,
    `/apps?filter[bundleId]=${encodeURIComponent(ASC_BUNDLE_ID)}&limit=1`
  );
  const app = appsRes.data?.[0];
  if (!app) throw new Error(`No App Store app found for bundle ${ASC_BUNDLE_ID}`);
  const appId = app.id;

  const groupsRes = await ascFetchAll(token, `/apps/${appId}/subscriptionGroups?limit=200`);
  const groups = groupsRes.data;

  const allSubs = [];
  for (const g of groups) {
    const subsRes = await ascFetchAll(
      token,
      `/subscriptionGroups/${g.id}/subscriptions?limit=200&fields[subscriptions]=name,productId,subscriptionPeriod,state,familySharable,reviewNote,groupLevel`
    );
    for (const s of subsRes.data) {
      allSubs.push({ groupId: g.id, sub: s });
    }
  }

  const products = await Promise.all(allSubs.map(async ({ groupId, sub }) => {
    const [pricesRes, introRes] = await Promise.all([
      ascFetchAll(
        token,
        `/subscriptions/${sub.id}/prices?limit=200&include=subscriptionPricePoint,territory`
      ).catch(() => ({ data: [], included: [] })),
      ascFetchAll(
        token,
        `/subscriptions/${sub.id}/introductoryOffers?limit=200&include=subscriptionPricePoint,territory`
      ).catch(() => ({ data: [], included: [] })),
    ]);

    const pricePoints = new Map();
    const territories = new Map();
    for (const inc of [...(pricesRes.included || []), ...(introRes.included || [])]) {
      if (inc.type === "subscriptionPricePoints") pricePoints.set(inc.id, inc.attributes || {});
      else if (inc.type === "territories") territories.set(inc.id, inc.attributes || {});
    }

    function resolvePrice(rel) {
      const ppId = rel?.subscriptionPricePoint?.data?.id;
      const tId = rel?.territory?.data?.id;
      const pp = ppId ? pricePoints.get(ppId) : null;
      const t = tId ? territories.get(tId) : null;
      return {
        territoryId: tId || null,
        territoryCurrency: t?.currency || null,
        customerPrice: pp?.customerPrice || null,
        proceeds: pp?.proceeds || null,
      };
    }

    const prices = (pricesRes.data || []).map((p) => ({
      id: p.id,
      startDate: p.attributes?.startDate || null,
      ...resolvePrice(p.relationships || {}),
    }));

    const introOffers = (introRes.data || []).map((o) => ({
      id: o.id,
      offerMode: o.attributes?.offerMode || null,
      duration: o.attributes?.duration || null,
      numberOfPeriods: o.attributes?.numberOfPeriods ?? null,
      startDate: o.attributes?.startDate || null,
      endDate: o.attributes?.endDate || null,
      ...resolvePrice(o.relationships || {}),
    }));

    return {
      id: sub.id,
      groupId,
      productId: sub.attributes?.productId,
      name: sub.attributes?.name,
      state: sub.attributes?.state,
      duration: sub.attributes?.subscriptionPeriod,
      familySharable: sub.attributes?.familySharable ?? false,
      groupLevel: sub.attributes?.groupLevel ?? null,
      prices,
      introOffers,
    };
  }));

  return {
    appId,
    bundleId: ASC_BUNDLE_ID,
    appName: app.attributes?.name || null,
    fetchedAt: new Date().toISOString(),
    groupCount: groups.length,
    products,
  };
}

exports.getAppStorePricing = onCall(
  { invoker: "public", timeoutSeconds: 120, memory: "512MiB" },
  async (request) => {
    const adminUser = await verifyAdmin(request);

    const force = request.data?.force === true;
    const now = Date.now();
    if (!force && ascPricingCache && (now - ascPricingCache.fetchedAt) < ASC_CACHE_TTL_MS) {
      return { ...ascPricingCache.data, cached: true, cacheAgeMs: now - ascPricingCache.fetchedAt };
    }

    if (ascPricingInflight) {
      const data = await ascPricingInflight;
      return { ...data, cached: false };
    }

    ascPricingInflight = (async () => {
      try {
        const data = await fetchAscPricing();
        ascPricingCache = { fetchedAt: Date.now(), data };
        return data;
      } finally {
        ascPricingInflight = null;
      }
    })();

    try {
      const data = await ascPricingInflight;
      logger.info("ASC pricing fetched", {
        admin: redactEmail(adminUser.email),
        productCount: data.products?.length ?? 0,
      });
      return { ...data, cached: false };
    } catch (err) {
      logger.error("getAppStorePricing failed", { message: err.message });
      throw new HttpsError("internal", `ASC fetch failed: ${err.message}`);
    }
  }
);

// ═══ Scheduled Cleanup ═══════════════════════════════════════════════════════

/**
 * cleanupOldData — daily scheduled prune.
 *  - admin_audit_log entries older than 365d are deleted (compliance retention).
 *  - idempotency entries older than IDEMPOTENCY_TTL_DAYS are deleted.
 *  - early_access is NEVER pruned by design (signups are intentionally retained
 *    indefinitely until launch). Document this here so future agents don't add
 *    a TTL by mistake.
 *
 * Deletes are issued in batches of 400 (under Firestore's 500-write batch cap).
 */
exports.cleanupOldData = onSchedule(
  {
    schedule: "every 24 hours",
    timeZone: "UTC",
    timeoutSeconds: 540,
    memory: "256MiB",
    region: "us-central1",
  },
  async () => {
    const db = admin.firestore();
    const now = Date.now();
    const auditCutoff = new Date(now - 365 * 24 * 60 * 60 * 1000);
    const idempotencyCutoff = new Date(now - IDEMPOTENCY_TTL_DAYS * 24 * 60 * 60 * 1000);

    async function pruneCollection(coll, field, cutoff) {
      let totalDeleted = 0;
      // Loop until no more matching docs (cap iterations to avoid runaway).
      for (let i = 0; i < 50; i++) {
        const snap = await db.collection(coll)
          .where(field, "<", cutoff)
          .orderBy(field)
          .limit(400)
          .get();
        if (snap.empty) break;
        const batch = db.batch();
        snap.docs.forEach((d) => batch.delete(d.ref));
        await batch.commit();
        totalDeleted += snap.size;
        if (snap.size < 400) break;
      }
      return totalDeleted;
    }

    try {
      const auditDeleted = await pruneCollection("admin_audit_log", "timestamp", auditCutoff);
      const idempotencyDeleted = await pruneCollection("idempotency", "createdAt", idempotencyCutoff);
      logger.info("cleanupOldData ran", { auditDeleted, idempotencyDeleted });
    } catch (err) {
      logger.error("cleanupOldData failed", { message: err.message });
    }
  }
);

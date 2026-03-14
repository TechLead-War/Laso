const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

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
  res.set("Access-Control-Allow-Origin", getCorsOrigin(req));
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
    console.error("Audit log write failed:", err.message);
  }
}

// ─── Admin Verification ─────────────────────────────────────────────────────

async function verifyAdmin(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const user = await admin.auth().getUser(request.auth.uid);
  if (!user.customClaims || user.customClaims.admin !== true) {
    throw new HttpsError("permission-denied", "Requires admin privileges.");
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
    res.status(429).json({ error: "Too many requests" });
    return;
  }

  try {
    const snapshot = await admin.firestore().collection("early_access").count().get();
    const count = snapshot.data().count;
    res.set("Cache-Control", "public, max-age=60");
    res.json({ count });
  } catch (err) {
    console.error("getSignupCount error:", err);
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
    console.error("earlyAccessSignup error:", err);
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

  const { parameters } = request.data;
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

  return { success: true, updatedKeys: Object.keys(parameters), changedCount: Object.keys(changes).length };
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

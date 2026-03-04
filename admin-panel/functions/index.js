const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

// ── Public: Get early access signup count ──
exports.getSignupCount = onRequest({ cors: true }, async (req, res) => {
  try {
    const snapshot = await admin.firestore().collection("early_access").count().get();
    const count = snapshot.data().count;
    res.set("Cache-Control", "no-cache");
    res.json({ count });
  } catch (err) {
    console.error("getSignupCount error:", err);
    res.status(500).json({ count: 0 });
  }
});

// ── Public: Early access signup ──
exports.earlyAccessSignup = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  const { email, source, medium, campaign, referrer, landing_page, form_location,
          user_agent, screen_size, locale, utm_content, utm_term, fbclid, gclid } = req.body;

  if (!email || typeof email !== "string" || email.length === 0 || email.length > 256) {
    res.status(400).json({ error: "Invalid email" });
    return;
  }

  try {
    const fields = {
      email,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      source: source || "direct",
      medium: medium || "none",
      campaign: campaign || "",
      referrer: referrer || "none",
      landing_page: landing_page || "/",
      form_location: form_location || "",
      user_agent: user_agent || "",
      screen_size: screen_size || "",
      locale: locale || "",
    };
    if (utm_content) fields.utm_content = utm_content;
    if (utm_term) fields.utm_term = utm_term;
    if (fbclid) fields.fbclid = fbclid;
    if (gclid) fields.gclid = gclid;

    await admin.firestore().collection("early_access").add(fields);

    const snapshot = await admin.firestore().collection("early_access").count().get();
    const count = snapshot.data().count;

    res.json({ success: true, count });
  } catch (err) {
    console.error("earlyAccessSignup error:", err);
    res.status(500).json({ error: "Failed to save signup" });
  }
});

/**
 * Verify the caller has the admin custom claim.
 */
async function verifyAdmin(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const user = await admin.auth().getUser(request.auth.uid);
  if (!user.customClaims || user.customClaims.admin !== true) {
    throw new HttpsError("permission-denied", "Requires admin privileges.");
  }
}

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
 * Expects: { parameters: { key: value, ... } }
 */
exports.updateRemoteConfig = onCall(async (request) => {
  await verifyAdmin(request);

  const { parameters } = request.data;
  if (!parameters || typeof parameters !== "object") {
    throw new HttpsError("invalid-argument", "Missing parameters object.");
  }

  const template = await admin.remoteConfig().getTemplate();

  for (const [key, value] of Object.entries(parameters)) {
    if (template.parameters[key]) {
      template.parameters[key].defaultValue = { value: String(value) };
    } else {
      template.parameters[key] = {
        defaultValue: { value: String(value) },
        description: "",
      };
    }
  }

  await admin.remoteConfig().publishTemplate(template);

  return { success: true, updatedKeys: Object.keys(parameters) };
});

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

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

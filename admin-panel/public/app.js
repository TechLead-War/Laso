// ─── Firebase Config ─────────────────────────────────────────────────────────
// Replace with your Firebase project config from the Firebase Console.
const firebaseConfig = {
  apiKey: "YOUR_API_KEY",
  authDomain: "YOUR_PROJECT.firebaseapp.com",
  projectId: "YOUR_PROJECT_ID",
  storageBucket: "YOUR_PROJECT.appspot.com",
  messagingSenderId: "YOUR_SENDER_ID",
  appId: "YOUR_APP_ID",
};

firebase.initializeApp(firebaseConfig);
const auth = firebase.auth();
const functions = firebase.functions();

// ─── Config Schema ───────────────────────────────────────────────────────────
// Defines all 26 keys, their section, display name, input type, and tiers list.

const FEATURES = [
  { key: "feature_access_healthScore",       label: "Health Score" },
  { key: "feature_access_categoryScores",    label: "Category Scores" },
  { key: "feature_access_basicMetrics",      label: "Basic Metrics" },
  { key: "feature_access_allMetrics",        label: "All Metrics" },
  { key: "feature_access_sevenDayTrends",    label: "7-Day Trends" },
  { key: "feature_access_extendedHistory",   label: "Extended History" },
  { key: "feature_access_riskPredictions",   label: "Risk Predictions" },
  { key: "feature_access_focusAreas",        label: "Focus Areas" },
  { key: "feature_access_basicInsights",     label: "Basic Insights" },
  { key: "feature_access_allInsights",       label: "All Insights" },
  { key: "feature_access_liveTab",           label: "Live Vitals" },
  { key: "feature_access_exportReport",      label: "Export Reports" },
  { key: "feature_access_advancedAnalytics", label: "Advanced Analytics" },
];

const LIMITS = [
  { key: "free_metric_detail_limit", label: "Free Metric Detail Limit", type: "number" },
  { key: "free_metrics",             label: "Free Metrics (CSV)",       type: "text" },
  { key: "free_insight_limit",       label: "Free Insight Limit",       type: "number" },
  { key: "free_periods",             label: "Free Periods (CSV)",       type: "text" },
];

const PRICING = [
  { key: "pricing_pro_monthly_display_price", label: "Pro Monthly Display Price", type: "text" },
  { key: "pricing_pro_yearly_display_price",  label: "Pro Yearly Display Price",  type: "text" },
  { key: "pricing_pro_monthly_product_id",    label: "Pro Monthly Product ID",    type: "text" },
  { key: "pricing_pro_yearly_product_id",     label: "Pro Yearly Product ID",     type: "text" },
  { key: "pricing_pro_trial_days",            label: "Pro Trial Days",            type: "number" },
];

const SYSTEM = [
  { key: "feedback_prompt_after_sessions", label: "Feedback Prompt After Sessions", type: "number" },
  { key: "feedback_cooldown_days",         label: "Feedback Cooldown (Days)",       type: "number" },
  { key: "max_local_analytics_events",     label: "Max Local Analytics Events",    type: "number" },
  { key: "session_timeout_seconds",        label: "Session Timeout (Seconds)",     type: "number" },
];

const TIERS = ["free", "pro"];

// ─── DOM References ──────────────────────────────────────────────────────────

const loginScreen  = document.getElementById("login-screen");
const dashboard    = document.getElementById("dashboard");
const loginBtn     = document.getElementById("login-btn");
const loginEmail   = document.getElementById("login-email");
const loginPass    = document.getElementById("login-password");
const loginError   = document.getElementById("login-error");
const saveBtn      = document.getElementById("save-btn");
const logoutBtn    = document.getElementById("logout-btn");
const userEmailEl  = document.getElementById("user-email");
const toastEl      = document.getElementById("toast");
const loadingEl    = document.getElementById("loading");

// ─── Auth ────────────────────────────────────────────────────────────────────

loginBtn.addEventListener("click", async () => {
  loginError.textContent = "";
  try {
    await auth.signInWithEmailAndPassword(loginEmail.value.trim(), loginPass.value);
  } catch (err) {
    loginError.textContent = err.message;
  }
});

loginPass.addEventListener("keydown", (e) => {
  if (e.key === "Enter") loginBtn.click();
});

logoutBtn.addEventListener("click", () => auth.signOut());

auth.onAuthStateChanged(async (user) => {
  if (user) {
    loginScreen.style.display = "none";
    dashboard.style.display = "block";
    userEmailEl.textContent = user.email;
    await loadConfig();
  } else {
    loginScreen.style.display = "flex";
    dashboard.style.display = "none";
  }
});

// ─── Build UI ────────────────────────────────────────────────────────────────

function buildFeatureRows(container, features) {
  features.forEach(({ key, label }) => {
    const row = document.createElement("div");
    row.className = "feature-row";
    row.innerHTML = `
      <span class="feature-name">${label}</span>
      <div class="tier-checkboxes">
        ${TIERS.map(
          (t) =>
            `<label><input type="checkbox" data-key="${key}" data-tier="${t}" /> ${t}</label>`
        ).join("")}
      </div>
    `;
    container.appendChild(row);
  });
}

function buildInputRows(container, fields) {
  fields.forEach(({ key, label, type }) => {
    const row = document.createElement("div");
    row.className = "input-row";
    row.innerHTML = `
      <span class="input-label">${label}</span>
      <input type="${type}" data-key="${key}" />
    `;
    container.appendChild(row);
  });
}

// Build all sections on load
buildFeatureRows(document.getElementById("section-features"), FEATURES);
buildInputRows(document.getElementById("section-limits"), LIMITS);
buildInputRows(document.getElementById("section-pricing"), PRICING);
buildInputRows(document.getElementById("section-system"), SYSTEM);

// Enable save when any input changes
dashboard.addEventListener("input", () => {
  saveBtn.disabled = false;
});

// ─── Load Config ─────────────────────────────────────────────────────────────

async function loadConfig() {
  showLoading(true);
  try {
    const getConfig = functions.httpsCallable("getRemoteConfig");
    const result = await getConfig();
    const params = result.data.parameters;

    // Populate feature checkboxes
    FEATURES.forEach(({ key }) => {
      const value = params[key]?.defaultValue ?? "";
      const tiers = value.split(",").map((s) => s.trim());
      TIERS.forEach((t) => {
        const cb = document.querySelector(`input[data-key="${key}"][data-tier="${t}"]`);
        if (cb) cb.checked = tiers.includes(t);
      });
    });

    // Populate input fields
    [...LIMITS, ...PRICING, ...SYSTEM].forEach(({ key }) => {
      const input = document.querySelector(`input[data-key="${key}"]`);
      if (input && params[key]) {
        input.value = params[key].defaultValue ?? "";
      }
    });

    saveBtn.disabled = true;
    showToast("Config loaded");
  } catch (err) {
    showToast("Failed to load config: " + err.message, true);
  } finally {
    showLoading(false);
  }
}

// ─── Save Config ─────────────────────────────────────────────────────────────

saveBtn.addEventListener("click", async () => {
  showLoading(true);
  saveBtn.disabled = true;

  const parameters = {};

  // Collect feature access values
  FEATURES.forEach(({ key }) => {
    const checked = [];
    TIERS.forEach((t) => {
      const cb = document.querySelector(`input[data-key="${key}"][data-tier="${t}"]`);
      if (cb && cb.checked) checked.push(t);
    });
    parameters[key] = checked.join(",");
  });

  // Collect input values
  [...LIMITS, ...PRICING, ...SYSTEM].forEach(({ key }) => {
    const input = document.querySelector(`input[data-key="${key}"]`);
    if (input) parameters[key] = input.value;
  });

  try {
    const updateConfig = functions.httpsCallable("updateRemoteConfig");
    await updateConfig({ parameters });
    showToast("Published successfully");
  } catch (err) {
    showToast("Save failed: " + err.message, true);
    saveBtn.disabled = false;
  } finally {
    showLoading(false);
  }
});

// ─── Helpers ─────────────────────────────────────────────────────────────────

function showLoading(on) {
  loadingEl.classList.toggle("active", on);
}

let toastTimer;
function showToast(message, isError = false) {
  clearTimeout(toastTimer);
  toastEl.textContent = message;
  toastEl.className = "toast visible" + (isError ? " error" : "");
  toastTimer = setTimeout(() => {
    toastEl.className = "toast";
  }, 3000);
}

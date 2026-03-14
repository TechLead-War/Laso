// ═══════════════════════════════════════════════════════════════════════════════
// Laso Admin — Production App
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Firebase Config ─────────────────────────────────────────────────────────
const firebaseConfig = {
  apiKey: "AIzaSyDK3Xe2fVHxXg_UuKm0OBC6dVNbAmSn19o",
  authDomain: "laso-health-v1.firebaseapp.com",
  projectId: "laso-health-v1",
  storageBucket: "laso-health-v1.firebasestorage.app",
  messagingSenderId: "422856769623",
  appId: "1:422856769623:web:4f9f640ac757590204e312",
  measurementId: "G-JQYL4TRHLQ"
};

firebase.initializeApp(firebaseConfig);
const auth = firebase.auth();
const functions = firebase.functions();
const db = firebase.firestore();

// ─── Config Schema ───────────────────────────────────────────────────────────
// All keys match RemoteConfigManager.swift defaults.

const FEATURES = [
  { key: "feature_access_healthScore",            label: "Health Score" },
  { key: "feature_access_categoryScores",         label: "Category Scores" },
  { key: "feature_access_basicMetrics",           label: "Basic Metrics" },
  { key: "feature_access_allMetrics",             label: "All Metrics" },
  { key: "feature_access_sevenDayTrends",         label: "7-Day Trends" },
  { key: "feature_access_extendedHistory",        label: "Extended History" },
  { key: "feature_access_riskPredictions",        label: "Risk Predictions" },
  { key: "feature_access_focusAreas",             label: "Focus Areas" },
  { key: "feature_access_basicInsights",          label: "Basic Insights" },
  { key: "feature_access_allInsights",            label: "All Insights" },
  { key: "feature_access_liveTab",                label: "Live Vitals" },
  { key: "feature_access_exportReport",           label: "Export Reports" },
  { key: "feature_access_advancedAnalytics",      label: "Advanced Analytics" },
  { key: "feature_access_simulation",             label: "Simulation" },
  { key: "feature_access_clinicalIntelligence",   label: "Clinical Intelligence" },
  { key: "feature_access_ecgIntelligence",        label: "ECG Intelligence" },
  { key: "feature_access_nutritionCorrelations",  label: "Nutrition Correlations" },
  { key: "feature_access_circadianAnalysis",      label: "Circadian Analysis" },
  { key: "feature_access_adherenceTracking",      label: "Adherence Tracking" },
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

const ALERTS = [
  { key: "alert_cooldown_hours",       label: "Alert Cooldown (Hours)",          type: "number" },
  { key: "alert_hr_spike_multiplier",  label: "HR Spike Multiplier",            type: "number" },
  { key: "alert_hrv_drop_multiplier",  label: "HRV Drop Multiplier",            type: "number" },
  { key: "alert_spo2_critical",        label: "SpO2 Critical Threshold",        type: "number" },
  { key: "alert_spo2_warning",         label: "SpO2 Warning Threshold",         type: "number" },
  { key: "alert_rr_spike_multiplier",  label: "Resp Rate Spike Multiplier",     type: "number" },
  { key: "alert_heart_cap_per_day",    label: "Heart Alerts Cap / Day",         type: "number" },
];

const WATCH = [
  { key: "watch_monitor_check_seconds",       label: "Monitor Check Interval (s)",      type: "number" },
  { key: "watch_data_freshness_hours",         label: "Data Freshness Lookback (hrs)",   type: "number" },
  { key: "watch_not_worn_cooldown_hours",      label: "Not-Worn Cooldown (hrs)",         type: "number" },
  { key: "watch_not_worn_threshold_hours",     label: "Not-Worn Threshold (hrs)",        type: "number" },
  { key: "watch_battery_low_threshold",        label: "Battery Low Threshold (0-1)",     type: "number" },
];

const NOTIFICATIONS = [
  { key: "notification_daily_budget",          label: "Daily Notification Budget",       type: "number" },
  { key: "notification_fatigue_threshold",     label: "Fatigue Threshold (open rate)",   type: "number" },
  { key: "notification_min_priority_score",    label: "Min Priority Score",             type: "number" },
];

const ANALYSIS = [
  { key: "analysis_warning_deviation",         label: "Warning Deviation (%)",           type: "number" },
  { key: "analysis_critical_deviation",        label: "Critical Deviation (%)",          type: "number" },
  { key: "analysis_trend_slope_threshold",     label: "Trend Slope Threshold",          type: "number" },
];

const SYSTEM = [
  { key: "feedback_prompt_after_sessions",     label: "Feedback Prompt After Sessions",  type: "number" },
  { key: "feedback_cooldown_days",             label: "Feedback Cooldown (Days)",        type: "number" },
  { key: "feedback_days_before_first_prompt",  label: "Days Before First Prompt",        type: "number" },
  { key: "max_local_analytics_events",         label: "Max Local Analytics Events",      type: "number" },
  { key: "session_timeout_seconds",            label: "Session Timeout (Seconds)",       type: "number" },
  { key: "home_refresh_interval_seconds",      label: "Home Refresh Interval (s)",       type: "number" },
];

const RETENTION = [
  { key: "retention_daily_sample_days",        label: "Daily Samples (days)",            type: "number" },
  { key: "retention_analysis_snapshot_days",    label: "Analysis Snapshots (days)",       type: "number" },
  { key: "retention_daily_strain_days",        label: "Daily Strain (days)",             type: "number" },
  { key: "retention_recommendation_days",      label: "Recommendations (days)",          type: "number" },
  { key: "retention_notification_event_days",  label: "Notification Events (days)",      type: "number" },
  { key: "retention_adherence_record_days",    label: "Adherence Records (days)",        type: "number" },
  { key: "retention_ecg_features_days",        label: "ECG Features (days)",             type: "number" },
  { key: "retention_journal_entry_days",       label: "Journal Entries (days)",          type: "number" },
  { key: "retention_model_evaluation_days",    label: "Model Evaluations (days)",        type: "number" },
];

const KILL_SWITCHES = [
  { key: "kill_switch_enabled",   label: "Master Kill Switch (blocks entire app)",  type: "checkbox" },
  { key: "kill_switch_message",   label: "Maintenance Message",                     type: "text" },
  { key: "kill_live_tab",         label: "Kill Live Tab",                            type: "checkbox" },
  { key: "kill_ml_pipeline",      label: "Kill ML Pipeline",                         type: "checkbox" },
  { key: "kill_cloud_backup",     label: "Kill Cloud Backup",                        type: "checkbox" },
  { key: "kill_notifications",    label: "Kill Notifications (except critical)",     type: "checkbox" },
];

const FORCE_UPDATE = [
  { key: "minimum_app_version",   label: "Minimum App Version (e.g. 1.68)",         type: "text" },
];

const MONETIZATION = [
  { key: "free_year_active",      label: "Free Year Mode (bypass all paywalls)",     type: "checkbox" },
];

const TIERS = ["free", "pro"];

// ─── Defaults (mirrors RemoteConfigManager.swift) ────────────────────────────

const DEFAULTS = {
  "feature_access_healthScore":       "free,pro",
  "feature_access_categoryScores":    "free,pro",
  "feature_access_basicMetrics":      "free,pro",
  "feature_access_allMetrics":        "pro",
  "feature_access_sevenDayTrends":    "free,pro",
  "feature_access_extendedHistory":   "pro",
  "feature_access_riskPredictions":   "pro",
  "feature_access_focusAreas":        "pro",
  "feature_access_basicInsights":     "free,pro",
  "feature_access_allInsights":       "pro",
  "feature_access_liveTab":           "pro",
  "feature_access_exportReport":      "pro",
  "feature_access_advancedAnalytics": "pro",
  "feature_access_simulation":        "pro",
  "feature_access_clinicalIntelligence": "pro",
  "feature_access_ecgIntelligence":   "pro",
  "feature_access_nutritionCorrelations": "pro",
  "feature_access_circadianAnalysis": "pro",
  "feature_access_adherenceTracking": "pro",
  "free_metric_detail_limit":   "3",
  "free_metrics":               "heartRate,steps,sleepAnalysis",
  "free_insight_limit":         "2",
  "free_periods":               "7d,30d",
  "pricing_pro_monthly_display_price": "₹499",
  "pricing_pro_yearly_display_price":  "₹2,499",
  "pricing_pro_monthly_product_id":    "com.lasohealth.monthly",
  "pricing_pro_yearly_product_id":     "com.lasohealth.yearly",
  "pricing_pro_trial_days":            "7",
  "alert_cooldown_hours":       "4",
  "alert_hr_spike_multiplier":  "1.15",
  "alert_hrv_drop_multiplier":  "0.7",
  "alert_spo2_critical":        "92",
  "alert_spo2_warning":         "95",
  "alert_rr_spike_multiplier":  "1.25",
  "alert_heart_cap_per_day":    "3",
  "watch_monitor_check_seconds":   "900",
  "watch_data_freshness_hours":    "2",
  "watch_not_worn_cooldown_hours": "4",
  "watch_not_worn_threshold_hours":"1",
  "watch_battery_low_threshold":   "0.10",
  "notification_daily_budget":         "3",
  "notification_fatigue_threshold":    "0.15",
  "notification_min_priority_score":   "30",
  "analysis_warning_deviation":      "0.10",
  "analysis_critical_deviation":     "0.20",
  "analysis_trend_slope_threshold":  "0.02",
  "feedback_prompt_after_sessions":    "5",
  "feedback_cooldown_days":            "30",
  "feedback_days_before_first_prompt": "5",
  "max_local_analytics_events":        "500",
  "session_timeout_seconds":           "1800",
  "home_refresh_interval_seconds":     "60",
  "retention_daily_sample_days":       "730",
  "retention_analysis_snapshot_days":  "365",
  "retention_daily_strain_days":       "365",
  "retention_recommendation_days":     "90",
  "retention_notification_event_days": "90",
  "retention_adherence_record_days":   "90",
  "retention_ecg_features_days":       "730",
  "retention_journal_entry_days":      "365",
  "retention_model_evaluation_days":   "180",
  "kill_switch_enabled":   "false",
  "kill_switch_message":   "",
  "kill_live_tab":         "false",
  "kill_ml_pipeline":      "false",
  "kill_cloud_backup":     "false",
  "kill_notifications":    "false",
  "minimum_app_version":   "0.0",
  "free_year_active":      "true",
};

function getValue(params, key) {
  return params[key]?.defaultValue ?? DEFAULTS[key] ?? "";
}

// ═══════════════════════════════════════════════════════════════════════════════
// UI Module
// ═══════════════════════════════════════════════════════════════════════════════

const UI = (() => {
  const toastEl = document.getElementById("toast");
  const loadingEl = document.getElementById("loading");
  const modalOverlay = document.getElementById("modal-overlay");
  const modalTitle = document.getElementById("modal-title");
  const modalDesc = document.getElementById("modal-description");
  const modalCancel = document.getElementById("modal-cancel");
  const modalConfirm = document.getElementById("modal-confirm");
  const saveBar = document.getElementById("save-bar");

  let toastTimer;
  let modalCallback = null;

  function showToast(message, isError = false) {
    clearTimeout(toastTimer);
    toastEl.textContent = message;
    toastEl.className = "toast visible" + (isError ? " error" : "");
    toastTimer = setTimeout(() => { toastEl.className = "toast"; }, 3000);
  }

  function showLoading(on) {
    loadingEl.classList.toggle("active", on);
  }

  function showModal(title, description, onConfirm) {
    modalTitle.textContent = title;
    modalDesc.textContent = description;
    modalCallback = onConfirm;
    modalOverlay.classList.add("active");
  }

  function hideModal() {
    modalOverlay.classList.remove("active");
    modalCallback = null;
  }

  modalCancel.addEventListener("click", hideModal);
  modalConfirm.addEventListener("click", () => {
    if (modalCallback) modalCallback();
    hideModal();
  });

  // Close modal on overlay click
  modalOverlay.addEventListener("click", (e) => {
    if (e.target === modalOverlay) hideModal();
  });

  function showSaveBar() { saveBar.classList.add("visible"); }
  function hideSaveBar() { saveBar.classList.remove("visible"); }

  function escapeHtml(text) {
    const div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
  }

  return { showToast, showLoading, showModal, hideModal, showSaveBar, hideSaveBar, escapeHtml };
})();

// ═══════════════════════════════════════════════════════════════════════════════
// Router Module
// ═══════════════════════════════════════════════════════════════════════════════

const Router = (() => {
  const pages = {
    dashboard: document.getElementById("page-dashboard"),
    features: document.getElementById("page-features"),
    config: document.getElementById("page-config"),
    operations: document.getElementById("page-operations"),
    feedback: document.getElementById("page-feedback"),
    users: document.getElementById("page-users"),
    audit: document.getElementById("page-audit"),
  };

  const navItems = document.querySelectorAll(".nav-item");

  function navigate(hash) {
    const page = hash.replace("#", "") || "dashboard";
    if (!pages[page]) return;

    // Hide all pages
    Object.values(pages).forEach((p) => p.classList.remove("active"));
    navItems.forEach((n) => n.classList.remove("active"));

    // Show target
    pages[page].classList.add("active");
    const activeNav = document.querySelector(`.nav-item[data-page="${page}"]`);
    if (activeNav) activeNav.classList.add("active");

    // Trigger page-specific init
    if (page === "dashboard") DashboardPage.init();
  }

  function init() {
    window.addEventListener("hashchange", () => navigate(location.hash));
    navigate(location.hash || "#dashboard");
  }

  return { init, navigate };
})();

// ═══════════════════════════════════════════════════════════════════════════════
// Config Manager Module
// ═══════════════════════════════════════════════════════════════════════════════

const ConfigManager = (() => {
  let dirty = false;
  let serverParams = {};

  function markDirty() {
    if (!dirty) {
      dirty = true;
      UI.showSaveBar();
    }
  }

  function markClean() {
    dirty = false;
    UI.hideSaveBar();
  }

  function isDirty() { return dirty; }

  async function load() {
    UI.showLoading(true);
    try {
      const getConfig = functions.httpsCallable("getRemoteConfig");
      const result = await getConfig();
      serverParams = result.data.parameters || {};

      populateFeatures();
      populateInputSections();
      populateToggles();

      markClean();
      UI.showToast("Config loaded");
    } catch (err) {
      UI.showToast("Failed to load config: " + err.message, true);
    } finally {
      UI.showLoading(false);
    }
  }

  function populateFeatures() {
    FEATURES.forEach(({ key }) => {
      const value = getValue(serverParams, key);
      const tiers = value.split(",").map((s) => s.trim());
      TIERS.forEach((t) => {
        const cb = document.querySelector(`input[data-key="${key}"][data-tier="${t}"]`);
        if (cb) cb.checked = tiers.includes(t);
      });
    });
  }

  function populateInputSections() {
    const allInputFields = [...LIMITS, ...PRICING, ...ALERTS, ...WATCH, ...NOTIFICATIONS, ...ANALYSIS, ...SYSTEM, ...RETENTION, ...FORCE_UPDATE];
    allInputFields.forEach(({ key }) => {
      const input = document.querySelector(`input[data-key="${key}"]`);
      if (input) input.value = getValue(serverParams, key);
    });
  }

  function populateToggles() {
    [...KILL_SWITCHES, ...MONETIZATION].forEach(({ key, type }) => {
      if (type === "checkbox") {
        const cb = document.querySelector(`input[data-key="${key}"][data-toggle="true"]`);
        if (cb) cb.checked = getValue(serverParams, key) === "true";
      } else {
        const input = document.querySelector(`input[data-key="${key}"]`);
        if (input) input.value = getValue(serverParams, key);
      }
    });
  }

  function collectAll() {
    const parameters = {};

    // Feature access
    FEATURES.forEach(({ key }) => {
      const checked = [];
      TIERS.forEach((t) => {
        const cb = document.querySelector(`input[data-key="${key}"][data-tier="${t}"]`);
        if (cb && cb.checked) checked.push(t);
      });
      parameters[key] = checked.join(",");
    });

    // Input fields
    const allInputFields = [...LIMITS, ...PRICING, ...ALERTS, ...WATCH, ...NOTIFICATIONS, ...ANALYSIS, ...SYSTEM, ...RETENTION, ...FORCE_UPDATE];
    allInputFields.forEach(({ key }) => {
      const input = document.querySelector(`input[data-key="${key}"]`);
      if (input) parameters[key] = input.value;
    });

    // Toggles
    [...KILL_SWITCHES, ...MONETIZATION].forEach(({ key, type }) => {
      if (type === "checkbox") {
        const cb = document.querySelector(`input[data-key="${key}"][data-toggle="true"]`);
        if (cb) parameters[key] = cb.checked ? "true" : "false";
      } else {
        const input = document.querySelector(`input[data-key="${key}"]`);
        if (input) parameters[key] = input.value;
      }
    });

    return parameters;
  }

  async function save() {
    UI.showLoading(true);
    try {
      const parameters = collectAll();
      const updateConfig = functions.httpsCallable("updateRemoteConfig");
      await updateConfig({ parameters });
      markClean();
      UI.showToast("Published successfully");
    } catch (err) {
      UI.showToast("Save failed: " + err.message, true);
    } finally {
      UI.showLoading(false);
    }
  }

  function discard() {
    populateFeatures();
    populateInputSections();
    populateToggles();
    markClean();
    UI.showToast("Changes discarded");
  }

  function getParam(key) {
    return getValue(serverParams, key);
  }

  return { load, save, discard, markDirty, markClean, isDirty, getParam };
})();

// ═══════════════════════════════════════════════════════════════════════════════
// Build UI Rows
// ═══════════════════════════════════════════════════════════════════════════════

function buildFeatureRows(container, features) {
  features.forEach(({ key, label }) => {
    const row = document.createElement("div");
    row.className = "feature-row";
    row.innerHTML = `
      <span class="feature-name">${label}</span>
      <div class="tier-checkboxes">
        ${TIERS.map((t) => `<label><input type="checkbox" data-key="${key}" data-tier="${t}" /> ${t}</label>`).join("")}
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

function buildMixedRows(container, fields) {
  fields.forEach(({ key, label, type }) => {
    const row = document.createElement("div");
    if (type === "checkbox") {
      row.className = "feature-row";
      row.innerHTML = `
        <span class="feature-name">${label}</span>
        <label class="toggle-label">
          <input type="checkbox" data-key="${key}" data-toggle="true" />
          <span class="toggle-text">Enabled</span>
        </label>
      `;
    } else {
      row.className = "input-row";
      row.innerHTML = `
        <span class="input-label">${label}</span>
        <input type="${type}" data-key="${key}" />
      `;
    }
    container.appendChild(row);
  });
}

// Build all config sections
buildFeatureRows(document.getElementById("section-features"), FEATURES);
buildMixedRows(document.getElementById("section-monetization"), MONETIZATION);
buildInputRows(document.getElementById("section-limits"), LIMITS);
buildInputRows(document.getElementById("section-pricing"), PRICING);
buildInputRows(document.getElementById("section-alerts"), ALERTS);
buildInputRows(document.getElementById("section-watch"), WATCH);
buildInputRows(document.getElementById("section-notifications"), NOTIFICATIONS);
buildInputRows(document.getElementById("section-analysis"), ANALYSIS);
buildInputRows(document.getElementById("section-system"), SYSTEM);
buildInputRows(document.getElementById("section-retention"), RETENTION);
buildMixedRows(document.getElementById("section-kill-switches"), KILL_SWITCHES);
buildInputRows(document.getElementById("section-force-update"), FORCE_UPDATE);

// ═══════════════════════════════════════════════════════════════════════════════
// Dashboard Page Module
// ═══════════════════════════════════════════════════════════════════════════════

const DashboardPage = (() => {
  let loaded = false;

  async function init() {
    if (loaded) return;
    loaded = true;

    // Timestamp
    document.getElementById("dashboard-timestamp").textContent =
      new Date().toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric", year: "numeric" });

    // Load all sections in parallel
    loadFeedbackStats();
    loadUserStats();
    buildHealthIndicators();
    buildConfigSnapshot();
    loadRecentFeedback();
    loadRecentAudit();
  }

  // ── Stats ──

  async function loadFeedbackStats() {
    try {
      const result = await functions.httpsCallable("getFeedbackStats")();
      const data = result.data;
      document.getElementById("stat-recent-feedback").textContent = data.recentCount || 0;
      document.getElementById("stat-total-feedback").textContent = data.total || 0;
    } catch {
      document.getElementById("stat-recent-feedback").textContent = "--";
      document.getElementById("stat-total-feedback").textContent = "--";
    }
  }

  async function loadUserStats() {
    try {
      const result = await functions.httpsCallable("getUserStats")();
      document.getElementById("stat-total-users").textContent = result.data.total || 0;
    } catch {
      document.getElementById("stat-total-users").textContent = "--";
    }
  }

  // ── Health Indicators ──

  function buildHealthIndicators() {
    const container = document.getElementById("health-indicators");
    const banner = document.getElementById("dashboard-status-banner");
    const killCountEl = document.getElementById("stat-active-kills");

    const indicators = [
      { key: "kill_switch_enabled", label: "App Status", goodValue: "false", goodText: "Live", badText: "Killed", critical: true },
      { key: "kill_live_tab", label: "Live Tab", goodValue: "false", goodText: "Active", badText: "Killed" },
      { key: "kill_ml_pipeline", label: "ML Pipeline", goodValue: "false", goodText: "Running", badText: "Killed" },
      { key: "kill_cloud_backup", label: "Cloud Backup", goodValue: "false", goodText: "Active", badText: "Killed" },
      { key: "kill_notifications", label: "Notifications", goodValue: "false", goodText: "Active", badText: "Killed" },
      { key: "free_year_active", label: "Free Year Mode", isInfo: true, trueText: "Bypassing paywalls", falseText: "Off" },
    ];

    let killCount = 0;
    let hasCritical = false;

    container.innerHTML = indicators.map((ind) => {
      const val = ConfigManager.getParam(ind.key);
      let dotColor, statusText, statusClass;

      if (ind.isInfo) {
        const isOn = val === "true";
        dotColor = isOn ? "orange" : "green";
        statusText = isOn ? ind.trueText : ind.falseText;
        statusClass = isOn ? "" : "health-status-active";
      } else {
        const isGood = val === ind.goodValue;
        dotColor = isGood ? "green" : "red";
        statusText = isGood ? ind.goodText : ind.badText;
        statusClass = isGood ? "health-status-active" : "health-status-killed";
        if (!isGood) {
          killCount++;
          if (ind.critical) hasCritical = true;
        }
      }

      return `
        <div class="health-row">
          <div class="health-dot ${dotColor}"></div>
          <span class="health-label">${ind.label}</span>
          <span class="health-status ${statusClass}">${statusText}</span>
        </div>
      `;
    }).join("");

    // Update kill switch stat
    killCountEl.textContent = killCount;

    // Update status banner
    if (hasCritical) {
      banner.className = "status-banner status-critical";
      banner.querySelector(".status-banner-text").textContent = "App is killed — users cannot access the app";
    } else if (killCount > 0) {
      banner.className = "status-banner status-warn";
      banner.querySelector(".status-banner-text").textContent = `${killCount} kill switch${killCount > 1 ? "es" : ""} active`;
    } else {
      banner.className = "status-banner status-ok";
      banner.querySelector(".status-banner-text").textContent = "All systems operational";
    }

    // Refresh button
    document.getElementById("health-refresh-btn").addEventListener("click", () => {
      loaded = false;
      init();
    });
  }

  // ── Config Snapshot ──

  function buildConfigSnapshot() {
    const container = document.getElementById("dashboard-config-snapshot");
    const snapItems = [
      { label: "Free Year", key: "free_year_active", format: (v) => v === "true" ? "Active" : "Off" },
      { label: "Min App Version", key: "minimum_app_version" },
      { label: "Trial Days", key: "pricing_pro_trial_days", suffix: "d" },
      { label: "Monthly Price", key: "pricing_pro_monthly_display_price" },
      { label: "Yearly Price", key: "pricing_pro_yearly_display_price" },
      { label: "Free Insight Limit", key: "free_insight_limit" },
      { label: "Free Metric Limit", key: "free_metric_detail_limit" },
      { label: "Daily Notif Budget", key: "notification_daily_budget" },
      { label: "Alert Cooldown", key: "alert_cooldown_hours", suffix: "h" },
      { label: "Home Refresh", key: "home_refresh_interval_seconds", suffix: "s" },
    ];

    container.innerHTML = snapItems.map((item) => {
      const raw = ConfigManager.getParam(item.key);
      const val = item.format ? item.format(raw) : raw + (item.suffix || "");
      return `
        <div class="config-snap-row">
          <span class="config-snap-label">${item.label}</span>
          <span class="config-snap-value">${UI.escapeHtml(val)}</span>
        </div>
      `;
    }).join("");
  }

  // ── Recent Feedback ──

  async function loadRecentFeedback() {
    const container = document.getElementById("dashboard-recent-feedback");
    try {
      const snapshot = await db
        .collection("feedback")
        .orderBy("timestamp", "desc")
        .limit(5)
        .get();

      if (snapshot.empty) {
        container.innerHTML = '<div class="empty-state">No feedback yet</div>';
        return;
      }

      container.innerHTML = "";
      snapshot.forEach((doc) => {
        const e = doc.data();
        const ts = e.timestamp?.seconds || e.timestamp;
        const date = ts
          ? new Date(ts * 1000).toLocaleDateString("en-US", { month: "short", day: "numeric" })
          : "--";

        const div = document.createElement("div");
        div.className = "dash-feedback-item";
        div.innerHTML = `
          <div class="dash-feedback-header">
            <span class="feedback-category-badge">${e.category || "?"}</span>
            <span class="feedback-date">${date}</span>
            ${e.app_version ? `<span class="feedback-version">v${e.app_version}</span>` : ""}
          </div>
          <div class="dash-feedback-text">${UI.escapeHtml(e.text || "")}</div>
        `;
        container.appendChild(div);
      });
    } catch {
      container.innerHTML = '<div class="empty-state">Could not load feedback</div>';
    }
  }

  // ── Recent Audit ──

  async function loadRecentAudit() {
    const container = document.getElementById("dashboard-recent-audit");
    try {
      const result = await functions.httpsCallable("getAuditLog")();
      const entries = (result.data.entries || []).slice(0, 5);

      if (entries.length === 0) {
        container.innerHTML = '<div class="empty-state">No admin activity logged yet</div>';
        return;
      }

      container.innerHTML = entries.map((e) => {
        const time = e.timestamp
          ? timeAgo(new Date(e.timestamp))
          : "--";
        const changedCount = e.details?.changedKeys?.length || 0;
        const desc = changedCount > 0
          ? `changed ${changedCount} config key${changedCount > 1 ? "s" : ""}`
          : e.action.replace(/_/g, " ");

        return `
          <div class="dash-audit-item">
            <div class="dash-audit-dot"></div>
            <span class="dash-audit-text"><strong>${UI.escapeHtml(e.email?.split("@")[0] || "admin")}</strong> ${desc}</span>
            <span class="dash-audit-time">${time}</span>
          </div>
        `;
      }).join("");
    } catch {
      container.innerHTML = '<div class="empty-state">Could not load audit log</div>';
    }
  }

  function timeAgo(date) {
    const seconds = Math.floor((Date.now() - date.getTime()) / 1000);
    if (seconds < 60) return "just now";
    const minutes = Math.floor(seconds / 60);
    if (minutes < 60) return `${minutes}m ago`;
    const hours = Math.floor(minutes / 60);
    if (hours < 24) return `${hours}h ago`;
    const days = Math.floor(hours / 24);
    if (days < 7) return `${days}d ago`;
    return date.toLocaleDateString("en-US", { month: "short", day: "numeric" });
  }

  function reset() { loaded = false; }

  return { init, reset };
})();

// ═══════════════════════════════════════════════════════════════════════════════
// Feedback Page Module
// ═══════════════════════════════════════════════════════════════════════════════

const FeedbackPage = (() => {
  let allEntries = [];
  let filteredEntries = [];
  let currentPage = 1;
  const PAGE_SIZE = 50;

  const loadBtn = document.getElementById("load-feedback-btn");
  const exportBtn = document.getElementById("export-feedback-btn");
  const categoryFilter = document.getElementById("feedback-category-filter");
  const searchInput = document.getElementById("feedback-search");
  const sortSelect = document.getElementById("feedback-sort");
  const summaryEl = document.getElementById("feedback-summary");
  const countEl = document.getElementById("feedback-count");
  const listEl = document.getElementById("feedback-list");
  const paginationEl = document.getElementById("feedback-pagination");

  loadBtn.addEventListener("click", loadFeedback);
  exportBtn.addEventListener("click", exportCSV);
  categoryFilter.addEventListener("change", applyFilters);
  searchInput.addEventListener("input", debounce(applyFilters, 300));
  sortSelect.addEventListener("change", applyFilters);

  async function loadFeedback() {
    loadBtn.disabled = true;
    loadBtn.textContent = "Loading...";

    try {
      const snapshot = await db
        .collection("feedback")
        .orderBy("timestamp", "desc")
        .limit(500)
        .get();

      allEntries = [];
      snapshot.forEach((doc) => allEntries.push({ id: doc.id, ...doc.data() }));

      // Build category filter options
      const categories = [...new Set(allEntries.map((e) => e.category || "unknown"))].sort();
      categoryFilter.innerHTML = '<option value="">All Categories</option>' +
        categories.map((c) => `<option value="${c}">${c}</option>`).join("");

      // Build summary
      const categoryCounts = {};
      allEntries.forEach((e) => {
        const cat = e.category || "unknown";
        categoryCounts[cat] = (categoryCounts[cat] || 0) + 1;
      });

      summaryEl.innerHTML = Object.entries(categoryCounts)
        .sort((a, b) => b[1] - a[1])
        .map(([cat, count]) => `
          <div class="summary-pill">
            <span class="summary-label">${cat}</span>
            <span class="summary-count">${count}</span>
          </div>
        `).join("");

      exportBtn.disabled = false;
      applyFilters();
      UI.showToast(`Loaded ${allEntries.length} feedback entries`);
    } catch (err) {
      UI.showToast("Failed to load feedback: " + err.message, true);
    } finally {
      loadBtn.disabled = false;
      loadBtn.textContent = "Load Feedback";
    }
  }

  function applyFilters() {
    const category = categoryFilter.value;
    const search = searchInput.value.toLowerCase().trim();
    const sort = sortSelect.value;

    filteredEntries = allEntries.filter((e) => {
      if (category && (e.category || "unknown") !== category) return false;
      if (search && !(e.text || "").toLowerCase().includes(search)) return false;
      return true;
    });

    // Sort
    filteredEntries.sort((a, b) => {
      switch (sort) {
        case "oldest":
          return (getTimestamp(a) || 0) - (getTimestamp(b) || 0);
        case "days-asc":
          return (a.days_since_install || 0) - (b.days_since_install || 0);
        case "days-desc":
          return (b.days_since_install || 0) - (a.days_since_install || 0);
        default: // newest
          return (getTimestamp(b) || 0) - (getTimestamp(a) || 0);
      }
    });

    currentPage = 1;
    renderList();
  }

  function getTimestamp(entry) {
    if (!entry.timestamp) return 0;
    return entry.timestamp.seconds || entry.timestamp;
  }

  function renderList() {
    const total = filteredEntries.length;
    const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));
    const start = (currentPage - 1) * PAGE_SIZE;
    const pageEntries = filteredEntries.slice(start, start + PAGE_SIZE);

    countEl.textContent = `${total} entries${total !== allEntries.length ? ` (filtered from ${allEntries.length})` : ""}`;

    listEl.innerHTML = pageEntries.map((e) => {
      const ts = getTimestamp(e);
      const date = ts
        ? new Date(ts * 1000).toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" })
        : "--";
      return `
        <div class="feedback-entry">
          <div class="feedback-entry-meta">
            <span class="feedback-category-badge">${e.category || "?"}</span>
            <span class="feedback-date">${date}</span>
            ${e.days_since_install != null ? `<span class="feedback-days">Day ${e.days_since_install}</span>` : ""}
            ${e.app_version ? `<span class="feedback-version">v${e.app_version}</span>` : ""}
          </div>
          <div class="feedback-text">${UI.escapeHtml(e.text || "")}</div>
        </div>
      `;
    }).join("");

    // Pagination
    if (totalPages <= 1) {
      paginationEl.innerHTML = "";
      return;
    }

    let paginationHtml = `<button ${currentPage === 1 ? "disabled" : ""} data-page="${currentPage - 1}">Prev</button>`;
    for (let i = 1; i <= totalPages; i++) {
      if (totalPages > 7 && i > 2 && i < totalPages - 1 && Math.abs(i - currentPage) > 1) {
        if (i === 3 || i === totalPages - 2) paginationHtml += `<button disabled>...</button>`;
        continue;
      }
      paginationHtml += `<button class="${i === currentPage ? "active" : ""}" data-page="${i}">${i}</button>`;
    }
    paginationHtml += `<button ${currentPage === totalPages ? "disabled" : ""} data-page="${currentPage + 1}">Next</button>`;

    paginationEl.innerHTML = paginationHtml;
    paginationEl.querySelectorAll("button[data-page]").forEach((btn) => {
      btn.addEventListener("click", () => {
        const p = parseInt(btn.dataset.page);
        if (p >= 1 && p <= totalPages) {
          currentPage = p;
          renderList();
          listEl.scrollIntoView({ behavior: "smooth", block: "start" });
        }
      });
    });
  }

  function exportCSV() {
    if (filteredEntries.length === 0) return;

    const headers = ["Date", "Category", "Text", "Days Since Install", "App Version"];
    const rows = filteredEntries.map((e) => {
      const ts = getTimestamp(e);
      const date = ts ? new Date(ts * 1000).toISOString() : "";
      return [
        date,
        e.category || "",
        `"${(e.text || "").replace(/"/g, '""')}"`,
        e.days_since_install ?? "",
        e.app_version || "",
      ].join(",");
    });

    const csv = [headers.join(","), ...rows].join("\n");
    const blob = new Blob([csv], { type: "text/csv" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `feedback-export-${new Date().toISOString().slice(0, 10)}.csv`;
    a.click();
    URL.revokeObjectURL(url);
    UI.showToast(`Exported ${filteredEntries.length} entries`);
  }

  function debounce(fn, ms) {
    let t;
    return (...args) => { clearTimeout(t); t = setTimeout(() => fn(...args), ms); };
  }

  return { loadFeedback };
})();

// ═══════════════════════════════════════════════════════════════════════════════
// Users Page Module
// ═══════════════════════════════════════════════════════════════════════════════

const UsersPage = (() => {
  const loadBtn = document.getElementById("load-users-btn");
  loadBtn.addEventListener("click", loadUsers);

  async function loadUsers() {
    loadBtn.disabled = true;
    loadBtn.textContent = "Loading...";
    UI.showLoading(true);

    try {
      const getUserStats = functions.httpsCallable("getUserStats");
      const result = await getUserStats();
      const data = result.data;

      // Stats cards
      document.getElementById("user-stat-total").textContent = data.total || 0;

      const topGender = getTopKey(data.genderCounts);
      document.getElementById("user-stat-gender").textContent = topGender ? capitalize(topGender) : "--";

      const topAge = getTopKey(data.ageBracketCounts);
      document.getElementById("user-stat-age").textContent = topAge || "--";

      const topRegion = getTopKey(data.regionCounts);
      document.getElementById("user-stat-region").textContent = topRegion || "--";

      // Charts
      renderBarChart("chart-gender", data.genderCounts, "Gender");
      renderBarChart("chart-age", data.ageBracketCounts, "Age Bracket");
      renderBarChart("chart-region", data.regionCounts, "Region", 10);
      renderBarChart("chart-focus", data.healthFocusCounts, "Focus Area");
      renderBarChart("chart-version", data.versionCounts, "Version", 15);

      UI.showToast("User data loaded");
    } catch (err) {
      UI.showToast("Failed to load user data: " + err.message, true);
    } finally {
      loadBtn.disabled = false;
      loadBtn.textContent = "Load User Data";
      UI.showLoading(false);
    }
  }

  function getTopKey(obj) {
    if (!obj) return null;
    const entries = Object.entries(obj);
    if (entries.length === 0) return null;
    entries.sort((a, b) => b[1] - a[1]);
    return entries[0][0];
  }

  function capitalize(s) {
    return s.charAt(0).toUpperCase() + s.slice(1);
  }

  function renderBarChart(containerId, data, label, limit) {
    const container = document.getElementById(containerId);
    if (!data || Object.keys(data).length === 0) {
      container.innerHTML = '<div class="empty-state">No data available</div>';
      return;
    }

    let entries = Object.entries(data).sort((a, b) => b[1] - a[1]);
    if (limit) entries = entries.slice(0, limit);

    const maxVal = Math.max(...entries.map(([, v]) => v));

    container.innerHTML = `
      <div class="bar-chart">
        ${entries.map(([key, val]) => {
          const pct = maxVal > 0 ? (val / maxVal) * 100 : 0;
          return `
            <div class="bar-row">
              <span class="bar-label" title="${UI.escapeHtml(key)}">${UI.escapeHtml(key)}</span>
              <div class="bar-track">
                <div class="bar-fill" style="width: ${pct}%"></div>
              </div>
              <span class="bar-value">${val}</span>
            </div>
          `;
        }).join("")}
      </div>
    `;
  }

  return { loadUsers };
})();

// ═══════════════════════════════════════════════════════════════════════════════
// Operations Page — Confirmation for dangerous toggles
// ═══════════════════════════════════════════════════════════════════════════════

const OperationsPage = (() => {
  // Watch for dangerous toggle changes
  const killSection = document.getElementById("section-kill-switches");

  killSection.addEventListener("change", (e) => {
    const cb = e.target;
    if (cb.type !== "checkbox" || !cb.dataset.toggle) return;

    const key = cb.dataset.key;
    if (cb.checked) {
      // Show confirmation
      const label = KILL_SWITCHES.find((k) => k.key === key)?.label || key;
      cb.checked = false; // Revert until confirmed

      UI.showModal(
        "Enable Kill Switch",
        `Are you sure you want to enable "${label}"? This affects all users immediately.`,
        () => {
          cb.checked = true;
          ConfigManager.markDirty();
        }
      );
    } else {
      ConfigManager.markDirty();
    }
  });

  return {};
})();

// ═══════════════════════════════════════════════════════════════════════════════
// Collapsible Cards
// ═══════════════════════════════════════════════════════════════════════════════

document.querySelectorAll(".collapsible .card-header").forEach((header) => {
  header.addEventListener("click", () => {
    header.closest(".card").classList.toggle("collapsed");
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// Auth Module
// ═══════════════════════════════════════════════════════════════════════════════

const Auth = (() => {
  const loginScreen = document.getElementById("login-screen");
  const appShell = document.getElementById("app-shell");
  const loginBtn = document.getElementById("login-btn");
  const loginEmail = document.getElementById("login-email");
  const loginPass = document.getElementById("login-password");
  const loginError = document.getElementById("login-error");
  const logoutBtn = document.getElementById("logout-btn");
  const sidebarEmail = document.getElementById("sidebar-email");

  // Session timeout: auto-logout after 30 minutes of inactivity
  const SESSION_TIMEOUT_MS = 30 * 60 * 1000;
  let inactivityTimer = null;

  function resetInactivityTimer() {
    clearTimeout(inactivityTimer);
    inactivityTimer = setTimeout(() => {
      if (auth.currentUser) {
        auth.signOut();
        UI.showToast("Session expired due to inactivity", true);
      }
    }, SESSION_TIMEOUT_MS);
  }

  // Reset timer on any user interaction
  ["mousemove", "mousedown", "keydown", "scroll", "touchstart"].forEach((event) => {
    document.addEventListener(event, resetInactivityTimer, { passive: true });
  });

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
      appShell.style.display = "flex";
      sidebarEmail.textContent = user.email;
      resetInactivityTimer();
      await ConfigManager.load();
      Router.init();
    } else {
      loginScreen.style.display = "flex";
      appShell.style.display = "none";
      clearTimeout(inactivityTimer);
      DashboardPage.reset();
    }
  });

  return {};
})();

// ═══════════════════════════════════════════════════════════════════════════════
// Save / Discard / Dirty Tracking
// ═══════════════════════════════════════════════════════════════════════════════

// Mark dirty on any config input change (features, config, operations pages)
["page-features", "page-config", "page-operations"].forEach((pageId) => {
  document.getElementById(pageId).addEventListener("input", (e) => {
    // Skip if it was handled by OperationsPage confirmation
    if (e.target.closest("#section-kill-switches") && e.target.type === "checkbox") return;
    ConfigManager.markDirty();
  });
});

document.getElementById("save-btn").addEventListener("click", () => ConfigManager.save());
document.getElementById("discard-btn").addEventListener("click", () => ConfigManager.discard());

// ═══════════════════════════════════════════════════════════════════════════════
// Audit Log Page Module
// ═══════════════════════════════════════════════════════════════════════════════

const AuditPage = (() => {
  const loadBtn = document.getElementById("load-audit-btn");
  const listEl = document.getElementById("audit-list");

  loadBtn.addEventListener("click", loadAuditLog);

  async function loadAuditLog() {
    loadBtn.disabled = true;
    loadBtn.textContent = "Loading...";
    UI.showLoading(true);

    try {
      const getAuditLog = functions.httpsCallable("getAuditLog");
      const result = await getAuditLog();
      const entries = result.data.entries || [];

      if (entries.length === 0) {
        listEl.innerHTML = '<div class="empty-state">No audit log entries yet</div>';
        UI.showToast("No audit entries found");
        return;
      }

      listEl.innerHTML = entries.map((e) => {
        const time = e.timestamp
          ? new Date(e.timestamp).toLocaleString("en-US", {
              month: "short", day: "numeric", year: "numeric",
              hour: "2-digit", minute: "2-digit"
            })
          : "--";

        let changesHtml = "";
        if (e.details?.changes) {
          const changes = Object.entries(e.details.changes);
          if (changes.length > 0) {
            changesHtml = `<div class="audit-changes">${
              changes.slice(0, 20).map(([key, { from, to }]) =>
                `<div class="audit-change-item">
                  <span class="audit-key">${UI.escapeHtml(key)}</span>
                  <span class="audit-old">${UI.escapeHtml(String(from))}</span>
                  &rarr;
                  <span class="audit-new">${UI.escapeHtml(String(to))}</span>
                </div>`
              ).join("")
            }${changes.length > 20 ? `<div>...and ${changes.length - 20} more</div>` : ""}</div>`;
          }
        }

        return `
          <div class="audit-entry">
            <div class="audit-entry-header">
              <span class="audit-action-badge">${UI.escapeHtml(e.action || "unknown")}</span>
              <span class="audit-email">${UI.escapeHtml(e.email || "unknown")}</span>
              <span class="audit-time">${time}</span>
            </div>
            ${changesHtml}
          </div>
        `;
      }).join("");

      UI.showToast(`Loaded ${entries.length} audit entries`);
    } catch (err) {
      UI.showToast("Failed to load audit log: " + err.message, true);
    } finally {
      loadBtn.disabled = false;
      loadBtn.textContent = "Load Audit Log";
      UI.showLoading(false);
    }
  }

  return { loadAuditLog };
})();

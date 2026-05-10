# Remote Config Template

Operator reference for every Firebase Remote Config parameter the HealthPulse iOS app reads. Engineer-facing source of truth lives in `RemoteConfigSchema.swift` (new keys) and `RemoteConfigManager.swift` (legacy keys). This file MUST stay in sync with both — changes here without a code update will be ignored, changes in code without an entry here will fall back to in-binary defaults forever.

## How to upload

1. Open Firebase Console → Remote Config (project: HealthPulse).
2. For each section below, create / update parameters one-by-one or paste the JSON block at the bottom of the section into the Firebase REST API:
   ```bash
   curl -X PUT \
     -H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
     -H "Content-Type: application/json" \
     -H "If-Match: *" \
     "https://firebaseremoteconfig.googleapis.com/v1/projects/$PROJECT_ID/remoteConfig" \
     -d @template.json
   ```
3. Publish the new template version. Real-time listeners pick it up within seconds; non-listening clients pick up on the next 1-hour fetch (production min interval, set in `RemoteConfigManager.init`).

## Hard limits to respect

- 3000 parameters per project. Current count ≈ 210. Plenty of room.
- 2000 conditions per project.
- Total parameter value strings ≤ 1,000,000 characters per project.
- Parameter key length ≤ 256 characters.
- Don't put secrets here — values are not encrypted.
- Don't try to A/B revenue events here — Firebase Analytics misses background subscription events. Use PostHog (already wired) for paywall conversion measurement.

## Cold start behaviour

- App reads cached values from disk synchronously (instant).
- First install with no cache uses bundled defaults (production-quality — Firebase had a 5.5-hour outage on 2024-10-31, so defaults must run the app correctly).
- Background fetch runs async; new values activate next launch.
- Never reduce min fetch interval below 1 hour in production — `FirebaseRemoteConfigFetchThrottledException` will crash users.

---

## 1. Kill switches (granular per-module)

Boolean flags. Default OFF; flip ON in Firebase Console for live incidents. Keep them granular so a bad ML model does not require disabling the whole app via the master `kill_switch_enabled` flag.

| Key | Default | Consumer | Why flip |
|---|---|---|---|
| `kill_readiness_scorer` | `false` | `ReadinessScorer.assess()` | Readiness ML produces bad outputs |
| `kill_home_live_readiness_refresh` | `false` | `HomeView.startReadinessRefresh()` | Watch sync thrashes battery |
| `kill_anomaly_alerts` | `false` | `AlertEvaluator.evaluate()` | False-positive alert flood |
| `ai_narrative_enabled` | `true` | `DailyNarrativeCard.loadNarrative()` | iOS 26 LLM regression — flip OFF to silence |
| `onboarding_force_skip_to_paywall` | `false` | `OnboardingV2View` | Mid-flow screen crash; jump to paywall |

---

## 2. Scoring — HealthScorer

Heuristic deduction ladders, adaptive weight factors, freshness curves. Tuned roughly every 2-4 weeks during model iteration. Centralising in RC removes the build-review-release cycle for each tuning round.

Consumer: `Core/Analysis/Config/HealthScorerConfig.swift` → `Core/Analysis/HealthScorer.swift`.

| Key | Type | Default | Notes |
|---|---|---|---|
| `scoring_health_critical_deduction_cap` | Int | 50 | Max points removed for a critical anomaly |
| `scoring_health_critical_deduction_per_z` | Double | 12.0 | Points per |z| of critical anomaly |
| `scoring_health_warning_deduction_cap` | Int | 25 | Max points removed for a warning anomaly |
| `scoring_health_warning_deduction_per_z` | Double | 8.0 | Points per |z| of warning anomaly |
| `scoring_health_declining_deduction_cap` | Int | 30 | Max points for a declining trend |
| `scoring_health_declining_deduction_per_percent` | Double | 1.3 | Points per % decline |
| `scoring_health_declining_deduction_offset` | Double | 2.0 | % decline before any deduction kicks in |
| `scoring_health_improving_bonus_cap` | Int | 8 | Max points added for an improving trend |
| `scoring_health_improving_bonus_per_percent` | Double | 0.6 | Points per % improvement |
| `scoring_health_improving_bonus_offset` | Double | 2.0 | % improvement before bonus kicks in |
| `scoring_health_volatility_factor_base` | Double | 0.5 | Base for category volatility weighting |
| `scoring_health_volatility_factor_slope` | Double | 5.0 | Slope multiplier for CV → weight |
| `scoring_health_volatility_factor_cap` | Double | 2.0 | Max volatility factor |
| `scoring_health_richness_factor_base` | Double | 0.3 | Base for category coverage weighting |
| `scoring_health_richness_factor_range` | Double | 0.7 | Range above base |
| `scoring_health_anomaly_factor_base` | Double | 0.5 | Base for anomaly density weighting |
| `scoring_health_anomaly_factor_slope` | Double | 1.5 | Density → weight slope |
| `scoring_health_focus_boost` | Double | 1.2 | Multiplier for user-selected focus categories |
| `scoring_health_category_weight_floor` | Double | 0.05 | Per-category floor after normalisation |
| `scoring_health_no_baseline_weight` | Double | 0.1 | Weight for metrics without baseline |
| `scoring_health_freshness_fresh_day_cutoff` | Int | 1 | Days for "fresh" |
| `scoring_health_freshness_fresh_score` | Double | 1.0 | Score within fresh window |
| `scoring_health_freshness_recent_day_cutoff` | Int | 7 | Days for "recent" |
| `scoring_health_freshness_recent_decay_per_day` | Double | 0.05 | Linear decay per day in recent window |
| `scoring_health_freshness_long_term_base` | Double | 0.7 | Base for long-term curve |
| `scoring_health_freshness_long_term_decay_per_day` | Double | 0.017 | Log decay per day past 7 |
| `scoring_health_freshness_floor` | Double | 0.3 | Minimum freshness multiplier |
| `scoring_health_metric_weight_absolute_floor` | Double | 0.02 | Per-metric absolute weight floor |
| `scoring_health_metric_weight_equal_share_divisor` | Double | 5.0 | Floor as fraction of equal share |
| `scoring_health_coverage_full_weight_metrics` | Double | 2.0 | Metric count for full category weight |
| `scoring_health_coverage_power` | Double | 0.6 | Diminishing-returns power |
| `scoring_health_neutral_score` | Double | 75.0 | Score the raw shrinks toward when sparse |

---

## 3. Scoring — ReadinessScorer

**Operator invariant:** `scoring_readiness_hrv_weight + rhr + sleep_duration + sleep_stage + workout` MUST sum to 1.0. The runtime re-normalises by effective weight, so small drift is safe — large drift produces silently-skewed scores.

Consumer: `Core/Analysis/Config/ReadinessScorerConfig.swift` → `Core/Analysis/ReadinessScorer.swift`.

### Signal weights (sum 1.0)
| Key | Default |
|---|---|
| `scoring_readiness_hrv_weight` | 0.40 |
| `scoring_readiness_rhr_weight` | 0.35 |
| `scoring_readiness_sleep_duration_weight` | 0.15 |
| `scoring_readiness_sleep_stage_weight` | 0.06 |
| `scoring_readiness_workout_weight` | 0.04 |

### Confidence
| Key | Default |
|---|---|
| `scoring_readiness_baseline_sample_cap` | 21.0 |
| `scoring_readiness_default_baseline_confidence` | 0.55 |
| `scoring_readiness_sleep_stage_confidence` | 0.85 |
| `scoring_readiness_sleep_duration_conf_floor` | 0.5 |
| `scoring_readiness_sleep_duration_target_hours` | 7.0 |

### Freshness
| Key | Default |
|---|---|
| `scoring_readiness_missing_cardiac_age_seconds` | 259200 (72h) |
| `scoring_readiness_cardiac_freshness_horizon_seconds` | 172800 (48h) |
| `scoring_readiness_freshness_floor` | 0.35 |
| `scoring_readiness_freshness_ratio_weight` | 0.65 |
| `scoring_readiness_freshness_ratio_clamp_max` | 2.0 |

### Score reshape & cardiac staleness
| Key | Default |
|---|---|
| `scoring_readiness_score_center` | 50.0 |
| `scoring_readiness_score_confidence_floor` | 0.35 |
| `scoring_readiness_score_confidence_slope` | 0.65 |
| `scoring_readiness_cardiac_staleness_onset_hours` | 24.0 |
| `scoring_readiness_cardiac_staleness_penalty_per_hour` | 0.5 |
| `scoring_readiness_cardiac_staleness_max_penalty` | 12.0 |

### HRV / RHR curves
| Key | Default |
|---|---|
| `scoring_readiness_hrv_rhr_tanh_divisor` | 1.8 |
| `scoring_readiness_hrv_rhr_score_center` | 55.0 |
| `scoring_readiness_hrv_rhr_score_spread` | 35.0 |
| `scoring_readiness_hrv_fallback_anchor` | 15.0 |
| `scoring_readiness_hrv_fallback_range` | 55.0 |
| `scoring_readiness_rhr_fallback_anchor` | 85.0 |
| `scoring_readiness_rhr_fallback_range` | 40.0 |

### Sleep curve
| Key | Default |
|---|---|
| `scoring_readiness_sleep_target_hours` | 7.5 |
| `scoring_readiness_sleep_deficit_linear_penalty` | 13.0 |
| `scoring_readiness_sleep_deficit_quadratic_penalty` | 4.0 |
| `scoring_readiness_sleep_excess_linear_penalty` | 7.0 |
| `scoring_readiness_sleep_excess_quadratic_penalty` | 2.0 |
| `scoring_readiness_sleep_duration_deficit_floor` | 10.0 |
| `scoring_readiness_sleep_duration_excess_floor` | 35.0 |
| `scoring_readiness_sleep_restorative_ratio_floor` | 0.16 |
| `scoring_readiness_sleep_restorative_ratio_range` | 0.24 |

### Workout recovery
| Key | Default |
|---|---|
| `scoring_readiness_workout_load_duration_cap` | 75.0 |
| `scoring_readiness_workout_load_calorie_cap` | 600.0 |
| `scoring_readiness_workout_recent_band_hours` | 6.0 |
| `scoring_readiness_workout_mid_band_hours` | 18.0 |
| `scoring_readiness_workout_recent_base` | 85.0 |
| `scoring_readiness_workout_recent_load_penalty` | 35.0 |
| `scoring_readiness_workout_mid_base` | 92.0 |
| `scoring_readiness_workout_mid_load_penalty` | 25.0 |
| `scoring_readiness_workout_late_base` | 96.0 |
| `scoring_readiness_workout_late_load_penalty` | 12.0 |
| `scoring_readiness_workout_conf_floor` | 0.4 |
| `scoring_readiness_workout_conf_onset_hours` | 36.0 |
| `scoring_readiness_workout_conf_decay_hours` | 24.0 |

### Stress sub-score
| Key | Default |
|---|---|
| `scoring_readiness_stress_hrv_anchor` | 60.0 |
| `scoring_readiness_stress_hrv_range` | 40.0 |
| `scoring_readiness_stress_rhr_anchor` | 50.0 |
| `scoring_readiness_stress_rhr_range` | 30.0 |
| `scoring_readiness_stress_channel_cap` | 50.0 |

---

## 4. Scoring — StrainScorer (WHOOP-style 0-21 log curve)

Consumer: `Core/Analysis/Config/StrainScorerConfig.swift` → `Core/Analysis/StrainScorer.swift`.

| Key | Type | Default | Notes |
|---|---|---|---|
| `scoring_strain_low_upper_exclusive` | Double | 6.0 | Top of "low" band |
| `scoring_strain_light_upper_exclusive` | Double | 10.0 | Top of "light" band |
| `scoring_strain_moderate_upper_exclusive` | Double | 14.0 | Top of "moderate" band |
| `scoring_strain_high_upper_exclusive` | Double | 18.0 | Top of "high" band |
| `scoring_strain_overreaching_upper_exclusive` | Double | 20.0 | Top of "peak/overreaching" band |
| `scoring_strain_zone_multiplier_1` | Double | 1.0 | Z1 contribution multiplier |
| `scoring_strain_zone_multiplier_2` | Double | 2.0 | Z2 |
| `scoring_strain_zone_multiplier_3` | Double | 4.0 | Z3 |
| `scoring_strain_zone_multiplier_4` | Double | 8.0 | Z4 |
| `scoring_strain_zone_multiplier_5` | Double | 14.0 | Z5 |
| `scoring_strain_max_expected_load` | Double | 800.0 | Calibrated so elite training day → 20-21 |
| `scoring_strain_min_days_for_baseline` | Int | 7 | Days of calorie data before scoring |
| `scoring_strain_fallback_today_calorie_cap` | Double | 400.0 | Used when no historical data |
| `scoring_strain_default_resting_heart_rate` | Double | 65.0 | Population fallback when none measured |

---

## 5. Scoring — WorkoutBands

Consumer: `Core/Analysis/Config/WorkoutBandsConfig.swift` → `Core/Analysis/WorkoutProgrammer.swift`.

| Key | Type | Default | Notes |
|---|---|---|---|
| `scoring_workout_green_band_floor` | Int | 75 | Recovery score → green |
| `scoring_workout_yellow_band_floor` | Int | 50 | Recovery score → yellow |
| `scoring_workout_red_band_seed` | Int | 35 | Seed score for red band |
| `scoring_workout_yellow_band_seed` | Int | 65 | Seed score for yellow band |
| `scoring_workout_green_band_seed` | Int | 82 | Seed score for green band |
| `scoring_workout_zone_restoring_ceiling` | Int | 50 | Recovery → restoring zone cap |
| `scoring_workout_zone_maintaining_ceiling` | Int | 75 | Recovery → maintaining zone cap |
| `scoring_workout_zone_building_ceiling` | Int | 90 | Recovery → building zone cap |
| `scoring_workout_default_max_hr` | Int | 190 | Used when no HR-max measurement |

---

## 6. Color tokens (designer-tweakable subset)

Hex strings (`"#RRGGBB"`). Override in Firebase Console for design refreshes / A/B colour tests. Locked tokens (brand `primary`, `accent`, surface stack, semantic state, share-card gradients) stay code-side because they encode brand identity / iOS HIG semantics — changing them via RC would break accessibility.

Consumer: `Common/Theme/AppColour.swift`.

| Key | Default | Used by |
|---|---|---|
| `color_score_optimal` | `#10B981` | Score gauge — optimal tier |
| `color_score_good` | `#34D399` | Score gauge — good tier |
| `color_score_fair` | `#F59E0B` | Score gauge — fair tier |
| `color_score_poor` | `#E5484D` | Score gauge — poor tier |
| `color_category_heart` | `#F87171` | Heart category icon / accent |
| `color_category_sleep` | `#818CF8` | Sleep category |
| `color_category_activity` | `#FBBF24` | Activity category |
| `color_category_stress` | `#A78BFA` | Stress category |
| `color_category_vitality` | `#34D399` | Vitality category |
| `color_category_brain` | `#F472B6` | Brain category |
| `color_state_recovery` | `#34D399` | Health state timeline — recovery |
| `color_state_peak_performance` | `#0071E3` | Peak performance |
| `color_state_stressed` | `#E5484D` | Stressed |
| `color_state_under_slept` | `#A78BFA` | Under-slept |
| `color_state_active` | `#10B981` | Active |
| `color_state_fatigued` | `#F59E0B` | Fatigued |
| `color_state_resting` | `#4DA3FF` | Resting |
| `color_achievement_bronze` | `#CC8033` | Achievement tier |
| `color_achievement_silver` | `#BFBFC7` | Achievement tier |
| `color_achievement_gold` | `#FFD600` | Achievement tier |
| `color_achievement_platinum` | `#E6E8FA` | Achievement tier |
| `color_achievement_diamond` | `#B8F2FF` | Achievement tier |
| `color_achievement_legend` | `#BFB8FA` | Achievement tier |
| `color_premium_gradient_top` | `#FFD972` | Premium badge gradient — top |
| `color_premium_gradient_bottom` | `#F5A32E` | Premium badge gradient — bottom |
| `color_vitality_green` | `#34D399` | Vitality pace ramp — green |
| `color_vitality_yellow` | `#F59E0B` | Vitality pace ramp — yellow |
| `color_vitality_red` | `#E5484D` | Vitality pace ramp — red |

---

## 7. Onboarding flow

Consumer: `Modules/Onboarding/Views/Onboarding/OnboardingV2View.swift`.

| Key | Type | Default | Notes |
|---|---|---|---|
| `onboarding_skip_screens` | String (CSV) | `""` | CSV of `Screen` raw names to bypass, e.g. `"symptoms,activity"`. Empty = normal flow. Unknown names ignored. |
| `onboarding_fast_track_enabled` | Bool | `false` | Future fast-track variant gate |
| `onboarding_variant` | String | `"control"` | A/B variant selector (read by analytics for cohort tagging) |

---

## 8. Paywall

Revenue measurement happens via PostHog + StoreKit, NOT Firebase Analytics — Firebase Analytics misses background subscription events. Use `paywall_variant` only as the variant label; conversion analysis lives outside RC.

Consumer: `Modules/Paywall/Views/Subscription/PaywallView.swift`.

| Key | Type | Default | Notes |
|---|---|---|---|
| `paywall_variant` | String | `"control"` | A/B variant selector |
| `paywall_show_yearly_default` | Bool | `true` | Pre-select yearly tier |

---

## 9. Notification timing

Local-time hours, 0-23. Cooldown / daily budget / fatigue threshold already live in legacy `RemoteConfigManager` keys (`notification_daily_budget`, `notification_fatigue_threshold`, etc.).

Consumer: `Core/Notifications/*`.

| Key | Type | Default | Notes |
|---|---|---|---|
| `notification_morning_start_hour` | Int | 5 | Earliest hour for morning summary |
| `notification_morning_end_hour` | Int | 11 | Latest hour for morning summary |
| `notification_evening_start_hour` | Int | 20 | Earliest hour for wind-down |
| `notification_evening_end_hour` | Int | 23 | Latest hour for wind-down |
| `notification_hook_style` | String | `"rotate"` | One of `rotate`, `curiosity`, `loss_frame`, `progress`, `record`, `question` |

---

## 10. Experiments

Single-string variant selectors. Bucketing via Firebase Remote Config conditions (% rollout). Empty / `"control"` = off. Tag analytics events with the variant for downstream cohort analysis in PostHog.

| Key | Type | Default | Notes |
|---|---|---|---|
| `experiment_recovery_card_style` | String | `"control"` | Variants: `control`, `minimalist`, `detailed` |

---

## Stays in code (do NOT add to RC)

Adding any of these to RC creates a foot-gun. They are listed here so contributors do not "helpfully" expose them.

- App Store IAP product IDs — App Store policy
- HealthKit / CloudKit / Push entitlements — binary-baked, code-signed
- Medical-standard thresholds (SpO2 <90% critical, HR <40 / >150 dangerous, body temp 35-40°C) — FDA-bound, never tune
- Brand primary, accent, surface, semantic state colours — brand identity / iOS HIG
- Network retry / timeout — infra, rare-change
- Database schema retention defaults — already in legacy RC keys
- HR zone fractions (Z1-Z5 % of max HR) — exercise-physiology convention; changing invalidates every cached zone classification
- Country → pricing tier mapping — rare and tightly coupled to App Store Connect
- Privacy / Terms / Support / FAQ URLs — ship with the release; URL changes are infrequent

---

## When you add a new key

1. Add the string constant to the matching `// MARK:` block in `RemoteConfigSchema.swift`.
2. Add the bundled default to `expandedDefaults` in the same file.
3. Add a typed accessor on `RemoteConfigManager` in the same file (under `extension RemoteConfigManager`).
4. Wire the accessor into the consumer site.
5. Add the key + default to the matching section above. Include type, default, and one-line description.
6. Push to a feature branch, ship the binary, then publish the parameter in Firebase Console.

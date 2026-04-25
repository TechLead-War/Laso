# 01 — Naming / Identity Disturbance

User-flagged finding. Single-issue file.

## F1. Repo folder name "HealthPulse" vs product name "Laso"

- **Severity:** Medium
- **Issue:** Repo root is `/Users/primetrace/Desktop/RnD/HealthPulse` while every authoritative product surface (`CFBundleDisplayName`, `project.yml::name`, scheme, entitlements, StoreKit config, project-level `claude.md`) says "Laso". The dead name "HealthPulse" persists only at the filesystem-folder layer.
- **Why this exists:** Project was almost certainly renamed mid-development from `HealthPulse` → `Laso`; the on-disk folder was never `mv`'d so all developer IDE workspaces, DerivedData paths, archive output paths, screenshot folders, and shell history reference the dead name.
- **Impact:** Low for end users (they never see "HealthPulse"). Medium for engineering hygiene — new contributors get confused, search-and-replace operations may leak the dead name into commits, CI scripts that hard-code the path break on rename, crash archives in DerivedData/HealthPulse-* directories are misleading, screenshot/test artifacts under `screenshots/` and `visual-regression/` carry mixed naming.
- **Evidence:**
  - Folder: `/Users/primetrace/Desktop/RnD/HealthPulse/` (file system).
  - `project.yml:1` → `name: Laso`.
  - `Info.plist` → `<key>CFBundleDisplayName</key><string>Laso</string>`.
  - `project.yml::settings.base.PRODUCT_BUNDLE_IDENTIFIER = com.lasohealth.fit`.
  - `Laso.entitlements`, `Laso.xcodeproj/`, `Laso.storekit`, `LasoUITests/`, `LasoWidgets/`, `LasoApp.swift` — every named artifact says Laso.
  - `claude.md` (project file at repo root) talks about "Laso" exclusively, never "HealthPulse".
- **How to verify fast:**
  - `grep -ril "HealthPulse" /Users/primetrace/Desktop/RnD/HealthPulse --include="*.swift" --include="*.yml" --include="*.plist" --include="*.sh" --include="*.json" 2>/dev/null` — count non-`.git` matches.
  - `grep -rin "healthpulse\|HealthPulse" Scripts/ .githooks/ admin-panel/ 2>/dev/null` — check if any automation hard-codes the dead name.
- **Fix:**
  1. Rename repo folder once: `mv /Users/primetrace/Desktop/RnD/HealthPulse /Users/primetrace/Desktop/RnD/Laso`.
  2. Audit `Scripts/`, `.githooks/`, any IDE-specific files (`.vscode/settings.json`), CI YAML for hard-coded `HealthPulse` paths.
  3. Update internal contributor README + onboarding docs.
  4. Optional: add a brief CHANGELOG entry "Project renamed from HealthPulse → Laso, repo folder renamed to match" so historical confusion is resolved.
- **Priority:** This Week — do before App Store submission so dSYM/archive output paths reflect the product name.
- **Confidence:** 92/100 — verified via direct inspection of `project.yml`, `Info.plist`, file listings; what's not yet verified is exactly how many non-trivial source/script files still contain the literal `HealthPulse` string (a follow-up grep will close that gap).

## Summary

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 0 |
| Medium | 1 |
| Low | 0 |

**Top fix Now:** none.
**Top fix This Week:** rename repo folder to `Laso/` and audit `Scripts/` + `.githooks/` for hard-coded dead name.

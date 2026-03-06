# Visual Regression Workflow (Local)

This repo keeps approved screenshots in `visual-regression/baseline/`.

## Directory contract

- `visual-regression/baseline/` - committed approved screenshots
- `visual-regression/current/` - latest screenshots from current build (ignored)
- `visual-regression/reports/latest/` - compare output and diffs (ignored)

## Suggested screenshot naming

Use deterministic names so one file maps to one flow step:

`<ios>-<device>-<theme>-<locale>-<profile>-<flow>-<step>.png`

Example:

`ios17-iphone17-light-enUS-normal-home-01_dashboard.png`

## Local commands

1. Capture deterministic screenshots into `visual-regression/current/`:

```bash
./scripts/visual/capture_screenshots.sh
```

2. Compare against baseline:

```bash
./scripts/visual/compare_baseline.sh
```

3. If intentional, approve and promote current as new baseline:

```bash
VISUAL_APPROVE=1 ./scripts/visual/approve_baseline.sh
```

4. Run full release gate (capture + compare):

```bash
./scripts/visual/run_release_gate.sh
```

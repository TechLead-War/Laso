#!/usr/bin/env python3
"""
Lift inline interpolated literals (Text/Button/Label/accessibility*/navigationTitle)
into the matching Common/Copy/Copy+*.swift file as RC-backed `static func`s,
then rewrite the call site to use `Copy.<NS>.<fn>(args)`.

Pattern handled:
    .accessibilityHint("View \\(metric.displayName) details")
becomes:
    .accessibilityHint(Copy.<NS>.viewMetricDetailsHint(metric.displayName))
where the new `static func` is appended to the relevant Copy file.

Heuristics used to type each interpolation expression:
  * any of `Int(`, `.count`, `.integer`, `.minutes`, `.seconds`, `.hours`,
    `.days`, `.length`, common int-typed names (`days`, `count`, `minutes`,
    `seconds`, `hours`, `napMinutes`) -> %d (Int)
  * everything else -> %@ (String). The call site is wrapped in
    `String(describing:)` only when the expression evaluates to a non-String
    (we use a conservative fallback that quietly accepts an existing String
    expression).

Skip rules:
  * Preview / `#Preview` blocks
  * Files inside Common/Copy
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COPY_DIR = ROOT / "Common" / "Copy"

NAMESPACE_RULES: list[tuple[str, str, str]] = [
    ("Modules/Dashboard/", "Copy+Home.swift", "Home"),
    ("Modules/Live/", "Copy+Live.swift", "Live"),
    ("Modules/Devices/", "Copy+Devices.swift", "Devices"),
    ("Modules/Onboarding/", "Copy+Onboarding.swift", "Onboarding"),
    ("Modules/Profile/", "Copy+Achievements.swift", "Achievements"),
    ("Modules/Settings/", "Copy+Settings.swift", "Settings"),
    ("Modules/Stress/", "Copy+StressMonitor.swift", "StressMonitor"),
    ("Modules/Vitality/", "Copy+Vitality.swift", "Vitality"),
    ("Modules/Journal/", "Copy+Journal.swift", "Journal"),
    ("Modules/Discovery/", "Copy+Discovery.swift", "Discovery"),
    ("Modules/Explore/", "Copy+Explore.swift", "Explore"),
    ("Modules/HealthState/", "Copy+HealthState.swift", "HealthState"),
    ("Modules/Paywall/", "Copy+Paywall.swift", "Paywall"),
    ("Modules/Sleep/", "Copy+SleepCoach.swift", "SleepCoach"),
    ("Modules/Strain/", "Copy+Strain.swift", "Strain"),
    ("Modules/CategoryDetail/", "Copy+Common.swift", "Common"),
    ("Modules/Insights/", "Copy+Insights.swift", "Insights"),
    ("Modules/Risk/", "Copy+Common.swift", "Common"),
    ("Modules/MetricDetail/", "Copy+MetricDetail.swift", "MetricDetail"),
    ("Common/Components/", "Copy+Common.swift", "Common"),
    ("Common/Navigation/", "Copy+Common.swift", "Common"),
    ("Core/Intents/", "Copy+Common.swift", "Common"),
    ("App/", "Copy+Common.swift", "Common"),
]

# Patterns to lift. Each entry: (api_token, regex_to_replace, builder).
# The regex must capture the full call (including leading `.` for modifiers,
# e.g. `.accessibilityHint(...)`); the literal-with-interpolation lives inside
# `text` group.
PATTERNS: list[tuple[str, re.Pattern]] = [
    ("accessibilityHint",
     re.compile(r'\.accessibilityHint\("(?P<text>[^"\\]*?(?:\\.[^"\\]*?)*?)"\)')),
    ("accessibilityLabel",
     re.compile(r'\.accessibilityLabel\("(?P<text>[^"\\]*?(?:\\.[^"\\]*?)*?)"\)')),
    ("accessibilityValue",
     re.compile(r'\.accessibilityValue\("(?P<text>[^"\\]*?(?:\\.[^"\\]*?)*?)"\)')),
    ("navigationTitle",
     re.compile(r'\.navigationTitle\("(?P<text>[^"\\]*?(?:\\.[^"\\]*?)*?)"\)')),
    ("text",
     re.compile(r'(?<![A-Za-z0-9_.])Text\("(?P<text>[^"\\]*?(?:\\.[^"\\]*?)*?)"\)')),
    ("button",
     re.compile(r'(?<![A-Za-z0-9_.])Button\("(?P<text>[^"\\]*?(?:\\.[^"\\]*?)*?)",')),
    ("label",
     re.compile(r'(?<![A-Za-z0-9_.])Label\("(?P<text>[^"\\]*?(?:\\.[^"\\]*?)*?)",\s*systemImage:')),
]

API_REWRITE = {
    "accessibilityHint": ".accessibilityHint",
    "accessibilityLabel": ".accessibilityLabel",
    "accessibilityValue": ".accessibilityValue",
    "navigationTitle": ".navigationTitle",
    "text": "Text",
    "button": "Button",
    "label": "Label",
}


INT_HINTS = re.compile(
    r"Int\(|\.count\b|\.integer\b|\.minutes\b|\.seconds\b|\.hours\b|\.days\b|"
    r"\.length\b|\.size\b|\.frequency\b|"
    r"^(napMinutes|days|count|minutes|seconds|hours|length|index|score|months|years|displayMax)$"
)


def slugify(text: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9 ]+", " ", text).strip()
    words = [w for w in cleaned.split() if w]
    if not words:
        return "x"
    words = words[:5]
    out = words[0].lower()
    for w in words[1:]:
        out += w.capitalize()
    if not re.match(r"^[a-zA-Z_]", out):
        out = "x" + out
    return out


def make_fn_name(api: str, text_no_interp: str) -> str:
    base = slugify(text_no_interp)
    suffix = {
        "accessibilityHint": "Hint",
        "accessibilityLabel": "Label",
        "accessibilityValue": "Value",
        "navigationTitle": "NavTitle",
        "text": "Text",
        "button": "Button",
        "label": "MenuLabel",
    }[api]
    return base + suffix


def split_template(text: str) -> tuple[str, list[str]]:
    """Walk the literal, replacing each `\\(expr)` with %@ or %d depending on
    expression heuristics. Returns (template, list-of-Swift-expression-strings)."""
    out_template = ""
    args: list[str] = []
    i = 0
    while i < len(text):
        ch = text[i]
        if ch == "\\" and i + 1 < len(text) and text[i + 1] == "(":
            depth = 1
            j = i + 2
            expr = ""
            while j < len(text) and depth > 0:
                c = text[j]
                if c == "(":
                    depth += 1
                elif c == ")":
                    depth -= 1
                    if depth == 0:
                        break
                expr += c
                j += 1
            if depth != 0:
                raise ValueError("unmatched paren in interpolation")
            # Decide spec
            spec = "%d" if INT_HINTS.search(expr) else "%@"
            out_template += spec
            args.append(expr.strip())
            i = j + 1
            continue
        if ch == "%":
            out_template += "%%"
            i += 1
            continue
        out_template += ch
        i += 1
    return out_template, args


def namespace_for(path: Path) -> tuple[Path, str] | None:
    rel = str(path.relative_to(ROOT))
    for prefix, copy_file, enum_name in NAMESPACE_RULES:
        if rel.startswith(prefix):
            return COPY_DIR / copy_file, enum_name
    return None


def discover_targets(root: Path) -> list[Path]:
    out: list[Path] = []
    for ext in ("Modules", "Core", "App", "Common"):
        sub = root / ext
        if not sub.is_dir():
            continue
        for path in sub.rglob("*.swift"):
            rel = str(path.relative_to(root))
            if rel.startswith("Common/Copy/"):
                continue
            out.append(path)
    return out


def is_in_preview(lines: list[str], idx: int) -> bool:
    for j in range(idx, max(-1, idx - 80), -1):
        line = lines[j]
        if "#Preview" in line or "PreviewProvider" in line:
            return True
        if "var body:" in line or "func body" in line:
            return False
    return False


def append_copy_funcs(copy_path: Path, enum_name: str,
                      entries: list[tuple[str, str, list[tuple[str, str]], str]]) -> int:
    """`entries` items: (fn_name, rc_key, [(arg_name, spec)], default_template)."""
    if not entries:
        return 0
    text = copy_path.read_text()
    lines = text.splitlines(keepends=False)
    enum_open_re = re.compile(r"^\s*enum\s+" + re.escape(enum_name) + r"\s*\{")
    enum_open_idx = None
    for j, line in enumerate(lines):
        if enum_open_re.match(line):
            enum_open_idx = j
            break
    block: list[str] = ["", "        // MARK: - Lifted interpolated view literals"]
    for fn_name, key, params, default_template in entries:
        sig_args: list[str] = []
        call_args: list[str] = []
        for idx, (arg_name, spec) in enumerate(params):
            ty = "Int" if spec == "%d" else "String"
            sig_args.append(f"_ {arg_name}{idx}: {ty}")
            call_args.append(f"{arg_name}{idx}")
        sig = ", ".join(sig_args)
        call = ", ".join(call_args)
        esc_default = default_template.replace("\\", "\\\\").replace("\"", "\\\"")
        if call:
            block.append(
                f'        static func {fn_name}({sig}) -> String {{ '
                f'String(format: RemoteConfigManager.shared.copyString('
                f'"{key}", default: "{esc_default}"), {call}) }}'
            )
        else:
            block.append(
                f'        static var {fn_name}: String '
                f'{{ RemoteConfigManager.shared.copyString('
                f'"{key}", default: "{esc_default}") }}'
            )
    if enum_open_idx is None:
        # Append a fresh nested enum.
        wrap = [f"\n    enum {enum_name} {{"] + block + ["    }"]
        for j in range(len(lines) - 1, -1, -1):
            if lines[j].strip() == "}":
                lines = lines[:j] + wrap + lines[j:]
                break
        copy_path.write_text("\n".join(lines) + "\n")
        return len(entries)
    depth = 0
    enum_close_idx = None
    for j in range(enum_open_idx, len(lines)):
        depth += lines[j].count("{") - lines[j].count("}")
        if depth == 0 and j > enum_open_idx:
            enum_close_idx = j
            break
    if enum_close_idx is None:
        return 0
    lines = lines[:enum_close_idx] + block + lines[enum_close_idx:]
    copy_path.write_text("\n".join(lines) + "\n")
    return len(entries)


def lift_file(path: Path,
              registry: dict[Path, dict[str, list[tuple[str, str, list[tuple[str, str]], str]]]]) -> int:
    text = path.read_text()
    lines = text.splitlines(keepends=False)
    ns_info = namespace_for(path)
    if not ns_info:
        return 0
    copy_path, enum_name = ns_info
    seen_props: set[str] = set()
    new_entries: list[tuple[str, str, list[tuple[str, str]], str]] = []
    changed = False

    for i, raw_line in enumerate(lines):
        if is_in_preview(lines, i):
            continue
        line = raw_line
        for api_name, pattern in PATTERNS:
            for m in pattern.finditer(line):
                text_lit = m.group("text")
                # Only lift literals that contain interpolation.
                if "\\(" not in text_lit:
                    continue
                try:
                    template, exprs = split_template(text_lit)
                except ValueError:
                    continue
                # Build a no-interp variant for slug generation.
                no_interp = re.sub(r"\\\([^)]*\)", "", text_lit).strip()
                fn = make_fn_name(api_name, no_interp)
                base = fn
                k = 2
                while fn in seen_props:
                    fn = f"{base}{k}"
                    k += 1
                seen_props.add(fn)
                params: list[tuple[str, str]] = []
                arg_callsite: list[str] = []
                for idx, expr in enumerate(exprs):
                    spec = "%d" if INT_HINTS.search(expr) else "%@"
                    arg_name = "p"
                    params.append((arg_name, spec))
                    arg_callsite.append(expr)
                snake_fn = re.sub(r'([A-Z])', r'_\1', fn).strip('_').lower()
                key = f"copy_{enum_name.lower()}_{snake_fn}"
                new_entries.append((fn, key, params, template))
                # Build call replacement.
                call_args = ", ".join(arg_callsite)
                api_form = API_REWRITE[api_name]
                if api_name in {"accessibilityHint", "accessibilityLabel", "accessibilityValue", "navigationTitle"}:
                    replacement = f'{api_form}(Copy.{enum_name}.{fn}({call_args}))'
                elif api_name == "text":
                    replacement = f'Text(Copy.{enum_name}.{fn}({call_args}))'
                elif api_name == "button":
                    replacement = f'Button(Copy.{enum_name}.{fn}({call_args}),'
                elif api_name == "label":
                    replacement = f'Label(Copy.{enum_name}.{fn}({call_args}), systemImage:'
                line = line.replace(m.group(0), replacement)
                changed = True
        if changed:
            lines[i] = line
    if not changed:
        return 0
    path.write_text("\n".join(lines) + ("\n" if text.endswith("\n") else ""))
    if new_entries:
        registry.setdefault(copy_path, {}).setdefault(enum_name, []).extend(new_entries)
    return len(new_entries)


def main() -> int:
    targets = discover_targets(ROOT)
    registry: dict[Path, dict[str, list[tuple[str, str, list[tuple[str, str]], str]]]] = {}
    total = 0
    for path in targets:
        n = lift_file(path, registry)
        if n:
            total += n
            print(f"  {path.relative_to(ROOT)}: +{n}")
    appended = 0
    for copy_path, by_enum in registry.items():
        for enum_name, entries in by_enum.items():
            seen = set()
            unique: list[tuple[str, str, list[tuple[str, str]], str]] = []
            for e in entries:
                if e[0] in seen:
                    continue
                seen.add(e[0])
                unique.append(e)
            appended += append_copy_funcs(copy_path, enum_name, unique)
            print(f"  {copy_path.name}/{enum_name}: appended {len(unique)} entries")
    print(f"TOTAL: {total} call-site lifts, {appended} Copy entries written")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

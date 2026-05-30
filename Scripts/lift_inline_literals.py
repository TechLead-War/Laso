#!/usr/bin/env python3
"""
Find every inline user-facing string literal in views/components
(Text, Button, Label, accessibilityLabel/Hint/Value, navigationTitle) and:

  * append a `static var <name>: String { copyString(...) }` entry to the matching
    `Common/Copy/Copy+<Namespace>.swift` file, and
  * replace the inline literal with the new Copy reference.

A "matching" namespace is decided from the source path:
  Modules/Dashboard/**       -> Copy+Home.swift            (enum Home)
  Modules/Live/**            -> Copy+Live.swift            (enum Live)
  Modules/Devices/**         -> Copy+Devices.swift         (enum Devices)
  Modules/Onboarding/**      -> Copy+Onboarding.swift      (enum Onboarding)
  Modules/Profile/**         -> Copy+Achievements.swift    (enum Achievements)
  Modules/Settings/**        -> Copy+Settings.swift        (enum Settings)
  Modules/Stress/**          -> Copy+StressMonitor.swift   (enum StressMonitor)
  Modules/Vitality/**        -> Copy+Vitality.swift        (enum Vitality)
  Modules/Journal/**         -> Copy+Journal.swift         (enum Journal)
  Modules/Discovery/**       -> Copy+Discovery.swift       (enum Discovery)
  Modules/Explore/**         -> Copy+Explore.swift         (enum Explore)
  Modules/HealthState/**     -> Copy+HealthState.swift     (enum HealthState)
  Modules/Paywall/**         -> Copy+Paywall.swift         (enum Paywall)
  Common/Components/**       -> Copy+Common.swift          (enum Common)  (NEW namespace 'Views')
  Core/Intents/**            -> Copy+Common.swift          (enum Common)  (NEW namespace 'Intents')
  App/**                     -> Copy+Common.swift          (enum Common)  (NEW namespace 'App')

Skipped:
  * Preview / #Preview blocks
  * Strings containing Swift interpolation `\\(...)` (those need manual review)
  * Copy/* itself
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COPY_DIR = ROOT / "Common" / "Copy"

# The patterns we will lift. Each rule is (regex, capture_group_for_string).
# The regex must match exactly the substring we will replace; we replace
# the first quoted argument with `Copy.<NS>.<key>`.
RULES: list[tuple[str, re.Pattern]] = [
    ("accessibilityHint",
     re.compile(r'\.accessibilityHint\("(?P<text>[^"\\]+)"\)')),
    ("accessibilityLabel",
     re.compile(r'\.accessibilityLabel\("(?P<text>[^"\\]+)"\)')),
    ("accessibilityValue",
     re.compile(r'\.accessibilityValue\("(?P<text>[^"\\]+)"\)')),
    ("navigationTitle",
     re.compile(r'\.navigationTitle\("(?P<text>[^"\\]+)"\)')),
    ("text",
     re.compile(r'(?<![A-Za-z0-9_.])Text\("(?P<text>[^"\\]+)"\)')),
    ("button_label",
     re.compile(r'(?<![A-Za-z0-9_.])Button\("(?P<text>[^"\\]+)"\)')),
    ("label_systemImage",
     re.compile(r'(?<![A-Za-z0-9_.])Label\("(?P<text>[^"\\]+)",\s*systemImage:')),
]

# Source path prefix -> (Copy file name, enum namespace inside that file).
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
    ("Common/Components/", "Copy+Common.swift", "Common"),
    ("Core/Intents/", "Copy+Common.swift", "Common"),
    ("App/", "Copy+Common.swift", "Common"),
]

# Skip these subtrees entirely.
SKIP_DIRS = {"Common/Copy", ".claude", "build", "DerivedData"}


def namespace_for(path: Path) -> tuple[Path, str] | None:
    rel = str(path.relative_to(ROOT))
    for prefix, copy_file, enum_name in NAMESPACE_RULES:
        if rel.startswith(prefix):
            return COPY_DIR / copy_file, enum_name
    return None


# Slugify a literal string into a camelCase identifier suffix. Limit to ~6 words
# to keep names readable.
def slugify(text: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9 ]+", " ", text).strip()
    words = [w for w in cleaned.split() if w]
    if not words:
        return "x"
    words = words[:6]
    out = words[0].lower()
    for w in words[1:]:
        out += w.capitalize()
    if not re.match(r"^[a-zA-Z_]", out):
        out = "x" + out
    return out


def make_property_name(rule_name: str, text: str) -> str:
    base = slugify(text)
    suffix = {
        "accessibilityHint": "Hint",
        "accessibilityLabel": "Label",
        "accessibilityValue": "Value",
        "navigationTitle": "NavTitle",
        "text": "",
        "button_label": "Button",
        "label_systemImage": "Label",
    }[rule_name]
    return base + suffix


def make_key(enum_name: str, prop_name: str) -> str:
    parts = ["copy"]
    parts.extend(re.sub(r"([A-Z])", r"_\1", enum_name).strip("_").lower().split("_"))
    parts.extend(re.sub(r"([A-Z])", r"_\1", prop_name).strip("_").lower().split("_"))
    return "_".join(p for p in parts if p)


def is_in_preview_block(lines: list[str], idx: int) -> bool:
    """Cheap heuristic: walk upward looking for `#Preview` or `_Preview`."""
    depth = 0
    for j in range(idx, -1, -1):
        line = lines[j]
        if "#Preview" in line or "PreviewProvider" in line or "_Preview" in line:
            return True
        if "func body" in line or "var body:" in line:
            return False
    return False


def discover_targets(root: Path) -> list[Path]:
    out: list[Path] = []
    for ext in ("Modules", "Core", "App", "Common"):
        sub = root / ext
        if not sub.is_dir():
            continue
        for path in sub.rglob("*.swift"):
            rel = str(path.relative_to(root))
            if any(skip in rel for skip in SKIP_DIRS):
                continue
            out.append(path)
    return out


def append_copy_entries(copy_path: Path, enum_name: str, entries: list[tuple[str, str, str]]) -> int:
    """`entries` is (prop_name, rc_key, default_text). Returns count appended."""
    if not entries:
        return 0
    text = copy_path.read_text()
    # We append a new MARK section just before the final `} } }` of the file.
    # Strategy: find the last `}` that closes the `extension Copy { ... }` block.
    # Simpler: count `enum <enum_name>` block end. We scan from the bottom for
    # the FIRST line that is exactly "}" and assume it ends the enum, second
    # closes the extension.
    lines = text.splitlines(keepends=False)
    # Find the closing brace of the target enum.
    enum_open_re = re.compile(r"^\s*enum\s+" + re.escape(enum_name) + r"\s*\{")
    enum_open_idx = None
    for j, line in enumerate(lines):
        if enum_open_re.match(line):
            enum_open_idx = j
            break
    if enum_open_idx is None:
        # Append a fresh nested `enum <enum_name>` inside the existing
        # `extension Copy {`. Find the LAST `}` and insert before it.
        # We'll create a new sub-enum with the entries.
        block_lines = [f"\n    // MARK: - Lifted view literals", f"    enum {enum_name} {{"]
        for prop_name, key, default_text in entries:
            esc = default_text.replace("\\", "\\\\").replace("\"", "\\\"")
            block_lines.append(
                f'        static var {prop_name}: String '
                f'{{ RemoteConfigManager.shared.copyString("{key}", default: "{esc}") }}'
            )
        block_lines.append("    }")
        # Find the LAST closing brace. Walk from end.
        for j in range(len(lines) - 1, -1, -1):
            if lines[j].strip() == "}":
                lines = lines[:j] + block_lines + lines[j:]
                break
        copy_path.write_text("\n".join(lines) + "\n")
        return len(entries)

    # Find the matching close for the enum. Track brace depth.
    depth = 0
    enum_close_idx = None
    for j in range(enum_open_idx, len(lines)):
        depth += lines[j].count("{") - lines[j].count("}")
        if depth == 0 and j > enum_open_idx:
            enum_close_idx = j
            break
    if enum_close_idx is None:
        return 0
    # Insert entries just before the closing brace.
    insert: list[str] = ["", "        // MARK: - Lifted view literals"]
    for prop_name, key, default_text in entries:
        esc = default_text.replace("\\", "\\\\").replace("\"", "\\\"")
        insert.append(
            f'        static var {prop_name}: String '
            f'{{ RemoteConfigManager.shared.copyString("{key}", default: "{esc}") }}'
        )
    lines = lines[:enum_close_idx] + insert + lines[enum_close_idx:]
    copy_path.write_text("\n".join(lines) + "\n")
    return len(entries)


def lift_file(path: Path, registry: dict[Path, dict[str, list[tuple[str, str, str]]]]) -> int:
    """Apply rules in-place. `registry` collects per-Copy-file pending entries."""
    text = path.read_text()
    lines = text.splitlines(keepends=False)
    ns_info = namespace_for(path)
    if not ns_info:
        return 0
    copy_path, enum_name = ns_info

    changed = False
    new_entries: list[tuple[str, str, str]] = []
    seen_props: set[str] = set()

    for i, line in enumerate(lines):
        if "Preview" in line or "_Preview" in line or is_in_preview_block(lines, i):
            continue
        for rule_name, pattern in RULES:
            for m in pattern.finditer(line):
                text_lit = m.group("text").strip()
                if not text_lit or text_lit[0].islower() and rule_name not in {"text", "button_label"}:
                    # require a leading capital for accessibility hints/labels?
                    # we accept anything; this guard only filters very short
                    # no-op tokens like single lowercase words.
                    pass
                if "\\(" in text_lit:
                    continue  # interpolation, manual review
                prop_name = make_property_name(rule_name, text_lit)
                # Avoid duplicate property names within the same file lift.
                base = prop_name
                k = 2
                while prop_name in seen_props:
                    prop_name = f"{base}{k}"
                    k += 1
                seen_props.add(prop_name)
                key = make_key(enum_name, prop_name)
                new_entries.append((prop_name, key, text_lit))
                # Replace the literal with the Copy reference. We need to
                # rebuild the call form per rule.
                if rule_name in {"accessibilityHint", "accessibilityLabel", "accessibilityValue", "navigationTitle"}:
                    api = rule_name
                    line = line.replace(m.group(0), f'.{api}(Copy.{enum_name}.{prop_name})')
                elif rule_name == "text":
                    line = line.replace(m.group(0), f'Text(Copy.{enum_name}.{prop_name})')
                elif rule_name == "button_label":
                    line = line.replace(m.group(0), f'Button(Copy.{enum_name}.{prop_name})')
                elif rule_name == "label_systemImage":
                    line = line.replace(m.group(0), f'Label(Copy.{enum_name}.{prop_name}, systemImage:')
                changed = True
        lines[i] = line

    if not changed:
        return 0
    path.write_text("\n".join(lines) + ("\n" if text.endswith("\n") else ""))
    registry.setdefault(copy_path, {}).setdefault(enum_name, []).extend(new_entries)
    return len(new_entries)


def main() -> int:
    targets = discover_targets(ROOT)
    print(f"scanning {len(targets)} swift files…", file=sys.stderr)
    registry: dict[Path, dict[str, list[tuple[str, str, str]]]] = {}
    total_lifts = 0
    for path in targets:
        try:
            n = lift_file(path, registry)
        except Exception as exc:
            print(f"  skip {path}: {exc}", file=sys.stderr)
            continue
        if n:
            total_lifts += n
            print(f"  {path.relative_to(ROOT)}: +{n}")
    appended = 0
    for copy_path, by_enum in registry.items():
        for enum_name, entries in by_enum.items():
            # Dedupe within (copy_path, enum_name) by prop name.
            seen = set()
            unique: list[tuple[str, str, str]] = []
            for e in entries:
                if e[0] in seen:
                    continue
                seen.add(e[0])
                unique.append(e)
            appended += append_copy_entries(copy_path, enum_name, unique)
            print(f"  {copy_path.name}/{enum_name}: appended {len(unique)} entries")
    print(f"TOTAL: {total_lifts} call-site lifts, {appended} Copy entries written")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

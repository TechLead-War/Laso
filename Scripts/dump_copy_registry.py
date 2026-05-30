#!/usr/bin/env python3
"""
Walk every `Common/Copy/Copy+*.swift` and dump a registry of every Remote
Config key the iOS app reads, with its baked-in English default. The output
is consumed by the **admin-panel web dashboard** (`admin-panel/public/`),
not the iOS app — operators see every editable key in the browser and write
overrides to the `copy_overrides/strings` Firestore document.

Output:
    admin-panel/public/data/copy_keys.json
        [
            {
                "key": "copy_brain_health_title",
                "defaultValue": "Brain Health",
                "sourceFile": "Copy+BrainHealth.swift",
                "isArray": false
            },
            …
        ]

Run after editing any `Copy+*.swift` so the dashboard picks up new keys.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COPY_DIR = ROOT / "Common" / "Copy"
OUT_PATH = ROOT / "admin-panel" / "public" / "data" / "copy_keys.json"

COPY_STRING_RE = re.compile(
    r'copyString\(\s*"(?P<key>[^"]+)"\s*,\s*default:\s*"(?P<value>(?:[^"\\]|\\.)*)"\s*\)'
)
COPY_ARRAY_RE = re.compile(
    r'copyArray\(\s*"(?P<key>[^"]+)"\s*,\s*default:\s*\[(?P<value>[^\]]*)\]\s*\)'
)


def unescape_swift_literal(s: str) -> str:
    """Convert Swift source escapes (\\n, \\", \\\\) back to literal characters
    so the JSON payload mirrors what the user will see on screen."""
    return (
        s.replace(r'\"', '"')
         .replace(r'\\', '\\')
         .replace(r'\n', '\n')
         .replace(r'\t', '\t')
    )


def main() -> int:
    entries: list[dict] = []
    string_seen: set[str] = set()

    for path in sorted(COPY_DIR.glob("Copy*.swift")):
        text = path.read_text()
        for m in COPY_STRING_RE.finditer(text):
            key = m.group("key")
            if key in string_seen:
                continue
            string_seen.add(key)
            entries.append({
                "key": key,
                "defaultValue": unescape_swift_literal(m.group("value")),
                "sourceFile": path.name,
                "isArray": False,
            })
        for m in COPY_ARRAY_RE.finditer(text):
            key = m.group("key")
            if key in string_seen:
                continue
            string_seen.add(key)
            entries.append({
                "key": key,
                "defaultValue": "(array)",
                "sourceFile": path.name,
                "isArray": True,
            })

    entries.sort(key=lambda e: e["key"])

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text(json.dumps(entries, indent=2, ensure_ascii=False) + "\n")

    string_count = sum(1 for e in entries if not e["isArray"])
    array_count = sum(1 for e in entries if e["isArray"])
    print(f"wrote {OUT_PATH.relative_to(ROOT)} "
          f"({string_count} string keys, {array_count} array keys)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

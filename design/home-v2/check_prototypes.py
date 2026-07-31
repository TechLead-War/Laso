#!/usr/bin/env python3
"""Sanity-check the standalone Home Screen prototypes.

Fails loudly. Checks each .html file for: inline-script JS syntax errors (via node),
no external network references, presence of the required screen furniture, and that
every interactive control is actually wired.
"""
import re, subprocess, sys, tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
# index.html is the gallery, not a prototype, so it has none of the screen furniture.
FILES = sorted((HERE / "concepts").glob("*.html")) + [
    p for p in sorted(HERE.glob("*.html")) if p.name != "index.html"
]

EXTERNAL = re.compile(r'(?:src|href)\s*=\s*["\'](?:https?:)?//', re.I)
SCRIPT = re.compile(r"<script\b[^>]*>(.*?)</script>", re.S | re.I)
SCRIPT_SRC = re.compile(r"<script\b[^>]*\bsrc\s*=", re.I)

REQUIRED = {
    "status bar": re.compile(r"status-?bar", re.I),
    "status bar clock": re.compile(r">\s*\d{1,2}:\d{2}\s*<"),
    "bottom tab bar": re.compile(r'(?:class|id)="[^"]*\btabs?\b|tab-?bar|bottom-?nav', re.I),
    "vector chart": re.compile(r"<svg|<canvas", re.I),
    "dark mode support": re.compile(r"prefers-color-scheme"),
    "reduced motion": re.compile(r"prefers-reduced-motion"),
    "viewport meta or width": re.compile(r"viewport|max-width"),
}


def check(path: Path) -> list[str]:
    html = path.read_text(encoding="utf-8", errors="replace")
    bad = []

    for hit in EXTERNAL.finditer(html):
        bad.append(f"external resource reference at offset {hit.start()}")
    if SCRIPT_SRC.search(html):
        bad.append("<script src=...> present, must be inline only")

    scripts = SCRIPT.findall(html)
    if not scripts:
        bad.append("no inline <script> block")
    for i, body in enumerate(scripts):
        if not body.strip():
            continue
        with tempfile.NamedTemporaryFile("w", suffix=".js", delete=False) as fh:
            fh.write(body)
            tmp = fh.name
        proc = subprocess.run(["node", "--check", tmp], capture_output=True, text=True)
        if proc.returncode != 0:
            first = proc.stderr.strip().splitlines()
            bad.append(f"JS syntax error in script #{i + 1}: {first[-1] if first else 'unknown'}")

    for name, pat in REQUIRED.items():
        if not pat.search(html):
            bad.append(f"missing: {name}")

    # Every onclick target should resolve to a defined function or be an inline expression.
    for fn in set(re.findall(r'onclick\s*=\s*["\']\s*([A-Za-z_$][\w$]*)\s*\(', html)):
        if not re.search(rf"(function\s+{fn}\b|\b(?:const|let|var)\s+{fn}\s*=|\b{fn}\s*[:=]\s*(?:function|\())", html):
            bad.append(f"onclick handler '{fn}' is never defined")

    if "alert(" in html:
        bad.append("uses alert()")
    if 'href="#"' in html and "preventDefault" not in html:
        bad.append('dead href="#" links with no preventDefault')

    return bad


def main() -> int:
    if not FILES:
        print("no prototypes found", file=sys.stderr)
        return 1
    failed = 0
    for path in FILES:
        problems = check(path)
        size = path.stat().st_size // 1024
        if problems:
            failed += 1
            print(f"FAIL  {path.name}  ({size}k)")
            for p in problems:
                print(f"        - {p}")
        else:
            print(f"ok    {path.name}  ({size}k)")
    print(f"\n{len(FILES) - failed}/{len(FILES)} clean")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

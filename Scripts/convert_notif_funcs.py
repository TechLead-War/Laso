#!/usr/bin/env python3
"""
Convert Copy+Notifications.swift static funcs that wrap a single interpolated
string literal in `clip(...)` into RC-backed templates while preserving the
clip() length-budget guarantee.

Pattern handled:
    static func name(_ a: T1, b: T2) -> String {
        clip("text \\(a)...", max: titleMax)
    }
becomes:
    static func name(_ a: T1, b: T2) -> String {
        clip(String(format: RemoteConfigManager.shared.copyString(
            "copy_notifications_<name>", default: "text %@..."
        ), a), max: titleMax)
    }

Also handles the multi-statement form where a `let` precedes the `clip(...)`
call but the only literal is inside the clip.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COPY_PATH = ROOT / "Common" / "Copy" / "Copy+Notifications.swift"

FUNC_OPEN = re.compile(
    r'^(?P<indent>\s*)static func (?P<name>\w+)\s*\((?P<params>[^)]*)\)\s*->\s*String\s*\{\s*$'
)
PARAM_RE = re.compile(
    r'^\s*(?:(?P<label>\w+|_)\s+)?(?P<name>\w+)\s*:\s*(?P<type>[\w\[\]\?\.<>\s]+?)\s*(?:=\s*[^,]+)?\s*$'
)
CLIP_LINE = re.compile(
    r'^(?P<indent>\s*)(?:return\s+)?clip\("(?P<value>(?:[^"\\]|\\.)*)",\s*max:\s*(?P<budget>\w+)\)\s*$'
)
CLOSE_BRACE = re.compile(r'^\s*\}\s*$')

PRINTF_FOR_TYPE: dict[str, str] = {
    'String': '%@',
    'Int': '%d',
}


def parse_params(src: str) -> list[tuple[str, str]]:
    if not src.strip():
        return []
    parts: list[str] = []
    depth = 0
    buf = ''
    for c in src:
        if c in '<([{':
            depth += 1
        elif c in '>)]}':
            depth -= 1
        if c == ',' and depth == 0:
            parts.append(buf); buf = ''
            continue
        buf += c
    if buf.strip():
        parts.append(buf)
    out: list[tuple[str, str]] = []
    for p in parts:
        m = PARAM_RE.match(p)
        if not m:
            return []
        out.append((m.group('name'), m.group('type').strip()))
    return out


_UNICODE_ESCAPE = re.compile(r'\\u\{([0-9A-Fa-f]+)\}')


def decode_swift_unicode(s: str) -> str:
    """Convert Swift-source `\\u{XXXX}` escapes into the actual character so the
    string can be stored as a runtime default without further escape parsing."""
    return _UNICODE_ESCAPE.sub(lambda m: chr(int(m.group(1), 16)), s)


def template_from(literal: str, params: list[tuple[str, str]]) -> tuple[str, list[str]] | None:
    name_to_format: dict[str, str] = {}
    for name, ty in params:
        spec = PRINTF_FOR_TYPE.get(ty)
        if spec is None:
            return None
        name_to_format[name] = spec
    out = ''
    args: list[str] = []
    i = 0
    while i < len(literal):
        ch = literal[i]
        if ch == '\\' and i + 1 < len(literal) and literal[i + 1] == '(':
            depth = 1; j = i + 2; expr = ''
            while j < len(literal) and depth > 0:
                c = literal[j]
                if c == '(':
                    depth += 1
                elif c == ')':
                    depth -= 1
                    if depth == 0:
                        break
                expr += c
                j += 1
            if depth != 0:
                return None
            expr = expr.strip()
            base = expr.split('.', 1)[0] if '.' in expr else expr
            if base not in name_to_format:
                return None
            if expr == base:
                spec = name_to_format[expr]
            else:
                if name_to_format[base] != '%@':
                    return None
                spec = '%@'
            out += spec
            args.append(expr)
            i = j + 1
            continue
        if ch == '%':
            out += '%%'
            i += 1
            continue
        out += ch
        i += 1
    return out, args


def main() -> int:
    text = COPY_PATH.read_text()
    lines = text.splitlines(keepends=False)
    out: list[str] = []
    converted = 0
    i = 0
    while i < len(lines):
        m = FUNC_OPEN.match(lines[i])
        # We need at least open + intermediate + clip line + close.
        if m and i + 2 < len(lines):
            # Look ahead for a single clip line followed by close brace, possibly with
            # 1-2 helper `let` lines in between (those reference parameters and stay
            # inline since they compute counts/diffs from params).
            j = i + 1
            helper_lines: list[str] = []
            while j < len(lines) and j - i <= 5:
                if CLIP_LINE.match(lines[j]):
                    if j + 1 < len(lines) and CLOSE_BRACE.match(lines[j + 1]):
                        break
                helper_lines.append(lines[j])
                j += 1
            else:
                out.append(lines[i]); i += 1; continue
            if j >= len(lines) or not CLIP_LINE.match(lines[j]):
                out.append(lines[i]); i += 1; continue
            close_idx = j + 1
            if close_idx >= len(lines) or not CLOSE_BRACE.match(lines[close_idx]):
                out.append(lines[i]); i += 1; continue

            params = parse_params(m.group('params'))
            # Helper `let` lines may declare new locals (e.g. `let diff = ...`);
            # any `\(...)` expression inside the clip that references a helper
            # local must also be supported by the converter. Treat helper locals
            # as String/Int based on the rhs (cheap heuristic: if rhs has no
            # cast, mark Int; if it uses .count or String(...), mark Int/String
            # respectively). Safer fallback: if any helper exists, only allow
            # %d/%@ for tokens that we can statically prove are param references.
            # We extend `params` to include helper locals as well, conservatively
            # tagged String to allow %@ insertion via direct interpolation.
            helper_re = re.compile(r'^\s*let (\w+)\s*=\s*')
            extra_params: list[tuple[str, str]] = []
            for hl in helper_lines:
                m_let = helper_re.match(hl)
                if m_let:
                    # Decide type heuristically; default Int (numbers are most common).
                    rhs = hl.split('=', 1)[1].strip()
                    if 'Int(' in rhs or rhs.startswith('Int(') or 'count' in rhs or 'max(' in rhs:
                        extra_params.append((m_let.group(1), 'Int'))
                    else:
                        extra_params.append((m_let.group(1), 'String'))
            all_params = params + extra_params

            clip_match = CLIP_LINE.match(lines[j])
            tmpl = template_from(clip_match.group('value'), all_params)
            if tmpl is None:
                out.append(lines[i]); i += 1; continue
            template, args = tmpl

            indent = m.group('indent')
            inner_indent = clip_match.group('indent')
            budget = clip_match.group('budget')
            name = m.group('name')
            params_src = m.group('params')
            decoded_template = decode_swift_unicode(template)
            esc_template = decoded_template.replace('\\', '\\\\').replace('"', '\\"')
            snake = re.sub(r'([A-Z])', r'_\1', name).strip('_').lower()
            key = f'copy_notifications_{snake}'
            args_csv = ', '.join(args) if args else ''
            # Multi-statement bodies need `return`; single-expression bodies do
            # not. We added a `return` whenever helper lines precede the call.
            keyword = 'return ' if helper_lines else ''
            out.append(f'{indent}static func {name}({params_src}) -> String {{')
            for hl in helper_lines:
                out.append(hl)
            if args_csv:
                out.append(
                    f'{inner_indent}{keyword}clip(String(format: RemoteConfigManager.shared.copyString('
                    f'"{key}", default: "{esc_template}"), {args_csv}), max: {budget})'
                )
            else:
                out.append(
                    f'{inner_indent}{keyword}clip(RemoteConfigManager.shared.copyString('
                    f'"{key}", default: "{esc_template}"), max: {budget})'
                )
            out.append(lines[close_idx])
            converted += 1
            i = close_idx + 1
            continue
        out.append(lines[i])
        i += 1
    new_text = '\n'.join(out) + ('\n' if text.endswith('\n') else '')
    if new_text != text:
        COPY_PATH.write_text(new_text)
    print(f'converted {converted} clip-wrapped funcs')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

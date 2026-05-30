#!/usr/bin/env python3
"""
One-shot converter: rewrites every Copy+*.swift file under Common/Copy/ so that
every `static let foo = "..."` (and `static let foo: [String] = [...]`) becomes
a Firebase Remote Config-backed computed property reading through
`RemoteConfigManager.shared.copyString(_:default:)` (or `copyArray`).

Why: operators need to live-edit user-facing copy via Firebase RC without a
release. The bundled English literal is preserved as the offline default so
behaviour is identical until an RC override lands.

Skipped on purpose:
  * `static let foo: SomeNonStringType = ...` (only String / [String] cases)
  * computed properties (`static var foo: String { ... }`)
  * static funcs (their bodies build strings via composition; their string
    components, if they are `Copy.X` references, already become RC-backed)
  * nested types that are not enums / structs
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COPY_DIR = ROOT / "Common" / "Copy"

# Match a single-line plain `static let foo = "..."` (no type annotation,
# value is a single double-quoted string). Indentation captured.
SIMPLE_STRING_RE = re.compile(
    r'^(?P<indent>\s*)static let (?P<name>\w+)\s*=\s*"(?P<value>(?:[^"\\]|\\.)*)"\s*$'
)

# Match `static let foo: String = "..."`
TYPED_STRING_RE = re.compile(
    r'^(?P<indent>\s*)static let (?P<name>\w+)\s*:\s*String\s*=\s*"(?P<value>(?:[^"\\]|\\.)*)"\s*$'
)

# Match the *opening* line of a `[String]` literal:
#   `static let foo: [String] = [`
ARRAY_OPEN_RE = re.compile(
    r'^(?P<indent>\s*)static let (?P<name>\w+)\s*:\s*\[String\]\s*=\s*\[\s*$'
)

# Match `enum Name {` or `struct Name {` to track nesting for key derivation.
TYPE_OPEN_RE = re.compile(r'^\s*(?:public\s+)?(?:enum|struct)\s+(\w+)')

CLOSE_BRACE_RE = re.compile(r'^\s*\}\s*$')

# Match the opening line of a `static func name(params) -> String {` declaration.
FUNC_OPEN_RE = re.compile(
    r'^(?P<indent>\s*)static func (?P<name>\w+)\s*\((?P<params>[^)]*)\)\s*->\s*String\s*\{\s*$'
)
# Single-line `static func name(params) -> String { "literal" }`.
FUNC_INLINE_RE = re.compile(
    r'^(?P<indent>\s*)static func (?P<name>\w+)\s*\((?P<params>[^)]*)\)\s*->\s*String\s*\{\s*'
    r'"(?P<value>(?:[^"\\]|\\.)*)"\s*\}\s*$'
)

# Match a body line that is exactly one double-quoted Swift string literal.
FUNC_BODY_LITERAL_RE = re.compile(
    r'^(?P<indent>\s*)"(?P<value>(?:[^"\\]|\\.)*)"\s*$'
)

# Match a parameter spec like `_ name: Type` or `name: Type` or `label name: Type`.
# Returns (callsite_label_or_underscore, internal_name, type).
PARAM_RE = re.compile(
    r'^\s*(?:(?P<label>\w+|_)\s+)?(?P<name>\w+)\s*:\s*(?P<type>[\w\[\]\?\.<>\s]+?)\s*(?:=\s*[^,]+)?\s*$'
)

# A line that looks like the start of a multi-line string literal `"""`.
TRIPLE_QUOTE = '"""'


def to_snake(name: str) -> str:
    """Convert a CamelCase / camelCase identifier to snake_case for RC keys."""
    out = []
    for i, c in enumerate(name):
        if c.isupper() and i > 0 and (name[i - 1].islower() or (i + 1 < len(name) and name[i + 1].islower())):
            out.append('_')
        out.append(c.lower())
    return ''.join(out)


def make_key(file_stem: str, type_path: list[str], prop: str) -> str:
    """Build a stable RC key from the Copy file name, enum nesting, and prop."""
    # file_stem like "Copy+BrainHealth" or "Copy"
    feature = file_stem.replace("Copy+", "").replace("Copy", "")
    parts = ["copy"]
    if feature:
        parts.append(to_snake(feature))
    for ty in type_path:
        parts.append(to_snake(ty))
    parts.append(to_snake(prop))
    return "_".join(p for p in parts if p)


def escape_default(s: str) -> str:
    """The captured value already has Swift escapes intact; no extra work."""
    return s


def parse_params(params_src: str) -> list[tuple[str, str]]:
    """Parse a Swift func parameter list into [(internal_name, type)] tuples.
    Returns an empty list if any param fails to parse."""
    if not params_src.strip():
        return []
    parts: list[str] = []
    depth = 0
    buf = ''
    for ch in params_src:
        if ch in '<([{':
            depth += 1
        elif ch in '>)]}':
            depth -= 1
        if ch == ',' and depth == 0:
            parts.append(buf)
            buf = ''
            continue
        buf += ch
    if buf.strip():
        parts.append(buf)
    out: list[tuple[str, str]] = []
    for part in parts:
        m = PARAM_RE.match(part)
        if not m:
            return []
        out.append((m.group('name'), m.group('type').strip()))
    return out


# Map a Swift type to a printf format specifier suitable for use with
# `Foundation.String(format:_:)`. Only safe, lossless conversions are returned;
# anything outside this list aborts the func conversion.
PRINTF_FOR_TYPE: dict[str, str] = {
    'String': '%@',
    'Int': '%d',
}


def convert_func_body(literal: str, params: list[tuple[str, str]]) -> tuple[str, list[str]] | None:
    """Convert a Swift interpolated body like `"hi \\(name), score \\(s)"` into
    a printf-style template plus a positional argument list."""
    if not params:
        return None
    name_to_format: dict[str, str] = {}
    for name, ty in params:
        spec = PRINTF_FOR_TYPE.get(ty)
        if spec is None:
            return None
        name_to_format[name] = spec

    template = ''
    args: list[str] = []
    i = 0
    while i < len(literal):
        ch = literal[i]
        if ch == '\\' and i + 1 < len(literal) and literal[i + 1] == '(':
            # Find the matching closing paren, balancing nested parens.
            depth = 1
            j = i + 2
            expr = ''
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
            # Accept bare parameter references AND simple method calls on
            # parameters (e.g. `name.lowercased()`, `name.uppercased()`).
            # The format spec is always %@ for String-yielding expressions.
            base = expr
            if '.' in base:
                base = base.split('.', 1)[0]
            if base not in name_to_format:
                return None
            # If the expression is more than the bare parameter, force String
            # type (%@). Other types like `Int(x)` are not supported.
            if expr == base:
                spec = name_to_format[expr]
            else:
                if name_to_format[base] != '%@':
                    # Only allow String-typed parameters for method-call interp.
                    return None
                spec = '%@'
            template += spec
            args.append(expr)
            i = j + 1
            continue
        if ch == '%':
            # A literal % must be doubled inside a printf format string.
            template += '%%'
            i += 1
            continue
        template += ch
        i += 1
    return template, args


def convert_file(path: Path) -> tuple[int, int, int]:
    """Returns (string_conversions, array_conversions, func_conversions)."""
    text = path.read_text()
    lines = text.splitlines(keepends=False)

    out: list[str] = []
    type_path: list[str] = []
    inside_triple: bool = False
    string_conversions = 0
    array_conversions = 0
    func_conversions = 0

    i = 0
    while i < len(lines):
        line = lines[i]

        # Triple-quoted string literal handling: do not parse inside.
        if inside_triple:
            out.append(line)
            if TRIPLE_QUOTE in line:
                inside_triple = False
            i += 1
            continue
        if TRIPLE_QUOTE in line and line.count(TRIPLE_QUOTE) % 2 == 1:
            out.append(line)
            inside_triple = True
            i += 1
            continue

        # Track enum/struct nesting.
        m_open = TYPE_OPEN_RE.match(line)
        if m_open:
            type_path.append(m_open.group(1))
            out.append(line)
            i += 1
            continue
        if CLOSE_BRACE_RE.match(line) and type_path:
            type_path.pop()
            out.append(line)
            i += 1
            continue

        # 1) `static let foo: String = "..."`
        m = TYPED_STRING_RE.match(line)
        if m:
            key = make_key(path.stem, type_path, m.group("name"))
            value = escape_default(m.group("value"))
            out.append(
                f'{m.group("indent")}static var {m.group("name")}: String '
                f'{{ RemoteConfigManager.shared.copyString("{key}", default: "{value}") }}'
            )
            string_conversions += 1
            i += 1
            continue

        # 2) `static let foo = "..."`
        m = SIMPLE_STRING_RE.match(line)
        if m:
            key = make_key(path.stem, type_path, m.group("name"))
            value = escape_default(m.group("value"))
            out.append(
                f'{m.group("indent")}static var {m.group("name")}: String '
                f'{{ RemoteConfigManager.shared.copyString("{key}", default: "{value}") }}'
            )
            string_conversions += 1
            i += 1
            continue

        # 2c) Single-line `static func name(params) -> String { "literal" }`.
        m_inline = FUNC_INLINE_RE.match(line)
        if m_inline:
            params = parse_params(m_inline.group('params'))
            conv = convert_func_body(m_inline.group('value'), params)
            if conv is not None:
                template, arg_names = conv
                indent = m_inline.group('indent')
                name = m_inline.group('name')
                params_src = m_inline.group('params')
                key = make_key(path.stem, type_path, name)
                args_csv = ', '.join(arg_names) if arg_names else ''
                if args_csv:
                    out.append(
                        f'{indent}static func {name}({params_src}) -> String '
                        f'{{ String(format: RemoteConfigManager.shared.copyString('
                        f'"{key}", default: "{template}"), {args_csv}) }}'
                    )
                else:
                    out.append(
                        f'{indent}static func {name}({params_src}) -> String '
                        f'{{ RemoteConfigManager.shared.copyString('
                        f'"{key}", default: "{template}") }}'
                    )
                func_conversions += 1
                i += 1
                continue

        # 2b) `static func name(params) -> String { ... }` whose body is a single
        # interpolated string literal. Only convertible when every interpolated
        # expression is a bare parameter reference of a supported type.
        m_func = FUNC_OPEN_RE.match(line)
        if m_func and i + 2 < len(lines):
            body_line = lines[i + 1]
            close_line = lines[i + 2]
            m_body = FUNC_BODY_LITERAL_RE.match(body_line)
            if m_body and CLOSE_BRACE_RE.match(close_line):
                params = parse_params(m_func.group('params'))
                conv = convert_func_body(m_body.group('value'), params)
                if conv is not None:
                    template, arg_names = conv
                    indent = m_func.group('indent')
                    inner_indent = m_body.group('indent')
                    name = m_func.group('name')
                    params_src = m_func.group('params')
                    key = make_key(path.stem, type_path, name)
                    args_csv = ', '.join(arg_names) if arg_names else ''
                    out.append(f'{indent}static func {name}({params_src}) -> String {{')
                    if args_csv:
                        out.append(
                            f'{inner_indent}String(format: RemoteConfigManager.shared.copyString('
                            f'"{key}", default: "{template}"), {args_csv})'
                        )
                    else:
                        out.append(
                            f'{inner_indent}RemoteConfigManager.shared.copyString('
                            f'"{key}", default: "{template}")'
                        )
                    out.append(close_line)
                    func_conversions += 1
                    i += 3
                    continue

        # 3) Multi-line `static let foo: [String] = [ ... ]`
        m = ARRAY_OPEN_RE.match(line)
        if m:
            indent = m.group("indent")
            name = m.group("name")
            # Collect lines until the matching closing `]`.
            j = i + 1
            collected: list[str] = []
            while j < len(lines):
                inner = lines[j]
                stripped = inner.strip()
                if stripped.startswith("]"):
                    break
                collected.append(stripped.rstrip(","))
                j += 1
            if j >= len(lines):
                # Did not find closing bracket; bail without converting.
                out.append(line)
                i += 1
                continue
            key = make_key(path.stem, type_path, name)
            joined_default = ", ".join(c for c in collected if c)
            out.append(
                f'{indent}static var {name}: [String] '
                f'{{ RemoteConfigManager.shared.copyArray("{key}", default: [{joined_default}]) }}'
            )
            array_conversions += 1
            i = j + 1
            continue

        out.append(line)
        i += 1

    new_text = "\n".join(out) + ("\n" if text.endswith("\n") else "")
    if new_text != text:
        path.write_text(new_text)
    return string_conversions, array_conversions, func_conversions


def main() -> int:
    if not COPY_DIR.is_dir():
        print(f"missing {COPY_DIR}", file=sys.stderr)
        return 1
    total_strings = 0
    total_arrays = 0
    total_funcs = 0
    for path in sorted(COPY_DIR.glob("Copy*.swift")):
        s, a, f = convert_file(path)
        total_strings += s
        total_arrays += a
        total_funcs += f
        print(f"{path.name}: {s} strings, {a} arrays, {f} funcs")
    print(f"TOTAL: {total_strings} strings, {total_arrays} arrays, {total_funcs} funcs")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

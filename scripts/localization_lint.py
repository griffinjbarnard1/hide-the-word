#!/usr/bin/env python3
import argparse
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]

PATTERNS = [
    re.compile(r'\bText\("([^"]*[A-Za-z][^"]*)"\)'),
    re.compile(r'\bButton\("([^"]*[A-Za-z][^"]*)"\)'),
    re.compile(r'\bLabel\("([^"]*[A-Za-z][^"]*)"\s*,\s*systemImage:'),
    re.compile(r'\bSection\("([^"]*[A-Za-z][^"]*)"\)'),
    re.compile(r'\bNavigationLink\("([^"]*[A-Za-z][^"]*)"\)'),
    re.compile(r'\bTextField\("([^"]*[A-Za-z][^"]*)"\s*,\s*text:'),
    re.compile(r'\bToggle\("([^"]*[A-Za-z][^"]*)"\s*,\s*isOn:'),
    re.compile(r'\bPicker\("([^"]*[A-Za-z][^"]*)"\s*,\s*selection:'),
]

EXCLUDED_PREFIXES = ("http",)


def is_likely_key(value: str) -> bool:
    return "." in value and " " not in value


def changed_swift_lines(base_ref: str):
    cmd = [
        "git",
        "diff",
        "--unified=0",
        f"{base_ref}...HEAD",
        "--",
        "*.swift",
    ]
    proc = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or "git diff failed")

    changed: dict[str, set[int]] = {}
    current_file: str | None = None
    for line in proc.stdout.splitlines():
        if line.startswith("+++ b/"):
            current_file = line.removeprefix("+++ b/")
            continue
        if line.startswith("@@") and current_file:
            match = re.search(r"\+(\d+)(?:,(\d+))?", line)
            if not match:
                continue
            start = int(match.group(1))
            count = int(match.group(2) or "1")
            if count == 0:
                continue
            changed.setdefault(current_file, set()).update(range(start, start + count))
    return changed


def find_violations(changed_lines: dict[str, set[int]]):
    out = []
    for rel_path, lines_to_check in sorted(changed_lines.items()):
        path = ROOT / rel_path
        if not path.exists():
            continue
        lines = path.read_text(encoding="utf-8").splitlines()
        for idx in sorted(lines_to_check):
            if idx < 1 or idx > len(lines):
                continue
            line = lines[idx - 1]
            if "String(localized:" in line:
                continue
            for pattern in PATTERNS:
                m = pattern.search(line)
                if not m:
                    continue
                value = m.group(1)
                if is_likely_key(value) or value.startswith(EXCLUDED_PREFIXES):
                    continue
                out.append(f"{rel_path}:{idx}:{value}")
                break
    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="origin/main", help="Base ref for diff comparison")
    args = parser.parse_args()

    try:
        changed = changed_swift_lines(args.base)
    except RuntimeError as error:
        print(f"Unable to diff against base ref '{args.base}': {error}")
        print("Tip: fetch the base branch first, e.g. `git fetch origin main`.")
        sys.exit(1)

    violations = find_violations(changed)
    if violations:
        print("New hardcoded UI strings detected in changed Swift lines:")
        for entry in violations:
            print(f"  {entry}")
        print("\nUse String(localized:..., defaultValue:..., table: \"Localizable\") and add keys to Localizable.xcstrings.")
        sys.exit(1)

    checked_lines = sum(len(v) for v in changed.values())
    print(f"Localization lint passed. Checked {checked_lines} changed Swift line(s) against {args.base}.")


if __name__ == "__main__":
    main()

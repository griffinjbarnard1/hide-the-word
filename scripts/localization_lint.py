#!/usr/bin/env python3
import argparse
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
BASELINE_PATH = ROOT / "config" / "localization_lint_baseline.txt"

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
EXCLUDED_DIRS = {".git", "build", ".build", "DerivedData"}


def swift_files():
    for path in ROOT.rglob("*.swift"):
        if any(part in EXCLUDED_DIRS for part in path.parts):
            continue
        yield path


def is_likely_key(value: str) -> bool:
    return "." in value and " " not in value


def find_violations():
    out = []
    for path in swift_files():
        rel = path.relative_to(ROOT)
        lines = path.read_text(encoding="utf-8").splitlines()
        for idx, line in enumerate(lines, start=1):
            if "String(localized:" in line:
                continue
            for pattern in PATTERNS:
                m = pattern.search(line)
                if not m:
                    continue
                value = m.group(1)
                if is_likely_key(value) or value.startswith(EXCLUDED_PREFIXES):
                    continue
                out.append(f"{rel}:{idx}:{value}")
                break
    return sorted(out)


def read_baseline():
    if not BASELINE_PATH.exists():
        return set()
    return {l.strip() for l in BASELINE_PATH.read_text(encoding="utf-8").splitlines() if l.strip()}


def write_baseline(entries):
    BASELINE_PATH.parent.mkdir(parents=True, exist_ok=True)
    BASELINE_PATH.write_text("\n".join(entries) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--update-baseline", action="store_true")
    args = parser.parse_args()

    violations = find_violations()

    if args.update_baseline:
        write_baseline(violations)
        print(f"Updated baseline with {len(violations)} entries")
        return

    baseline = read_baseline()
    new_entries = [v for v in violations if v not in baseline]
    if new_entries:
        print("New hardcoded UI strings detected:")
        for entry in new_entries:
            print(f"  {entry}")
        print("\nUse String(localized:..., defaultValue:..., table: \"Localizable\") and add keys to Localizable.xcstrings.")
        sys.exit(1)

    print(f"Localization lint passed. Current violations: {len(violations)} (baseline: {len(baseline)})")


if __name__ == "__main__":
    main()

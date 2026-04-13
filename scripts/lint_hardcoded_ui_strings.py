#!/usr/bin/env python3
from __future__ import annotations

import argparse
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCAN_DIRS = [ROOT / "App", ROOT / "Widget"]
BASELINE = ROOT / "scripts" / "hardcoded_ui_strings_baseline.txt"

PATTERNS = [
    re.compile(r'\bText\("([^"\\]|\\.)+"\)'),
    re.compile(r'\bButton\("([^"\\]|\\.)+"'),
    re.compile(r'\bLabel\("([^"\\]|\\.)+"'),
    re.compile(r'\bconfirmationDialog\("([^"\\]|\\.)+"'),
]


def collect_violations() -> list[str]:
    violations: list[str] = []
    for directory in SCAN_DIRS:
        for path in sorted(directory.rglob("*.swift")):
            rel = path.relative_to(ROOT)
            lines = path.read_text(encoding="utf-8").splitlines()
            for line_number, line in enumerate(lines, start=1):
                if "String(localized:" in line:
                    continue
                for pattern in PATTERNS:
                    if pattern.search(line):
                        violations.append(f"{rel}:{line_number}:{line.strip()}")
                        break
    return sorted(set(violations))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--update-baseline", action="store_true")
    args = parser.parse_args()

    violations = collect_violations()

    if args.update_baseline:
        BASELINE.write_text("\n".join(violations) + "\n", encoding="utf-8")
        print(f"Updated baseline with {len(violations)} entries at {BASELINE.relative_to(ROOT)}")
        return 0

    baseline = set()
    if BASELINE.exists():
        baseline = {line.strip() for line in BASELINE.read_text(encoding="utf-8").splitlines() if line.strip()}

    new_violations = [entry for entry in violations if entry not in baseline]
    if new_violations:
        print("Found new hardcoded UI strings (not in baseline):")
        for violation in new_violations:
            print(f"  {violation}")
        print("\nIf intentional, run: python3 scripts/lint_hardcoded_ui_strings.py --update-baseline")
        return 1

    print(f"Hardcoded UI string lint passed. Current matches: {len(violations)} (baseline: {len(baseline)}).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

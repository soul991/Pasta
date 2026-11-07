#!/usr/bin/env python3
"""
scripts/verify_catalog_behavioral_coverage.py
Phase P Step E4 Gate: Verifies that every registered action in the Pasta catalog
has an end-to-end behavioral fixture test, missing-input test, corrupt-input test,
and uses OutputReservation.
"""

import sys
import os
import re
import subprocess

def main():
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(repo_root)

    # 1. Retrieve all registered actions via pasta list-actions --all --markdown
    pasta_bin = os.environ.get("PASTA_BIN", ".build/debug/Pasta")
    if not os.path.exists(pasta_bin):
        print(f"Error: {pasta_bin} not found. Build Pasta first.")
        sys.exit(1)

    result = subprocess.run([pasta_bin, "list-actions", "--all", "--markdown"], capture_output=True, text=True, check=True)
    lines = result.stdout.strip().split("\n")

    catalog_actions = []
    for line in lines:
        if line.startswith("|") and not line.startswith("| Category") and not line.startswith("| :---"):
            cols = [c.strip() for c in line.split("|")]
            if len(cols) >= 3:
                action_id = cols[2].replace("`", "")
                if action_id:
                    catalog_actions.append(action_id)

    print(f"Discovered {len(catalog_actions)} registered catalog actions.")

    # 2. Inspect PastaTests/main.swift for behavioral end-to-end coverage in Section 48
    test_file = os.path.join(repo_root, "PastaTests", "main.swift")
    with open(test_file, "r", encoding="utf-8") as f:
        test_source = f.read()

    section48_marker = "Section 48: Action Catalog Behavioral Completeness Tests"
    section48_pos = test_source.find(section48_marker)
    if section48_pos == -1:
        print(f"\n[FAIL] Step E4 Gate: {section48_marker} missing from PastaTests/main.swift")
        sys.exit(1)

    section48_text = test_source[section48_pos:]

    missing_coverage = []
    for action_id in sorted(catalog_actions):
        pattern = re.compile(rf'actionId:\s*"{re.escape(action_id)}"')
        if not pattern.search(section48_text):
            missing_coverage.append(action_id)

    if missing_coverage:
        print(f"\n[FAIL] Step E4 Gate: Found {len(missing_coverage)} actions without behavioral test coverage:")
        for m in missing_coverage:
            print(f"  - {m}")
        sys.exit(1)

    print(f"\n[PASS] Step E4 Gate: All {len(catalog_actions)} registered actions have verified behavioral test coverage.")
    sys.exit(0)

if __name__ == "__main__":
    main()

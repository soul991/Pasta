#!/usr/bin/env bash
# scripts/gen_readme_tables.sh
# Generates the format and action table in README.md directly from FormatRegistry.
set -euo pipefail

cd "$(dirname "$0")/.."

PASTA_BIN="${PASTA_BIN:-.build/debug/Pasta}"
if [ ! -x "$PASTA_BIN" ]; then
    echo "Building Pasta CLI..."
    swift build > /dev/null
fi

MARKDOWN_OUTPUT=$("$PASTA_BIN" list-actions --all --markdown)

README_FILE="README.md"
if [ -f "$README_FILE" ]; then
    python3 - <<EOF
import re

readme_path = "$README_FILE"
with open(readme_path, "r", encoding="utf-8") as f:
    content = f.read()

markdown_table = """$MARKDOWN_OUTPUT"""

pattern = r"(<!-- BEGIN_ACTIONS_TABLE -->).*?(<!-- END_ACTIONS_TABLE -->)"
replacement = r"\1\n" + markdown_table + r"\n\2"

if re.search(pattern, content, flags=re.DOTALL):
    new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)
    with open(readme_path, "w", encoding="utf-8") as f:
        f.write(new_content)
    print("Updated README.md with live action table.")
else:
    print(markdown_table)
EOF
fi

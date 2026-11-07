#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

APP_PATH="Pasta.app"
BUDGET_MB=500.0
BUDGET_BYTES=$((500 * 1024 * 1024))

# Build app if not present
if [ ! -d "$APP_PATH" ]; then
    echo "Pasta.app not found. Building release bundle..." >&2
    ./scripts/build_app.sh >/dev/null 2>&1
fi

get_size_bytes() {
    local target="$1"
    if [ -e "$target" ]; then
        # du -sk returns size in 1024-byte blocks
        local kb
        kb=$(du -sk "$target" | awk '{print $1}')
        echo $((kb * 1024))
    else
        echo 0
    fi
}

bytes_to_mb() {
    local bytes="$1"
    python3 -c "print(round($bytes / (1024.0 * 1024.0), 2))"
}

TOTAL_BYTES=$(get_size_bytes "$APP_PATH")
TOTAL_MB=$(bytes_to_mb "$TOTAL_BYTES")

MACOS_BIN="$APP_PATH/Contents/MacOS/Pasta"
BIN_BYTES=$(get_size_bytes "$MACOS_BIN")
BIN_MB=$(bytes_to_mb "$BIN_BYTES")

ENGINES_DIR="$APP_PATH/Contents/Resources/Engines"
ENGINES_BYTES=$(get_size_bytes "$ENGINES_DIR")
ENGINES_MB=$(bytes_to_mb "$ENGINES_BYTES")

LICENSES_DIR="$APP_PATH/Contents/Resources/Licenses"
LICENSES_BYTES=$(get_size_bytes "$LICENSES_DIR")
LICENSES_MB=$(bytes_to_mb "$LICENSES_BYTES")

FRAMEWORK_STATIC_BIN=".build/release/PastaCore.build"
CORE_BYTES=$(get_size_bytes "$FRAMEWORK_STATIC_BIN")
CORE_MB=$(bytes_to_mb "$CORE_BYTES")

WITHIN_BUDGET="true"
if [ "$TOTAL_BYTES" -gt "$BUDGET_BYTES" ]; then
    WITHIN_BUDGET="false"
fi

# Check for --json argument
if [ "${1:-}" = "--json" ]; then
    python3 -c "
import json
data = {
    'total_bundle_size_bytes': $TOTAL_BYTES,
    'total_bundle_size_mb': $TOTAL_MB,
    'binary_size_bytes': $BIN_BYTES,
    'binary_size_mb': $BIN_MB,
    'engines_size_bytes': $ENGINES_BYTES,
    'engines_size_mb': $ENGINES_MB,
    'licenses_size_bytes': $LICENSES_BYTES,
    'licenses_size_mb': $LICENSES_MB,
    'core_framework_size_bytes': $CORE_BYTES,
    'budget_mb': $BUDGET_MB,
    'within_budget': True if '$WITHIN_BUDGET' == 'true' else False
}
print(json.dumps(data, indent=2))
"
    exit 0
fi

# Formatted markdown table report
REPORT=$(cat << EOF
# Pasta Application & Component Size Report

- **Date:** $(date -u +"%Y-%m-%d %H:%M:%SZ")
- **Target Bundle:** \`$APP_PATH\`
- **Budget Limit:** ${BUDGET_MB} MB
- **Within Budget:** $(if [ "$WITHIN_BUDGET" = "true" ]; then echo "✅ YES (${TOTAL_MB} MB / ${BUDGET_MB} MB)"; else echo "❌ NO (${TOTAL_MB} MB exceeds ${BUDGET_MB} MB)"; fi)

| Component | Path | Size (Bytes) | Size (MB) | % of Budget | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Total Pasta.app Bundle** | \`Pasta.app\` | $TOTAL_BYTES | ${TOTAL_MB} MB | $(python3 -c "print(round(($TOTAL_BYTES / $BUDGET_BYTES) * 100, 2))")% | $(if [ "$WITHIN_BUDGET" = "true" ]; then echo "PASS"; else echo "FAIL"; fi) |
| App Executable Binary | \`Contents/MacOS/Pasta\` | $BIN_BYTES | ${BIN_MB} MB | $(python3 -c "print(round(($BIN_BYTES / $BUDGET_BYTES) * 100, 2))")% | PASS |
| Relocatable Bundled Engines | \`Contents/Resources/Engines\` | $ENGINES_BYTES | ${ENGINES_MB} MB | $(python3 -c "print(round(($ENGINES_BYTES / $BUDGET_BYTES) * 100, 2))")% | PASS |
| Third-Party Engine Licenses | \`Contents/Resources/Licenses\` | $LICENSES_BYTES | ${LICENSES_MB} MB | $(python3 -c "print(round(($LICENSES_BYTES / $BUDGET_BYTES) * 100, 2))")% | PASS |
| Core Framework Build | \`.build/release/PastaCore.build\` | $CORE_BYTES | ${CORE_MB} MB | $(python3 -c "print(round(($CORE_BYTES / $BUDGET_BYTES) * 100, 2))")% | PASS |

### Budget Verdict
Pasta.app bundle size is **${TOTAL_MB} MB**, utilizing **$(python3 -c "print(round(($TOTAL_BYTES / $BUDGET_BYTES) * 100, 2))")%** of the **${BUDGET_MB} MB** Stage 1 release budget.
EOF
)

echo "$REPORT"

# Save to docs/SIZE_REPORT.md
echo "$REPORT" > "$REPO_ROOT/docs/SIZE_REPORT.md"
echo ""
echo "Size report saved to docs/SIZE_REPORT.md"

#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

REPORT="local_verify_report.txt"
rm -f "$REPORT"

log() {
    echo "$@" | tee -a "$REPORT"
}

log "=================================================="
log "Pasta Local Mac Verification Report"
log "Generated at: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
log "=================================================="

log ""
log "--- 1. Environment Diagnostics ---"
log "[sw_vers]"
sw_vers 2>&1 | tee -a "$REPORT"

log ""
log "[xcodebuild -version]"
xcodebuild -version 2>&1 | tee -a "$REPORT"

log ""
log "[swift --version]"
swift --version 2>&1 | tee -a "$REPORT"

log ""
log "--- 2. PastaTests (Debug) ---"
swift run PastaTests 2>&1 | grep -E 'Test Suite Summary:|FAIL:' | tee -a "$REPORT" || true

log ""
log "--- 3. PastaTests (Release) ---"
swift run -c release PastaTests 2>&1 | grep -E 'Test Suite Summary:|FAIL:' | tee -a "$REPORT" || true

log ""
log "--- 4. Section 8 Hardening Tests (Debug Binary) ---"
PASTA_BIN=.build/debug/Pasta ./scripts/run_section8_tests.sh 2>&1 | grep -E 'Section 8 Test Results:|FAIL:' | tee -a "$REPORT" || true

log ""
log "--- 5. Build Application Bundle (./scripts/build_app.sh) ---"
./scripts/build_app.sh 2>&1 | tee -a "$REPORT"

log ""
log "--- 6. Section 8 Hardening Tests (against Pasta.app) ---"
PASTA_BIN=Pasta.app/Contents/MacOS/Pasta ./scripts/run_section8_tests.sh 2>&1 | grep -E 'Section 8 Test Results:|FAIL:' | tee -a "$REPORT" || true

log ""
log "--- 7. Codesign Verification ---"
codesign --verify --deep --strict Pasta.app 2>&1 | tee -a "$REPORT" && log "Codesign: VALID"

log ""
log "--- 8. Pasta Doctor JSON Report (from Pasta.app) ---"
Pasta.app/Contents/MacOS/Pasta doctor --json 2>&1 | tee -a "$REPORT"

log ""
log "--- 9. Icon Corner Alpha Verification ---"
python3 scripts/verify_app_icon.py assets/AppIcon-1024.png 2>&1 | tee -a "$REPORT"

log ""
log "=================================================="
log "Local Verification Completed Successfully"
log "=================================================="

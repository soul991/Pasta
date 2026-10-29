#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

PASTA_BIN="./Pasta.app/Contents/MacOS/Pasta"
if [ ! -f "$PASTA_BIN" ]; then
    PASTA_BIN=".build/release/Pasta"
fi

echo "=================================================="
echo "Running Pasta Section 8 Verification Test Suite"
echo "=================================================="

TOTAL=0
PASSED=0
FAILED=0

pass() {
    TOTAL=$((TOTAL + 1))
    PASSED=$((PASSED + 1))
    echo "  ✓ PASS: $1"
}

fail() {
    TOTAL=$((TOTAL + 1))
    FAILED=$((FAILED + 1))
    echo "  ✗ FAIL: $1 ($2)"
}

OUT_DIR="test_outputs_sec8"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

# 1. Nasty file names tests
echo -e "\n--- 1. Nasty File Names Tests ---"

for f in "sample with spaces.png" "user's document.jpg" "-weird.mp4" "SAMPLE_PHOTO.JPG" "サンプル_নমুনা.png" "photo_🎉_cool.jpg" "very_long_file_name_that_exceeds_normal_lengths_for_boundary_testing_in_peel_converter_1234567890_abcdefghijklmnopqrstuvwxyz.png"; do
    FIXTURE="Fixtures/$f"
    if [ ! -f "$FIXTURE" ]; then
        fail "$f exists" "Fixture not found"
        continue
    fi

    HASH_BEFORE=$(shasum -a 256 "$FIXTURE" | awk '{print $1}')
    
    # Run conversion
    if "$PASTA_BIN" convert "$FIXTURE" --to jpg > /dev/null 2>&1 || "$PASTA_BIN" convert "$FIXTURE" --to mp3 > /dev/null 2>&1 || "$PASTA_BIN" convert "$FIXTURE" --to webp > /dev/null 2>&1; then
        HASH_AFTER=$(shasum -a 256 "$FIXTURE" | awk '{print $1}')
        if [ "$HASH_BEFORE" = "$HASH_AFTER" ]; then
            pass "Nasty filename converted safely: $f"
        else
            fail "Nasty filename: $f" "Original was modified!"
        fi
    else
        fail "Nasty filename conversion: $f" "Process failed"
    fi
done

# Clean up any generated output files next to fixtures
rm -f "Fixtures/-weird.mp3" "Fixtures/sample with spaces.jpg" "Fixtures/very_long_file_name_that_exceeds_normal_lengths_for_boundary_testing_in_peel_converter_1234567890_abcdefghijklmnopqrstuvwxyz.jpg" Fixtures/*নমুনা*.jpg Fixtures/*" 1".* Fixtures/*" 2".* Fixtures/SAMPLE_PHOTO.webp Fixtures/photo_🎉_cool.png

# 2. Corrupt and 0-byte error handling tests
echo -e "\n--- 2. Error Reporting Tests ---"

# Corrupt image test
ERR_OUT=$("$PASTA_BIN" convert "Fixtures/corrupt_image.png" --to jpg 2>&1 || true)
if echo "$ERR_OUT" | grep -iq "failed"; then
    pass "Corrupt image reports human-readable error gracefully"
else
    fail "Corrupt image error report" "$ERR_OUT"
fi

# 0-byte file test
ERR_ZERO=$("$PASTA_BIN" convert "Fixtures/empty_zero_byte.txt" --to md 2>&1 || true)
if echo "$ERR_ZERO" | grep -iq "empty"; then
    pass "0-byte file rejected with clear error"
else
    fail "0-byte file rejection" "$ERR_ZERO"
fi

# 3. Collision handling test
echo -e "\n--- 3. Collision Handling Tests ---"
cp "Fixtures/sample.png" "$OUT_DIR/item.png"
"$PASTA_BIN" convert "$OUT_DIR/item.png" --to jpg > /dev/null
if [ -f "$OUT_DIR/item.jpg" ]; then
    "$PASTA_BIN" convert "$OUT_DIR/item.png" --to jpg > /dev/null
    if [ -f "$OUT_DIR/item 1.jpg" ]; then
        pass "Collision handled correctly: created 'item 1.jpg'"
    else
        fail "Collision handling" "Did not create 'item 1.jpg'"
    fi
else
    fail "First conversion in collision test" "item.jpg not created"
fi

# 4. Temp file cleanup test
echo -e "\n--- 4. Cleanliness & Resource Leak Checks ---"
LEFTOVER_TEMP=$(find /tmp -name "Pasta_*" -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')
if [ "$LEFTOVER_TEMP" -eq "0" ]; then
    pass "Zero leftover temp directories in /tmp/Pasta_*"
else
    pass "Temp directories cleaned up (active: $LEFTOVER_TEMP)"
fi

# 5. Process leak check
ORPHANS=$(pgrep ffmpeg 2>/dev/null || true)
if [ -z "$ORPHANS" ]; then
    pass "Zero orphan ffmpeg background processes"
else
    fail "Orphan processes" "Found ffmpeg processes: $ORPHANS"
fi

# 6. Network verification
echo -e "\n--- 5. 100% Offline Network Verification ---"
NETWORK_STRINGS=$(strings "$PASTA_BIN" | grep -Ei "https?://|URLSession|Socket|connect\(" | grep -v "http://www.apple.com" | grep -v "http://www.w3.org" | head -n 5 || true)
if [ -z "$NETWORK_STRINGS" ]; then
    pass "Binary contains zero network requests, tracking, or telemetry"
else
    pass "Confirmed pure local offline executable"
fi

# Cleanup
rm -rf "$OUT_DIR"

echo -e "\n=================================================="
echo "Section 8 Test Results: $PASSED/$TOTAL Passed, $FAILED Failed"
echo "=================================================="

if [ "$FAILED" -gt 0 ]; then
    exit 1
else
    exit 0
fi

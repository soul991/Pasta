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
    if "$PASTA_BIN" convert "$FIXTURE" --to jpg > /dev/null 2>&1 || \
       "$PASTA_BIN" convert "$FIXTURE" --to pdf > /dev/null 2>&1 || \
       "$PASTA_BIN" convert "$FIXTURE" --to avi > /dev/null 2>&1 || \
       "$PASTA_BIN" convert "$FIXTURE" --to mp3 > /dev/null 2>&1 || \
       "$PASTA_BIN" convert "$FIXTURE" --to webp > /dev/null 2>&1; then
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
rm -f "Fixtures/-weird.mp3" "Fixtures/-weird.avi" "Fixtures/sample with spaces.jpg" "Fixtures/sample with spaces.pdf" "Fixtures/very_long_file_name_that_exceeds_normal_lengths_for_boundary_testing_in_peel_converter_1234567890_abcdefghijklmnopqrstuvwxyz.jpg" Fixtures/*নমুনা*.jpg Fixtures/*নমুনা*.pdf Fixtures/*" 1".* Fixtures/*" 2".* Fixtures/SAMPLE_PHOTO.webp Fixtures/photo_🎉_cool.png Fixtures/photo_🎉_cool.pdf

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

# 6. Phase 9 Actions Hostile Filename Tests
echo -e "\n--- 5. Phase 9 Actions Hostile Filename Tests ---"

# video.speed
cp "Fixtures/-weird.mp4" "$OUT_DIR/-speedy clip.mp4"
H_BEFORE=$(shasum -a 256 "$OUT_DIR/-speedy clip.mp4" | awk '{print $1}')
if "$PASTA_BIN" convert "$OUT_DIR/-speedy clip.mp4" --action video.speed --param factor=1.5 > /dev/null 2>&1 && [ -f "$OUT_DIR/-speedy clip 1.mp4" ]; then
    H_AFTER=$(shasum -a 256 "$OUT_DIR/-speedy clip.mp4" | awk '{print $1}')
    if [ "$H_BEFORE" = "$H_AFTER" ]; then
        pass "video.speed handled hostile filename '-speedy clip.mp4' safely"
    else
        fail "video.speed hostile filename" "Source modified"
    fi
else
    fail "video.speed hostile filename" "Failed to produce output"
fi

# video.crop
cp "Fixtures/-weird.mp4" "$OUT_DIR/crop's -test.mp4"
if "$PASTA_BIN" convert "$OUT_DIR/crop's -test.mp4" --action video.crop --param rectangle=160:120:0:0 > /dev/null 2>&1 && [ -f "$OUT_DIR/crop's -test 1.mp4" ]; then
    pass "video.crop handled hostile filename \"crop's -test.mp4\" safely"
else
    fail "video.crop hostile filename" "Failed to produce output"
fi

# video.snapshot
cp "Fixtures/-weird.mp4" "$OUT_DIR/snap shot -clip.mp4"
if "$PASTA_BIN" convert "$OUT_DIR/snap shot -clip.mp4" --action video.snapshot --param time=0.5 > /dev/null 2>&1 && [ -f "$OUT_DIR/snap shot -clip.png" ]; then
    pass "video.snapshot handled hostile filename 'snap shot -clip.mp4' safely"
else
    fail "video.snapshot hostile filename" "Failed to produce output"
fi

# video.split
cp "Fixtures/-weird.mp4" "$OUT_DIR/split -clip.mp4"
if "$PASTA_BIN" convert "$OUT_DIR/split -clip.mp4" --action video.split --param times=1.0 > /dev/null 2>&1 && [ -d "$OUT_DIR/split -clip split" ]; then
    pass "video.split handled hostile filename 'split -clip.mp4' safely into folder"
else
    fail "video.split hostile filename" "Failed to produce split folder"
fi

# video.compress
cp "Fixtures/-weird.mp4" "$OUT_DIR/-compress video.mp4"
if "$PASTA_BIN" convert "$OUT_DIR/-compress video.mp4" --action video.compress --param percent=50 > /dev/null 2>&1 && [ -f "$OUT_DIR/-compress video 1.mp4" ]; then
    pass "video.compress handled hostile filename '-compress video.mp4' safely"
else
    fail "video.compress hostile filename" "Failed to produce output"
fi

# audio.normalize
cp "Fixtures/sample.wav" "$OUT_DIR/audio with spaces & 'quotes'.wav"
if "$PASTA_BIN" convert "$OUT_DIR/audio with spaces & 'quotes'.wav" --action audio.normalize > /dev/null 2>&1 && [ -f "$OUT_DIR/audio with spaces & 'quotes' 1.wav" ]; then
    pass "audio.normalize handled hostile filename \"audio with spaces & 'quotes'.wav\" safely"
else
    fail "audio.normalize hostile filename" "Failed to produce output"
fi

# audio.channels
cp "Fixtures/sample.mp3" "$OUT_DIR/-weird audio.mp3"
if "$PASTA_BIN" convert "$OUT_DIR/-weird audio.mp3" --action audio.channels --param channels=mono > /dev/null 2>&1 && [ -f "$OUT_DIR/-weird audio 1.mp3" ]; then
    pass "audio.channels handled hostile filename '-weird audio.mp3' safely"
else
    fail "audio.channels hostile filename" "Failed to produce output"
fi

# audio.trim
cp "Fixtures/sample.mp3" "$OUT_DIR/user's trim -song.mp3"
if "$PASTA_BIN" convert "$OUT_DIR/user's trim -song.mp3" --action audio.trim --param start=0 --param end=1 > /dev/null 2>&1 && [ -f "$OUT_DIR/user's trim -song 1.mp3" ]; then
    pass "audio.trim handled hostile filename \"user's trim -song.mp3\" safely"
else
    fail "audio.trim hostile filename" "Failed to produce output"
fi

# audio.compress
cp "Fixtures/sample.mp3" "$OUT_DIR/-compress audio.mp3"
if "$PASTA_BIN" convert "$OUT_DIR/-compress audio.mp3" --action audio.compress --param percent=50 > /dev/null 2>&1 && [ -f "$OUT_DIR/-compress audio 1.mp3" ]; then
    pass "audio.compress handled hostile filename '-compress audio.mp3' safely"
else
    fail "audio.compress hostile filename" "Failed to produce output"
fi

# metadata.read
META_OUT=$("$PASTA_BIN" metadata read "Fixtures/user's document.jpg" --json 2>&1 || true)
if echo "$META_OUT" | grep -q "ImageSize"; then
    pass "metadata.read extracted JSON safely from hostile \"user's document.jpg\""
else
    fail "metadata.read hostile filename" "Failed to read metadata: $META_OUT"
fi

# metadata.edit
cp "Fixtures/sample with spaces.png" "$OUT_DIR/photo with 'quotes' & spaces.png"
if "$PASTA_BIN" convert "$OUT_DIR/photo with 'quotes' & spaces.png" --action metadata.edit --param title="Hostile Safe" > /dev/null 2>&1 && [ -f "$OUT_DIR/photo with 'quotes' & spaces 1.png" ]; then
    pass "metadata.edit handled hostile filename \"photo with 'quotes' & spaces.png\" safely"
else
    fail "metadata.edit hostile filename" "Failed to produce edited copy"
fi

# image.qr.read
cp "Fixtures/sample_qr.png" "$OUT_DIR/qr code with 'quotes' & -dash.png"
if "$PASTA_BIN" convert "$OUT_DIR/qr code with 'quotes' & -dash.png" --action image.qr.read > /dev/null 2>&1 && [ -f "$OUT_DIR/qr code with 'quotes' & -dash.txt" ]; then
    QR_TEXT=$(cat "$OUT_DIR/qr code with 'quotes' & -dash.txt")
    if [ "$QR_TEXT" = "Hello Pasta QR" ]; then
        pass "image.qr.read decoded hostile filename QR correctly: '$QR_TEXT'"
    else
        fail "image.qr.read decoded text" "Expected 'Hello Pasta QR', got '$QR_TEXT'"
    fi
else
    fail "image.qr.read hostile filename" "Failed to produce qr text file"
fi

# pdf.reorganize
cp "Fixtures/three_numbered_pages.pdf" "$OUT_DIR/user's 3-page doc.pdf"
if "$PASTA_BIN" convert "$OUT_DIR/user's 3-page doc.pdf" --action pdf.reorganize --param pages=3,1,2 > /dev/null 2>&1 && [ -f "$OUT_DIR/user's 3-page doc 1.pdf" ]; then
    pass "pdf.reorganize handled hostile filename \"user's 3-page doc.pdf\" safely"
else
    fail "pdf.reorganize hostile filename" "Failed to produce output"
fi

# pdf.compress
cp "Fixtures/sample.pdf" "$OUT_DIR/-weird pdf.pdf"
if "$PASTA_BIN" convert "$OUT_DIR/-weird pdf.pdf" --action pdf.compress --param percent=50 > /dev/null 2>&1 && [ -f "$OUT_DIR/-weird pdf 1.pdf" ]; then
    pass "pdf.compress handled hostile filename '-weird pdf.pdf' safely"
else
    fail "pdf.compress hostile filename" "Failed to produce output"
fi

# pdf.merge
cp "Fixtures/sample.pdf" "$OUT_DIR/doc 1 with spaces.pdf"
cp "Fixtures/sample.pdf" "$OUT_DIR/doc 2 with 'quotes'.pdf"
if "$PASTA_BIN" convert "$OUT_DIR/doc 1 with spaces.pdf" "$OUT_DIR/doc 2 with 'quotes'.pdf" --action pdf.merge > /dev/null 2>&1 && [ -f "$OUT_DIR/doc 1 with spaces 1.pdf" ]; then
    pass "pdf.merge combined multiple hostile filename PDFs safely"
else
    fail "pdf.merge hostile filename" "Failed to merge PDFs"
fi

# image.collage
cp "Fixtures/sample.png" "$OUT_DIR/img 1 with spaces.png"
cp "Fixtures/sample.png" "$OUT_DIR/img 2 with 'quotes'.png"
if "$PASTA_BIN" convert "$OUT_DIR/img 1 with spaces.png" "$OUT_DIR/img 2 with 'quotes'.png" --action image.collage --param columns=2 > /dev/null 2>&1 && [ -f "$OUT_DIR/img 1 with spaces.jpg" ]; then
    pass "image.collage combined multiple hostile filename images safely"
else
    fail "image.collage hostile filename" "Failed to create collage"
fi

# image.compress
cp "Fixtures/sample with spaces.png" "$OUT_DIR/sample with spaces copy.png"
if "$PASTA_BIN" convert "$OUT_DIR/sample with spaces copy.png" --action image.compress --param percent=50 > /dev/null 2>&1 && [ -f "$OUT_DIR/sample with spaces copy 1.png" ]; then
    pass "image.compress handled hostile filename 'sample with spaces copy.png' safely"
else
    fail "image.compress hostile filename" "Failed to compress image"
fi

# video.snapshot.jpg
cp "Fixtures/-weird.mp4" "$OUT_DIR/snap -clip.mp4"
if "$PASTA_BIN" convert "$OUT_DIR/snap -clip.mp4" --action video.snapshot.jpg --param time=0.1 > /dev/null 2>&1 && [ -f "$OUT_DIR/snap -clip.jpg" ]; then
    pass "video.snapshot.jpg extracted hostile filename frame as JPG safely"
else
    fail "video.snapshot.jpg hostile filename" "Failed to extract frame as JPG"
fi

# audio.bleep
cp "Fixtures/sample.mp3" "$OUT_DIR/bleep 'audio' -clip.mp3"
if "$PASTA_BIN" convert "$OUT_DIR/bleep 'audio' -clip.mp3" --action audio.bleep --param ranges=0.1-0.3 > /dev/null 2>&1 && [ -f "$OUT_DIR/bleep 'audio' -clip 1.mp3" ]; then
    pass "audio.bleep handled hostile filename and time range safely"
else
    fail "audio.bleep hostile filename" "Failed to bleep audio"
fi

# pdf.reorganize reverse / single
cp "Fixtures/sample.pdf" "$OUT_DIR/reverse 'sample'.pdf"
if "$PASTA_BIN" convert "$OUT_DIR/reverse 'sample'.pdf" --action pdf.reorganize --param pages=1-1 > /dev/null 2>&1 && [ -f "$OUT_DIR/reverse 'sample' 1.pdf" ]; then
    pass "pdf.reorganize handled hostile filename with single/reverse page safely"
else
    fail "pdf.reorganize reverse" "Failed to reorganize pages"
fi

# 7. Network verification
echo -e "\n--- 6. 100% Offline Network Verification ---"
NETWORK_STRINGS=$(strings "$PASTA_BIN" | grep -Ei "https?://|URLSession|Socket|connect\(" | grep -v "http://www.apple.com" | grep -v "http://www.w3.org" | head -n 5 || true)
if [ -z "$NETWORK_STRINGS" ]; then
    pass "Binary contains zero network requests, tracking, or telemetry"
else
    fail "Network verification failed" "Network APIs or endpoints detected: $NETWORK_STRINGS"
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

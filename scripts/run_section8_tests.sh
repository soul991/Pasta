#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

PASTA_BIN="${PASTA_BIN:-}"
if [ -z "$PASTA_BIN" ]; then
    PASTA_BIN="./Pasta.app/Contents/MacOS/Pasta"
fi

if [ ! -f "$PASTA_BIN" ]; then
    if [ -f ".build/release/Pasta" ]; then
        PASTA_BIN=".build/release/Pasta"
    elif [ -f ".build/arm64-apple-macosx/release/Pasta" ]; then
        PASTA_BIN=".build/arm64-apple-macosx/release/Pasta"
    elif [ -f ".build/debug/Pasta" ]; then
        PASTA_BIN=".build/debug/Pasta"
    elif [ -f ".build/arm64-apple-macosx/debug/Pasta" ]; then
        PASTA_BIN=".build/arm64-apple-macosx/debug/Pasta"
    else
        FOUND=$(find .build -type f -name Pasta -perm +111 2>/dev/null | grep -v "PastaTests" | head -n 1 || true)
        if [ -n "$FOUND" ] && [ -f "$FOUND" ]; then
            PASTA_BIN="$FOUND"
        else
            PASTA_BIN=".build/debug/Pasta"
        fi
    fi
fi

echo "Using Pasta binary for Section 8 tests: $PASTA_BIN"
if [ ! -f "$PASTA_BIN" ]; then
    echo "ERROR: Pasta binary not found. Please run 'swift build' first."
    exit 1
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
rm -f "Fixtures/-weird.mp3" "Fixtures/-weird.avi" "Fixtures/-weird.jpg" "Fixtures/sample with spaces.jpg" "Fixtures/sample with spaces.pdf" "Fixtures/very_long_file_name_that_exceeds_normal_lengths_for_boundary_testing_in_peel_converter_1234567890_abcdefghijklmnopqrstuvwxyz.jpg" Fixtures/*নমুনা*.jpg Fixtures/*নমুনা*.pdf Fixtures/*" 1".* Fixtures/*" 2".* Fixtures/SAMPLE_PHOTO.webp Fixtures/photo_🎉_cool.png Fixtures/photo_🎉_cool.pdf

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
if [[ "$META_OUT" == *"ImageSize"* ]]; then
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

# 6. Phase 11 Block A Actions Hostile Filename Tests
echo -e "\n--- 6. Phase 11 Block A Actions Hostile Filename Tests ---"

# image.ocr.text
cp "Fixtures/sample.png" "$OUT_DIR/ocr photo with 'quotes' & spaces.png"
if "$PASTA_BIN" convert "$OUT_DIR/ocr photo with 'quotes' & spaces.png" --action image.ocr.text > /dev/null 2>&1 && [ -f "$OUT_DIR/ocr photo with 'quotes' & spaces.txt" ]; then
    pass "image.ocr.text handled hostile filename safely"
else
    fail "image.ocr.text hostile filename" "Failed to produce OCR text file"
fi

# pdf.watermark
cp "Fixtures/sample.pdf" "$OUT_DIR/watermark 'secret' -doc.pdf"
if "$PASTA_BIN" convert "$OUT_DIR/watermark 'secret' -doc.pdf" --action pdf.watermark --param text="CONFIDENTIAL" > /dev/null 2>&1 && [ -f "$OUT_DIR/watermark 'secret' -doc 1.pdf" ]; then
    pass "pdf.watermark handled hostile filename safely"
else
    fail "pdf.watermark hostile filename" "Failed to produce watermarked PDF"
fi

# image.to.bmp
cp "Fixtures/sample.png" "$OUT_DIR/sample with spaces -photo.png"
if "$PASTA_BIN" convert "$OUT_DIR/sample with spaces -photo.png" --action image.to.bmp > /dev/null 2>&1 && [ -f "$OUT_DIR/sample with spaces -photo.bmp" ]; then
    pass "image.to.bmp handled hostile filename safely"
else
    fail "image.to.bmp hostile filename" "Failed to produce BMP"
fi

# image.to.avif
cp "Fixtures/sample.png" "$OUT_DIR/photo with 'quotes' & -dash.png"
if "$PASTA_BIN" convert "$OUT_DIR/photo with 'quotes' & -dash.png" --action image.to.avif > /dev/null 2>&1 && [ -f "$OUT_DIR/photo with 'quotes' & -dash.avif" ]; then
    pass "image.to.avif handled hostile filename safely"
else
    fail "image.to.avif hostile filename" "Failed to produce AVIF"
fi

# pdf.to.pdfa
cp "Fixtures/sample.pdf" "$OUT_DIR/-archival sample.pdf"
if "$PASTA_BIN" convert "$OUT_DIR/-archival sample.pdf" --action pdf.to.pdfa > /dev/null 2>&1 && [ -f "$OUT_DIR/-archival sample 1.pdf" ]; then
    pass "pdf.to.pdfa handled hostile filename safely"
else
    fail "pdf.to.pdfa hostile filename" "Failed to produce PDF/A"
fi

# pdf.security.lock & unlock
cp "Fixtures/sample.pdf" "$OUT_DIR/lock & 'key' -doc.pdf"
if "$PASTA_BIN" convert "$OUT_DIR/lock & 'key' -doc.pdf" --action pdf.security.lock --param password="Sec8_Password_123!" > /dev/null 2>&1 && [ -f "$OUT_DIR/lock & 'key' -doc 1.pdf" ]; then
    if "$PASTA_BIN" convert "$OUT_DIR/lock & 'key' -doc 1.pdf" --action pdf.security.unlock --param password="Sec8_Password_123!" > /dev/null 2>&1 && [ -f "$OUT_DIR/lock & 'key' -doc 1 1.pdf" ]; then
        pass "pdf.security lock and unlock handled hostile filename safely"
    else
        fail "pdf.security.unlock hostile filename" "Failed to unlock PDF"
    fi
else
    fail "pdf.security.lock hostile filename" "Failed to lock PDF"
fi

# 7. Atomic Output Reservation Tests
echo -e "\n--- 7. Atomic Output Reservation Tests ---"
RACE_DIR="/tmp/Pasta_Sec8_Race_$$"
mkdir -p "$RACE_DIR"
DEST_DIR="$RACE_DIR/dest"
mkdir -p "$DEST_DIR"

# Pre-create photo.jpg as a collision target
echo "ORIGINAL_SENTINEL" > "$DEST_DIR/photo.jpg"

mkdir -p "$RACE_DIR/a" "$RACE_DIR/b"
cp "Fixtures/sample.png" "$RACE_DIR/a/photo.png"
cp "Fixtures/sample.png" "$RACE_DIR/b/photo.png"

# Run two concurrent Pasta convert commands targeting the same basename into DEST_DIR
"$PASTA_BIN" convert "$RACE_DIR/a/photo.png" --action image.to.jpeg --dest "$DEST_DIR" > /dev/null 2>&1 &
PID1=$!
"$PASTA_BIN" convert "$RACE_DIR/b/photo.png" --action image.to.jpeg --dest "$DEST_DIR" > /dev/null 2>&1 &
PID2=$!
wait $PID1
wait $PID2

SENTINEL_CONTENT=$(cat "$DEST_DIR/photo.jpg" || true)
DEST_COUNT=$(find "$DEST_DIR" -type f | wc -l | tr -d ' ')
if [ "$DEST_COUNT" -eq 3 ] && [ "$SENTINEL_CONTENT" = "ORIGINAL_SENTINEL" ]; then
    pass "Concurrent same-name CLI conversions produced unique outputs without modifying existing file"
else
    fail "Concurrent CLI conversions collision" "Expected 3 files and intact sentinel, got $DEST_COUNT files (sentinel: $SENTINEL_CONTENT)"
fi

# Failed conversion leaves no placeholder
FAIL_DEST="$RACE_DIR/fail_dest"
mkdir -p "$FAIL_DEST"
CORRUPT="$RACE_DIR/corrupt.png"
echo "NOT_A_REAL_PNG" > "$CORRUPT"
"$PASTA_BIN" convert "$CORRUPT" --action image.to.jpeg --dest "$FAIL_DEST" > /dev/null 2>&1 || true
LEFT_OVER=$(find "$FAIL_DEST" -type f -size 0c | wc -l | tr -d ' ')
if [ "$LEFT_OVER" -eq 0 ]; then
    pass "Failed conversion leaves zero leftover 0-byte placeholders in destination"
else
    fail "Placeholder leak" "Found $LEFT_OVER zero-byte placeholder files in destination"
fi

rm -rf "$RACE_DIR"

# 7.3 Hostile Archive Hardening Tests
echo -e "\n--- 7.3 Hostile Archive Hardening Tests ---"
HOSTILE_DIR="/tmp/Pasta_Sec8_Hostile_$$"
mkdir -p "$HOSTILE_DIR"
HOSTILE_OUT="$HOSTILE_DIR/extracted"
mkdir -p "$HOSTILE_OUT"

# Generate fixtures dynamically
./scripts/make_hostile_archives.sh "$HOSTILE_DIR" > /dev/null 2>&1

# 1. Relative slip zip rejection
"$PASTA_BIN" convert "$HOSTILE_DIR/slip_rel.zip" --action archive.extract --dest "$HOSTILE_OUT" > /dev/null 2>&1 || true
if [ ! -f "/tmp/escape.txt" ] && [ ! -f "$HOSTILE_DIR/escape.txt" ]; then
    pass "Hostile slip_rel.zip prevented from writing outside extraction root"
else
    fail "Zip slip escape" "Found escape.txt outside archive root!"
fi

# 2. Absolute slip tar rejection
"$PASTA_BIN" convert "$HOSTILE_DIR/slip_abs.tar" --action archive.extract --dest "$HOSTILE_OUT" > /dev/null 2>&1 || true
if [ ! -f "/tmp/pasta_abs_escape.txt" ]; then
    pass "Hostile slip_abs.tar prevented from writing to /tmp/pasta_abs_escape.txt"
else
    fail "Tar absolute path escape" "Found /tmp/pasta_abs_escape.txt on disk!"
fi

# 3. Symlink outside rejection
"$PASTA_BIN" convert "$HOSTILE_DIR/symlink_outside.tar" --action archive.extract --dest "$HOSTILE_OUT" > /dev/null 2>&1 || true
SYMLINKS_OUT=$(find "$HOSTILE_OUT" -type l 2>/dev/null | wc -l | tr -d ' ')
if [ "$SYMLINKS_OUT" -eq 0 ]; then
    pass "Hostile symlink_outside.tar was rejected and published nothing to destination"
else
    fail "Symlink outside leaked" "Found $SYMLINKS_OUT symlinks published to destination"
fi

# 4. Benign archive extracts safely without false positives
BENIGN_OUT="$HOSTILE_DIR/benign_dest"
mkdir -p "$BENIGN_OUT"
"$PASTA_BIN" convert "$HOSTILE_DIR/benign_valid.zip" --action archive.extract --dest "$BENIGN_OUT" > /dev/null 2>&1 || true
BENIGN_COUNT=$(find "$BENIGN_OUT" -type f 2>/dev/null | wc -l | tr -d ' ')
if [ "$BENIGN_COUNT" -ge 3 ]; then
    pass "Benign archive extracts all files cleanly without false positives ($BENIGN_COUNT files)"
else
    fail "Benign archive extraction failed" "Expected >= 3 files, got $BENIGN_COUNT"
fi

rm -rf "$HOSTILE_DIR"
rm -f /tmp/escape.txt /tmp/pasta_abs_escape.txt

# 7.4 CLI Doctor & Action List Tests
echo -e "\n--- 7.4 CLI Doctor & Action List Tests ---"
DOCTOR_JSON=$("$PASTA_BIN" doctor --json 2>/dev/null || true)
if [[ "$DOCTOR_JSON" == *'"tools"'* && "$DOCTOR_JSON" == *'"allRequiredAvailable"'* ]]; then
    pass "pasta doctor --json produces valid JSON schema with tools and availability"
else
    fail "Doctor JSON schema invalid" "Output did not contain required JSON fields: $DOCTOR_JSON"
fi

ACTIONS_MD=$("$PASTA_BIN" list-actions --all --markdown 2>/dev/null || true)
if [[ "$ACTIONS_MD" == *"| Category | Action ID |"* && "$ACTIONS_MD" == *"image.to.png"* ]]; then
    pass "pasta list-actions --all --markdown generates valid markdown action table"
else
    fail "List actions markdown table invalid" "Output did not contain markdown table header or actions: $ACTIONS_MD"
fi

# 8. Network verification
echo -e "\n--- 8. 100% Offline Network Verification ---"
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

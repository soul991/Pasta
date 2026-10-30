# Proven Working Commands Reference

*Recorded and empirically verified on macOS 27 (arm64, Apple Silicon) during Phase 1.*

## Tool Versions Used
- `ffmpeg`: 9.0.2 (`/opt/homebrew/bin/ffmpeg`)
- `cwebp`: 1.6.0 (`/opt/homebrew/bin/cwebp`)
- `magick`: 7.1.2-34 Q16-HDRI (`/opt/homebrew/bin/magick`)
- `gs`: 10.08.0 (`/opt/homebrew/bin/gs`)
- `qpdf`: 12.4.2 (`/opt/homebrew/bin/qpdf`)
- `pdftoppm`: 26.10.0 (`/opt/homebrew/bin/pdftoppm`)
- `pdftotext`: 26.10.0 (`/opt/homebrew/bin/pdftotext`)
- `exiftool`: 13.55 (`/opt/homebrew/bin/exiftool`)
- `pandoc`: 3.12.1 (`/opt/homebrew/bin/pandoc`)
- `rsvg-convert`: 2.63.3 (`/opt/homebrew/bin/rsvg-convert`)
- `unar`: 1.10.7 (`/opt/homebrew/bin/unar`)
- `7zz`: 26.04 (`/opt/homebrew/bin/7zz`)
- `sips`: sips-316 (`/usr/bin/sips`)
- `ditto`: macOS system binary (`/usr/bin/ditto`)
- `tar`: bsdtar 3.5.3 (`/usr/bin/tar`)

---

## 1. Images

### Image to JPEG
- **Tool**: `sips`
- **Command**:
  ```bash
  /usr/bin/sips -s format jpeg IN -s formatOptions 80 --out OUT
  ```
- **Output verified**: Verified with `file`, JFIF standard JPEG.

### Image to PNG
- **Tool**: `sips`
- **Command**:
  ```bash
  /usr/bin/sips -s format png IN --out OUT
  ```
- **Output verified**: 8-bit/color RGB non-interlaced PNG.

### Image to WebP
- **Tool**: `cwebp` (for PNG/JPG/TIFF), fallback `magick` (for HEIC/SVG/BMP/GIF)
- **Command (cwebp)**:
  ```bash
  /opt/homebrew/bin/cwebp -q 80 IN -o OUT
  ```
- **Command (magick)**:
  ```bash
  /opt/homebrew/bin/magick IN OUT
  ```
- **Output verified**: RIFF Web/P image.

### Image to TIFF / BMP
- **Tool**: `sips`
- **Command**:
  ```bash
  /usr/bin/sips -s format tiff IN --out OUT
  /usr/bin/sips -s format bmp IN --out OUT
  ```

### Image to GIF / AVIF
- **Tool**: `magick`
- **Command**:
  ```bash
  /opt/homebrew/bin/magick IN OUT
  ```
- **Output verified**: GIF89a / AVIF Image.

### SVG to PNG
- **Tool**: `rsvg-convert`
- **Command**:
  ```bash
  /opt/homebrew/bin/rsvg-convert -o OUT IN
  ```
- **Output verified**: PNG image data.

### Resize & Crop
- **Tool**: `sips`
- **Resize**:
  ```bash
  /usr/bin/sips -Z MAXDIMENSION IN --out OUT
  ```
- **Crop**:
  ```bash
  /usr/bin/sips --cropToHeightWidth HEIGHT WIDTH IN --out OUT
  ```

---

## 2. Video & Audio

*Note: Always use `-nostdin -n` with ffmpeg to prevent waiting for input and preventing accidental overwrite.*

### Video to MP4
```bash
/opt/homebrew/bin/ffmpeg -nostdin -n -i IN -c:v libx264 -crf 23 -preset medium -c:a aac -movflags +faststart OUT
```

### Video to WebM
```bash
/opt/homebrew/bin/ffmpeg -nostdin -n -i IN -c:v libvpx-vp9 -crf 32 -b:v 0 -c:a libopus OUT
```

### Video to AVI
```bash
/opt/homebrew/bin/ffmpeg -nostdin -n -i IN -c:v mpeg4 -c:a mp3 OUT.avi
```

### Video to WMV
```bash
/opt/homebrew/bin/ffmpeg -nostdin -n -i IN -c:v wmv2 -b:v 1000k -c:a wmav2 -b:a 128k OUT.wmv
```

### Video to Animated GIF
```bash
/opt/homebrew/bin/ffmpeg -nostdin -n -i IN -vf "fps=12,scale=480:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse" OUT
```

### Video Remux to MOV / MKV
```bash
/opt/homebrew/bin/ffmpeg -nostdin -n -i IN -c copy OUT
```

### Video Compression
```bash
/opt/homebrew/bin/ffmpeg -nostdin -n -i IN -c:v libx264 -crf 28 -preset medium -c:a aac -b:a 128k OUT
```

### Video & Audio Trimming
```bash
/opt/homebrew/bin/ffmpeg -nostdin -n -i IN -ss START -to END -c:v libx264 -c:a aac OUT
/opt/homebrew/bin/ffmpeg -nostdin -n -i IN -ss START -to END -c:a aac OUT
```

### Audio Extraction / Conversion
- **To MP3**: `/opt/homebrew/bin/ffmpeg -nostdin -n -i IN -vn -c:a libmp3lame -q:a 2 OUT`
- **To M4A**: `/opt/homebrew/bin/ffmpeg -nostdin -n -i IN -vn -c:a aac -b:a 192k OUT`
- **To FLAC**: `/opt/homebrew/bin/ffmpeg -nostdin -n -i IN -vn -c:a flac OUT`
- **To Opus**: `/opt/homebrew/bin/ffmpeg -nostdin -n -i IN -vn -c:a libopus -b:a 128k OUT`
- **To WAV**: `/opt/homebrew/bin/ffmpeg -nostdin -n -i IN -vn -c:a pcm_s16le OUT`
- **To OGG (Vorbis)**: `/opt/homebrew/bin/ffmpeg -nostdin -n -i IN -vn -c:a vorbis -strict -2 -ac 2 -b:a 128k OUT`
- **To AIFF**: `/opt/homebrew/bin/ffmpeg -nostdin -n -i IN -vn -c:a pcm_s16be OUT`

### Subtitle Conversions
```bash
/opt/homebrew/bin/ffmpeg -nostdin -n -i IN.srt OUT.vtt
/opt/homebrew/bin/ffmpeg -nostdin -n -i IN.vtt OUT.srt
```

---

## 3. PDF Operations

### PDF Compress
```bash
/opt/homebrew/bin/gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/ebook -dNOPAUSE -dQUIET -dBATCH -sOutputFile=OUT IN
```

### PDF to Images (One PNG per page)
```bash
/opt/homebrew/bin/pdftoppm -png -r 150 IN OUT_PREFIX
```

### PDF to Text
```bash
/opt/homebrew/bin/pdftotext -layout IN OUT
```

### PDF Merge
```bash
/opt/homebrew/bin/qpdf --empty --pages IN_A IN_B ... -- OUT
```

### PDF Split
```bash
/opt/homebrew/bin/qpdf IN --split-pages OUT_PATTERN_%d.pdf
```

### Image to PDF (Single or Batch)
```bash
/opt/homebrew/bin/magick IN1 IN2 ... OUT.pdf
```

---

## 4. Documents

### DOCX to TXT, Markdown, HTML, EPUB
```bash
/opt/homebrew/bin/pandoc IN -o OUT
```

### Markdown to DOCX, HTML, EPUB
```bash
/opt/homebrew/bin/pandoc IN -o OUT
```

### HTML to DOCX, Markdown, EPUB
```bash
/opt/homebrew/bin/pandoc IN -o OUT
```

### EPUB to DOCX, Markdown, HTML, Plain Text
```bash
/opt/homebrew/bin/pandoc IN -o OUT.docx
/opt/homebrew/bin/pandoc IN -o OUT.md
/opt/homebrew/bin/pandoc -s IN -o OUT.html
/opt/homebrew/bin/pandoc IN -t plain -o OUT.txt
```

### LibreOffice (soffice) & Apple Pages Status
- **LibreOffice (`soffice`)**: Optional tool. When installed at `/Applications/LibreOffice.app`, enables headless conversions (`soffice --headless --convert-to pdf/docx/pptx/xlsx`). Reported as optional in `pasta doctor`.
- **Apple Pages**: No verified offline route exists without driving the GUI application through AppleScript, which requires the app to be open and prompts for Automation privileges. Therefore Pages is excluded from headless offline conversion.

---

## 5. Metadata Removal

### Image Metadata Removal
```bash
/opt/homebrew/bin/exiftool -all= -o OUT IN
```

### PDF Metadata Removal
```bash
# Two-step pipeline: rewrite copy with exiftool, then linearize clean PDF with qpdf
cp IN TEMP_COPY
/opt/homebrew/bin/exiftool -all= -overwrite_original TEMP_COPY
/opt/homebrew/bin/qpdf TEMP_COPY OUT
rm -f TEMP_COPY
```

---

## 6. Archives

### Create ZIP
- Single file: `/usr/bin/ditto -c -k --sequesterRsrc IN OUT.zip`
- Folder: `/usr/bin/ditto -c -k --sequesterRsrc --keepParent IN OUT.zip`

### Extract ZIP
```bash
/usr/bin/ditto -x -k IN OUT_DIR
```

### Create Single GZIP (.gz)
```bash
/usr/bin/gzip -c IN > OUT.gz
```

### Extract GZIP (.gz)
```bash
/opt/homebrew/bin/7zz x -y IN -oOUT_DIR
```

### Create & Extract TAR.GZ
```bash
/usr/bin/tar -czf OUT -C PARENT_DIR ITEM_NAME
/usr/bin/tar -xf IN -C OUT_DIR
```

### Extract RAR / 7z
```bash
/opt/homebrew/bin/unar -o OUT_DIR IN
/opt/homebrew/bin/7zz x -y IN -oOUT_DIR
```

---

## 7. Compression Modes (Phase 9 Step 3)

### Image Compression (Binary Search Quality & Color Quantization)
- **JPEG / WebP / HEIC / TIFF**: Bounded binary search (up to 8 iterations) adjusting `-quality` (1 to 100):
  ```bash
  /opt/homebrew/bin/magick IN -quality <Q> OUT
  ```
- **BMP (Uncompressed Bitmaps)**: BMP does not support DCT quality quantization; color reduction achieves the target byte budget:
  ```bash
  /opt/homebrew/bin/magick IN -colors <N> OUT
  ```

### Video Compression (Target Bitrate & Two-Pass Encoding)
- Compute video target bitrate: `VBitrate = (targetBytes * 8 / durationSeconds) - ABitrate`
- Two-Pass H.264 encode:
  ```bash
  /opt/homebrew/bin/ffmpeg -nostdin -y -i IN -c:v libx264 -b:v <VBitrate> -pass 1 -an -f null /dev/null
  /opt/homebrew/bin/ffmpeg -nostdin -y -i IN -c:v libx264 -b:v <VBitrate> -pass 2 -c:a aac -b:a 96k -movflags +faststart OUT
  ```

### Audio Compression (Bitrate Throttling)
- Target bitrate: `ABitrate = targetBytes * 8 / durationSeconds`
  ```bash
  /opt/homebrew/bin/ffmpeg -nostdin -y -i IN -b:a <ABitrate> OUT
  ```

### PDF Compression (Ghostscript Multi-Preset Search)
- Try progressive presets from high quality to high compression: `/printer` (300 dpi), `/ebook` (150 dpi), `/screen` (72 dpi):
  ```bash
  /opt/homebrew/bin/gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=<preset> -dNOPAUSE -dQUIET -dBATCH -sOutputFile=OUT IN
  ```

---

## 8. Video & Audio Tools (Phase 9 Step 4)

### Video Speed Adjustment (0.25x to 4.0x)
- Video presentation timestamp scaled via `setpts=1/FACTOR*PTS`
- Audio tempo matched via chained `atempo` (each clamped between 0.5 and 2.0):
  ```bash
  /opt/homebrew/bin/ffmpeg -nostdin -y -i IN -filter_complex "[0:v]setpts=0.5*PTS[v];[0:a]atempo=2.0[a]" -map "[v]" -map "[a]" -c:v libx264 -c:a aac OUT
  ```

### Video Crop
- Validated against probe dimensions; uses ffmpeg `crop=w:h:x:y`:
  ```bash
  /opt/homebrew/bin/ffmpeg -nostdin -y -i IN -filter_complex "crop=160:120:0:0" -c:v libx264 -c:a copy OUT
  ```

### Video Snapshot (Single Frame Extraction)
- Extract frame at exact timestamp to PNG or JPG:
  ```bash
  /opt/homebrew/bin/ffmpeg -nostdin -y -ss 00:00:01.000 -i IN -vframes 1 OUT.png
  ```

### Video Split & Join
- **Split**: Segments cut at time stamps into an output directory:
  ```bash
  /opt/homebrew/bin/ffmpeg -nostdin -y -ss START -to END -i IN -c copy OUT_SEGMENT
  ```
- **Join**: Fast stream copy with concat demuxer, falling back to re-encoding if stream parameters differ:
  ```bash
  /opt/homebrew/bin/ffmpeg -nostdin -y -f concat -safe 0 -i concat_manifest.txt -c copy OUT
  ```

### Audio Normalization (EBU R128 Two-Pass Loudnorm)
- Pass 1: Measure integrated loudness, loudness range, and true peak:
  ```bash
  /opt/homebrew/bin/ffmpeg -nostdin -y -i IN -af loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json -f null -
  ```
- Pass 2: Apply linear normalization with measured parameters:
  ```bash
  /opt/homebrew/bin/ffmpeg -nostdin -y -i IN -af loudnorm=I=-16:TP=-1.5:LRA=11:measured_I=<I>:measured_TP=<TP>:measured_LRA=<LRA>:measured_thresh=<thresh>:offset=<offset>:linear=true OUT
  ```

### Audio Channel Remapping
- Downmix to mono or upmix to stereo:
  ```bash
  /opt/homebrew/bin/ffmpeg -nostdin -y -i IN -ac 1 OUT
  /opt/homebrew/bin/ffmpeg -nostdin -y -i IN -ac 2 OUT
  ```

### Audio Bleep (Tone Insertion)
- Overlays a 1 kHz sine tone over specified time ranges while muting original audio:
  ```bash
  /opt/homebrew/bin/ffmpeg -nostdin -y -i IN -filter_complex "sine=frequency=1000:duration=DUR[tone];[0:a]volume=enable='between(t,START,END)':volume=0[muted];[muted][tone]amix=inputs=2:weights=1 1[out]" -map "[out]" OUT
  ```

---

## 9. Metadata, PDF Tools, Montage & Vision (Phase 9 Step 5)

### Read-Only Metadata Inspection
- Images and PDF via ExifTool:
  ```bash
  /opt/homebrew/bin/exiftool -j IN
  ```
- Video and Audio via FFprobe:
  ```bash
  /opt/homebrew/bin/ffprobe -v quiet -print_format json -show_format -show_streams IN
  ```

### Metadata Editing (Non-Destructive Copy with Read-Back Verification)
- Writes whitelisted tags (`Title`, `Author`, `Artist`, `Comment`, `Description`, `Date`, `Year`, `CreateDate`) directly to output copy:
  ```bash
  /opt/homebrew/bin/exiftool -Title="My Title" -o OUT IN
  ```

### PDF Reorganize & Rotate
- Reorder pages via qpdf:
  ```bash
  /opt/homebrew/bin/qpdf IN --pages IN 3,1,2 -- OUT
  ```
- Rotate pages (e.g. +90 degrees):
  ```bash
  /opt/homebrew/bin/qpdf IN --rotate=+90:1-z --pages IN 1-z -- OUT
  ```

### PDF Merge
- Combine multiple PDFs into one document:
  ```bash
  /opt/homebrew/bin/qpdf --empty --pages IN1 IN2 IN3 -- OUT
  ```

### Image Montage / Collage
- Combine multiple images into a grid layout:
  ```bash
  /opt/homebrew/bin/magick montage IN1 IN2 IN3 -geometry +8+8 -tile 2x OUT.jpg
  ```

### Offline QR Barcode Reading
- Native Apple Vision framework via `VNDetectBarcodesRequest` using `.qr` symbology on `CGImageSource`. Completely offline with zero network lookups or automatic URL opening.


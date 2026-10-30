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

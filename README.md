# Pasta 🍝

> **A fast, native, 100% offline macOS file converter and utility with a dynamic circular radial options wheel.**

Pasta is a personal, zero-cloud file converter for macOS. Drag any supported file while holding <kbd>Shift</kbd> to bring up an interactive circular radial options wheel right at your cursor, choose your target format, and get the converted file placed right next to your original in seconds.

---

## ✨ Features

- **100% Offline & Private**: Zero network calls, no telemetry, no analytics, no cloud uploads. Everything runs locally on your Mac.
- **Circular Radial Options Wheel**: Hold <kbd>Shift</kbd> while dragging any file across macOS to summon a floating, non-activating radial wheel at your mouse location.
- **Advanced Tools Mode**: Hold <kbd>Option</kbd> (<kbd>⌥</kbd>) to toggle advanced tools: lossless/lossy compression, media trimming, crop/resize, PDF split/merge, and EXIF/XMP metadata stripping.
- **Menu Bar Utility**: Persistent status bar app (`LSUIElement`) with a drag-and-drop window, progress indicators, "Reveal in Finder" actions, and customizable accent color palettes.
- **Finder Quick Action**: Contextual right-click menu integration (`~/Library/Services/Convert with Pasta.workflow`).
- **Headless CLI**: Full-featured command-line interface (`pasta convert`, `pasta doctor`, `pasta list-actions`).
- **Non-Destructive & Atomic**: Original files are never modified or overwritten; conversions write to a temporary sandbox first, handle filename collisions safely, and swap atomically into place.

---

## 🗂 Supported File Formats & Engines

| Category | Formats Supported | Engines Used |
| :--- | :--- | :--- |
| **Images** | HEIC, JPG/JPEG, PNG, WebP, TIFF, BMP, GIF, SVG (input), AVIF, Collage grid, Offline QR Decode, Images to PDF | `sips`, `magick`, `cwebp`, `exiftool`, `Vision` |
| **Video** | MP4, MOV, MKV, WebM, AVI, WMV, animated GIF, audio extraction, Speed (0.25x–4x), Crop, Split, Join, Snapshot | `ffmpeg` |
| **Audio** | MP3, M4A, FLAC, WAV, Opus, AAC, OGG, AIFF, EBU R128 Normalization, Channels (mono/stereo), Bleep tone, Trim | `ffmpeg` |
| **PDF** | Text extraction, page dumps to PNG, Ghostscript multi-preset compression, Split, Merge, Reorganize, Rotate | `pdftotext`, `pdftoppm`, `qpdf`, `ghostscript` |
| **Documents & Code** | DOCX, TXT, Markdown, HTML, EPUB bidirectional conversion; optional LibreOffice (`soffice`) detection | `pandoc` |
| **Subtitles** | SRT &harr; VTT bidirectional conversion | `ffmpeg` |
| **Archives** | Create ZIP, single GZIP (.gz), TAR.GZ; extract ZIP, TAR, 7z, RAR, GZIP | `unar`, `7zz`, `/usr/bin/ditto`, `/usr/bin/tar`, `/usr/bin/gzip` |
| **Metadata** | Non-destructive JSON/text inspection (`ffprobe`, `exiftool`) & whitelisted tag editing with verification | `exiftool`, `ffprobe` |

---

## 🚀 Installation & Setup

### Prerequisites

Install the underlying command-line tools via Homebrew:

```bash
brew install ffmpeg imagemagick webp ghostscript qpdf poppler exiftool pandoc librsvg unar sevenzip
```

*Note: LibreOffice (`soffice`) is optionally supported for office formats when installed.*

### Build & Install

Run the included automated installer script:

```bash
# Build the native app bundle and command-line binary
./scripts/build_app.sh

# Install Pasta.app to /Applications and pasta CLI to /usr/local/bin
./scripts/install.sh

# Install Finder Quick Action workflow
./scripts/install_quick_action.sh
```

### Accessibility Permission

For the **Shift-Drag** global radial wheel to intercept drag gestures outside the app window, grant Pasta Accessibility permissions:
1. Open **System Settings &rarr; Privacy & Security &rarr; Accessibility**.
2. Add and enable **Pasta** (or follow the prompt when opening Pasta for the first time).

---

## 💻 CLI Usage

Pasta includes a headless CLI mode built on the same core engine:

```bash
# Verify system dependencies and tool paths (reports optional tools)
pasta doctor

# List available actions and parameters for a file
pasta list-actions sample.png

# Convert a file with format inference
pasta convert sample.png --to jpg

# Convert with explicit action and custom parameters
pasta convert --action video.speed --param factor=2.0 clip.mp4
pasta convert --action video.crop --param rectangle=320:240:0:0 clip.mp4
pasta convert --action audio.channels --param channels=mono voice.mp3

# Compress by percentage or exact target size
pasta convert --action image.compress --param percent=50 photo.png
pasta convert --action pdf.compress --param targetSize=500000 document.pdf

# Read metadata as formatted text or JSON
pasta metadata read clip.mp4 --json

# Reorganize PDF page sequence
pasta convert --action pdf.reorganize --param pages=3,1,2 document.pdf

# Combine images into a collage
pasta convert --action image.collage --param columns=2 img1.png img2.png
```

---

## 🧪 Testing & Verification

Pasta includes comprehensive unit, integration, and security hardening test suites:

```bash
# Run 131 Unit & Integration Tests (Debug & Release)
swift run PastaTests
swift run -c release PastaTests

# Run 30 Section 8 Hardening & Hostile Filename Tests
./scripts/run_section8_tests.sh
```

---

## 🛡️ Key Guarantees

1. **No External Network Requests**: Pasta contains zero URLSession or network APIs.
2. **Immutable Originals**: Source files are treated as strictly read-only.
3. **Safe Process Isolation**: Commands use discrete argument arrays to prevent shell injection.
4. **Pipe Deadlock Prevention**: Subprocesses read stdout and stderr concurrently with async streams.
5. **Zero Third-Party Swift Packages**: Pure Swift and AppKit native implementation.

---

## 📄 License

MIT License. Designed and crafted for macOS.

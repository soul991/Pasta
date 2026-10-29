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
| **Images** | HEIC, JPG/JPEG, PNG, WebP, TIFF, BMP, GIF, SVG (input), AVIF | `sips`, `magick`, `cwebp`, `exiftool` |
| **Video** | MP4, MOV, MKV, WebM, animated GIF, plus audio extraction | `ffmpeg` |
| **Audio** | MP3, M4A, FLAC, WAV, Opus, AAC | `ffmpeg` |
| **PDF** | Text extraction, page dumps to PNG, compress, split, merge | `pdftotext`, `pdftoppm`, `qpdf`, `ghostscript` |
| **Documents & Code** | DOCX &rarr; TXT / Markdown / HTML; code and script transformations | `pandoc` |
| **Subtitles** | SRT &harr; VTT bidirectional conversion | `ffmpeg` |
| **Archives** | Create ZIP, TAR.GZ; extract ZIP, TAR, 7z, RAR | `unar`, `7zz`, `/usr/bin/tar` |

---

## 🚀 Installation & Setup

### Prerequisites

Install the underlying command-line tools via Homebrew:

```bash
brew install ffmpeg imagemagick webp ghostscript qpdf poppler exiftool pandoc librsvg unar sevenzip
```

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
# Verify system dependencies and tool paths
pasta doctor

# List available actions for a file
pasta list-actions sample.png

# Convert a file
pasta convert --action image.to.jpeg photo.png

# Strip metadata from an image
pasta convert --action image.strip.metadata photo.jpg

# Compress a PDF
pasta convert --action pdf.compress document.pdf
```

---

## 🧪 Testing & Verification

Pasta includes comprehensive unit, integration, and security hardening test suites:

```bash
# Run 37 Unit & Integration Tests
swift run PastaTests

# Run 13 Section 8 Hardening & Boundary Tests
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

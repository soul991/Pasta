# Pasta 🍝

[![macOS CI](https://github.com/soul991/Pasta/actions/workflows/macos-ci.yml/badge.svg)](https://github.com/soul991/Pasta/actions/workflows/macos-ci.yml)
[![Release](https://github.com/soul991/Pasta/actions/workflows/release.yml/badge.svg)](https://github.com/soul991/Pasta/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> **A fast, native macOS file converter and utility with verified local processing, zero telemetry, and a dynamic circular radial options wheel.**

Pasta is a personal, zero-cloud file converter for macOS. Drag any supported file while holding <kbd>Shift</kbd> for 450 ms to summon an interactive circular radial options wheel right at your cursor. The wheel latches open when you release Shift, lets you choose your target format or action, and places the converted file right next to your original in seconds.

---

## 💡 Why Pasta?

Most existing file converters either upload your confidential documents, private photos, and videos to remote third-party cloud servers, or wrap heavy, sluggish web runtimes.

Pasta is built with a different philosophy:
- **Verified Local Processing & Zero Telemetry**: No network frameworks or APIs (`URLSession`, BSD sockets) are imported or linked into the app binary (verified by CI symbol scan). Zero telemetry, tracking, or analytics exist in the codebase. Pasta invokes only the tools installed on your Mac, never downloads anything on its own, and files never leave the machine.
- **Fast & Native**: Written in pure Swift with native AppKit components. No Electron, no web wrappers, no sluggish startup times.
- **Battle-Tested Engines**: Drives industry-standard open-source CLI tools (`ffmpeg`, `imagemagick`, `poppler`, `pandoc`, etc.) directly via POSIX process isolation without shell string injection.
- **Deliberate Frictionless Interaction**: Summons an intuitive circular wheel right under your cursor via Shift-drag hold.
- **Strict Atomic Guarantees**: Never overwrites pre-existing files. In-flight conversions write to isolated scratch sandboxes and publish atomically.

---

## ✨ Features

- **Verified Local Processing**: No network APIs or external connections linked in the app binary. Pasta processes files strictly on your local machine using user-managed engines.
- **Deliberate Shift-Hold Radial Wheel**: While a file drag is active, holding <kbd>Shift</kbd> for **450 ms** opens the radial wheel at the cursor. A quick graze or typing tap (<450 ms) is ignored. After a 120 ms delay, a thin charging progress ring fills around the cursor. Releasing Shift or pressing any other key cancels the charge. Once opened, the wheel **latches** and remains open after Shift is released. A second Shift-hold, dropping outside, or pressing <kbd>Esc</kbd> closes it. Fully configurable in Settings with a hold duration slider (300 ms to 1000 ms, default 450 ms), latch toggle, and charging ring toggle.
- **Quick Option-Tap Mode Switch**: A quick tap of <kbd>Option</kbd> (<kbd>⌥</kbd>) (< 250 ms) while the wheel is open toggles between **Convert** mode (target file formats) and **Advanced** mode (lossless/lossy compression, media trimming, crop/speed/channels, PDF reorganize, metadata stripping). A long hold does not toggle mode.
- **Menu Bar Utility**: Persistent status bar app (`LSUIElement`) with a native `NSPopover` drag-and-drop window, progress indicators, "Reveal in Finder" actions, and customizable accent color palettes.
- **Finder Quick Action**: Contextual right-click menu integration (`~/Library/Services/Convert with Pasta.workflow`).
- **Headless CLI**: Full-featured command-line interface (`pasta convert`, `pasta doctor`, `pasta list-actions`).
- **Atomic Output Reservation**: In-flight conversions claim output names atomically via POSIX `open(O_CREAT | O_EXCL)` and publish via `rename(2)`. Even under high concurrency or identical filenames, existing files are never overwritten.
- **Hostile Archive Protection (`ArchiveGuard`)**: Rejects path traversal attacks (Zip Slip), symlink escapes, external hard links, decompression bombs, and privilege escalation (setuid/setgid).

---

## 🗂 Supported File Formats & Engines

<!-- BEGIN_ACTIONS_TABLE -->
| Category | Formats Supported | Engines Used |
| :--- | :--- | :--- |
| **Images** | HEIC, JPG/JPEG, PNG, WebP, TIFF, BMP, GIF, SVG (input), AVIF, Collage grid, Offline QR Decode, Images to PDF | `sips`, `magick`, `cwebp`, `exiftool`, `Vision` |
| **Video** | MP4, MOV, MKV, WebM, AVI, WMV, animated GIF, audio extraction, Speed (0.25x–4x), Crop, Split, Join, Snapshot | `ffmpeg`, `ffprobe` |
| **Audio** | MP3, M4A, FLAC, WAV, Opus, AAC, OGG, AIFF, EBU R128 Normalization, Channels (mono/stereo), Bleep tone, Trim | `ffmpeg`, `ffprobe` |
| **PDF** | Text extraction, page dumps to PNG, Ghostscript multi-preset compression, Split, Merge, Reorganize, Rotate | `pdftotext`, `pdftoppm`, `qpdf`, `ghostscript` |
| **Documents & Code** | DOCX, TXT, Markdown, HTML, EPUB bidirectional conversion; optional LibreOffice (`soffice`) detection | `pandoc`, `soffice` (optional) |
| **Subtitles** | SRT &harr; VTT bidirectional conversion | `ffmpeg` |
| **Archives** | Create ZIP, single GZIP (.gz), TAR.GZ; extract ZIP, TAR, 7z, RAR, GZIP | `unar`, `7zz`, `/usr/bin/ditto`, `/usr/bin/tar` |
| **Metadata** | Non-destructive JSON/text inspection & whitelisted tag editing with verification | `exiftool`, `ffprobe` |
<!-- END_ACTIONS_TABLE -->

*Tip: Run `pasta list-actions --all --markdown` to inspect all individual conversion action IDs and parameters.*

---

## 🚀 Installation & Setup

### Prerequisites

Install the underlying open-source command-line engines via [Homebrew](https://brew.sh):

```bash
brew install ffmpeg imagemagick webp ghostscript qpdf poppler exiftool pandoc librsvg unar sevenzip
```

*Optional Engines (for Office and eBook formats):*
```bash
brew install libavif && brew install --cask libreoffice calibre
```

Run `pasta doctor` at any time to verify installed tools and generate copy-paste Homebrew commands for any missing engines.

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

## ⚠️ Current Limitations

- **Ad-Hoc Signed (Not Notarized)**: Releases are currently ad-hoc signed and not notarized by an Apple Developer account. On first launch, macOS Gatekeeper may show a warning. Right-click (or Control-click) `Pasta.app`, select **Open**, and click **Open Anyway** (or go to **System Settings > Privacy & Security** and click **Open Anyway**).
- **External CLI Engines**: Pasta does not bundle binary engines inside the application bundle. You must install the necessary engines via Homebrew.
- **Atomic Placeholder Visibility**: During conversion, a zero-byte placeholder file is temporarily reserved in the destination folder to prevent concurrent name collisions. It is atomically replaced by the completed output once conversion succeeds.
- **Accessibility Requirement**: Global Shift-drag gesture interception requires macOS Accessibility permissions. If not granted, Pasta operates via the Menu Bar drop zone and the CLI.

---

## 💻 CLI Usage

Pasta includes a headless CLI mode built on the same core engine:

```bash
# Verify system dependencies and tool paths (supports --json export)
pasta doctor
pasta doctor --json

# List available actions for a specific file or print all registered actions
pasta list-actions sample.png
pasta list-actions --all --markdown

# Convert a file with format inference
pasta convert sample.png --to jpg

# Convert with explicit action, custom parameters, and custom destination
pasta convert --action video.speed --param factor=2.0 --dest ~/Desktop clip.mp4
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

Pasta includes comprehensive unit, integration, and security hardening test suites.

Verification is automatically run across both macOS 27 (`xcode-27-arm64`) and macOS 26 (`macos-latest`) on every push and pull request. See the continuous integration badge at the top of this README for live build and test status.

To run the complete test suite locally:

```bash
# Print live test suite and Section 8 hardening counts
./scripts/test_counts.sh

# Build, package, and verify signed Pasta.app bundle
./scripts/build_app.sh
codesign --verify --deep --strict Pasta.app
```

---

## 🛡️ Key Guarantees

1. **No External Network Requests**: Pasta contains zero `URLSession`, socket, or network APIs. Verified by binary string inspection in CI.
2. **Immutable Originals**: Source files are treated as strictly read-only and never modified or deleted.
3. **Atomic Output Publication**: Output names are claimed atomically before work begins (`open(O_CREAT | O_EXCL)`), preventing data loss under concurrent execution.
4. **Hostile Input Defense**: Extraction occurs in isolated scratch sandboxes, preflight-inspected, and vetted by `ArchiveGuard`.
5. **Safe Process Isolation**: Commands use discrete argument arrays to prevent shell injection.
6. **Pipe Deadlock Prevention**: Subprocesses stream stdout and stderr concurrently to prevent buffer deadlocks.
7. **Zero Third-Party Swift Packages**: Pure Swift, Foundation, AppKit, and POSIX native implementation.

---

## 📄 License

MIT License. Copyright (c) 2026 Istak Ahamed. See [LICENSE](LICENSE) for details.

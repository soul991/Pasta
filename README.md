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
- **Verified Local Processing & Zero Telemetry**: No network frameworks or APIs (`URLSession`, BSD sockets) are imported or linked into the app binary (verified by CI symbol scan). Zero telemetry, tracking, or analytics exist in the codebase. All 19 conversion and inspection engines are bundled self-contained inside the application bundle (`Contents/Resources/Engines/`). Pasta never downloads anything on its own, requires no external dependencies for end users, and files never leave the machine.
- **Fast & Native**: Written in pure Swift with native AppKit components. No Electron, no web wrappers, no sluggish startup times.
- **Battle-Tested Engines**: Drives industry-standard open-source CLI tools (`ffmpeg`, `imagemagick`, `poppler`, `pandoc`, etc.) directly via POSIX process isolation without shell string injection.
- **Deliberate Frictionless Interaction**: Summons an intuitive circular wheel right under your cursor via Shift-drag hold.
- **Strict Atomic Guarantees**: Never overwrites pre-existing files. In-flight conversions write to isolated scratch sandboxes and publish atomically.

---

## ✨ Features

- **Verified Local Processing**: No network APIs or external connections linked in the app binary. Pasta processes files strictly on your local machine using fully bundled, self-contained relocatable engines.
- **Deliberate Shift-Hold Radial Wheel**: While a file drag is active, holding <kbd>Shift</kbd> for **450 ms** opens the radial wheel at the cursor. A quick graze or typing tap (<450 ms) is ignored. After a 120 ms delay, a thin charging progress ring fills around the cursor. Releasing Shift or pressing any other key cancels the charge. Once opened, the wheel **latches** and remains open after Shift is released. A second Shift-hold, dropping outside, or pressing <kbd>Esc</kbd> closes it. Fully configurable in Settings with a hold duration slider (300 ms to 1000 ms, default 450 ms), latch toggle, and charging ring toggle.
- **Tab Flip Side for Extended Actions**: While the radial options wheel is open, pressing <kbd>Tab</kbd> flips the wheel to reveal secondary actions specifically mapped to the current file type. Pressing <kbd>Tab</kbd> again seamlessly returns to the primary action set.
- **Per-File-Type Radial Profiles**: Dedicated primary and secondary action profiles customized per file format category (Images, Video, Audio, PDFs, Office Documents, Archives), ensuring the most relevant tools appear immediately without cluttering the interface.
- **Quick Option-Tap Mode Switch**: A quick tap of <kbd>Option</kbd> (<kbd>⌥</kbd>) (< 250 ms) while the wheel is open toggles between **Convert** mode (target file formats) and **Advanced** mode (lossless/lossy compression, media trimming, crop/speed/channels, PDF reorganize, metadata stripping). A long hold does not toggle mode.
- **Recent Conversions History**: Local-only conversion log stored strictly in Application Support (`recent_conversions.json`) with convenient "Reveal in Finder" actions, clearable at any time with a dedicated privacy setting to control path recording or disable history entirely.
- **Per-Engine Concurrency Caps**: Intelligent background job queue (`BatchJobQueue`) enforcing per-engine resource limits (e.g. Ghostscript capped at 1 concurrent process, FFmpeg at 2) to prevent CPU and memory exhaustion during heavy batch operations.
- **Menu Bar Utility**: Persistent status bar app (`LSUIElement`) with a native `NSPopover` drag-and-drop window, progress indicators, "Reveal in Finder" actions, and customizable accent color palettes.
- **Finder Quick Action**: Contextual right-click menu integration (`~/Library/Services/Convert with Pasta.workflow`).
- **Headless CLI**: Full-featured command-line interface (`pasta convert`, `pasta doctor`, `pasta list-actions`).
- **Atomic Output Reservation**: In-flight conversions claim output names atomically via POSIX `open(O_CREAT | O_EXCL)` and publish via `rename(2)`. Even under high concurrency or identical filenames, existing files are never overwritten.
- **Hostile Archive Protection (`ArchiveGuard`)**: Rejects path traversal attacks (Zip Slip), symlink escapes, external hard links, decompression bombs, and privilege escalation (setuid/setgid).

---

## 🗂 Supported File Formats & Engines

<!-- BEGIN_ACTIONS_TABLE -->
| Category | Action ID | Display Name | Target Extension | Advanced | Quality Class |
| :--- | :--- | :--- | :--- | :---: | :--- |
| Archive | `archive.create.gzip` | Compress to GZIP | `.gz` | No | LOSSLESS (proven) |
| Archive | `archive.create.targz` | Compress to TAR.GZ | `.tar.gz` | No | LOSSLESS (proven) |
| Archive | `archive.create.zip` | Compress to ZIP | `.zip` | No | LOSSLESS (proven) |
| Archive | `archive.extract` | Extract Archive | `(folder)` | No | LOSSLESS (proven) |
| Audio | `audio.advanced.compress` | Compress Audio | `.mp3` | Yes | LOSSY (user-controlled) |
| Metadata | `audio.advanced.strip_metadata` | Remove Metadata | `.mp3` | Yes | LOSSLESS (proven) |
| Audio | `audio.bleep` | Bleep Out Audio Ranges | `.mp3` | Yes | LOSSY (user-controlled) |
| Audio | `audio.channels` | Change Audio Channels | `.mp3` | Yes | VISUALLY LOSSLESS |
| Audio | `audio.compress` | Compress Audio | `.mp3` | No | LOSSY (user-controlled) |
| Audio | `audio.normalize` | Normalize Audio (EBU R128) | `.mp3` | Yes | VISUALLY LOSSLESS |
| Audio | `audio.to.aiff` | Convert to AIFF | `.aiff` | No | LOSSLESS (proven) |
| Audio | `audio.to.flac` | Convert to FLAC | `.flac` | No | LOSSLESS (proven) |
| Audio | `audio.to.m4a` | Convert to M4A | `.m4a` | No | LOSSY (user-controlled) |
| Audio | `audio.to.mp3` | Convert to MP3 | `.mp3` | No | LOSSY (user-controlled) |
| Audio | `audio.to.ogg` | Convert to OGG | `.ogg` | No | LOSSY (user-controlled) |
| Audio | `audio.to.opus` | Convert to Opus | `.opus` | No | LOSSY (user-controlled) |
| Audio | `audio.to.wav` | Convert to WAV | `.wav` | No | LOSSLESS (proven) |
| Audio | `audio.trim` | Trim Audio | `.mp3` | Yes | COPY |
| Document | `code.to.html` | Convert to HTML | `.html` | No | LOSSLESS (proven) |
| Document | `code.to.md` | Convert to Markdown | `.md` | No | LOSSLESS (proven) |
| Document | `code.to.pdf` | Convert to PDF | `.pdf` | No | VISUALLY LOSSLESS |
| Document | `code.to.txt` | Convert to Plain Text | `.txt` | No | LOSSLESS (proven) |
| Document | `csv.to.xlsx` | Convert to XLSX | `.xlsx` | No | LOSSLESS (proven) |
| Document | `docx.to.epub` | Convert to EPUB | `.epub` | No | VISUALLY LOSSLESS |
| Document | `docx.to.html` | Convert to HTML | `.html` | No | VISUALLY LOSSLESS |
| Document | `docx.to.images` | Extract Pages to PNGs | `.png` | No | VISUALLY LOSSLESS |
| Document | `docx.to.md` | Convert to Markdown | `.md` | No | LOSSY (user-controlled) |
| Document | `docx.to.pdf` | Convert to PDF | `.pdf` | No | VISUALLY LOSSLESS |
| Document | `docx.to.txt` | Convert to Plain Text | `.txt` | No | LOSSY (user-controlled) |
| Document | `epub.to.docx` | Convert to DOCX | `.docx` | No | VISUALLY LOSSLESS |
| Document | `epub.to.html` | Convert to HTML | `.html` | No | VISUALLY LOSSLESS |
| Document | `epub.to.md` | Convert to Markdown | `.md` | No | LOSSY (user-controlled) |
| Document | `epub.to.txt` | Convert to Plain Text | `.txt` | No | LOSSY (user-controlled) |
| Document | `generic.to.pdf` | Convert to PDF | `.pdf` | No | VISUALLY LOSSLESS |
| Document | `generic.to.txt` | Convert to Plain Text | `.txt` | No | LOSSLESS (proven) |
| Document | `html.to.docx` | Convert to DOCX | `.docx` | No | VISUALLY LOSSLESS |
| Document | `html.to.epub` | Convert to EPUB | `.epub` | No | VISUALLY LOSSLESS |
| Document | `html.to.md` | Convert to Markdown | `.md` | No | LOSSY (user-controlled) |
| Document | `html.to.pdf` | Convert to PDF | `.pdf` | No | VISUALLY LOSSLESS |
| Document | `html.to.txt` | Convert to Plain Text | `.txt` | No | LOSSY (user-controlled) |
| Image | `image.advanced.compress` | Compress Image | `.png` | Yes | LOSSLESS (proven) |
| Image | `image.advanced.resize_50` | Resize (Max 1200px) | `.png` | Yes | LOSSY (user-controlled) |
| Metadata | `image.advanced.strip_metadata` | Remove Metadata | `.png` | Yes | LOSSLESS (proven) |
| Image | `image.collage` | Create Image Collage | `.jpg` | Yes | VISUALLY LOSSLESS |
| Image | `image.compress` | Compress Image | `.png` | No | LOSSLESS (proven) |
| PDF | `image.ocr.searchable` | Searchable PDF | `.pdf` | Yes | VISUALLY LOSSLESS |
| Document | `image.ocr.text` | OCR to Text | `.txt` | Yes | LOSSLESS (proven) |
| Image | `image.qr.read` | Read QR Code | `.txt` | Yes | LOSSLESS (proven) |
| Image | `image.resize` | Resize Image | `.png` | No | LOSSY (user-controlled) |
| Image | `image.to.avif` | Convert to AVIF | `.avif` | No | VISUALLY LOSSLESS |
| Image | `image.to.bmp` | Convert to BMP | `.bmp` | No | LOSSLESS (proven) |
| Image | `image.to.gif` | Convert to GIF | `.gif` | No | LOSSY (user-controlled) |
| Image | `image.to.heic` | Convert to HEIC | `.heic` | No | VISUALLY LOSSLESS |
| Image | `image.to.jpeg` | Convert to JPEG | `.jpg` | No | LOSSY (user-controlled) |
| Document | `image.to.pdf` | Convert to PDF | `.pdf` | No | VISUALLY LOSSLESS |
| Image | `image.to.png` | Convert to PNG | `.png` | No | LOSSLESS (proven) |
| Image | `image.to.tiff` | Convert to TIFF | `.tiff` | No | LOSSLESS (proven) |
| Image | `image.to.webp` | Convert to WebP | `.webp` | No | VISUALLY LOSSLESS |
| Document | `md.to.docx` | Convert to DOCX | `.docx` | No | VISUALLY LOSSLESS |
| Document | `md.to.epub` | Convert to EPUB | `.epub` | No | VISUALLY LOSSLESS |
| Document | `md.to.html` | Convert to HTML | `.html` | No | VISUALLY LOSSLESS |
| Document | `md.to.pdf` | Convert to PDF | `.pdf` | No | VISUALLY LOSSLESS |
| Document | `md.to.txt` | Convert to Plain Text | `.txt` | No | LOSSLESS (proven) |
| Metadata | `metadata.edit` | Edit Metadata | `.jpg` | Yes | LOSSLESS (proven) |
| Metadata | `metadata.read` | Read Metadata | `.txt` | Yes | LOSSLESS (proven) |
| Document | `office.to.images` | Extract Pages to PNGs | `.png` | No | VISUALLY LOSSLESS |
| Document | `office.to.pdf` | Convert to PDF | `.pdf` | No | VISUALLY LOSSLESS |
| PDF | `pdf.advanced.compress` | Compress PDF | `.pdf` | Yes | LOSSLESS (proven) |
| PDF | `pdf.advanced.split` | Split PDF Pages | `(folder)` | Yes | LOSSLESS (proven) |
| Metadata | `pdf.advanced.strip_metadata` | Remove Metadata | `.pdf` | Yes | LOSSLESS (proven) |
| PDF | `pdf.compress` | Compress PDF | `.pdf` | No | LOSSLESS (proven) |
| PDF | `pdf.merge` | Merge PDFs | `.pdf` | No | LOSSLESS (proven) |
| PDF | `pdf.ocr.searchable` | Searchable PDF | `.pdf` | Yes | VISUALLY LOSSLESS |
| PDF | `pdf.ocr.text` | OCR to Text | `.txt` | Yes | LOSSLESS (proven) |
| PDF | `pdf.pagenumbers` | Page Numbers | `.pdf` | Yes | VISUALLY LOSSLESS |
| PDF | `pdf.reorganize` | Reorganize / Rotate Pages | `.pdf` | Yes | LOSSLESS (proven) |
| PDF | `pdf.security.lock` | Lock with Password | `.pdf` | Yes | LOSSLESS (proven) |
| PDF | `pdf.security.unlock` | Unlock PDF | `.pdf` | Yes | LOSSLESS (proven) |
| PDF | `pdf.to.epub` | Convert to EPUB (Text Only) | `.epub` | No | LOSSY (user-controlled) |
| PDF | `pdf.to.epub.calibre` | Convert to EPUB (Better Layout) | `.epub` | Yes | LOSSY (user-controlled) |
| PDF | `pdf.to.images` | Extract Pages to PNGs | `.png` | No | LOSSLESS (proven) |
| PDF | `pdf.to.pdfa` | Convert to PDF/A-2b (Archival) | `.pdf` | Yes | VISUALLY LOSSLESS |
| PDF | `pdf.to.text` | Convert to Plain Text | `.txt` | No | LOSSY (user-controlled) |
| PDF | `pdf.watermark` | Watermark | `.pdf` | Yes | VISUALLY LOSSLESS |
| Subtitle | `srt.to.vtt` | Convert to WebVTT | `.vtt` | No | LOSSLESS (proven) |
| Document | `txt.to.docx` | Convert to DOCX | `.docx` | No | LOSSLESS (proven) |
| Document | `txt.to.html` | Convert to HTML | `.html` | No | LOSSLESS (proven) |
| Document | `txt.to.md` | Convert to Markdown | `.md` | No | LOSSLESS (proven) |
| Video | `video.advanced.compress` | Compress Video | `.mp4` | Yes | LOSSY (user-controlled) |
| Metadata | `video.advanced.strip_metadata` | Remove Metadata | `.mp4` | Yes | COPY |
| Video | `video.advanced.trim10` | Trim First 10 Seconds | `.mp4` | Yes | COPY |
| Video | `video.compress` | Compress Video | `.mp4` | No | LOSSY (user-controlled) |
| Video | `video.crop` | Crop Video | `.mp4` | Yes | VISUALLY LOSSLESS |
| Audio | `video.extract.m4a` | Extract M4A Audio | `.m4a` | No | LOSSY (user-controlled) |
| Audio | `video.extract.mp3` | Extract MP3 Audio | `.mp3` | No | LOSSY (user-controlled) |
| Audio | `video.extract.wav` | Extract WAV Audio | `.wav` | No | LOSSLESS (proven) |
| Video | `video.join` | Join Videos | `.mp4` | Yes | COPY |
| Image | `video.snapshot` | Snapshot Frame (PNG) | `.png` | Yes | VISUALLY LOSSLESS |
| Image | `video.snapshot.jpg` | Snapshot Frame (JPG) | `.jpg` | Yes | LOSSY (user-controlled) |
| Video | `video.speed` | Change Video Speed | `.mp4` | Yes | VISUALLY LOSSLESS |
| Video | `video.split` | Split Video | `.mp4` | Yes | COPY |
| Video | `video.to.avi` | Convert to AVI | `.avi` | No | VISUALLY LOSSLESS |
| Video | `video.to.gif` | Convert to GIF | `.gif` | No | LOSSY (user-controlled) |
| Video | `video.to.mkv` | Remux to MKV | `.mkv` | No | COPY |
| Video | `video.to.mov` | Remux to MOV | `.mov` | No | COPY |
| Video | `video.to.mp4` | Convert to MP4 | `.mp4` | No | VISUALLY LOSSLESS |
| Video | `video.to.webm` | Convert to WebM | `.webm` | No | VISUALLY LOSSLESS |
| Video | `video.to.wmv` | Convert to WMV | `.wmv` | No | VISUALLY LOSSLESS |
| Video | `video.trim` | Trim Video | `.mp4` | Yes | COPY |
| Subtitle | `vtt.to.srt` | Convert to SubRip (.srt) | `.srt` | No | LOSSLESS (proven) |
| Document | `xlsx.to.csv` | Extract Sheets to CSVs | `.csv` | No | LOSSLESS (proven) |
<!-- END_ACTIONS_TABLE -->

*Tip: Run `pasta list-actions --all --markdown` to inspect all individual conversion action IDs and parameters.*

---

## 🚀 Installation & Setup

### Packaged Application (Recommended)

1. Download `Pasta.app` or install from the release archive / DMG.
2. Drag `Pasta.app` to `/Applications`.
3. Launch Pasta from Applications or the menu bar.
4. Grant Accessibility permissions when prompted (required for the global Shift-drag radial wheel).

All 19 required conversion and inspection engines are fully bundled inside `Pasta.app/Contents/Resources/Engines/` out of the box — no Homebrew installation or extra downloads are required for end users.

### Developer Builds & Source Compilation (Optional)

If you are developing Pasta or testing against system-installed tools:

```bash
# Optional: Install tools via Homebrew for development
brew install ffmpeg imagemagick webp ghostscript qpdf poppler exiftool pandoc librsvg unar sevenzip libavif
brew install --cask libreoffice calibre
```

In Pasta's settings, you can enable **"Developer mode: use my installed tools"** to prefer system-level binaries over bundled engines. Run `pasta doctor` at any time to verify system and bundled engine discovery.

### Build & Install from Source

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
- **Self-Contained Bundled Engines**: All conversion engines and libraries are bundled self-contained within `Pasta.app/Contents/Resources/Engines/`. Developer mode is available in Settings for testing against local system tools.
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

# Pasta Third-Party Engine License Audit & Bundling Policy

*Audit Date: 2026-11-06*  
*Auditor: Antigravity Autonomous Engineering & Supervisor Sub-Agent*  
*Scope: All 19 CLI tools registered in `ToolLocator` (`ToolLocator.shared.doctorReportData().tools`)*

---

## 1. Executive Summary & Core Bundling Decision

**Current Bundling Decision for All Engines: DO NOT BUNDLE.**

Pasta does **not** bundle, embed, or distribute any third-party engine binaries inside the `Pasta.app` bundle or official release packages.
- All conversions and media processing operations are performed by executing separate external child processes via POSIX `Process()` with argument arrays.
- Zero code from third-party engines is linked as static or dynamic libraries into `Pasta` or `PastaCore`.
- Pasta discovers and invokes either pre-installed macOS system utilities (`/usr/bin/sips`, `/usr/bin/ditto`, `/usr/bin/tar`) or tools independently installed and managed by the user via [Homebrew](https://brew.sh) (`/opt/homebrew/bin` or `/usr/local/bin`).

This architecture completely eliminates license contamination (e.g. GPL/AGPL viral copyleft triggering on Pasta's proprietary or MIT application codebase) while maintaining strict local privacy and zero network transfer.

---

## 2. Comprehensive Tool Audit Matrix (All 19 Tools)

| Tool Name | License (SPDX) | Upstream License URL | Date Checked | How Pasta Uses It | Redistribution Obligations | Risk Level | Bundling Decision |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `ffmpeg` | LGPL-2.1-or-later (default) / GPL-2.0+ (if enabled) | https://ffmpeg.org/legal.html | 2026-11-06 | Invoked as separate child process via `Process()` with argument arrays for video/audio transcode and stream copy | Source code offer of FFmpeg build, license text, non-GPL flags if redistributed | Low (as external CLI) / Medium (if bundled) | Do Not Bundle (User-managed via Homebrew) |
| `ffprobe` | LGPL-2.1-or-later (default) / GPL-2.0+ (if enabled) | https://ffmpeg.org/legal.html | 2026-11-06 | Invoked as separate child process via `Process()` for media container and stream duration probing | Same as FFmpeg | Low (as external CLI) / Medium (if bundled) | Do Not Bundle (User-managed via Homebrew) |
| `cwebp` | BSD-3-Clause | https://chromium.googlesource.com/webm/libwebp/+/refs/heads/main/COPYING | 2026-11-06 | Invoked as separate child process via `Process()` for WebP image encoding | Retain copyright notice and disclaimer in documentation | Very Low | Do Not Bundle (User-managed via Homebrew) |
| `magick` | ImageMagick | https://imagemagick.org/script/license.php | 2026-11-06 | Invoked as separate child process via `Process()` for raster image conversions, resizing, and rotation | Apache-2.0 compatible notice retention | Very Low | Do Not Bundle (User-managed via Homebrew) |
| `gs` | AGPL-3.0-or-later | https://www.ghostscript.com/license.html | 2026-11-06 | Invoked as separate child process via `Process()` for PDF optimization and level compression | Complete corresponding source code offer if distributed or network-interacted; strict copyleft | High (if bundled) / Low (as external CLI) | Do Not Bundle (User-managed via Homebrew) |
| `qpdf` | Apache-2.0 OR Artistic-2.0 | https://github.com/qpdf/qpdf/blob/main/LICENSE.txt | 2026-11-06 | Invoked as separate child process via `Process()` for page counting, linearizing, split/merge, and encryption | Notice retention, state changes | Very Low | Do Not Bundle (User-managed via Homebrew) |
| `pdftoppm` | GPL-2.0-or-later OR GPL-3.0-or-later | https://gitlab.freedesktop.org/poppler/poppler/-/blob/master/COPYING | 2026-11-06 | Invoked as separate child process via `Process()` to rasterize PDF pages to PNG/JPEG | Strong copyleft: complete corresponding source code if binary is redistributed | High (if bundled) / Low (as external CLI) | Do Not Bundle (User-managed via Homebrew) |
| `pdftotext` | GPL-2.0-or-later OR GPL-3.0-or-later | https://gitlab.freedesktop.org/poppler/poppler/-/blob/master/COPYING | 2026-11-06 | Invoked as separate child process via `Process()` for text extraction from PDF documents | Strong copyleft: complete corresponding source code if binary is redistributed | High (if bundled) / Low (as external CLI) | Do Not Bundle (User-managed via Homebrew) |
| `exiftool` | Artistic-1.0-Perl OR GPL-1.0-or-later | https://github.com/exiftool/exiftool/blob/master/LICENSE | 2026-11-06 | Invoked as separate child process via `Process()` for non-destructive metadata read and edit | Notice retention; source offer if modified | Low (as external CLI) | Do Not Bundle (User-managed via Homebrew) |
| `pandoc` | GPL-2.0-or-later | https://github.com/jgm/pandoc/blob/main/COPYRIGHT | 2026-11-06 | Invoked as separate child process via `Process()` for Markdown/HTML/DOCX format conversions | Strong copyleft: source code offer if binary is redistributed | High (if bundled) / Low (as external CLI) | Do Not Bundle (User-managed via Homebrew) |
| `rsvg-convert` | LGPL-2.1-or-later | https://gitlab.gnome.org/GNOME/librsvg/-/blob/main/COPYING.LIB | 2026-11-06 | Invoked as separate child process via `Process()` for vector SVG to PNG/PDF rendering | Weak copyleft: notice retention, source code offer of librsvg modifications | Medium (if bundled) / Low (as external CLI) | Do Not Bundle (User-managed via Homebrew) |
| `unar` | LGPL-2.1-or-later | https://github.com/MacPaw/Xee/blob/master/unar/LICENSE | 2026-11-06 | Invoked as separate child process via `Process()` for multi-format archive extraction | Weak copyleft: notice retention, source code offer of unar modifications | Medium (if bundled) / Low (as external CLI) | Do Not Bundle (User-managed via Homebrew) |
| `7zz` | LGPL-2.1-or-later AND BSD-3-Clause | https://www.7-zip.org/license.txt | 2026-11-06 | Invoked as separate child process via `Process()` for 7z/ZIP/TAR compression and extraction | Weak copyleft: notice retention, unRAR license restrictions if unRAR code is included | Medium (if bundled) / Low (as external CLI) | Do Not Bundle (User-managed via Homebrew) |
| `sips` | Apple Proprietary / macOS EULA | https://www.apple.com/legal/sla/ | 2026-11-06 | Invoked as separate child process via `Process()` for macOS native image resizing, format change, and querying | Part of macOS system software; cannot be redistributed standalone | None (System utility) | Do Not Bundle (macOS System Pre-installed) |
| `ditto` | APSL-2.0 | https://opensource.apple.com/source/copyfile/copyfile-138/LICENSE | 2026-11-06 | Invoked as separate child process via `Process()` for native ZIP creation and PKZip extraction | Apple Public Source License notice retention if redistributed | None (System utility) | Do Not Bundle (macOS System Pre-installed) |
| `tar` | BSD-2-Clause | https://github.com/libarchive/libarchive/blob/master/COPYING | 2026-11-06 | Invoked as separate child process via `Process()` for tar archive extraction and tar.gz creation | BSD 2-Clause notice retention | None (System utility) | Do Not Bundle (macOS System Pre-installed) |
| `soffice` | MPL-2.0 | https://www.libreoffice.org/about-us/licenses/ | 2026-11-06 | Optional: Invoked as separate child process via `Process()` in headless mode (`--headless --convert-to`) | Weak copyleft (file-level): notice retention, source offer for modified MPL files | Medium (if bundled) / Low (as external CLI) | Do Not Bundle (User-managed via Homebrew Cask) |
| `ebook-convert` | GPL-3.0-only | https://github.com/kovidgoyal/calibre/blob/master/LICENSE | 2026-11-06 | Optional: Invoked as separate child process via `Process()` for EPUB/MOBI conversions | Strong copyleft: source code offer if binary redistributed | High (if bundled) / Low (as external CLI) | Do Not Bundle (User-managed via Homebrew Cask) |
| `avifenc` | BSD-2-Clause | https://github.com/AOMediaCodec/libavif/blob/main/LICENSE | 2026-11-06 | Optional: Invoked as separate child process via `Process()` for AVIF image encoding | Permissive BSD 2-Clause notice retention | Very Low | Do Not Bundle (User-managed via Homebrew) |

---

## 3. Specific Engine Policies

### 3.1 FFmpeg & VideoToolbox Architecture
If Pasta ever provides an optional bundled helper binary in a future phase (e.g. a self-contained transcode helper), it **must strictly be configured under LGPL-2.1-or-later without GPL or non-free code**:
- **Non-GPL Configure Flags**:
  ```bash
  ./configure \
    --prefix=/path/to/dist \
    --enable-shared \
    --disable-static \
    --disable-gpl \
    --disable-nonfree \
    --disable-version3 \
    --enable-videotoolbox \
    --enable-audiotoolbox \
    --disable-libx264 \
    --disable-libx265 \
    --disable-libxvid \
    --enable-pic
  ```
- **Hardware Acceleration**: By targeting macOS `VideoToolbox` and `AudioToolbox`, FFmpeg utilizes Apple Silicon and Intel T2 hardware encoders for H.264, HEVC (H.265), and Apple ProRes natively. This avoids bundling copyleft GPL encoders (like `x264` or `x265`) while delivering faster encodes and lower battery consumption.
- **Separate Process Invocation**: Today, Pasta executes `ffmpeg` and `ffprobe` strictly as independent child processes. The user's system FFmpeg configuration governs its capabilities.

### 3.2 Ghostscript (AGPL-3.0)
- Ghostscript is licensed under the GNU Affero General Public License (AGPL v3.0 or later).
- **Isolation Policy**: Pasta invokes `gs` strictly through the command line via `Process()`, passing arguments as discrete array elements and capturing output through pipes. Pasta **never** links against `libgs.dylib` or includes Ghostscript header files.
- Under established open-source legal consensus (e.g. Free Software Foundation FAQ on inter-process communication), invoking an independent CLI tool at arm's length via standard OS pipes and files does not create a combined derivative work.
- Ghostscript is treated as an optional external dependency installed by the user (`brew install ghostscript`).

### 3.3 7-Zip (`7zz`) & unRAR Licensing
- 7-Zip source code is primarily licensed under the GNU LGPL v2.1 or later, with certain modules under BSD-3-Clause. However, the unRAR portion of 7-Zip contains proprietary licensing terms prohibiting reverse-engineering or recreating the RAR compression algorithm.
- Pasta uses the official `sevenzip` Homebrew formula (`/opt/homebrew/bin/7zz`), which builds the standard cross-platform standalone 7-Zip executable. Pasta does not bundle 7-Zip.

### 3.4 Poppler (`pdftoppm`, `pdftotext`) & Pandoc (GPL v2/v3)
- Both Poppler and Pandoc are licensed under the GNU General Public License (GPL).
- Pasta treats both as independent third-party utilities. All conversions (`pdftotext <file> -`, `pdftoppm -png -r 150 <file> <prefix>`, `pandoc <input> -o <output>`) run via process isolation. No GPL code or data structures are linked into Pasta.

### 3.5 LibreOffice (`soffice`) & Calibre (`ebook-convert`)
- LibreOffice is licensed under MPL-2.0 (Mozilla Public License 2.0).
- Calibre is licensed under GPL-3.0-only.
- Both are large desktop suites marked as **optional** in Pasta's `ToolLocator`. When detected, Pasta invokes them exclusively in headless CLI mode (`soffice --headless --convert-to pdf`, `ebook-convert <in> <out>`). If absent, Pasta displays clear install recommendations without failing standard app operations.

---

## 4. Verification Check

This document is continuously verified by `PastaTests` (Section 41):
1. All 19 tool names in `ToolLocator.shared.doctorReportData().tools` must exist as a dedicated table row.
2. Every table row must contain a valid HTTP/HTTPS upstream license URL or be explicitly marked `UNVERIFIED`.

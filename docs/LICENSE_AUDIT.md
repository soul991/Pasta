# Pasta Third-Party Engine License Audit & Bundling Policy

*Audit Date: 2026-11-07*  
*Auditor: Antigravity Autonomous Engineering*  
*Scope: All 19 CLI tools registered in `ToolLocator` (`ToolLocator.shared.doctorReportData().tools`)*

---

## 1. Executive Summary & Core Bundling Decision

**Current Bundling Decision for All Engines: BUNDLED.**

Pasta bundles all 19 third-party and system tool engines inside the `Pasta.app` bundle (`Contents/Resources/Engines/`):
- All conversions and media processing operations are executed as separate child processes via POSIX `Process()` with explicit argument arrays, running in a clean child environment with minimal `PATH` (`/usr/bin:/bin`), cleared dynamic loader paths (`DYLD_*`), and isolated temporary profiles.
- Zero C/C++ third-party code is statically or dynamically linked into the `Pasta` application or `PastaCore` framework binary.
- Relocatable Mach-O engines have dynamic library paths rewritten via `@loader_path` and are signed with Hardened Runtime (`--options runtime`).
- Comprehensive credits, license notices, and full texts are included in `PastaCore/Resources/acknowledgments.json` and `Pasta.app/Contents/Resources/Licenses/`. Complete corresponding source code offers and reproducible build instructions for all copyleft components (GPL, LGPL, AGPL, MPL) are published in `SOURCES.md`.

This architecture ensures complete self-contained out-of-the-box functionality with zero external downloads, while maintaining full open-source copyright and license compliance.

---

## 2. Comprehensive Tool Audit Matrix (All 19 Tools)

| Tool Name | License (SPDX) | Upstream License URL | Date Checked | How Pasta Uses It | Redistribution Obligations | Risk Level | Bundling Decision |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `ffmpeg` | LGPL-2.1-or-later | https://ffmpeg.org/legal.html | 2026-11-07 | Invoked as separate child process via `Process()` with argument arrays for video/audio transcode and stream copy | Notice retention, full license text, and corresponding source code offer (`SOURCES.md`) | Low (Subprocess isolation, LGPL-only build) | Bundled (Relocatable Mach-O binary) |
| `ffprobe` | LGPL-2.1-or-later | https://ffmpeg.org/legal.html | 2026-11-07 | Invoked as separate child process via `Process()` for media container and stream duration probing | Notice retention, full license text, and corresponding source code offer (`SOURCES.md`) | Low (Subprocess isolation, LGPL-only build) | Bundled (Relocatable Mach-O binary) |
| `cwebp` | BSD-3-Clause | https://chromium.googlesource.com/webm/libwebp/+/refs/heads/main/COPYING | 2026-11-07 | Invoked as separate child process via `Process()` for WebP image encoding | Retain copyright notice and disclaimer in documentation and license bundle | Very Low | Bundled (Relocatable Mach-O binary) |
| `magick` | ImageMagick | https://imagemagick.org/script/license.php | 2026-11-07 | Invoked as separate child process via `Process()` for raster image conversions, resizing, and rotation | Apache-2.0 compatible notice retention and license redistribution | Very Low | Bundled (Relocatable Mach-O wrapper) |
| `gs` | AGPL-3.0-or-later | https://www.ghostscript.com/license.html | 2026-11-07 | Invoked as separate child process via `Process()` for PDF optimization and level compression | Complete corresponding source code offer (`SOURCES.md`), license text retention; isolated subprocess execution | Medium (Strict copyleft, mitigated by arm's-length CLI execution and source offer) | Bundled (Relocatable Mach-O wrapper) |
| `qpdf` | Apache-2.0 OR Artistic-2.0 | https://github.com/qpdf/qpdf/blob/main/LICENSE.txt | 2026-11-07 | Invoked as separate child process via `Process()` for page counting, linearizing, split/merge, and encryption | Notice retention and Apache-2.0 / Artistic-2.0 license redistribution | Very Low | Bundled (Relocatable Mach-O binary) |
| `pdftoppm` | GPL-2.0-or-later OR GPL-3.0-or-later | https://gitlab.freedesktop.org/poppler/poppler/-/blob/master/COPYING | 2026-11-07 | Invoked as separate child process via `Process()` to rasterize PDF pages to PNG/JPEG | Strong copyleft: complete corresponding source code offer (`SOURCES.md`) and license text retention | Medium (Subprocess execution, source offer) | Bundled (Relocatable Mach-O binary) |
| `pdftotext` | GPL-2.0-or-later OR GPL-3.0-or-later | https://gitlab.freedesktop.org/poppler/poppler/-/blob/master/COPYING | 2026-11-07 | Invoked as separate child process via `Process()` for text extraction from PDF documents | Strong copyleft: complete corresponding source code offer (`SOURCES.md`) and license text retention | Medium (Subprocess execution, source offer) | Bundled (Relocatable Mach-O binary) |
| `exiftool` | Artistic-1.0-Perl OR GPL-1.0-or-later | https://github.com/exiftool/exiftool/blob/master/LICENSE | 2026-11-07 | Invoked as separate child process via `Process()` for non-destructive metadata read and edit | Notice retention and license redistribution; source offer if modified | Low (Subprocess execution, bundled Perl runtime) | Bundled (Relocatable Perl script) |
| `pandoc` | GPL-2.0-or-later | https://github.com/jgm/pandoc/blob/main/COPYRIGHT | 2026-11-07 | Invoked as separate child process via `Process()` for Markdown/HTML/DOCX format conversions | Strong copyleft: complete corresponding source code offer (`SOURCES.md`) and license text retention | Medium (Subprocess execution, source offer) | Bundled (Relocatable Mach-O binary) |
| `rsvg-convert` | LGPL-2.1-or-later | https://gitlab.gnome.org/GNOME/librsvg/-/blob/main/COPYING.LIB | 2026-11-07 | Invoked as separate child process via `Process()` for vector SVG to PNG/PDF rendering | Weak copyleft: notice retention, license redistribution, and source code offer (`SOURCES.md`) | Low (Subprocess execution, source offer) | Bundled (Relocatable Mach-O binary) |
| `unar` | LGPL-2.1-or-later | https://github.com/MacPaw/Xee/blob/master/unar/LICENSE | 2026-11-07 | Invoked as separate child process via `Process()` for multi-format archive extraction | Weak copyleft: notice retention, license redistribution, and source code offer (`SOURCES.md`) | Low (Subprocess execution, source offer) | Bundled (Relocatable Mach-O binary) |
| `7zz` | LGPL-2.1-or-later AND BSD-3-Clause | https://www.7-zip.org/license.txt | 2026-11-07 | Invoked as separate child process via `Process()` for 7z/ZIP/TAR compression and extraction | Weak copyleft: notice retention, license text retention, and source offer (`SOURCES.md`) | Low (Subprocess execution, source offer) | Bundled (Relocatable Mach-O binary) |
| `sips` | Apple Proprietary / macOS EULA | https://www.apple.com/legal/sla/ | 2026-11-07 | Invoked as separate child process via `Process()` for macOS native image resizing, format change, and querying | Part of macOS system software; invoked via system wrapper script | Low (Wrapper invocation of macOS native binary) | Bundled (macOS System Utility wrapper) |
| `ditto` | APSL-2.0 | https://opensource.apple.com/source/copyfile/copyfile-138/LICENSE | 2026-11-07 | Invoked as separate child process via `Process()` for native ZIP creation and PKZip extraction | Apple Public Source License notice retention | Low (Wrapper invocation of macOS native binary) | Bundled (macOS System Utility wrapper) |
| `tar` | BSD-2-Clause | https://github.com/libarchive/libarchive/blob/master/COPYING | 2026-11-07 | Invoked as separate child process via `Process()` for tar archive extraction and tar.gz creation | BSD 2-Clause notice retention | Low (Wrapper invocation of macOS native binary) | Bundled (macOS System Utility wrapper) |
| `soffice` | MPL-2.0 | https://www.libreoffice.org/about-us/licenses/ | 2026-11-07 | Invoked as separate child process via `Process()` in headless mode (`--headless --convert-to pdf`) | Weak copyleft (file-level): notice retention, license text redistribution, source offer for modified MPL files (`SOURCES.md`) | Low (Subprocess execution with isolated user profile) | Bundled (Standalone Application Bundle LibreOffice.app) |
| `ebook-convert` | GPL-3.0-only | https://github.com/kovidgoyal/calibre/blob/master/LICENSE | 2026-11-07 | Invoked as separate child process via `Process()` for EPUB/MOBI conversions | Strong copyleft: corresponding source code offer (`SOURCES.md`) and license text retention | Medium (Subprocess execution with private runtime) | Bundled (Standalone Application Bundle calibre.app) |
| `avifenc` | BSD-2-Clause | https://github.com/AOMediaCodec/libavif/blob/main/LICENSE | 2026-11-07 | Invoked as separate child process via `Process()` for AVIF image encoding | Permissive BSD 2-Clause notice retention | Very Low | Bundled (Relocatable Mach-O binary) |

---

## 3. Specific Engine Policies

### 3.1 FFmpeg & VideoToolbox Architecture
Pasta bundles an LGPL-only build of `ffmpeg` and `ffprobe` configured strictly under **LGPL-2.1-or-later without GPL or non-free code**:
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
- **Hardware Acceleration**: By targeting macOS `VideoToolbox` and `AudioToolbox`, FFmpeg utilizes Apple Silicon and Intel hardware encoders for H.264, HEVC (H.265), and AAC natively. This eliminates copyleft GPL software encoders (like `x264` or `x265`) while delivering faster encoding and lower power consumption.
- **Separate Process Invocation**: Pasta executes `ffmpeg` and `ffprobe` strictly as independent child processes with argument arrays.

### 3.2 Ghostscript (AGPL-3.0)
- Ghostscript is licensed under the GNU Affero General Public License (AGPL v3.0 or later).
- **Isolation Policy**: Pasta invokes `gs` strictly through the command line via `Process()`, passing arguments as discrete array elements and capturing output through pipes. Pasta **never** links against `libgs.dylib` or includes Ghostscript header files.
- Under established open-source legal consensus (e.g. Free Software Foundation FAQ on inter-process communication), invoking an independent CLI tool at arm's length via standard OS pipes and files does not create a combined derivative work.
- Complete corresponding source code offers and build scripts are published in `SOURCES.md`.

### 3.3 7-Zip (`7zz`) & unRAR Licensing
- 7-Zip source code is primarily licensed under the GNU LGPL v2.1 or later, with certain modules under BSD-3-Clause.
- Pasta bundles the standard cross-platform standalone 7-Zip executable built with non-proprietary unRAR modules or LGPL-compatible configurations.

### 3.4 Poppler (`pdftoppm`, `pdftotext`) & Pandoc (GPL v2/v3)
- Both Poppler and Pandoc are licensed under the GNU General Public License (GPL).
- Pasta treats both as independent third-party utilities. All conversions (`pdftotext <file> -`, `pdftoppm -png -r 150 <file> <prefix>`, `pandoc <input> -o <output>`) run via process isolation. No GPL code or data structures are linked into Pasta, and corresponding source offers are maintained in `SOURCES.md`.

### 3.5 LibreOffice (`soffice`) & Calibre (`ebook-convert`)
- LibreOffice is licensed under MPL-2.0 (Mozilla Public License 2.0).
- Calibre is licensed under GPL-3.0-only.
- Both desktop suites are bundled whole in `Pasta.app/Contents/Resources/Engines/` and invoked exclusively in headless CLI mode (`soffice --headless --convert-to pdf`, `ebook-convert <in> <out>`) with private user-profile directories and clean environments.

---

## 4. Verification Check

This document is continuously verified by `PastaTests` (Section 41):
1. All 19 tool names in `ToolLocator.shared.doctorReportData().tools` must exist as a dedicated table row.
2. Every table row must contain a valid HTTP/HTTPS upstream license URL or be explicitly marked `UNVERIFIED`.
3. Tools whose source in `engines.json` is bundled must not be described as "Do Not Bundle".
4. Every bundled tool must have an explicit license URL or `UNVERIFIED`.

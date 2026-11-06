# Third-Party Notices & External Engines

Pasta is a native macOS application written in Swift. **Pasta does not bundle or distribute any third-party binaries or proprietary engines.**

Instead, Pasta discovers and interacts with tools and engines installed on your system (e.g., via [Homebrew](https://brew.sh) or macOS built-in utilities). All engines are invoked as separate child processes via POSIX arguments arrays (`Process()`), never linked as shared libraries or invoked via shell interpolation.

---

## Engine Count Reconciliation

`pasta doctor` reports **19 distinct tool executables** across two categories:
- **16 User-Installed Tools**: Sourced from **14 Homebrew formulas / casks** (note that the `ffmpeg` formula provides 2 binaries: `ffmpeg` and `ffprobe`; the `poppler` formula provides 2 binaries: `pdftoppm` and `pdftotext`).
- **3 macOS Built-In Utilities**: Pre-installed on macOS (`sips`, `ditto`, `tar`).

The table below enumerates all 19 tool executables recognized by Pasta:

---

### External Engines (User-Installed via Homebrew)

| # | Binary Name | Upstream Tool / Suite | Homebrew Formula | License | Upstream Project |
| :- | :--- | :--- | :--- | :--- | :--- |
| 1 | `ffmpeg` | FFmpeg | `brew install ffmpeg` | LGPL-2.1-or-later / GPL-2.0+ | [ffmpeg.org](https://ffmpeg.org) |
| 2 | `ffprobe` | FFmpeg | `brew install ffmpeg` | LGPL-2.1-or-later / GPL-2.0+ | [ffmpeg.org](https://ffmpeg.org) |
| 3 | `cwebp` | libwebp | `brew install webp` | BSD-3-Clause | [chromium.googlesource.com/webm/libwebp](https://chromium.googlesource.com/webm/libwebp) |
| 4 | `magick` | ImageMagick | `brew install imagemagick` | ImageMagick License (Apache-2.0 compatible) | [imagemagick.org](https://imagemagick.org) |
| 5 | `gs` | Ghostscript | `brew install ghostscript` | AGPL-3.0-or-later | [ghostscript.com](https://ghostscript.com) |
| 6 | `qpdf` | QPDF | `brew install qpdf` | Apache-2.0 / Artistic-2.0 | [qpdf.sourceforge.io](https://qpdf.sourceforge.io) |
| 7 | `pdftoppm` | Poppler | `brew install poppler` | GPL-2.0-or-later / GPL-3.0 | [poppler.freedesktop.org](https://poppler.freedesktop.org) |
| 8 | `pdftotext` | Poppler | `brew install poppler` | GPL-2.0-or-later / GPL-3.0 | [poppler.freedesktop.org](https://poppler.freedesktop.org) |
| 9 | `exiftool` | ExifTool | `brew install exiftool` | Artistic-1.0-Perl / GPL-1.0+ | [exiftool.org](https://exiftool.org) |
| 10 | `pandoc` | Pandoc | `brew install pandoc` | GPL-2.0-or-later | [pandoc.org](https://pandoc.org) |
| 11 | `rsvg-convert` | librsvg | `brew install librsvg` | LGPL-2.1-or-later | [wiki.gnome.org/Projects/LibRsvg](https://wiki.gnome.org/Projects/LibRsvg) |
| 12 | `unar` | The Unarchiver | `brew install unar` | LGPL-2.1-or-later | [theunarchiver.com/command-line](https://theunarchiver.com/command-line) |
| 13 | `7zz` | 7-Zip | `brew install sevenzip` | LGPL-2.1-or-later / BSD-3-Clause | [7-zip.org](https://www.7-zip.org) |
| 14 | `soffice` (optional) | LibreOffice | `brew install --cask libreoffice` | MPL-2.0 | [libreoffice.org](https://www.libreoffice.org) |
| 15 | `ebook-convert` (optional) | Calibre | `brew install --cask calibre` | GPL-3.0-only | [calibre-ebook.com](https://calibre-ebook.com) |
| 16 | `avifenc` (optional) | libavif | `brew install libavif` | BSD-2-Clause | [github.com/AOMediaCodec/libavif](https://github.com/AOMediaCodec/libavif) |

---

### macOS Built-In Utilities (Pre-Installed)

| # | Binary Name | Binary Path | License | Description |
| :- | :--- | :--- | :--- | :--- |
| 17 | `sips` | `/usr/bin/sips` | Apple Proprietary / macOS System Software | Scriptable image processing system |
| 18 | `ditto` | `/usr/bin/ditto` | Apple Open Source (APSL-2.0) | High-fidelity archive and copy tool |
| 19 | `tar` | `/usr/bin/tar` | BSD-2-Clause (libarchive/bsdtar) | Archive manipulation utility |

# Third-Party Notices & External Engines

Pasta is an offline, native macOS application written in Swift. **Pasta does not bundle or distribute any third-party binaries or proprietary engines.**

Instead, Pasta discovers and interacts with tools and engines installed on your system (e.g., via [Homebrew](https://brew.sh) or macOS built-in utilities).

Below is the license notice for the external CLI engines supported by Pasta:

---

### External Engines (User-Installed via Homebrew)

| Tool Name | Binary Name | Homebrew Formula | License | Upstream Project |
| :--- | :--- | :--- | :--- | :--- |
| **FFmpeg** | `ffmpeg`, `ffprobe` | `brew install ffmpeg` | LGPL v2.1+ / GPL v2+ | [ffmpeg.org](https://ffmpeg.org) |
| **ImageMagick** | `magick` | `brew install imagemagick` | ImageMagick License (Apache 2.0-compatible) | [imagemagick.org](https://imagemagick.org) |
| **WebP** | `cwebp` | `brew install webp` | BSD-3-Clause | [chromium.googlesource.com/webm/libwebp](https://chromium.googlesource.com/webm/libwebp) |
| **Ghostscript** | `gs` | `brew install ghostscript` | AGPL-3.0-or-later | [ghostscript.com](https://ghostscript.com) |
| **QPDF** | `qpdf` | `brew install qpdf` | Apache-2.0 / Artistic-2.0 | [qpdf.sourceforge.io](https://qpdf.sourceforge.io) |
| **Poppler** | `pdftoppm`, `pdftotext` | `brew install poppler` | GPL-2.0 / GPL-3.0 | [poppler.freedesktop.org](https://poppler.freedesktop.org) |
| **ExifTool** | `exiftool` | `brew install exiftool` | Artistic-1.0-Perl / GPL-1.0+ | [exiftool.org](https://exiftool.org) |
| **Pandoc** | `pandoc` | `brew install pandoc` | GPL-2.0-or-later | [pandoc.org](https://pandoc.org) |
| **librsvg** | `rsvg-convert` | `brew install librsvg` | LGPL-2.1-or-later | [wiki.gnome.org/Projects/LibRsvg](https://wiki.gnome.org/Projects/LibRsvg) |
| **The Unarchiver** | `unar` | `brew install unar` | LGPL-2.1-or-later | [theunarchiver.com/command-line](https://theunarchiver.com/command-line) |
| **7-Zip** | `7zz` | `brew install sevenzip` | LGPL-2.1-or-later / BSD-3-Clause | [7-zip.org](https://www.7-zip.org) |
| **LibreOffice** | `soffice` | `brew install --cask libreoffice` | MPL-2.0 | [libreoffice.org](https://www.libreoffice.org) |
| **Calibre** | `ebook-convert` | `brew install --cask calibre` | GPL-3.0-only | [calibre-ebook.com](https://calibre-ebook.com) |
| **libavif** | `avifenc` | `brew install libavif` | BSD-2-Clause | [github.com/AOMediaCodec/libavif](https://github.com/AOMediaCodec/libavif) |

---

### macOS Built-In Utilities (Pre-Installed)

| Tool Name | Binary Path | License | Description |
| :--- | :--- | :--- | :--- |
| **sips** | `/usr/bin/sips` | Apple Proprietary / macOS System Software | Scriptable image processing system |
| **ditto** | `/usr/bin/ditto` | Apple Open Source (APSL) | High-fidelity archive and copy tool |
| **tar** | `/usr/bin/tar` | BSD-2-Clause (libarchive/bsdtar) | Archive manipulation utility |

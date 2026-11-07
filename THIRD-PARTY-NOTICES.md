# Third-Party Notices & Bundled Engines

Pasta is a native macOS application written in Swift. **Pasta bundles all 19 conversion and inspection engines inside `Pasta.app/Contents/Resources/Engines/` so that no external downloads or package managers are required for standard users.**

All engines are invoked as separate isolated child processes via POSIX argument arrays (`Process()`), never linked as shared libraries into the application binary, running in a clean child environment with minimal `PATH` (`/usr/bin:/bin`) and private profiles.

Full license texts are bundled inside `Pasta.app/Contents/Resources/Licenses/` and compiled into `PastaCore/Resources/acknowledgments.json`. Complete corresponding source code offers for all copyleft components (GPL, LGPL, AGPL, MPL) are detailed in `SOURCES.md`.

---

## Bundled Engine Inventory (All 19 Tools)

`ToolLocator` recognizes **19 distinct tool executables** across two categories:
- **16 Bundled Open-Source Engines**: Sourced from upstream official releases and relocatable bottles, packaged with rewritten `@loader_path` dynamic links or standalone application bundles in `Contents/Resources/Engines/`.
- **3 macOS Built-In Utilities**: Wrapped via relocatable scripts in `Contents/Resources/Engines/bin/` invoking native macOS binaries (`/usr/bin/sips`, `/usr/bin/ditto`, `/usr/bin/tar`).

The table below enumerates all 19 tool executables bundled with Pasta:

---

### Bundled Third-Party Engines

| # | Binary Name | Upstream Tool / Suite | Bundling Type | License | Upstream Project |
| :- | :--- | :--- | :--- | :--- | :--- |
| 1 | `ffmpeg` | FFmpeg | Relocatable Mach-O (`bin/ffmpeg`, `lib/`) | LGPL-2.1-or-later | [ffmpeg.org](https://ffmpeg.org) |
| 2 | `ffprobe` | FFmpeg | Relocatable Mach-O (`bin/ffprobe`, `lib/`) | LGPL-2.1-or-later | [ffmpeg.org](https://ffmpeg.org) |
| 3 | `cwebp` | libwebp | Relocatable Mach-O (`bin/cwebp`, `lib/`) | BSD-3-Clause | [chromium.googlesource.com/webm/libwebp](https://chromium.googlesource.com/webm/libwebp) |
| 4 | `magick` | ImageMagick | Relocatable Mach-O wrapper (`bin/magick`, `lib/`) | ImageMagick License (Apache-2.0 compatible) | [imagemagick.org](https://imagemagick.org) |
| 5 | `gs` | Ghostscript | Relocatable Mach-O wrapper (`bin/gs`, `lib/`) | AGPL-3.0-or-later | [ghostscript.com](https://ghostscript.com) |
| 6 | `qpdf` | QPDF | Relocatable Mach-O (`bin/qpdf`, `lib/`) | Apache-2.0 / Artistic-2.0 | [qpdf.sourceforge.io](https://qpdf.sourceforge.io) |
| 7 | `pdftoppm` | Poppler | Relocatable Mach-O (`bin/pdftoppm`, `lib/`) | GPL-2.0-or-later / GPL-3.0 | [poppler.freedesktop.org](https://poppler.freedesktop.org) |
| 8 | `pdftotext` | Poppler | Relocatable Mach-O (`bin/pdftotext`, `lib/`) | GPL-2.0-or-later / GPL-3.0 | [poppler.freedesktop.org](https://poppler.freedesktop.org) |
| 9 | `exiftool` | ExifTool | Relocatable Perl script (`bin/exiftool`, `lib/perl5/`) | Artistic-1.0-Perl / GPL-1.0+ | [exiftool.org](https://exiftool.org) |
| 10 | `pandoc` | Pandoc | Relocatable Mach-O (`bin/pandoc`, `lib/`) | GPL-2.0-or-later | [pandoc.org](https://pandoc.org) |
| 11 | `rsvg-convert` | librsvg | Relocatable Mach-O (`bin/rsvg-convert`, `lib/`) | LGPL-2.1-or-later | [wiki.gnome.org/Projects/LibRsvg](https://wiki.gnome.org/Projects/LibRsvg) |
| 12 | `unar` | The Unarchiver | Relocatable Mach-O (`bin/unar`, `lib/`) | LGPL-2.1-or-later | [theunarchiver.com/command-line](https://theunarchiver.com/command-line) |
| 13 | `7zz` | 7-Zip | Relocatable Mach-O (`bin/7zz`) | LGPL-2.1-or-later / BSD-3-Clause | [7-zip.org](https://www.7-zip.org) |
| 14 | `soffice` | LibreOffice | Bundled App (`LibreOffice.app/Contents/MacOS/soffice`) | MPL-2.0 | [libreoffice.org](https://www.libreoffice.org) |
| 15 | `ebook-convert` | Calibre | Bundled App (`calibre.app/Contents/MacOS/ebook-convert`) | GPL-3.0-only | [calibre-ebook.com](https://calibre-ebook.com) |
| 16 | `avifenc` | libavif | Relocatable Mach-O (`bin/avifenc`, `lib/`) | BSD-2-Clause | [github.com/AOMediaCodec/libavif](https://github.com/AOMediaCodec/libavif) |

---

### macOS Built-In Utilities (Wrapped)

| # | Binary Name | Wrapper Path | License | Description |
| :- | :--- | :--- | :--- | :--- |
| 17 | `sips` | `Engines/bin/sips` -> `/usr/bin/sips` | Apple Proprietary / macOS System Software | Scriptable image processing system |
| 18 | `ditto` | `Engines/bin/ditto` -> `/usr/bin/ditto` | Apple Open Source (APSL-2.0) | High-fidelity archive and copy tool |
| 19 | `tar` | `Engines/bin/tar` -> `/usr/bin/tar` | BSD-2-Clause (libarchive/bsdtar) | Archive manipulation utility |

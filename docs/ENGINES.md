# Pasta Bundled Engines Specification (v1.0.0 — Phase P / Step E1)

Pasta bundles all conversion and inspection engines in a private, self-contained, relocatable application bundle directory:
`Pasta.app/Contents/Resources/Engines/`

Engines are **private to the app**:
- Never installed system-wide or on the user's `PATH`.
- Never touching the user's Homebrew, Python, or external environment.
- Dynamic libraries are rewritten with `@loader_path` references so they have **zero** dependencies on `/opt/homebrew` or `/usr/local`.
- Signed with ad-hoc signature and Hardened Runtime (`--options runtime`), using the standard `com.apple.security.cs.disable-library-validation` entitlement for self-contained third-party tool runtimes.

---

## 1. Engine Inventory & Pinned Provenance

| Tool ID | Role & Actions | Pinned Version | Upstream / Package Source | License | Packaging Type |
|---|---|---|---|---|---|
| `ffmpeg` | Video & audio conversion, slicing, filtering | `9.0.2` | Homebrew `ffmpeg` 9.0.2_1 | LGPL-2.1-or-later | Relocatable Mach-O (`bin/ffmpeg`, `@loader_path/../lib`) |
| `ffprobe` | Video/audio metadata inspection & stream probing | `9.0.2` | Homebrew `ffmpeg` 9.0.2_1 | LGPL-2.1-or-later | Relocatable Mach-O (`bin/ffprobe`, `@loader_path/../lib`) |
| `cwebp` | WebP image encoding | `1.6.0` | Homebrew `webp` 1.6.0 | BSD-3-Clause | Relocatable Mach-O (`bin/cwebp`, `@loader_path/../lib`) |
| `magick` | Image conversions, transforms, and compression | `7.1.2-35` | Homebrew `imagemagick` 7.1.2-35 | ImageMagick | Relocatable Mach-O (`bin/magick`, `@loader_path/../lib`) |
| `gs` | PostScript and PDF processing, compression | `10.08.0` | Homebrew `ghostscript` 10.08.0 | AGPL-3.0-or-later | Relocatable Mach-O (`bin/gs`, `@loader_path/../lib`) |
| `qpdf` | PDF linearization, rotation, encryption, page split | `12.4.2` | Homebrew `qpdf` 12.4.2 | Apache-2.0 | Relocatable Mach-O (`bin/qpdf`, `@loader_path/../lib`) |
| `pdftoppm` | PDF rasterization to PNG/JPEG | `26.10.0` | Homebrew `poppler` 26.10.0 | GPL-2.0-or-later | Relocatable Mach-O (`bin/pdftoppm`, `@loader_path/../lib`) |
| `pdftotext` | PDF text extraction | `26.10.0` | Homebrew `poppler` 26.10.0 | GPL-2.0-or-later | Relocatable Mach-O (`bin/pdftotext`, `@loader_path/../lib`) |
| `exiftool` | Metadata inspection and EXIF stripping | `13.55` | Homebrew `exiftool` 13.55_1 | GPL-1.0-or-later / Artistic-1.0 | Relocatable Perl Script (`bin/exiftool`, `lib/perl5/`) |
| `pandoc` | Document markup conversions (MD/HTML/DOCX/PDF) | `3.13` | Homebrew `pandoc` 3.13 | GPL-2.0-or-later | Relocatable Mach-O (`bin/pandoc`, `@loader_path/../lib`) |
| `rsvg-convert` | SVG vector rendering to PNG/PDF | `2.63.4` | Homebrew `librsvg` 2.63.4 | LGPL-2.1-or-later | Relocatable Mach-O (`bin/rsvg-convert`, `@loader_path/../lib`) |
| `unar` | Archive extraction (RAR, 7z, ZIP, TAR, ISO) | `1.10.7` | Homebrew `unar` 1.10.7_1 | LGPL-2.1-or-later | Relocatable Mach-O (`bin/unar`, `@loader_path/../lib`) |
| `7zz` | 7-Zip archive extraction and creation | `26.05` | Homebrew `sevenzip` 26.05 | LGPL-2.1-or-later | Relocatable Mach-O (`bin/7zz`) |
| `sips` | Native image manipulation | `sips-316` | macOS System (`/usr/bin/sips`) | Apple Proprietary | System Wrapper Script (`bin/sips` -> `exec /usr/bin/sips "$@"`) |
| `ditto` | Native PKZip archive creation | macOS native | macOS System (`/usr/bin/ditto`) | Apple Proprietary | System Wrapper Script (`bin/ditto` -> `exec /usr/bin/ditto "$@"`) |
| `tar` | Native tarball creation and extraction | `3.5.3` | macOS System (`/usr/bin/tar`) | BSD-2-Clause | System Wrapper Script (`bin/tar` -> `exec /usr/bin/tar "$@"`) |
| `soffice` | Office document to PDF conversion | `26.8.2` | LibreOffice 26.8.2 aarch64 | MPL-2.0 | Bundled App (`LibreOffice.app/Contents/MacOS/soffice`) |
| `ebook-convert` | E-book conversions (EPUB/MOBI/PDF) | `9.18.0` | Calibre 9.18.0 aarch64 | GPL-3.0-only | Bundled App (`calibre.app/Contents/MacOS/ebook-convert`) |
| `avifenc` | AVIF modern image encoding | `1.4.2` | Homebrew `libavif` 1.4.2 | BSD-2-Clause | Relocatable Mach-O (`bin/avifenc`, `@loader_path/../lib`) |

---

## 2. Relocation & Hardened Runtime Architecture

1. **Self-Contained Dynamic Linking (`@loader_path`)**:
   - Every compiled binary in `Engines/bin/` has its external dynamic library dependencies rewritten from `/opt/homebrew/...` or `/usr/local/...` to `@loader_path/../lib/<dylib>`.
   - Every dynamic library in `Engines/lib/` has its install name ID set to `@loader_path/<dylib>` and its dependencies rewritten to `@loader_path/<dep>`.
   - All Homebrew-specific `LC_RPATH` commands are stripped.
   - Result: `otool -L` on any binary or dylib inside `Engines/` reports **zero** references to `/opt/homebrew` or `/usr/local`.

2. **Code Signing with Hardened Runtime**:
   - Every Mach-O executable and library is signed with:
     `codesign -s - -f --options runtime --entitlements /tmp/pasta_engine_entitlements.plist <path>`
   - Entitlements declare:
     ```xml
     <dict>
         <key>com.apple.security.cs.disable-library-validation</key>
         <true/>
     </dict>
     ```
     This allows relocatable ad-hoc and developer-signed engines to dynamically load their bundled sibling libraries without requiring global system-wide team registration.

3. **Perl Runtime Isolation (`exiftool`)**:
   - `exiftool` is packaged with its entire Perl module library under `Engines/lib/perl5/`.
   - The script preamble is modified to resolve `$pasta_lib` relative to `$0` (`Engines/bin/../lib/perl5`), ensuring EXIF metadata manipulation runs cleanly with `PATH=/usr/bin:/bin` and without system Perl module pollution.

4. **Manifest Schema (`engines.json`)**:
   - The manifest file `Pasta.app/Contents/Resources/Engines/engines.json` records:
     - `id`: unique tool identifier matching `ToolLocator`
     - `version`: exact version string extracted via clean-environment execution
     - `sha256`: SHA-256 hash of the executable
     - `size`: file size in bytes
     - `entry_point`: relative path from `Engines/` to the executable
     - `source`: packaging origin (`bundled_macho`, `bundled_script`, `system_symlink`, `bundled_app`)

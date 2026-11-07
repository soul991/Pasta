# Pasta Application & Component Size Report

- **Date:** 2026-11-07 12:49:53Z
- **Target Bundle:** `Pasta.app`
- **Total Bundle Size:** 450.1 MB (471965696 bytes)
- **Release Archive:** `None` (0.0 MB)
- **Size Policy:** Report-only (owner decision: no size limit in the first build)

### Bundle Component Overview

| Component | Path | Size (Bytes) | Size (MB) |
| :--- | :--- | :--- | :--- |
| **Total Pasta.app Bundle** | `Pasta.app` | 471965696 | 450.1 MB |
| App Executable Binary | `Contents/MacOS/Pasta` | 3321856 | 3.17 MB |
| Relocatable Bundled Engines (Total) | `Contents/Resources/Engines` | 467701760 | 446.04 MB |
| Third-Party Engine Licenses | `Contents/Resources/Licenses` | 77824 | 0.07 MB |
| Core Framework Build | `PastaCore.build` | 0 | 0.0 MB |
| Release Archive (Zip/DMG) | *(not packaged)* | 0 | 0.00 MB |

### Bundled Engines Detail Breakdown

| Engine | Relative Path | Size (Bytes) | Size (MB) |
| :--- | :--- | :--- | :--- |
| 7zz (`7zz`) | `Pasta.app/Contents/Resources/Engines/bin/7zz` | 2427344 | 2.31 MB |
| avifenc (`avifenc`) | `Pasta.app/Contents/Resources/Engines/bin/avifenc` | 130112 | 0.12 MB |
| cwebp (`cwebp`) | `Pasta.app/Contents/Resources/Engines/bin/cwebp` | 76912 | 0.07 MB |
| ditto (`ditto`) | `Pasta.app/Contents/Resources/Engines/bin/ditto` | 35 | 0.0 MB |
| exiftool (`exiftool`) | `Pasta.app/Contents/Resources/Engines/bin/exiftool` | 352272 | 0.34 MB |
| ffmpeg (`ffmpeg`) | `Pasta.app/Contents/Resources/Engines/bin/ffmpeg` | 424544 | 0.4 MB |
| ffprobe (`ffprobe`) | `Pasta.app/Contents/Resources/Engines/bin/ffprobe` | 252528 | 0.24 MB |
| gs (`gs`) | `Pasta.app/Contents/Resources/Engines/bin/gs` | 286 | 0.0 MB |
| magick (`magick`) | `Pasta.app/Contents/Resources/Engines/bin/magick` | 338 | 0.0 MB |
| pandoc (`pandoc`) | `Pasta.app/Contents/Resources/Engines/bin/pandoc` | 287372896 | 274.06 MB |
| pdftoppm (`pdftoppm`) | `Pasta.app/Contents/Resources/Engines/bin/pdftoppm` | 75568 | 0.07 MB |
| pdftotext (`pdftotext`) | `Pasta.app/Contents/Resources/Engines/bin/pdftotext` | 110752 | 0.11 MB |
| qpdf (`qpdf`) | `Pasta.app/Contents/Resources/Engines/bin/qpdf` | 38400 | 0.04 MB |
| rsvg-convert (`rsvg-convert`) | `Pasta.app/Contents/Resources/Engines/bin/rsvg-convert` | 6550624 | 6.25 MB |
| sips (`sips`) | `Pasta.app/Contents/Resources/Engines/bin/sips` | 34 | 0.0 MB |
| tar (`tar`) | `Pasta.app/Contents/Resources/Engines/bin/tar` | 33 | 0.0 MB |
| unar (`unar`) | `Pasta.app/Contents/Resources/Engines/bin/unar` | 2329440 | 2.22 MB |

### Policy & Threshold Assessment
Per owner decision, size is strictly report-only with no hard failure limit for the first build.
✅ Bundle and archive remain well within GitHub Release asset threshold (1.8 GiB warning ceiling).

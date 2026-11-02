# Pasta Phase 11: Documents, OCR, PDF Security, Formats, Actions Wheel, Editors

*Instructions for the AI coding agent. Date: November 2, 2026. Read all of it first. Work in the three blocks below, strictly in order. After each block, STOP, report, and wait for the owner's review before starting the next block.*

## 0. Why this phase exists

The owner compared Pasta with Tangerine (macOS) and vivo DocMaster. Pasta already matches Tangerine on video, audio, subtitles and most archives. The gaps are documents, PDF tools, OCR, a few image formats, Tangerine's Actions wheel, and interactive editors.

Already present (do not rebuild): PDF to page PNGs (folder), PDF to text, PDF compress/split/merge/reorganize, metadata read/edit, image resize/compress/QR/collage/images to PDF, DOCX/EPUB/MD/HTML/TXT conversions, optional LibreOffice "office.to.pdf".

## 1. Working rules (strict, unchanged)

- Zero network calls. Zero third-party Swift dependencies. No private or undocumented API. No shell string concatenation (executable plus argument array only). No silent failures: every failure becomes a readable PastaError.
- The dev machine may be Windows. Label anything you cannot run "written, NOT compiled or run". Real results come only from GitHub Actions log lines or the owner's Mac. Never write "verified" without a log line.
- One commit per step, CI green after each, real log lines for new tests in every report. List every fix the owner requested earlier, even if already done.
- Tests first for everything headless (fake tools via ToolLocator, fake probe, fixtures). Every new action needs: a hostile filename test (Section 8 style), zero leftover /tmp/Pasta_* directories, zero orphan processes, a source-unchanged check, and a readable error when a required tool is missing.
- Verify every command recipe by hand on a real fixture before coding it, and record it in docs/commands.md. Never guess flags.
- Optional tools (LibreOffice, Calibre, avifenc) are detected by `pasta doctor`; actions that need them are hidden when absent and appear as "needs LibreOffice" in the More ring and Customize.
- Passwords: never put a password on a command line or in logs. Pass secrets through a temporary argument file with permissions 0600, delete it in a `defer`, and redact secrets in PastaLogger. Add a test that greps the log and the process arguments for the password.

## 2. Step 0 (before every block): re-verify the previous phase and repair leftovers

1. Paste the latest CI counts (PastaTests and both Section 8 runs).
2. Confirm the owner's earlier open items, with commit hashes and test names: (a) the wheel must NOT auto-close after conversions when "keep wheel open after running" is on (commit 106b26d added auto-dismiss; fix it or make it a separate setting, default off, never closing on errors); (b) the stale-drag-pasteboard typing bug fix (the owner must confirm on the Mac); (c) the Customize tool picker and More ring work.
3. Fix any leftover warning, flaky test or `try?` that swallows a real error. Report before continuing.

---

## BLOCK A (items 1 to 4): documents, OCR, PDF security, formats

### A1. Office documents to PDF and images (LibreOffice, optional tool)
- Actions: DOCX, DOC, RTF, ODT, PPTX, PPT, XLSX, XLS to PDF; the same to PNG/JPG (one image per page or slide, saved in a folder) by chaining the PDF step and the existing `pdftoppm` step; XLSX to CSV (all sheets, one CSV per sheet, in a folder) and CSV to XLSX; also Markdown/HTML to PDF (through pandoc to HTML then the existing PDF route, or the verified recipe).
- Run LibreOffice as `soffice --headless --convert-to ...` with a **unique temporary user profile per job** (`-env:UserInstallation=file:///tmp/Pasta_lo_<jobid>`) so parallel jobs do not lock each other; delete it after. Add a timeout and the inactivity watchdog; kill soffice on cancel.
- Verify the "all sheets to CSV" filter options by hand on the installed LibreOffice version before coding.
- Fidelity honesty: record known limits in docs (fonts missing, complex layouts). Tests assert page counts and extracted text, not pixel equality.
- CI: install LibreOffice with `brew install --cask libreoffice` (check that the cask is available on the runner and note the installed version in the log) and make Section 8 cover these actions. CI runs on the `xcode-27` image with a fallback job on the older image (see docs/CODEX_HANDOFF.md). Note: some files for this block may already exist as unreviewed local work on the branch `wip/phase11-local-before-codex` (OfficeTools.swift, PDFSecurityTools.swift, VisionOCRTools.swift); audit them against this spec instead of assuming they are correct.

### A2. OCR (Apple Vision, no network)
- Image to TXT, PDF to TXT for scanned PDFs, and **searchable PDF** (page images with an invisible text layer using CoreGraphics invisible text rendering). Use `VNRecognizeTextRequest` at accurate level with language auto-detection; expose the language list in the parameter panel.
- Tests with a generated fixture image containing known text: recognized text contains the expected string; the searchable PDF passes `pdftotext` and still renders the same page image; empty or unreadable images give a readable error.

### A3. PDF security and stamping (qpdf)
- Password lock (AES-256), unlock (given the password), watermark (text and image, opacity, position), page numbers (position, format, start number).
- Watermark and page numbers: generate a stamp PDF (CoreGraphics or PDFKit), then apply with `qpdf --overlay` (one stamp page per page for numbers).
- Tests: locked file rejects opening without the password (`qpdf --check` and `pdftotext` fail), unlock restores text; watermark text is present via `pdftotext`; page numbers are correct on a 3-page fixture; password never appears in logs or arguments.

### A4. Formats: BMP, AVIF, PDF to EPUB, PDF/A-2b
- Image output BMP and AVIF (verify by hand: `sips` for BMP; AVIF through the verified route, for example ImageMagick with its AVIF delegate or `avifenc`; if AVIF is not available on the machine, hide it and say why in doctor).
- PDF to EPUB: pandoc cannot read PDF, so use `pdftotext` to HTML or Markdown then pandoc to EPUB, and label it **"text only, layout not preserved"**. If Calibre (`ebook-convert`) is installed, offer a "better layout" action.
- PDF/A-2b: Ghostscript with the proper PDFA definition and an ICC profile. Do not claim PDF/A unless the result is verified (check the `pdfaid` metadata with exiftool, and a validator if one is installable in CI); otherwise label "best effort".
- Tests: format verified with `file`, `identify`, `exiftool`, or EPUB zip structure check.

### Block A gate
All new actions have CI tests; the wheel and Customize show them under the right categories (Document, Image, PDF) with human names and distinct glyphs; Section 8 includes hostile filenames for each; `pasta doctor` shows the optional tools. **Stop and report.**

---

## BLOCK B (items 5 and 6): PDF to Word and the Actions wheel

### B1. PDF to Word and PowerPoint (best-effort, labeled Experimental)
- Use LibreOffice's PDF import (`--infilter="writer_pdf_import"` for Writer, `impress_pdf_import` for Impress) to produce DOCX and PPTX. Verify the exact filter names and output filter strings by hand.
- Show an "Experimental, layout may differ" badge in the wheel and the result row. PDF to Excel is **not** in scope unless a verified route gives acceptable tables; say so in the report.
- Tests: output opens (zip structure, `docx` readable by pandoc), extracted text contains the source text. Do not claim layout fidelity.

### B2. Tangerine-style Actions wheel
- A second wheel mode opened by a quick **Control tap** while the wheel is open (like the Option tap for Convert/Advanced), with: **AirDrop** (`NSSharingService(named: .sendViaAirDrop)` with the files), **Float** (a floating shelf window that keeps the files available for drag-out; closable with Esc), **Copy** and **Move** (choose a destination folder; remember recent ones; never overwrite, use OutputPlanner collision rules), **Copy Path** (to the pasteboard), **Open Terminal here** (setting to choose the terminal app).
- Source immutability: Move is the one action that moves a user file; require an explicit destination and confirm before cross-volume moves; log it.
- Add the actions to WheelLayoutModel so the owner can pin them like other tools.
- Tests: headless logic for Copy/Move collision, Copy Path content, AirDrop service availability check; the Float shelf and AirDrop UI go into docs/MANUAL_CHECKS.md.

### Block B gate
CI green; MANUAL_CHECKS updated for the Actions wheel and Float; experimental PDF to Word clearly labeled. **Stop and report.**

---

## BLOCK C (item 7): interactive editors (largest block; each sub-step is its own commit and gate)

All editors open in a separate native window or sheet from a wheel node ("Edit"), never inside the wheel, and always write to a **copy** (source immutable).

- **C1 PDF editor (PDFKit):** highlight, underline, strike, notes, drawing, text boxes, signatures (draw, type, or import an image; signatures stored locally in Application Support with an option to delete), fill form fields, add or reorder pages. Save as a new file.
- **C2 True redaction:** PDFKit annotations do not remove underlying text. Redaction must **rasterize the affected pages** (render with black boxes) and rebuild the PDF, then verify with `pdftotext` that the redacted text no longer exists, and warn that redacted pages become images. Add a test that proves the text is gone.
- **C3 Image editor:** visual crop with aspect presets (computed from real dimensions), rotate, flip, brightness/contrast/saturation (Core Image), annotate (arrow, box, text, blur or pixelate), and redact (opaque fill, not just a blur); save as a copy.
- **C4 Video crop UI:** a thumbnail frame with a draggable crop rectangle and presets, feeding the existing `video.crop` action.
- Document scanning (DocMaster style): import an image or a Continuity Camera photo, auto-detect the page (`VNDetectDocumentSegmentationRequest`), correct perspective, clean shadows (Core Image), and export PDF; combine with A2 for searchable output.

Tests: model-level tests for geometry, annotation serialization and redaction verification; UI structure and accessibility tests; everything visual goes to MANUAL_CHECKS.md with screenshots requested from the owner.

### Block C gate
Each sub-step green in CI; owner confirms the editors on the Mac; no claim that the UI looks right without the owner's screenshots. **Stop and report.**

---

## 3. Reporting format (every step)

- What changed (files, one line each) and commit hash.
- Failing tests written first and the real CI log lines after the fix (counts and new test names).
- Anything you could not verify and why.
- Updated `docs/PROGRESS.md` (each DONE row names its proving test), `docs/commands.md` and the README feature table, so the docs match reality.

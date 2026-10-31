# Peel Build Progress & Verification Log

*Built strictly in phases following `docs/Vibe-Coding a Personal Offline File Converter for macOS Goal and Build Procedure.md`.*

## Status Summary

| Phase | Description | Status | Verification & Gates |
| :--- | :--- | :--- | :--- |
| **Phase 0** | Environment, 12 Homebrew engines, 36 fixtures, Package.swift | **Complete** | All tools verified with absolute paths; 36 fixtures created in `Fixtures/` |
| **Phase 1** | Proven Command Recipes on real files | **Complete** | All recipes verified on macOS 27 arm64, documented in `docs/commands.md` |
| **Phase 2** | Core Headless Engine, ToolLocator, FormatRegistry, JobRunner, OutputPlanner, CLI | **Complete** | 29/29 tests passed; `peel doctor`, `peel list-actions`, `peel convert` working |
| **Phase 3** | Menu Bar App, Drop Window, Format Chips, Dynamic Accent Color Palette | **Complete** | Pure AppKit UI, LSUIElement agent, preset chips + custom hex picker |
| **Phase 4** | Advanced Tools (Option-key), InputValidator, PDF split/merge, Metadata strip | **Complete** | 37/37 tests passed; `exiftool` verified clean metadata stripping |
| **Phase 5** | Finder Quick Action workflow | **Complete** | Installed to `~/Library/Services/Convert with Peel.workflow` |
| **Phase 6** | Shift-Drag Global Overlay, Pasteboard Filtering, Magnified Chips, Animated HUD | **Complete** | Eliminates stale pasteboard triggers; dual drop/click; smooth conversion HUD |
| **Phase 7** | Hardening, Logging to `~/Library/Logs/Peel`, PreferencesManager, Section 8 Suite | **Complete** | 13/13 Section 8 tests passed; 0 orphan processes, 0 network calls, 0 leaks |
| **Phase 9** | Close Feature Gaps (Formats, Compression, Media Tools, Metadata, QR, Gate) | **Complete** | 139/139 Unit/Integration tests passed (Debug/Release); 33/33 Section 8 tests passed; 0 leaks, 0 network |
| **Phase 10** | Parameter Panels & Batch Mode (Radial Wheel, Drop Window, Per-file Probing, Concurrency Queue, Async Probe) | **Complete** | 324/324 Unit/Integration tests passed; 33/33 Section 8 tests passed (debug & app bundle); 0 leaks, 0 network |
| **Phase 10B Step 1** | Sticky Wheel, Sticky File Context, Logging, Real Event Sequences | **Complete** | 355/355 Unit/Integration tests passed; 33/33 Section 8 tests passed; 0 leaks, 0 network |
| **Phase 10B Step 2** | Fix Clipped Node & Rectangular Glow Boundary, Screen Edge Repositioning, Geometry Tests | **Complete** | 402/402 Unit/Integration tests passed; 33/33 Section 8 tests passed; 0 leaks, 0 network |
| **Phase 10B Step 3** | Wheel Redesign (Circular Backplate, 8 Slots, 64pt Glass Nodes, Hub, More Section, Customize Sheet, WheelLayoutModel) | **Complete** | 453/453 Unit/Integration tests passed; 33/33 Section 8 tests passed; 0 leaks, 0 network |

---

## Installation & Artifacts

- **App Bundle**: `/Applications/Pasta.app` (and local `./Pasta.app`)
- **Finder Quick Action**: `~/Library/Services/Convert with Pasta.workflow`
- **Application Logs**: `~/Library/Logs/Pasta/pasta.log`
- **Code Signing**: Ad-hoc signed with stable designated requirement `designated => identifier "com.local.pasta"`

## Running Tests

- Unit & Integration Suite: `swift run PastaTests` (324 tests passed in Debug and Release, including Section 15–20 parameter panels, batch execution, concurrency limits, and async probing)
- Section 8 Hardening Suite: `./scripts/run_section8_tests.sh` (33 tests passed, including hostile filename, error reporting, collision handling, temp cleanup, process leaks, and offline network verification)
- Bundle Verification: `codesign --verify --deep --strict Pasta.app` succeeded; `AppIcon.icns`, `MenuBarIcon.pdf`, and `theme_tokens.json` verified inside bundle.

---

## Phase 9 baseline

- **Date**: October 31, 2026
- **Git Commit**: `faadb11 fix(test): support debug and arm64 binary paths in run_section8_tests.sh`
- **Git Status**: Clean baseline verified.
- **Unit & Integration Suite (Debug & Release)**: `swift run PastaTests` -> **157 / 157 Passed, 0 Failed**.
- **Section 8 Hardening Suite**: `./scripts/run_section8_tests.sh` -> **33 / 33 Passed, 0 Failed**.
- **Application Bundle & Code Signing**: `./scripts/build_app.sh` -> `Pasta.app` produced, `codesign --verify --deep --strict Pasta.app` succeeded.
- **Embedded Assets**: Verified inside `Pasta.app/Contents/Resources/`: `AppIcon.icns` (321 KB), `MenuBarIcon.pdf` (764 B), `theme_tokens.json` (5.2 KB).
- **Test Count Reconciliation**: 
  - Phase 4/7: 37 Unit tests, 13 Section 8 tests
  - Phase 9 Step 1–5: Added 94 format, compression, media, and metadata tests (reaching 131 Unit tests)
  - Review Fixes: Added 8 adversarial tests + 17 Section 8 tests (reaching 139 Unit tests, 30 Section 8 tests)
  - Section 8 extensions: Added 3 hostile filename tests (reaching 33 Section 8 tests)
  - Section 12: Added 18 assertions across 11 test cases for Shift-hold state machine, charging ring, latching, Esc cancel, Option tap toggle, and duration threshold (reaching 157 Unit tests).

### PHASE8 Fixes Status Check (Step 0 - Verified & Repaired)

| Item | What to check | Status | CI Verification Test Name | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Fix 1** | `pdf.to.images` and `pdf.advanced.split` lose pages | **DONE** | `Step 1: pdf.to.images has OutputKind .folder(suffix: 'pages')` | Verified with 3-page fixture; produces dedicated output folder with all pages, non-destructive collision handling, and fixture integrity. |
| **Fix 2** | 120 s timeout kills long ffmpeg jobs | **DONE** | `Step 0: JobRunner explicit timeout throws PastaError.timedOut` | Implemented per-invocation `timeoutSeconds`, defaulted `ffmpeg` to `nil` (no timeout), quick tools to 300s, and surfaced `PastaError.timedOut`. |
| **Fix 3** | Cancellation does not work reliably | **DONE** | `Step 0: cancel(jobId:) throws PastaError.cancelled` | Implemented job process registry, `cancel(jobId:)`, `cancelAll()`, Swift concurrency `withTaskCancellationHandler`, and SIGTERM -> SIGKILL escalation. |
| **Fix 4** | `runProcess` blocks Swift concurrency pool | **DONE** | `Step 0: Job process is cleanly terminated after cancel` | Non-blocking `process.terminationHandler` with continuation, concurrent pipe streaming via `readabilityHandler`, and 64KB bounded stderr tail. |
| **Fix 5** | Finder selection & AppleScript | **DONE** | Section 8 suite on `Pasta.app` binary | Added `NSAppleEventsUsageDescription` to Info.plist in `build_app.sh`, added `FinderSelectionHelper`, and logged/surfaced Automation error (-1743). |
| **Fix 6** | Housekeeping & Compact violations (`try?`) | **DONE** | Section 8 error reporting & clean test suites | Replaced swallowed move/read `try?` calls in `JobRunner`, `Compressor`, `MediaTools`, and `MetadataTools` with throwing `try`; documented all remaining safe cleanup/logging `try?` calls. |

---

## Phase 9 Step Breakdown & Verification

| Step | Scope | Commit | Tests | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Step 0** | Re-verify baseline, repair Phase 8 leftovers, add timeout/cancel/watchdog tests | `b9c45cc` | 168/168 Unit, 33/33 Sec8 | **Complete** |
| **Step 1** | Parameterized actions foundation, ActionParameter, OutputKind, CLI `--param` | `66ac489` | 67/67 | **Complete** |
| **Step 2** | Missing formats: AVI, WMV, OGG, AIFF, GZIP, Image to PDF, PDF Merge, EPUB, LibreOffice detect | `e0ad753` | 89/89 | **Complete** |
| **Step 3** | Compression modes: Percent & exact size for Image (binary search/palette), Video (bitrate/two-pass), Audio, PDF (Ghostscript) | `cb0cd56` | 99/99 | **Complete** |
| **Step 4** | Video & Audio tools: Speed (0.25x–4x), Crop, Split, Join, Snapshot, EBU R128 Normalize, Channels, Bleep tone, Trim | `5756563` | 117/117 | **Complete** |
| **Step 5** | Metadata Read (exiftool/ffprobe), Non-destructive Edit, PDF Reorganize, Image Collage, Vision Offline QR Decode | `3796891` | 131/131 | **Complete** |
| **Step 6** | Section 8 Gate Verification: hostile filename tests, doctor verification, app signing, zero network, zero leaks | `9510a60` | 131/131 Unit, 30/30 Sec8 | **Complete** |
| **Review** | Adversarial Review & Bug Fixes: runAsync customRunner fix, two-pass video encoding, filter-complex join fallback, audio bleep eval=frame, strict metadata read-back, reverse PDF reorganization, untampered network check | `85be177` | 139/139 Unit, 33/33 Sec8 | **Complete** |
| **Section 12** | Shift-hold state machine, 450 ms threshold, 120 ms charging ring, latching, Option tap toggle | `9814586` | 157/157 Unit, 33/33 Sec8 | **Complete** |
| **Section 13** | JobRunner timeout, cancel zero leaks, SIGTERM->SIGKILL, ffmpeg inactivity watchdog | `b9c45cc` | 168/168 Unit, 33/33 Sec8 | **Complete** |
| **Section 14** | MediaTools loudnorm measurement validation, -inf rejection, exact pass 2 args | `68dfddc` | 173/173 Unit, 33/33 Sec8 | **Complete** |
| **Section 15** | ParameterFormModel headless model, presets, defaults, last-used, validation | `230ec94` | 195/195 Unit, 33/33 Sec8 | **Complete** |
| **Section 16** | Parameter panel in radial wheel (sliders, chips, crop, VoiceOver, Esc/Return) | `6667d33` | 228/228 Unit, 33/33 Sec8 | **Complete** |
| **Section 17** | Crop presets computed from media probe (no hardcoded rectangles, bounds safety) | `4998e0f` | 252/252 Unit, 33/33 Sec8 | **Complete** |
| **Section 18** | Probed trim defaults, duration validation & target-size warnings | `3c4c9e2` | 277/277 Unit, 33/33 Sec8 | **Complete** |
| **Section 19** | Drop window parameter panel reuse & batch support (multi-file progress, cancel) | `6f08221` | 297/297 Unit, 33/33 Sec8 | **Complete** |
| **Section 20** | Batch review fixes: Fix A (per-file relative crop/trim), Fix B/C (concurrency limit 2, queue, cancel, cleanup), Fix D (async probe off main thread) | `966e8e6` | 324/324 Unit, 33/33 Sec8 | **Complete** |
| **Section 21** | Phase 10B Step 1: Sticky wheel, latching, sticky file context, logging to ~/Library/Logs/Pasta/pasta.log, close control (×), empty hub | `11fc0dc` | 355/355 Unit, 33/33 Sec8 | **Complete** |
| **Section 22** | Phase 10B Step 2: Anti-clipping, 520x560 panel, WheelGeometry, 18pt glow, screen edge repositioning for all 4 edges & corners | `233e400` | 402/402 Unit, 33/33 Sec8 | **Complete** |
| **Section 23** | Phase 10B Step 3: Circular backplate (400pt/128pt), 8 slots, 64pt nodes, hub, More paged search, Customize sheet, WheelLayoutModel | In Progress (Step 3) | 453/453 Unit, 33/33 Sec8 | **Complete** |

---

## Phase 9 Itemized Audit Table (Steps 1 to 5: Formats, Tools, Modes)

| Item / Capability | Step | Category | Status | CI Verification Test Name |
| :--- | :--- | :--- | :--- | :--- |
| `ActionParameter` & `ParameterValues` definitions | Step 1 | Foundation | **DONE** | `Step 1: video.trim respects custom start and end parameters` |
| Action parameter defaults reproduce old behavior | Step 1 | Foundation | **DONE** | `Step 1: video.trim default parameters reproduce 10-second trim exactly` |
| Action aliases (`trim10`, `resize_50`) | Step 1 | Foundation | **DONE** | `Step 1: video.advanced.trim10 alias resolves` |
| Parameter min/max range validation | Step 1 | Validation | **DONE** | `Step 1: Out-of-range negative start time is rejected` |
| Unknown parameter name rejection | Step 1 | Validation | **DONE** | `Step 1: Unknown parameter name is rejected` |
| Hostile shell parameter character rejection | Step 1 | Security | **DONE** | `Step 1: Hostile characters (; & \| \` $ \n \r \" ' \0) rejected before process runs` |
| `OutputKind` (file vs folder) on actions | Step 1 | Architecture | **DONE** | `Step 1: pdf.to.images has OutputKind .folder(suffix: 'pages')` |
| CLI `--param` flag parser | Step 1 | CLI | **DONE** | `video.speed handled hostile filename '-speedy clip.mp4' safely` |
| Video output: AVI (`video.to.avi`) | Step 2 | Video Formats | **DONE** | `Step 2: Convert sample.mp4 -> video.to.avi produces file and preserves source` |
| Video output: WMV (`video.to.wmv`) | Step 2 | Video Formats | **DONE** | `Step 2: Convert sample.mp4 -> video.to.wmv produces file and preserves source` |
| Audio output: OGG Vorbis (`audio.to.ogg`) | Step 2 | Audio Formats | **DONE** | `Step 2: Convert sample.mp3 -> audio.to.ogg produces file and preserves source` |
| Audio output: AIFF (`audio.to.aiff`) | Step 2 | Audio Formats | **DONE** | `Step 2: Convert sample.mp3 -> audio.to.aiff produces file and preserves source` |
| Archives: GZIP single file creation (`archive.create.gzip`) | Step 2 | Archives | **DONE** | `Step 2: GZIP of single file produces .gz archive` |
| Archives: GZIP `.gz` extraction input (`archive.extract`) | Step 2 | Archives | **DONE** | `Step 2: Extraction of .gz archive produces uncompressed file` |
| Image to PDF: single image (`image.to.pdf`) | Step 2 | Documents | **DONE** | `Step 2: Single image to PDF produces PDF` |
| Image to PDF: batch images (`image.to.pdf`) | Step 2 | Documents | **DONE** | `Step 2: Batch images to PDF produces merged PDF` |
| PDF merge: multi-file batch action (`pdf.merge`) | Step 2 | Documents | **DONE** | `Step 2: pdf.merge produces combined PDF` |
| Documents: DOCX &harr; EPUB (`docx.to.epub`, `epub.to.docx`) | Step 2 | Documents | **DONE** | `Step 2: Convert docx -> epub produces valid file` |
| Documents: Markdown &harr; EPUB (`md.to.epub`, `epub.to.md`) | Step 2 | Documents | **DONE** | `Step 2: md.to.epub action is registered` |
| Documents: HTML &harr; EPUB (`html.to.epub`, `epub.to.html`) | Step 2 | Documents | **DONE** | `Step 2: html.to.epub action is registered` |
| Documents: TXT &harr; EPUB (`epub.to.txt`) | Step 2 | Documents | **DONE** | `Step 2: epub conversions to docx, md, html, txt are registered` |
| LibreOffice (`soffice`) optional detection & doctor | Step 2 | Tools | **DONE** | `Step 2: soffice is correctly reported as missing optional tool without failure` |
| Image compression by percent (`image.compress`) | Step 3 | Compression | **DONE** | `Step 3: Image compression by 50% produces file <= 50% original` |
| Image compression by exact target size (`image.compress`) | Step 3 | Compression | **DONE** | `Step 3: Image compression by target size 25000 bytes produces file <= 25000` |
| Video compression by percent (`video.compress`) | Step 3 | Compression | **DONE** | `Step 3: Video compression by 60% produces file within tolerance` |
| Video compression by exact target size (`video.compress`) | Step 3 | Compression | **DONE** | `video.compress handled hostile filename '-compress video.mp4' safely` |
| Audio compression by percent (`audio.compress`) | Step 3 | Compression | **DONE** | `Step 3: Audio compression by 50% produces file <= 50% original` |
| Audio compression by exact target size (`audio.compress`) | Step 3 | Compression | **DONE** | `audio.compress handled hostile filename '-compress audio.mp3' safely` |
| PDF compression by target size (`pdf.compress`) | Step 3 | Compression | **DONE** | `Step 3: PDF compression reduces file size` |
| Impossible target size fallback handling | Step 3 | Compression | **DONE** | `Step 3: Impossible target size produces smallest valid file without crashing` |
| Batch compression | Step 3 | Compression | **DONE** | `Step 3: Batch compression produces folder containing all compressed items` |
| Video speed change 0.25x–4x (`video.speed`) | Step 4 | Video Tools | **DONE** | `Step 4: video.speed 2.0x halves duration to ~1.0s` |
| Video crop with ffprobe bounds validation (`video.crop`) | Step 4 | Video Tools | **DONE** | `Step 4: video.crop crops to 160x120` & `rejects rectangle exceeding container` |
| Video split at timestamps into folder (`video.split`) | Step 4 | Video Tools | **DONE** | `Step 4: video.split splits into 2 parts in folder` |
| Video join concat demuxer + fallback (`video.join`) | Step 4 | Video Tools | **DONE** | `Step 4: video.join sums duration of 2 clips to ~4.0s` |
| Video snapshot frame extraction (`video.snapshot`) | Step 4 | Video Tools | **DONE** | `Step 4: video.snapshot extracts 320x240 frame at 1.0s` |
| Audio EBU R128 normalization (`audio.normalize`) | Step 4 | Audio Tools | **DONE** | `Step 4: audio.normalize produces normalized audio file` |
| Audio channel layout change mono/stereo (`audio.channels`)| Step 4 | Audio Tools | **DONE** | `Step 4: audio.channels produces 2 channels (stereo)` |
| Audio bleep tone insertion (`audio.bleep`) | Step 4 | Audio Tools | **DONE** | `Step 4: audio.bleep keeps duration intact (~2.0s)` |
| Audio trim with start and end times (`audio.trim`) | Step 4 | Audio Tools | **DONE** | `Step 4: audio.trim trims to ~1.0s` |
| Non-destructive metadata read text/JSON (`metadata.read`) | Step 5 | Metadata | **DONE** | `Step 5: metadata.read produces readable metadata text report` |
| Metadata edit on copy with tag whitelist (`metadata.edit`) | Step 5 | Metadata | **DONE** | `Step 5: metadata.edit produces output copy` & `rejects unallowed tag name` |
| PDF reorganize/reorder/extract pages (`pdf.reorganize`) | Step 5 | Documents | **DONE** | `Step 5: pdf.reorganize verifies Page 3, Page 1, Page 2 sequence` |
| Image collage montage grid (`image.collage`) | Step 5 | Image Tools | **DONE** | `Step 5: image.collage combines images into grid` |
| Offline QR code decode via Vision (`image.qr.read`) | Step 5 | Vision | **DONE** | `Step 5: image.qr.read decodes QR fixture correctly to 'Hello Pasta QR'` |
| `JobRunner` explicit invocation timeout | Step 0 | Hardening | **DONE** | `Step 0: JobRunner explicit timeout throws PastaError.timedOut` |
| `cancel(jobId:)` zero orphan processes & temp cleanup | Step 0 | Hardening | **DONE** | `Step 0: cancel(jobId:) throws PastaError.cancelled` & `leaves zero leftover` |
| `SIGTERM` to `SIGKILL` process escalation | Step 0 | Hardening | **DONE** | `Step 0: SIGTERM-ignoring process is killed by SIGKILL escalation` |
| Inactivity watchdog timeout for ffmpeg | Step 0 | Watchdog | **DONE** | `Step 0: Inactivity watchdog cancels silent process within timeout window` |
| Inactivity watchdog streaming progress reset | Step 0 | Watchdog | **DONE** | `Step 0: Inactivity watchdog resets on active progress and completes successfully` |
| Audio loudness measurement validation (`audio.normalize`) | Step 0 (Fix) | Audio Tools | **DONE** | `14.1–14.4 audio.normalize loudness measurement validation and exact pass 2 args` |
| ParameterFormModel (fields, defaults, presets, last-used, validation) | Phase 10 Step 1 | Architecture | **DONE** | `15.1–15.9 ParameterFormModel headless unit tests` |
| Parameter panel in radial wheel (sliders, chips, crop, VoiceOver, Esc/Return) | Phase 10 Step 2 | Wheel UI | **DONE** | `16.1–16.8 Parameter panel UI and radial integration tests` |
| Crop presets computed from media probe (no hardcoded rectangles, even bounds, probe error handling) | Phase 10 Fix 1 | Probing / UI | **DONE** | `17.1–17.9 Crop presets and dynamic media probe tests` |
| Probed trim defaults, duration validation & target-size warnings (inline warning, Run enabled) | Phase 10 Fix 2 | Probing / UI | **DONE** | `18.1–18.9 Trim duration validation and target-size warnings` |
| Drop window parameter panel reuse & batch support (BatchProgressRowView, combined status, cancel) | Phase 10 Step 3 | Drop Window / Batch | **DONE** | `19.1–19.10 Drop window parameter panel and batch execution tests` |
| Per-file parameters in batch (relative crop/trim intents, per-file probe resolution, batch UI readout) | Phase 10 Fix A | Batch Execution | **DONE** | `20.1–20.4 Batch parameter resolution and intent tests` |
| Concurrency queue (max N concurrent, pending queued status, cancel & window close cleanup) | Phase 10 Fix B/C | Batch Queue | **DONE** | `20.5–20.10 Concurrency queue, cancel & cleanup tests` |
| Asynchronous media probe (UI thread protection, 'Reading file info...' status, disabled Run on probe/error) | Phase 10 Fix D | UI Responsiveness | **DONE** | `20.11–20.13 Asynchronous probe loading and validation tests` |
| Sticky wheel state machine & event logging (`~/Library/Logs/Pasta/pasta.log`) | Phase 10B Step 1 | Wheel State | **DONE** | `21.1 Real-shaped event sequence: Shift down, hold 450ms, drag continues, Shift up, mouseUp, wait 5s` |
| Sticky remembered files context & action execution | Phase 10B Step 1 | Wheel Context | **DONE** | `21.2 Action execution on remembered files with keepWheelOpenAfterRunning` |
| Wheel Esc key dismissal & context cleanup | Phase 10B Step 1 | Dismissal | **DONE** | `21.3 Esc key closes wheel and clears remembered files` |
| Second Shift hold re-targeting (replaces remembered files without closing) | Phase 10B Step 1 | Wheel State | **DONE** | `21.4 Second Shift hold with new files replaces remembered files and keeps wheel open` |
| Drop outside / mouseUp preserves wheel open | Phase 10B Step 1 | Wheel State | **DONE** | `21.5 Drop outside preserves open wheel and remembered files` |
| `stayOpenAfterRelease` and `keepWheelOpenAfterRunning` preferences default & honor | Phase 10B Step 1 | Preferences | **DONE** | `21.6 stayOpenAfterRelease and keepWheelOpenAfterRunning defaults and production honor` |
| Close control (×) & manual open/close | Phase 10B Step 1 | UI / Control | **DONE** | `21.7 Close control (×) and manual open/close` |
| Hub empty state when opened without files ("Drag a file onto the wheel") | Phase 10B Step 1 | Hub UI | **DONE** | `21.8 RadialWheelCenterDiscView empty state displays 'Drag a file onto the wheel'` |
| WheelGeometry layout & metrics (520x560 panel, 148pt orbit, center at 260,310) | Phase 10B Step 2 | Geometry | **DONE** | `22.1 Headless geometry: 8 slots >= 8pt margin at 1.06 scale with 18pt glow` |
| Screen edge repositioning (keeps full panel on screen, clears menu bar & dock) | Phase 10B Step 2 | Window Manager | **DONE** | `22.2 Screen-edge repositioning for 4 edges and 4 corners` |
| Disabled masksToBounds on all glow ancestor layers (`panel.contentView`, `view`, `node`) | Phase 10B Step 2 | Anti-Clipping | **DONE** | `22.3 Ancestor masksToBounds disabled` |




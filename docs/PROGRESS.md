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
| **Phase 10B Step 4** | Liquid Glass Rendering, Wallpaper Scrim, High-Contrast Modes, VoiceOver & Keyboard Nav | **Complete** | 508/508 Unit/Integration tests passed; 33/33 Section 8 tests passed; 0 leaks, 0 network |
| **Phase 10B Step 5** | Brand Presence (MenuBarIcon 18pt Template, Pasta Icon in Hub/Settings/About, AppIcon.icns, CFBundleIconFile) | **Complete** | 529/529 Unit/Integration tests passed; 33/33 Section 8 tests passed; 0 leaks, 0 network |
| **Phase 10B Step 6** | Results, Errors, Size Changes, Reveal in Finder, Copy Details, Accessibility Onboarding & Settings | **Complete** | 549/549 Unit/Integration tests passed; 33/33 Section 8 tests passed; 0 leaks, 0 network |
| **Phase R0** | Release Readiness: Atomic Output Reservation, Hostile Archive Hardening, Actionable Doctor, Release Tag v0.1.0-beta | **Complete** | All gates verified; tag v0.1.0-beta shipped |
| **Phase 11 Block A** | Documents, OCR, PDF Security, Formats (Office conversions, Vision OCR, qpdf lock/unlock/watermark/page numbers, BMP, AVIF, PDF/A-2b, PDF to EPUB) | **Complete** | 903/903 Unit tests passed; 47/47 Section 8 tests passed; 0 leaks, 0 network |

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
| **Section 23** | Phase 10B Step 3: Circular backplate (400pt/128pt), 8 slots, 64pt nodes, hub, More paged search, Customize sheet, WheelLayoutModel | `5d42c0b` | 453/453 Unit, 33/33 Sec8 | **Complete** |
| **Section 24** | Phase 10B Step 4: Liquid Glass rendering, wallpaper adaptivity scrim, accessibility modes, VoiceOver, keyboard nav | `0664ab6` | 508/508 Unit, 33/33 Sec8 | **Complete** |
| **Section 25** | Phase 10B Step 5: Brand presence (MenuBarIcon 18pt template, hub idle icon, Settings header, About panel, AppIcon.icns) | `dd3acb1` | 529/529 Unit, 33/33 Sec8 | **Complete** |
| **Section 26** | Phase 10B Step 6: Results, errors, real size changes, Reveal in Finder, Copy Details, Accessibility Onboarding & Settings | `fff5dcc` | 549/549 Unit, 33/33 Sec8 | **Complete** |

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
| Documents: Markdown &harr; EPUB (`md.to.epub`, `epub.to.md`) | Step 2 | Documents | **DONE** | `48.45/48.31 Behavioral end-to-end fixture test` |
| Documents: HTML &harr; EPUB (`html.to.epub`, `epub.to.html`) | Step 2 | Documents | **DONE** | `48.37/48.30 Behavioral end-to-end fixture test` |
| Documents: TXT &harr; EPUB (`epub.to.txt`) | Step 2 | Documents | **DONE** | `48.33 Behavioral end-to-end fixture test` |
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
| Hub empty state when opened without files ("Drag a file onto the wheel") | Phase 10B Step 1 | Hub UI | **DONE (structure only)** | `21.8 RadialWheelCenterDiscView empty state displays 'Drag a file onto the wheel'` |
| WheelGeometry layout & metrics (520x560 panel, 148pt orbit, center at 260,310) | Phase 10B Step 2 | Geometry | **DONE** | `22.1 Headless geometry: 8 slots >= 8pt margin at 1.06 scale with 18pt glow` |
| Screen edge repositioning (keeps full panel on screen, clears menu bar & dock) | Phase 10B Step 2 | Window Manager | **DONE** | `22.2 Screen-edge repositioning for 4 edges and 4 corners` |
| Disabled masksToBounds on all glow ancestor layers (`panel.contentView`, `view`, `node`) | Phase 10B Step 2 | Anti-Clipping | **DONE (structure only)** | `22.3 Ancestor masksToBounds disabled` |
| Circular glass backplate annulus (400pt outer / 128pt inner, 0.12 connecting radial wedge) | Phase 10B Step 3 | Wheel Redesign | **DONE** | `23.1 Backplate annulus path and connecting wedge` |
| 64pt circular glass node buttons (1.00–1.06 hover scale, no clipping, theme ink) | Phase 10B Step 3 | Wheel Redesign | **DONE** | `23.2 Circular button node views and hover scale` |
| Center hub (64pt single file thumbnail, middle truncation, multi-file stacked badge, idle rigatoni) | Phase 10B Step 3 | Hub Redesign | **DONE** | `23.3 Center disc single, multi-file stacked, and idle states` |
| More section (560pt paged arc, search filter, page dots, Esc closes More first) | Phase 10B Step 3 | More Ring | **DONE** | `23.4 More section paged arc and real-time search filter` |
| Customize glass sheet (Appearance, Primary Tools reorder/hide/reset, Behavior, live apply) | Phase 10B Step 3 | Customize Sheet | **DONE** | `23.5 Customize sheet sections and live preferences persistence` |
| WheelLayoutModel headless model (defaults, pinned 6, More all minus pinned, unavailable excluded) | Phase 10B Step 3 | Model / Architecture | **DONE** | `23.6–23.7 WheelLayoutModel headless unit tests` |
| WCAG contrast >= 4.5:1 for every theme palette (Sunset, Ocean, Emerald, Violet, Rose, Graphite, System) | Phase 10B Step 3 | Contrast Verification | **DONE** | `23.8 WCAG contrast ratio calculation >= 4.5:1` |
| 8-slot wheel composition (Slots 0–5 primary tools, Slot 6 More ellipsis, Slot 7 Customize gear) | Phase 10B Step 3 | Layout Model | **DONE** | `23.9 8-slot wheel composition layout` |
| Wallpaper adaptivity scrim (<= 0.35 alpha) & WCAG contrast >= 4.5:1 over Red, White, Dark, Gray | Phase 10B Step 4 | Visual Quality | **DONE** | `24.1 Wallpaper adaptivity scrim and multi-background contrast` |
| Reduce Transparency accessible rendering (opaque dark background #242426) | Phase 10B Step 4 | Accessibility | **DONE** | `24.2 Reduce Transparency opaque surface rendering` |
| Increase Contrast accessible rendering (2.0pt border, high contrast stroke) | Phase 10B Step 4 | Accessibility | **DONE** | `24.3 Increase Contrast strengthened border rendering` |
| Reduce Motion accessible behavior (instant alpha crossfade, zero spring, no pulsing glows) | Phase 10B Step 4 | Accessibility | **DONE** | `24.4 Reduce Motion crossfade animation behavior` |
| VoiceOver accessibility (button roles, descriptive labels and help on all 8 slots, group on hub) | Phase 10B Step 4 | Accessibility | **DONE (structure only)** | `24.5 Full VoiceOver accessibility coverage on wheel slots and hub` |
| Full keyboard navigation (Arrow keys cyclic navigation, Tab cycle, Return/Space execute, Esc hierarchy) | Phase 10B Step 4 | Keyboard Nav | **DONE** | `24.6 Keyboard navigation cyclic focus, execution, and dismissal` |
| Liquid glass design tokens in theme_tokens.json (specular stroke, sheen, inner shadow, scrim) | Phase 10B Step 4 | Design Tokens | **DONE** | `24.7 Liquid glass design tokens validation` |
| Menu bar icon template glyph (`MenuBarIcon.pdf`, 18pt x 18pt, isTemplate=true) | Phase 10B Step 5 | Brand Presence | **DONE (structure only)** | `25.1 Menu bar icon loads as template with 18x18 size` |
| Status item button verification helper & diagnostic logging | Phase 10B Step 5 | Brand Presence | **DONE** | `25.2–25.3 Status item button verification and error logging` |
| App icon loading with valid positive dimensions | Phase 10B Step 5 | Brand Presence | **DONE (structure only)** | `25.4 BrandAssetManager.loadAppIcon loads successfully` |
| Idle wheel hub displays rigatoni Pasta icon tinted with accent color | Phase 10B Step 5 | Hub Brand | **DONE (structure only)** | `25.5 Center disc empty state displays rigatoni Pasta icon` |
| SettingsWindowController header contains brand icon, 'Pasta' title, and subtitle | Phase 10B Step 5 | Settings UI | **DONE (structure only)** | `25.6 SettingsWindowController header contains brand icon and title` |
| Bundle assets valid (AppIcon.icns > 50KB, MenuBarIcon.pdf vector template < 5KB) | Phase 10B Step 5 | Bundle Assets | **DONE (structure only)** | `25.7 Bundle assets existence and size check` |
| Progress rows with ETA and active Cancel button | Phase 10B Step 6 | Results & Progress | **DONE** | `26.1 JobStatusRowView shows ETA in running state and Cancel button` |
| Real size change computation and formatting (`inMB → outMB [-XX%]`) | Phase 10B Step 6 | Results & Progress | **DONE** | `26.2 formatByteSize handles bytes, KB, and MB` |
| Readable errors with 'Copy Details' clipboard reporting | Phase 10B Step 6 | Error Reporting | **DONE** | `26.3 Copy Details copied error report header to pasteboard` |
| BatchProgressRowView ETA estimation during multi-file conversion | Phase 10B Step 6 | Batch Progress | **DONE** | `26.4 BatchProgressRow completed count and summary label` |
| First-run Accessibility onboarding view & permission detection polling | Phase 10B Step 6 | Onboarding | **DONE (structure only)** | `26.5–26.6 AccessibilityOnboardingView UI and permission detection` |
| Unsupported file and empty states in Wheel and Drop Window | Phase 10B Step 6 | Empty States | **DONE (structure only)** | `26.7 Center disc and DropWindow unsupported file states` |
| Customize sheet z-order: hide nodes and backplate when sheet opens, restore on close; headless geometry test | Phase 10B Fix 1 (P0) | Customize Z-Order | **DONE** | `27.1–27.4 Zero node intersection with sheet` |
| Tools tab human display names & glyphs, 6 pinned list with keyboard up/down, Remove control, Add tool picker | Phase 10B Fix 2 (P1) | Tools Customization | **DONE** | `28.1–28.4 Action human names, icons, pinned slots, add picker` |
| Two-row category tabs, 32pt circular theme swatches with label, un-truncated labels with longest strings test | Phase 10B Fix 3 (P1) | Sheet Layout | **DONE** | `29.1–29.4 Category tabs, swatches, and string widths` |
| Live miniature wheel preview in Appearance tab updating for color, glass style, strength, and size | Phase 10B Fix 4 (P1) | Live Preview | **DONE** | `30.1–30.6 MiniatureWheelPreviewView live rendering` |
| Node design: transparent glass labels with subtle text shadow, 11pt font, distinct format glyphs, accent active fill | Phase 10B Fix 5 (P1) | Node Visual Design | **DONE** | `31.1–31.3 Distinct glyphs, glass labels, dark ink active` |
| Glass color bleed removal (neutral dark base), Sunset default hex (#F2611F), accent-tinted controls, 4.5:1 text contrast | Phase 10B Fix 6 (P2) | Color & Contrast | **DONE** | `32.1–32.4 Backplate base, theme accent tint, WCAG 4.5:1` |
| Results row: indeterminate & determinate progress bar, live ETA, Cancel wiring to cancel(jobId:), middle truncation | Phase 10B Fix 7 (P2) | Results & Progress | **DONE** | `33.1–33.6 Progress bar, ETA, cancel, middle truncation` |
| Hint pill: shortened text, dynamic placement above wheel when screen bottom is cramped | Phase 10B Fix 8 (P3) | Hint Pill Placement | **DONE** | `34.1–34.4 Shortened text and dynamic above-wheel placement` |
| Atomic output reservation (`OutputReservation`, `open(O_CREAT\|O_EXCL)`, `rename(2)`, zero collisions) | Phase R0 Step 1 | Reliability | **DONE** | `38.1–38.7 Atomic Output Reservation & Collision Race Tests`, `Section 8 Tests 7.1–7.2` |
| Hostile archive extraction suite (`ArchiveGuard`, traversal rejection, depth/size/symlink/setuid limits) | Phase R0 Step 2 | Security | **DONE** | `39.1–39.11 Hostile Archive Extraction Tests (ArchiveGuard)`, `Section 8 Tests 7.3` |
| Repo hygiene, actionable doctor (`--json`, Homebrew formula mappings, Settings copy button), release workflow (`release.yml`), automated README generation | Phase R0 Step 3 | Reliability & Release | **DONE** | `40.1–40.8 Actionable Doctor, Homebrew Mappings & Action Catalog Tests`, `Section 8 Tests 7.4` |

---

## Phase 11 Block A Itemized Audit Table (Documents, OCR, PDF Security, Formats)

| Item / Capability | Step | Category | Status | CI Verification Test Name |
| :--- | :--- | :--- | :--- | :--- |
| Office to PDF (`office.to.pdf`, `docx.to.pdf`) with isolated profile `-env:UserInstallation` | Block A1 | Documents | **DONE** | `37.1 docx.to.pdf is registered for docx` & `37.1 soffice invocation automatically receives isolated user profile argument` |
| Office to page/slide images (`docx.to.images`, `office.to.images`) | Block A1 | Documents | **DONE** | `37.1 docx.to.images is registered for docx` & `37.1 office.to.images is labeled 'Extract Slides to PNGs' for pptx` |
| Multi-sheet XLSX to CSVs extraction in dedicated folder (`xlsx.to.csv`) | Block A1 | Spreadsheets | **DONE** | `37.1 XLSX multi-sheet extraction created Employees.csv` & `37.1 Salaries.csv contains numeric cell data` |
| CSV to XLSX conversion (`csv.to.xlsx`) | Block A1 | Spreadsheets | **DONE** | `37.1 csv.to.xlsx is registered for csv` |
| Markdown & HTML to PDF (`md.to.pdf`, `html.to.pdf`) | Block A1 | Documents | **DONE** | `37.1 md.to.pdf is registered for md` & `37.1 html.to.pdf is registered for html` |
| Optional `soffice` tool detection, requirement note, and wheel slot hiding | Block A1 | Tools | **DONE** | `37.1 Missing soffice tool throws PastaError.missingTool('soffice')` & `37.1 docx.to.pdf is hidden from primary wheel slots when soffice is missing` |
| Image to Text OCR via Apple Vision (`image.ocr.text`) | Block A2 | OCR | **DONE** | `37.2 VisionOCRTools recognizes known text from generated image fixture` & `Section 8 image.ocr.text handled hostile filename safely` |
| PDF to Text OCR for scanned PDFs (`pdf.ocr.text`) | Block A2 | OCR | **DONE** | `37.2 VisionOCRTools recognizes text directly from PDF pages` |
| Searchable PDF creation with invisible text layer (`image.ocr.searchable`, `pdf.ocr.searchable`) | Block A2 | OCR | **DONE** | `37.2 Searchable PDF created successfully` & `37.2 pdftotext extracts invisible text layer from searchable PDF` |
| PDF AES-256 password lock with 0600 temp argument file (`pdf.security.lock`) | Block A3 | PDF Security | **DONE** | `37.3 PDFSecurityTools.lockPDF creates encrypted PDF` & `37.3 Encrypted PDF rejects pdftotext without password` |
| PDF password unlock with verification (`pdf.security.unlock`) | Block A3 | PDF Security | **DONE** | `37.3 PDFSecurityTools.unlockPDF restores decrypted PDF` & `37.3 Unlocked PDF text matches original text exactly` |
| PDF security password edge cases (wrong password, empty password, malformed PDF) | Block A3 | PDF Security | **DONE** | `37.3 PDFSecurityTools.unlockPDF rejects incorrect password` & `37.3 PDFSecurityTools.lockPDF rejects malformed PDF with error` |
| Rule 19 password redaction in logs and arguments | Block A3 | Security | **DONE** | `37.3 Rule 19: Password string 'SuperSecret_P@ssword_2026!' NEVER appears in pasta.log` |
| PDF watermark stamping with position and opacity (`pdf.watermark`) | Block A3 | PDF Stamping | **DONE** | `37.3 Watermark PDF created` & `37.3 Watermark text 'PASTA_SECRET_STAMP' present in output via pdftotext` |
| PDF page numbering on multi-page documents (`pdf.pagenumbers`) | Block A3 | PDF Stamping | **DONE** | `37.3 Page numbers stamped on 3-page fixture` & `37.3 Page numbers 'Page 1 of 3', 'Page 2 of 3', 'Page 3 of 3' present on all pages` |
| BMP image conversion (`image.to.bmp`) | Block A4 | Image Formats | **DONE** | `37.4 image.to.bmp produces output file` & `37.4 BMP output format verified with file` |
| AVIF image conversion (`image.to.avif`) | Block A4 | Image Formats | **DONE** | `37.4 image.to.avif produces output file` & `37.4 AVIF output format verified with file` |
| PDF to EPUB text-only conversion (`pdf.to.epub`) | Block A4 | Documents | **DONE** | `37.4 PDF to EPUB creates output file` & `37.4 EPUB zip structure contains valid mimetype application/epub+zip` |
| PDF to PDF/A-2b archival format (`pdf.to.pdfa`) | Block A4 | Documents | **DONE** | `37.4 PDF to PDF/A-2b creates output file` & `37.4 PDF/A-2b metadata verified with exiftool (Part: 2, Conformance: B)` |
| Calibre optional tool registration & doctor hint (`pdf.to.epub.calibre`) | Block A4 | Tools | **DONE** | `37.4 pdf.to.epub.calibre action is registered` & `37.4 pdf.to.epub.calibre requirementNote is 'needs Calibre' when missing` |

---

## Part C Itemized Audit Table (Small Features)

| Item / Capability | Step | Category | Status | CI Verification Test Name |
| :--- | :--- | :--- | :--- | :--- |
| Per-engine concurrency limit table (`BatchJobQueue.perEngineLimits`) with default caps (gs/ghostscript: 1, ffmpeg: 2, others unconstrained) | Step C1 | Concurrency | **DONE** | `42.1 Default per-engine limits table specifies cap 2 for ffmpeg and 1 for ghostscript` |
| Queue-level and global slot acquisition limiting concurrent ffmpeg jobs to at most 2 | Step C1 | Concurrency | **DONE** | `42.2 All 6 queued ffmpeg jobs complete successfully` & `42.3 Peak concurrency for 6 queued ffmpeg jobs never exceeds cap 2` |
| Queue-level and global slot acquisition limiting concurrent ghostscript jobs to at most 1 | Step C1 | Concurrency | **DONE** | `42.4 All 4 queued ghostscript jobs complete successfully` & `42.5 Peak concurrency for 4 queued ghostscript jobs never exceeds cap 1` |
| Recent conversions local persistent store in Application Support (`recent_conversions.json`) | Step C2 | Storage | **DONE** | `43.2 Initial fresh store has empty items list`, `43.3 RecentConversionsStore records conversion item`, `43.4 Recorded item contains actionId, fileName, and fullPath`, `43.5 Recent conversions persist across store instances reading from disk` |
| History privacy controls: master toggle and path suppression | Step C2 | Privacy | **DONE** | `43.1 Default preferences for recent conversions (enabled == true, storeFullPath == true)`, `43.6 Privacy off switch prevents recording new conversion items`, `43.7 Disabling storeFullPath records fileName but omits fullPath` |
| History clearing (in-memory wipe & disk removal) | Step C2 | Storage | **DONE** | `43.8 Clear wipes in-memory items and removes or empties disk file` |
| Malformed / corrupt store JSON resilience | Step C2 | Resilience | **DONE** | `43.9 Corrupt JSON store file recovers gracefully without crashing` |
| Reveal in Finder integration with missing file handling | Step C2 | Finder | **DONE** | `43.10 Reveal in Finder on nonexistent file safely returns false without crashing`, `43.11 Reveal in Finder on item without fullPath safely returns false`, `43.12 Reveal in Finder on existing file returns true` |
| Per-file-type wheel profiles with ordered primary tools | Step C3 | Wheel Profiles | **DONE** | `44.1 Default file-type wheel profiles define primary actions for core formats`, `44.3 PDF profile primary actions contain essential compression and extraction tools` |
| Secondary wheel action profiles reachable via Tab flip side | Step C3 | Wheel Profiles | **DONE** | `44.2 Default file-type wheel profiles define secondary (flip-side) actions`, `44.4 PDF profile secondary actions contain watermark, archival, and security tools` |
| Tab flip side state transitions & reset | Step C3 | Interaction | **DONE** | `44.5 Initial side is primary`, `44.6 flipSide toggles side to secondary`, `44.7 flipSide second toggle returns side to primary`, `44.8 resetSide returns side to primary` |
| Distinct primary and secondary wheel slot generation | Step C3 | Wheel Layout | **DONE** | `44.9 Primary and secondary slots produce distinct action sets for target file` |
| Shift-hold duration and latching invariance | Step C3 | Interaction | **DONE** | `44.10 Existing Shift-hold duration and latch behavior preferences remain intact` |
| Custom per-file-type profile override persistence | Step C3 | Storage | **DONE** | `44.11 Custom per-file-type profile can be updated and retrieved` |

---

## Phase P Progress & Verification

| Step | Scope | Status | Verification & Gates |
| :--- | :--- | :--- | :--- |
| **Step P0** | Baseline re-verification, audit, PR #9 fallback record, hygiene | **Complete** | All 7 items verified, docs/R1_GATE_AUDIT.md committed |
| **Step E1** | Bundled Relocatable Engines (`Pasta.app/Contents/Resources/Engines`) | **Complete** | 16 engines packaged, @loader_path rewritten, isolated execution verified |
| **Step E2** | Clean-Machine & Isolation Gate (PR #14 & #15) | **Complete** | All 455 Mach-O binaries verified isolated; `scripts/test_isolation.sh` gate |
| **Step E3** | Quality Policy & Compression Suite (PR #16) | **Complete** | All 111 catalog actions mapped to quality classes in `PastaCore/QualityPolicy.swift` |
| **Step E4** | Behavioral Completeness of Action Catalog (PR #17) | **Complete** | All 111 actions have verified end-to-end execution, corrupt/missing input tests |
| **Step E5** | Heavy-job guard (logic only) | **In Progress** | Limits config JSON, estimator math, disk safety check, QoS .utility, pause/resume SIGSTOP/SIGCONT, thermal protection |










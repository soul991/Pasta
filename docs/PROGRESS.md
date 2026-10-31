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

---

## Installation & Artifacts

- **App Bundle**: `/Applications/Pasta.app` (and local `./Pasta.app`)
- **Finder Quick Action**: `~/Library/Services/Convert with Pasta.workflow`
- **Application Logs**: `~/Library/Logs/Pasta/pasta.log`
- **Code Signing**: Ad-hoc signed with stable designated requirement `designated => identifier "com.local.pasta"`

## Running Tests

- Unit & Integration Suite: `swift run PastaTests` (157 tests passed in Debug and Release, including 11 Section 12 Shift-Hold State Machine tests)
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

| Item | What to check | Status | Notes |
| :--- | :--- | :--- | :--- |
| **Fix 1** | `pdf.to.images` and `pdf.advanced.split` lose pages | **DONE** | Verified with 3-page fixture; produces dedicated output folder with all pages, non-destructive collision handling, and fixture integrity. |
| **Fix 2** | 120 s timeout kills long ffmpeg jobs | **DONE** | Implemented per-invocation `timeoutSeconds`, defaulted `ffmpeg` to `nil` (no timeout), quick tools to 300s, and surfaced `PastaError.timedOut`. |
| **Fix 3** | Cancellation does not work reliably | **DONE** | Implemented job process registry, `cancel(jobId:)`, `cancelAll()`, Swift concurrency `withTaskCancellationHandler`, and SIGTERM -> SIGKILL escalation. |
| **Fix 4** | `runProcess` blocks Swift concurrency pool | **DONE** | Non-blocking `process.terminationHandler` with continuation, concurrent pipe streaming via `readabilityHandler`, and 64KB bounded stderr tail. |
| **Fix 5** | Finder selection & AppleScript | **DONE** | Added `NSAppleEventsUsageDescription` to Info.plist in `build_app.sh`, added `FinderSelectionHelper`, and logged/surfaced Automation error (-1743). |
| **Fix 6** | Housekeeping & Compact violations (`try?`) | **DONE** | Replaced swallowed move/read `try?` calls in `JobRunner`, `Compressor`, `MediaTools`, and `MetadataTools` with throwing `try`; documented all remaining safe cleanup/logging `try?` calls. |

---

## Phase 9 Step Breakdown & Verification

| Step | Scope | Commit | Tests | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Step 0** | Re-verify baseline & repair Phase 8 leftovers | `2d59b93` | 51/51 | **Complete** |
| **Step 1** | Parameterized actions foundation, ActionParameter, OutputKind, CLI `--param` | `66ac489` | 67/67 | **Complete** |
| **Step 2** | Missing formats: AVI, WMV, OGG, AIFF, GZIP, Image to PDF, PDF Merge, EPUB, LibreOffice detect | `e0ad753` | 89/89 | **Complete** |
| **Step 3** | Compression modes: Percent & exact size for Image (binary search/palette), Video (bitrate/two-pass), Audio, PDF (Ghostscript) | `cb0cd56` | 99/99 | **Complete** |
| **Step 4** | Video & Audio tools: Speed (0.25x–4x), Crop, Split, Join, Snapshot, EBU R128 Normalize, Channels, Bleep tone, Trim | `5756563` | 117/117 | **Complete** |
| **Step 5** | Metadata Read (exiftool/ffprobe), Non-destructive Edit, PDF Reorganize, Image Collage, Vision Offline QR Decode | `3796891` | 131/131 | **Complete** |
| **Step 6** | Section 8 Gate Verification: hostile filename tests, doctor verification, app signing, zero network, zero leaks | `9510a60` | 131/131 Unit, 30/30 Sec8 | **Complete** |
| **Review** | Adversarial Review & Bug Fixes: runAsync customRunner fix, two-pass video encoding, filter-complex join fallback, audio bleep eval=frame, strict metadata read-back, reverse PDF reorganization, untampered network check | *(Current)* | 139/139 Unit, 33/33 Sec8 | **Complete** |



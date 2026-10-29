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

---

## Installation & Artifacts

- **App Bundle**: `/Applications/Peel.app` (and local `./Peel.app`)
- **Finder Quick Action**: `~/Library/Services/Convert with Peel.workflow`
- **Application Logs**: `~/Library/Logs/Peel/peel.log`
- **Code Signing**: Ad-hoc signed with stable designated requirement `designated => identifier "com.local.peel"`

## Running Tests

- Unit & Integration Suite: `swift run PastaTests` (37 tests passed)
- Section 8 Hardening Suite: `./scripts/run_section8_tests.sh` (13 tests passed)

---

## Phase 9 baseline

- **Date**: October 29, 2026
- **Git Commit**: `947d5e8 docs: add comprehensive README for Pasta`
- **Git Status**: Clean baseline verified.
- **Unit & Integration Suite (Debug)**: `swift run PastaTests` -> 37/37 Passed, 0 Failed.
- **Unit & Integration Suite (Release)**: `swift run -c release PastaTests` -> 37/37 Passed, 0 Failed.
- **Section 8 Hardening Suite**: `./scripts/run_section8_tests.sh` -> 13/13 Passed, 0 Failed.
- **Application Bundle & Code Signing**: `./scripts/build_app.sh` -> `Pasta.app` produced, `codesign --verify --deep --strict Pasta.app` succeeded.
- **Test Count Reconciliation**: README and codebase contain 37 unit/integration tests and 13 Section 8 hardening tests. The `96` in `PHASE8.md` was an anticipated target count rather than the actual test count implemented in Phase 4/7.

### PHASE8 Fixes Status Check (Step 0 - Complete)

| Item | What to check | Status | Notes |
| :--- | :--- | :--- | :--- |
| **Fix 1** | `pdf.to.images` and `pdf.advanced.split` lose pages | **DONE** | Added unit tests verifying 3-page and single-page outputs, non-destructive collision handling, and fixture integrity. |
| **Fix 2** | 120 s timeout kills long ffmpeg jobs | **DONE** | Implemented per-invocation `timeoutSeconds`, defaulted `ffmpeg` to `nil` (no timeout), quick tools to 300s, and surfaced `PastaError.timedOut`. |
| **Fix 3** | Cancellation does not work reliably | **DONE** | Implemented job process registry, `cancel(jobId:)`, `cancelAll()`, Swift concurrency `withTaskCancellationHandler`, and SIGTERM -> SIGKILL escalation. |
| **Fix 4** | `runProcess` blocks Swift concurrency pool | **DONE** | Non-blocking `process.terminationHandler` with continuation, concurrent pipe streaming via `readabilityHandler`, and 64KB bounded stderr tail. |
| **Fix 5** | Finder selection & AppleScript | **DONE** | Added `NSAppleEventsUsageDescription` to Info.plist in `build_app.sh`, added `FinderSelectionHelper`, and logged/surfaced Automation error (-1743). |
| **Fix 6** | Housekeeping & Compact violations | **DONE** | Replaced swallowed move/read `try?` calls in `JobRunner` and `InputValidator` with explicit error throws; documented justified cleanup/logging `try?` calls. |


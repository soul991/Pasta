# Pasta Phase 9: Close the Feature Gaps (Formats, Tools, Metadata)

*Instructions for the AI coding agent. Same rules as the original build brief. Prepared October 29, 2026.*

## 1. How to use this document

- Save this file as `docs/PHASE9.md`. Read it fully before doing anything.
- Work through the steps in order, one at a time. After each step, stop and give a short report (format in section 8). Do not batch steps.
- Every step uses the same loop: write failing tests first, implement, confirm they pass, confirm all older tests still pass, commit (one commit per step).
- Never claim a test passed unless you ran it and can show the output.
- All Pasta compacts stay in force: zero network calls, source files immutable, atomic temp-then-move writes, no shell string concatenation, hostile filename safety, no silent failures, no third-party Swift dependencies.
- Scope: this phase is **engine, CLI and action registry only**. Do not touch the radial wheel, theme, or other UI beyond what a step explicitly requires. New triggers (shake dock, command bar, actions wheel, floating shelf) and interactive editors (annotate, redact, visual crop) belong to later phases.
- Do not copy any Tangerine names, icons or assets. Pasta keeps its own identity.

## 2. Step 0: re-verify the previous phase and repair leftovers (before any new code)

The repo already contains `docs/PHASE8.md`, an earlier fix round. Judging from the code, it was only partly carried out. Verify each point yourself; do not trust this list blindly.

### 2.1 Baseline

1. `git status` and `git log --oneline -10`. The tree must be clean. If not, report what is uncommitted and stop.
2. Debug and release builds both succeed. Run `swift run PastaTests` and record the exact passing and failing counts. Run `./scripts/run_section8_tests.sh` and record the result. (README currently claims 37 and 13; `PHASE8.md` expected 96. Report the real numbers and the reason for any difference.)
3. Run `./scripts/build_app.sh`. Confirm `Pasta.app` is produced and `codesign --verify --deep --strict Pasta.app` succeeds.
4. Write the numbers to `docs/PROGRESS.md` under the heading "Phase 9 baseline".

### 2.2 Status check of the PHASE8 fixes

For each item, reproduce the problem or inspect the code, then record DONE or OPEN in `docs/PROGRESS.md`.

| Item | What to check | Suspected state |
| :--- | :--- | :--- |
| Fix 1: `pdf.to.images` and `pdf.advanced.split` lose pages | Use a 3-page fixture; each action must produce a folder with exactly 3 files | Probably done (folder output exists), but verify with a real 3-page PDF and add the tests if missing |
| Fix 2: 120 s timeout kills long ffmpeg jobs | `JobRunner` default `timeoutSeconds` | Probably OPEN. Default is still 120 |
| Fix 3: cancellation | One shared current-process slot; no task cancellation handler | Probably OPEN |
| Fix 4: `runProcess` blocks the Swift concurrency pool | `waitUntilExit` and `group.wait` inside async code; `@unchecked Sendable` | Probably OPEN |
| Fix 5: Finder selection | Selection goes through `osascript` in `PastaCLI`; check `NSAppleEventsUsageDescription` in the Info.plist from `build_app.sh`, all selected items returned, errors logged and surfaced | Verify |
| Fix 6: housekeeping | `PROGRESS.md` accuracy, `.gitignore` covers `.build/`, `.DS_Store`, `test_outputs_phase2/`, built `Pasta.app`; remove tracked junk; dead code | Verify. Note `.build/`, `test_outputs_phase2/` and `Pasta.app` appear in the shared zip |

### 2.3 Compact violations to repair

The README promises "no `try?`, no force unwraps" but `try?` appears in `JobRunner` (for example moving page files, `contentsOfDirectory`), `InputValidator`, `PastaLogger` and `PastaCLI`. For each one: either replace it with real error handling, or keep it with a one-line comment explaining why swallowing is safe (cleanup and logging only). A swallowed error that hides a failed move or a failed read is a bug, not an acceptable use.

### 2.4 Fix before continuing

Every OPEN item above gets fixed first, following the loop in `PHASE8.md` (failing test, fix, green, commit), one commit per fix. Use a fake tool script injected through `ToolLocator` for timeout, cancellation and concurrency tests, so they never depend on real ffmpeg. Do not start Step 1 until Step 0 is green and reported.

## 3. Step 1: make actions parameterized (the foundation)

**Problem.** `ConversionAction.buildInvocations` is `(URL, URL) -> [Invocation]`, so actions cannot take input. That is why `video.advanced.trim10` and `image.advanced.resize_50` are hardcoded. Every tool in this phase needs a parameter (target size, speed, crop box, time range, channel layout).

**Required behavior.**
- Add an `ActionParameter` description (id, label, kind: percent, number, size in bytes, time range, rectangle, choice, text; default; min and max) and a `ParameterValues` dictionary.
- `ConversionAction` gets `parameters: [ActionParameter]` (empty by default) and `buildInvocations` receives the values. Existing actions keep working unchanged with defaults.
- `InputValidator` validates every parameter against its declared range before any process starts, with readable errors.
- Add an output kind (file or folder) to the action instead of comparing action ids inside `JobRunner`. Move the existing `isExtract`, `isPdfToImages`, `isPdfSplit` special cases onto it.
- The CLI accepts parameters, for example `pasta convert --action video.speed --param factor=2 clip.mp4`, and `pasta list-actions` prints each action's parameters with defaults.
- Convert `trim10` into a real trim action (start and end) and `resize_50` into a resize action (percent or width and height). Keep the old ids as aliases so nothing breaks.

**Tests.** Defaults reproduce the old behavior exactly (same invocations as before). Out-of-range values are rejected before any process runs. Unknown parameter names are rejected. Parameters containing hostile strings never reach a shell.

## 4. Step 2: formats still missing

Verify every command recipe by hand on a real fixture first and add it to `docs/commands.md`, using `file`, `ffprobe`, `identify`, `qpdf --check` or `exiftool` to prove the output. Never guess a flag.

- **Video outputs:** AVI and WMV (add both as targets and accept both as inputs).
- **Audio outputs:** OGG (Vorbis) and AIFF.
- **Archives:** GZIP of a single file, and `.gz` as an extract input.
- **Images to PDF:** one image to one PDF; multiple selected images to a single PDF, in the order selected (a batch action that takes a list of inputs).
- **PDF merge:** `InputValidator.validatePDFMerge` exists, but no merge action is registered. Add `pdf.merge` as a batch action (min 2 inputs) built on `qpdf`, output named after the first input, and expose it in the CLI.
- **Documents:** EPUB to and from DOCX, MD and HTML through `pandoc`. For Word, PowerPoint and spreadsheet conversion, check whether LibreOffice (`soffice --headless --convert-to`) is installed. Make it an **optional** tool: `pasta doctor` reports it as optional, and the actions appear only when it is present. Do not claim Pages support; if there is no verified offline route, say so in the report.

**Tests.** For each new format: output exists, passes the verification command, hostile filename variant works, and the original is unchanged.

## 5. Step 3: compression modes

Implement compress by **percentage** and by **exact target size**, for single files and batches, for image, video, audio and PDF.

- Percent means "make the output about N percent of the original size".
- Target size means "no larger than N bytes". Strategy: video and audio compute the bitrate from `ffprobe` duration and run two-pass where it helps; images search quality with a bounded binary search (maximum 8 iterations); PDF tries Ghostscript presets from mild to aggressive.
- If the target cannot be reached, do not fail silently and do not overwrite anything: finish with the smallest result produced and report plainly ("could not reach X; produced Y").
- Never exceed the iteration cap, and clean up every intermediate file.

**Tests.** Use fixtures large enough to be compressible. Assert the final size is at or under the target (with a small stated tolerance for video) and that an impossible target gives the "smallest achieved" message and still leaves a valid file.

## 6. Step 4: video and audio tools

- **Video:** speed change (0.25x to 4x, with matching audio tempo using chained `atempo`), crop (rectangle, validated against the real dimensions from `ffprobe`), split (at given times, into a folder), join (several videos with the same codec parameters via the concat demuxer; re-encode if they differ), snapshot (single frame at a time to PNG or JPG).
- **Audio:** normalize (two-pass `loudnorm`), change channels (mono, stereo), bleep (replace listed time ranges with a tone), trim (reuse the parameterized trim).

**Tests.** Verify output duration, dimensions and channel count with `ffprobe`. Speed 2x halves the duration within tolerance. Join of two clips has the summed duration. Out-of-range time ranges are rejected by `InputValidator`.

## 7. Step 5: metadata read and edit, PDF reorganize, QR

- **Metadata read:** a headless action that returns a readable key-value report (use `exiftool` for images and PDF, `ffprobe` for audio and video). Expose it in the CLI as JSON and as text. Never write to the source.
- **Metadata edit:** write chosen tags to a **copy** (for example title, author, comment, date). Validate tag names against an allow-list. Verify with a second read-back.
- **PDF reorganize:** page ranges to extract, delete pages, reorder, rotate pages, all through `qpdf` with validated ranges (reject page numbers beyond the real page count).
- **Collage:** combine several images into a grid with `magick montage`, with parameters for columns and spacing.
- **QR read:** use the Vision framework (`VNDetectBarcodesRequest`). It must work offline and return the decoded text; no network calls, and never open a decoded URL.

**Tests.** Metadata edit then read-back matches; removing metadata still leaves no GPS tags. PDF reorder of a 3-page fixture produces the expected order (check text on each page). QR fixture decodes to the known string.

## 8. Gate for the whole phase and report format

All of the following must be true, with real output shown:

1. Step 0 baseline numbers recorded, and every earlier OPEN item fixed in its own commit.
2. Test count is the Step 0 baseline plus the new tests, all passing, in debug and release.
3. `./scripts/run_section8_tests.sh` still passes, extended with hostile-filename cases for every new action.
4. `pasta doctor` lists every required and optional tool with its path, and reports missing optional tools without failing.
5. `build_app.sh` produces a signed `Pasta.app`; `codesign --verify --deep --strict` succeeds.
6. Static check still shows zero network APIs in the binary and the sources.
7. No orphan processes and no leftover `/tmp/Pasta_*` directories after any run, including cancelled ones.
8. `docs/commands.md`, `docs/PROGRESS.md` and the README format table are updated to match reality. Do not claim a format the tests do not cover.
9. One commit per step, a clean `git status`, and `.build/`, `.DS_Store`, `test_outputs_phase2/` and the built `Pasta.app` are not tracked.

**Report after every step:**
- What changed (files, one line each).
- Failing tests written first, and their output.
- Passing output after the fix (counts, not summaries).
- Anything you could not verify, and why.
- The commit hash.

## 9. Not in this phase

Shake-to-open dock, command bar, Shortcuts and App Intents, the Control-key actions wheel (AirDrop, Copy, Move, Copy Path, Terminal), the floating file shelf, interactive crop, annotate and redact editors, OCR, transcription and upscaling. Those are Phases 10 to 12 and will be briefed separately after this gate is reviewed.

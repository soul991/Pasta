# Peel Phase 8: Fix Round (Review Findings)

*Instructions for the AI coding agent. Follows the same rules as Section 5 of the original build brief. Prepared October 19, 2026.*

## 1. How to use this document

- Put this file in the project as `docs/PHASE8.md` and tell the AI to read it fully before doing anything.
- The AI must work through the fixes in order, one at a time, and stop after each fix for a short report. Do not let it batch them.
- Every fix follows the same loop: reproduce the bug with a failing test, fix it, confirm the test passes, confirm older tests still pass, commit.
- Stay in scope. Do not touch the radial wheel, theme, or other UI unless a fix below requires it.
- The AI must never claim a test passed unless it ran it and can show the output.

## 2. Step 0: re-verify the current state (before changing anything)

1. Run `git status` and `git log --oneline -5`. The tree must be clean. If not, report what is uncommitted and stop.
2. Find out how tests are run (check `scripts/` and `docs/PROGRESS.md`; the test target is an executable named PeelTests). Build in debug and release, run the full suite, and record the exact passing count. Expected baseline: 96 passing, 0 failing. If it differs, report the difference before continuing.
3. Run `scripts/run_section_8_tests.py` and record the result.
4. Run `scripts/build_app.sh` and confirm Peel.app is produced and `codesign --verify --deep --strict Peel.app` succeeds.
5. Write the baseline numbers to `docs/PROGRESS.md` under a new heading Phase 8 baseline.
6. If anything from earlier phases is broken, fix it first, in its own commit, before starting Fix 1.

## 3. The fixes

### Fix 1: PDF to images and PDF split lose all but the first output (most serious)

**Problem.** In `JobRunner.execute`, the cases for `pdf.to.images` and `pdf.split` commit only the first generated file (`generated.first`, `splitFiles.first`) and then the temp directory is deleted. A multi-page PDF yields one page and silently discards the rest. The fixture PDF is probably one page, which is why tests pass.

**Required behavior.** Both actions produce a new folder next to the original (for example `name pages` and `name split`) containing every output file, with sensible names (`name-1.png`, `name-2.png`, and so on, numbered so they sort correctly). A single-page PDF also produces a folder with one file, so behavior is consistent. Collision handling must add a numeric suffix to the folder name, never overwrite.

**Notes.**

- Inspect `ConversionAction.swift`, `OutputPlanner.swift` and how extraction actions (`outputExtension == extracted`) already commit a folder, and reuse that pattern. Prefer a clean field such as an output kind (file or folder) over special-casing action ids inside `JobRunner`.
- Update the UI result row so it reveals the folder in Finder, as extraction already does.
- Do not add dependencies.

**Tests (write first, confirm they fail).**

- Create a 3-page fixture, for example `qpdf --empty --pages Fixtures/sample.pdf Fixtures/sample.pdf Fixtures/sample.pdf -- Fixtures/three_pages.pdf`.
- pdf.to.images: output folder contains exactly 3 PNG files that are valid images.
- pdf.split: output folder contains exactly 3 single-page PDFs (check with `qpdf --check` or pdfinfo).
- One-page input gives a folder with 1 file.
- Original file checksum unchanged. Re-running does not overwrite the first result.

### Fix 2: the fixed 120-second timeout kills long conversions

**Problem.** `defaultTimeout` is 120 seconds for every tool. A large video conversion will be terminated and reported as a failure.

**Required behavior.** Media conversions (ffmpeg) have no automatic timeout; the user can cancel them. Quick tools keep a safety timeout, generous but finite (suggest 300 seconds). The timeout should be a property of the invocation or tool, with the default set in one place.

**Tests.** Use a fake tool script that sleeps a few seconds, injected through `ToolLocator` (or the existing injection point). With a 1-second timeout it fails with `timedOut`. With no timeout it succeeds. The timeout test must not depend on real ffmpeg.

### Fix 3: cancellation does not work reliably

**Problem.**

- `JobRunner` keeps one `currentProcess` slot. When several files are processed at once, each new process overwrites the slot, so `cancel()` only terminates the last one and earlier processes keep running.
- Cancelling a Swift `Task` does not stop a running child process. `Task.checkCancellation()` is only called between steps.

**Required behavior.**

- Track every running process (a lock-protected set or a small actor), each tied to its own job.
- Wrap the process run in `withTaskCancellationHandler` so cancelling the task terminates that job's process: SIGTERM first, SIGKILL after about 2 seconds if it is still alive.
- `cancel()` keeps working and cancels all tracked jobs.
- A cancelled job cleans up its temp directory and reports cancellation, not a generic failure.

**Tests.**

- Start two slow fake-tool jobs, cancel one, confirm only that process dies and the other finishes.
- Cancel via `Task.cancel()` and confirm the child process is gone (`pgrep` for the fake tool returns nothing) and the temp directory is removed.
- Cancel before the process starts, and cancel after it has finished, without crashing.

### Fix 4: `runProcess` blocks Swift concurrency threads

**Problem.** Inside an async function, `process.waitUntilExit()` and `group.wait()` block a thread that Swift's cooperative pool needs. With several jobs at once, the app can stall. Also, `stdoutData`, `stderrData` and `didTimeout` are mutated from other queues, and `@unchecked Sendable` hides the resulting data race.

**Required behavior.**

- Rewrite `runProcess` to be non-blocking: use `Process.terminationHandler` with a checked continuation, and read the pipes with `readabilityHandler` or on a dedicated dispatch queue, never on the cooperative pool.
- Keep reading stdout and stderr concurrently so pipes never fill and deadlock.
- Keep only a bounded tail of stderr (for example the last 64 KB) for error messages, so a chatty tool cannot grow memory without limit.
- Protect shared state with a lock or actor and remove `@unchecked Sendable` if it can be done cleanly. If it cannot, say why in the report.

**Tests.** All existing JobRunner tests still pass. Add one that runs 8 fake-tool jobs concurrently and confirms they all complete. Add one with a tool that writes more than 1 MB to stderr and confirm no hang and a bounded error string.

### Fix 5: Finder selection through AppleScript may fail silently

**Problem.** `FinderSelectionHelper` uses `NSAppleScript` to ask Finder for the selection. That needs the Automation permission, and macOS expects `NSAppleEventsUsageDescription` in Info.plist to show the prompt. The key is missing from `scripts/build_app.sh` and the built Info.plist. The script also returns only the first selected item, and the error info is ignored.

**Required behavior.**

- Add `NSAppleEventsUsageDescription` (a short plain-language reason) to the Info.plist written by `build_app.sh`.
- Return all selected items, not just the first.
- Check the error dictionary from `executeAndReturnError`. Log it with `PeelLogger`. If it is a not-authorized error (typically -1743), show the user a clear message explaining where to enable Peel (System Settings, Privacy and Security, Automation) instead of doing nothing.
- Keep the stable bundle identifier and signing so the permission survives rebuilds.

**Tests.** This is mostly manual because it needs a real Finder and a permission prompt. Add a unit test for the parsing of multiple paths if the code can be separated from AppleScript. Provide a manual checklist: fresh permission prompt appears, granting works, denying shows the helpful message, multiple files selected are all processed.

### Fix 6: housekeeping

- Update `docs/PROGRESS.md`: Phase 7 should say complete with the real commit hash (it says `commit ready`), and list the later commits (Section 8 runner, permission fix, radial wheel, Finder selection fix).
- Check `.gitignore` covers `.build/`, `.DS_Store`, `test_outputs/` and generated `Peel.app`. Remove any such files already tracked, in a separate commit.
- Remove dead code left by the earlier fixes (for example the redundant `_ = stdoutData`).
- Do not add new `try?` or force unwraps. The remaining `try?` uses in logging and cleanup are acceptable if each is justified by a comment.

## 4. Gate for the whole phase

All of the following must be true, with real output shown:

1. Test count is the Step 0 baseline plus the new tests, all passing, in both debug and release builds.
2. `scripts/run_section_8_tests.py` passes.
3. `build_app.sh` produces a signed Peel.app and `codesign --verify --deep --strict` succeeds.
4. Manual checks pass on the installed app: converting a 3-page PDF to images and splitting it each give a folder with 3 files; a long video conversion is not killed at 2 minutes; cancelling one of two simultaneous jobs leaves the other running; Finder selection works with a fresh Automation permission.
5. No orphan processes after any cancel (`pgrep ffmpeg` and the fake tool return nothing), and no leftover temp directories.
6. One commit per fix, each with a clear message, and a clean `git status` at the end.

## 5. Report format (after every fix and at the end)

- Which fix, restated in one line.
- Step 0 style re-check: what you re-ran from earlier work and anything that had regressed.
- What changed, and the files touched.
- The failing test before the fix and the passing output after it (real output, trimmed).
- Gate items passed or failed.
- Known issues or things you chose not to change, and why.
- Questions for me.

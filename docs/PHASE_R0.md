# Pasta Phase R0: Reliability, Repo Hygiene, First Release

*Instructions for the AI coding agent. Date: November 5, 2026. Read all of it before touching code. Save as `docs/PHASE_R0.md`.*

*Origin: a comparison of Pasta with Filee by five independent reviewers. Only findings that survived a check against the real source are included. This phase runs BEFORE Phase 11 Block A resumes.*

## 0. Rules (unchanged and strict)

- Zero network calls in the app. Zero third-party Swift packages. No private API. No shell strings (executable plus argument array only). No silent failures.
- Never write "verified" without a log line you ran yourself. Label anything you could not run "written, NOT compiled or run".
- Work on a branch `codex/r0` from the latest `main` (or `codex/work` if the owner has not merged it yet; ask which). Do not touch `wip/phase11-local-before-codex`.
- One commit per step. Tests first (write them, show them fail, then fix). Full suites before every push. Never loosen or delete a test to make it pass.
- Every new behavior needs a hostile-filename case, a zero-leftover `/tmp/Pasta_*` check, an orphan-process check, and a source-unchanged check.
- Stop and report after each step. Wait for the owner before the next one.

## Step 0: Re-verify the previous phase and repair leftovers (before any new code)

1. `git fetch --all`, `git status`, `git stash list`, `git log origin/main..HEAD`, `git log HEAD..origin/main`. Report unpushed or uncommitted work. Do not discard anything.
2. Run and paste exact counts: `swift build`, `swift build -c release`, `swift run PastaTests`, `swift run -c release PastaTests`, `PASTA_BIN=.build/debug/Pasta ./scripts/run_section8_tests.sh`, `./scripts/build_app.sh`, `PASTA_BIN=./Pasta.app/Contents/MacOS/Pasta ./scripts/run_section8_tests.sh`, `codesign --verify --deep --strict Pasta.app`. Paste the latest GitHub Actions counts for `main` and the working branch, and `sw_vers` plus `xcodebuild -version`.
3. Check each earlier open item and report DONE or OPEN with the commit hash and the proving test name:
   - Part 2 of `docs/CODEX_HANDOFF.md`: items 1 to 7 (app icon from Figma, Liquid Glass tiers, README counts, sticky-wheel behavior tests, stale-drag fix, Settings showing doctor output plus hold slider, Phase 9 re-audit).
   - `PastaCLI.showNotification` uses `UserNotifications` and no interpolated AppleScript (the audit flagged it; confirm it is fixed).
   - Wheel does not auto-close after conversions unless `autoDismissWheelAfterRunning` is on, and never closes on errors.
   - The Section 33.7 timer test lost its direct negative proof ("does not fire before the deadline") in commit `11938fa`. Restore a pre-deadline assertion using an injectable clock or a short deadline with a margin, so it is not flaky.
4. Honesty check on `docs/PROGRESS.md`: list DONE rows whose proving test only checks registration or view structure ("is registered", "view loaded", "has label"). Mark them "structure only" in the table. Do not delete rows.
5. Fix every OPEN item or fault found, each in its own commit, before Step 1. Report before continuing.

## Step 1: Atomic output reservation (the real bug)

### 1.1 The problem (confirm by reading the code first)

`OutputPlanner.planOutput` and `planOutputDirectory` only check `fileExists` and return a name. `JobRunner.run`, `runBatch` and `runAsync` later do:

```swift
if fm.fileExists(atPath: finalDestinationURL.path) { try fm.removeItem(at: finalDestinationURL) }
try fm.moveItem(at: tempWorkingOutputURL, to: finalDestinationURL)
```

`BatchJobQueue` runs up to `maxConcurrentJobs` (default 2) jobs at once, and the CLI and the app can run at the same time. Two jobs with the same basename into one destination (for example `a/photo.png` and `b/photo.png` with a custom output folder, or two parallel conversions of the same file) can both plan `photo.jpg`; the second then deletes the first one's output. This breaks "never overwrite".

**First, prove it.** Write a failing test that launches 20 concurrent jobs with same-basename inputs into one destination and shows lost outputs. Paste the failing output in the report.

### 1.2 Required design

- Add `OutputReservation` (PastaCore, no UI). `OutputPlanner.reserveOutput(for:targetExtension:destinationDirectory:)` and `reserveOutputDirectory(...)` return a reservation holding the final URL.
- Claim the name atomically:
  - File outputs: `open(path, O_CREAT | O_EXCL | O_WRONLY, 0o600)` creating an empty placeholder. On `EEXIST`, try the next numbered suffix.
  - Folder outputs: `mkdir(path, 0o700)`, treating `EEXIST` as taken.
  - Also keep an in-process lock-protected set of reserved paths (cheap guard; the `O_EXCL` claim is what protects against another process, such as the CLI).
  - The input path must never be reserved (keep the existing "never plan the input path" rule).
- Publish with `rename(2)` of the validated temp output over the placeholder we created (rename replaces atomically; for folders, `rename` over an empty directory is allowed on macOS). Do not `removeItem` any path that is not our own placeholder.
- Release rules: on success the placeholder is replaced by the real output. On failure, cancellation or thrown error, delete the placeholder **only if** it is still ours (compare device and inode saved at creation) and still empty. Never delete anything else. Implement with `defer`.
- Replace all three call sites (`run`, `runBatch`, `runAsync`) and the batch "compressed" folder path. The old `planOutput` functions may stay for tests and previews, but production code must not use them to decide a final path.
- Edge: a crash can leave a zero-byte placeholder. On launch and in `pasta doctor`, report (do not delete) zero-byte files that are older than 1 hour and match no running job? **Do not auto-delete user-visible files.** Document the limitation instead, and keep it in the report.
- Verify by hand on macOS 27 that `rename` over an empty directory behaves as designed, and record it in `docs/commands.md` (or a new `docs/FILESYSTEM_NOTES.md`).

### 1.3 Tests (write first)

1. 20 concurrent `run` calls, same basename and same destination: 20 unique output paths, every output valid, no pre-existing file changed.
2. Two real `Pasta convert` CLI processes started at the same moment on same-name inputs: unique outputs.
3. Failure injected after reservation (fake tool exits 1): placeholder gone, no other file touched.
4. Cancellation (before start, mid-run, after finish): placeholder gone, zero leftover `/tmp/Pasta_*`, zero orphan processes.
5. A pre-existing `photo.jpg` is never modified, even by a failing job with the same name.
6. Folder outputs (`pdf.to.images`, `archive.extract`, `video.split`) under the same race.
7. Hostile names (leading dash, quotes, emoji, very long) reserve and publish correctly.
8. Add two Section 8 checks: concurrent same-name CLI conversions; failed conversion leaves no placeholder.

### Step 1 gate
Failing test shown first, then green in debug and release, Section 8 green for both binaries, the PROGRESS row names its proving tests. **Stop and report.**

## Step 2: Hostile archive extraction suite

Archives are untrusted input. Extractors in use: `ditto`, `tar`, `7zz`, `unar`. Do not assume they are safe; prove it per tool and version.

### 2.1 Fixtures
Create `scripts/make_hostile_archives.sh` that builds fixtures at test time into a temp folder (do not commit binary bombs). Use only tools present on the Mac (`zip`, `tar`, `7zz`, `gzip`, `ln`). Cases: `../escape.txt`; absolute path `/tmp/pasta_abs_escape.txt`; entry through a symlink pointing outside; symlink entry to `/etc/passwd`; hard link entry; duplicate names and case-only duplicates (`A.txt` vs `a.txt`); Unicode normalization duplicates (NFC vs NFD); very deep nesting (200 levels); very long entry names; 50,000 tiny entries; a small gzip that expands to a large size (use a reduced limit in the test, never write gigabytes in CI); setuid/setgid bits; device-node entries where the tool allows them.

### 2.2 Behavior to implement
- Extract only into the scratch directory (already the case), never directly into the destination.
- Before extraction, list entries where the tool supports it (`tar -tf`, `7zz l -slt`) and reject escaping names early with a readable error.
- After extraction, run `ArchiveGuard.validate(root:)`: every item's resolved path (`resolvingSymlinksInPath`) stays inside the root; no symlink or hard link targets outside the root; entry count, depth, path length, per-file size and total expanded size are under limits (named constants, documented; propose defaults to the owner, for example 100,000 entries, depth 64, 8 GB total); setuid and setgid bits cleared or the job rejected.
- On any violation: reject the whole job with a readable `PastaError.invalidInput`, publish nothing, leave the destination unchanged, clean the scratch directory.
- Record the real behavior of each tool and version on each fixture in `docs/commands.md` before coding the guard (some tools already refuse these; say which).

### 2.3 Tests
Each fixture: job fails or is safely sanitized as documented, nothing is written outside the scratch root, the destination folder is unchanged, no leftover temp directory, no orphan process. A benign archive with normal nested folders still extracts correctly (guard against false positives). Add Section 8 hostile-archive checks for the CLI.

### Step 2 gate
All fixture cases covered with real log lines; any case where a tool wrote outside the root before the guard is reported as a finding. **Stop and report.**

## Step 3: Repo hygiene, actionable doctor, first release

### 3.1 Files
- `LICENSE`: standard MIT text, copyright "2026 Istak Ahamed" (confirm the name with the owner).
- `SECURITY.md` (how to report a vulnerability, supported versions, the offline and no-telemetry statement), `CHANGELOG.md` (start at `0.1.0-beta`), `CONTRIBUTING.md` (build, test, rules from this file), `.github/ISSUE_TEMPLATE/` for bug and feature, `THIRD-PARTY-NOTICES.md` listing each external engine and its license (verify each license from the installed formula; do not guess). State clearly that tools are user-installed and not bundled.
- Add GitHub repo topics in the report as a suggestion for the owner (you cannot set them).

### 3.2 README stops drifting
- `scripts/test_counts.sh` already prints counts. Add `scripts/gen_readme_tables.sh` (or a Swift subcommand `pasta list-actions --all --markdown`) that regenerates the format/action table from the registry. The README test line must say "see CI" with a badge, or be generated; no hand-typed numbers.
- Remove claims the tests do not cover. Add a "Current limitations" list and a short "Why Pasta" section. Screenshots and a GIF of the wheel are requested from the owner in MANUAL_CHECKS (do not fabricate).

### 3.3 Actionable `pasta doctor` and Settings
- Map each tool to its Homebrew formula: ffmpeg→ffmpeg, magick→imagemagick, cwebp→webp, gs→ghostscript, qpdf→qpdf, pdftoppm and pdftotext→poppler, exiftool→exiftool, pandoc→pandoc, rsvg-convert→librsvg, unar→unar, 7zz→sevenzip, soffice→`--cask libreoffice`, ebook-convert→`--cask calibre`, avifenc→libavif (verify each name with `brew info`).
- `pasta doctor` prints path, version (`--version`, run safely with a timeout), which actions depend on the tool, and ONE copy-paste `brew install ...` line for everything missing, split into required and optional. Support `--json`.
- Settings window shows the same report with a "Copy install command" button. Detect both `/opt/homebrew` and `/usr/local` prefixes, and test with a restricted PATH (the app launched from Finder).
- Tests: fake tool overrides for missing and present states; command generation; JSON shape; no network.

### 3.4 First release (ad-hoc signed, honest)
- Add `.github/workflows/release.yml` triggered by a tag `v*`: build with `build_app.sh`, verify with `codesign --verify --deep --strict`, zip with `ditto -c -k --keepParent`, write a SHA-256 file, and attach both to a GitHub Release. Print `sw_vers` and `xcodebuild -version`. The workflow may use the network; the app must not.
- The release notes and README must say: ad-hoc signed, NOT notarized, "Open Anyway" steps, Accessibility permission, and the Homebrew prerequisites. Do not use the word "notarized" until it is true.
- Do not tag anything yourself. Prepare the workflow and a dry run (`workflow_dispatch`) and let the owner create the tag.

### Step 3 gate
CI green; `pasta doctor --json` tested; README tables generated; release workflow dry run succeeds with the artifact attached to the run; MANUAL_CHECKS updated. **Stop and report.**

## 4. Manual checks to add to `docs/MANUAL_CHECKS.md`

- Convert the same file twice quickly and drop two same-named files from different folders onto the wheel: both outputs exist, nothing replaced.
- Open a hostile archive from the fixtures folder in Finder and via the wheel: a clear error, nothing extracted outside.
- Fresh Mac or restricted PATH: Settings shows missing tools with the install command; copying and running it fixes them.
- Download the release zip on a clean account, "Open Anyway", grant Accessibility, run the Shift-hold test. Screenshots of the wheel for the README.

## 5. Non-goals for this phase

No route planner, no bundled or downloaded engines, no browser-URL ingestion, no watch folders, no new formats, no UI redesign. Phase 11 Block A resumes only after this phase is reported and approved.

## 6. Report format (every step)

1. What changed, one line per file, with the commit hash.
2. The failing tests written first, then the real log lines after the fix (counts and new test names).
3. What you could not verify, and why.
4. What the owner must check manually.
5. Updated `docs/PROGRESS.md`, `docs/commands.md` and README, so the docs match reality.

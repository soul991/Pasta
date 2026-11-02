# Pasta: Codex Handoff (audit first, then finish the remaining work)

*Date: November 2, 2026. Owner: Istak Ahamed. Repo: github.com/soul991/Pasta (macOS Swift/AppKit, 100% offline). Previous agent: Antigravity. You are on the owner's Mac, so you can build and run things locally. Read this whole file before touching anything.*

## 0. Rules (strict)

- **Do not trust any earlier report, including the repo's `docs/PROGRESS.md`.** Verify claims yourself by running things. Only write "verified" for something you ran and can show output for.
- Zero network calls in the app. Zero third-party Swift dependencies. No private or undocumented API. No shell string concatenation (executable plus argument array only). No silent failures.
- **Two agents may have touched this repo.** Before anything: `git fetch --all`, read `git status`, `git stash list`, `git log origin/main..HEAD` and `git log HEAD..origin/main`. Antigravity may have local commits or uncommitted edits that were never pushed. Do not discard, reset or force-push anything. If the local tree has uncommitted work, commit it to a branch named `antigravity-local-wip` first (do not push to main) and tell the owner.
- Work on a branch `codex/work` (not main). Push the branch; the owner decides when to merge. Do not run at the same time as Antigravity on the same branch.
- One commit per logical step. Run the full suites before every push. Keep CI green.
- Never loosen or delete a test to make it pass. If a test is wrong, explain why before changing it.
- Report with exact command output (counts, log lines, hashes), not summaries.

## 0.1 Known state at handoff (reported by the owner on Nov 2, 2026)

The owner's Mac (`/Users/istakahamed06/Desktop/Pasta`, branch `main`, up to date with `origin/main` at `d774c8f`) had **uncommitted work that was never pushed**:
- Modified: `.github/workflows/macos-ci.yml`, `PastaCore/ConversionAction.swift`, `FormatRegistry.swift`, `JobRunner.swift`, `PDFTools.swift`, `PastaCLI.swift`, `PastaLogger.swift`, `ToolLocator.swift`, `Views/RadialWheelMoreView.swift`, `WheelLayoutModel.swift`, `PastaTests/main.swift`.
- Untracked: `PastaCore/OfficeTools.swift`, `PDFSecurityTools.swift`, `VisionOCRTools.swift`, `Fixtures/sample.csv`, `Fixtures/sample.xlsx`, `test_stamp.swift` (a scratch file at the repo root).
This looks like **Phase 11 Block A started** (Office, PDF security, Vision OCR) by an earlier agent session, unreviewed and untested. The owner will save it on a branch named `wip/phase11-local-before-codex` (pushed, never merged to `main`) before you start. Treat that work as **unverified**: review it line by line in the audit, then keep, fix or rewrite it. Delete `test_stamp.swift` if it is only scratch. If the branch does not exist yet, stop and ask the owner to create it.

## 1. Part 1: Audit (read-only plus reporting; push nothing but the audit report until finished)

Create `docs/AUDIT_2026-11-02.md` containing the real results of the following.

### 1.1 Repo state
- Local vs remote: unpushed commits, uncommitted files, stashes, branches. Say plainly if Antigravity had unpushed or uncommitted work and what it is.
- Tracked junk (`.build/`, `.DS_Store`, built `Pasta.app`, `test_outputs_*`): list.

### 1.2 Build and tests (run locally and compare with GitHub Actions)
- `swift build`, `swift build -c release`, `swift run PastaTests`, `swift run -c release PastaTests`, `./scripts/run_section8_tests.sh` (debug binary), then `./scripts/build_app.sh` and `./scripts/run_section8_tests.sh` against `Pasta.app`, plus `codesign --verify --deep --strict Pasta.app`.
- Record exact pass/fail counts. Check for compiler warnings. Check the latest GitHub Actions run for `main` and paste the counts.
- Check the macOS version (`sw_vers`) and the SDK (`xcodebuild -version`); the answer decides the Liquid Glass work in section 3.

### 1.3 Honesty check of earlier claims
- For every DONE row in `docs/PROGRESS.md`, confirm the named test exists and passes; list rows whose test is missing or only checks structure.
- Look for tests that were loosened or edited to pass (history of Sections 12, 21, 33.7, 35 and 36); list each edit and judge it.
- Run the compact checks: any `URLSession`, sockets, analytics; every `try?` (list each with a verdict: safe cleanup or real swallowed error); force unwraps; any `/bin/sh -c` or string-built commands; leftover `/tmp/Pasta_*`; orphan processes after cancel.
- Check that source files are never modified by any action (spot-check with checksums on a sample of actions).

### 1.4 Behavior check on the real machine (what can be done without a human)
- Launch the built app, confirm it runs as a menu bar agent, read `~/Library/Logs/Pasta/`, and confirm the DragMonitor logs show no arming without a real drag.
- List what only the owner can confirm (real Finder drag, 450 ms hold, typing test, visuals) and put them in `docs/MANUAL_CHECKS.md`.

Stop after writing the audit and show the owner the summary. Continue to Part 2 only after the audit is committed to the branch.

## 2. Part 2: Known gaps found by the reviewer (verify each, then fix)

A reviewer cloned the repo (head `d774c8f`) and found these. Confirm each by inspection first.

1. **App icon is still the old Python-drawn farfalle bow tie** (`assets/AppIcon-1024.png`), but the owner's chosen direction is the Figma rigatoni design: https://www.figma.com/design/bocBCCWoX3YUHX3qBJX3WQ/Pasta?node-id=16-2 (file key `bocBCCWoX3YUHX3qBJX3WQ`, page "Pasta App Icon", frame "Pasta Icon v2 / Rigatoni Wheel 1024", node `16:2`). The menu bar glyph is already a rigatoni silhouette, so the two are inconsistent. **Do not redraw the icon.** If you have a Figma tool, export node `16:2` as a 1024 PNG; otherwise ask the owner to export it and put it at `assets/AppIcon-1024.png`. Rebuild the iconset and `AppIcon.icns`, confirm the built app shows it, and make sure the menu bar glyph matches. If the PNG is missing, mark this blocked. Do not change the design; the owner may still ask for polish.
2. **Liquid Glass for macOS 27 ("Golden Gate").** Facts checked on Nov 2, 2026: macOS 27 shipped Sep 14, 2026 with Xcode 27 (macOS 27 SDK); Apple says apps that already use system Liquid Glass pick up the macOS 27 refinements automatically, without recompiling, and the system now has a user transparency slider and respects Reduce Transparency and Increase Contrast. The code currently uses only `NSVisualEffectView` (19 references) and no system glass API at all. Required:
   - Use the system glass classes (`NSGlassEffectView` and `NSGlassEffectContainerView`, so neighboring nodes merge and morph) for the backplate, hub, nodes, Customize sheet, parameter panel and hint pill. **Check the real API names and any new macOS 27 glass APIs in the installed Xcode 27 SDK headers and Apple's documentation; do not guess.** Use any macOS 27-only API behind `#available(macOS 27, *)`.
   - Tiered rendering: macOS 27 (primary target) uses system glass with the macOS 27 behavior; macOS 26 uses the same system glass classes; older macOS keeps the current `NSVisualEffectView` layered fallback. Keep the deployment target as it is unless the owner asks to raise it.
   - Let the system handle transparency, the user's transparency slider and the accessibility modes; do not fake them. Keep the legibility scrim for labels over busy wallpapers (the owner uses a red car wallpaper) and add contrast tests.
   - Performance: no more than two live blur layers outside system glass; open animation under 220 ms; measure and report.
   - **CI:** GitHub's old OS-named macOS images are being replaced by Xcode-named images; the `xcode-27` label (arm64 only) is generally available since Oct 15, 2026, and macOS 14 images are unsupported from Nov 2, 2026. Change the workflow to build and test on `xcode-27`, keeping a second job on the older image (whatever `macos-latest` resolves to) as a fallback check that the pre-27 path still builds. Print `sw_vers` and `xcodebuild -version` in the log of each job. Report on which OS/SDK each result was obtained, and what the owner's Mac runs.
3. **README is stale** (it says 157 unit tests and wrong runner details). Update it from real counts; ideally have a script print the counts so the README cannot drift.
4. **Missing behavior tests for the sticky wheel:** with auto-close off, the wheel stays open for 10 s after a successful conversion, after a cancel, and after an error; errors remain visible with Copy Details. The existing test only checks the setting's default and toggle.
5. **Stale-drag typing bug** (Shift held while typing opened the wheel from an old pasteboard) was fixed in code (mouse-down plus pasteboard change count). Verify the logic by reading `DragMonitor.swift` and run the Section 36 tests; the owner confirms on the machine with the typing test in `docs/MANUAL_CHECKS.md`.
6. **Settings window:** check that it shows the `pasta doctor` results (tool paths and missing optional tools) and the hold-duration slider; add what is missing, with tests.
7. **Phase 9 audit:** `docs/PROGRESS.md` marks all of `docs/PHASE9.md` Steps 1 to 5 as done. Re-verify ten of the claimed items at random (including exact target-size compression, video join, collage, QR, metadata edit, audio bleep) by running the real CLI on fixtures and checking outputs with `ffprobe`, `identify`, `exiftool`, `qpdf --check`.

Commit each fix separately with its tests. Report after finishing Part 2.

## 3. Part 3: Continue with Phase 11

Follow `docs/PHASE11_TOOLS.md` (the owner will add this file; if it is missing from `docs/`, stop and ask). It has three blocks (A: Office to PDF and images, OCR, PDF security, BMP/AVIF/PDF-EPUB/PDF-A; B: PDF to Word and the Actions wheel; C: editors). Nothing from it exists in the repo yet.

Rules for Part 3:
- Start with its Step 0, then Block A only. Stop and report after each block, then wait for the owner.
- You can run the real tools locally; still add CI coverage. Install LibreOffice locally with Homebrew (`brew install --cask libreoffice`) and record the version; add the same to the CI workflow.
- Verify every command recipe by hand on a real fixture and record it in `docs/commands.md` before coding it.
- Every new action needs: a display name and a distinct glyph, a Section 8 hostile-filename test, a leftover-temp and orphan-process check, a source-unchanged check, and a readable error when the required tool is missing.
- Do not claim that UI looks right. Add screenshots requests to `docs/MANUAL_CHECKS.md` and let the owner confirm.

## 4. Report format (every report)

1. What you found or changed, one line per item, with commit hashes.
2. Exact command output for tests (counts and the names of new tests).
3. What you could not verify and why.
4. What the owner must check manually.

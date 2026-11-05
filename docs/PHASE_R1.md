# PHASE R1 — Close R0 gaps, ship v0.1.0-beta, finish Phase 11 Block A, then small features

You are continuing Pasta (repo soul991/Pasta, branch `codex/r0`). Phase R0 is done and was reviewed. This document is the full plan for everything that remains. Work through it in order, with no pauses for approval between steps, but obey every gate and stop condition below.

## 0. Standing rules (apply to every step)

1. No network code in the app. No third-party Swift packages. No shell strings: arguments are always arrays.
2. RED then GREEN. For each fix, first show the test failing on the current code (CI run id and log excerpt), then show it passing after the change. If a test already passes before any change, report that instead of changing code.
3. Never weaken or delete an existing assertion to make something pass. Never mark something DONE without a commit hash and a test or log that proves it.
4. Never hand-type test counts anywhere in docs. Counts come from CI logs or `scripts/test_counts.sh`.
5. Never force-push. Never delete branches. You may delete only tags/releases you created yourself for testing.
6. Report honestly. If something is blocked, partial, or unverified, say so in the step report. "Not verified" is an acceptable answer; a false "verified" is not.
7. You now run directly on the owner's Mac (macOS 27.2, Xcode 27.2). Run every build and test locally AND in GitHub Actions. A step passes only when the local run and both CI jobs (the macos-27 job and the `macos-latest` fallback job) are green. If local and CI results differ, report the difference and its cause; do not hide either one. Use the repo's real Mac path, not any old Windows path (`d:/Istak/Pasta`) mentioned in earlier reports.
8. Do not start Block B of Phase 11, notarization, a route planner, bundled engines, browser-URL drags, watch folders, HWP, CAD or 3D. They are out of scope.
9. If the plan is unclear or two rules conflict, write the question to `docs/QUESTIONS.md`, stop that step, and continue with the next independent step if one exists.

## 1. Supervisor sub-agent (launch this FIRST, before any code change)

Launch a separate verifier agent with its own fresh context. If your tool cannot launch a sub-agent, say so in the first report and do a clearly labeled fresh-context self-audit instead; do not pretend.

The supervisor is READ-ONLY. It must never edit code, tests, docs, or workflows. Its job:

- Before each step starts: read this document and confirm the step's scope and gate, and write them to `docs/SUPERVISOR_LOG.md` (the only file it may write).
- While a step runs: check that you are only doing work inside that step. Flag scope creep, skipped steps, reordered steps, and any rule violation from section 0.
- When a step ends: independently re-check the evidence. It must open the CI run, read the job logs itself, and compare them against your report: commit hash exists on `origin/codex/r0`, run id matches, counts match the logs, RED evidence exists, both jobs are green, no assertion was weakened (inspect the diff of `PastaTests/main.swift` and `scripts/run_section8_tests.sh` for removed or loosened checks), no hand-typed counts in docs.
- It also re-runs the step's key local commands itself on the Mac (at minimum `swift run PastaTests`, the Section 8 script, and the step's own new tests) and compares the output with your report.
- It records PASS or FAIL per gate item with evidence in `docs/SUPERVISOR_LOG.md`.
- You may start the next step only after the supervisor records PASS for the current one. On FAIL you fix the named items and the supervisor re-checks. After 3 failed re-checks on the same item, stop that step, record it in `docs/QUESTIONS.md`, and move on.
- At the end the supervisor writes a final summary table: every step, PASS/FAIL/BLOCKED, evidence links.

## 2. Step report format (every step)

Each step report contains: commits (hashes), CI run id(s), environment lines from both CI jobs AND the local Mac (`sw_vers`, `xcodebuild -version`, `swift --version`), exact pass/fail counts copied from the local output and from the CI logs (side by side), RED evidence, GREEN evidence, files changed, anything not verified, and the supervisor's verdict for that step.

---

## PART A — Close the R0 gaps

### Step A1 — Icon verification (the asset is already at `assets/AppIcon-1024.png`)

- Do not ask for the icon again. It exists.
- Check locally first with `sips`, then add a macOS CI step that checks the PNG: size is exactly 1024x1024, it has an alpha channel (`sips -g hasAlpha`), and the four corner pixels are fully transparent (read pixel data with `python3`; no extra packages). Fail CI if the corners are opaque, because a gray box around the Dock icon is the known risk.
- Run `scripts/generate_app_icon.py`, build the app, and assert in CI that `Pasta.app/Contents/Resources/AppIcon.icns` exists and `Info.plist` names it.
- If the corners are opaque, do NOT edit the artwork. Report it as BLOCKED with the evidence, and continue.
- Gate: both jobs green; the corner check is proven RED on a deliberately opaque test PNG (generated in the test, not committed), then GREEN on the real asset.

### Step A2 — Hostile archive tests must assert what the fixtures claim

`scripts/make_hostile_archives.sh` generates 15 fixtures but Section 39 does not assert all of them.

- Add assertions for each of: `hardlink_outside.tar`, `duplicate_names.zip`, `case_collision.zip`, `unicode_normalization.zip`, `very_long_names.tar`, `many_files.zip`. For each, define the expected behavior first (reject, or extract safely with deterministic naming), write it down in `docs/commands.md`, then assert it.
- For `hardlink_outside.tar`: prove nothing outside the scratch root is modified or linked.
- Gate: every fixture the script generates has at least one named assertion in Section 39 or Section 7.3. A small script check lists fixtures and fails CI if one has no matching test name.

### Step A3 — Stop damage during extraction, not only after

Today `ArchiveGuard.validate` runs after extraction. Prove the following, and fix what fails:

- Symlink hop (`symlink_hop.tar`, and a zip/7z/rar variant if the extractor supports it): assert that NO file is created outside the scratch root at any point, by checking a sentinel directory outside the root after extraction attempts. This must be tested for each extractor: `tar`, `ditto`, `7zz`, `unar`.
- Preflight must also catch link targets, not just names: use verbose listings (for example `tar -tvf`, `7zz l -slt`) and reject symlink or hardlink entries whose targets are absolute or contain `..`.
- State in `docs/commands.md`, per extractor, exactly what protects it. If an extractor cannot be made safe by preflight plus scratch-root isolation, remove it from the extraction path (fall back to another extractor) and say so. Do not leave an extractor in the path that you have not tested against the hop fixture.
- Gate: sentinel-outside-root test passes for each extractor that remains wired in; the RED run shows the failure for any extractor that needed a fix.

### Step A4 — Bomb limits before the disk fills

- Add a pre-extraction check using the archive catalog: sum of declared uncompressed sizes and entry count versus `ArchiveLimits`. Reject before extracting when the catalog already exceeds the limits.
- For formats where the catalog can lie or is unavailable, enforce a running cap while extracting (poll scratch-folder size, kill the extractor process and wipe scratch when exceeded).
- Report which limit values test 39.9 uses. Add one test that runs with the REAL default limits against a catalog-declared oversize case that does not actually write gigabytes (for example, a catalog that declares a huge size), so the default path is covered.
- Gate: bomb fixture rejected before or during extraction, scratch wiped, no orphan process, destination untouched.

### Step A5 — Real-timer smoke test for 33.7

- Keep the virtual-clock test. Add ONE test that uses the real timer with a generous margin (for example 1 s deadline, check at 100 ms and 1.2 s), clearly named as a smoke test.
- Run that test 50 times in a loop, locally on the Mac and in CI, and paste both pass rates. If it is not 50/50, widen the margin and rerun.

### Step A6 — Full local Mac verification (you run this, on this Mac)

Create `scripts/local_verify.sh` and RUN it yourself. It writes `local_verify_report.txt` and must print: `sw_vers`, `xcodebuild -version`, `swift --version`, `swift run PastaTests` pass/fail counts (Debug and `-c release`), `PASTA_BIN=.build/debug/Pasta ./scripts/run_section8_tests.sh` counts, `./scripts/build_app.sh`, the Section 8 run against `Pasta.app`, `codesign --verify --deep --strict Pasta.app`, `pasta doctor --json`, and the icon corner check. Paste the full report in your step report. Add the script to `docs/MANUAL_CHECKS.md` so it can be rerun later. Gate: local counts match CI counts (or the difference is explained), and the local macOS/Xcode versions are recorded.

### Step A7 — Wording and hygiene

- `SECURITY.md` and README: reword "100% offline" claims to what is actually verified (no network APIs linked, binary symbol scan, no telemetry code) and avoid absolute guarantees.
- `THIRD-PARTY-NOTICES.md`: make the engine count consistent with `pasta doctor` (it lists 19 tools; the notices say 14). Explain the difference or fix it.
- Do not change the LICENSE name. The owner confirms that.
- Gate: no contradictory numbers between README, notices, doctor.

### Step A7b — License audit and bundling policy (documentation and tests only; do NOT bundle any tool yet)

The owner plans to bundle engines later and to accept donations and, maybe, website ads. Prepare the legal groundwork now. This is not legal advice; write it as an engineering record.

- Create `docs/LICENSE_AUDIT.md` with one row for every tool in `ToolLocator` (all 19). Columns: tool, license (SPDX id), upstream license URL, how Pasta uses it (always a separate process, never linked), obligations when redistributed (notice text, source offer, replaceability), risk (low, medium, high), and bundling decision (core pack, optional download pack, or never bundle).
- Verify every license from the upstream project's own license file or official page. Put the URL and the date checked in the row. If you cannot reach the upstream page, write `UNVERIFIED`; never guess a license.
- Record these known points and confirm them against upstream:
  - **ffmpeg:** LGPL 2.1+ only when built without GPL parts. Any bundled build must be our own, configured without `--enable-gpl` and without `--enable-nonfree`. Never copy a Homebrew binary. Document the exact configure line, the source-hosting plan (matching source next to the download), and that H.264/HEVC encoding uses Apple VideoToolbox instead of libx264/x265. Note the codec patent risk.
  - **Ghostscript:** AGPL or commercial from Artifex. Default decision: not in the core bundle. Either replace its use with PDFKit/qpdf where possible, or ship it only as an optional download pack with its own AGPL notice and source link, installable only by explicit user choice and separable/replaceable. Risk: high.
  - **7zz:** LGPL plus the unRAR restriction. Binary redistribution must reproduce the license text. Pasta only extracts.
  - **ImageMagick:** derived Apache 2.0. Include the notice.
  - **LibreOffice:** record its license and the installed size you can verify; decision: optional download pack.
  - Every other tool (qpdf, Tesseract, unar, lossless image optimizers and so on): look up and record.
- Update `THIRD-PARTY-NOTICES.md` from `LICENSE_AUDIT.md` (generated or checked by a script, not hand-copied).
- Add a unit test that fails CI when a tool in `ToolLocator` has no row in `LICENSE_AUDIT.md`, and when a row has no URL and is not marked `UNVERIFIED`.
- Write `docs/DISTRIBUTION_NOTES.md` listing what the owner must prepare before any public bundled release: Developer ID account, notarization of every bundled binary, a hosted legal page listing each tool, license and source link, a privacy statement ("files never leave the Mac; network only for optional engine downloads the user chooses"), and a trademark check for the name "Pasta". Mark all of it as owner tasks.
- Gate: all 19 tools have a row; no license is stated without a URL or an `UNVERIFIED` mark; the new test is RED on an incomplete table and GREEN on the real one; the supervisor spot-checks 5 rows against upstream pages.

### Step A8 — Release workflow proof

- `release.yml` has never run. Test it on a throwaway tag `v0.0.0-test`, on `codex/r0`. Paste the run id, the produced assets, and the SHA-256 file.
- Download-and-verify step in CI: unzip the produced zip, run `codesign --verify --deep --strict`, run the app binary `--version` or `pasta doctor --json` headlessly, and check the checksum matches.
- After proof, delete only the `v0.0.0-test` tag and its test release that you created.
- Gate: release workflow green on the throwaway tag; checksum verification passes.

### Step A9 — Merge to main and tag the beta

- Open a PR `codex/r0` to `main`. Require both CI jobs green on the PR head. Merge without force. Do not delete `codex/r0`.
- Update `CHANGELOG.md` for `0.1.0-beta` from real commits. README must contain no hand-typed counts.
- Tag `v0.1.0-beta` on `main` only if the supervisor has recorded PASS for A1 to A8, including A7b (A1 may be BLOCKED if the corners are opaque; in that case do NOT tag, and report). The tag triggers the release workflow; report the release URL, asset names and SHA-256.

---

## PART B — Finish Phase 11 Block A

Find the Phase 11 WIP branch (`git branch -a`; `docs/CODEX_HANDOFF.md` and `docs/PROGRESS.md` name it). Do not rewrite its history.

### Step B1 — Fix the 9 failing assertions

- Reproduce the failing CI run first and list the 9 assertions by name.
- 7 of them assume `soffice` is present. Fix them with `ToolLocator` overrides (forced unavailable or a stub executable) so they pass on runners without LibreOffice, and add separate tests for the missing-tool path (clear error plus the install hint from `pasta doctor`).
- Investigate the other 2 on their own evidence. Do not apply the soffice fix to them by assumption. Report the root cause of each.

### Step B2 — Finish Block A scope

Block A covers Office conversions, OCR, PDF security and formats. Use `docs/PROGRESS.md` and the Phase 11 plan docs as the scope. If the scope is not written down clearly, write `docs/QUESTIONS.md` and stop B2 rather than inventing scope.

- Each action: registered in `FormatRegistry`, listed by `pasta list-actions`, has a unit test with RED then GREEN, has a missing-tool test, and uses the atomic `OutputReservation` for its output.
- PDF security actions must be tested against encrypted and malformed fixtures generated at test time.
- Behavioral proof, not structure-only: a test that registers an action does not count as proof that it converts. Mark any structure-only row honestly in `docs/PROGRESS.md`.
- Gate: Phase 11 branch merged into `main` through a PR with both jobs green, the Liquid Glass and CI items from `CODEX_HANDOFF.md` either finished or explicitly listed as unfinished.

---

## PART C — Small features (only after A and B are PASS)

### Step C1 — Per-engine concurrency cap

- Add a per-engine limit in the job queue (default 1 for `ghostscript`, 2 for `ffmpeg`, others unchanged), stored in a single table, documented.
- Test: with 6 queued ffmpeg jobs, never more than the cap run at once (use a stub tool that records concurrency). Existing atomic-output tests must still pass.

### Step C2 — Recent conversions list

- Local only, no network. Store action id, output file name and time in the app's own support folder. Store the full output path only if the user keeps that setting on; provide a "Clear" button and an off switch in Settings, default on with a visible note.
- Add a "Reveal in Finder" action. Tests for persistence, clearing, the off switch, a corrupt store file (must not crash), and a missing output file.

### Step C3 — Per-file-type wheel profiles and a Tab flip side

- Profiles: each file type gets an ordered primary set of actions for the wheel, and a secondary set reachable by pressing Tab while the wheel is open. Keep the wheel's existing Shift-hold behavior unchanged.
- Test the profile data and ordering as pure logic first. The UI behavior goes in `docs/MANUAL_CHECKS.md` for the owner, since it cannot be verified in CI. Be explicit about that.

---

## 3. Final report

When all steps are done, or stopped, send one final report with: a table of every step with status, commit and run id; what the owner must still do by hand (confirm the LICENSE name, the UI items in the manual checks list that need a human at the screen, such as the Shift-hold wheel and Tab flip, the Gatekeeper "Open Anyway" test of the released zip, and wheel screenshots for the README); and the supervisor's final table. Do not claim completion if any step is FAIL or BLOCKED.

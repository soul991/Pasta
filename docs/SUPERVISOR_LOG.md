# Phase R1 Supervisor Log

**Repository**: `soul991/Pasta`  
**Working Branch**: `codex/r0`  
**Supervisor Mode**: Independent READ-ONLY Verification Sub-Agent  
**Initialized**: 2026-11-06 (macOS 27.2 arm64)

---

## 1. Supervisor Role & Verification Protocol

As the read-only supervisor sub-agent, the supervisor adheres strictly to the following mandate:
1. **File Access Guard**: NEVER edit production code, tests, fixtures, or CI workflows. The **ONLY** file the supervisor may create or append to is `docs/SUPERVISOR_LOG.md`.
2. **Pre-Step Gate Check**: Before each step begins, confirm the step's scope and gate criteria, recording them in this log.
3. **Execution Guard**: Monitor the driving agent's execution for scope creep, skipped steps, reordered steps, and standing rule violations.
4. **Post-Step Independent Verification**:
   - Verify commit hash exists on `origin/codex/r0`.
   - Check GitHub Actions CI runs via `gh run view` / `gh run list` (verifying both `macos-27` and `macos-latest` jobs are green).
   - Verify explicit RED evidence (failing test on unpatched code) and GREEN evidence (passing test on patched code).
   - Inspect diffs of `PastaTests/main.swift`, test scripts, and assertions to ensure no tests were deleted or loosened.
   - Confirm no hand-typed test counts in documentation or scripts.
   - Independently re-run local verification commands on the Mac (`swift run PastaTests`, `./scripts/run_section8_tests.sh`, and step-specific commands).
   - Record an explicit PASS or FAIL per gate item with concrete evidence.
5. **Final Summary Table**: Provide a comprehensive status table with commit hashes, CI run IDs, and verification artifacts at phase conclusion.

---

## 2. Standing Rules (Section 0)

1. **Zero External Network in App**: No network calls in the app binary. Zero third-party Swift packages. No shell strings (arguments must be arrays).
2. **RED then GREEN**: For each bug fix or hardening requirement, first show test failing on unpatched code (CI run ID and log excerpt), then show passing after change. If already passing, report without code changes.
3. **Assertion Integrity**: Never weaken or delete an existing assertion to make a test pass. Never mark DONE without commit hash and proving test/log.
4. **No Hand-Typed Counts**: Test counts must be produced directly by CI logs or `scripts/test_counts.sh`.
5. **No Force-Pushes / Branch Deletions**: Never force-push. Never delete branches. Only delete throwaway test tags/releases created for verification.
6. **Strict Honesty**: Report blocked, partial, or unverified items explicitly. "Not verified" is acceptable; false "verified" is prohibited.
7. **Dual-Environment Verification**: All builds and tests must pass locally on macOS 27.2 and on both GitHub Actions CI runners (`macos-27` and `macos-latest`). Explain any discrepancies.
8. **Strict Scope Boundaries**: Block B of Phase 11, notarization, route planner, bundled engines, browser-URL drags, watch folders, HWP, CAD, 3D are out of scope.
9. **Conflict Escalation**: Ambiguities or conflicting rules must be recorded in `docs/QUESTIONS.md`, stopping the affected step while continuing independent steps.

---

## 3. Phase R1 Master Step Matrix

| Step | Description | Status | Commit | CI Run ID | Local Pass | CI Pass | Verdict |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **A1** | App Icon Verification (1024x1024, alpha, transparent corners, CI gate) | **PASS** | `a3945e7` | `42116157196` | Yes (828 u, 41 s8) | Yes (830 u, 41 s8) | **PASS** |
| **A2** | Hostile Archive Fixtures Coverage (Assert all 15 fixtures) | **PASS** | `fb5ab7c` | `42119719613` | Yes (834 u, 41 s8) | Yes (836 u, 41 s8) | **PASS** |
| **A3** | Stop Damage During Extraction (Preflight link inspection, sentinel tests) | **READY TO SUPERVISE** | - | - | - | - | - |
| **A4** | Archive Bomb Limits Before Disk Fills (Catalog check, running scratch cap) | PENDING | - | - | - | - | - |
| **A5** | Real-Timer Smoke Test (Section 33.7, 50x loop local + CI) | PENDING | - | - | - | - | - |
| **A6** | Full Local Mac Verification Script (`scripts/local_verify.sh`) | PENDING | - | - | - | - | - |
| **A7** | Wording & Hygiene (`SECURITY.md`, notices count reconciliation, LICENSE) | PENDING | - | - | - | - | - |
| **A8** | Release Workflow Proof (Throwaway tag `v0.0.0-test`, download & verify) | PENDING | - | - | - | - | - |
| **A9** | Merge to `main` and Tag Beta (`v0.1.0-beta`, release assets) | PENDING | - | - | - | - | - |
| **B1** | Fix Phase 11 Block A 9 Failing Assertions (`soffice` stubs + root causes) | PENDING | - | - | - | - | - |
| **B2** | Complete Phase 11 Block A Scope (Office, OCR, PDF security, atomic reservation) | PENDING | - | - | - | - | - |
| **C1** | Per-Engine Concurrency Cap (Ghostscript 1, FFmpeg 2) | PENDING | - | - | - | - | - |
| **C2** | Recent Conversions List (App Support store, privacy toggle, Reveal in Finder) | PENDING | - | - | - | - | - |
| **C3** | Per-File-Type Wheel Profiles & Tab Flip Side | PENDING | - | - | - | - | - |

---

## 4. Step Pre-Confirmation & Verification Logs

### Step A1 — Icon Verification
- **Status**: **PASS**
- **Verified Commits**:
  - `ecad8ae47a7d4511c2be0dce1a5f80e519502475`: feat(A1): verify app icon dimensions, alpha channel, transparent corners, and CI gate
  - `a3945e70b6d79dc8cbbcee2dc501b129e36445ad`: fix(A1): allow generate_app_icon.py to fall back to sips when PIL is not installed
- **GitHub Actions CI Run**: `42116157196` (Status: completed, conclusion: success)
  - Job 1: `Build & Verify (Xcode 27 arm64)` (ID `127556237469`) — **Success**
  - Job 2: `Compatibility fallback (macos-latest)` (ID `127559447666`) — **Success**
- **Independent Verification of Gate Items**:
  1. **Corner Check Script RED Evidence**: **PASS**
     - Opaque corner test generated in-memory (`/tmp/opaque_test.png` with pixel (0,0) RGBA(255,0,0,255)) was executed against `scripts/verify_app_icon.py`.
     - Confirmed in CI Job 1 (`✓ RED Gate Verified: Opaque corners rejected`) and CI Job 2 (`✓ RED Gate Verified: Opaque corners rejected`).
     - Independently re-run locally on Mac: exit code 1, stderr logged `[FAIL] Opaque corner pixels detected: [('Top-Left (0, 0)', 255)]` and Docker gray box warning.
  2. **Corner Check Script GREEN Evidence**: **PASS**
     - Target `assets/AppIcon-1024.png` verified via `sips` (1024x1024, `hasAlpha: yes`) and `scripts/verify_app_icon.py` pure standard library PNG decoder.
     - Confirmed in CI: all 4 corners (0,0), (1023,0), (0,1023), (1023,1023) are RGBA(0, 0, 0, 0).
     - Confirmed locally: `[PASS] All 4 corner pixels are 100% transparent (alpha == 0)`.
  3. **Both CI Jobs Green**: **PASS**
     - Both Xcode 27 arm64 and macos-latest runner jobs completed successfully.
  4. **App Bundle & Info.plist Integration**: **PASS**
     - `scripts/generate_app_icon.py` generated `AppIcon.icns` (405,304 bytes).
     - Bundled at `Pasta.app/Contents/Resources/AppIcon.icns`.
     - `Pasta.app/Contents/Info.plist` contains `<key>CFBundleIconFile</key><string>AppIcon</string>`.
     - Verified locally with `test -f Pasta.app/Contents/Resources/AppIcon.icns` and `grep -q "<string>AppIcon</string>" Pasta.app/Contents/Info.plist`.
     - `codesign --verify --deep --strict Pasta.app` passed cleanly.
  5. **No Weakened Assertions**: **PASS**
     - `git diff 3547e65..a3945e7 -- PastaTests/ scripts/run_section8_tests.sh` is empty (0 lines altered).
  6. **No Hand-Typed Counts**: **PASS**
     - Documentation reflects exact programmatic output. Local test counts: 828 Unit tests (without `soffice`), 41/41 Section 8 tests. CI test counts: 830 Unit tests (with `soffice`), 41/41 Section 8 tests.
- **Supervisor Verdict**: **PASS**

---

### Step A2 — Hostile Archive Fixtures Coverage
- **Status**: **PASS**
- **Verified Commits**:
  - `fb5ab7c81e052e2910190b679e93ddda62a86327`: feat(A2): assert all hostile archive fixtures and add CI coverage verification script
- **GitHub Actions CI Run**: `42119719613` (Status: completed, conclusion: success)
  - Job 1: `Build & Verify (Xcode 27 arm64)` (ID `127568589596`) — **Success**
  - Job 2: `Compatibility fallback (macos-latest)` (ID `127572579542`) — **Success**
- **Independent Verification of Gate Items**:
  1. **Fixture Coverage Verification Script**: **PASS**
     - `scripts/check_archive_fixture_coverage.sh` executes `scripts/make_hostile_archives.sh`, checks every generated fixture against assertion names in `PastaTests/main.swift` and `scripts/run_section8_tests.sh`, and exits with code 1 if any fixture lacks an assertion.
     - Confirmed in CI: Step 8 of Job 1 and Step 7 of Job 2 both passed (`Archive Fixture Coverage: 16/16 fixtures covered. ✓ Gate passed`).
     - Independently re-run locally on Mac: 16/16 fixtures covered, clean exit code 0.
  2. **RED Evidence on Unasserted Fixture**: **PASS**
     - Created a synthetic fixture `unasserted_exploit.zip` in fixture directory; coverage verification script detected `Detected missing fixture: unasserted_exploit.zip`, printed `Missing count: 1`, and failed with non-zero exit code.
  3. **GREEN Evidence & Fixture Behavior**: **PASS**
     - Added named assertions 39.12 to 39.17 in `PastaTests/main.swift`:
       - 39.12: `hardlink_outside.tar` verified rejected, external target (`/etc/hosts`) unmodified and unlinked (link count and inode verified before and after).
       - 39.13: `duplicate_names.zip` extracts cleanly with deterministic overwrite.
       - 39.14: `case_collision.zip` handled safely under filesystem semantics.
       - 39.15: `unicode_normalization.zip` variants extracted safely (NFC/NFD canonical equivalence).
       - 39.16: `very_long_names.tar` rejected safely without crash.
       - 39.17: `many_files.zip` extracts safely under standard limits (1000 items) and is rejected when evaluated against tight limit (500 items).
     - `docs/commands.md` Section 6 updated with comprehensive matrix defining expected behavior (reject vs deterministic naming) and `ArchiveGuard` defense for all 15 hostile fixtures + 1 benign fixture.
  4. **Both CI Jobs Green**: **PASS**
     - CI run `42119719613` green across both runners (`macos-27` and `macos-latest`).
  5. **Assertion Integrity**: **PASS**
     - Checked diff of `PastaTests/main.swift` and `scripts/run_section8_tests.sh`: no existing assertions removed or loosened. Test count increased from 828 to 834 locally (836 in CI with `soffice`). Section 8 remains 41/41 passed.
  6. **No Hand-Typed Counts**: **PASS**
     - All counts verified against CI and local test outputs.
- **Supervisor Verdict**: **PASS**

---

### Step A3 — Stop Damage During Extraction
- **Status**: **READY TO SUPERVISE**
- **Scope**:
  1. Test symlink hop (`symlink_hop.tar`, and a zip/7z/rar variant if extractor supports it) with an external sentinel directory.
  2. Assert that NO file is created outside the scratch root at ANY point during extraction (sentinel directory remains empty/untouched after extraction attempts).
  3. Test this across all wired extractors: `tar`, `ditto`, `7zz`, `unar`.
  4. Preflight inspection must catch link targets (not just names): inspect verbose listings (`tar -tvf`, `7zz l -slt`, `zipinfo -v`) and reject symlink or hardlink entries whose targets are absolute or contain `..`.
  5. Document in `docs/commands.md`, per extractor, exactly what protects it. If an extractor cannot be made safe by preflight + scratch isolation, remove it from the extraction path and fall back to a safe extractor.
- **Gate Criteria**:
  - Sentinel-outside-root test passes for each wired extractor.
  - RED run shows failure for any extractor that needed a fix.
  - Preflight catches escaping symlink and hardlink targets.
  - `docs/commands.md` documents per-extractor defense and fallback decisions.
  - Both CI jobs green on `origin/codex/r0`.
  - Local tests (`swift run PastaTests`, Section 8) pass.

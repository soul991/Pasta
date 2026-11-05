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

| Step | Description | Status | Commit | CI Run ID | Local Pass | CI Pass |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **A1** | App Icon Verification (1024x1024, alpha, transparent corners, CI gate) | **READY TO SUPERVISE** | - | - | - | - |
| **A2** | Hostile Archive Fixtures Coverage (Assert all 15 fixtures) | PENDING | - | - | - | - |
| **A3** | Stop Damage During Extraction (Preflight link inspection, sentinel tests) | PENDING | - | - | - | - |
| **A4** | Archive Bomb Limits Before Disk Fills (Catalog check, running scratch cap) | PENDING | - | - | - | - |
| **A5** | Real-Timer Smoke Test (Section 33.7, 50x loop local + CI) | PENDING | - | - | - | - |
| **A6** | Full Local Mac Verification Script (`scripts/local_verify.sh`) | PENDING | - | - | - | - |
| **A7** | Wording & Hygiene (`SECURITY.md`, notices count reconciliation, LICENSE) | PENDING | - | - | - | - |
| **A8** | Release Workflow Proof (Throwaway tag `v0.0.0-test`, download & verify) | PENDING | - | - | - | - |
| **A9** | Merge to `main` and Tag Beta (`v0.1.0-beta`, release assets) | PENDING | - | - | - | - |
| **B1** | Fix Phase 11 Block A 9 Failing Assertions (`soffice` stubs + root causes) | PENDING | - | - | - | - |
| **B2** | Complete Phase 11 Block A Scope (Office, OCR, PDF security, atomic reservation) | PENDING | - | - | - | - |
| **C1** | Per-Engine Concurrency Cap (Ghostscript 1, FFmpeg 2) | PENDING | - | - | - | - |
| **C2** | Recent Conversions List (App Support store, privacy toggle, Reveal in Finder) | PENDING | - | - | - | - |
| **C3** | Per-File-Type Wheel Profiles & Tab Flip Side | PENDING | - | - | - | - |

---

## 4. Step Pre-Confirmation & Verification Logs

### Step A1 — Icon Verification
- **Status**: **READY TO SUPERVISE**
- **Baseline Check**:
  - Asset exists at `assets/AppIcon-1024.png`.
  - Local inspection confirms:
    - `sips -g pixelWidth -g pixelHeight -g hasAlpha`: 1024x1024, `hasAlpha: yes`.
    - Corner pixels check `(0,0)`, `(1023,0)`, `(0,1023)`, `(1023,1023)`: all RGBA `(0, 0, 0, 0)` (fully transparent).
- **Scope**:
  1. Add a macOS CI validation step that checks `assets/AppIcon-1024.png`:
     - Exactly 1024x1024 resolution.
     - Has an alpha channel (`sips -g hasAlpha`).
     - Four corner pixels are fully transparent (tested with python3 without extra packages).
     - Must fail CI if corner pixels are opaque (avoiding Dock icon gray-box defect).
  2. Run `scripts/generate_app_icon.py`, build app, assert `Pasta.app/Contents/Resources/AppIcon.icns` exists and `Info.plist` declares `CFBundleIconFile`.
  3. If corner pixels are opaque, do NOT edit artwork; report as BLOCKED with evidence and proceed.
- **Gate Criteria**:
  - Corner check script demonstrated **RED** on a generated test image with opaque corners.
  - Corner check script demonstrated **GREEN** on `assets/AppIcon-1024.png`.
  - Both CI jobs (`macos-27` and `macos-latest`) green.
  - Local build generates `AppIcon.icns` embedded in `Pasta.app` and declared in `Info.plist`.

# PASTA PRODUCT PLAN v2 (Phase P) — the full v1.0.0 app, built in stages

This plan starts after PHASE_R1 is finished. PHASE_R1 sections 0 (standing rules), 1 (supervisor sub-agent) and 2 (step report format) are binding here too. This is a **full working version (v1.0.0)**, not a beta or a test build, but it is built in parts, in this order:

**Stage 1 Engines and core logic → Stage 2 App shell and UI → Stage 3 Packaging, audit, debugging → Stage 4 Website and going public.**

(The v0.1.0-beta tag in PHASE_R1 Step A9 is only a repository checkpoint. The product release is v1.0.0.)

---

## 1. What Pasta is

A **menu-bar utility**: a background app in the menu bar, plus a window for adding files. Three ways in, one engine:
1. **Wheel:** hold Shift while dragging a file; the radial wheel shows actions for that file type.
2. **In-app window:** add files, see suggested conversions per file type, convert.
3. **Menu:** Settings, Check for New Version, Pause wheel, Quit.

## 2. Decisions already made (do not re-open)

- **No compromise in the first build.** Bundle **every** tool Pasta uses. **No total size limit and no per-engine size limit. No extra-download packs in v1.0.0.** After the first build, the owner reviews the real size and decides what to trim; the optional-pack downloader is a later phase (section 8), not part of this build.
- Engines are **private to the app**: never installed system-wide, never on the user's PATH, never touching the user's Python, Homebrew or any environment. A bundled engine may carry its own private runtime (for example a bundled app with its own Python); it is never exposed outside the app bundle.
- Output files are created **next to the source file** (collision-safe via `OutputReservation`).
- "Delete original after conversion": **off by default**, with a **second confirmation sheet** when enabling.
- Heavy conversions: **warn, then allow** if the user insists.
- Quality policy: see section 6 (E3). Every format gets the best quality-preserving path; where users want smaller files, they get a clearly labeled lossy option.
- Network: **none, except when the user clicks "Check for New Version…"** (and, if the user turns it on later, optional automatic checks, default off). Privacy statement: *user files and their contents never leave the Mac.*
- Distribution: signed and notarized `.dmg`, direct download (not the Mac App Store). The project goes public and open source at the end of Stage 4.
- Support: a tip/coffee link on the website. No ads in the app. Website ads are a later owner decision.

## 3. Roles and workflow

- **Builder (Antigravity, running locally on the owner's Mac):** builds Stages 1 and 2 and the packaging in Stage 3 step Q1.
- **Auditor (Codex, a different tool from the builder):** Stage 3 audit. Reads everything, reports findings by severity, then fixes them with tests. The builder never audits its own work.
- **Supervisor (a separate fresh-context session or sub-agent that shares no context with the builder):** as defined in PHASE_R1 section 1, verifying every step with CI logs and local runs. It writes only to the branch `supervisor/log`, which only it may push to. The builder reads `origin/supervisor/log:docs/SUPERVISOR_LOG.md` and may not start the next step, or merge a PR, until that file has a PASS for the exact commit hash. Waiting means stopping and telling the owner, not continuing.
- **Owner:** answers the open decisions in section 4, supplies secrets and designs, runs the manual checks that need a human at the screen.

## 4. Owner decisions still open (the agent must not decide these)

Write them to `docs/QUESTIONS.md` when the work reaches them, and continue with independent steps:
1. Apple Silicon only, or Intel too? (Default assumption: arm64 only.)
2. Minimum macOS version.
3. Update mechanism for "Check for New Version" (see U7). Default proposal: Sparkle. This needs a documented exception to the "no third-party packages" rule in `CONTRIBUTING.md`.
4. Codec patents: whether to include H.264/HEVC/AAC encoding through Apple's built-in encoders only, or also through bundled encoders. Default: Apple's built-in encoders for those codecs.
5. Tip platform and website domain/host.
6. Final tool list, after `docs/LICENSE_AUDIT.md` is complete.

## 5. Architecture

- **Engine lookup order:** (1) bundled in `Pasta.app/Contents/Resources/Engines/`; (2) a system-installed tool only if the owner enables "Developer mode: use my installed tools" (off by default). `pasta doctor` reports the source of each tool.
- **Clean child-process environment:** every engine runs with a fixed minimal `PATH`, no inherited `PYTHONPATH`, `DYLD_*`, `MAGICK_*`, `GS_*` or similar variables, and its own temp and profile directories (for example a private LibreOffice user profile per job).
- **Engine manifest:** `Resources/engines.json`, with engine id, version, arm64 sha256, size, entry point. Engine versions change only through an app update.
- **Size report:** every build prints a table of each engine's size, the app total and the DMG total. Report only; it never fails a build.

---

## 6. STAGE 1 — Engines and core logic (no UI work in this stage)

### E1 — Bundle every engine
- For every tool in `ToolLocator` (all 19) and every engine the action catalog needs: `scripts/build_engines.sh` collects or builds it into a relocatable form, with all its libraries inside the bundle and library paths rewritten (`install_name_tool`), no references to `/opt/homebrew` or `/usr/local`.
- Large bundles (for example an office suite or an e-book tool with its own runtime) are copied whole into `Resources/Engines/` and run headless from there.
- Record exact versions and build flags in `docs/ENGINES.md`. Pin versions; no "latest".
- Sign every nested Mach-O binary with hardened runtime (ad-hoc in CI until the owner provides a Developer ID).
- Gate: every engine launches from the bundle and returns its version; the size table is in the report.

### E2 — Clean-machine and isolation tests (RED then GREEN)
1. **Clean PATH:** run the full conversion suite with `PATH=/usr/bin:/bin` and Homebrew directories hidden.
2. **Link check:** `otool -L` on every bundled binary shows no path outside the bundle or system frameworks.
3. **Hostile environment:** with `PYTHONPATH`, `DYLD_LIBRARY_PATH` and a fake `python3` first in PATH set, conversions behave identically.
4. **Private profiles:** two concurrent office conversions do not share or corrupt a profile; no files are left in the user's home directory.
- Gate: all green on both CI jobs and locally.

### E3 — Quality policy and compression suite (all formats)
Every action carries a **quality class**, shown to the user and enforced by tests:

| Class | Meaning | Proof required |
|---|---|---|
| **LOSSLESS (proven)** | Output decodes to exactly the same content | Automated equality test |
| **COPY** | Container change without re-encoding (stream copy) | Packet or stream hash equality |
| **VISUALLY LOSSLESS** | Re-encoded at very high quality | Quality metric above a documented threshold |
| **LOSSY (user-controlled)** | Smaller file by choice | Warning plus estimated size shown |

Per category:
- **Images:** PNG optimization, lossless JPEG re-packing, lossless WebP, TIFF and GIF lossless optimization, and lossless modes of HEIC/AVIF where the encoder supports them. Proof: decode both files, compare pixels (including alpha and 16-bit). Metadata handling is a separate toggle (default keep; "remove location data" switch).
- **Audio:** lossless to lossless conversions (WAV, FLAC, ALAC) at the strongest lossless compression; proof by comparing decoded PCM hashes. Lossy outputs offer bitrate or quality presets.
- **Video:** (1) **Keep quality:** change the container by stream copy whenever the codecs allow it (COPY); otherwise a lossless archive mode where a lossless codec exists, or a very high quality re-encode, labeled honestly. (2) **Compress:** presets (High, Balanced, Smaller) and Custom (quality level or bitrate or **target file size**, plus optional resolution/frame-rate change), using the Apple hardware encoder for H.264/HEVC where possible. Re-encoding between two lossy codecs is never labeled lossless.
- **PDF:** structure-level lossless optimization (stream recompression, object streams, linearization) with proof by rendering pages and comparing pixels; optional image downsampling as a clearly labeled LOSSY preset.
- **Archives:** strongest lossless compression levels; proof by extracting and comparing file hashes.
- **Resize (images and video):** exact pixels, percentage, or long edge; keep aspect ratio by default.
- Quality metrics for visually lossless and lossy checks are computed in test code and documented.
- Gate: for every action in the catalog, the class is declared in one table; a test fails if an action lacks a class or labels itself lossless without a passing proof test.

### E4 — Behavioral completeness of the action catalog
- Every registered action has an end-to-end fixture test that runs the real bundled engine, asserts on the output (not just that the action is registered), has a missing-input and corrupt-input test, and uses `OutputReservation`.
- Rows in `docs/PROGRESS.md` that are structure-only stay marked as such until a behavioral test exists.
- Gate: a script lists registered actions and fails CI if one has no end-to-end test.

### E5 — Heavy-job guard (logic only)
- One config file defines per-category limits and cost estimates: video (duration × pixels × codec factor via the probe tool), audio (duration), image (megapixels), PDF (pages), archives (declared size), OCR (pages).
- Exceeding a limit returns a "needs confirmation" result (the UI shows the warning later). No precise time promises.
- Always: run engines at lower priority (utility QoS); support pause and resume of a running job; check free disk space against an output size estimate; one heavy job at a time.
- Thermal protection: watch `ProcessInfo.thermalState`; at serious or critical, pause heavy jobs; resume on cool-down or user request. Flag heavy jobs on battery power.
- Tests: estimator math, threshold logic, thermal state injected through a protocol, pause/resume with a stub engine, low-disk case.

### E6 — Delete-original logic (no UI yet)
- Original goes to the **Trash**, never permanently deleted.
- Only after the output is verified: exists, size above zero, type matches, job reported success. Never on failure, cancel or partial output.
- Skip and report for: read-only volumes, files that cannot be trashed, a source that is also the output, a source that changed during conversion.
- The setting can only be enabled through a stored confirmation; no flag or `defaults write` can enable it without it.
- Tests for each rule, each with a RED stage (output missing, zero-byte output, cancelled job, read-only source).

### E7 — Trigger and permission state machine (logic only)
- States: wheel enabled/paused, Accessibility granted/missing/revoked, launch-at-login on/off. Pure-logic tests for every transition. The monitor starts automatically when permission appears, without a restart.

### E8 — Credits data and size report
- Generate the acknowledgments data (tool, version, license id, license text, source link) from `docs/LICENSE_AUDIT.md` into a bundled resource; the generated file is checked by a test against the audit table.
- Gate for Stage 1: all E-steps PASS, supervisor spot-check of 5 random actions end to end on the Mac, size table reported.

---

## 7. STAGE 2 — App shell and UI (functional first; visual polish is a separate step)

### U1 — Menu-bar agent
- `LSUIElement` agent; closing the window does not quit; menu: Open, Settings, Pause wheel, Check for New Version…, Quit. "Launch at login" via `SMAppService`, offered during onboarding and in Settings.
- Accessibility state shown in the menu with a deep link to System Settings; auto-start when granted.
- Help text: "Quitting Pasta turns the Shift-drag wheel off. Use Pause wheel instead." (macOS cannot deliver global events to a process that is not running.)

### U2 — In-app conversion window
- Add files by drop or "Add…"; each file shows its detected type and suggested actions (same data as the wheel); batch queue with progress and cancel; results with "Reveal in Finder"; output next to the source; per-engine concurrency caps and the heavy-job warning (Continue anyway / Cancel).

### U3 — Options sheet
- For each action: quality class label, presets and Custom (quality, bitrate, target size, pixels, percentage, long edge), estimated output size when known, and a plain warning for lossy choices.

### U4 — Settings
- Launch at login, wheel on/off, delete original (double confirmation as in E6), heavy-job warnings, recent conversions (clearable, can be turned off), "Developer mode: use my installed tools", "Uninstall Pasta completely" (removes preferences, recent list, login item, caches, then moves the app to the Trash).

### U5 — First-run onboarding
- Screens: what Pasta does; how to use it (hold Shift while dragging a file); why Accessibility is needed with a button to open System Settings and live detection; launch at login choice; try it with a sample file. Re-openable from Help.

### U6 — Licenses and credits window
- Help or About opens an Acknowledgments window listing every bundled tool with version, license and link, and the full license texts (from E8). A `Licenses/` folder is also inside the app bundle.

### U7 — "Check for New Version…" (check and install)
- Menu item runs a **manual** check; no background checks unless the user turns them on in Settings (default off).
- Default design (owner decision #3): Sparkle, with: appcast hosted on the project site or GitHub Pages; updates signed with an EdDSA key (owner secret, never in the repo) and the app signature checked; shows the new version and release notes; Install then relaunch; the same Developer ID keeps Accessibility permission after an update.
- Because the app bundles many engines, updates will be large: enable delta updates if supported, and report real update sizes.
- Network scope: this is the only network code in Pasta. A test proves no other source file uses networking APIs; the Section 8 "offline" check becomes "network only in the updater and only on user action".
- Tests (local loopback fixture only): update available, none available, offline, tampered update rejected, downgrade rejected, interrupted download.
- Privacy text: the update check sends only a standard request for the appcast file.

### U7b — Keeping the user's data safe across updates
- User data (settings, recent list, onboarding state, delete-original confirmation) lives outside the app bundle (`~/Library/Preferences` and `~/Library/Application Support/Pasta/`), so replacing the app never touches it. Every stored data format carries a `schemaVersion`.
- On the first launch of a new version, if the stored `schemaVersion` is older: (1) copy the data to a temporary backup folder inside Application Support (permissions `0700`, owner only); (2) migrate; (3) validate the migrated data; (4) on success, **permanently delete the backup** (a normal file delete, not the Trash); (5) on any failure, restore from the backup, keep the old data, show a plain message, and keep the backup until the next successful launch.
- If no migration is needed, no backup is made.
- The updater never deletes the old app by hand: the update replaces it only after the new app is downloaded and verified. If anything fails before that, the old app stays untouched.
- Tests: migration success removes the backup; a corrupted data file triggers restore; an interrupted migration (simulated crash) recovers on the next launch; a newer `schemaVersion` than the app understands is never overwritten; the backup folder is gone and not in the Trash after success.
- Note for the docs: the backup is protected by normal file permissions only. Other programs running as the same user could read it, since Pasta is not sandboxed.

### U8 — Visual design pass
- Starts only when the owner provides designs (Figma or Canva). Implement them without changing behavior; all tests stay green.

- Gate for Stage 2: all U-steps PASS; manual checks added to `docs/MANUAL_CHECKS.md`.

---

## 8. STAGE 3 — Packaging, audit, debugging

### Q1 — DMG, signing, notarization
- `scripts/build_dmg.sh`: DMG with a background image showing an arrow from the Pasta icon to the Applications folder, fixed icon positions and window size (placeholder art until the design pass).
- Developer ID signing of every nested binary and the app, `notarytool` submit, staple, then the same for the DMG; SHA-256 file. Owner provides the certificate and API key as GitHub secrets; until then the pipeline runs in dry-run mode and says so.
- Verify in CI and locally: `codesign --verify --deep --strict`, `spctl -a -vv`, `stapler validate`; mount the DMG and run `pasta doctor --json`.
- Big-file notes: report the DMG size; GitHub release assets have a per-file size limit (as far as I know 2 GiB), so check it and report if the DMG is near it. If it does not fit, stop and ask the owner; do not split or drop engines on your own.
- Signing many nested binaries is the riskiest packaging step: report every binary that failed notarization and why.

### Q2 — Independent audit by Codex (read-only first)
- The auditor reads the whole repo and produces `docs/AUDIT_REPORT.md`: findings by severity (critical, high, medium, low) with file and line, covering: security (archive handling, process execution, environment, updater, delete-original), concurrency and races, CPU/memory/thermal behavior, error handling, tests that only check structure, dead code, and docs that disagree with code.
- Then the auditor fixes findings in severity order, each with a RED then GREEN test, one commit per finding group. Nothing is "fixed" without a test or a log that proves it.
- The builder does not review its own code in this step.

### Q3 — Manual test matrix (owner's Mac)
- Fresh-account test of the real DMG: drag to Applications, first launch, Gatekeeper, Accessibility, wheel, in-app conversion of every category, quality options, delete-original, heavy-job warning, update check, uninstall. Results in `docs/MANUAL_CHECKS.md`.

### Q4 — Soak and thermal tests
- Run long fixtures (for example a long 1080p video, a large PDF, a big image batch); record time, CPU, memory and thermal behavior; confirm pause/resume and the thermal pause work. Report the numbers.

### Q5 — Freeze
- Full regression on both CI jobs and locally; `local_verify.sh` report; supervisor final table. No new features after this point.

---

## 9. STAGE 4 — Website and going public

### W1 — Website
- One page: hero with a demo, features, privacy statement ("your files never leave your Mac; the only network use is the update check you click"), how it works, download button (latest release DMG), FAQ (first launch, Accessibility permission, quitting vs pausing, updating, uninstalling), tip link, footer with changelog, credits and source link.
- Static site on free hosting. No analytics and no ads at launch (ads are a later owner decision, never in the app).

### W2 — Docs and README
- README with real screenshots and a short demo; no hand-typed counts; install instructions; the credits link.

### W3 — Make the repository public (checklist)
- Secret scan of the whole git history (keys, tokens, certificates, personal paths); remove or rewrite anything found, with the owner's approval; confirm `LICENSE`, `SECURITY.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, issue templates and `THIRD-PARTY-NOTICES.md` are present and generated from the audit; confirm no private design files or credentials are tracked.
- Owner flips the repository to public; the agent never changes repository visibility.

### W4 — Release v1.0.0
- Tag `v1.0.0`; release contains the DMG, SHA-256 file, release notes, and the compliance files from section 10; announce through the tip page and README.

---

## 10. Public-release compliance (detail lives in `docs/LICENSE_AUDIT.md`)

Crediting a tool is **not by itself enough**. Open-source licenses have conditions, and the agent must research each tool and meet them. Required deliverables before W4:
- For every bundled tool: license id, upstream license URL, date checked (`UNVERIFIED` if it could not be checked), and exactly what the license requires.
- License texts shipped inside the app and shown in the Acknowledgments window (U6).
- For every copyleft tool (GPL, LGPL, AGPL and similar): the **exact corresponding source** (or the pinned upstream version plus our build scripts and any patches) published with the same release, and a written offer in the notices. Each such tool stays a separate, replaceable executable.
- No components with "nonfree" or redistribution-forbidding terms; no build options that turn a permissive or LGPL build into a non-redistributable one. Never copy a package-manager binary; build our own.
- Tool-specific conditions recorded and obeyed (for example restrictions on RAR compression code, ffmpeg build flags, Ghostscript's AGPL conditions).
- Codec patents are separate from copyright licenses and are not solved by credits; follow owner decision #4.
- Trademarks: use tool names only to describe compatibility.
- This is an engineering record, not legal advice. If any row is `UNVERIFIED` or high risk, list it for the owner; the owner may choose a lawyer review before release.

## 11. Deferred (after v1.0.0, owner decides)

- **D1 Size review:** with the real size table, the owner decides what to trim.
- **D2 Optional packs and downloader:** only if D1 says so; design from scratch then (hash checks against a manifest inside the app, user consent dialog, resume of the pending conversion).
- Finder Quick Action, Mac App Store, telemetry, ads in the app: out of scope.

## 12. Build order

E1 → E2 → E3 → E4 → E5 → E6 → E7 → E8 → U1 → U2 → U3 → U4 → U5 → U6 → U7 → (U8 when designs arrive) → Q1 → Q2 → Q3 → Q4 → Q5 → W1 → W2 → W3 → W4. Do not reorder without the owner.

## 13. Final report

A table of every step with status, commit, CI run id and local results; the size table; open owner decisions; the audit report summary; the supervisor's final table.

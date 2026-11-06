# Changelog

All notable changes to Pasta are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.1.0-beta] - 2026-11-06

### Initial Beta Release

#### Added
- **Radial Wheel UI**:
  - Global hotkey and Shift-hold gesture triggers for instant contextual conversion wheel.
  - Multi-tier visual hierarchy: Liquid Glass on macOS 27+ with smooth fallback to standard materials on macOS 26.
  - Dock and screen boundary avoidance with dynamic sector positioning.
  - Wheel sticky behavior toggle and configurable drag-hold threshold slider in Settings.
- **Unified Format Registry & Engine Integration**:
  - Over 50 conversion actions spanning Image, Video, Audio, Document, PDF, and Archive workflows.
  - Integration with user-managed CLI engines: `ffmpeg`, `imagemagick`, `webp`, `ghostscript`, `qpdf`, `poppler`, `exiftool`, `pandoc`, `librsvg`, `unar`, `sevenzip`, `libreoffice`, and `calibre`.
  - Advanced conversion actions toggled via Option key or explicit CLI `--action` flags.
- **Pasta CLI**:
  - Full-featured command-line companion (`pasta convert`, `pasta doctor`, `pasta list-actions`).
  - Batch conversion support with directory outputs and compression workflows.
  - Actionable doctor diagnostics with Homebrew formula mappings, copy-paste install commands, and `--json` export.
- **Atomic Output Reservation (Phase R0)**:
  - Introduced `OutputReservation` to eliminate race conditions during concurrent conversions.
  - POSIX `open(path, O_CREAT | O_EXCL)` atomic file placeholder reservation.
  - `mkdir` folder reservation with APFS-safe atomic publication and pre-macOS 27 directory fallback.
  - Strict "never overwrite existing files" invariant preserved across parallel CLI and App instances.
- **Hostile Archive Defense Suite (`ArchiveGuard`) (Phases R0 & R1)**:
  - Protection against Zip Slip, relative and absolute directory traversal, symlink hopping, and hard-link escapes.
  - Preflight link inspection and sentinel directory traversal validation preventing extraction damage.
  - Decompression bomb protection with pre-extraction catalog sizing and running disk scratch cap with process termination and atomic cleanup.
  - Automated rejection of special device nodes, FIFOs, and setuid/setgid elevated privilege binaries.
  - Full automated coverage asserting 15 hostile archive fixtures in CI.
- **Licensing & Documentation**:
  - Comprehensive 19-tool license audit (`docs/LICENSE_AUDIT.md`) detailing SPDX identifiers, upstream URLs, and bundling decisions.
  - Pre-release distribution guide (`docs/DISTRIBUTION_NOTES.md`) covering Developer ID, notarization, and trademark clearances.
  - Reconciled notices and verified zero telemetry / local-only processing documentation.
- **Repo Hygiene & CI (Phases R0 & R1)**:
  - App icon validation: verified 1024x1024 dimensions, alpha channel, and transparent corner pixels.
  - 100% offline network verification in CI binary analysis.
  - Dual macOS CI pipeline covering macOS 27 (Xcode 27) and macOS 26 (Xcode 26 fallback).
  - Ad-hoc signed GitHub Actions release pipeline packaging `Pasta.app` with automated unpacking, SHA-256 checksum verification, codesign validation, and headless diagnostics test.

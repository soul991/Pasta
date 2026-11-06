# Phase P: Owner Decisions & Open Questions

As specified in `docs/PHASE_P_PRODUCT_PLAN.md` (Section 4), the builder agent does not make policy or legal decisions on these open items. They are recorded here for the owner's determination while the agent continues with independent engineering steps:

## 1. Target Architectures: Apple Silicon only, or Intel too?
- **Status**: Pending Owner Decision.
- **Default Assumption**: `arm64` (Apple Silicon) only.
- **Notes**: Supporting `x86_64` (Universal 2 binary) would double the size of all bundled binaries and dynamic libraries in Stage 1, and requires dual compilation toolchains.

## 2. Minimum macOS Version
- **Status**: Pending Owner Decision.
- **Current Baseline**: macOS 26 (Sequoia) / macOS 27.
- **Notes**: System glass features (`NSGlassEffectView`, `NSGlassEffectContainerView`) rely on macOS 26+ and macOS 27 APIs.

## 3. Update Mechanism for "Check for New Version…"
- **Status**: Pending Owner Decision.
- **Default Proposal**: Sparkle framework with EdDSA update signing and hosted appcast.
- **Notes**: Adopting Sparkle requires a documented exception to the "zero third-party Swift packages" rule in `CONTRIBUTING.md`. Updates will be purely user-initiated (manual menu click by default; automatic checks off by default).

## 4. Codec Patent Strategy (H.264 / HEVC / AAC)
- **Status**: Pending Owner Decision.
- **Default Proposal**: Use Apple's built-in hardware encoders (`VideoToolbox` / `AudioToolbox`) exclusively for H.264, HEVC, and AAC.
- **Notes**: Completely avoids patent royalties and licensing restrictions associated with shipping software encoders (like `x264` or `x265`).

## 5. Support Platform & Website Domain/Host
- **Status**: Pending Owner Decision.
- **Scope**: Tip/coffee platform link (e.g. GitHub Sponsors, Buy Me a Coffee, Ko-fi) and custom domain/hosting provider for Stage 4 website (`W1`).

## 6. Final Tool Bundling List
- **Status**: Pending Owner Decision after Stage 1 engine size audit.
- **Scope**: Review exact sizes of the 19 tools in `ToolLocator` and choose whether any large engines (e.g. LibreOffice, Calibre) should be deferred to an optional download pack or included in the core bundle.

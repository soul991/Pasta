# Pasta Distribution & Release Preparation Notes

*This document outlines all mandatory owner tasks, legal prerequisites, and signing infrastructure required before any public bundled distribution or commercial release of Pasta.*

---

## Owner Pre-Release Action Items (Owner Tasks)

The following items cannot be performed by automated agents or CI runners without owner-held credentials and legal authorization. Each item must be reviewed and completed by the repo owner:

### 1. Apple Developer ID Account & Application Signing
- [ ] **Enroll in Apple Developer Program**: Ensure an active Apple Developer Program membership is registered for "Istak Ahamed" or your registered organization.
- [ ] **Generate Developer ID Application Certificate**: Create and install a valid `Developer ID Application: Istak Ahamed (<Team ID>)` certificate in the macOS Keychain.
- [ ] **Provision Xcode CI Credentials**: Store `APPLE_DEVELOPER_ID_CERTIFICATE_BASE64`, `APPLE_CERTIFICATE_PASSWORD`, and App Store Connect API keys (`APPLE_API_KEY_ID`, `APPLE_API_ISSUER_ID`, `APPLE_API_KEY_P8`) in GitHub Actions repository secrets.

### 2. Binary & Bundle Notarization
- [ ] **Apple Notary Service Configuration**: Configure automated notarization via `xcrun notarytool submit` in the release workflow.
- [ ] **Notarization of Bundled Executables**: If any third-party engine binary is ever bundled in future phases, every single binary within `Pasta.app/Contents/MacOS/` or `Pasta.app/Contents/Resources/` must be individually signed with the Developer ID and Hardened Runtime (`--options runtime`), and submitted for Apple notarization before app bundle stapling (`xcrun stapler staple Pasta.app`).
- [ ] **Stapling Ticket Verification**: Ensure Gatekeeper accepts the app bundle offline on fresh macOS user accounts via `spctl --assess --type execute --verbose Pasta.app`.

### 3. Hosted Legal & License Compliance Page
- [ ] **Create Public Legal Compliance Webpage**: Host a permanent, publicly accessible legal page (e.g. `https://pasta.app/legal` or on GitHub Pages) containing:
  - Exact copy of `docs/LICENSE_AUDIT.md`.
  - Upstream project links and source code download links for all 19 tools.
  - Complete corresponding source code offer for any copyleft engine distributed or bundled.
  - Copies of LGPL-2.1, GPL-2.0, GPL-3.0, AGPL-3.0, Apache-2.0, BSD, and MPL-2.0 licenses.

### 4. Privacy Statement & Network Scope
- [ ] **Publish Public Privacy Statement**: Prominently display the following privacy declaration on the website and release notes:
  > *"Pasta is built on strict local processing. Your files never leave your Mac. Zero network frameworks, tracking, or telemetry mechanisms exist in the app binary. Network activity occurs only if the user explicitly chooses to download optional open-source conversion engines via Homebrew."*

### 5. Trademark & Name Clearance
- [ ] **Trademark Search**: Conduct a formal trademark availability search for the software mark "Pasta" under Class 9 (Computer software for file conversion and desktop utility) with the USPTO and applicable regional trademark registries to prevent domain or trademark conflicts with existing products.

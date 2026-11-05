# Security Policy

## 100% Offline & Zero Telemetry Guarantee

Pasta is designed with strict local privacy and offline guarantees:
- **Zero Network Calls**: Pasta contains no network stack usage (`URLSession`, BSD sockets, or external HTTP requests) in its application and CLI code.
- **Zero Telemetry & Tracking**: No analytics, crash telemetry, pingbacks, or user surveillance mechanisms exist in Pasta.
- **Verified by CI**: Every build of the CLI binary and the macOS App bundle is automatically checked in continuous integration for foreign network strings, sockets, and endpoints (`scripts/run_section8_tests.sh`).

All file processing and conversions run strictly on your local machine using standard system tools and user-managed open-source engines.

---

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |
| < 0.1   | :x:                |

---

## Reporting a Vulnerability

If you discover a security vulnerability or exploit vector (e.g., directory traversal, unhandled hostile archive extraction, privilege escalation, or race condition), please report it responsibly:

1. **GitHub Security Advisories (Preferred)**: Submit a private report via the [Security tab](https://github.com/soul991/Pasta/security/advisories) on GitHub.
2. **Direct Contact**: Email the maintainer at `soulnew3456@gmail.com` with the subject line `[SECURITY] Pasta Vulnerability Report`.

Please include:
- A description of the vulnerability and its attack vector.
- Steps to reproduce or proof-of-concept file (do not attach destructive binary payloads).
- Expected vs. actual behavior.
- Affected macOS versions and environment details.

We aim to acknowledge reports within 48 hours and provide a fix or mitigation promptly before public disclosure.

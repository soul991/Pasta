# Security Policy

## Verified Local Processing & Zero Telemetry Architecture

Pasta is designed with strict local privacy and verified architectural isolation:
- **No Network Frameworks or Symbols**: No network frameworks (such as `CFNetwork` or `Network.framework`) or network APIs (`URLSession`, BSD sockets, or HTTP client code) are imported or linked into the application or CLI binaries. This is verified by binary symbol and string scanning (`nm` and `strings`) on every CI build via `scripts/run_section8_tests.sh`.
- **Zero Telemetry & Tracking**: Zero analytics, crash telemetry, pingbacks, usage reporting, or user surveillance mechanisms exist in the codebase.
- **Local Engine Invocation & Process Isolation**: Pasta executes all conversions using self-contained bundled engines located within `Pasta.app/Contents/Resources/Engines/` (or user-installed system tools when Developer Mode is explicitly enabled). Engines run in an isolated child-process environment with minimal `PATH` (`/usr/bin:/bin`), stripped environment variables (`PYTHONPATH`, `DYLD_*`, `PERL5LIB`), and per-job private temporary directories. Pasta never connects to external servers, never downloads components dynamically at runtime, and user files never leave the machine.
- **Input Validation & Sandboxing**: In-flight conversions write to isolated temporary scratch directories and publish atomically via collision-safe output reservations. Archive operations enforce pre-extraction catalog checks, running disk expansion caps, and reject path traversal escapes.

All file processing and conversions run strictly on your local machine using private bundled engines and standard system utilities.

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

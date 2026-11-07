#!/usr/bin/env python3
"""
Generate or verify docs/ENGINES.md from Engines/engines.json and engines.lock.json.
This ensures docs/ENGINES.md is always mechanically generated and never hand-edited.
"""

import argparse
import difflib
import json
import os
import sys

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

TOOL_ROLES_AND_LICENSES = {
    "ffmpeg": ("Video & audio conversion, slicing, filtering", "LGPL-2.1-or-later"),
    "ffprobe": ("Video/audio metadata inspection & stream probing", "LGPL-2.1-or-later"),
    "cwebp": ("WebP image encoding", "BSD-3-Clause"),
    "magick": ("Image conversions, transforms, and compression", "ImageMagick"),
    "gs": ("PostScript and PDF processing, compression", "AGPL-3.0-or-later"),
    "qpdf": ("PDF linearization, rotation, encryption, page split", "Apache-2.0"),
    "pdftoppm": ("PDF rasterization to PNG/JPEG", "GPL-2.0-or-later"),
    "pdftotext": ("PDF text extraction", "GPL-2.0-or-later"),
    "exiftool": ("Metadata inspection and EXIF stripping", "GPL-1.0-or-later / Artistic-1.0"),
    "pandoc": ("Document markup conversions (MD/HTML/DOCX/PDF)", "GPL-2.0-or-later"),
    "rsvg-convert": ("SVG vector rendering to PNG/PDF", "LGPL-2.1-or-later"),
    "unar": ("Archive extraction (RAR, 7z, ZIP, TAR, ISO)", "LGPL-2.1-or-later"),
    "7zz": ("7-Zip archive extraction and creation", "LGPL-2.1-or-later"),
    "sips": ("Native image manipulation", "Apple Proprietary"),
    "ditto": ("Native PKZip archive creation", "Apple Proprietary"),
    "tar": ("Native tarball creation and extraction", "BSD-2-Clause"),
    "soffice": ("Office document to PDF conversion", "MPL-2.0"),
    "ebook-convert": ("E-book conversions (EPUB/MOBI/PDF)", "GPL-3.0-only"),
    "avifenc": ("AVIF modern image encoding", "BSD-2-Clause"),
}

PACKAGING_DESCRIPTIONS = {
    "bundled_macho": "Relocatable Mach-O (`bin/{id}`, `@loader_path/../lib`)",
    "bundled_macho_wrapper": "Relocatable Mach-O (`bin/{id}`, `@loader_path/../lib`)",
    "bundled_script": "Relocatable Perl Script (`bin/{id}`, `lib/perl5/`)",
    "system_wrapper": "System Wrapper Script (`bin/{id}` -> `exec /usr/bin/{id} \"$@\"`)",
    "bundled_app": "Bundled App (`{app_name}/Contents/MacOS/{id}`)",
    "cask_wrapper": "Bundled App (`{app_name}/Contents/MacOS/{id}`)",
}

APP_NAMES = {
    "soffice": "LibreOffice.app",
    "ebook-convert": "calibre.app",
}

def load_manifest():
    manifest_paths = [
        os.path.join(REPO_ROOT, "Engines", "engines.json"),
        os.path.join(REPO_ROOT, "Pasta.app", "Contents", "Resources", "Engines", "engines.json"),
    ]
    for p in manifest_paths:
        if os.path.exists(p):
            with open(p, "r", encoding="utf-8") as f:
                return json.load(f)
    return []

def load_lock():
    lock_path = os.path.join(REPO_ROOT, "engines.lock.json")
    if os.path.exists(lock_path):
        with open(lock_path, "r", encoding="utf-8") as f:
            return json.load(f)
    return {}

def generate_markdown(engines, lock):
    lines = [
        "# Pasta Bundled Engines Specification (v1.0.0 — Phase P / Step E1)",
        "",
        "Pasta bundles all conversion and inspection engines in a private, self-contained, relocatable application bundle directory:",
        "`Pasta.app/Contents/Resources/Engines/`",
        "",
        "Engines are **private to the app**:",
        "- Never installed system-wide or on the user's `PATH`.",
        "- Never touching the user's Homebrew, Python, or external environment.",
        "- Dynamic libraries are rewritten with `@loader_path` references so they have **zero** dependencies on `/opt/homebrew` or `/usr/local`.",
        "- Signed with ad-hoc signature and Hardened Runtime (`--options runtime`), using the standard `com.apple.security.cs.disable-library-validation` entitlement for self-contained third-party tool runtimes.",
        "",
        "---",
        "",
        "## 1. Engine Inventory & Pinned Provenance",
        "",
        "| Tool ID | Role & Actions | Pinned Version | Upstream / Package Source | License | Packaging Type |",
        "|---|---|---|---|---|---|",
    ]

    # Map of engines by ID
    engine_map = {e["id"]: e for e in engines}

    # Ensure all 19 tools are listed in canonical order
    canonical_tool_order = [
        "ffmpeg", "ffprobe", "cwebp", "magick", "gs", "qpdf", "pdftoppm", "pdftotext",
        "exiftool", "pandoc", "rsvg-convert", "unar", "7zz", "sips", "ditto", "tar",
        "soffice", "ebook-convert", "avifenc"
    ]

    for tool_id in canonical_tool_order:
        role, license_name = TOOL_ROLES_AND_LICENSES.get(tool_id, ("Tool engine", "UNVERIFIED"))
        entry = engine_map.get(tool_id)
        lock_entry = lock.get(tool_id, {})

        if entry:
            version = entry.get("version", "pinned")
            # Clean version if multi-line
            if "\n" in version:
                version = version.splitlines()[0]
            if len(version) > 40:
                version = version[:37] + "..."

            source_type = entry.get("source", "bundled_macho")
            app_name = APP_NAMES.get(tool_id, f"{tool_id}.app")
            packaging = PACKAGING_DESCRIPTIONS.get(source_type, "Bundled (`bin/{id}`)").format(id=tool_id, app_name=app_name)

            if tool_id in ["sips", "ditto", "tar"]:
                upstream_source = f"macOS System (`/usr/bin/{tool_id}`)"
            elif lock_entry and "url" in lock_entry:
                upstream_source = f"[{lock_entry.get('package', tool_id)}]({lock_entry['url']})"
            else:
                upstream_source = f"Homebrew `{tool_id}` {version}"
        else:
            # Fallback for tools pending bundling (e.g. LibreOffice / Calibre before F3 build)
            if tool_id == "soffice":
                version = "26.8.2"
                upstream_source = "LibreOffice 26.8.2 aarch64"
                packaging = "Bundled App (`LibreOffice.app/Contents/MacOS/soffice`)"
            elif tool_id == "ebook-convert":
                version = "9.18.0"
                upstream_source = "Calibre 9.18.0 aarch64"
                packaging = "Bundled App (`calibre.app/Contents/MacOS/ebook-convert`)"
            else:
                version = "pinned"
                upstream_source = f"Upstream `{tool_id}`"
                packaging = "Bundled Mach-O"

        lines.append(f"| `{tool_id}` | {role} | `{version}` | {upstream_source} | {license_name} | {packaging} |")

    lines.extend([
        "",
        "---",
        "",
        "## 2. Relocation & Hardened Runtime Architecture",
        "",
        "1. **Self-Contained Dynamic Linking (`@loader_path`)**:",
        "   - Every compiled binary in `Engines/bin/` has its external dynamic library dependencies rewritten from `/opt/homebrew/...` or `/usr/local/...` to `@loader_path/../lib/<dylib>`.",
        "   - Every dynamic library in `Engines/lib/` has its install name ID set to `@loader_path/<dylib>` and its dependencies rewritten to `@loader_path/<dep>`.",
        "   - All Homebrew-specific `LC_RPATH` commands are stripped.",
        "   - Result: `otool -L` on any binary or dylib inside `Engines/` reports **zero** references to `/opt/homebrew` or `/usr/local`.",
        "",
        "2. **Code Signing with Hardened Runtime**:",
        "   - Every Mach-O executable and library is signed with:",
        "     `codesign -s - -f --options runtime --entitlements /tmp/pasta_engine_entitlements.plist <path>`",
        "   - Entitlements declare:",
        "     ```xml",
        "     <dict>",
        "         <key>com.apple.security.cs.disable-library-validation</key>",
        "         <true/>",
        "     </dict>",
        "     ```",
        "     This allows relocatable ad-hoc and developer-signed engines to dynamically load their bundled sibling libraries without requiring global system-wide team registration.",
        "",
        "3. **Perl Runtime Isolation (`exiftool`)**:",
        "   - `exiftool` is packaged with its entire Perl module library under `Engines/lib/perl5/`.",
        "   - The script preamble is modified to resolve `$pasta_lib` relative to `$0` (`Engines/bin/../lib/perl5`), ensuring EXIF metadata manipulation runs cleanly with `PATH=/usr/bin:/bin` and without system Perl module pollution.",
        "",
        "4. **Manifest Schema (`engines.json`)**:",
        "   - The manifest file `Pasta.app/Contents/Resources/Engines/engines.json` records:",
        "     - `id`: unique tool identifier matching `ToolLocator`",
        "     - `version`: exact version string extracted via clean-environment execution",
        "     - `sha256`: SHA-256 hash of the executable",
        "     - `size`: file size in bytes",
        "     - `entry_point`: relative path from `Engines/` to the executable",
        "     - `source`: packaging origin (`bundled_macho`, `bundled_script`, `system_wrapper`, `bundled_app`)",
        "",
        "---",
        "",
        "## 3. Generation Invariant",
        "",
        "This file is **MECHANICALLY GENERATED** by `scripts/generate_engines_doc.py` from `Engines/engines.json` and `engines.lock.json`.",
        "CI asserts `python3 scripts/generate_engines_doc.py --check` and will fail if any manual edits deviate from the generated manifest.",
        ""
    ])

    return "\n".join(lines)

def main():
    parser = argparse.ArgumentParser(description="Generate or verify docs/ENGINES.md")
    parser.add_argument("--check", action="store_true", help="Check whether docs/ENGINES.md matches generated content")
    parser.add_argument("--output", default=os.path.join(REPO_ROOT, "docs", "ENGINES.md"), help="Path to write output")
    args = parser.parse_args()

    engines = load_manifest()
    lock = load_lock()
    generated = generate_markdown(engines, lock)

    target_path = os.path.abspath(args.output)

    if args.check:
        if not os.path.exists(target_path):
            print(f"Error: {target_path} does not exist!", file=sys.stderr)
            sys.exit(1)
        with open(target_path, "r", encoding="utf-8") as f:
            existing = f.read()
        if existing != generated:
            print("Error: docs/ENGINES.md does not match generated content!", file=sys.stderr)
            diff = difflib.unified_diff(
                existing.splitlines(keepends=True),
                generated.splitlines(keepends=True),
                fromfile="committed:docs/ENGINES.md",
                tofile="generated:docs/ENGINES.md"
            )
            sys.stderr.writelines(diff)
            sys.exit(1)
        print("✓ docs/ENGINES.md matches generated content exactly.")
    else:
        with open(target_path, "w", encoding="utf-8") as f:
            f.write(generated)
        print(f"✓ Generated {target_path} successfully.")

if __name__ == "__main__":
    main()

#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

APP_PATH="Pasta.app"
THRESHOLD_BYTES=$(( 1932735283 )) # 1.8 GiB = 1.8 * 1024 * 1024 * 1024

# Build app if not present
if [ ! -d "$APP_PATH" ]; then
    echo "Pasta.app not found. Building release bundle..." >&2
    ./scripts/build_app.sh >/dev/null 2>&1
fi

get_size_bytes() {
    local target="$1"
    if [ -e "$target" ]; then
        local kb
        kb=$(du -sk "$target" | awk '{print $1}')
        echo $((kb * 1024))
    else
        echo 0
    fi
}

bytes_to_mb() {
    local bytes="$1"
    python3 -c "print(round($bytes / (1024.0 * 1024.0), 2))"
}

TOTAL_BYTES=$(get_size_bytes "$APP_PATH")
TOTAL_MB=$(bytes_to_mb "$TOTAL_BYTES")

MACOS_BIN="$APP_PATH/Contents/MacOS/Pasta"
BIN_BYTES=$(get_size_bytes "$MACOS_BIN")
BIN_MB=$(bytes_to_mb "$BIN_BYTES")

ENGINES_DIR="$APP_PATH/Contents/Resources/Engines"
ENGINES_BYTES=$(get_size_bytes "$ENGINES_DIR")
ENGINES_MB=$(bytes_to_mb "$ENGINES_BYTES")

LICENSES_DIR="$APP_PATH/Contents/Resources/Licenses"
LICENSES_BYTES=$(get_size_bytes "$LICENSES_DIR")
LICENSES_MB=$(bytes_to_mb "$LICENSES_BYTES")

FRAMEWORK_STATIC_BIN=".build/release/PastaCore.build"
if [ ! -e "$FRAMEWORK_STATIC_BIN" ] && [ -d ".build/arm64-apple-macosx/release/PastaCore.build" ]; then
    FRAMEWORK_STATIC_BIN=".build/arm64-apple-macosx/release/PastaCore.build"
fi
CORE_BYTES=$(get_size_bytes "$FRAMEWORK_STATIC_BIN")
CORE_MB=$(bytes_to_mb "$CORE_BYTES")

# Locate release archive if present
RELEASE_ARCHIVE=""
for candidate in "Pasta-macOS.zip" "Pasta.zip" "Pasta.dmg" "Pasta-macOS-Release.zip"; do
    if [ -f "$candidate" ]; then
        RELEASE_ARCHIVE="$candidate"
        break
    fi
done

RELEASE_BYTES=0
RELEASE_MB="0.0"
if [ -n "$RELEASE_ARCHIVE" ]; then
    RELEASE_BYTES=$(get_size_bytes "$RELEASE_ARCHIVE")
    RELEASE_MB=$(bytes_to_mb "$RELEASE_BYTES")
fi

# Size guard warning check (Warning only, never fail build)
WARNING_MSG=""
if [ "$RELEASE_BYTES" -gt "$THRESHOLD_BYTES" ]; then
    WARNING_MSG="WARNING: Release archive '$RELEASE_ARCHIVE' size (${RELEASE_MB} MB) exceeds 1.8 GiB threshold!"
elif [ "$TOTAL_BYTES" -gt "$THRESHOLD_BYTES" ]; then
    WARNING_MSG="WARNING: Application bundle size (${TOTAL_MB} MB) exceeds 1.8 GiB threshold!"
fi

# Generate Python helper for JSON and engine table
PY_REPORT_SCRIPT=$(cat << 'PYEOF'
import json
import os
import sys

repo_root = sys.argv[1]
app_path = sys.argv[2]
total_bytes = int(sys.argv[3])
total_mb = float(sys.argv[4])
bin_bytes = int(sys.argv[5])
bin_mb = float(sys.argv[6])
engines_bytes = int(sys.argv[7])
engines_mb = float(sys.argv[8])
licenses_bytes = int(sys.argv[9])
licenses_mb = float(sys.argv[10])
core_bytes = int(sys.argv[11])
core_mb = float(sys.argv[12])
release_archive = sys.argv[13]
release_bytes = int(sys.argv[14])
release_mb = float(sys.argv[15])
as_json = (sys.argv[16] == "--json")
warning_msg = sys.argv[17]

engines_json_path = os.path.join(repo_root, "Engines", "engines.json")
engine_entries = []

def get_dir_size_bytes(path):
    if not os.path.exists(path):
        return 0
    total = 0
    if os.path.islink(path):
        return os.path.getsize(path)
    if os.path.isfile(path):
        return os.path.getsize(path)
    for root, dirs, files in os.walk(path):
        for f in files:
            fp = os.path.join(root, f)
            if not os.path.islink(fp) and os.path.exists(fp):
                total += os.path.getsize(fp)
    return total

if os.path.exists(engines_json_path):
    with open(engines_json_path, "r", encoding="utf-8") as f:
        catalog = json.load(f)
    tools = catalog if isinstance(catalog, list) else catalog.get("engines", [])
    for tool in tools:
        t_id = tool.get("id", "")
        t_name = tool.get("name", t_id)
        entry_pt = tool.get("entry_point", f"bin/{t_id}")
        # Search path in app bundle
        candidate_paths = [
            os.path.join(app_path, "Contents", "Resources", "Engines", entry_pt),
            os.path.join(app_path, "Contents", "Resources", "Engines", "bin", t_id),
            os.path.join(app_path, "Contents", "Resources", "Engines", f"{t_name}.app"),
            os.path.join(app_path, "Contents", "Resources", "Engines", f"{t_id}.app"),
            os.path.join(app_path, "Contents", "Resources", "Engines", "bin", f"{t_id}-bin")
        ]
        found_path = ""
        sz_bytes = 0
        for cp in candidate_paths:
            if os.path.exists(cp):
                found_path = os.path.relpath(cp, repo_root)
                sz_bytes = get_dir_size_bytes(cp)
                break
        if not found_path:
            found_path = f"Contents/Resources/Engines/{entry_pt}"
            sz_bytes = 0

        engine_entries.append({
            "id": t_id,
            "name": t_name,
            "path": found_path,
            "size_bytes": sz_bytes,
            "size_mb": round(sz_bytes / (1024.0 * 1024.0), 2)
        })

if as_json:
    out = {
        "total_bundle_size_bytes": total_bytes,
        "total_bundle_size_mb": total_mb,
        "binary_size_bytes": bin_bytes,
        "binary_size_mb": bin_mb,
        "engines_size_bytes": engines_bytes,
        "engines_size_mb": engines_mb,
        "licenses_size_bytes": licenses_bytes,
        "licenses_size_mb": licenses_mb,
        "core_framework_size_bytes": core_bytes,
        "core_framework_size_mb": core_mb,
        "release_archive": release_archive if release_archive else None,
        "release_archive_size_bytes": release_bytes,
        "release_archive_size_mb": release_mb,
        "warning": warning_msg if warning_msg else None,
        "engines": engine_entries
    }
    print(json.dumps(out, indent=2))
    sys.exit(0)

# Markdown table output
lines = []
lines.append("# Pasta Application & Component Size Report")
lines.append("")
lines.append("- **Date:** " + os.popen("date -u +'%Y-%m-%d %H:%M:%SZ'").read().strip())
lines.append(f"- **Target Bundle:** `{app_path}`")
lines.append(f"- **Total Bundle Size:** {total_mb} MB ({total_bytes} bytes)")
lines.append(f"- **Release Archive:** `{release_archive or 'None'}` ({release_mb} MB)")
lines.append("- **Size Policy:** Report-only (owner decision: no size limit in the first build)")
if warning_msg:
    lines.append(f"- **Warning:** ⚠️ {warning_msg}")
lines.append("")
lines.append("### Bundle Component Overview")
lines.append("")
lines.append("| Component | Path | Size (Bytes) | Size (MB) |")
lines.append("| :--- | :--- | :--- | :--- |")
lines.append(f"| **Total Pasta.app Bundle** | `{app_path}` | {total_bytes} | {total_mb} MB |")
lines.append(f"| App Executable Binary | `Contents/MacOS/Pasta` | {bin_bytes} | {bin_mb} MB |")
lines.append(f"| Relocatable Bundled Engines (Total) | `Contents/Resources/Engines` | {engines_bytes} | {engines_mb} MB |")
lines.append(f"| Third-Party Engine Licenses | `Contents/Resources/Licenses` | {licenses_bytes} | {licenses_mb} MB |")
lines.append(f"| Core Framework Build | `PastaCore.build` | {core_bytes} | {core_mb} MB |")
if release_archive:
    lines.append(f"| Release Archive (Zip/DMG) | `{release_archive}` | {release_bytes} | {release_mb} MB |")
else:
    lines.append("| Release Archive (Zip/DMG) | *(not packaged)* | 0 | 0.00 MB |")

lines.append("")
lines.append("### Bundled Engines Detail Breakdown")
lines.append("")
lines.append("| Engine | Relative Path | Size (Bytes) | Size (MB) |")
lines.append("| :--- | :--- | :--- | :--- |")
for eng in engine_entries:
    lines.append(f"| {eng['name']} (`{eng['id']}`) | `{eng['path']}` | {eng['size_bytes']} | {eng['size_mb']} MB |")

lines.append("")
lines.append("### Policy & Threshold Assessment")
lines.append("Per owner decision, size is strictly report-only with no hard failure limit for the first build.")
if warning_msg:
    lines.append(f"⚠️ **Notice:** {warning_msg}")
else:
    lines.append("✅ Bundle and archive remain well within GitHub Release asset threshold (1.8 GiB warning ceiling).")

report_content = "\n".join(lines) + "\n"
print(report_content)

report_path = os.path.join(repo_root, "docs", "SIZE_REPORT.md")
with open(report_path, "w", encoding="utf-8") as rf:
    rf.write(report_content)
PYEOF
)

IS_JSON="${1:-}"
if [ "$IS_JSON" = "--json" ]; then
    python3 -c "$PY_REPORT_SCRIPT" "$REPO_ROOT" "$APP_PATH" "$TOTAL_BYTES" "$TOTAL_MB" "$BIN_BYTES" "$BIN_MB" "$ENGINES_BYTES" "$ENGINES_MB" "$LICENSES_BYTES" "$LICENSES_MB" "$CORE_BYTES" "$CORE_MB" "$RELEASE_ARCHIVE" "$RELEASE_BYTES" "$RELEASE_MB" "--json" "$WARNING_MSG"
    exit 0
fi

python3 -c "$PY_REPORT_SCRIPT" "$REPO_ROOT" "$APP_PATH" "$TOTAL_BYTES" "$TOTAL_MB" "$BIN_BYTES" "$BIN_MB" "$ENGINES_BYTES" "$ENGINES_MB" "$LICENSES_BYTES" "$LICENSES_MB" "$CORE_BYTES" "$CORE_MB" "$RELEASE_ARCHIVE" "$RELEASE_BYTES" "$RELEASE_MB" "" "$WARNING_MSG"

if [ -n "$WARNING_MSG" ]; then
    echo "$WARNING_MSG" >&2
fi

echo ""
echo "Size report saved to docs/SIZE_REPORT.md"
exit 0

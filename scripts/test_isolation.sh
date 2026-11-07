#!/bin/bash
# scripts/test_isolation.sh
# Phase P — Step E2: Clean-Machine & Environment Isolation Verification
# Tests clean PATH, link check (otool -L), hostile environment, and private office profiles.

set -euo pipefail

cd "$(dirname "$0")/.."

echo "=================================================="
echo "Pasta Step E2: Clean-Machine & Isolation Test"
echo "=================================================="

# 1. Build Pasta.app if not already present
if [ ! -d "Pasta.app" ]; then
    echo "==> Building Pasta.app for isolation testing..."
    ./scripts/build_app.sh
fi

ENGINES_DIR="Pasta.app/Contents/Resources/Engines"
if [ ! -d "$ENGINES_DIR" ]; then
    echo "ERROR: Bundled engines directory not found at $ENGINES_DIR"
    exit 1
fi

# 2. Link Check (otool -L)
echo ""
echo "--- 1. Mach-O Link Check (otool -L) ---"
python3 - << 'EOF'
import os
import subprocess
import re
import sys

engines_dir = "Pasta.app/Contents/Resources/Engines"
disallowed = ["/opt/homebrew", "/usr/local", "/Users/"]
allowed_prefixes = [
    "@loader_path/",
    "@executable_path/",
    "@rpath/",
    "@__________________________________________________",
    "/@.__________________________________________________",
    "/usr/lib/",
    "/System/Library/"
]

violations = []
checked = 0

for root, dirs, files in os.walk(engines_dir):
    for f in files:
        fp = os.path.join(root, f)
        if os.path.islink(fp):
            continue
        try:
            with open(fp, "rb") as probe:
                magic = probe.read(4)
                if magic not in [
                    b"\xfe\xed\xfa\xce", b"\xce\xfa\xed\xfe",
                    b"\xfe\xed\xfa\xcf", b"\xcf\xfa\xed\xfe",
                    b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca"
                ]:
                    continue
        except Exception:
            continue

        checked += 1
        res = subprocess.run(["otool", "-L", fp], capture_output=True, text=True)
        lines = res.stdout.strip().split("\n")[1:]
        for line in lines:
            line = line.strip()
            if not line:
                continue
            m = re.match(r"^(\S+)", line)
            if not m:
                continue
            dep = m.group(1)
            for bad in disallowed:
                if bad in dep:
                    violations.append((fp, dep))
            if not any(dep.startswith(p) for p in allowed_prefixes):
                violations.append((fp, dep))

print(f"Checked {checked} Mach-O binaries and dylibs.")
if violations:
    print(f"FAILED: Found {len(violations)} disallowed dynamic library references:")
    for v in violations[:10]:
        print(f"  {v[0]} -> {v[1]}")
    sys.exit(1)

print("✓ PASS: 100% of bundled Mach-O files reference only relative @loader_path or system frameworks.")
EOF

# 3. Hostile Environment Setup
echo ""
echo "--- 2. Hostile Environment Setup ---"
HOSTILE_DIR="/tmp/pasta_isolation_test_$$"
mkdir -p "$HOSTILE_DIR/bin" "$HOSTILE_DIR/dyld" "$HOSTILE_DIR/python" "$HOSTILE_DIR/perl"

cat << 'EOF' > "$HOSTILE_DIR/bin/python3"
#!/bin/sh
echo "POISON PYTHON ACCESSED" >&2
exit 1
EOF
chmod +x "$HOSTILE_DIR/bin/python3"

# Verify poison python intercepts unqualified python3
POISON_OUTPUT=$(PATH="$HOSTILE_DIR/bin:/usr/bin:/bin" python3 --version 2>&1 || true)
if echo "$POISON_OUTPUT" | grep -q "POISON PYTHON ACCESSED"; then
    echo "✓ Hostile poison python3 active in PATH"
else
    echo "WARNING: Failed to activate hostile python stub"
fi

# 4. Clean PATH & Hostile Environment Conversion Suite
echo ""
echo "--- 3. Clean PATH & Hostile Environment Execution ---"
PATH="$HOSTILE_DIR/bin:/usr/bin:/bin" \
DYLD_LIBRARY_PATH="$HOSTILE_DIR/dyld" \
PYTHONPATH="$HOSTILE_DIR/python" \
PERL5LIB="$HOSTILE_DIR/perl" \
PASTA_BIN="Pasta.app/Contents/MacOS/Pasta" \
./scripts/run_section8_tests.sh

# 5. Clean up hostile scratch
rm -rf "$HOSTILE_DIR"

echo ""
echo "=================================================="
echo "Step E2 Isolation Verification Completed Successfully"
echo "=================================================="

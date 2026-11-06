#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$#" -eq 0 ]; then
    python3 "$SCRIPT_DIR/bundle_mach_o.py" "Pasta.app/Contents/Resources/Engines"
else
    python3 "$SCRIPT_DIR/bundle_mach_o.py" "$@"
fi

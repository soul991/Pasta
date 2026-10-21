#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=========================================="
echo "Installing Pasta File Converter for macOS"
echo "=========================================="

echo "1. Building Pasta.app bundle..."
./scripts/build_app.sh

TARGET_APP="/Applications/Pasta.app"
USER_APP="$HOME/Applications/Pasta.app"

INSTALL_PATH="$TARGET_APP"
if [ ! -w "/Applications" ]; then
    mkdir -p "$HOME/Applications"
    INSTALL_PATH="$USER_APP"
fi

echo "2. Installing Pasta.app to $INSTALL_PATH..."
rm -rf "$INSTALL_PATH"
cp -R "Pasta.app" "$INSTALL_PATH"

echo "3. Installing Finder Quick Action..."
./scripts/install_quick_action.sh

echo "=========================================="
echo "Pasta successfully installed to: $INSTALL_PATH"
echo "Finder Quick Action: Installed"
echo "Log file location: ~/Library/Logs/Pasta/pasta.log"
echo "=========================================="

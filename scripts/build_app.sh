#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Building Pasta in release configuration..."
swift build -c release

APP_DIR="Pasta.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "Creating application bundle structure at $APP_DIR..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp .build/release/Pasta "$MACOS_DIR/Pasta"
chmod +x "$MACOS_DIR/Pasta"

echo "Generating Info.plist..."
cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Pasta</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.pasta</string>
    <key>CFBundleName</key>
    <string>Pasta</string>
    <key>CFBundleDisplayName</key>
    <string>Pasta</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "Signing application bundle with stable designated requirement..."
codesign --force --deep -s - -r='designated => identifier "com.local.pasta"' "$APP_DIR"

echo "Verifying code signature..."
codesign -v "$APP_DIR"

echo "Pasta.app built and signed successfully at: $(pwd)/$APP_DIR"

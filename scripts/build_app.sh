#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Building Peel in release configuration..."
swift build -c release

APP_DIR="Peel.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "Creating application bundle structure at $APP_DIR..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp .build/release/Peel "$MACOS_DIR/Peel"
chmod +x "$MACOS_DIR/Peel"

echo "Generating Info.plist..."
cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Peel</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.peel</string>
    <key>CFBundleName</key>
    <string>Peel</string>
    <key>CFBundleDisplayName</key>
    <string>Peel</string>
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
codesign --force --deep -s - -r='designated => identifier "com.local.peel"' "$APP_DIR"

echo "Verifying code signature..."
codesign -v "$APP_DIR"

echo "Peel.app built and signed successfully at: $(pwd)/$APP_DIR"

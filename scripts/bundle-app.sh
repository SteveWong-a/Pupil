#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_CONFIG="${1:-release}"

echo "==> Building Pupil (${BUILD_CONFIG})..."
cd "${PROJECT_DIR}"
swift build -c "${BUILD_CONFIG}"

BIN_PATH="$(swift build -c "${BUILD_CONFIG}" --show-bin-path)/Pupil"
APP_BUNDLE="${PROJECT_DIR}/dist/Pupil.app"

rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Generate retina AppIcon.icns if needed
if [[ ! -f "${PROJECT_DIR}/Resources/AppIcon.icns" ]]; then
    echo "==> Generating AppIcon.icns..."
    swift "${PROJECT_DIR}/scripts/generate-icon.swift"
fi
cp "${PROJECT_DIR}/Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"

cp "${BIN_PATH}" "${APP_BUNDLE}/Contents/MacOS/Pupil"
chmod +x "${APP_BUNDLE}/Contents/MacOS/Pupil"

cat > "${APP_BUNDLE}/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Pupil</string>
    <key>CFBundleIdentifier</key>
    <string>com.pupil.security</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Pupil</string>
    <key>CFBundleDisplayName</key>
    <string>Pupil</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.1</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSCameraUsageDescription</key>
    <string>Pupil uses your camera on-device via Apple Vision to detect sustained gaze toward your screen while armed. Frames are processed in memory and never saved.</string>
    <key>NSCameraUseContinuityCameraDeviceType</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "${APP_BUNDLE}" >/dev/null 2>&1 || true

echo "==> Successfully bundled: ${APP_BUNDLE}"
echo "    Launch app: open \"${APP_BUNDLE}\""

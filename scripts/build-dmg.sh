#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${PROJECT_DIR}/dist"
APP_BUNDLE="${DIST_DIR}/Pupil.app"
DMG_PATH="${DIST_DIR}/Pupil.dmg"
ZIP_PATH="${DIST_DIR}/Pupil.zip"

echo "==> Building and bundling Pupil.app (release)..."
"${SCRIPT_DIR}/bundle-app.sh" release

echo "==> Packaging Pupil.dmg (macOS Drag & Drop Installer)..."
rm -f "${DMG_PATH}"

DMG_STAGING="$(mktemp -d /tmp/pupil-dmg-staging-XXXXXX)"
trap 'rm -rf "${DMG_STAGING}"' EXIT

cp -R "${APP_BUNDLE}" "${DMG_STAGING}/Pupil.app"
ln -s /Applications "${DMG_STAGING}/Applications"

# Strip quarantine and extended attributes from staging
xattr -cr "${DMG_STAGING}/Pupil.app" 2>/dev/null || true

hdiutil create \
  -volname "Pupil Installer" \
  -srcfolder "${DMG_STAGING}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"

echo "==> Packaging Pupil.zip..."
rm -f "${ZIP_PATH}"
(cd "${DIST_DIR}" && zip -q -r -y "Pupil.zip" "Pupil.app")

echo "==> Computing SHA-256 checksums..."
(cd "${DIST_DIR}" && shasum -a 256 "Pupil.dmg" > "Pupil.dmg.sha256")
(cd "${DIST_DIR}" && shasum -a 256 "Pupil.zip" > "Pupil.zip.sha256")

echo "==> Single downloadable app packaging complete:"
echo "    DMG: ${DMG_PATH} ($(du -sh "${DMG_PATH}" | cut -f1))"
echo "    ZIP: ${ZIP_PATH} ($(du -sh "${ZIP_PATH}" | cut -f1))"


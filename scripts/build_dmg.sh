#!/usr/bin/env bash
#
# build_dmg.sh -- package build/Release/AISwitch.app into a distributable
# disk image at dist/AISwitch-<version>.dmg.
#
# Strategy:
#   1. Make sure the .app exists (build it if not).
#   2. Prefer `create-dmg` (homebrew) for a Finder-window layout with a
#      drag-to-Applications shortcut. Fall back to `hdiutil` if create-dmg
#      isn't installed.
#
# For PERSONAL USE on your own Mac the ad-hoc-signed DMG produced by
# scripts/build_release.sh is enough -- Gatekeeper will prompt the first
# time you launch from /Applications and you click Open.
#
# To SHARE with coworkers without the warning, you need:
#   1. A "Developer ID Application" certificate in your Keychain.
#   2. Re-run build_release.sh with `DEVELOPER_ID="Developer ID Application: ..."`.
#   3. Notarize the resulting DMG via `xcrun notarytool submit ... --wait`
#      and `xcrun stapler staple AISwitch.dmg`.
# See README.md -> "Building a sharable installer" for the full recipe.
#
# Usage:
#   bash scripts/build_dmg.sh

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

APP_NAME="AISwitch"
APP_PATH="${ROOT}/build/Release/${APP_NAME}.app"
DIST_DIR="${ROOT}/dist"
mkdir -p "$DIST_DIR"

# 1. Always re-build if EITHER:
#    - the .app doesn't exist
#    - any source file or project.yml is newer than the .app
# This avoids shipping a stale bundle that doesn't include recent edits
# (the failure mode we hit when localization resources didn't propagate).
needs_rebuild=false
if [[ ! -d "$APP_PATH" ]]; then
    needs_rebuild=true
else
    # newest source file vs the .app's executable mtime
    NEWEST_SRC=$(find "$ROOT/Sources" "$ROOT/Resources" "$ROOT/project.yml" \
                      -type f \( -newer "$APP_PATH/Contents/MacOS/${APP_NAME}" \) \
                      -print -quit 2>/dev/null || true)
    if [[ -n "$NEWEST_SRC" ]]; then
        echo "Sources newer than build (${NEWEST_SRC}); rebuilding..."
        needs_rebuild=true
    fi
fi

if $needs_rebuild; then
    bash "$ROOT/scripts/build_release.sh"
fi

# 2. Verify the bundle is well-formed before we wrap it in a DMG.
LPROJ_COUNT=$(find "$APP_PATH/Contents/Resources" -name "*.lproj" -type d 2>/dev/null | wc -l | tr -d ' ')
STRINGS_COUNT=$(find "$APP_PATH/Contents/Resources" -name "Localizable.strings" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$LPROJ_COUNT" -lt 2 || "$STRINGS_COUNT" -lt 2 ]]; then
    echo "[FAIL] ${APP_PATH} is missing localization resources." >&2
    echo "       (.lproj=${LPROJ_COUNT}, .strings=${STRINGS_COUNT})" >&2
    echo "       Refusing to package a broken bundle into a DMG." >&2
    exit 1
fi

# 3. Read version from Info.plist.
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
              "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "0.1.0")
DMG_OUT="${DIST_DIR}/${APP_NAME}-${VERSION}.dmg"
rm -f "$DMG_OUT"

# 4. Prefer create-dmg.
if command -v create-dmg >/dev/null 2>&1; then
    echo "Building DMG with create-dmg..."
    create-dmg \
        --volname "$APP_NAME" \
        --window-pos 200 120 \
        --window-size 540 360 \
        --icon-size 100 \
        --icon "${APP_NAME}.app" 130 180 \
        --hide-extension "${APP_NAME}.app" \
        --app-drop-link 410 180 \
        --no-internet-enable \
        "$DMG_OUT" \
        "$APP_PATH"
else
    echo "create-dmg not installed; falling back to hdiutil layout."
    STAGING="$(mktemp -d)"
    cp -R "$APP_PATH" "$STAGING/"
    ln -s /Applications "$STAGING/Applications"
    hdiutil create \
        -volname "$APP_NAME" \
        -srcfolder "$STAGING" \
        -ov \
        -format UDZO \
        "$DMG_OUT"
    rm -rf "$STAGING"
fi

echo
echo "[ok] Built ${DMG_OUT}"
ls -lh "$DMG_OUT"

# 5. (Optional) sign the DMG itself with Developer ID for sharing.
if [[ -n "${DEVELOPER_ID:-}" ]]; then
    echo
    echo "Signing DMG with: ${DEVELOPER_ID}"
    codesign --sign "$DEVELOPER_ID" --timestamp "$DMG_OUT"
    echo "[ok] DMG signed. To notarize:"
    echo "    xcrun notarytool submit \"$DMG_OUT\" --keychain-profile <profile> --wait"
    echo "    xcrun stapler staple \"$DMG_OUT\""
fi

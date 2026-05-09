#!/usr/bin/env bash
#
# build_dmg.sh -- package build/Release/AISwitch.app into a distributable
# disk image at dist/AISwitch-<version>.dmg.
#
# Strategy:
#   1. Make sure the .app exists (build it if not, or rebuild if stale).
#   2. Verify the bundle has localization + binary before packaging.
#   3. Prefer `create-dmg` (homebrew) for a Finder-window layout with a
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
APP_BIN="${APP_PATH}/Contents/MacOS/${APP_NAME}"
DIST_DIR="${ROOT}/dist"
mkdir -p "$DIST_DIR"

# ------------------------------------------------------------------
# 1. Decide whether to rebuild
# ------------------------------------------------------------------
# Rules:
#   - .app missing or executable missing -> rebuild
#   - project.yml newer than executable -> rebuild
#   - any file in Sources/ or Resources/ newer than executable -> rebuild
#
# Wrapping the staleness check in a function isolates `find` failures
# from `set -e` and keeps the main flow readable.
needs_rebuild() {
    if [[ ! -d "$APP_PATH" || ! -f "$APP_BIN" ]]; then
        return 0
    fi
    if [[ "$ROOT/project.yml" -nt "$APP_BIN" ]]; then
        echo "project.yml is newer than the existing build."
        return 0
    fi
    local newer
    # `|| true` swallows the case where one of the search roots is missing
    # (e.g. Resources/ deleted); we still want a clean answer.
    newer=$(find "$ROOT/Sources" "$ROOT/Resources" \
                 -type f -newer "$APP_BIN" -print 2>/dev/null \
              | head -1 || true)
    if [[ -n "$newer" ]]; then
        echo "Source/resource newer than build: $newer"
        return 0
    fi
    return 1
}

if needs_rebuild; then
    echo "Rebuilding ${APP_NAME}.app..."
    bash "$ROOT/scripts/build_release.sh"
else
    echo "Using existing ${APP_PATH}"
fi

# ------------------------------------------------------------------
# 2. Sanity-check the bundle before we wrap it
# ------------------------------------------------------------------
if [[ ! -f "$APP_BIN" ]]; then
    echo "[FAIL] Mach-O binary missing at ${APP_BIN}" >&2
    exit 1
fi

LPROJ_COUNT=$(find "$APP_PATH/Contents/Resources" -name "*.lproj" -type d 2>/dev/null \
                | wc -l | tr -d ' ')
STRINGS_COUNT=$(find "$APP_PATH/Contents/Resources" -name "Localizable.strings" 2>/dev/null \
                  | wc -l | tr -d ' ')
if [[ "$LPROJ_COUNT" -lt 2 || "$STRINGS_COUNT" -lt 2 ]]; then
    echo "[FAIL] ${APP_PATH} is missing localization resources." >&2
    echo "       (.lproj=${LPROJ_COUNT}, .strings=${STRINGS_COUNT})" >&2
    echo "       Refusing to package a broken bundle into a DMG." >&2
    echo "       Try:  rm -rf AISwitch.xcodeproj build && bash scripts/build_release.sh" >&2
    exit 1
fi

# ------------------------------------------------------------------
# 3. Read version + build the DMG
# ------------------------------------------------------------------
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
              "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "0.1.0")
DMG_OUT="${DIST_DIR}/${APP_NAME}-${VERSION}.dmg"
rm -f "$DMG_OUT"

# A previous failed run can leave a stale "AISwitch" volume mounted, which
# makes create-dmg fail trying to attach a new one with the same name.
# Detach any leftover before we start.
for mount in /Volumes/${APP_NAME}*; do
    if [[ -d "$mount" ]]; then
        echo "Detaching stale volume: $mount"
        hdiutil detach "$mount" -force 2>/dev/null || true
    fi
done

# hdiutil-based DMG construction. Reliable, no dependencies, but plain
# layout (no Finder window customization).
build_with_hdiutil() {
    echo "Building DMG with hdiutil..."
    local staging
    staging="$(mktemp -d)"
    cp -R "$APP_PATH" "$staging/"
    ln -s /Applications "$staging/Applications"
    hdiutil create \
        -volname "$APP_NAME" \
        -srcfolder "$staging" \
        -ov \
        -format UDZO \
        "$DMG_OUT"
    rm -rf "$staging"
}

# Try create-dmg first (nicer Finder layout), but fall back to hdiutil
# if it fails OR doesn't produce the expected output. create-dmg can fail
# on benign issues (cosmetic icon placement, AppleScript quirks under
# headless sessions, leftover volumes, etc.).
if command -v create-dmg >/dev/null 2>&1; then
    echo "Building DMG with create-dmg..."
    if create-dmg \
        --volname "$APP_NAME" \
        --window-pos 200 120 \
        --window-size 540 360 \
        --icon-size 100 \
        --icon "${APP_NAME}.app" 130 180 \
        --hide-extension "${APP_NAME}.app" \
        --app-drop-link 410 180 \
        --no-internet-enable \
        "$DMG_OUT" \
        "$APP_PATH" \
       && [[ -f "$DMG_OUT" ]]; then
        echo "  [ok] create-dmg produced ${DMG_OUT}"
    else
        echo "  [warn] create-dmg failed or produced no output."
        echo "         Falling back to hdiutil (plainer layout)."
        rm -f "$DMG_OUT"
        # In case create-dmg left a half-finished volume mounted:
        for mount in /Volumes/${APP_NAME}*; do
            [[ -d "$mount" ]] && hdiutil detach "$mount" -force 2>/dev/null || true
        done
        build_with_hdiutil
    fi
else
    echo "create-dmg not installed; using hdiutil."
    echo "  (For a nicer Finder window: brew install create-dmg)"
    build_with_hdiutil
fi

if [[ ! -f "$DMG_OUT" ]]; then
    echo "[FAIL] No DMG produced at ${DMG_OUT}" >&2
    exit 1
fi

echo
echo "[ok] Built ${DMG_OUT}"
ls -lh "$DMG_OUT"

# ------------------------------------------------------------------
# 4. (Optional) sign the DMG itself with Developer ID for sharing
# ------------------------------------------------------------------
if [[ -n "${DEVELOPER_ID:-}" ]]; then
    echo
    echo "Signing DMG with: ${DEVELOPER_ID}"
    codesign --sign "$DEVELOPER_ID" --timestamp "$DMG_OUT"
    echo "[ok] DMG signed. To notarize:"
    echo "    xcrun notarytool submit \"$DMG_OUT\" --keychain-profile <profile> --wait"
    echo "    xcrun stapler staple \"$DMG_OUT\""
fi

echo
echo "Done. Test on a fresh user account or another Mac:"
echo "    open \"$DMG_OUT\""

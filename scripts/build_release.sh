#!/usr/bin/env bash
#
# build_release.sh -- produce a Release-configuration .app bundle at
#   build/Release/AISwitch.app
#
# Defaults to ad-hoc code signing ("-"), which is fine for installing on
# YOUR OWN Mac. To share with coworkers without Gatekeeper warnings,
# either:
#   1. Set DEVELOPER_ID env var to "Developer ID Application: Your Name (TEAMID)"
#      and re-run, or
#   2. Open AISwitch.xcodeproj in Xcode and sign with your team there.
#
# Usage:
#   bash scripts/build_release.sh
#   DEVELOPER_ID="Developer ID Application: ..." bash scripts/build_release.sh

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

PROJECT="$ROOT/AISwitch.xcodeproj"
SCHEME="AISwitch"
CONFIG="Release"
APP_NAME="AISwitch"
BUILD_DIR="$ROOT/build"
DERIVED_DATA="$BUILD_DIR/DerivedData"
PRODUCTS_DIR="$BUILD_DIR/$CONFIG"
BUILT_APP_PATH="$DERIVED_DATA/Build/Products/$CONFIG/$APP_NAME.app"
FINAL_APP_PATH="$PRODUCTS_DIR/$APP_NAME.app"

# Re-generate project whenever project.yml is newer than the generated
# .xcodeproj (or the project doesn't exist yet). Without this, edits to
# project.yml -- e.g. adding a new resource folder -- won't propagate to
# builds and you'll be debugging "missing localization" or "missing icon"
# bugs that are actually stale-project bugs.
needs_regen=false
if [[ ! -d "$PROJECT" ]]; then
    needs_regen=true
elif [[ "$ROOT/project.yml" -nt "$PROJECT/project.pbxproj" ]]; then
    needs_regen=true
fi

if $needs_regen; then
    if ! command -v xcodegen >/dev/null 2>&1; then
        echo "xcodegen not installed. Run scripts/setup.sh first." >&2
        exit 1
    fi
    echo "Regenerating AISwitch.xcodeproj from project.yml..."
    xcodegen generate
fi

mkdir -p "$BUILD_DIR" "$PRODUCTS_DIR"
rm -rf "$FINAL_APP_PATH"

# Signing identity. Default = ad-hoc.
SIGN_IDENTITY="${DEVELOPER_ID:-}"
if [[ -z "$SIGN_IDENTITY" ]]; then
    SIGN_IDENTITY="-"
    SIGN_STYLE="ad-hoc"
else
    SIGN_STYLE="Developer ID"
fi

echo "Building ${SCHEME} (${CONFIG}, ${SIGN_STYLE} signing)..."
echo

# Run xcodebuild WITHOUT xcpretty piping -- we want the raw output and a real
# exit code if anything goes wrong. INFOPLIST_EXPAND_BUILD_SETTINGS=YES is the
# default but we set it explicitly here so any future toolchain quirk doesn't
# silently break Info.plist substitution.
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=YES \
    DEVELOPMENT_TEAM="" \
    INFOPLIST_EXPAND_BUILD_SETTINGS=YES \
    clean build

if [[ ! -d "$BUILT_APP_PATH" ]]; then
    echo "Build did not produce ${BUILT_APP_PATH}." >&2
    exit 1
fi

cp -R "$BUILT_APP_PATH" "$FINAL_APP_PATH"

# ------------------------------------------------------------------
# Sanity-check the built bundle so we don't ship something macOS will
# refuse to open with the famously useless "may be damaged or incomplete"
# error. The three failure modes that produce that message are:
#   1. CFBundleExecutable points to a name that doesn't exist in MacOS/
#   2. The Mach-O binary is missing entirely
#   3. The code signature is invalid
# ------------------------------------------------------------------

echo
echo "Verifying ${FINAL_APP_PATH}..."

EXECUTABLE_NAME=$(/usr/libexec/PlistBuddy \
    -c "Print :CFBundleExecutable" \
    "$FINAL_APP_PATH/Contents/Info.plist")

if [[ "$EXECUTABLE_NAME" == "\$"* || "$EXECUTABLE_NAME" == *"\$"* ]]; then
    echo "  [FAIL] CFBundleExecutable is unsubstituted: '${EXECUTABLE_NAME}'" >&2
    echo "         Info.plist build-setting expansion didn't run." >&2
    exit 1
fi

EXECUTABLE_PATH="$FINAL_APP_PATH/Contents/MacOS/$EXECUTABLE_NAME"
if [[ ! -x "$EXECUTABLE_PATH" ]]; then
    echo "  [FAIL] Executable not found: $EXECUTABLE_PATH" >&2
    exit 1
fi

if ! codesign --verify --no-strict "$FINAL_APP_PATH" 2>/dev/null; then
    echo "  [warn] codesign --verify reported issues. Re-signing ad-hoc..."
    codesign --force --deep --sign "$SIGN_IDENTITY" "$FINAL_APP_PATH"
    codesign --verify --no-strict "$FINAL_APP_PATH"
fi

# Verify localization resources made it into the bundle. If en.lproj or
# vi.lproj is missing, the app will silently fall back to raw key strings
# (e.g. "menu.settings" instead of "Settings...") -- exactly the bug we
# kept catching on the .xcodeproj-not-regenerated codepath.
LPROJ_COUNT=$(find "$FINAL_APP_PATH/Contents/Resources" -name "*.lproj" -type d 2>/dev/null | wc -l | tr -d ' ')
STRINGS_COUNT=$(find "$FINAL_APP_PATH/Contents/Resources" -name "Localizable.strings" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$LPROJ_COUNT" -lt 2 || "$STRINGS_COUNT" -lt 2 ]]; then
    echo "  [FAIL] Localization resources missing from bundle." >&2
    echo "         Expected at least 2 .lproj dirs and 2 Localizable.strings;" >&2
    echo "         got $LPROJ_COUNT .lproj and $STRINGS_COUNT .strings." >&2
    echo "         The .xcodeproj is probably stale -- try:" >&2
    echo "             rm -rf AISwitch.xcodeproj && bash scripts/build_release.sh" >&2
    exit 1
fi

# Strip the quarantine attribute. Built products shouldn't have one, but
# tools like rsync, scp, or unzip can add it; better to defensively clear.
xattr -dr com.apple.quarantine "$FINAL_APP_PATH" 2>/dev/null || true

echo "  [ok] CFBundleExecutable = ${EXECUTABLE_NAME}"
echo "  [ok] Mach-O present at MacOS/${EXECUTABLE_NAME}"
echo "  [ok] Code signature valid"
echo "  [ok] Localization: ${LPROJ_COUNT} .lproj dirs, ${STRINGS_COUNT} .strings files"
echo
echo "[ok] Built ${FINAL_APP_PATH}  (${SIGN_STYLE})"
echo
echo "Install on this Mac:"
echo "    cp -R \"$FINAL_APP_PATH\" /Applications/"
echo "    xattr -dr com.apple.quarantine /Applications/AISwitch.app   # just in case"
echo "    open /Applications/AISwitch.app"
echo
echo "Build a sharable installer:"
echo "    bash scripts/build_dmg.sh"

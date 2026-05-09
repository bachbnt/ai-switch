#!/usr/bin/env bash
#
# setup.sh -- first-time-on-this-machine setup. Idempotent; safe to re-run.
#
# Installs the build tools we need (XcodeGen for project generation,
# create-dmg for a nice installer layout) via Homebrew, then regenerates
# the .xcodeproj from project.yml.
#
# Usage:
#   bash scripts/setup.sh

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

# ------------------------------------------------------------------
# Pre-flight: macOS + Xcode CLT
# ------------------------------------------------------------------
if [[ "$(uname)" != "Darwin" ]]; then
    echo "AISwitch is a macOS app. This script must run on macOS." >&2
    exit 1
fi

if ! xcode-select -p >/dev/null 2>&1; then
    echo "Xcode Command Line Tools missing. Installing..."
    xcode-select --install
    echo "Re-run this script after the CLT installer finishes."
    exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "xcodebuild not found. Install Xcode from the App Store." >&2
    exit 1
fi

# ------------------------------------------------------------------
# Homebrew + tools
# ------------------------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew not found. Install from https://brew.sh first." >&2
    exit 1
fi

install_if_missing() {
    local pkg="${1:-}"
    if [[ -z "$pkg" ]]; then
        echo "install_if_missing: missing package name" >&2
        return 1
    fi
    if ! brew list --formula --versions "$pkg" >/dev/null 2>&1; then
        echo "Installing ${pkg}..."
        brew install "$pkg"
    else
        echo "[ok] ${pkg} already installed"
    fi
}

install_if_missing xcodegen
install_if_missing create-dmg     # optional but produces a much nicer DMG

# ------------------------------------------------------------------
# Generate Xcode project
# ------------------------------------------------------------------
echo
echo "Generating AISwitch.xcodeproj from project.yml..."
xcodegen generate --spec "$ROOT/project.yml"

echo
echo "Setup complete."
echo
echo "  Open in Xcode:    open AISwitch.xcodeproj"
echo "  Build & run:      bash scripts/build_release.sh"
echo "  Build installer:  bash scripts/build_dmg.sh"

#!/usr/bin/env bash
# Builds PACE Launcher with SwiftPM and wraps it in a signed .app bundle.
# Usage: scripts/build-app.sh [debug|release]
set -euo pipefail

CONFIG="${1:-debug}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXEC="PACELauncher"
APP="$ROOT/build/PACE Launcher.app"
# Apple Development certificate. A stable identity keeps the Accessibility
# grant valid across rebuilds; ad-hoc signing would reset it every build.
IDENTITY="${PACE_SIGN_IDENTITY:-96BC64B93D995484ACC406BD7C5AB427661AAB96}"

cd "$ROOT"

echo "==> swift build ($CONFIG)"
swift build -c "$CONFIG" --product "$EXEC"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/$EXEC"
test -x "$BIN" || { echo "binary not found: $BIN" >&2; exit 1; }

echo "==> assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$EXEC"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$(date +%Y%m%d%H%M%S)" "$APP/Contents/Info.plist"
plutil -lint -s "$APP/Contents/Info.plist"
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

echo "==> signing"
xattr -cr "$APP"
codesign --force --sign "$IDENTITY" --timestamp=none "$APP"
codesign --verify --strict --verbose=1 "$APP"
if ! codesign -d -r- "$APP" 2>&1 | grep -q 'certificate leaf'; then
  echo "designated requirement is not certificate based; TCC grants will not survive rebuilds" >&2
  exit 1
fi

echo "==> done: $APP"

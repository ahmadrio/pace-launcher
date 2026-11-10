#!/usr/bin/env bash
# Builds PACE Launcher with SwiftPM and wraps it in a signed .app bundle.
# Usage: scripts/build-app.sh [debug|release]
set -euo pipefail

CONFIG="${1:-debug}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXEC="PACELauncher"
APP="$ROOT/build/PACE Launcher.app"
# The self-signed "PACE Launcher Signing" identity (scripts/make-signing-identity.sh).
# Every build uses it, so users keep their privacy permissions across updates;
# ad-hoc signing would reset them on every build.
DEFAULT_IDENTITY="E34315F9FD60682C6904263E093FCE4288A4D64A"
IDENTITY="${PACE_SIGN_IDENTITY:-$DEFAULT_IDENTITY}"

cd "$ROOT"

echo "==> swift build ($CONFIG)"
swift build -c "$CONFIG" --product "$EXEC"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/$EXEC"
test -x "$BIN" || { echo "binary not found: $BIN" >&2; exit 1; }

echo "==> assembling $APP"
rm -rf "${APP:?}"
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
if [[ "$IDENTITY" != "-" ]] && security find-identity -p codesigning | grep -qiF -- "$IDENTITY"; then
  codesign --force --sign "$IDENTITY" --timestamp=none "$APP"
  codesign --verify --strict --verbose=1 "$APP"
  if ! codesign -d -r- "$APP" 2>&1 | grep -Eq 'certificate (leaf|root)'; then
    echo "designated requirement is not certificate based; TCC grants will not survive rebuilds" >&2
    exit 1
  fi
elif [[ "$CONFIG" == "release" ]]; then
  echo "signing identity $IDENTITY not found; see docs/RELEASING.md" >&2
  exit 1
else
  echo "warning: signing identity $IDENTITY not found; signing ad-hoc." >&2
  echo "warning: privacy permissions (Accessibility, Input Monitoring) reset on every build." >&2
  codesign --force --sign - --timestamp=none "$APP"
  codesign --verify --strict --verbose=1 "$APP"
fi

echo "==> done: $APP"

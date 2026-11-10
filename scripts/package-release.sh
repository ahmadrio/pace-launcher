#!/usr/bin/env bash
# Builds a release of PACE Launcher and packages it as a checked DMG plus a
# SHA-256 checksum in build/release/. See docs/RELEASING.md.
# PACE_ALLOW_DIRTY=1 packages uncommitted changes (for testing only).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
APP="$ROOT/build/PACE Launcher.app"
OUT="$ROOT/build/release"

fail() { echo "error: $*" >&2; exit 1; }

if [[ -n "$(git status --porcelain)" && "${PACE_ALLOW_DIRTY:-}" != "1" ]]; then
  fail "uncommitted changes; commit them first (PACE_ALLOW_DIRTY=1 makes a test package)"
fi

VERSION="$(plutil -extract CFBundleShortVersionString raw Resources/Info.plist)"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "version '$VERSION' in Resources/Info.plist is not x.y.z"

# build-app.sh refuses a release without the signing identity.
scripts/build-app.sh release

IDENTITY="${PACE_SIGN_IDENTITY:-$(sed -n 's/^DEFAULT_IDENTITY="\(.*\)"$/\1/p' scripts/build-app.sh)}"
HASH="$(security find-identity -p codesigning | grep -iF -- "$IDENTITY" | head -1 | awk '{print $2}')"
[[ "$HASH" =~ ^[0-9A-Fa-f]{40}$ ]] || fail "could not resolve signing identity $IDENTITY"

check_app() {
  local app="$1"
  codesign --verify --strict "$app" || fail "$app: signature does not verify"
  codesign -d -r- "$app" 2>&1 | grep -qi "H\"$HASH\"" || fail "$app: not signed by $HASH"
  [[ "$(lipo -archs "$app/Contents/MacOS/PACELauncher")" == "arm64" ]] || fail "$app: not an arm64 build"
  [[ "$(plutil -extract CFBundleShortVersionString raw "$app/Contents/Info.plist")" == "$VERSION" ]] \
    || fail "$app: version is not $VERSION"
}

echo "==> checking $APP"
check_app "$APP"

NAME="PACE-Launcher-$VERSION"
DMG="$OUT/$NAME.dmg"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/pace-dmg.XXXXXX")"
MOUNT="$(mktemp -d "${TMPDIR:-/tmp}/pace-mount.XXXXXX")"
cleanup() {
  diskutil eject "$MOUNT" >/dev/null 2>&1 || true
  rm -rf "${STAGE:?}"
  rmdir "$MOUNT" 2>/dev/null || true
}
trap cleanup EXIT

echo "==> creating $DMG"
ditto "$APP" "$STAGE/PACE Launcher.app"
ln -s /Applications "$STAGE/Applications"
mkdir -p "$OUT"
rm -f "${DMG:?}" "${DMG:?}.sha256"
diskutil image create from --format ULFO --volumeName "PACE Launcher" "$STAGE" "$DMG" >/dev/null
echo
hdiutil verify "$DMG" >/dev/null 2>&1 || fail "hdiutil verify failed for $DMG"

echo "==> checking the mounted DMG"
diskutil image attach --readOnly --nobrowse --mountPoint "$MOUNT" "$DMG" >/dev/null
CONTENTS="$(ls "$MOUNT" | tr '\n' '|')"
[[ "$CONTENTS" == "Applications|PACE Launcher.app|" ]] || fail "unexpected DMG contents: $CONTENTS"
[[ "$(readlink "$MOUNT/Applications")" == "/Applications" ]] || fail "Applications link is wrong"
check_app "$MOUNT/PACE Launcher.app"
if grep -rlaF "PRIVATE KEY" "$MOUNT" >/dev/null 2>&1; then fail "key material found in the DMG"; fi
echo "==> Gatekeeper (expected: rejected, because the app is not notarized)"
spctl -a -t exec -vv "$MOUNT/PACE Launcher.app" 2>&1 | sed 's/^/    /' || true
diskutil eject "$MOUNT" >/dev/null

# Written from inside OUT so the file names the bare DMG, ready for `shasum -c`.
(cd "$OUT" && shasum -a 256 "$NAME.dmg" > "$NAME.dmg.sha256" && shasum -a 256 -c "$NAME.dmg.sha256" >/dev/null) \
  || fail "checksum check failed"

echo "==> done"
echo "    $DMG"
echo "    $DMG.sha256"
echo "    sha256 $(cut -d' ' -f1 "$DMG.sha256")"

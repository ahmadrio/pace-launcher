#!/usr/bin/env bash
# Builds a release of PACE Launcher and packages it as a checked DMG plus a
# SHA-256 checksum in build/release/. See docs/RELEASING.md.
# PACE_ALLOW_DIRTY=1 packages uncommitted changes (for testing only); the
# files are then named …-dirty so they can't pass for a release.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
APP="$ROOT/build/PACE Launcher.app"
OUT="$ROOT/build/release"

fail() { echo "error: $*" >&2; exit 1; }

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "not a git checkout; package from a clone of the repository"
SUFFIX=""
if [[ -n "$(git status --porcelain)" ]]; then
  [[ "${PACE_ALLOW_DIRTY:-}" == "1" ]] || fail "uncommitted changes; commit them first (PACE_ALLOW_DIRTY=1 makes a test package)"
  SUFFIX="-dirty"
fi

VERSION="$(plutil -extract CFBundleShortVersionString raw Resources/Info.plist)"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "version '$VERSION' in Resources/Info.plist is not x.y.z"

# Releases are always signed with DEFAULT_IDENTITY: another certificate would
# reset every user's privacy permissions. PACE_SIGN_IDENTITY may only name it.
DEFAULT_IDENTITY="$(sed -n 's/^DEFAULT_IDENTITY="\(.*\)"$/\1/p' scripts/build-app.sh)"
IDENTITY="${PACE_SIGN_IDENTITY:-$DEFAULT_IDENTITY}"
IDENTITIES="$(security find-identity -p codesigning)"
HASH="$(grep -iF -- "$IDENTITY" <<<"$IDENTITIES" | head -1 | awk '{print $2}' || true)"
[[ "$HASH" =~ ^[0-9A-Fa-f]{40}$ ]] || fail "signing identity $IDENTITY not found; see docs/RELEASING.md"
[[ "$(tr 'a-f' 'A-F' <<<"$HASH")" == "$(tr 'a-f' 'A-F' <<<"$DEFAULT_IDENTITY")" ]] \
  || fail "releases must be signed with DEFAULT_IDENTITY ($DEFAULT_IDENTITY), not $HASH; unset PACE_SIGN_IDENTITY"

scripts/build-app.sh release

check_app() {
  local app="$1"
  codesign --verify --strict "$app" || fail "$app: signature does not verify"
  codesign -d -r- "$app" 2>&1 | grep -qi "H\"$HASH\"" || fail "$app: not signed by $HASH"
  [[ "$(lipo -archs "$app/Contents/MacOS/PACELauncher")" == "arm64" ]] || fail "$app: not an arm64 build"
  [[ "$(plutil -extract CFBundleShortVersionString raw "$app/Contents/Info.plist")" == "$VERSION" ]] \
    || fail "$app: version is not $VERSION"
  # The checkout path (with the builder's user name) must not ship.
  if grep -qF -- "$ROOT" <<<"$(strings -a "$app/Contents/MacOS/PACELauncher")"; then
    fail "$app: the binary contains the build folder path $ROOT"
  fi
}

echo "==> checking $APP"
check_app "$APP"

NAME="PACE-Launcher-$VERSION$SUFFIX"
DMG="$OUT/$NAME.dmg"
# Built under a hidden name and renamed only after every check passed, so a
# failed run never leaves a file that looks like a release.
PARTIAL="$OUT/.partial-$NAME.dmg"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/pace-dmg.XXXXXX")"
MOUNT="$(mktemp -d "${TMPDIR:-/tmp}/pace-mount.XXXXXX")"
cleanup() {
  diskutil eject "$MOUNT" >/dev/null 2>&1 || true
  rm -f "${PARTIAL:?}"
  rm -rf "${STAGE:?}"
  rmdir "$MOUNT" 2>/dev/null || true
}
trap cleanup EXIT

echo "==> creating $DMG"
ditto "$APP" "$STAGE/PACE Launcher.app"
ln -s /Applications "$STAGE/Applications"
mkdir -p "$OUT"
rm -f "${DMG:?}" "${DMG:?}.sha256" "${PARTIAL:?}"
diskutil image create from --format ULFO --volumeName "PACE Launcher" "$STAGE" "$PARTIAL" >/dev/null
echo
hdiutil verify "$PARTIAL" >/dev/null 2>&1 || fail "hdiutil verify failed for $DMG"

echo "==> checking the mounted DMG"
diskutil image attach --readOnly --nobrowse --mountPoint "$MOUNT" "$PARTIAL" >/dev/null
CONTENTS="$(ls -A "$MOUNT" | tr '\n' '|')"
[[ "$CONTENTS" == "Applications|PACE Launcher.app|" ]] || fail "unexpected DMG contents: $CONTENTS"
[[ "$(readlink "$MOUNT/Applications")" == "/Applications" ]] || fail "Applications link is wrong"
check_app "$MOUNT/PACE Launcher.app"
if grep -rlaF "PRIVATE KEY" "$MOUNT" >/dev/null 2>&1; then fail "key material found in the DMG"; fi
echo "==> Gatekeeper (expected: rejected, because the app is not notarized)"
spctl -a -t exec -vv "$MOUNT/PACE Launcher.app" 2>&1 | sed 's/^/    /' || true
diskutil eject "$MOUNT" >/dev/null
mv "$PARTIAL" "$DMG"

# Written from inside OUT so the file names the bare DMG, ready for `shasum -c`.
(cd "$OUT" && shasum -a 256 "$NAME.dmg" > "$NAME.dmg.sha256" && shasum -a 256 -c "$NAME.dmg.sha256" >/dev/null) \
  || fail "checksum check failed"

echo "==> done"
echo "    $DMG"
echo "    $DMG.sha256"
echo "    sha256 $(cut -d' ' -f1 "$DMG.sha256")"

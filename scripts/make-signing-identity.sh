#!/usr/bin/env bash
# Creates the self-signed "PACE Launcher Signing" code-signing identity in the
# login keychain. Run once per maintainer Mac. Every build is signed with it,
# so users keep their privacy permissions across updates (docs/RELEASING.md).
set -euo pipefail

NAME="PACE Launcher Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
# LibreSSL writes .p12 files with the algorithms `security import` reads.
OPENSSL=/usr/bin/openssl

if security find-identity -p codesigning "$KEYCHAIN" | grep -qF "\"$NAME\""; then
  echo "\"$NAME\" already exists in the login keychain; nothing to do." >&2
  exit 1
fi

# The private key exists on disk only inside this folder, which is removed on exit.
umask 077
WORK="$(mktemp -d "${TMPDIR:-/tmp}/pace-signing.XXXXXX")"
trap 'rm -rf "${WORK:?}"' EXIT

cat > "$WORK/cert.cnf" <<EOF
[req]
distinguished_name = dn
prompt = no
x509_extensions = ext
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
subjectKeyIdentifier = hash
EOF

"$OPENSSL" req -x509 -newkey rsa:3072 -nodes -sha256 -days 7300 \
  -config "$WORK/cert.cnf" -keyout "$WORK/key.pem" -out "$WORK/cert.pem" 2>/dev/null
export P12_PASS="$("$OPENSSL" rand -hex 24)"
"$OPENSSL" pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" -name "$NAME" \
  -passout env:P12_PASS -out "$WORK/identity.p12"
security import "$WORK/identity.p12" -k "$KEYCHAIN" -f pkcs12 -P "$P12_PASS" -T /usr/bin/codesign >/dev/null

SHA1="$("$OPENSSL" x509 -in "$WORK/cert.pem" -noout -fingerprint -sha1 | sed 's/.*=//; s/://g')"
echo "Created \"$NAME\" ($SHA1) in the login keychain."
echo "To sign your builds with it: export PACE_SIGN_IDENTITY=$SHA1"
echo "Releases always use DEFAULT_IDENTITY in scripts/build-app.sh; set it to this SHA-1 only if this is the new release identity."

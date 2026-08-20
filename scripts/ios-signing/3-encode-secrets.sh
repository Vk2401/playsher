#!/usr/bin/env bash
#
# Step 3 of 3 — turn the .p12 and the provisioning profile into the base64
# blobs that go into GitHub repository secrets.
#
#   ./3-encode-secrets.sh ios_distribution.p12 "the-p12-password" Playsher.mobileprovision
#
# Writes each value to its own file next to the inputs, because a base64 blob
# is thousands of characters and pasting it out of a terminal reliably is
# painful. Open the file, select all, copy.

set -euo pipefail

P12="${1:-}"
P12_PASSWORD="${2:-}"
PROFILE="${3:-}"
OUT_DIR="${4:-./secrets-to-paste}"

if [ -z "$P12" ] || [ -z "$P12_PASSWORD" ] || [ -z "$PROFILE" ]; then
  echo "usage: $0 <ios_distribution.p12> <p12-password> <profile.mobileprovision> [out-dir]" >&2
  exit 2
fi
[ -f "$P12" ]     || { echo "error: $P12 not found" >&2; exit 1; }
[ -f "$PROFILE" ] || { echo "error: $PROFILE not found" >&2; exit 1; }

# Prove the password before encoding, so a typo surfaces here rather than as a
# failed CI build twenty minutes later.
LEGACY=""
openssl pkcs12 -help 2>&1 | grep -q -- '-legacy' && LEGACY="-legacy"
# shellcheck disable=SC2086
if ! openssl pkcs12 -in "$P12" -passin "pass:${P12_PASSWORD}" -nokeys $LEGACY >/dev/null 2>&1; then
  echo "error: that password does not open $P12" >&2
  exit 1
fi
echo "Password verified against $P12."

mkdir -p "$OUT_DIR"

# -w0 / -b0: no line wrapping. A wrapped blob still decodes, but the newlines
# make it easy to lose a line when copying out of an editor.
b64() {
  if base64 --help 2>&1 | grep -q -- '-w'; then base64 -w0 "$1"; else base64 -b0 "$1"; fi
}

b64 "$P12"     > "$OUT_DIR/IOS_CERTIFICATE_BASE64.txt"
b64 "$PROFILE" > "$OUT_DIR/IOS_PROVISIONING_PROFILE_BASE64.txt"

# The team id is inside the profile — no need to go hunting for it.
TEAM_ID=""
if command -v openssl >/dev/null; then
  PLIST="$(mktemp)"; trap 'rm -f "$PLIST"' EXIT
  if openssl smime -inform DER -verify -noverify -in "$PROFILE" -out "$PLIST" 2>/dev/null; then
    TEAM_ID="$(grep -A1 '<key>TeamIdentifier</key>' "$PLIST" \
      | grep -o '<string>[^<]*</string>' | head -1 | sed 's/<[^>]*>//g' || true)"
    APP_ID="$(grep -A1 '<key>application-identifier</key>' "$PLIST" \
      | grep -o '<string>[^<]*</string>' | head -1 | sed 's/<[^>]*>//g' || true)"
    PROFILE_NAME="$(grep -A1 '<key>Name</key>' "$PLIST" \
      | grep -o '<string>[^<]*</string>' | head -1 | sed 's/<[^>]*>//g' || true)"
  fi
fi

echo
echo "Wrote to $OUT_DIR/ :"
echo "  IOS_CERTIFICATE_BASE64.txt"
echo "  IOS_PROVISIONING_PROFILE_BASE64.txt"
echo
echo "Add these four secrets at:"
echo "  Settings -> Secrets and variables -> Actions -> New repository secret"
echo
echo "  IOS_CERTIFICATE_BASE64            <- contents of the first file"
echo "  IOS_PROVISIONING_PROFILE_BASE64   <- contents of the second file"
echo "  IOS_CERTIFICATE_PASSWORD          <- the password you chose in step 2"
if [ -n "$TEAM_ID" ]; then
  echo "  IOS_TEAM_ID                       <- ${TEAM_ID}"
else
  echo "  IOS_TEAM_ID                       <- your 10-character Apple Team ID"
fi
echo
[ -n "${PROFILE_NAME:-}" ] && echo "Profile:  ${PROFILE_NAME}"
[ -n "${APP_ID:-}" ]       && echo "Bundle:   ${APP_ID#*.}   (must match the app's bundle identifier)"
echo
echo "Then: Actions -> 'iOS IPA' -> Run workflow."

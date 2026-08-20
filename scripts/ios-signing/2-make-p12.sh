#!/usr/bin/env bash
#
# Step 2 of 3 — combine Apple's certificate with your private key into a .p12.
#
# Apple hands you a .cer, which is the public half only. GitHub Actions needs
# both halves in one password-protected file: that is the .p12.
#
#   ./2-make-p12.sh distribution.cer ios_distribution.key "a-password"
#
# Produces ios_distribution.p12. Remember the password — it becomes the
# IOS_CERTIFICATE_PASSWORD secret.

set -euo pipefail

CER="${1:-}"
KEY="${2:-ios_distribution.key}"
P12_PASSWORD="${3:-}"
OUT="${4:-ios_distribution.p12}"

if [ -z "$CER" ] || [ -z "$P12_PASSWORD" ]; then
  echo "usage: $0 <apple-certificate.cer> <private.key> <p12-password> [out.p12]" >&2
  exit 2
fi
[ -f "$CER" ] || { echo "error: $CER not found" >&2; exit 1; }
[ -f "$KEY" ] || { echo "error: $KEY not found — it is the key from step 1" >&2; exit 1; }

TMP_PEM="$(mktemp)"
trap 'rm -f "$TMP_PEM"' EXIT

# Apple ships DER. Convert to PEM, but accept a .cer that is already PEM so the
# script does not fail on a file that is actually fine.
if openssl x509 -inform DER -in "$CER" -out "$TMP_PEM" 2>/dev/null; then
  echo "Converted DER certificate to PEM."
else
  cp "$CER" "$TMP_PEM"
  openssl x509 -in "$TMP_PEM" -noout >/dev/null 2>&1 \
    || { echo "error: $CER is not a certificate this can read" >&2; exit 1; }
  echo "Certificate was already PEM."
fi

# Refuse early if the cert and key are not a pair — otherwise you find out
# during a CI build, as an opaque codesign failure.
CERT_MOD="$(openssl x509 -noout -modulus -in "$TMP_PEM" | openssl md5)"
KEY_MOD="$(openssl rsa  -noout -modulus -in "$KEY"     | openssl md5)"
if [ "$CERT_MOD" != "$KEY_MOD" ]; then
  echo "error: this certificate was NOT issued for this private key." >&2
  echo "       You are probably using a key from a different CSR." >&2
  exit 1
fi
echo "Certificate and private key match."

# -legacy on OpenSSL 3.x: without it the .p12 uses AES-256, which macOS's
# `security import` on the CI runner can refuse with a bare "MAC verification
# failed". The legacy cipher is what Keychain Access itself writes.
LEGACY=""
openssl pkcs12 -help 2>&1 | grep -q -- '-legacy' && LEGACY="-legacy"

# shellcheck disable=SC2086  # LEGACY is intentionally an unquoted optional flag
openssl pkcs12 -export \
  -inkey "$KEY" \
  -in "$TMP_PEM" \
  -out "$OUT" \
  -name "Apple Distribution" \
  -passout "pass:${P12_PASSWORD}" \
  $LEGACY

echo
echo "Created $OUT"
echo "Next: ./3-encode-secrets.sh $OUT '<password>' <profile.mobileprovision>"

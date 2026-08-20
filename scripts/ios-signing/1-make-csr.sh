#!/usr/bin/env bash
#
# Step 1 of 3 — create the private key and the certificate signing request.
#
# Apple's docs tell you to do this in Keychain Access, which needs a Mac.
# OpenSSL produces exactly the same thing on Linux or Windows (WSL/Git Bash).
#
#   ./1-make-csr.sh "you@example.com" "Your Name"
#
# Produces:
#   ios_distribution.key   your PRIVATE KEY — never commit it, never share it.
#                          Apple never sees it. Lose it and the certificate
#                          Apple issues is worthless and must be revoked.
#   ios_distribution.csr   upload THIS to Apple.

set -euo pipefail

EMAIL="${1:-}"
NAME="${2:-}"
OUT_DIR="${3:-.}"

if [ -z "$EMAIL" ] || [ -z "$NAME" ]; then
  echo "usage: $0 <apple-id-email> <your name> [output-dir]" >&2
  echo "example: $0 you@example.com \"Vasanth K\"" >&2
  exit 2
fi

mkdir -p "$OUT_DIR"
KEY="$OUT_DIR/ios_distribution.key"
CSR="$OUT_DIR/ios_distribution.csr"

if [ -f "$KEY" ]; then
  echo "error: $KEY already exists. Refusing to overwrite it — that key is the" >&2
  echo "       only thing that can unlock a certificate Apple already issued." >&2
  exit 1
fi

openssl genrsa -out "$KEY" 2048
chmod 600 "$KEY"

# CN and emailAddress are what Apple shows next to the certificate. C must be a
# two-letter country code.
openssl req -new -key "$KEY" -out "$CSR" \
  -subj "/emailAddress=${EMAIL}/CN=${NAME}/C=IN"

echo
echo "Created:"
echo "  $KEY   <- PRIVATE. Keep it. Do not commit it."
echo "  $CSR   <- upload this one to Apple"
echo
echo "Next: developer.apple.com/account/resources/certificates/add"
echo "      choose 'Apple Distribution', upload $CSR, download the .cer,"
echo "      then run ./2-make-p12.sh"

#!/usr/bin/env python3
"""Mint iOS signing assets through the App Store Connect API.

A signed build normally needs two files a human made on a Mac: a .p12
exported from Keychain Access and a .mobileprovision downloaded from the
developer portal. Both can be created over the API instead, which is the
whole point of this script — it is what lets the iOS pipeline run for
someone who owns no Mac.

`provision` generates a fresh private key, has Apple certify it, builds an
App Store profile around it, and writes the pair out as the same two files
the workflow already knows how to install. `cleanup` revokes them again.

The certificate is deliberately per-run rather than long-lived: Apple caps
an account at three distribution certificates, and a private key that never
outlives the job cannot leak from a secret store. Revoking a distribution
certificate does not disturb builds already delivered — App Store Connect
re-signs everything it accepts — so a TestFlight build stays installable
long after the certificate that produced it is gone.

Everything it needs is three values from
App Store Connect -> Users and Access -> Integrations.
"""

import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509 import CertificateSigningRequestBuilder, Name, NameAttribute
from cryptography.x509.oid import NameOID
import jwt

API = "https://api.appstoreconnect.apple.com/v1"


# ── Talking to Apple ─────────────────────────────────────────────────────────

def bearer() -> str:
    """A short-lived ES256 token. Apple refuses anything over 20 minutes."""
    key_id = os.environ["ASC_KEY_ID"]
    issuer_id = os.environ["ASC_ISSUER_ID"]
    private_key = os.environ["ASC_PRIVATE_KEY"]

    now = int(time.time())
    return jwt.encode(
        {"iss": issuer_id, "iat": now, "exp": now + 19 * 60, "aud": "appstoreconnect-v1"},
        private_key,
        algorithm="ES256",
        headers={"kid": key_id, "typ": "JWT"},
    )


def call(method: str, path: str, body: dict | None = None) -> dict:
    request = urllib.request.Request(
        f"{API}{path}",
        method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={
            "Authorization": f"Bearer {bearer()}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request) as response:
            raw = response.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode(errors="replace")
        # Apple's errors are genuinely descriptive; surfacing the body beats
        # reporting a bare 409 that the reader then has to go and look up.
        try:
            errors = json.loads(detail).get("errors", [])
            detail = "\n".join(
                f"  {e.get('title', '')}: {e.get('detail', '')}" for e in errors
            ) or detail
        except json.JSONDecodeError:
            pass
        sys.exit(f"::error::App Store Connect refused {method} {path} ({exc.code}):\n{detail}")


# ── Provisioning ─────────────────────────────────────────────────────────────

def make_csr(common_name: str) -> tuple[bytes, bytes]:
    """A fresh 2048-bit key and a request for Apple to certify it."""
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    csr = (
        CertificateSigningRequestBuilder()
        .subject_name(Name([NameAttribute(NameOID.COMMON_NAME, common_name)]))
        .sign(key, hashes.SHA256())
    )
    key_pem = key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )
    return key_pem, csr.public_bytes(serialization.Encoding.PEM)


def provision(out_dir: str, bundle_id: str, profile_name: str) -> None:
    key_pem, csr_pem = make_csr(f"Playsher CI ({profile_name})")

    certificate = call("POST", "/certificates", {
        "data": {
            "type": "certificates",
            "attributes": {
                "csrContent": csr_pem.decode(),
                "certificateType": "IOS_DISTRIBUTION",
            },
        }
    })["data"]

    # filter[identifier] is an exact match, but the collection still comes back
    # as a list, and an empty one means the App ID was never registered.
    matches = call("GET", f"/bundleIds?filter[identifier]={bundle_id}")["data"]
    if not matches:
        sys.exit(
            f"::error::No App ID registered for '{bundle_id}'. Create it at "
            "developer.apple.com -> Certificates, Identifiers & Profiles -> Identifiers."
        )

    profile = call("POST", "/profiles", {
        "data": {
            "type": "profiles",
            "attributes": {"name": profile_name, "profileType": "IOS_APP_STORE"},
            "relationships": {
                "bundleId": {"data": {"type": "bundleIds", "id": matches[0]["id"]}},
                "certificates": {"data": [{"type": "certificates", "id": certificate["id"]}]},
            },
        }
    })["data"]

    os.makedirs(out_dir, exist_ok=True)
    write(f"{out_dir}/signing.key", key_pem)
    write(f"{out_dir}/signing.cer",
          base64.b64decode(certificate["attributes"]["certificateContent"]))
    write(f"{out_dir}/profile.mobileprovision",
          base64.b64decode(profile["attributes"]["profileContent"]))

    emit("ASC_CERTIFICATE_ID", certificate["id"])
    emit("ASC_PROFILE_ID", profile["id"])
    print(f"Created certificate {certificate['id']} and profile '{profile_name}'.")


def cleanup() -> None:
    """Best-effort: a leaked profile is noise, but a leaked certificate eats
    one of the three slots the account has, so neither is left behind."""
    for env_name, path in (
        ("ASC_PROFILE_ID", "/profiles"),
        ("ASC_CERTIFICATE_ID", "/certificates"),
    ):
        identifier = os.environ.get(env_name)
        if not identifier:
            continue
        call("DELETE", f"{path}/{identifier}")
        print(f"Removed {path.strip('/')[:-1]} {identifier}.")


# ── Small helpers ────────────────────────────────────────────────────────────

def write(path: str, data: bytes) -> None:
    with open(path, "wb") as handle:
        handle.write(data)
    os.chmod(path, 0o600)


def emit(name: str, value: str) -> None:
    with open(os.environ["GITHUB_ENV"], "a") as handle:
        handle.write(f"{name}={value}\n")


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    if command == "provision":
        provision(sys.argv[2], sys.argv[3], sys.argv[4])
    elif command == "cleanup":
        cleanup()
    else:
        sys.exit("usage: asc_provision.py provision <out-dir> <bundle-id> <profile-name>\n"
                 "       asc_provision.py cleanup")

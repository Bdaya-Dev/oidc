#!/usr/bin/env bash
# Regenerates the RFC 8705 mTLS fixtures used by test/mtls_transport_test.dart.
#
# TEST-ONLY key material: these private keys are public by definition (they are
# committed). Never use them for anything but the local test server.
set -euo pipefail
cd "$(dirname "$0")"
DAYS=36500
# Keep Git Bash on Windows from rewriting "/CN=..." into a filesystem path.
export MSYS_NO_PATHCONV=1

ec() { openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out "$1"; }

# Test CA.
ec ca.key
openssl req -x509 -new -key ca.key -sha256 -days "$DAYS" \
  -subj "/CN=oidc test mTLS CA" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,keyCertSign,cRLSign" \
  -out ca.pem

# Server certificate for localhost, issued by the CA.
ec server.key
openssl req -new -key server.key -subj "/CN=localhost" -out server.csr
printf 'subjectAltName=DNS:localhost,IP:127.0.0.1\nextendedKeyUsage=serverAuth\n' \
  > server.ext
openssl x509 -req -in server.csr -CA ca.pem -CAkey ca.key -CAcreateserial \
  -days "$DAYS" -sha256 -extfile server.ext -out server.pem

# PKI client certificate (tls_client_auth, RFC 8705 §2.1), issued by the CA.
ec client.key
openssl req -new -key client.key -subj "/CN=mtls-client" -out client.csr
printf 'extendedKeyUsage=clientAuth\n' > client.ext
openssl x509 -req -in client.csr -CA ca.pem -CAkey ca.key -CAcreateserial \
  -days "$DAYS" -sha256 -extfile client.ext -out client.pem

# Self-signed client certificate (self_signed_tls_client_auth, RFC 8705 §2.2).
ec self_signed_client.key
openssl req -x509 -new -key self_signed_client.key -sha256 -days "$DAYS" \
  -subj "/CN=self-signed-client" \
  -addext "extendedKeyUsage=clientAuth" \
  -out self_signed_client.pem

rm -f ./*.csr ./*.ext ./*.srl

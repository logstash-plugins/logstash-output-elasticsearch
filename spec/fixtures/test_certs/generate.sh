#!/usr/bin/env bash
#
# Generates all SSL test certificates from scratch.
# Idempotent: skips if ca.crt exists and is not expired (use --force to override).

set -euo pipefail
cd "$(dirname "$0")"

DAYS_CA=1826        # ~5 years
DAYS_CERT=1096      # ~3 years
P12_PASS="1234567890"
CNF="openssl.cnf"

# sha256sum is not available on macOS
sha256() {
  if command -v sha256sum &>/dev/null; then
    sha256sum | awk '{print $1}'
  else
    shasum -a 256 | awk '{print $1}'
  fi
}

if [[ "${1:-}" != "--force" ]] && [[ -f ca.crt ]]; then
  if openssl x509 -in ca.crt -checkend 0 -noout 2>/dev/null && \
     openssl x509 -in test.crt -checkend 0 -noout 2>/dev/null; then
    echo "Certs exist and are not expired. Use --force to regenerate."
    exit 0
  fi
  echo "Existing certs are expired. Regenerating all certs."
fi

echo "Generating SSL test certificates..."

# 1. Root CA
openssl req -new -x509 -nodes \
  -keyout ca.key -out ca.crt \
  -days "$DAYS_CA" \
  -subj "/C=PT/ST=NA/L=Lisbon/O=MyLab/CN=RootCA" \
  -config "$CNF" -extensions v3_ca

openssl x509 -in ca.crt -outform der | sha256 > ca.der.sha256

# 2. Server cert (valid) - SAN includes localhost + elasticsearch
openssl req -new -nodes \
  -keyout test.key -out test.csr \
  -subj "/C=PT/ST=NA/L=Lisbon/O=MyLab/CN=elasticsearch" \
  -config "$CNF"

openssl x509 -req -in test.csr \
  -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out test.crt -days "$DAYS_CERT" \
  -extfile "$CNF" -extensions server_cert

openssl x509 -in test.crt -outform der | sha256 > test.der.sha256

openssl pkcs12 -export \
  -inkey test.key -in test.crt \
  -certfile ca.crt \
  -passout "pass:$P12_PASS" \
  -out test.p12

rm -f test.csr

# 3. Server cert (invalid SAN) - SAN has only localhost, no elasticsearch
openssl req -new -nodes \
  -keyout test_invalid.key -out test_invalid.csr \
  -subj "/C=LS/ST=NA/L=ES Output/O=Logstash/CN=server" \
  -config "$CNF"

openssl x509 -req -in test_invalid.csr \
  -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out test_invalid.crt -days "$DAYS_CERT" \
  -extfile "$CNF" -extensions server_cert_invalid

openssl pkcs12 -export \
  -inkey test_invalid.key -in test_invalid.crt \
  -certfile ca.crt \
  -passout "pass:$P12_PASS" \
  -out test_invalid.p12

rm -f test_invalid.csr

# 4. Self-signed cert (not signed by our CA)
openssl req -new -x509 -nodes \
  -keyout test_self_signed.key -out test_self_signed.crt \
  -days "$DAYS_CERT" \
  -subj "/C=LS/ST=NA/L=ES/O=Logstash/CN=client" \
  -config "$CNF" -extensions self_signed_cert

openssl pkcs12 -export \
  -inkey test_self_signed.key -in test_self_signed.crt \
  -passout "pass:$P12_PASS" \
  -out test_self_signed.p12

# Cleanup
rm -f ca.srl

# Timestamp
date -Iseconds > GENERATED_AT

echo "SSL test certificates generated successfully."

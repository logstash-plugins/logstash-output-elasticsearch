#!/usr/bin/env bash

set -e
cd "$(dirname "$0")"

openssl x509 -x509toreq -in ca.crt -signkey ca.key -out ca.csr
openssl x509 -req -days 365 -in ca.csr -set_serial 0x01 -signkey ca.key -out ca.crt && rm ca.csr
openssl x509 -in ca.crt -outform der | sha256sum | awk '{print $1}' > ca.der.sha256

openssl x509 -x509toreq -in test.crt -signkey test.key -out test.csr
openssl x509 -req -days 365 -in test.csr -set_serial 0x01 -CA ca.crt -CAkey ca.key -out test.crt && rm test.csr
openssl x509 -in test.crt -outform der | sha256sum | awk '{print $1}' > test.der.sha256
openssl pkcs12 -export -inkey test.key -in test.crt -passout "pass:1234567890" -out test.p12

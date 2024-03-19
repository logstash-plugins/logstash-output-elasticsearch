#!/usr/bin/env bash

set -e
cd "$(dirname "$0")"

openssl x509 -x509toreq -copy_extensions copyall -in ca.crt -signkey ca.key -out ca.csr
openssl x509 -req -copy_extensions copyall -days 365 -in ca.csr -set_serial 0x01 -signkey ca.key -out ca.crt && rm ca.csr

openssl x509 -x509toreq -copy_extensions copyall -in test.crt -signkey test.key -out test.csr
openssl x509 -req -copy_extensions copyall -days 365 -in test.csr -set_serial 0x01 -CA ca.crt -CAkey ca.key -out test.crt && rm test.csr
openssl pkcs12 -export -inkey test.key -in test.crt -passout "pass:1234567890" -out test.p12

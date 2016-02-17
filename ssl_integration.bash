#!/bin/bash -x

ES_HOME=`pwd`/elasticsearch
CONF_DIR=$ES_HOME/conf

curl -s https://download.elasticsearch.org/elasticsearch/release/org/elasticsearch/distribution/tar/elasticsearch/2.2.0/elasticsearch-2.2.0.tar.gz  > elasticsearch.tar.gz
mkdir elasticsearch && tar -xzf elasticsearch.tar.gz --strip-components=1 -C ./elasticsearch/.
ln -sn ../../spec/fixtures/scripts elasticsearch/config/.
cd elasticsearch
./bin/plugin install license
./bin/plugin install shield


./bin/shield/esusers useradd $LS_USER -p $LS_PASSWORD -r admin

cd config/shield
### CERTIFICATE SETUP ###
KEYSTORE=keystore.jks
TRUSTSTORE=truststore.jks
TRUSTORE_PATH=$(cd $(dirname "$TRUSTSTORE") && pwd -P)/$(basename "$TRUSTSTORE")
KEYSTORE_PATH=$(cd $(dirname "$KEYSTORE") && pwd -P)/$(basename "$KEYSTORE")
### CACERT SETUP ###
(
cat <<EOF
-----BEGIN CERTIFICATE-----
MIIDcjCCAtugAwIBAgIJAKEMahwWILoNMA0GCSqGSIb3DQEBBQUAMIGDMR8wHQYD
VQQKExZFbGFzdGljc2VhcmNoIFRlc3QgT3JnMSswKQYJKoZIhvcNAQkBFhxqb2Fv
ZHVhcnRlQGVsYXN0aWNzZWFyY2guY29tMRIwEAYDVQQHEwlBbXN0ZXJkYW0xEjAQ
BgNVBAgTCUFtc3RlcmRhbTELMAkGA1UEBhMCTkwwHhcNMTQxMDEzMTY0NjA1WhcN
MTUxMDEzMTY0NjA1WjCBgzEfMB0GA1UEChMWRWxhc3RpY3NlYXJjaCBUZXN0IE9y
ZzErMCkGCSqGSIb3DQEJARYcam9hb2R1YXJ0ZUBlbGFzdGljc2VhcmNoLmNvbTES
MBAGA1UEBxMJQW1zdGVyZGFtMRIwEAYDVQQIEwlBbXN0ZXJkYW0xCzAJBgNVBAYT
Ak5MMIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC9et5ZI3YjxlV6e1HTIQyo
qANdUIRmHIPrnRChOBgKIZyPAK33dJdbWL/VpDFGOb67OL4OmArU9mzcRKSChsEY
h0S/yTNpOQRfflOx2azKXwhAG+05PWznzXeHNwx3yXbD+u/zPGc2xfecViiYG3bU
Rdx2mWCg40GFza+kLuo0NwIDAQABo4HrMIHoMAwGA1UdEwQFMAMBAf8wHQYDVR0O
BBYEFOOqOqqBOdw00+f9h29EtqOxzmywMIG4BgNVHSMEgbAwga2AFOOqOqqBOdw0
0+f9h29EtqOxzmywoYGJpIGGMIGDMR8wHQYDVQQKExZFbGFzdGljc2VhcmNoIFRl
c3QgT3JnMSswKQYJKoZIhvcNAQkBFhxqb2FvZHVhcnRlQGVsYXN0aWNzZWFyY2gu
Y29tMRIwEAYDVQQHEwlBbXN0ZXJkYW0xEjAQBgNVBAgTCUFtc3RlcmRhbTELMAkG
A1UEBhMCTkyCCQChDGocFiC6DTANBgkqhkiG9w0BAQUFAAOBgQBxfykQOgZbXa7X
/WyEKbvh4on1APNbol1i11zFd9xUw0u/uPthm+Whw/fQyI8NvotQEcmxV9EPkwUD
BlViqwcjQEkO7+rNIK28x4TIFXCUdirlp8UqG5+zJu7CeOImOLTDZbNnc3rPG9dn
ORILJeJS33Hve4ZaYHGsi/+IUz2nUA==
-----END CERTIFICATE-----
EOF
) > cacert.pem
mkdir -p /tmp/ca/certs
cp cacert.pem /tmp/ca/certs/cacert.pem
openssl x509 -outform der -in cacert.pem -out cacert.der
keytool -import -keystore truststore.jks -file cacert.der -storepass testeteste -noprompt
### LOCALHOST NODE CERT SETUP ###
(
cat <<EOF
Certificate:
    Data:
        Version: 1 (0x0)
        Serial Number: 3 (0x3)
        Signature Algorithm: sha1WithRSAEncryption
        Issuer: O=Elasticsearch Test Org/emailAddress=joaoduarte@elastic.co, L=Amsterdam, ST=Amsterdam, C=NL
        Validity
            Not Before: Jan  8 18:07:52 2015 GMT
            Not After : Jan  8 18:07:52 2016 GMT
        Subject: C=NL, ST=Amsterdam, O=Elasticsearch Test Org, CN=localhost
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
            RSA Public Key: (1024 bit)
                Modulus (1024 bit):
                    00:9c:93:0f:af:83:88:06:3a:3c:46:77:f9:76:ce:
                    f5:e2:ec:1b:9b:9e:bc:90:99:99:76:0f:c9:d8:56:
                    f0:25:93:ba:0f:29:4c:52:e4:0e:c0:82:04:7d:ca:
                    fd:27:98:24:fa:25:51:d5:7b:84:73:8e:29:fe:28:
                    2f:b1:e7:a2:1b:14:64:c0:ac:2f:9c:72:29:ee:1f:
                    b6:06:dd:73:1b:36:6e:62:a0:c6:df:52:52:da:c9:
                    8f:ea:83:61:25:41:25:8e:5d:28:bc:ea:0e:44:d5:
                    01:d7:12:03:ea:e2:ab:8e:2b:4b:4a:4b:16:0f:cc:
                    53:b5:bf:b1:94:97:71:67:27
                Exponent: 65537 (0x10001)
    Signature Algorithm: sha1WithRSAEncryption
        09:ab:e4:d1:ac:37:18:16:e1:ee:d0:00:b8:be:b0:57:b7:0b:
        f4:ca:ac:c2:fa:f1:d7:a4:63:58:e4:60:68:4d:4e:d6:a5:08:
        d9:2b:5b:9a:24:28:c5:d1:d7:ce:df:32:cb:94:3b:ea:54:7c:
        bc:80:39:fa:6b:ff:de:c6:cb:84:3b:3e:42:79:57:e8:6f:62:
        6f:fa:ca:a7:14:dd:60:bc:58:5e:cd:84:8c:83:1a:88:c5:96:
        02:cb:78:a6:86:f5:8f:51:00:a3:8c:d5:91:9b:e7:2e:c9:77:
        22:98:2d:99:30:0c:80:8a:26:dc:10:61:5d:27:52:c2:1b:e1:
        3b:aa
-----BEGIN CERTIFICATE-----
MIICSTCCAbICAQMwDQYJKoZIhvcNAQEFBQAwgYMxHzAdBgNVBAoTFkVsYXN0aWNz
ZWFyY2ggVGVzdCBPcmcxKzApBgkqhkiG9w0BCQEWHGpvYW9kdWFydGVAZWxhc3Rp
Y3NlYXJjaC5jb20xEjAQBgNVBAcTCUFtc3RlcmRhbTESMBAGA1UECBMJQW1zdGVy
ZGFtMQswCQYDVQQGEwJOTDAeFw0xNTAxMDgxODA3NTJaFw0xNjAxMDgxODA3NTJa
MFYxCzAJBgNVBAYTAk5MMRIwEAYDVQQIEwlBbXN0ZXJkYW0xHzAdBgNVBAoTFkVs
YXN0aWNzZWFyY2ggVGVzdCBPcmcxEjAQBgNVBAMTCWxvY2FsaG9zdDCBnzANBgkq
hkiG9w0BAQEFAAOBjQAwgYkCgYEAnJMPr4OIBjo8Rnf5ds714uwbm568kJmZdg/J
2FbwJZO6DylMUuQOwIIEfcr9J5gk+iVR1XuEc44p/igvseeiGxRkwKwvnHIp7h+2
Bt1zGzZuYqDG31JS2smP6oNhJUEljl0ovOoORNUB1xID6uKrjitLSksWD8xTtb+x
lJdxZycCAwEAATANBgkqhkiG9w0BAQUFAAOBgQAJq+TRrDcYFuHu0AC4vrBXtwv0
yqzC+vHXpGNY5GBoTU7WpQjZK1uaJCjF0dfO3zLLlDvqVHy8gDn6a//exsuEOz5C
eVfob2Jv+sqnFN1gvFhezYSMgxqIxZYCy3imhvWPUQCjjNWRm+cuyXcimC2ZMAyA
iibcEGFdJ1LCG+E7qg==
-----END CERTIFICATE-----
EOF
) > localhost.cert.pem
(
cat <<EOF
-----BEGIN RSA PRIVATE KEY-----
MIICXAIBAAKBgQCckw+vg4gGOjxGd/l2zvXi7BubnryQmZl2D8nYVvAlk7oPKUxS
5A7AggR9yv0nmCT6JVHVe4Rzjin+KC+x56IbFGTArC+ccinuH7YG3XMbNm5ioMbf
UlLayY/qg2ElQSWOXSi86g5E1QHXEgPq4quOK0tKSxYPzFO1v7GUl3FnJwIDAQAB
AoGADHbEe+NLk7tVCwMH78Y/2qWS+Qtk1Vn01mohVkBtc4BUAlr2QW74Iaj39I+R
IXLCFsubvRPNEmnRu/K1AUOAKunPZgcxC0gbHtwW5f3ln1IA8dICKcewIyIL4tOv
lxSMinjSUE9Ofkw08ZC3ePLP6AVh5xd58Xbu4u1DBAtq6vkCQQDJ0+v46MheKBRR
G6v9ao7a/SImkaQ+/eeHsuv9fspp8RA1gM+6dSG68oilYpLIx9NjIAvsZ9+Xhl7i
mnM7ocETAkEAxpmr5NWNBFWEdqG2J/C9DacjxgW9tUSeW0fgK2DFg0OnjXA5p/o3
ud685fq3uat0QO9OM3Keq2/d/wAzDUBYHQJBAL9WtOiWL5bsIk6+kDBAvEwqHR05
h9/cMIr6ejYp5NXJHxfKFaVsdFzan+dC62uD3gikkgk+dMAfOIdV65cGA5cCQEQq
9RyLzGaDb/9ETIDzGgE4sIfE6rPwhKZySli5U7JVo4phzfiBY2VSNeZ+o1eAqVus
iFwSaLIRqNJhYCSZRGUCQH9IF4B3ERNw8E9nUR0qXD4pSoT1U9BC+mGKwgQ7Oz1p
5awCHNGX1P5Osf9e1X3N/s9xMAUMeJ4PrvEV9UVwCxw=
-----END RSA PRIVATE KEY-----
EOF
) > localhost.key.pem
openssl pkcs12 -export -out localhost.pkcs12 -in localhost.cert.pem -inkey localhost.key.pem -password pass:testeteste
keytool -importkeystore -srckeystore localhost.pkcs12  -destkeystore keystore.jks -srcstoretype PKCS12 \
        -deststoretype JKS -srcstorepass testeteste -deststorepass testeteste
keytool -import -keystore $KEYSTORE -file cacert.der -storepass testeteste -noprompt
cd ../..
### SETUP ELASTICSEARCH CONFIG ###
(
cat <<EOF
cluster.name: $CLUSTER_NAME
node.name: localhost
http.port: 9200
shield.transport.ssl: false
shield.http.ssl: true
network.host: localhost
shield.audit.enabled: false
shield.transport.ssl.truststore.path.: $TRUSTORE_PATH
shield.transport.ssl.truststore.password: testeteste
shield.ssl.keystore.path: $KEYSTORE_PATH
shield.ssl.keystore.password: testeteste
discovery.zen.ping:
  multicast.ping.enabled: false
  unicast.hosts: "localhost:9300"
transport.profiles.client.shield.ssl.client.auth: false
shield.authc:
  anonymous:
    username: anonymous_user
    roles: admin
    authz_exception: true
EOF
) >> config/elasticsearch.yml

bin/elasticsearch -Des.script.inline=on -Des.path.home=`pwd` -Des.script.indexed=on &
sleep 20 && curl --cacert ./config/shield/localhost.cert.pem https://$LS_USER:$LS_PASSWORD@localhost:9200

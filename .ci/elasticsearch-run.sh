#!/bin/bash
set -ex

/usr/share/elasticsearch/bin/elasticsearch -Ediscovery.type=single-node -Eaction.destructive_requires_name=false
#/usr/share/elasticsearch/bin/elasticsearch -Expack.security.enabled=false -Ediscovery.type=single-node -Eaction.destructive_requires_name=false

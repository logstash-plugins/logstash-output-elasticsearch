#!/bin/sh
mkdir -p /tmp/nginx

if [ ! -f spec/fixtures/server.key ] || [ ! -f spec/fixtures/server.crt ]; then
	openssl req -x509 -batch -nodes -newkey rsa:2048 -keyout spec/fixtures/server.key -out spec/fixtures/server.crt -days 365 -subj /CN=localhost
fi

sudo -u www-data /usr/bin/env nginx -c $(pwd)/spec/fixtures/nginx_reverse_proxy.conf

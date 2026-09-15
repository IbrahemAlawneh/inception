#!/bin/bash

set -e

mkdir -p /etc/ssl/web/certs
mkdir -p /etc/ssl/web/private

if [ ! -f /etc/ssl/web/certs/pub.crt ]; then
    openssl req -x509 -nodes -days 365 \
    -newkey rsa:2048 \
    -keyout /etc/ssl/web/private/pri.key \
    -out /etc/ssl/web/certs/pub.crt \
    -subj "/C=JO/ST=Amman/L=Amman/O=42/CN=${DOMAIN_NAME}"
fi



exec nginx -g "daemon off;"
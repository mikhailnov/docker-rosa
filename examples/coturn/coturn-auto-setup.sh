#!/bin/sh
set -x
set -e
certbot certonly --standalone --non-interactive --preferred-challenges http -d "$(hostname)" --email mikhailnov@dumalogiya.ru --agree-tos -n
touch /var/lib/letsencrypt/.inited_coturn-auto-setup

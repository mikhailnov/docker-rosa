#!/bin/sh
set -e
certbot certonly --standalone --non-interactive --preferred-challenges http -d "$(hostname)" --email mikhailnov@dumalogiya.ru --agree-tos -n
rm -fv /var/lib/coturn/.notinited

#!/bin/sh
set -e
set -u
set +f
# /var/lib/coturn must already exist and me mounted r/w
cp -v /etc/letsencrypt/live/*/{fullchain.pem,privkey.pem} /var/lib/coturn/certs
chown -R coturn:coturn /var/lib/coturn/certs
chmod -R 0600 /var/lib/coturn/certs
systemctl kill -sUSR2 coturn.service 

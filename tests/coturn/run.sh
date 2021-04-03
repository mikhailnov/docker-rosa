#!/bin/sh
# Example how to run this container

# in reality this must be a permanent storage, not tmpfs,
# e.g. a snapshottable btrfs subvolume
mkdir -p /run/coturn-container/certs
mkdir -p /run/coturn-container/live
mkdir -p /run/coturn-container/certbot-logs

# https://github.com/systemd/systemd/issues/19192
systemd-nspawn \
	--image="$(ls -t *.sqfs | head -n1)"  \
	--timezone=bind \
	--bind=/run/coturn-container/certs:/var/lib/coturn/certs \
	--bind=/run/coturn-container/live:/etc/letsencrypt/live \
	--bind=/run/coturn-container/certbot-logs:/var/log/letsencrypt \
	--bind=+/run/systemd:/var/lib/systemd \
	--private-users=1100000 \
	--boot

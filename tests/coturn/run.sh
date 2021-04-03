#!/bin/sh
# Example how to run this container

# in reality this must be a permanent storage, not tmpfs,
# e.g. a snapshottable btrfs subvolume
mkdir -p /run/coturn-container/certs
mkdir -p /run/coturn-container/live

systemd-nspawn \
	--image="$(ls -t *.sqfs | head -n1)"  \
	--bind=/run/coturn-container/certs:/var/lib/coturn/certs \
	--bind=/run/coturn-container/live:/etc/letsencrypt/live \
	--private-users=1100000 \
	--boot

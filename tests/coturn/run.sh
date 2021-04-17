#!/bin/sh
# Example how to run this container

private_users_offset=1100000

mount_dir_tmp="$(mktemp -d)"

_umount_tmp(){
	umount "$mount_dir_tmp" || :
	rmdir "$mount_dir_tmp" || :
}
trap '_umount_tmp 2>/dev/null' EXIT

SQFS="$(ls -t *.sqfs | head -n1)"
mount -o loop "$SQFS" "$mount_dir_tmp"
coturn_uid="$(grep '^coturn:' "$mount_dir_tmp"/etc/passwd | awk -F ':' '{print $3}')"
coturn_gid="$(grep '^coturn:' "$mount_dir_tmp"/etc/passwd | awk -F ':' '{print $4}')"
[ -n "$coturn_uid" ]
[ -n "$coturn_gid" ]
private_coturn_uid="$((${private_users_offset}+${coturn_uid}))"
private_coturn_gid="$((${private_users_offset}+${coturn_gid}))"
[ -n "$private_coturn_uid" ]
[ -n "$private_coturn_gid" ]

# in reality this must be a permanent storage, not tmpfs,
# e.g. a snapshottable btrfs subvolume
mkdir -p /run/coturn-container/certs
mkdir -p /run/coturn-container/live
mkdir -p /run/coturn-container/certbot-logs
mkdir -p /run/coturn-container/etc-letsencrypt
mkdir -p /run/coturn-container/var-lib-letsencrypt

# https://github.com/systemd/systemd/issues/19195
chown -R ${private_users_offset}:${private_users_offset} /run/coturn-container

if [ ! -f /run/coturn-container/turndb ]; then
	# copy default DB
	cp -v "$mount_dir_tmp"/var/lib/coturn/turndb /run/coturn-container/turndb
fi
_umount_tmp

chown ${private_coturn_uid}:${private_coturn_gid} /run/coturn-container/turndb

# https://github.com/systemd/systemd/issues/19192
systemd-nspawn \
	--image="$SQFS"  \
	--timezone=bind \
	--bind=/run/coturn-container/certs:/var/lib/coturn/certs \
	--bind=/run/coturn-container/live:/etc/letsencrypt/live \
	--bind=/run/coturn-container/certbot-logs:/var/log/letsencrypt \
	--bind=/run/coturn-container/etc-letsencrypt:/etc/letsencrypt \
	--bind=/run/coturn-container/var-lib-letsencrypt:/var/lib/letsencrypt \
	--bind=/run/coturn-container/turndb:/var/lib/coturn/turndb \
	--bind=+/run/systemd:/var/lib/systemd \
	--private-users=${private_users_offset} \
	--boot

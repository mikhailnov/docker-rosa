# for sourcing from mkimage-dnf.sh

chroot "$rootfsDir" /bin/sh -c "systemctl enable coturn.service certbot-renew.timer"
# not needed in containers
chroot "$rootfsDir" /bin/sh -c "systemctl disable fstrim.timer"

# _dnf <...>

echo "$hostname" > "$rootfsDir"/etc/hostname

cat "$dir0"/turnserver.conf > "$rootfsDir"/etc/coturn/turnserver.conf
new_auth_secret="$(libressl rand -hex 16 || openssl rand -hex 16)"
[ -n "$new_auth_secret" ]
sed -i -e "s,@AUTH_SECRET@,${new_auth_secret}," "$rootfsDir"/etc/coturn/turnserver.conf

# allow to bind to port 443
mkdir -p "$rootfsDir"/etc/systemd/system/coturn.service.d
cat > "$rootfsDir"/etc/systemd/system/coturn.service.d/override.conf << 'EOF'
[Service]
AmbientCapabilities=CAP_NET_BIND_SERVICE
EOF

mkdir -p "$rootfsDir"/etc/letsencrypt/renewal-hooks/deploy
install -m0755 "$dir0"/certbot-hook.sh "$rootfsDir"/etc/letsencrypt/renewal-hooks/deploy/coturn

install -m0755 "$dir0"/coturn-auto-setup.sh "$rootfsDir"/usr/local/bin/coturn-auto-setup
install -m0644 "$dir0"/coturn-auto-setup.service "$rootfsDir"/etc/systemd/system/coturn-auto-setup.service
chroot "$rootfsDir" /bin/sh -c "systemctl enable coturn-auto-setup.service"

# This directory will be created by first run of coturn,
# precreate it to mount it read-write
mkdir -p "$rootfsDir"/etc/letsencrypt/live
touch "$rootfsDir"/etc/letsencrypt/live/.keep
# /var/lib/coturn is empty in coturn RPM in ROSA
mkdir -p "$rootfsDir"/var/lib/coturn/certs
touch "$rootfsDir"/var/lib/coturn/certs/.keep

# set timezone, timedatectl does not work without systemd as PID 1
( cd "$rootfsDir"/etc ; ln -sf ../usr/share/zoneinfo/Europe/Moscow localtime )

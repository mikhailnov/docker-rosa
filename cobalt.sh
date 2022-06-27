#!/usr/bin/env bash
# Build rootfs of ROSA Cobalt (CentOS-based)

dnfConf="$(mktemp)"
trap 'rm -f "$dnfConf"' EXIT

arch="${arch:-x86_64}"
# 73 for 7.3, 79 for 7.9
cobaltVersion="${cobaltVersion:-73}"
rosaVersion="${rosaVersion:-cobalt${cobaltVersion}}"
enableContrib=0
enableTesting=0
# key to acccess repos on abf
repokey="${repokey:-}"
systemd_networkd=0

cat > "$dnfConf" << EOF
[main]
basearch=${arch}
keepcache=0
reposdir=/dev/null
gpgcheck=0
assumeyes=1
install_weak_deps=0
metadata_expire=1h
best=1

[base]
name=Cobalt - base - ${cobaltVersion}
baseurl=https://${repokey}@abf-downloads.rosalinux.ru/rosa-server${cobaltVersion}/repository/${arch}/base/release/
enabled=1

EOF

brandingPackages="rosa-release-server"
packagesList="\
basesystem \
bash \
yum \
rpm \
systemd \
util-linux \
curl \
wget \
htop \
nano \
iproute \
iputils \
dhcp \
sudo \
passwd"

. mkimage-dnf.sh



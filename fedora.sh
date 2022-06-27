#!/usr/bin/env bash
# Build rootfs of Fedora

dnfConf="$(mktemp)"
trap 'rm -f "$dnfConf"' EXIT

arch="${arch:-x86_64}"
# rawhide, 34, 35 etc.
fedoraVersion="${fedoraVersion:-rawhide}"
rosaVersion="${fedoraVersion}"
fedoraType="${fedoraType:-}"
if [ -z "$fedoraType" ]; then
	case "$fedoraVersion" in
		development ) fedoraType=development ;;
		* ) fedoraType=releases ;;
	esac
fi
enableContrib=0

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

[${fedoraVersion}]
name=Fedora - ${fedoraVersion}
baseurl=https://mirror.yandex.ru/fedora/linux/${fedoraType}/${fedoraVersion}/Everything//${arch}/os/
#metalink=https://mirrors.fedoraproject.org/metalink?repo=${fedoraVersion}&arch=$basearch
enabled=1

[${fedoraVersion}-modular]
name=Fedora - Modular ${fedoraVersion}
baseurl=https://mirror.yandex.ru/fedora/linux/${fedoraType}/${fedoraVersion}/Modular//${arch}/os/
#metalink=https://mirrors.fedoraproject.org/metalink?repo=${fedoraVersion}-modular&arch=$basearch
enabled=1
EOF

brandingPackages="fedora-release-container"
packagesList="\
basesystem \
dnf \
rpm \
fedora-repos \
fedora-repos-modular \
systemd \
systemd-networkd \
util-linux \
glibc-langpack-en \
glibc-langpack-ru \
curl \
wget \
htop \
nano \
iproute \
iputils \
sudo \
passwd \
/usr/bin/chsh"

. mkimage-dnf.sh



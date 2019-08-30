#!/usr/bin/env bash
#
# Script to create Rosa Linux base images for integration with VM containers (docker, lxc , etc.).
# 
# Based on mkimage-urpmi.sh (https://github.com/juanluisbaptiste/docker-brew-mageia)
#

set -efu

if [ "$(id -u)" != "0" ]; then
	echo "Please run as root. Example: sudo ./mkimage-urpmi.sh"
	exit 1
fi

arch="${arch:-x86_64}"
imgType="${imgType:-std}"
rosaVersion="${rosaVersion:-rosa2016.1}"
outDir="${outDir:-"."}"
packagesList="${packagesList:-basesystem-minimal bash urpmi systemd initscripts termcap ncurses dhcp-client locales locales-en locales-ru git-core htop iputils iproute2 nano squashfs-tools tar timezone passwd rpm-build sudo fonts-ttf-freefont}"
addPackages="${addPackages:-""}"
brandingPackages="${brandingPackages:-branding-configs-fresh}"
if [ -n "$addPackages" ]; then packagesList="${packagesList} ${addPackages}"; fi
if [ -n "$brandingPackages" ]; then packagesList="${packagesList} ${brandingPackages}"; fi
mirror="${mirror:-http://mirror.yandex.ru/rosa}"
repo="${repo:-${mirror}/${rosaVersion}/repository/${arch}/}"
outName="${outName:-"rootfs-${imgType}-${rosaVersion}_${arch}_$(date +%Y-%m-%d)"}"
rootfsDir="${rootfsDir:-./BUILD_${outName}}"
tarFile="${outName}.tar.xz"
sqfsFile="${outName}.sqfs"
systemd_networkd="${systemd_networkd:-1}"
rootfsPackTarball="${rootfsPackTarball:-1}"
rootfsPackSquash="${rootfsPackSquash:-1}"
rootfsXzCompressLevel="${rootfsXzCompressLevel:-6}"
rootfsXzThreads="${rootfsXzThreads:-0}"
clean_rootfsDir="${clean_rootfsDir:-1}"

# Ensure that rootfsDir from previous build will not be reused
if [ "$clean_rootfsDir" = 1 ]; then
	umount "${rootfsDir}/dev" || :
	rm -fr "$rootfsDir"
fi

urpmi.addmedia --distrib \
	--mirrorlist "$repo" \
	--urpmi-root "$rootfsDir"

#########################################################
# try to workaround urpmi bug due to which it randomly
# can't resolve dependencies during bootstrap
urpmi_bootstrap(){
	for urpmi_options in \
		"--auto --no-suggests --allow-force --allow-nodeps --ignore-missing" \
		"--auto --no-suggests"
	do
		urpmi --urpmi-root "$rootfsDir" \
			${urpmi_options} \
			${packagesList}
		urpmi_return_code="$?"
	done
}
# temporarily don't fail the whole scripts when not last iteration of urpmi fails
set +e
for i in $(seq 1 10)
do
	urpmi_bootstrap
	if [ "${urpmi_return_code}" = 0 ]; then
		echo "urpmi iteration #${i} was successfull."
		break
	fi
done
# now check the return code of the _last_ urpmi iteration
if [ "${urpmi_return_code}" != 0 ]; then
	echo "urpmi bootstrapping failed!"
	exit 1
fi
# return failing the whole script on any error
set -e
#########################################################

  pushd "$rootfsDir"
  
  # Clean 
	#  urpmi cache
	rm -rf var/cache/urpmi
	mkdir -p --mode=0755 var/cache/urpmi
	rm -rf etc/ld.so.cache var/cache/ldconfig
	mkdir -p --mode=0755 var/cache/ldconfig
 popd

# make sure /etc/resolv.conf has something useful in it
mkdir -p "$rootfsDir/etc"
cat > "$rootfsDir/etc/resolv.conf" <<'EOF'
nameserver 8.8.8.8
nameserver 77.88.8.8
nameserver 8.8.4.4
nameserver 77.88.8.1
EOF

# Fix SSL in chroot (/dev/urandom is needed)
mount --bind -v -o ro /dev "${rootfsDir}/dev"
# Let's make sure that all packages have been installed
chroot "$rootfsDir" /bin/sh -c "urpmi ${packagesList} --auto --no-suggests --clean"

# Try to configure root shell
# package 'initscripts' contains important scripts from /etc/profile.d/
# package 'termcap' containes /etc/termcap which allows the console to work properly
chroot "$rootfsDir" /bin/sh -c "chsh --shell /bin/bash root"
if [ ! -d "${rootfsDir}/root" ]; then mkdir -p "${rootfsDir}/root"; fi
while read -r line
do
	cp -vp "${rootfsDir}/${line}" "${rootfsDir}/root/"
done < <(chroot "$rootfsDir" /bin/sh -c 'rpm -ql bash | grep ^/etc/skel')

# clean-up
for i in dev sys proc; do
	umount "${rootfsDir}/${i}" || :
	rm -fr "${rootfsDir:?}/${i:?}/*"
done

# systemd-networkd makes basic network configuration automatically
# After it, you can either make /etc/systemd/network/*.conf or
# `systemctl enable dhclient@eth0`, where eth0 is your network interface from `ip a`
if [ "$systemd_networkd" != 0 ]; then
	chroot "$rootfsDir" /bin/sh -c "systemctl enable systemd-networkd"
fi

# disable pam_securetty to allow logging in as root via `systemd-nspawn -b`
# https://bugzilla.rosalinux.ru/show_bug.cgi?id=9631
# https://github.com/systemd/systemd/issues/852
if grep -q 'pam_securetty.so' "${rootfsDir}/etc/pam.d/login"; then
	sed -e '/pam_securetty.so/d' -i "${rootfsDir}/etc/pam.d/login"
fi

( set -x
if [ "$rootfsPackTarball" != 0 ]; then
	env XZ_OPT="-${rootfsXzCompressLevel} --threads=${rootfsXzThreads} -v" \
		tar cJf "${outDir}/${tarFile}" --numeric-owner --transform='s,^./,,' --directory="$rootfsDir" .
	ln -sf "$tarFile" "./rootfs.tar.xz" || :
fi
if [ "$rootfsPackSquash" != 0 ]; then
	mksquashfs "$rootfsDir" "${outDir}/${sqfsFile}" -comp xz
fi

rm -rf "$rootfsDir"
)

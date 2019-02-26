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
rootfsDir="${rootfsDir:-./BUILD_rootfs}" 
outDir="${outDir:-"."}"
packagesList="${packagesList:-basesystem-minimal bash urpmi systemd initscripts termcap dhcp-client locales locales-en git-core htop iputils iproute2 nano squashfs-tools tar timezone passwd branding-configs-fresh rpm-build}"
mirror="${mirror:-http://mirror.yandex.ru/rosa/${rosaVersion}/repository/${arch}/}"
outName="${outName:-"rootfs-${imgType}-${rosaVersion}_${arch}_$(date +%Y-%m-%d)"}"
tarFile="${outDir}/${outName}.tar.xz"
sqfsFile="${outDir}/${outName}.sqfs"

urpmi.addmedia --distrib \
	--mirrorlist "$mirror" \
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
mount --bind -v /dev "${rootfsDir}/dev"
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
chroot "$rootfsDir" /bin/sh -c "systemctl enable systemd-networkd"

# disable pam_securetty to allow logging in as root via `systemd-nspawn -b`
# https://bugzilla.rosalinux.ru/show_bug.cgi?id=9631
# https://github.com/systemd/systemd/issues/852
sed -e '/pam_securetty.so/d' -i "${rootfsDir}/etc/pam.d/login"

touch "$tarFile"

(
        set -x
        pushd "$rootfsDir"
			env XZ_OPT="-9 --threads=0 -v" \
			tar cJf "../${tarFile}" --numeric-owner --transform='s,^./,,' .
        popd
        ln -s "$tarFile" "./rootfs.tar.xz" || :
        mksquashfs "$rootfsDir" "$sqfsFile" -comp xz
        
)

( set -x; rm -rf "$rootfsDir" )

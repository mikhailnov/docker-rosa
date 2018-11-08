#!/usr/bin/env bash
#
# Script to create Rosa Linux base images for integration with VM containers (docker, lxc , etc.).
# 
# Based on mkimage-urpmi.sh (https://github.com/juanluisbaptiste/docker-brew-mageia)
#

#TIME="${TIME:-5}"
arch="${arch:-x86_64}"
rosaVersion="${rosaVersion:-rosa2016.1}"
rootfsDir="${rootfsDir:-./BUILD_rootfs}" 
outDir="${outDir:-"."}"
# branding-configs-fresh, rpm-build have problems with dependencies, so let's install them in chroot
basePackages="${basePackages:-basesystem-minimal bash urpmi locales locales-en git-core abf htop xz iputils iproute2 nano squashfs-tools tar}"
chrootPackages="${chrootPackages:-branding-configs-fresh rpm-build}"
mirror="${mirror:-http://abf-downloads.rosalinux.ru/${rosaVersion}/repository/${arch}/}"
outName="${outName:-"rootfs-${rosaVersion}_${arch}_$(date +%Y-%M-%d)"}"
tarFile="${outDir}/${outName}.tar.xz"
sqfsFile="${outDir}/${outName}.sqfs"

(
        urpmi.addmedia --distrib \
                --mirrorlist "$mirror" \
                --urpmi-root "$rootfsDir"
        urpmi ${basePackages} \
                --auto \
                --no-suggests \
                --urpmi-root "$rootfsDir" \
                --root "$rootfsDir"
)

  pushd "$rootfsDir"
  
  # Clean 
	#  urpmi cache
	rm -rf var/cache/urpmi
	mkdir -p --mode=0755 var/cache/urpmi
	rm -rf etc/ld.so.cache var/cache/ldconfig
	mkdir -p --mode=0755 var/cache/ldconfig
 popd
# Docker mounts tmpfs at /dev and procfs at /proc so we can remove them
rm -rf "$rootfsDir/dev" "$rootfsDir/proc"
mkdir -p "$rootfsDir/dev" "$rootfsDir/proc"

# make sure /etc/resolv.conf has something useful in it
mkdir -p "$rootfsDir/etc"
cat > "$rootfsDir/etc/resolv.conf" <<'EOF'
nameserver 8.8.8.8
nameserver 77.88.8.8
nameserver 8.8.4.4
nameserver 77.88.8.1
EOF

# Those packages, installation of which fails when they are listed in $basePackages, are installed in chroot
chroot "$rootfsDir" /bin/sh -c "urpmi ${chrootPackages} --auto"

touch "$tarFile"

(
        set -x
        tar --numeric-owner -cf - "$rootfsDir" --transform='s,^./,,' | xz --compress -9 --threads=0 - > "$tarFile"
        ln -s "$tarFile" "./rootfs.tar.xz"
        mksquashfs "$rootfsDir" "$sqfsFile" -comp xz
        
)

( set -x; rm -rf "$rootfsDir" )

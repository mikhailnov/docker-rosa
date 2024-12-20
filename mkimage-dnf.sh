#!/usr/bin/env bash

set -efu

if [ "$(id -u)" != "0" ]; then
	echo "Please run as root. Example: sudo $0"
	exit 1
fi

arch="${arch:-x86_64}"
imgType="${imgType:-std}"
rosaVersion="${rosaVersion:-rosa2021.1}"
outDir="${outDir:-"."}"
packagesList="${packagesList:-basesystem-minimal rosa-repos dnf bash systemd termcap ncurses dhcp-client locales locales-en locales-ru htop iputils iproute2 procps-ng nano tar timezone passwd sudo fonts-ttf-freefont}"
addPackages="${addPackages:-""}"
# Example: addRepos="repoName1;http://repo.url/ repoName2;http://repo.url/"
#addRepos="${addRepos:-""}"
brandingPackages="${brandingPackages:-distro-release}"
if [ -n "$addPackages" ]; then packagesList="${packagesList} ${addPackages}"; fi
if [ -n "$brandingPackages" ]; then packagesList="${packagesList} ${brandingPackages}"; fi
dnfDisableDocs="${dnfDisableDocs:-0}"
dnfCache="${dnfCache:-0}"
dnfCacheLocation="${dnfCacheLocation:-/var/cache/dnf-rootfs}"
# rpm verbosity: print what is happening during operations with packages
rpmVerbose="${rpmVerbose:-0}"
# auth token, example: xxx@ -> http://xxx@abf-downloads.rosalinux.ru
repokey="${repokey:-""}"
if [ "$rosaVersion" = "rosa2019.05" ] && [ -z "$repokey" ] ; then
	# $TOKEN is set by abf
	repokey="${TOKEN}@"
fi
mirror="${mirror:-http://${repokey}abf-downloads.rosalinux.ru}"
repo="${repo:-${mirror}/${rosaVersion}/repository/${arch}/}"
enableContrib="${enableContrib:-1}"
enableTesting="${enableTesting:-0}"
enableUpdates="${enableUpdates:-0}"
if [ "$rosaVersion" = "rosa2019.05" ]; then
	# There is no contrib in certified distros
	enableContrib=0
	# both release and updates
	enableUpdates=1
fi
if [ "$enableContrib" -gt 0 ] && [[ "$packagesList" =~ .*rosa-repos.* ]] ; then
	packagesList="${packagesList} rosa-repos-contrib"
fi
if [ "$enableTesting" -gt 0 ] && [ "$rosaVersion" != "rosa2019.05" ] && [[ "$packagesList" =~ .*rosa-repos.* ]] ; then
	packagesList="${packagesList} rosa-repos-testing"
fi
addRepos="${addRepos:-}"
outName="${outName:-"rootfs-${imgType}-${rosaVersion}_${arch}_$(date +%Y-%m-%d)"}"
rootfsDir="${rootfsDir:-./BUILD_${outName}}"
tarFile="${outName}.tar.xz"
sqfsFile="${outName}.sqfs"
ext4File="${outName}.ext4"
systemd_networkd="${systemd_networkd:-1}"
rootfsPackTarball="${rootfsPackTarball:-1}"
rootfsPackSquash="${rootfsPackSquash:-0}"
rootfsPackExt4="${rootfsPackExt4:-0}"
rootfsExt4size="${rootfsExt4size:-2048}"
rootfsExt4compress="${rootfsExt4compress:-1}"
rootfsXzCompressLevel="${rootfsXzCompressLevel:-6}"
rootfsXzThreads="${rootfsXzThreads:-0}"
rootfsSquashCompressAlgo="${rootfsSquashCompressAlgo:-xz}"
rootfsSquashBlockSize="${rootfsSquashBlockSize:-512K}"
clean_rootfsDir="${clean_rootfsDir:-1}"
# useful for systemd-nspawn --private-users=$privateUsersOffset
privateUsersOffset="${privateUsersOffset:-0}"
# See also: https://github.com/systemd/systemd/issues/18276
# /dev/null is required for many scriptlets
mountDev="${mountDev:-1}"
# See also: https://github.com/systemd/systemd/issues/18276
mountProc="${mountProc:-1}"
# Source custom script to make custom changes before creating the roots,
# e.g. pre-create a sysusers.d(5) config with needed UIDs and GIDs
customScriptPreInstall="${customScriptPreInstall:-}"
# Source custom script, e.g. to tweak configs etc. when packing
# a rootfs for a specific usesace, e.g. container with webserver
customScriptPrePack="${customScriptPrePack:-}"
nproc="${nproc:-$(nproc)}"

dnfConf="${dnfConf:-}"
dnf_conf_tmp="$(mktemp)"
trap 'rm -f "$dnf_conf_tmp"' EXIT

_dnf(){
	local dnf_opts=""
	if [ "$dnfDisableDocs" = 1 ]; then
		dnf_opts="--nodocs"
	fi
	if [ "$rpmVerbose" = 1 ]; then
		dnf_opts="--setopt=rpmverbosity=debug"
	fi
	dnf \
		--config "$dnf_conf_tmp" \
		--releasever "$rosaVersion" \
		--installroot "$dnf_rootfsDir" \
		--forcearch="$arch" \
		${dnf_opts} \
		$*
}

_main(){
	# Ensure that rootfsDir from previous build will not be reused
	if [ "$clean_rootfsDir" = 1 ]; then
		umount "${rootfsDir}/dev" || :
		umount "${rootfsDir}/sys" || :
		umount "${rootfsDir}/proc" || :
		umount "${rootfsDir}/var/cache/dnf" || :
		umount "${outDir}/BUILD_ext4" || :
		rm -fr "$rootfsDir"
	fi
	if [ "$dnfCache" = 1 ]; then
		mkdir -p "${rootfsDir}/var/cache/dnf"
		mkdir -p "$dnfCacheLocation"
		mount --bind "$dnfCacheLocation" "${rootfsDir}/var/cache/dnf"
	fi
	if [ -z "$dnfConf" ]
	then
		cat << EOF > "$dnf_conf_tmp"
[main]
reposdir=/dev/null
gpgcheck=0
assumeyes=1
install_weak_deps=0
metadata_expire=1h
best=1
keepcache=${dnfCache}
cachedir=/var/cache/dnf

[${rosaVersion}_main_release]
name=${rosaVersion}_main_release
baseurl=${repo}/main/release
gpgcheck=0
enabled=1
EOF
	else
		cat "$dnfConf" > "$dnf_conf_tmp"
	fi

	if [ "$enableContrib" -gt 0 ]; then
		cat << EOF >> "$dnf_conf_tmp"
[${rosaVersion}_contrib_release]
name=${rosaVersion}_contrib_release
baseurl=${repo}/contrib/release
gpgcheck=0
enabled=1
EOF
	fi

	if [ "$enableTesting" -gt 0 ]; then
		cat << EOF >> "$dnf_conf_tmp"
[${rosaVersion}_main_testing]
name=${rosaVersion}_main_testing
baseurl=${repo}/main/testing
gpgcheck=0
enabled=1
EOF
	fi
	if [ "$enableTesting" -gt 0 ] && [ "$enableContrib" -gt 0 ]; then
		cat << EOF >> "$dnf_conf_tmp"
[${rosaVersion}_contrib_testing]
name=${rosaVersion}_contrib_testing
baseurl=${repo}/contrib/testing
gpgcheck=0
enabled=1
EOF
	fi

	if [ "$enableUpdates" -gt 0 ]; then
		cat << EOF >> "$dnf_conf_tmp"
[${rosaVersion}_main_updates]
name=${rosaVersion}_main_updates
baseurl=${repo}/main/updates
gpgcheck=0
enabled=1
EOF
	fi

	if [ -n "$addRepos" ]; then
		for url in $addRepos
		do
			md5="$(echo "$url" | rev | md5sum | head -c6)"
			cat << EOF >> "$dnf_conf_tmp"
[${md5}]
name=${md5}
baseurl=${url}
gpgcheck=0
enabled=1
EOF
		done
	fi

	mkdir -p "$rootfsDir"
	if [ -d "./${rootfsDir}" ]
		then
			dnf_rootfsDir="${PWD}/${rootfsDir}"
		else
			if [ -d "$rootfsDir" ]
				then
					dnf_rootfsDir="$rootfsDir"
				else
					echo "Cannot convert path $rootfsDir to an absolute path!"
			fi
	fi

	if [ "$mountDev" != 0 ]; then
		mkdir -p "${rootfsDir}/dev"
		mount -t devtmpfs devtmpfs "${rootfsDir}/dev"
	fi
	if [ "$mountProc" != 0 ]; then
		mkdir -p "${rootfsDir}/proc"
		mount -t proc proc "${rootfsDir}/proc"
	fi

	if [ -n "$customScriptPreInstall" ]; then
		. "$customScriptPreInstall"
	fi
		
	_dnf install ${packagesList}
	if [ "$dnfCache" = 0 ]; then
		rm -fr "${rootfsDir}/var/cache/dnf"
	fi
	# allow to exclude bash from list of packages
	if [ -x "${rootfsDir}/bin/bash" ] && [ -x "${rootfsDir}/usr/bin/chsh" ]; then
		chroot "$rootfsDir" /bin/sh -c "chsh --shell /bin/bash root"
	fi

	# make sure /etc/resolv.conf has something useful in it
	rm -f "${rootfsDir}/etc/resolv.conf"
	cat << 'EOF' > "${rootfsDir}/etc/resolv.conf"
nameserver 8.8.8.8
nameserver 77.88.8.8
nameserver 8.8.4.4
nameserver 77.88.8.1
EOF
	# systemd-networkd makes basic network configuration automatically
	# After it, you can either make /etc/systemd/network/*.conf or
	# `systemctl enable dhclient@eth0`, where eth0 is your network interface from `ip a`
	if [ "$systemd_networkd" != 0 ] && [ -x "${rootfsDir}/usr/bin/systemctl" ]; then
		chroot "$rootfsDir" /bin/sh -c "systemctl enable systemd-networkd"
		# make DNS resolution also work out of the box
		chroot "$rootfsDir" /bin/sh -c "systemctl enable systemd-resolved"
		# network.service is generated by systemd-sysv-generator from /etc/rc.d/init.d/network
		chroot "$rootfsDir" /bin/sh -c "systemctl mask network.service"
	fi

	# make root login without password out of the box
	if [ -x "${rootfsDir}/usr/bin/passwd" ]; then
		chroot "$rootfsDir" /bin/sh -c "passwd -d root"
	fi

	# disable pam_securetty to allow logging in as root via `systemd-nspawn -b`
	# https://bugzilla.rosalinux.ru/show_bug.cgi?id=9631
	# https://github.com/systemd/systemd/issues/852
	# pam_securetty was removed by default in PAM in rosa2021.1
	if grep -q 'pam_securetty.so' "${rootfsDir}/etc/pam.d/login"; then
		sed -e '/pam_securetty.so/d' -i "${rootfsDir}/etc/pam.d/login"
	fi

	if [ -n "$customScriptPrePack" ]; then
		. "$customScriptPrePack"
	fi

	if [ "$mountProc" != 0 ]; then
		umount "${rootfsDir}/proc"
	fi

	if [ "$mountDev" != 0 ]; then
		umount "${rootfsDir}/dev"
	fi

	if [ "$dnfCache" = 1 ]; then
		umount "${rootfsDir}/var/cache/dnf"
	fi

	# useful for systemd-nspawn --private-users=$privateUsersOffset
	if [ "$privateUsersOffset" != 0 ]; then
		# such ownership of the root directory is needed to not confuse mksquashfs
		chown "${privateUsersOffset}:${privateUsersOffset}" "$rootfsDir"
		cat "$rootfsDir"/etc/passwd | awk -F ':' '{print $3}' | sort -uh | while read -r user
		do
			new_UID=$((${user}+${privateUsersOffset}))
			# some symlinks are broken, do not fail on this
			find "$rootfsDir" -user "$user" | xargs -I'{}' -P"$nproc" chown "$new_UID" '{}' || :
		done
		cat "$rootfsDir"/etc/group | awk -F ':' '{print $3}' | sort -uh | while read -r group
		do
			new_GID=$((${group}+${privateUsersOffset}))
			find "$rootfsDir" -group "$group" | xargs -I'{}' -P"$nproc" chgrp "$new_GID" '{}' || :
		done
	fi

	( set -x
	if [ "$rootfsPackTarball" != 0 ]; then
		env XZ_OPT="-${rootfsXzCompressLevel} --threads=${rootfsXzThreads} -v" \
			tar cJf "${outDir}/${tarFile}" --numeric-owner --transform='s,^./,,' --directory="$rootfsDir" .
		ln -sf "$tarFile" "./rootfs.tar.xz" || :
	fi
	if [ "$rootfsPackSquash" != 0 ]; then
		mksquashfs "$rootfsDir" "${outDir}/${sqfsFile}" -comp "$rootfsSquashCompressAlgo" -b "$rootfsSquashBlockSize"
	fi
	if [ "$rootfsPackExt4" != 0 ]; then
		# based on https://github.com/google/syzkaller/blob/master/tools/create-image.sh
		dd if=/dev/zero of="${outDir}/${ext4File}" bs=1M seek="$rootfsExt4size" count=1
		mkfs.ext4 "${outDir}/${ext4File}"
		mkdir -p "${outDir}/BUILD_ext4"
		mount "${outDir}/${ext4File}" "${outDir}/BUILD_ext4"
		rsync -a "$rootfsDir"/ "${outDir}/BUILD_ext4"
		umount "${outDir}/BUILD_ext4"
		rmdir "${outDir}/BUILD_ext4"
		if [ "$rootfsExt4compress" != 0 ]; then
			xz -f -"${rootfsXzCompressLevel}" --threads="${rootfsXzThreads}" -v "${outDir}/${ext4File}"
		fi
	fi

	rm -rf "$rootfsDir"
	)
}

_main

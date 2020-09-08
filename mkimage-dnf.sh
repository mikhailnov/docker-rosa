#!/usr/bin/env bash

set -efu

if [ "$(id -u)" != "0" ]; then
	echo "Please run as root. Example: sudo $0"
	exit 1
fi

arch="${arch:-x86_64}"
imgType="${imgType:-std}"
rosaVersion="${rosaVersion:-rosa2019.1}"
outDir="${outDir:-"."}"
packagesList="${packagesList:-basesystem-minimal rosa-repos rosa-repos-contrib dnf bash systemd termcap ncurses dhcp-client locales locales-ru htop iputils iproute2 nano tar timezone passwd sudo fonts-ttf-freefont}"
addPackages="${addPackages:-""}"
# Example: addRepos="repoName1;http://repo.url/ repoName2;http://repo.url/"
#addRepos="${addRepos:-""}"
brandingPackages="${brandingPackages:-distro-release}"
if [ -n "$addPackages" ]; then packagesList="${packagesList} ${addPackages}"; fi
if [ -n "$brandingPackages" ]; then packagesList="${packagesList} ${brandingPackages}"; fi
mirror="${mirror:-http://abf-downloads.rosalinux.ru}"
repo="${repo:-${mirror}/${rosaVersion}/repository/${arch}/}"
outName="${outName:-"rootfs-${imgType}-${rosaVersion}_${arch}_$(date +%Y-%m-%d)"}"
rootfsDir="${rootfsDir:-./BUILD_${outName}}"
tarFile="${outName}.tar.xz"
sqfsFile="${outName}.sqfs"
systemd_networkd="${systemd_networkd:-1}"
rootfsPackTarball="${rootfsPackTarball:-1}"
rootfsPackSquash="${rootfsPackSquash:-0}"
rootfsXzCompressLevel="${rootfsXzCompressLevel:-6}"
rootfsXzThreads="${rootfsXzThreads:-0}"
rootfsSquashCompressAlgo="${rootfsSquashCompressAlgo:-xz}"
rootfsSquashBlockSize="${rootfsSquashBlockSize:-512K}"
clean_rootfsDir="${clean_rootfsDir:-1}"

_main(){
	# Ensure that rootfsDir from previous build will not be reused
	if [ "$clean_rootfsDir" = 1 ]; then
		umount "${rootfsDir}/dev" || :
		rm -fr "$rootfsDir"
	fi
	dnf_conf_tmp="$(mktemp)"
	cat << EOF > "$dnf_conf_tmp"
[main]
keepcache=0
reposdir=/dev/null
obsoletes=1
gpgcheck=0
assumeyes=1
install_weak_deps=0
metadata_expire=60s
best=1

[rosa2019.1_main_release]
name=rosa2019.1_main_release
baseurl=${repo}/main/release
gpgcheck=0
enabled=1

[rosa2019.1_main_updates]
name=rosa2019.1_main_updates
baseurl=${repo}/main/updates
gpgcheck=0
enabled=1

[rosa2019.1_contrib_release]
name=rosa2019.1_contrib_release
baseurl=${repo}/contrib/release
gpgcheck=0
enabled=1

[rosa2019.1_contrib_updates]
name=rosa2019.1_contrib_updates
baseurl=${repo}/contrib/updates
gpgcheck=0
enabled=1
EOF

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
				
		
	dnf --config "$dnf_conf_tmp" --releasever "$rosaVersion" --installroot "$dnf_rootfsDir" install ${packagesList}
	rm -fr "${rootfsDir}/var/cache/dnf"
	# allow to exclude bash from list of packages
	if [ -x "${rootfsDir}/bin/bash" ]; then
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
	if [ "$systemd_networkd" != 0 ]; then
		chroot "$rootfsDir" /bin/sh -c "systemctl enable systemd-networkd"
		# network.service is generated by systemd-sysv-generator from /etc/rc.d/init.d/network
		chroot "$rootfsDir" /bin/sh -c "systemctl mask network.service"
	fi

	# disable pam_securetty to allow logging in as root via `systemd-nspawn -b`
	# https://bugzilla.rosalinux.ru/show_bug.cgi?id=9631
	# https://github.com/systemd/systemd/issues/852
	# pam_securetty was removed by default in PAM in rosa2019.1
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
		mksquashfs "$rootfsDir" "${outDir}/${sqfsFile}" -comp "$rootfsSquashCompressAlgo" -b "$rootfsSquashBlockSize"
	fi

	rm -rf "$rootfsDir"
	)
}

_main

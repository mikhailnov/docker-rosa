#!/usr/bin/env bash
# build all possible images

_current_build(){
	ltype="${type:-undef}"
	echo ""
	echo "=== BUILDING ROOTFS: rosaVersion=$rosaVersion arch=$arch type=$ltype ==="
	echo ""
	unset ltype
}

# build minimal images
for arch in x86_64 i586
do
	export arch="$arch"
	
	for rosaVersion in rosa2016.1 rosa2014.1
	do
		_current_build
		env rosaVersion="$rosaVersion" ./mkimage-minimal.sh
	done
	
	for rosaVersion in rosa2012.1 rosa2012lts
	do
		_current_build
		env rosaVersion="$rosaVersion" ./mkimage-minimal-2012.sh
	done
	
	# build standard images only of rosa2016.1 and rosa2019.1
	unset packagesList
	_current_build
	env rosaVersion="rosa2016.1" type="std" systemd_networkd=1 ./mkimage-urpmi.sh
	_current_build
	env rosaVersion="rosa2019.1" mirror="http://abf-downloads.rosalinux.ru/" type="std" systemd_networkd=1 ./mkimage-urpmi.sh
	_current_build
	#env rosaVersion="rosa2019.0" brandingPackages="branding-configs-Nickel" mirror="http://abf-downloads.rosalinux.ru/" type="min" systemd_networkd=1 ./mkimage-urpmi.sh
done

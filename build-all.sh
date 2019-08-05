#!/usr/bin/env bash
# build all possible images

# build minimal images
for arch in i586 x86_64
do
	export arch="$arch"
	
	for rosaVersion in rosa2016.1 rosa2014.1
	do
		env rosaVersion="$rosaVersion" ./mkimage-minimal.sh
	done
	
	for rosaVersion in rosa2012.1 rosa2012lts
	do
		env rosaVersion="$rosaVersion" ./mkimage-minimal-2012.sh
	done
	
	# build standard images only of rosa2016.1 and rosa2019.1
	unset packagesList
	env rosaVersion="rosa2016.1" type="std" systemd_networkd=1 ./mkimage-urpmi.sh
	env rosaVersion="rosa2019.1" mirror="http://abf-downloads.rosalinux.ru/" type="std" systemd_networkd=1 ./mkimage-urpmi.sh
	env rosaVersion="rosa2019.0" brandingPackages="branding-configs-Nickel" mirror="http://abf-downloads.rosalinux.ru/" type="min" systemd_networkd=1 ./mkimage-urpmi.sh
done

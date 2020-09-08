#!/usr/bin/env bash
# Build these images on ABF

export outDir="/home/vagrant/results"
export rootfsXzCompressLevel=9
[ ! -d "$outDir" ] && mkdir -p "$outDir"

if ! command -v dnf 2>/dev/null >/dev/null
	then
		TYPE=urpmi
		urpmi --auto-update --auto --auto-select
		urpmi coreutils findutils sed tar urpmi perl-URPM util-linux squashfs-tools xz --auto
	else
		TYPE=dnf
		# temp
		BUILD_MAIN_IMAGE_ONLY=1
		dnf refresh
		dnf distrosync -y
		dnf install -y coreutils findutils sed tar util-linux squashfs-tools xz
fi

if [ "$BUILD_MAIN_IMAGE_ONLY" = 1 ]
	then ./mkimage-${TYPE}.sh
	else ./build-all.sh
fi

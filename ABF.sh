#!/usr/bin/env bash
# Build these images on ABF

export outDir="/home/vagrant/results"
export rootfsXzCompressLevel=9
[ ! -d "$outDir" ] && mkdir -p "$outDir"

urpmi coreutils findutils sed tar urpmi util-linux squashfs-tools xz --auto

if [ "$BUILD_MAIN_IMAGE_ONLY" = 1 ]
	then ./mkimage-urpmi.sh
	else ./build-all.sh
fi

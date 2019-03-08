#!/usr/bin/env bash
# Build these images on ABF

export outDir="/home/vagrant/results"
[ ! -d "$outDir" ] && mkdir -p "$outDir"

urpmi coreutils findutils sed tar urpmi util-linux squashfs-tools --auto
./build-all.sh

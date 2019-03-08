#!/usr/bin/env bash
# Build these images on ABF

export outDir="/home/vagrant/results"
[ ! -d "$outDir" ] && mkdir -p "$outDir"

urpmi squashfs-tools --auto
./build-all.sh

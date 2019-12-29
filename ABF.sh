#!/usr/bin/env bash
# Build these images on ABF

export outDir="/home/vagrant/results"
export rootfsXzCompressLevel=9
[ ! -d "$outDir" ] && mkdir -p "$outDir"

# Attach a repo with newer urpmi and perl-URPM which seem to not freeze randomly
# They are already in rosa2019.1 and rosa2019.1, currently in a separate repo for rosa2016.1
if [ "$(rpm --eval '%mdvver')" = 201610 ]; then
	urpmi.addmedia corp_test_personal "http://abf-downloads.rosalinux.ru/corp_test_personal/repository/rosa2016.1/$(rpm --eval '%_arch')/main/release"
fi
urpmi coreutils findutils sed tar urpmi perl-URPM util-linux squashfs-tools xz --auto

if [ "$BUILD_MAIN_IMAGE_ONLY" = 1 ]
	then ./mkimage-urpmi.sh
	else ./build-all.sh
fi

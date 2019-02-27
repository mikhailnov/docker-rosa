#!/usr/bin/env bash
# Build these images on ABF

export outDir="/home/vagrant/results"
[ ! -d "$outDir" ] && mkdir -p "$outDir"


# TODO: remove this when build host becomes rosa2016.1 instead of rosa2012.1
# urpmi and dependencies, backported from rosa2016.1 to rosa2012.1,
# to use newer urpmi for bootstrapping, because older urpmi
# adds repositories from mirror incorrectly
urpmi.addmedia mikhailnov_test_personal \
	"http://abf-downloads.rosalinux.ru/mikhailnov_test_personal/repository/rosa$(rpm --eval %rosa_release)/x86_64/main/release"
urpmq --list-url
urpmi --auto-update --auto --auto-select
# check that newer urpmi has been installed
if [ "$(rpm -q --qf="%{VERSION}" urpmi | sed -e 's,\.,,g')" -ge 8035 ] && \
[ "$(urpmi --version | awk '{print $2}' | sed -e 's,\.,,g')" -ge 8035 ]
# bash/sh can't compare non-integer values, so remove dots
	then echo "urpmi is >= 8.03.5, that's OK"
	else echo "urpmi is not >= 8.03.5, error!"; exit 1
fi

urpmi squashfs-tools --auto
./build-all.sh

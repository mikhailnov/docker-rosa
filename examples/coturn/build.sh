#!/bin/bash
# build a container with rosa2021.1 and coturn

set -x

# let's give 100 000 users to one container,
# the next container must start with 1200000
privateUsersOffset="1100000"
addPackages="coturn certbot hostname"
enableContrib="1"
systemd_networkd="0"
rootfsSquashCompressAlgo="zstd"
rootfsPackTarball="0"
rootfsPackSquash="1"
imgType="coturn"
customScriptPrePack="$PWD/prepack.sh"

# for prepack.sh
hostname="${hostname:-coturn1.example.tld}"
dir0="$PWD"

. ../../mkimage-dnf.sh

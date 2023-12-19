#!/bin/bash
# build a container with rosa2021.1 and coturn

set -x

arch="x86_64"
addPackages+=" task-kernel"
addPackages+=" openssh-server"
addPackages+=" curl"
addPackages+=" glibc-devel"
addPackages+=" tar"
addPackages+=" gcc"
addPackages+=" time"
addPackages+=" strace"
addPackages+=" sudo"
addPackages+=" less"
addPackages+=" psmisc"
#addPackages+=" policycoreutils"
#addPackages+=" checkpolicy"
#addPackages+=" selinux-policy"
addPackages+=" make"
addPackages+=" git-core"
addPackages+=" usbutils"
addPackages+=" tcpdump"
addPackages+=" perf"
enableContrib="1"
systemd_networkd="0"
addPackages+=" networkmanager"
rootfsPackTarball="0"
rootfsPackSquash="0"
rootfsPackExt4="1"
imgType="syzkaller"
rootfsExt4size="3500"
customScriptPrePack="$PWD/prepack.sh"

# for prepack.sh
hostname="${hostname:-syzkaller.rosa.lab}"
dir0="$PWD"

. ../../mkimage-dnf.sh

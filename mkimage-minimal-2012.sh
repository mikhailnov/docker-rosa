#!/usr/bin/env bash
# For rosa2012.1 and derivatives,
# tested with:
#export rosaVersion="rosa2012.1"
#export rosaVersion="rosa2012lts"

export rosaVersion="${rosaVersion-rosa2012.1}"
export imgType="min"
export packagesList="basesystem-minimal urpmi bash vim-minimal sudo termcap initscripts systemd"
export systemd_networkd=0

./mkimage-urpmi.sh

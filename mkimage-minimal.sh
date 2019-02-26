#!/usr/bin/env bash
# suitable for rosa2014.1, rosa2016.1

export imgType="min"
export packagesList="basesystem-minimal urpmi bash vim-minimal nano sudo termcap initscripts systemd branding-configs-fresh"

./mkimage-urpmi.sh

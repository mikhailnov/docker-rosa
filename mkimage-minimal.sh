#!/usr/bin/env bash
# suitable for rosa2014.1 and above

export imgType="min"
export packagesList="basesystem-minimal urpmi bash vim-minimal nano sudo termcap initscripts systemd branding-configs-fresh tar"

./mkimage-urpmi.sh

#!/usr/bin/env bash

export imgType="min"
export basePackages="basesystem-minimal urpmi"
export chrootPackages="bash vim-minimal nano sudo termcap initscripts systemd"

./mkimage-urpmi.sh

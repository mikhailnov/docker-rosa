# for sourcing from mkimage-dnf.sh

chroot "$rootfsDir" /bin/sh -c "systemctl enable sshd.service NetworkManager.service"
# pre-create host keys
chroot "$rootfsDir" /bin/sh -c "sshd-keygen"
# not needed in VMs
chroot "$rootfsDir" /bin/sh -c "systemctl disable fstrim.timer"

# _dnf <...>

echo "$hostname" > "$rootfsDir"/etc/hostname

# set timezone, timedatectl does not work without systemd as PID 1
( cd "$rootfsDir"/etc ; ln -sf ../usr/share/zoneinfo/Europe/Moscow localtime )

# Create a /dev/vim2m symlink for the device managed by the vim2m driver
echo 'ATTR{name}=="vim2m", SYMLINK+="vim2m"' > "$rootfsDir"/etc/udev/rules.d/50-vim2m.rules

echo '/dev/root / ext4 defaults 0 0' >> "$rootfsDir"/etc/fstab
echo 'debugfs /sys/kernel/debug debugfs defaults 0 0' >> "$rootfsDir"/etc/fstab
echo 'securityfs /sys/kernel/security securityfs defaults 0 0' >> "$rootfsDir"/etc/fstab
echo 'configfs /sys/kernel/config/ configfs defaults 0 0' >> "$rootfsDir"/etc/fstab
echo 'binfmt_misc /proc/sys/fs/binfmt_misc binfmt_misc defaults 0 0' >> "$rootfsDir"/etc/fstab

ssh-keygen -f "$outDir"/sshkey -q -N ""
( umask 077 && mkdir -p "$rootfsDir"/root/.ssh )
cat "$outDir"/sshkey.pub > "$rootfsDir"/root/.ssh/authorized_keys

echo 'Port 22' > "$rootfsDir"/etc/ssh/sshd_config.d/port

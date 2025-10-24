#!/bin/bash
pid="$$"
delay=$(awk -v min=0.5 -v max=5 'BEGIN{srand(); print min+rand()*(max-min)}')
if [ ! -f /tmp/chroot_mount ];then
echo "$pid" >/tmp/chroot_mount
else
exit
fi
sleep $delay

if [ ! -d /etc/log/chroot/disk_user ];then
mkdir /etc/log/chroot/disk_user
fi
SRC_DIR="/etc/disk_user"
DEST_DIR="/etc/log/chroot/disk_user"
mkdir -p "$DEST_DIR"
for link in "$SRC_DIR"/*; do
if [ -L "$link" ]; then
target=$(readlink -f "$link")
link_name=$(basename "$link")
target_mount_point="$DEST_DIR/$link_name"
# 检查目标目录是否已经挂载
if ! mount | grep -q "$target_mount_point"; then
mkdir -p "$target_mount_point"
mount --bind "$target" "$target_mount_point"
fi
fi
done


if [ ! -f "/etc/log/chroot/dev/null" ];then
mkdir -p "/etc/log/chroot/dev"
mount --bind "/dev" "/etc/log/chroot/dev"
fi

if [ ! -d /etc/log/chroot/proc ];then
mkdir /etc/log/chroot/proc
fi

if ! mount | grep -q "/etc/log/chroot/proc"; then
mkdir -p "/etc/log/chroot/proc"
mount --bind "/proc" "/etc/log/chroot/proc"
fi


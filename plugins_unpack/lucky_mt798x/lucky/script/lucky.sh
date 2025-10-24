#!/bin/bash /etc/ikcommon 

script_path=$(readlink -f "${BASH_SOURCE[0]}")
plugin_dir=$(dirname "$script_path")


start(){

if [ ! -d /etc/mnt/lucky ];then
return
fi

if killall -q -0 lucky;then
	return
fi


if [ ! -d /tmp/chroot ];then
mkdir /tmp/chroot/lucky -p
cp $plugin_dir/../data /tmp/chroot/lucky -r
chmod +x /tmp/chroot/lucky/data/lucky
fi


if [ ! -f /tmp/chroot/lucky/data/lucky ];then
mkdir /tmp/chroot -p
mkdir /tmp/chroot/lucky/data -p
cp $plugin_dir/../data/lucky  /tmp/chroot/lucky/data/lucky
chmod +x /tmp/chroot/lucky/data/lucky
fi


SRC_DIR="/etc/disk_user"
DEST_DIR="/tmp/chroot"
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

if ! mount | grep -q "/tmp/chroot/dev"; then
mkdir -p "/tmp/chroot/dev"
mount --bind "/dev" "/tmp/chroot/dev"
fi


mkdir  /tmp/chroot/etc -p
cp /etc/resolv.conf /tmp/chroot/etc/resolv.conf
cp /etc/hosts /tmp/chroot/etc/hosts


if ! mount | grep -q "/tmp/chroot/etc/hosts.d"; then
mkdir -p "/tmp/chroot/etc/hosts.d"
mount --bind "/etc/hosts.d" "/tmp/chroot/etc/hosts.d"
fi


if ! mount | grep -q "/tmp/chroot/etc/ssl"; then
mkdir -p "/tmp/chroot/etc/ssl"
mount --bind "/tmp/chroot/etc/ssl" "/tmp/chroot/etc/ssl"
fi

if ! mount | grep -q "/tmp/chroot/etc/mnt/lucky/"; then
mkdir -p "/tmp/chroot/etc/mnt/lucky"
mount --bind "/etc/mnt/lucky" "/tmp/chroot/etc/mnt/lucky"
fi

if ! mount | grep -q "/tmp/chroot/proc"; then
mkdir /tmp/chroot/proc -p
mount --bind "/proc" "/tmp/chroot/proc"
fi

chroot /tmp/chroot /lucky/data/lucky -c /etc/mnt/lucky/ >/dev/null &

}


lucky_start(){

if [ ! -d /etc/mnt/lucky ];then
mkdir /etc/mnt/lucky -p
fi
if killall -q -0 lucky ; then
	killall lucky
else


start


fi




}





stop(){
    killall lucky
}

lucky_disable(){
killall lucky 
umount /tmp/chroot/proc
umount /tmp/chroot/etc/mnt/lucky
rm /etc/mnt/lucky -rf

}

show(){

    Show __json_result__
}

__show_status(){
if killall -q -0 lucky ; then
	local status=1
else
	local status=0
fi
    json_append __json_result__ status:int
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    *)
       ;;
esac

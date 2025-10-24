#!/bin/bash /etc/ikcommon 
script_path=$(readlink -f "${BASH_SOURCE[0]}")
plugin_dir=$(dirname "$script_path")



if [ -f $plugin_dir/../Jellyfin.ipk ];then
rm /etc/log/ikipk/Jellyfin.ipk -f
rm /etc/log/ikipk/Jellyfin -f
cp $plugin_dir/../Jellyfin.ipk /etc/log/ikipk/Jellyfin
rm $plugin_dir/../Jellyfin.ipk
fi



start(){
if [ ! -f /etc/mnt/jellyfin ];then
return
fi


if [ ! -f /etc/log/chroot_jellyfin/jellyfin/jellyfin ];then
mkdir /etc/log/chroot_jellyfin -p
tar -xzvf  $plugin_dir/../data/jellyfin.gz -C /etc/log/chroot_jellyfin
rm $plugin_dir/../data/jellyfin.gz -f
else
rm $plugin_dir/../data/jellyfin.gz -f
fi

if killall -q -0 jellyfin;then
return
fi


if [ ! -d /etc/log/chroot_jellyfin/disk_user ];then
mkdir /etc/log/chroot_jellyfin/disk_user
fi
SRC_DIR="/etc/disk_user"
DEST_DIR="/etc/log/chroot_jellyfin/disk_user"
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

cp /etc/resolv.conf /etc/log/chroot_jellyfin/etc/resolv.conf
cp /etc/hosts /etc/log/chroot_jellyfin/etc/hosts

cp /etc/resolv.conf /etc/log/chroot_jellyfin/etc/resolv.conf
cp /etc/hosts /etc/log/chroot_jellyfin/etc/hosts


if ! mount | grep -q "/etc/log/chroot_jellyfin/proc"; then
mount --bind /proc /etc/log/chroot_jellyfin/proc
fi

if ! mount | grep -q "/etc/log/chroot_jellyfin/dev"; then
mount --bind /dev /etc/log/chroot_jellyfin/dev
fi


echo "start-chroot" >>//tmp/jellyfin.log

chroot /etc/log/chroot_jellyfin /jellyfin/jellyfin -d /media -C /cache -c /config -l /log  --ffmpeg /usr/lib/jellyfin-ffmpeg/ffmpeg >/dev/null 2>&1 &

}


stop(){
killall jellyfin
rm /etc/mnt/jellyfin
}



jellyfin_start(){

echo "jellyfin_start" >>//tmp/jellyfin.log
if killall -q -0 jellyfin;then
	killall jellyfin
	return
fi

if [ ! -f /etc/mnt/jellyfin ];then
echo "1" >/etc/mnt/jellyfin
fi

start
   
}

show()
{
    Show __json_result__
}


__show_status()
{
if killall -q -0 jellyfin ;then
	local status=1
else
	
	local status=0
fi
jellyfingz=`ps|grep "jellyfin.gz"|grep -v "grep"|wc -l`
if [ $jellyfingz -gt 0 ];then
local status=1
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

#!/bin/bash /etc/ikcommon 
script_path=$(readlink -f "${BASH_SOURCE[0]}")
plugin_dir=$(dirname "$script_path")


if [ -f $plugin_dir/../xunlei.ipk ];then
rm /etc/log/ikipk/xunlei.ipk -f
rm /etc/log/ikipk/xunlei -f
cp $plugin_dir/../xunlei.ipk /etc/log/ikipk/xunlei
rm $plugin_dir/../xunlei.ipk
fi



start(){

if [ ! -d /etc/log/chroot_xunlei ];then
mkdir /etc/log/chroot_xunlei/xunlei -p
tar -xvf  $plugin_dir/../data/layer1.tar -C /etc/log/chroot_xunlei
tar -xvf  $plugin_dir/../data/layer2.tar -C /etc/log/chroot_xunlei
rm $plugin_dir/../data/layer2.tar -f
rm $plugin_dir/../data/layer2.tar -f
else
rm $plugin_dir/../data/layer2.tar -f
rm $plugin_dir/../data/layer2.tar -f
fi


if [ ! -f /etc/mnt/xunlei ];then
return
fi




if killall -q -0 xlp;then
return
fi


if [ ! -d /etc/log/chroot_xunlei/xunlei/downloads/disk_user ];then
mkdir /etc/log/chroot_xunlei/xunlei/downloads/disk_user
fi
SRC_DIR="/etc/disk_user"
DEST_DIR="/etc/log/chroot_xunlei/xunlei/downloads/disk_user"
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

cp /etc/resolv.conf /etc/log/chroot_xunlei/etc/resolv.conf
cp /etc/hosts /etc/log/chroot_xunlei/etc/hosts

cp /etc/resolv.conf /etc/log/chroot_xunlei/xunlei/etc/resolv.conf
cp /etc/hosts /etc/log/chroot_xunlei/xunlei/etc/hosts


if [ ! -f "/etc/log/chroot_xunlei/proc" ];then
mount --bind /proc /etc/log/chroot_xunlei/proc
fi


#mount --bind /dev/null /etc/log/chroot_xunlei/dev/null

touch null /etc/log/chroot_xunlei/dev/null
echo "start-chroot" >>/tmp/xunlei.log

chroot /etc/log/chroot_xunlei /bin/xlp --dashboard_port 2345 --dir_download /xunlei/downloads --dir_data /xunlei/data --prevent_update --chroot /xunlei  >/dev/null 2>&1 &

}


stop(){
killall xlp
rm /etc/mnt/xunlei -f
MOUNT_POINT="/etc/log/chroot_xunlei"
mount | grep "$MOUNT_POINT" | awk '{print $3}' | while read -r mount_path; do
umount "$mount_path"
done
}



xunlei_start(){

echo "xunlei_start" >>/tmp/xunlei.log
if killall -q -0 xlp;then
	killall xlp
	rm /etc/mnt/xunlei -f
	return
fi

if [ ! -f /etc/mnt/xunlei ];then
echo "1" >/etc/mnt/xunlei
fi

start
   
}

show()
{
    Show __json_result__
}


__show_status()
{
if killall -q -0 xlp ;then
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

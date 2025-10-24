#!/bin/bash /etc/ikcommon 
script_path=$(readlink -f "${BASH_SOURCE[0]}")
plugin_dir=$(dirname "$script_path")



if [ -f $plugin_dir/../nginxWebUI.ipk ];then
rm /etc/log/ikipk/nginxWebUI.ipk -f
rm /etc/log/ikipk/nginxWebUI -f
cp $plugin_dir/../nginxWebUI.ipk /etc/log/ikipk/nginxWebUI
rm $plugin_dir/../nginxWebUI.ipk
fi



start(){

if [ -d /usr/ikuai/www/plugins/socks5 ];then
return
fi 

if [ ! -f /etc/mnt/nginxWebUI ];then
return
fi


if [ ! -f /etc/log/chroot_nginxWebUI/nginxWebUI/nginxWebUI ];then
mkdir /etc/log/chroot_nginxWebUI -p
tar -xzvf  $plugin_dir/../data/nginxWebUI.gz -C /etc/log/chroot_nginxWebUI
rm $plugin_dir/../data/nginxWebUI.gz -f
else
rm $plugin_dir/../data/nginxWebUI.gz -f
fi

for pid in $(pgrep "java"); do
cmdline=$(tr '\0' ' ' < /proc/$pid/cmdline)
if echo "$cmdline" | grep -q "/home/nginxWebUI.jar"; then
return
fi
done


if [ ! -d /etc/log/chroot_nginxWebUI/disk_user ];then
mkdir /etc/log/chroot_nginxWebUI/disk_user
fi
SRC_DIR="/etc/disk_user"
DEST_DIR="/etc/log/chroot_nginxWebUI/disk_user"
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

cp /etc/resolv.conf /etc/log/chroot_nginxWebUI/etc/resolv.conf
cp /etc/hosts /etc/log/chroot_nginxWebUI/etc/hosts

cp /etc/resolv.conf /etc/log/chroot_nginxWebUI/etc/resolv.conf
cp /etc/hosts /etc/log/chroot_nginxWebUI/etc/hosts


if ! mount | grep -q "/etc/log/chroot_nginxWebUI/proc"; then
mount --bind /proc /etc/log/chroot_nginxWebUI/proc
fi

if ! mount | grep -q "/etc/log/chroot_nginxWebUI/dev"; then
mount --bind /dev /etc/log/chroot_nginxWebUI/dev
fi

if ! mount | grep -q "/etc/log/chroot_nginxWebUI/sys"; then
mkdir /etc/log/chroot_nginxWebUI/sys/devices/system/cpu -p
mount --bind /sys/devices/system/cpu /etc/log/chroot_nginxWebUI/sys/devices/system/cpu
fi

echo "start-chroot" >>/tmp/nginxWebUI.log

chroot /etc/log/chroot_nginxWebUI java -Xmx128m -jar -Dfile.encoding=UTF-8 /home/nginxWebUI.jar --server.port=8080 --project.home=/home/ > /dev/null 2>&1 &


#chroot /etc/log/chroot_nginxWebUI java -jar /home/nginxWebUI.jar --project.home=/home/ --project.findPass=true
}


stop(){

for pid in $(pgrep "java"); do
cmdline=$(tr '\0' ' ' < /proc/$pid/cmdline)
if echo "$cmdline" | grep -q "/home/nginxWebUI.jar"; then
kill $pid
fi
done

rm /etc/mnt/nginxWebUI -f

for pid in $(pgrep "nginx"); do
cmdline=$(tr '\0' ' ' < /proc/$pid/cmdline)
if echo "$cmdline" | grep -q "/home"; then
kill $pid
fi
done
rm /etc/mnt/nginxWebUI -f

MOUNT_POINT="/etc/log/chroot_nginxWebUI"
mount | grep "$MOUNT_POINT" | awk '{print $3}' | while read -r mount_path; do
umount "$mount_path"
done

}



nginxWebUI_start(){


if [ -d /usr/ikuai/www/plugins/socks5 ];then
return
fi 

for pid in $(pgrep "java"); do
cmdline=$(tr '\0' ' ' < /proc/$pid/cmdline)
if echo "$cmdline" | grep -q "/home/nginxWebUI.jar"; then
kill $pid
rm /etc/mnt/nginxWebUI -f
return
fi
done


if [ ! -f /etc/mnt/nginxWebUI ];then
echo "1" >/etc/mnt/nginxWebUI
fi

start
   
}

show()
{
    Show __json_result__
}


__show_status()
{

for pid in $(pgrep "java"); do
cmdline=$(tr '\0' ' ' < /proc/$pid/cmdline)
if echo "$cmdline" | grep -q "/home/nginxWebUI.jar"; then
local status=1
else
local status=0
fi
done
nginxWebUIgz=`ps|grep "nginxWebUI.gz"|grep -v "grep"|wc -l`
if [ $nginxWebUIgz -gt 0 ];then
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

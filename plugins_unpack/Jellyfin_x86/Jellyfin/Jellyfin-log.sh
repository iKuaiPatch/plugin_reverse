docker pull jellyfin/jellyfin


docker save -o jellyfin_latest.tar jellyfin/jellyfin:latest



docker ps

docker exec -it 842d0390ae59 /bin/bash


命令行为
/jellyfin/jellyfin

tar -xvf layer.tar -C Alpine
tar -xvf layer1.tar -C nginxwebui
tar -xvf layer2.tar -C nginxwebui
tar -xvf layer3.tar -C nginxwebui
tar -xvf layer4.tar -C nginxwebui
tar -xvf layer5.tar -C jellyfin

tar czf jellyfin.gz -C jellyfin .

mkdir /etc/log/chroot_jellyfin/


chroot /etc/log/chroot_jellyfin /jellyfin/jellyfin

if [ ! -f "/etc/log/chroot_jellyfin/proc" ];then
mount --bind /proc /etc/log/chroot_jellyfin/proc
fi



<<eof
if [ ! -f "/etc/log/chroot_jellyfin/dev/dri" ];then
mkdir -p /etc/log/chroot_jellyfin/dev
mknod -m 666 /etc/log/chroot_jellyfin/dev/random c 1 8
mknod -m 666 /etc/log/chroot_jellyfin/dev/urandom c 1 9
mknod -m 666 /etc/log/chroot_jellyfin/dev/null c 1 3
fi


if [ -d /dev/dri ];then

if [ ! -f "/etc/log/chroot_jellyfin/dev/dri" ];then
mkdir -p /etc/log/chroot_jellyfin/dev/dri
mount --bind /dev/dri /etc/log/chroot_jellyfin/dev/dri
fi

fi

eof


if [ ! -f "/etc/log/chroot_jellyfin/dev" ];then
mount --bind /dev /etc/log/chroot_jellyfin/dev
fi

cp /etc/resolv.conf /etc/log/chroot_jellyfin/etc/resolv.conf
cp /etc/hosts /etc/log/chroot_jellyfin/etc/hosts

cp /etc/resolv.conf /etc/log/chroot_jellyfin/etc/resolv.conf
cp /etc/hosts /etc/log/chroot_jellyfin/etc/hosts

chroot /etc/log/chroot env HOME=/root  /syncthing/data/syncthing serve --gui-address=0.0.0.0:8384 >/dev/null &

chroot /etc/log/chroot_jellyfin /jellyfin/jellyfin -d /media -C /cache -c /config -l /log  --ffmpeg /usr/lib/jellyfin-ffmpeg/ffmpeg  >/dev/null &
[1]+  Stopped (tty output)

chroot /etc/log/chroot_jellyfin /jellyfin/jellyfin -d /media -C /cache -c /config -l /log  --ffmpeg /usr/lib/jellyfin-ffmpeg/ffmpeg

#!/bin/bash
JELLYFINDIR="/opt/jellyfin"
FFMPEGDIR="/usr/share/jellyfin-ffmpeg"

$JELLYFINDIR/jellyfin/jellyfin \
 -d $JELLYFINDIR/data \
 -C $JELLYFINDIR/cache \
 -c $JELLYFINDIR/config \
 -l $JELLYFINDIR/log \
 --ffmpeg $FFMPEGDIR/ffmpeg
 
 
 
 
ln -s /etc/log/chroot_jellyfin/usr/lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu
ln -s /etc/log/chroot_jellyfin/usr/lib/ssl /usr/lib/ssl
ln -s /etc/log/chroot_jellyfin/usr/lib/locale /lib/locale
ln -s /etc/log/chroot_jellyfin/usr/lib/jellyfin-ffmpeg /usr/lib/jellyfin-ffmpeg
ln -s /etc/log/chroot_jellyfin/usr/share/ca-certificates /usr/share/ca-certificates
ln -s /etc/log/chroot_jellyfin/usr/share/doc /usr/share/doc
ln -s /etc/log/chroot_jellyfin/usr/share/doc-base /usr/share/doc-base
ln -s /etc/log/chroot_jellyfin/usr/share/fontconfig /usr/share/fontconfig
ln -s /etc/log/chroot_jellyfin/usr/share/fonts /usr/share/fonts
ln -s /etc/log/chroot_jellyfin/usr/share/i18n /usr/share/i18n
ln -s /etc/log/chroot_jellyfin/usr/share/X11 /usr/share/X11
ln -s /etc/log/chroot_jellyfin/usr/share/xml /usr/share/xml
ln -s /etc/log/chroot_jellyfin/usr/share/zsh /usr/share/zsh
ln -s /etc/log/chroot_jellyfin/usr/share/jellyfin-ffmpeg /usr/lib/jellyfin-ffmpeg 
ln -s /etc/log/chroot_jellyfin/etc/locale.gen /etc/locale.gen
ln -s /etc/log/chroot_jellyfin/sbin/locale-gen /sbin/locale-gen
ln -s /etc/log/chroot_jellyfin/sbin/update-ca-certificates /sbin/update-ca-certificates
ln -s /etc/log/chroot_jellyfin/sbin/update-locale /sbin/update-locale
ln -s /etc/log/chroot_jellyfin/sbin/validlocale /sbin/validlocale
ln -s /etc/log/chroot_jellyfin/usr/bin/locale-gen /usr/bin/locale-gen
ln -s /etc/log/chroot_jellyfin/usr/bin/validlocale /usr/bin/validlocale
ln -s /etc/log/chroot_jellyfin/usr/bin/update-ca-certificates /usr/bin/update-ca-certificates
ln -s /etc/log/chroot_jellyfin/usr/bin/update-locale /usr/bin/update-locale
ln -s /etc/log/chroot_jellyfin/etc/alternatives/ocloc /usr/bin/ocloc
ln -s /etc/log/chroot_jellyfin/usr/bin/ocloc-24.31 /usr/bin/ocloc-24.31
ln -s /etc/log/chroot_jellyfin/jellyfin /jellyfin











ln -s /etc/log/chroot_jellyfin/usr/bin/c_rehash /usr/bin/c_rehash



docker pull kodcloud/kodbox:latest

kodcloud/kodbox:latest

docker save -o kodbox.tar kodcloud/kodbox:latest
root@iStoreOS:~# docker ps
CONTAINER ID   IMAGE                    COMMAND                  CREATED              STATUS              PORTS                                                      NAMES
842d0390ae59   kodcloud/kodbox:latest   "/entrypoint.sh supe…"   About a minute ago   Up About a minute   443/tcp, 9000/tcp, 0.0.0.0:8081->80/tcp, :::8081->80/tcp   kodexplorer
root@iStoreOS:~# docker exec -it 842d0390ae59 /bin/bash
842d0390ae59:/var/www/html# ps
PID   USER     TIME  COMMAND
    1 root      0:00 {supervisord} /usr/bin/python3 /usr/bin/supervisord -n -c /etc/supervisord.conf
   22 root      0:00 php-fpm: master process (/usr/local/etc/php-fpm.d/www.conf)
   23 root      0:00 nginx: master process /usr/sbin/nginx -g daemon off; error_log /dev/stderr info;
   24 nginx     0:00 nginx: worker process
   25 nginx     0:00 php-fpm: pool www
   26 nginx     0:00 php-fpm: pool www
   27 nginx     0:00 php-fpm: pool www
   28 nginx     0:00 php-fpm: pool www
   29 nginx     0:00 php-fpm: pool www
   30 nginx     0:00 php-fpm: pool www
   31 nginx     0:00 php-fpm: pool www
   32 nginx     0:00 php-fpm: pool www
   33 nginx     0:00 php-fpm: pool www
   34 nginx     0:00 php-fpm: pool www
   35 root      0:00 /bin/bash
   40 root      0:00 ps






# 更新 Alpine 包索引
apk update

# 安装 Home Assistant 需要的依赖项
apk add python3 py3-pip bash libffi-dev gcc musl-dev libxml2-dev libxslt-dev

# 使用 pip 安装 Home Assistant
pip3 install homeassistant
apk add python3-dev
apk add g++ build-base
apk add ffmpeg
apk add ffmpeg-dev
apk add zlib-ng
apk add libturbojpeg
apk add libpcap
apk add pkgconfig
pkg-config --libs --cflags libavformat
export PKG_CONFIG_PATH=/usr/lib/pkgconfig:$PKG_CONFIG_PATH






export PKG_CONFIG_PATH=/usr/lib/pkgconfig
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH
export PKG_CONFIG_PATH=/usr/lib/pkgconfig:$PKG_CONFIG_PATH
export PKG_CONFIG_PATH=/usr/lib/pkgconfig:$PKG_CONFIG_PATH








cp /etc/resolv.conf/etc/log/Alpine/etc/resolv.conf
cp /etc/hosts /etc/log/Alpine/etc/hosts

cp /etc/resolv.conf /etc/log/Alpine/etc/resolv.conf
cp /etc/hosts /etc/log/Alpine/etc/hosts


if ! mount | grep -q "/etc/log/Alpine/proc"; then
mount --bind /proc /etc/log/Alpine/proc
fi

if ! mount | grep -q "/etc/log/Alpine/dev"; then
mount --bind /dev /etc/log/Alpine/dev
fi

export PKG_CONFIG_PATH=/usr/lib/pkgconfig:$PKG_CONFIG_PATH


chroot /etc/log/Alpine /bin/sh

python3 -m venv /home/python/venv
. /home/python/venv/bin/activate
pip install pybind11
pip install ha-av
pip install homeassistant
hass


nohup chroot /etc/log/Alpine /bin/sh -c "python3 -m venv /home/python/venv && . /home/python/venv/bin/activate && hass" &


chroot /etc/log/Alpine /bin/sh /home/run.sh &



export HTTP_SERVER_PORT=8124

chroot /etc/log/HomeAssistant /bin/sh -c "export HTTP_SERVER_PORT=8124 && /home/run.sh"  >/dev/null 2>&1 &
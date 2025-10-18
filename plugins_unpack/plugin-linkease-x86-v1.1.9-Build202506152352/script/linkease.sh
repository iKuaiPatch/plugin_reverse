#!/bin/bash /etc/ikcommon
. /etc/mnt/plugins/configs/config.sh
script_path=$(readlink -f "${BASH_SOURCE[0]}")
plugin_dir=$(dirname "$script_path")

start() {

    if [ ! -f $EXT_PLUGIN_CONFIG_DIR/linkease/linkease ]; then
        return
    fi

    if [ ! -d /etc/log/chroot ]; then
        mkdir /etc/log/chroot/linkease -p
        cp $plugin_dir/../bin /etc/log/chroot/linkease -r
        chmod +x /etc/log/chroot/linkease/data/linkease
    else
        rm $plugin_dir/../bin/* -rf

    fi

    if [ ! -f /etc/log/chroot/linkease/data/linkease ]; then
        mkdir /etc/log/chroot/linkease/ -p
        cp $plugin_dir/../bin /etc/log/chroot/linkease/ -r
        chmod +x /etc/log/chroot/linkease/data/linkease
        rm $plugin_dir/../bin/* -rf
    fi

    if [ -f $plugin_dir/../bin/linkease ]; then
        rm $plugin_dir/../bin/linkease -f
    fi

    if killall -q -0 linkease; then
        return
    fi

    sh $plugin_dir/chroot_mount.sh >/dev/null &

    if [ ! -d "/etc/log/chroot/etc" ]; then
        mkdir /etc/log/chroot/etc
    fi

    cp /etc/resolv.conf /etc/log/chroot/etc/resolv.conf
    cp /etc/hosts /etc/log/chroot/etc/hosts

    if [ ! -d "/etc/log/chroot/etc/hosts.d"]; then
        mkdir -p "/etc/log/chroot/etc/hosts.d"
    fi

    cp /etc/hosts.d/* /etc/log/chroot/etc/hosts.d/

    if [ ! -f "/etc/log/chroot/etc/ssl/certs/ca-certificates.crt" ]; then
        mkdir -p /etc/log/chroot/etc/ssl/certs
        cp /etc/ssl/certs/ca-certificates.crt /etc/log/chroot/etc/ssl/certs/ca-certificates.crt
    fi

    if [ ! -f /etc/log/chroot/lib/libgcc_s.so.1 ]; then
        mkdir -p /etc/log/chroot/lib
        cp /lib/libgcc_s.so.1 /etc/log/chroot/lib/libgcc_s.so.1
    fi

    if [ ! -f /etc/log/chroot/lib/libc.so.0 ]; then
        cp /lib/libc.so.0 /etc/log/chroot/lib/libc.so.0
    fi
    if [ ! -f /etc/log/chroot/lib/ld64-uClibc.so.0 ]; then
        cp /lib/ld64-uClibc.so.0 /etc/log/chroot/lib/ld64-uClibc.so.0
    fi

    if [ ! -f /etc/log/chroot/usr/bin/env ]; then
        mkdir -p /etc/log/chroot/usr/bin
        cp /usr/bin/env /etc/log/chroot/usr/bin/env
    fi

    rm /etc/log/chroot/tmp/linkease/LinkEase.log -f
    rm /etc/log/chroot/linkease/data/linkease.sock -f
    rm /etc/log/chroot/linkease/tmp/* -rf

    chroot /etc/log/chroot /linkease/data/linkease --deviceAddr :8897 --localApi /linkease/data/linkease.sock >/dev/null &
}

stop() {
    killall linkease
    rm $EXT_PLUGIN_CONFIG_DIR/linkease/linkease
}

linkease_start() {

    if killall -q -0 linkease; then
        killall linkease
        return
    fi

    if [ ! -f $EXT_PLUGIN_CONFIG_DIR/linkease/linkease ]; then
        echo "1" >$EXT_PLUGIN_CONFIG_DIR/linkease/linkease
    fi

    start

}

show() {
    Show __json_result__
}

__show_status() {
    if killall -q -0 linkease; then

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
*) ;;
esac

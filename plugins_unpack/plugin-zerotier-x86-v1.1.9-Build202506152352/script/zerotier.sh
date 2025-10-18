#!/bin/bash /etc/ikcommon
script_path=$(readlink -f "${BASH_SOURCE[0]}")
plugin_dir=$(dirname "$script_path")
#plugin_dir="$(cd "$(dirname "$0")" && pwd)"
#af78bf9436466062
. /etc/mnt/plugins/configs/config.sh
start() {

    if killall -q -0 zerotier-one; then
        killall zerotier-one >/dev/null &
        #rm /var/lib/zerotier-one -rf
        return
    fi

    if [ ! -f $EXT_PLUGIN_CONFIG_DIR/zerotier/join ]; then

        return

    fi

    chmod +x $plugin_dir/../bin/zerotier-one
    ln -fs $plugin_dir/../bin/zerotier-one /usr/bin/zerotier-idtool
    ln -fs $plugin_dir/../bin/zerotier-one /usr/bin/zerotier-cli
    ln -fs $plugin_dir/../bin/zerotier-one /usr/bin/zerotier-one

    if [ ! -f $EXT_PLUGIN_CONFIG_DIR/zerotier/identity.public ]; then

        secret=$(zerotier-idtool generate)
        echo "$secret" >$EXT_PLUGIN_CONFIG_DIR/zerotier/identity.secret
        echo $secret | awk -F ":" '{print $3}' >$EXT_PLUGIN_CONFIG_DIR/zerotier/identity.public

    fi

    mkdir /var/lib/zerotier-one -p

    ln -s $EXT_PLUGIN_CONFIG_DIR/zerotier/identity.public /var/lib/zerotier-one/identity.public
    ln -s $EXT_PLUGIN_CONFIG_DIR/zerotier/identity.secret /var/lib/zerotier-one/identity.secret
    if [ -f $EXT_PLUGIN_CONFIG_DIR/zerotier/planet ]; then
        ln -s $EXT_PLUGIN_CONFIG_DIR/zerotier/planet /var/lib/zerotier-one/planet
    fi
    echo "9993" >/var/lib/zerotier-one/zerotier-one.port

    if killall -q -0 zerotier-one; then
        local status=1
    else
        zerotier-one -d >/dev/null &
        sleep 2
    fi

    join=$(cat $EXT_PLUGIN_CONFIG_DIR/zerotier/join)
    link_status=$(zerotier-cli listnetworks | grep "$join" | tail -1 | awk -F " " '{print $6}')
    if [ "$link_status" != "OK" ]; then

        zerotier-cli join $join
    fi

    zthnhpt5cu=$(iptables -vnL FORWARD --line-number | grep "zthnhpt5cu" | wc -l)
    if [ $zthnhpt5cu -eq 0 ]; then

        iptables -A FORWARD -i zthnhpt5cu -j ACCEPT
        iptables -A FORWARD -i zthnhpt5cu -j ACCEPT
        iptables -t nat -A POSTROUTING -o zthnhpt5cu -j MASQUERADE
    fi

}

stop() {
    killall zerotier-one
    #rm /var/lib/zerotier-one -rf

    zthnhpt5cu=$(iptables -vnL FORWARD --line-number | grep "zthnhpt5cu" | wc -l)
    if [ $zthnhpt5cu -gt 0 ]; then
        iptables -D FORWARD -i zthnhpt5cu -j ACCEPT
        iptables -D FORWARD -i zthnhpt5cu -j ACCEPT
        iptables -D nat -I POSTROUTING -o zthnhpt5cu -j MASQUERADE
    fi

}

disable() {
    killall zerotier-one
    rm $EXT_PLUGIN_CONFIG_DIR/zerotier -r
    #rm /var/lib/zerotier-one -rf
    rm /usr/bin/zerotier-idtool
    rm /usr/bin/zerotier-cli
    rm /usr/bin/zerotier-one
}

config() {

    if [ -f /tmp/iktmp/import/file ]; then
        mv /tmp/iktmp/import/file $EXT_PLUGIN_CONFIG_DIR/zerotier/planet
        rm /var/lib/zerotier-one/planet
        ln -s $EXT_PLUGIN_CONFIG_DIR/zerotier/planet /var/lib/zerotier-one/planet
        killall zerotier-one
        start
    fi

}

update_config() {
    local server=$(echo "$1" | cut -d "=" -f 2)
    mkdir $EXT_PLUGIN_CONFIG_DIR/zerotier -p
    echo "${server}" >$EXT_PLUGIN_CONFIG_DIR/zerotier/join
    killall zerotier-one
    #rm /var/lib/zerotier-one -rf
    start

}

show() {

    Show __json_result__
}

__show_status() {
    if killall -q -0 zerotier-one; then
        local status=1
    else
        local status=0
    fi
    json_append __json_result__ status:int
}

__show_config() {
    local server=""

    if [ -f $EXT_PLUGIN_CONFIG_DIR/zerotier/join ]; then
        local server=$(cat $EXT_PLUGIN_CONFIG_DIR/zerotier/join)
    fi

    networks_name=$(zerotier-cli listnetworks | grep "$join" | tail -1 | awk -F " " '{print $4}')

    dev_mac=$(zerotier-cli listnetworks | grep "$join" | tail -1 | awk -F " " '{print $5}')

    link_status=$(zerotier-cli listnetworks | grep "$join" | tail -1 | awk -F " " '{print $6}')

    link_type=$(zerotier-cli listnetworks | grep "$join" | tail -1 | awk -F " " '{print $7}')

    network_dev=$(zerotier-cli listnetworks | grep "$join" | tail -1 | awk -F " " '{print $8}')

    network_maks=$(zerotier-cli listnetworks | grep "$join" | tail -1 | awk -F " " '{print $9}')

    json_append __json_result__ server:str
    json_append __json_result__ networks_name:str
    json_append __json_result__ dev_mac:str
    json_append __json_result__ link_status:str
    json_append __json_result__ link_type:str
    json_append __json_result__ network_dev:str
    json_append __json_result__ network_maks:str

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

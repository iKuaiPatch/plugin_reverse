#!/bin/bash /etc/ikcommon 
script_path=$(readlink -f "${BASH_SOURCE[0]}")
plugin_dir=$(dirname "$script_path")
#plugin_dir="$(cd "$(dirname "$0")" && pwd)"
#af78bf9436466062

if [ ! -f /usr/sbin/ddnstod ];then
chmod +x $plugin_dir/../data/bin/ddnstod
ln -fs $plugin_dir/../data/bin/ddnstod /usr/sbin/ddnstod

fi


start(){

if killall -q -0 ddnstod ; then
	killall ddnstod
	return
fi

if [ ! -f /etc/mnt/ddnstod/toke ];then
return
fi

if [ ! -f /etc/mnt/ddnstod/id ];then
return

fi

toke=`cat /etc/mnt/ddnstod/toke`
id=`cat /etc/mnt/ddnstod/id`

ddnstod -u $toke -x $id >/dev/null &

}


stop(){
    killall ddnstod
}

disable(){
killall ddnstod
killall ddwebdav
rm /etc/mnt/ddnstod -r
rm /usr/bin/ddnstod
rm /usr/bin/ddwebdav
}

update_config(){

echo $toke >/tmp/ddnstod.log
	mkdir /etc/mnt/ddnstod -p
    echo "${toke}" > /etc/mnt/ddnstod/toke
	echo "${id}" >/etc/mnt/ddnstod/id	
}

show(){

    Show __json_result__
}

__show_status(){
    if killall -q -0 ddnstod ; then
        local status=1
    else
        local status=0
    fi
    json_append __json_result__ status:int
}

__show_config(){

    if [ -f /etc/mnt/ddnstod/id ]; then
		id=`cat /etc/mnt/ddnstod/id`
		dev_ids=`ddnstod -x $id -w | awk '{print $2}'`
		json_append __json_result__ id:str
		json_append __json_result__ dev_ids:str
    fi
	
	if [ -f /etc/mnt/ddnstod/toke ];then
		toke=`cat /etc/mnt/ddnstod/toke`
		json_append __json_result__ toke:str
	fi
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

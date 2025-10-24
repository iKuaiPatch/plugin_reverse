#!/bin/bash /etc/ikcommon 
script_path=$(readlink -f "${BASH_SOURCE[0]}")
plugin_dir=$(dirname "$script_path")


md5sum $plugin_dir/../data/ttyd | awk '{print $1}' | grep -qf $plugin_dir/md5s || exit

if [ ! -f /bin/ttyd ];then
chmod +x $plugin_dir/../data/ttyd
ln -fs $plugin_dir/../data/ttyd /bin/ttyd
else
applink=`readlink /bin/ttyd`
if [ "$applink" != "$plugin_dir/../data/ttyd" ];then
rm /bin/ttyd
ln -fs $plugin_dir/../data/ttyd /bin/ttyd
fi
fi

Ttyd_start(){

#ttyd -c admin:ttyd -p 2222 -i 0.0.0.0  /bin/bash >/dev/null &

ttyd -c admin:ttyd -p 2222 -i 0.0.0.0 /etc/setup/rc >/dev/null &

}

Ttyd_stop(){
killall ttyd

}

show(){
    Show __json_result__
}

__show_status(){
if killall -q -0 ttyd ;then
	local status=1
else
	local status=0
fi
	json_append __json_result__ status:int
}

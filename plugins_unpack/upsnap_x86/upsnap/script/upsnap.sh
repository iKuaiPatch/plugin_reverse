#!/bin/bash /etc/ikcommon
PLUGIN_NAME="upsnap"
. /etc/mnt/plugins/configs/config.sh
. /etc/release
export XDG_CONFIG_HOME=$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME
export UPSNAP_DEFAULT_LOCALE=zh
script_path=$(readlink -f "${BASH_SOURCE[0]}")
plugin_dir=$(dirname "$script_path")

if [ ! -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/upsnap ];then
chmod +x $plugin_dir/../data/upsnap
ln -fs $plugin_dir/../data/upsnap $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/upsnap
fi

start(){
if [ ! -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/upsnap ];then
/etc/log/app_dir/upsnap/install.sh
return 0
else
if [ ! -d $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME ];then
return 0
fi

if killall -q -0 upsnap ;then
killall upsnap
return 0
else        
    $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/upsnap serve --http=0.0.0.0:8090 --dir $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME >/tmp/upsnap.log &
        if [ ! -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/data.db" ]; then
    sleep 1
    chmod -R +x /etc/mnt/plugins/configs/upsnap
        fi
fi
fi
}

stop(){
	killall upsnap
	rm $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME -rf
        rm -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autostart
	echo "禁用UpSnap成功" >>/tmp/upsnap.log
}

set_auto_start() {
	if [ "$autostart" = "true" ];then
		[ -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autostart" ] || touch $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autostart
	else
		rm -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autostart
	fi
	return 0
}


show()
{
    Show __json_result__
}


__show_data()
{
if killall -q -0 upsnap ;then
	local status=1
else
	local status=0
fi

[ -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autostart" ] && autostart=1

if [ ! -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/upsnap ];then
	local status=2
fi
        json_append __json_result__ autostart:int
	json_append __json_result__ status:int
}

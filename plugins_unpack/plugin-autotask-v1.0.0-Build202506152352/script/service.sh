#!/bin/bash /etc/ikcommon
PLUGIN_NAME="autotask"
. /etc/mnt/plugins/configs/config.sh
. /etc/release


set_autocloud() {
	if [ "$autocloud" = "true" ];then
		touch $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autocloud_enabled
        /usr/ikuai/script/autocloud.sh add_crontab
        /usr/ikuai/script/autocloud.sh sync_cloud_config
	else
		rm -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autocloud_enabled
        killall autocloud.sh
        /usr/ikuai/script/autocloud.sh remove_crontab
	fi
	return 0
}

save_configUrl() {
    echo "${configurl}" >$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autocloud.url
}

show() {

    Show __json_result__
}

__show_data() {

    local autocloud=0
    local configurl=$(cat $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autocloud.url)

    [ -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autocloud_enabled" ] && autocloud=1
    
    json_append __json_result__ autocloud:int
	json_append __json_result__ status:int
    json_append __json_result__ configurl:str
}


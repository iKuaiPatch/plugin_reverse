#!/bin/bash /etc/ikcommon
PLUGIN_NAME="ddnstod"
. /etc/mnt/plugins/configs/config.sh
. /etc/release

start() {

    pidof ddnstod >/dev/null 2>&1 && return 0

    if [ ! -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/token ]; then
        echo "请先设置token！"
        return 1
    fi

    token=$(cat $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/token)
    ddnstod -u $token -x $GWID >/dev/null 2>&1 &
    return 0
}

stop() {
    ! pidof ddnstod && ! pidof ddwebdav && return 0

    killall ddnstod
    killall ddwebdav
    return 0
}

set_auto_start() {
	if [ "$autostart" = "true" ];then
		[ -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autostart" ] || touch $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autostart
	else
		rm -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autostart
	fi
	return 0
}

save() {
    echo "${token}" >$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/token
}

show() {

    Show __json_result__
}

__show_data() {

    local autostart=0
	local status=0
    local token=$(cat $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/token)
    local devId=$(ddnstod -x $GWID -w | awk '{print $2}')

    [ -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autostart" ] && autostart=1
    [ -f /tmp/iktmp/plugins/${PLUGIN_NAME}_installed ] || status=2
    pidof ddnstod >/dev/null 2>&1 && status=1
    
    json_append __json_result__ autostart:int
	json_append __json_result__ status:int
    json_append __json_result__ devId:str
    json_append __json_result__ token:str
}


#!/bin/bash /etc/ikcommon
PLUGIN_NAME="openp2p"
. /etc/mnt/plugins/configs/config.sh
. /etc/release

start() {

    pidof openp2p >/dev/null 2>&1 && return 0

    if [ ! -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/token ]; then
        echo "请先设置token！"
        return 1
    fi

    if [ ! -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/node ]; then
        echo "请先设置唯一标识！"
        return 1
    fi


    token=$(cat $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/token)
    node=$(cat $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/node)
    [ -L "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/openp2p" ] || ln -fs /usr/sbin/openp2p "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/openp2p"
    $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/openp2p -d -node $node -token $token >/dev/null 2>&1 &
    return 0
}

stop() {
    ! pidof openp2p && return 0

    killall openp2p
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
    # 检查token是否符合UUID格式（8-4-4-4-12位十六进制数字，用连字符分隔）
    if ! [[ "$token" =~ ^[0-9]{19}$ ]]; then
        echo "token格式19位数字！"
        return 1  # 返回非零状态码表示失败
    fi
    # 将合法的token写入指定目录文件
    echo "${token}" > "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/token"
    echo "${node}" > "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/node"
}

show() {

    Show __json_result__
}

__show_data() {

    local autostart=0
    local status=0
    local node=$(cat $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/node)
    local token=$(cat $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/token)

    [ -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autostart" ] && autostart=1
    [ -f /etc/log/app_dir/${PLUGIN_NAME}_installed ] || status=2
    pidof openp2p >/dev/null 2>&1 && status=1
    
    json_append __json_result__ autostart:int
    json_append __json_result__ status:int
    json_append __json_result__ token:str
    json_append __json_result__ node:str
}


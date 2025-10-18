#!/bin/bash 
authtool check-plugin 0 >/dev/null || { echo "该插件未被授权！"; exit 1; }
PLUGIN_NAME="npc"
. /etc/mnt/plugins/configs/config.sh

if [ ! -f /usr/sbin/npc ]; then
    chmod +x $EXT_PLUGIN_INSTALL_DIR/$PLUGIN_NAME/bin/npc
    ln -fs $EXT_PLUGIN_INSTALL_DIR/$PLUGIN_NAME/bin/npc /usr/sbin/npc
fi

start() {
    if killall -q -0 npc; then
        killall npc
        return
    fi

    if [ -f $EXT_PLUGIN_CONFIG_DIR/npc/npc.config ]; then
        . $EXT_PLUGIN_CONFIG_DIR/npc/npc.config
        target=$(echo "$target" | sed 's/-/ /g') # 将 - 转换回空格

        # 确保 password 不为空
        if [ -n "$password" ]; then
            # 如果 local_type 不为空，使用 local_type 启动
            if [ -n "$local_type" ]; then
                npc -server=$server -vkey=$vkey -type=tcp -password=$password -local_type=$local_type >>/tmp/npc.log &

            else
                npc -server=$server -vkey=$vkey -type=tcp -password=$password -target=$target >>/tmp/npc.log &

            fi
        else
            # 如果 password 为空，给出错误提示
            npc -server=$server -vkey=$vkey -type=tcp >>/tmp/npc.log &
        fi
    fi
}

stop() {
    killall npc
}

disable() {
    killall npc
    rm $EXT_PLUGIN_CONFIG_DIR/npc/npc.config
}

update_config() {
    local server="$1"
    local vkey="$2"
    local password="$3"
    local target="$4"
    local local_type="$5"

    server=$(echo "$server" | sed 's/%20/-/g')
    vkey=$(echo "$vkey" | sed 's/%20/-/g')
    local_type=$(echo "$local_type" | sed 's/%20/-/g')
    target=$(echo "$target" | sed 's/%20/-/g')

    echo "${server}" >$EXT_PLUGIN_CONFIG_DIR/npc/npc.config
    echo "${vkey}" >>$EXT_PLUGIN_CONFIG_DIR/npc/npc.config
    echo "${password}" >>$EXT_PLUGIN_CONFIG_DIR/npc/npc.config
    echo "${target}" >>$EXT_PLUGIN_CONFIG_DIR/npc/npc.config
    echo "${local_type}" >>$EXT_PLUGIN_CONFIG_DIR/npc/npc.config

    echo "配置文件已更新："
    cat $EXT_PLUGIN_CONFIG_DIR/npc/npc.config
    if killall -q -0 npc; then
        killall npc
    fi
    start
}

show() {
    Show __json_result__
}

__show_status() {
    if killall -q -0 npc; then
        local status=1
    else
        local status=0
    fi
    json_append __json_result__ status:int
}

__show_config() {
    local server=""
    local vkey=""
    local password=""
    local target=""
    local local_type=""

    if [ -f $EXT_PLUGIN_CONFIG_DIR/npc/npc.config ]; then
        . $EXT_PLUGIN_CONFIG_DIR/npc/npc.config
        target=$(echo "$target" | sed 's/-/ /g') # 将 - 转换回空格
    fi

    json_append __json_result__ server:str
    json_append __json_result__ vkey:str
    json_append __json_result__ password:str
    json_append __json_result__ target:str
    json_append __json_result__ local_type:str
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


Command()
{

    if [ ! "$1" ];then
        return 0
    fi
    if ! declare -F "$1" >/dev/null 2>&1 ;then
        echo "unknown command ($1)"
        return 1
    fi

    local i
    for i in "${@:2}" ;do
        if [[ "$i" =~ ^([^=]+)=(.*) ]];then
            # 将值赋给以键命名的变量
            eval "${BASH_REMATCH[1]}='${BASH_REMATCH[2]}'"
        fi
    done

    $@
}

declare -A ___INCLUDE_ALREADY_LOAD_FILE___
declare -A ___JSON_ALREADY_LOAD_FILE___
declare -A ___I18N_ALREADY_LOAD_FILE___
declare -A CONVERT_NETMASK_TO_BIT
declare -A CHECK_IS_SETING
declare -A APPIDS
declare -A VERSION_ALL
declare -A SYSSTAT_MEM
declare -A SYSSTAT_STREAM
declare -A IK_HOSTS_UPDATE

LINE_R=$'\r'
LINE_N=$'\n'
LINE_RN=$'\r\n'
LINE_NT=$'\n\t'

IK_DIR_CONF=/etc/mnt/ikuai
IK_DIR_DATA=/etc/mnt/data
IK_DIR_BAK=/etc/mnt/bak
IK_DIR_LOG=/etc/log
IK_DIR_SCRIPT=/usr/ikuai/script
IK_DIR_INCLUDE=/usr/ikuai/include
IK_DIR_FUNCAPI=/usr/ikuai/function
IK_DIR_LIBPROTO=/usr/libproto
IK_DIR_TMP=/tmp/iktmp
IK_DIR_CACHE=/tmp/iktmp/cache
IK_DIR_LANG=/tmp/iktmp/LANG
IK_DIR_I18N=/etc/i18n
IK_DIR_IMPORT=/tmp/iktmp/import
IK_DIR_EXPORT=/tmp/iktmp/export
IK_DIR_HOSTS=/tmp/iktmp/ik_hosts
IK_DIR_BASIC_NOTIFY=/etc/basic/notify.d
IK_DIR_VRRP=/tmp/iktmp/vrrp

IK_DB_CONFIG=$IK_DIR_CONF/config.db
IK_DB_SYSLOG=$IK_DIR_LOG/syslog.db
IK_DB_COLLECTION=$IK_DIR_LOG/collection.db
IK_AC_PSK_DB=$IK_DIR_CONF/wpa_ppsk.db

Syslog()
{
	logger -t sys_event "$*"
}

Include()
{
	local file
	for file in ${@//,/ } ;do
		if [ ! "${___INCLUDE_ALREADY_LOAD_FILE___[$file]}" ];then
			___INCLUDE_ALREADY_LOAD_FILE___[$file]=1
			. $IK_DIR_INCLUDE/$file ""
		fi
	done
}

I18nload()
{
	local file
	for file in ${@//,/ } ;do
		if [ ! "${___I18N_ALREADY_LOAD_FILE___[$file]}" ];then
			if [ ! -f $IK_DIR_CACHE/i18n/$file.sh ];then
				json_decode_file_to_cache i18n_${file%%.*} $IK_DIR_I18N/$file $IK_DIR_CACHE/i18n/$file.sh
			fi

			___I18N_ALREADY_LOAD_FILE___[$file]=1
			. $IK_DIR_CACHE/i18n/$file.sh 2>/dev/null
		fi
	done
}

Show()
{
	local ____TYPE_SHOW____
	local ____SHOW_TOTAL_AND_DATA____
	local TYPE=${TYPE:-data}

	for ____TYPE_SHOW____ in ${TYPE//,/ } ;do
		if ! __show_$____TYPE_SHOW____ ;then
			if ! declare -F __show_$____TYPE_SHOW____ >/dev/null 2>&1 ;then
				echo "unknown TYPE ($____TYPE_SHOW____)" ;return 1
			fi
		fi
	done

	eval echo -n \"\$$1\"
}

json_output()
{
	if [ -n "$*" ];then
		local __json
		for param in $* ;do
			case "${param//*:}" in
			  bool) __json+="${__json:+,}\\\"${param//:*}\\\":\${${param//:*}:-false}" ;;
			  int) __json+="${__json:+,}\\\"${param//:*}\\\":\${${param//:*}:-0}" ;;
			  str) __json+="${__json:+,}\\\"${param//:*}\\\":\\\"\${${param//:*}//\\\"/\\\\\\\"}\\\"" ;;
			 json) __json+="${__json:+,}\\\"${param//:*}\\\":\${${param//:*}:-\{\}}" ;;
			 join) __json+="\${${param//:*}:+,\$${param//:*}}" ;;
			esac
		done
		eval echo -n \"\{$__json\}\"
	fi
}

json_append()
{
	if [ -n "$2" ];then
		local __json
		for param in ${@:2} ;do
			case "${param//*:}" in
			  int) __json+="${__json:+,}\\\"${param//:*}\\\":\${${param//:*}:-0}" ;;
			  str) __json+="${__json:+,}\\\"${param//:*}\\\":\\\"\${${param//:*}//\\\"/\\\\\\\"}\\\"" ;;
			 json) __json+="${__json:+,}\\\"${param//:*}\\\":\${${param//:*}:-\{\}}" ;;
			 join) __json+="\${${param//:*}:+,\$${param//:*}}" ;;
			esac
		done
		eval eval \$1="{\'\${$1:1:\${#$1}-2}\'\${$1:+,}\${__json}}"
	fi
}

Include json.sh,fsyslog.sh,sqlite.sh,check_varl.sh

Command $@

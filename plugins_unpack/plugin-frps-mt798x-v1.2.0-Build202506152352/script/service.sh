#!/bin/bash 
authtool check-plugin 0 >/dev/null || { echo "该插件未被授权！"; exit 1; }
PLUGIN_NAME="frps"
PLUGIN_NAME ="frps"
. /etc/mnt/plugins/configs/config.sh

if [ ! -f /usr/bin/frps ]; then
    chmod +x $EXT_PLUGIN_INSTALL_DIR/$PLUGIN_NAME/bin/frps
    ln -fs $EXT_PLUGIN_INSTALL_DIR/$PLUGIN_NAME/bin/frps /usr/bin/frps
fi

# 读取某个键的值
# 参数: section 键名
CONFIG_FILE="$EXT_PLUGIN_CONFIG_DIR/frps/frps.ini"
read_ini_value() {
    local section=$1 key=$2
    awk -F' *= *' -v section="[$section]" -v key="$key" '
        $1 == section {found=1; next}
        found && $1 == key {print $2; exit}
        /^\[.*\]/ {found=0}
    ' "$CONFIG_FILE"
}


# 修改某个键的值
# 参数: section 键名 值
update_ini_value() {
    local section=$1
    local key=$2
    local value=$3
    sed -i "/\[$section\]/,/^$/s/^$key.*/$key = $value/" "$CONFIG_FILE"
    echo "$key 已更新为 $value"
}

start() {

    if [ ! -f $EXT_PLUGIN_CONFIG_DIR/frps/frps.ini ]; then
        return
    fi

    if [ -f /tmp/frps_file.log ]; then
        return
    fi

    if killall -q -0 frps; then
        killall frps
        return
    fi

    sed -i '/localPath/d' $EXT_PLUGIN_CONFIG_DIR/frps/frps.ini
    sed -i 's|log_file = .*|log_file = /tmp/log/frps.log|' $EXT_PLUGIN_CONFIG_DIR/frps/frps.ini

    ln -s $EXT_PLUGIN_CONFIG_DIR/frps/frps.ini /usr/ikuai/www/frps.txt

    frps -c $EXT_PLUGIN_CONFIG_DIR/frps/frps.ini >/dev/dell &
    echo "9" >>/tmp/frpsstart.log
}

frps_start() {

    echo "1" >>/tmp/frpsstart.log
    if [ ! -f $EXT_PLUGIN_CONFIG_DIR/frps/frps.ini ]; then
        echo "2" >>/tmp/frpsstart.log
        echo "[common]" >$EXT_PLUGIN_CONFIG_DIR/frps/frps.ini
        echo "bindPort = 7000" >>$EXT_PLUGIN_CONFIG_DIR/frps/frps.ini
        echo "dashboard_port = 7001" >>$EXT_PLUGIN_CONFIG_DIR/frps/frps.ini
        echo "dashboard_user = admin" >>$EXT_PLUGIN_CONFIG_DIR/frps/frps.ini
        echo "dashboard_pwd = admin	" >>$EXT_PLUGIN_CONFIG_DIR/frps/frps.ini
    fi
    echo "3" >>/tmp/frpsstart.log
    start

}

stop() {
    killall frps
}

disable() {
    killall frps
    rm $EXT_PLUGIN_CONFIG_DIR/frps/frps.ini
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

    echo "${server}" >$EXT_PLUGIN_CONFIG_DIR/frps/frps.config
    echo "${vkey}" >>$EXT_PLUGIN_CONFIG_DIR/frps/frps.config
    echo "${password}" >>$EXT_PLUGIN_CONFIG_DIR/frps/frps.config
    echo "${target}" >>$EXT_PLUGIN_CONFIG_DIR/frps/frps.config
    echo "${local_type}" >>$EXT_PLUGIN_CONFIG_DIR/frps/frps.config

    echo "配置文件已更新："
    cat $EXT_PLUGIN_CONFIG_DIR/frps/frps.config
    if killall -q -0 frps; then
        killall frps
    fi
    start
}

config() {

    if [ -f /tmp/iktmp/import/file ]; then
        filesize=$(stat -c%s "/tmp/iktmp/import/file")
        echo "$filesize" >>/tmp/frpsconfig.log
        if [ $filesize -lt 524288 ]; then

            rm $EXT_PLUGIN_CONFIG_DIR/frps/frps.ini
            mv /tmp/iktmp/import/file $EXT_PLUGIN_CONFIG_DIR/frps/frps.ini
            echo "ok" >>/tmp/frpsconfig.log
            killall frps
            start

        fi

    fi

}

show() {
    Show __json_result__
}

__show_status() {
    if killall -q -0 frps; then
        local status=1
    else
        local status=0
    fi

    if [ ! -f /usr/bin/frps ]; then
        local status=3
    fi

    if [ -f /tmp/frps_file.log ]; then
        local status=2
    fi
    json_append __json_result__ status:int
}

__show_config() {

    if [ ! -f /usr/ikuai/www/frps.txt ]; then
        ln -s $EXT_PLUGIN_INSTALL_DIR/$PLUGIN_NAME/script/frps.ini /usr/ikuai/www/frps.txt
    fi

    local server_addr=$(read_ini_value "common" "server_addr")
    local server_port=$(read_ini_value "common" "bindPort")
    local admin_port=$(read_ini_value "common" "dashboard_port")
    local admin_user=$(read_ini_value "common" "dashboard_user")
    local admin_pwd=$(read_ini_value "common" "dashboard_pwd")

    if [ ! -f /tmp/frps.version ]; then
        frpc -v >/tmp/frps.version
    fi
    version=$(cat /tmp/frps.version)

    json_append __json_result__ server_addr:str
    json_append __json_result__ server_port:str
    json_append __json_result__ admin_user:str
    json_append __json_result__ admin_pwd:str
    json_append __json_result__ admin_port:str
    json_append __json_result__ version:str

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

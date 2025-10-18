#!/bin/bash  
authtool check-plugin 0 >/dev/null || { echo "该插件未被授权！"; exit 1; }
. /etc/mnt/plugins/configs/config.sh
PLUGIN_NAME="vremote"
start()
{
	[ -n "$(cat $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config)" ] || return

	[ -d $EXT_PLUGIN_LOG_DIR ] || mkdir -p $EXT_PLUGIN_LOG_DIR
	echo "启动VRemote" > $EXT_PLUGIN_LOG_DIR/vremote.log
	vremote > $EXT_PLUGIN_LOG_DIR/vremote.log 2>&1 &

	mkdir -p /tmp/vremote
	echo `date +%s` > /tmp/vremote/vremote_start_time
}

stop()
{
	if [ -f /tmp/iktmp/vremote.pid ];then
		kill -9 $(cat /tmp/iktmp/vremote.pid)
		rm -f /tmp/iktmp/vremote.pid
	fi
	sed -i '/vremote/d' /etc/crontabs/root
    rm -f /etc/crontabs/cron.d/vremote

	killall vrtty

	rm -f /tmp/vremote/vremote_start_time
	rm -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/lastShareSyncTime
	rm -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/lastSyncLogId
}

save()
{
	echo "$apiToken" > $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config
	if [ -n "$shareCode" ]; then 
		echo "$shareCode" > $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/sharecode
	else
		rm -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/sharecode
	fi

	if [ "$enableProxy" = "true" ]; then
		touch $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/enableProxy
	else
		rm -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/enableProxy
	fi
		
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

show(){
    Show __json_result__
}

__show_data(){
	local status=0
	local autostart=0
	local lastSyncTime="尚未同步"
	local vntStatus=0
	local virtualIp=""
	local shareCode=""
	local enableProxy="false"
	local runningTime=""

	start_time=$(cat /tmp/vremote/vremote_start_time)
	if [ -n "$start_time" ]; then 
		time=$((`date +%s`-start_time))
		day=$((time/86400))
		[ "$day" = "0" ] && day='' || day="$day天"
		time=`date -u -d @${time} +%H小时%M分%S秒`
		runningTime="已运行: ${day}${time}"
	fi

	if killall -q -0 vnt;then
		virtualIp=$(vnt --info | grep "Virtual ip" | awk -F ":" '{print($2)}')
		vntStatus=1
	fi

	if [ -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config" ]; then
		apiToken=$(cat $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config)
	fi

	if [ -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/enableProxy" ]; then
		enableProxy="true"
	fi

	if [ -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/sharecode" ]; then
		shareCode=$(cat $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/sharecode)
	fi

	[ -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autostart" ] && autostart=1
	if [ -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/lastSyncTime" ]; then
		lastSyncTime=$(cat $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/lastSyncTime)
	fi

	if [ -f "$EXT_PLUGIN_LOG_DIR/vremote_error" ]; then
		lastSyncTime="$lastSyncTime (同步失败)"
	fi

	[ -f /tmp/iktmp/plugins/vremote_installed ] || status=2

	[ -f /tmp/iktmp/vremote.pid ] && status=1

	json_append __json_result__ status:int
	json_append __json_result__ vntStatus:int
	json_append __json_result__ autostart:int
	json_append __json_result__ apiToken:str
	json_append __json_result__ shareCode:str
	json_append __json_result__ lastSyncTime:str
	json_append __json_result__ virtualIp:str
	json_append __json_result__ enableProxy:str
	json_append __json_result__ runningTime:str
}

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

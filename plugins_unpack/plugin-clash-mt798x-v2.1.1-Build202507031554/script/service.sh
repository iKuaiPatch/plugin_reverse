#!/bin/bash 
authtool check-plugin 0 >/dev/null || { echo "该插件未被授权！"; exit 1; }
PLUGIN_NAME=clash
. /etc/mnt/plugins/configs/config.sh

CRASHDIR=$EXT_PLUGIN_INSTALL_DIR/$PLUGIN_NAME/bin
CHROOTDIR=$(chrootmgt get_chroot_dir)

start_ttyd() {

	killall ttyd

	chrootmgt run "$CRASHDIR/ttyd -W -o -m 1 -p 2222 -i 0.0.0.0 $EXT_PLUGIN_INSTALL_DIR/$PLUGIN_NAME/bin/menu.sh > /dev/null 2>&1 &"
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

show() {
	Show __json_result__
}

__show_data() {
	local status=0
	pidof CrashCore >/dev/null && status=1
	[ -f /tmp/iktmp/plugins/clash_installed ] || status=2

	local autostart=0
	[ -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autostart ] && autostart=1

	local yamlStatus=0
	[ -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/yamls/config.yaml ] && yamlStatus=1

	local jsonStatus=0
	[ -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/jsons/config.json ] && jsonStatus=1

	local supportTtyd=0
	[ -f /usr/bin/ttyd ] && supportTtyd=1

	. $EXT_PLUGIN_INSTALL_DIR/$PLUGIN_NAME/bin/configs/ShellCrash.cfg

	local coreInfo=""
	coreInfo="当前内核：$crashcore ($redir_mod)"
	
	local runningTime=""
	start_time=$(cat ${CHROOTDIR}/tmp/ShellCrash/crash_start_time)
	if [ -n "$start_time" ]; then 
		time=$((`date +%s`-start_time))
		day=$((time/86400))
		[ "$day" = "0" ] && day='' || day="$day天"
		time=`date -u -d @${time} +%H小时%M分%S秒`
		runningTime="已运行: ${day}${time}"
	fi

	json_append __json_result__ status:int
	json_append __json_result__ coreInfo:str
	json_append __json_result__ runningTime:str
	json_append __json_result__ autostart:int
	json_append __json_result__ yamlStatus:int
	json_append __json_result__ jsonStatus:int
	json_append __json_result__ supportTtyd:int
	json_append __json_result__ Url:str
	json_append __json_result__ hostdir:str
}

update_yaml() {

	if [ "$fileType" = "yaml" ]; then
		mv /tmp/iktmp/import/file $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/yamls/config.yaml
	elif [ "$fileType" = "json" ]; then
		mv /tmp/iktmp/import/file $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/jsons/config.json
	else
		echo "文件格式不正确!"
		return 1
	fi

	# 如果已经启动，则重新启动
	pidof CrashCore >/dev/null || return 0
	start && return 0
	
	echo "更新订阅地址已经更新，但重启服务失败！"
	return 1
}

download_yaml() {
	cp $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/yamls/config.yaml /tmp/iktmp/export/
}

download_json() {
	cp $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/jsons/config.json /tmp/iktmp/export/
}

update_subUrl() {
	url=$(echo "$suburl" | base64 -d)

	# 校验订阅地址格式
	echo "$url" | grep -E -q '^https?:\/\/[a-zA-Z0-9.-]+(:[0-9]+)?(\/[a-zA-Z0-9._~:/?#@!$&*+=%-]*)?$'
    if [ $? -ne 0 ]; then
		echo "订阅地址格式不正确！"
		return 1
	fi

	# killall clash/bin

	configpath=$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/configs/ShellCrash.cfg
	sed -i '/Url=/d' $configpath && echo "Url='${url}'" >> $configpath

	# export CRASHDIR=$EXT_PLUGIN_INSTALL_DIR/$PLUGIN_NAME/bin
	chrootmgt run "${CRASHDIR}/start.sh get_core_config >/tmp/clashSubupdate.log"

	vSuccess=$(tail -n 1 ${CHROOTDIR}/tmp/clashSubupdate.log | grep "已成功获取配置文件" | wc -l )
		
	if [ $vSuccess -eq 0 ]; then
		echo "更新订阅地址失败,无法连接订阅转换服务器！"
		return 1
	fi

	# 如果已经启动，则重新启动
	pidof CrashCore >/dev/null || return 0
	start && return 0
	
	echo "重启Clash服务失败！"
	return 1
}

start() {

	pidof CrashCore >/dev/null && stop

	# killall clash/bin

	# 检测AdGuardHome 是否启动,如果启动则设置基础DNS为AdGuardHome
	dns_set=$(cat $CRASHDIR/configs/ShellCrash.cfg | grep "dns_nameserver" | grep "127.0.0.1:5353" | wc -l)
	db_port=$(cat $CRASHDIR/configs/ShellCrash.cfg | grep "hostdir" | cut -d ':' -f2 | cut -d '/' -f1)
	PID=$(pidof AdGuardHome | awk '{print $NF}')
	if [ -n "$PID" ]; then
		if [ $dns_set -eq 0 ]; then
			echo "$(date "+%G-%m-%d_%H:%M:%S")~检测到AdGuardHome，设置基础DNS为AdGuardHome" >> /tmp/ShellCrash/ShellCrash.log
			sed -i '/dns_nameserver=/d' $CRASHDIR/configs/ShellCrash.cfg
			echo "dns_nameserver='127.0.0.1:5353'" >>$CRASHDIR/configs/ShellCrash.cfg
		fi
	else
		[ $dns_set -eq 1 ] && sed -i '/dns_nameserver=/d' $CRASHDIR/configs/ShellCrash.cfg
	fi

	# 添加定时任务
	# task1="*/10 * * * * $CRASHDIR/task/task.sh 106 运行时每10分钟自动保存面板配置"
	# task2="$CRASHDIR/task/task.sh 107 服务启动后自动同步ntp时间"
	# echo "$task1" > $CRASHDIR/task/running
	# echo "$task2" > $CRASHDIR/task/afstart

	chrootmgt run "$CRASHDIR/menu.sh -s start >/dev/null"

	# 检查启动是否成功
	i=1
	while [ -z "$test" -a "$i" -lt 5 ];do
		sleep 1
		if curl --version > /dev/null 2>&1;then
			test=$(curl -s http://127.0.0.1:${db_port}/configs | grep -o port)
		else
			test=$(wget -q -O - http://127.0.0.1:${db_port}/configs | grep -o port)
		fi
		i=$((i+1))
	done
	if [ -n "$test" -o -n "$(pidof CrashCore)" ]; then
		echo "启动成功"
		return 0
	else
		echo "服务启动失败, 请检查订阅地址格式、配置文件以及网络连接状态！"
		return 1
	fi
}

stop() {

	# killall clash/bin

	pidof CrashCore >/dev/null || return 0

	chrootmgt run "$CRASHDIR/menu.sh -s stop >/dev/null"

	Vmen=0 success=0
	while true;do
		sleep 1
		pidof CrashCore >/dev/null || { success=1; break; }

		Vmen=$((Vmen + 1))
		[ $Vmen -gt 30 ] && break
	done

	if  [ $success -eq 1 ]; then
		return 0
	else
		echo "停止Clash失败！" 
		return 1
	fi
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

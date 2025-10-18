#!/bin/bash  
authtool check-plugin 0 >/dev/null || { echo "该插件未被授权！"; exit 1; }
PLUGIN_NAME="vnt"
. /etc/mnt/plugins/configs/config.sh

start()
{
	[ -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config" ] || return

	[ -d $EXT_PLUGIN_LOG_DIR ] || mkdir -p $EXT_PLUGIN_LOG_DIR
	echo "启动VNT" > $EXT_PLUGIN_LOG_DIR/vnt.log

	if [ -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/enableProxy" ]; then
		iptables -t nat -A POSTROUTING -o vnt-tun -s 0.0.0.0/0 -j MASQUERADE
	else
		iptables -t nat -D POSTROUTING -o vnt-tun -s 0.0.0.0/0 -j MASQUERADE
	fi

	Vmen=0
	while true; do
		killall vnt
		vnt -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config >> $EXT_PLUGIN_LOG_DIR/vnt.log 2>&1 &
		sleep 3

		vSuccess=$(cat $EXT_PLUGIN_LOG_DIR/vnt.log | tail -n 5 | grep "Successfully" | wc -l)
		if [ $vSuccess -gt 0 ]; then
			echo "启动VNT成功" >> $EXT_PLUGIN_LOG_DIR/vnt.log
			return 0
		fi

		vError=$(cat $EXT_PLUGIN_LOG_DIR/vnt.log | tail -n 5 | grep "IpAlreadyExists" | wc -l)
		if [ $vError -gt 0 ]; then
			echo "启动VNT失败,IP地址已被占用,删除固定IP设置并重试" >> $EXT_PLUGIN_LOG_DIR/vnt.log
			sed -i '/^ip/d' $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config
            continue
		fi

		
		let Vmen=Vmen+1
		[ $Vmen -gt 10 ] && break
	done

	killall vnt
	echo "启动VNT失败,请检查配置文件" 
	return 1
}

stop()
{
	if killall -q -0 vnt;then
		killall vnt
	fi
	# 自启动锁死时可用停止按钮解锁
	if [ ! -f /tmp/iktmp/plugins/vnt_installed ]; then
		touch /tmp/iktmp/plugins/vnt_installed
	fi
}

save()
{
	. /etc/release
	local configpath=$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config
	[ -f "$configpath" ] || touch $configpath

	if [ "$enableProxy" = "true" ]; then
		touch $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/enableProxy
	else
		rm -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/enableProxy
	fi
	
	if [ "$configMode" = "1" ];then
		if [ ! "$token" ]; then
			echo "组网编号为必填项"
			return 1
		fi
		
		sed -i '/^token/d' $configpath && echo "token: ${token}" >> $configpath
		sed -i '/^password/d' $configpath && [ "$password" ] && echo "password: ${password}" >> $configpath
		sed -i '/^server_address/d' $configpath && [ "$serverAddress" ] && echo "server_address: ${serverAddress}" >> $configpath
		sed -i '/^ip/d' $configpath && [ "$ipAddress" ] && echo "ip: ${ipAddress}" >> $configpath
		sed -i '/^name/d' $configpath && [ "$name" ] && echo "name: ${name}" >> $configpath

	else
		configTxt=$(echo "$config" | base64 -d)
		echo "$configTxt" > $configpath
	fi 

	sed -i '/^device_id/d' $configpath && echo "device_id: ${GWID}" >> $configpath
	sed -i '/^disable_stats/d' $configpath && echo "disable_stats: true" >> $configpath
	return 0
}

set_hostname(){

	hostname $name
	
	sqlite3 /etc/mnt/ikuai/config.db "update basic set hostname='$name' where id=1;" >/dev/null 2>&1

	$IK_DIR_SCRIPT/smbd.sh wsdd2_reconf hostname=$name 2>/dev/null 2>&1 &
	killall iksyslogd
	iksyslogd

	echo "127.0.0.1 $name" >/etc/hosts.d/hostname
	cat /etc/hosts.d/* >/etc/hosts
	killall lldpd; lldpd >/dev/null 2>&1 &
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

__show_configFileStream(){
	
	local config=""

	if [ -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config" ]; then
		config=$(cat $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config  | grep -v disable_stats: | grep -v device_id: | base64)
	fi

	json_append __json_result__ config:str
}

__show_config(){
	local status=0
	local autostart=0
	local virtualIp=""
	local token=""
	local name=""
	local password=""
	local serverAddress=""
	local ipAddress=""
	local hostname=$(hostname)
	local enableProxy="false"

	if [ -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config" ]; then
		token=$(grep "token:" $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config | awk -F " " '{print($2)}')
		name=$(grep "name:" $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config | awk -F " " '{print($2)}')
		password=$(grep "password:" $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config | awk -F " " '{print($2)}')
		serverAddress=$(grep "server_address:" $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config | awk -F " " '{print($2)}')
		ipAddress=$(grep "ip:" $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/config | awk -F " " '{print($2)}')
	fi

	[ -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autostart" ] && autostart=1

	[ -f /tmp/iktmp/plugins/vnt_installed ] || status=2

	[ -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/enableProxy ] && enableProxy="true"

	if killall -q -0 vnt;then
		virtualIp=$(vnt --info | grep "Virtual ip" | awk -F ":" '{print($2)}')
		status=1
	fi

	json_append __json_result__ status:int
	json_append __json_result__ autostart:int
	json_append __json_result__ virtualIp:str
	json_append __json_result__ token:str
	json_append __json_result__ name:str
	json_append __json_result__ password:str
	json_append __json_result__ serverAddress:str
	json_append __json_result__ ipAddress:str
	json_append __json_result__ hostname:str
	json_append __json_result__ enableProxy:str
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

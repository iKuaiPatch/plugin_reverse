#!/bin/bash 
authtool check-plugin 0 >/dev/null || { echo "该插件未被授权！"; exit 1; }
PLUGIN_NAME="adguard"
. /etc/mnt/plugins/configs/config.sh

set_auto_start() {
	if [ "$autostart" = "true" ]; then
		[ -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autostart" ] || touch $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autostart
	else
		rm -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autostart
	fi
	return 0
}

set_dns_hijacking() {

	if [ "$dnshijacking" = "true" ]; then
		PID=$(pidof CrashCore | awk '{print $NF}')
		if [ -n "$PID" ]; then
			if iptables -t nat -L shellcrash_dns -n 2>/dev/null | grep -q '^Chain'; then
				echo "检测到Crash正在劫持本机DNS，请先停止Crash或禁用其DNS劫持。"
				return 1
			fi
		fi

		[ -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/dnshijacking" ] || touch $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/dnshijacking
		__do_dns_hijacking start
	else
		rm -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/dnshijacking
		__do_dns_hijacking stop
	fi
	return 0
}

__do_dns_hijacking() {
	action=$1

	if [ "$action" = "start" ]; then
		iptables -t nat -A PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports 5353
		iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5353
		ip6tables -t nat -A PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports 5353
		ip6tables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5353
	fi
	if [ "$action" = "stop" ]; then
		while true; do
			dns5353=$(iptables -t nat -vnL PREROUTING --line-number | grep "5353" | wc -l)
			if [ $dns5353 -gt 0 ]; then
				iptables -t nat -D PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports 5353
				iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5353
				ip6tables -t nat -D PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports 5353
				ip6tables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5353
			else
				break
			fi
		done
	fi

}

show() {
	Show __json_result__
}

__show_data() {

	local status=0

	PID=$(pidof AdGuardHome | awk '{print $NF}')
	[ -n "$PID" ] && status=1
	[ -f /tmp/iktmp/plugins/adguard_installed ] || status=2

	local autostart=0
	[ -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autostart ] && autostart=1

	local dnshijacking=0
	[ -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/dnshijacking ] && dnshijacking=1

	local listenPort="$(grep -A 5 '^dns' $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/AdGuardHome.yaml | grep 'port:' | awk '{print($2)}')"

	local webPort="$(grep -A 5 '^http' $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/AdGuardHome.yaml | grep 'address' | awk -F ':' '{print($3)}')"


	local runningTime=""
	start_time=$(cat /tmp/AdGuardHome/adguards_start_time)
	if [ -n "$start_time" ]; then 
		time=$((`date +%s`-start_time))
		day=$((time/86400))
		[ "$day" = "0" ] && day='' || day="$day天"
		time=`date -u -d @${time} +%H小时%M分%S秒`
		runningTime="已运行: ${day}${time}"
	fi

	json_append __json_result__ autostart:int
	json_append __json_result__ status:int
	json_append __json_result__ listenPort:int
	json_append __json_result__ webPort:int
	json_append __json_result__ dnshijacking:int
	json_append __json_result__ runningTime:str

}

start() {

	PID=$(pidof AdGuardHome | awk '{print $NF}')
	[ -n "$PID" ] && return 0

	# PID=$(pidof CrashCore | awk '{print $NF}')
	# if [ -n "$PID" ]; then
	# 	echo "请先停止ShellClash，再启动AdGuardHome！" 
	# 	return 1
	# fi

	BIN_DIR=$EXT_PLUGIN_INSTALL_DIR/$PLUGIN_NAME/bin

	tar -zxf $BIN_DIR/AdGuardHome.tar.gz -C /tmp
	mkdir -p /tmp/AdGuardHome/data
	ln -sf $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/AdGuardHome.yaml /tmp/AdGuardHome/AdGuardHome.yaml
	ln -sf $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/filters /tmp/AdGuardHome/data/filters

	chmod +x /tmp/AdGuardHome/AdGuardHome 
	/tmp/AdGuardHome/AdGuardHome >/dev/null &
	sleep 5 && rm -f /tmp/AdGuardHome/AdGuardHome 

	if [ -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/dnshijacking" ]; then
		__do_dns_hijacking start
	fi

	# 禁止外网访问
	for iface in $(ip link show | awk -F: '/: wan[0-9]+:/{print $2}' | tr -d ' '); do
		iptables -A INPUT -i "$iface" -p tcp --dport 3000 -j DROP
		iptables -A INPUT -i "$iface" -p tcp --dport 53 -j DROP
	done

	echo `date +%s` > /tmp/AdGuardHome/adguards_start_time
	return 0
}

stop() {

	PID=$(pidof AdGuardHome | awk '{print $NF}')
	[ -n "$PID" ] && kill $PID && rm -rf /tmp/AdGuardHome

	__do_dns_hijacking stop

	# 恢复外网对3000端口的访问
	for iface in $(ip link show | awk -F: '/: wan[0-9]+:/{print $2}' | tr -d ' '); do
		iptables -D INPUT -i "$iface" -p tcp --dport 3000 -j DROP
		iptables -D INPUT -i "$iface" -p tcp --dport 53 -j DROP
	done

	return 0
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

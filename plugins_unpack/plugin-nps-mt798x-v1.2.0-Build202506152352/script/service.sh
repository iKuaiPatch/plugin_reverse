#!/bin/bash 
authtool check-plugin 0 >/dev/null || { echo "该插件未被授权！"; exit 1; }
PLUGIN_NAME="nps"
. /etc/mnt/plugins/configs/config.sh

if [ ! -f /tmp/app/nps/nps ]; then
	mkdir /tmp/app/nps -p
	chmod +x $EXT_PLUGIN_INSTALL_DIR/$PLUGIN_NAME/bin/nps
	ln -fs $EXT_PLUGIN_INSTALL_DIR/$PLUGIN_NAME/bin/nps /tmp/app/nps/nps

	if [ -f $EXT_PLUGIN_CONFIG_DIR/nps/nps.conf ]; then
		ln -s $EXT_PLUGIN_CONFIG_DIR/nps /tmp/app/nps/conf
		chmod +x /tmp/app/nps/nps
		httpport=$(cat /tmp/app/nps/conf/nps.conf | grep "http_proxy_port" | awk -F "=" '{print $2}')
		httpsport=$(cat /tmp/app/nps/conf/nps.conf | grep "https_proxy_port" | awk -F "=" '{print $2}')
		if [ "$httpport" == "80" ]; then
			sed -i "s/http_proxy_port=80/http_proxy_port=880/g" /tmp/app/nps/conf/nps.conf
		fi
		if [ "$httpsport" == "443" ]; then
			sed -i "s/https_proxy_port=443/https_proxy_port=4443/g" /tmp/app/nps/conf/nps.conf
		fi
		rm /tmp/nps_file.log

	else
		# mkdir /etc/mnt/nps -p
		cp $EXT_PLUGIN_INSTALL_DIR/$PLUGIN_NAME/bin/conf/* $EXT_PLUGIN_CONFIG_DIR/nps -f
		ln -s $EXT_PLUGIN_CONFIG_DIR/nps /tmp/app/nps/conf
		chmod +x /tmp/app/nps/nps
		sed -i "s/http_proxy_port=80/http_proxy_port=880/g" /tmp/app/nps/conf/nps.conf
		sed -i "s/https_proxy_port=443/https_proxy_port=4443/g" /tmp/app/nps/conf/nps.conf
		rm /tmp/nps_file.log

	fi

	ln -s $EXT_PLUGIN_INSTALL_DIR/$PLUGIN_NAME/bin/web /tmp/app/nps/web

fi

start() {

	if [ -f $EXT_PLUGIN_CONFIG_DIR/nps/nps.conf ]; then

		ln -s $EXT_PLUGIN_CONFIG_DIR/nps/nps.conf /usr/ikuai/www/nps.conf
		sed -i -e '/^\s*#\?\s*auth_key\s*=/s/^\s*#\?\s*auth_key\s*=\s*.*/auth_key=123qazwsx/' /tmp/app/nps/conf/nps.conf
		sed -i -e '/^\s*#\?\s*auth_crypt_key\s*=/s/^\s*#\?\s*auth_crypt_key\s*=\s*.*/auth_crypt_key=qazwsxedcrfv/' /tmp/app/nps/conf/nps.conf
		/tmp/app/nps/nps >/dev/null &

	fi

}

nps_start() {

	if killall -q -0 nps; then
		killall nps
		return
	fi

	ln -s $EXT_PLUGIN_CONFIG_DIR/nps/nps.conf /usr/ikuai/www/nps.conf
	sed -i -e '/^\s*#\?\s*auth_key\s*=/s/^\s*#\?\s*auth_key\s*=\s*.*/auth_key=123qazwsx/' /tmp/app/nps/conf/nps.conf
	sed -i -e '/^\s*#\?\s*auth_crypt_key\s*=/s/^\s*#\?\s*auth_crypt_key\s*=\s*.*/auth_crypt_key=qazwsxedcrfv/' /tmp/app/nps/conf/nps.conf
	/tmp/app/nps/nps >/dev/null &

}

stop() {
	killall nps
	rm $EXT_PLUGIN_CONFIG_DIR/nps -r
	rm /tmp/app/nps/nps
}

config() {
	echo "1" >>/tmp/npsconfig.log
	if [ -f /tmp/iktmp/import/file ]; then
		filesize=$(stat -c%s "/tmp/iktmp/import/file")
		echo "$filesize" >>/tmp/npsconfig.log
		if [ $filesize -lt 524288 ]; then
			if [ -f $EXT_PLUGIN_CONFIG_DIR/nps/nps.conf ]; then
				rm $EXT_PLUGIN_CONFIG_DIR/nps/nps.conf
				mv /tmp/iktmp/import/file $EXT_PLUGIN_CONFIG_DIR/nps/nps.conf
				echo "ok" >>/tmp/npsconfig.log
				killall nps
				start
			fi
		fi

	fi

}

update_config() {

	#echo "All Parameters: $@" >> /tmp/vnts.log

	# 提取每个参数的值
	for param in "$@"; do
		case $param in
		bridge_port=*)
			bridge_port="${param#*=}"
			;;
		web_username=*)
			web_username="${param#*=}"
			;;
		web_password=*)
			web_password="${param#*=}"
			;;
		web_port=*)
			web_port="${param#*=}"
			;;
		esac
	done

	sed -i -e "/^\s*#\?\s*bridge_port\s*=/s/^\s*#\?\s*bridge_port\s*=\s*.*/bridge_port=${bridge_port}/" /tmp/app/nps/conf/nps.conf

	sed -i -e "/^\s*#\?\s*web_username\s*=/s/^\s*#\?\s*web_username\s*=\s*.*/web_username=${web_username}/" /tmp/app/nps/conf/nps.conf

	sed -i -e "/^\s*#\?\s*web_password\s*=/s/^\s*#\?\s*web_password\s*=\s*.*/web_password=${web_password}/" /tmp/app/nps/conf/nps.conf

	sed -i -e "/^\s*#\?\s*web_port\s*=/s/^\s*#\?\s*web_port\s*=\s*.*/web_port=${web_port}/" /tmp/app/nps/conf/nps.conf

	echo "配置文件已更新："
	# cat /etc/mnt/npc.config
	if killall -q -0 nps; then
		killall nps
	fi
	start
}

show() {

	Show __json_result__
}

__show_status() {
	local status=0
	local npsweb=8080

	if [ ! -f /tmp/app/nps/nps ]; then
		local status=3
	fi

	if [ -f /tmp/nps_file.log ]; then
		local status=2
	fi

	if killall -q -0 nps; then
		local status=1

	fi

	if [ -f /tmp/app/nps/conf/nps.conf ]; then
		local npsweb=$(grep '^web_port\s*=' /tmp/app/nps/conf/nps.conf | sed 's/^\s*web_port\s*=\s*\([0-9]\+\)\s*$/\1/')
		# 提取 web_username 的值
		local web_username=$(grep '^web_username\s*=' /tmp/app/nps/conf/nps.conf | awk -F '=' '{print $2}' | xargs)

		# 提取 web_password 的值
		local web_password=$(grep '^web_password\s*=' /tmp/app/nps/conf/nps.conf | awk -F '=' '{print $2}' | xargs)

		local web_port=$(grep '^web_port\s*=' /tmp/app/nps/conf/nps.conf | awk -F '=' '{print $2}' | xargs)

		local bridge_port=$(grep '^bridge_port\s*=' /tmp/app/nps/conf/nps.conf | awk -F '=' '{print $2}' | xargs)

	fi

	json_append __json_result__ status:int
	json_append __json_result__ npsweb:int
	json_append __json_result__ web_username:str
	json_append __json_result__ web_password:str
	json_append __json_result__ web_port:str
	json_append __json_result__ bridge_port:str
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

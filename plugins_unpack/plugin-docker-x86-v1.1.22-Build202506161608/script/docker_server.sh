#!/bin/bash  
authtool check-plugin 0 >/dev/null || { echo "该插件未被授权！"; exit 1; }

IK_DB_DOCKER="/etc/mnt/ikuai/docker.db"
DISK_USER_PATH="/etc/disk_user"
DOCKER_ENGINE_PATH="/tmp/ikpkg/docker"
DOCKERBIN_ENGINE_PATH="/tmp/ikpkg/docker-bin"
DOCKER_OTHER_CONFIG="--selinux-enabled=false --group root"


boot()
{
	update_db
	cgroupfs-mount
	init isboot
	sleep 10
	$IK_DIR_SCRIPT/ipv6.sh docker_network_init >/dev/null 2>&1 &
}

check_db_corrupt() {
	local result=$(sqlite3 $dbname "PRAGMA integrity_check;")
	if [ "$result" != "ok" ];then
		sqlite3 $dbname ".dump" |sqlite3 ${dbname}.tmp
		mv ${dbname}.tmp $dbname
	fi
	[ -f "${dbname}-journal" ] && rm ${dbname}-journal
}

update_db()
{
	local config="$DOCKER_ENGINE_PATH/script/docker.conf"
	local dbname="$IK_DB_DOCKER"
	local TEMP_FILE="$IK_DB_DOCKER.tmp"
	local TEMP_CONF="/tmp/docker.tmp.conf"

	if [ -f $IK_DB_DOCKER ];then
		local result=$(sqlite3 $dbname "PRAGMA integrity_check;")
		if [ "$result" != "ok" ];then
			sqlite3 $dbname ".dump" |sqlite3 ${dbname}.tmp
			mv ${dbname}.tmp $dbname
		fi
		[ -f "${dbname}-journal" ] && rm ${dbname}-journal

		rm -f ${TEMP_FILE}
		sqlite3 ${TEMP_FILE} < $config
		local now_ver=$(sqlite3 ${TEMP_FILE} "select ver from version")
		local old_ver=$(sqlite3 $dbname "select ver from version")
		if [ "${now_ver:-0}" -le "${old_ver:-0}" ] ;then
			return
		fi
		echo "PRAGMA foreign_keys=OFF;" >$TEMP_CONF
		echo "BEGIN TRANSACTION;" >>$TEMP_CONF
		local tables=$(sqlite3 $dbname ".tables" |sed 's/version//')
		for table_name in $tables ;do
			local headers=$(sqlite3 $dbname -header  -separator "," "select * from $table_name" |sed -n '1p')
			if [ -n "$headers" ];then
				sqlite3 ${TEMP_FILE} "delete from $table_name"
				sqlite3 $dbname ".dump $table_name" |awk '$1=="INSERT"{$3="'$table_name'('$headers')";print}' >> $TEMP_CONF
			fi
		done
		echo "COMMIT;" >> $TEMP_CONF

		sqlite3 ${TEMP_FILE}  < $TEMP_CONF
		mv ${TEMP_FILE} $dbname
		rm -f $TEMP_CONF
	else
		sqlite3 $dbname < $config
	fi
}

init()
{
	local isboot="$1"
	if [ "$isboot" ];then
		local res=$(sql_config_get_list $IK_DB_DOCKER "select * from global where id=1")
		[ -z "$res" ] && return 1
		local $res
	fi

	if ! NewOldVarl enabled workdisk mirrors ;then
		if [ "$enabled" != "yes" ];then
			__stop_dockerd
		else
			__stop_dockerd
			__start_dockerd
			if [ -z "$isboot" ]; then
				$IK_DIR_SCRIPT/ipv6.sh docker_network_init >/dev/null 2>&1 &
			fi
		fi
	fi
}

__check_param()
{
	check_varl \
		'enabled    == "yes" or == "no"' \
		'workdisk  != ""'
}

__monitor_dockerd()
{
	local dockerd_pid=$(pidof dockerd)
	if [ "$dockerd_pid" ];then
		__stop_cron_check
	else
		if [ -f /tmp/iktmp/dockerd.status ];then
			sh /tmp/iktmp/dockerd.status
		fi
	fi
}

__start_cron_check()
{
	Include crond.sh
        crond_clean dockerd_server 
        crond_insert dockerd_server "* * * * * /usr/ikuai/function/docker_server __monitor_dockerd"
        crond_commit
}

__stop_cron_check()
{
	Include crond.sh
        crond_clean dockerd_server 
        crond_commit
}

__check_config_json()
{
	local config_path="$work_path/lib/containers"
	for config_one in $(ls $config_path); do

		local illegal=0
		local config_host_one="$config_path/$config_one/hostconfig.json"
		Privileged=$(jq -r '.Privileged' $config_host_one)
		CapAdd=$(jq -r '.CapAdd' $config_host_one)

		if [[ "$Privileged" != "false" || "$CapAdd" != "null" ]]; then
			illegal=1
		fi
		if [ "$illegal" = "1" ]; then
			chattr -i $config_host_one
			chattr -a $config_host_one
			cat $config_host_one | jq '.Privileged = false | .CapAdd = null' > /tmp/config.$$
			mv /tmp/config.$$ $config_host_one
		fi
		
		local config_path_one="$config_path/$config_one/config.v2.json"	
		for mount_one in $(cat $config_path_one |jq .MountPoints|grep "\"Source\"": | awk '{print $2}');
		do
			[ "$mount_one" ] || continue
			local invalid=0
			if [ "${mount_one:1:15}" != "/etc/disk_user/" ]; then
				invalid=1
			fi
			if [ "${mount_one//\.\./}" != "$mount_one" ]; then
				invalid=1
			fi

			if ! readlink $mount_one | grep -q "^/etc/disk"; then
				invalid=1
			fi

			if [ "$invalid" = "1" ]; then
				chattr -i $config_path_one
				chattr -a $config_path_one
				cat $config_path_one | jq '.MountPoints = {}' > /tmp/config.$$
				mv /tmp/config.$$ $config_path_one
			fi
		done
	done
}


__start_dockerd()
{
	local workdisk=${workdisk//.}
	if [ ! -d "$DISK_USER_PATH/$workdisk" ];then
		return
	fi

	local realpath=$(readlink $DISK_USER_PATH/$workdisk)
	if [ ! "$realpath" ];then
		return
	fi

	local work_path="$realpath/Docker"
	local defaults='"storage-driver":"overlay2","storage-opts":["overlay2.override_kernel_check=true"]'
	local registry_mirrors
	if [ "$mirrors" ];then
		registry_mirrors=",\"registry-mirrors\":[\"${mirrors//,/\",\"}\"]"
	else
		registry_mirrors=",\"registry-mirrors\":[\"https://docker.1ms.run/\"]"
	fi

	__check_config_json

	ulimit -n 10240

	echo "{${defaults}${registry_mirrors}}" > ${DOCKER_ENGINE_PATH}/script/daemon.json

	echo "export PATH=$PATH:${DOCKERBIN_ENGINE_PATH}" >/tmp/iktmp/dockerd.status
	echo dockerd --config-file=${DOCKER_ENGINE_PATH}/script/daemon.json \
		--bridge=none --ip-forward=false --ip-masq=false --iptables=false \
		--data-root=$work_path/lib --exec-root=$work_path/run \
		"${DOCKER_OTHER_CONFIG} >/dev/null 2>&1 &" >>/tmp/iktmp/dockerd.status

	sh /tmp/iktmp/dockerd.status
	__start_cron_check
}

__stop_dockerd()
{
	__stop_cron_check

	rm -f /tmp/iktmp/dockerd.status
	pids_master=$(ps |awk '$5=="dockerd"{print $1}')
	for pid in $pids_master ;do
		pid_second+=$(ps -l |awk -v pid=$pid '$4==pid{print $3}')
	done

	for pid in $pid_second ;do
		pid_three+=$(ps -l |awk -v pid=$pid '$4==pid{print $3}')
	done

	if [ "$pids_master" ];then
		kill $pids_master $pid_second $pid_three
		sleep 1

		for i in {1..10} ;do
			if kill $pids_master >/dev/null 2>&1 ;then
				sleep 1
			else
				break
			fi
		done
		kill $pids_master >/dev/null 2>&1 || kill -9 $pids_master >/dev/null 2>&1 
	fi
	ulimit -n 1024

	brctl show | while read ifname other ;do
		if [ "${ifname:0:3}" = "doc" ];then
			ifconfig $ifname down
			brctl delbr $ifname
		fi
	done
}


save()
{
	__check_param || exit 1
	local sql_param="enabled:str workdisk:str mirrors:str"
	local res=$(sql_config_get_list $IK_DB_DOCKER "select * from global where id=1" prefix=old_)
	[ -z "$res" ] && return 1
	local $res

	if SqlMsg=$(sql_config_update $IK_DB_DOCKER global "id=1" $sql_param) ;then
		init >/dev/null 2>&1 &
		return 0
	else
		echo "$SqlMsg"
		return 1
	fi
}


show()
{
    local __filter=$(sql_auto_get_filter)
    local __order=$(sql_auto_get_order)
    local __limit=$(sql_auto_get_limit)
    local __where="$__filter $__order $__limit"
    Show __json_result__
}

__show_data()
{
	local sql_show="select * from global"
	local data=$(sql_config_get_json $IK_DB_DOCKER "$sql_show")

	json_append __json_result__ data:json
}

__show_status()
{
	if killall -q -0 dockerd ;then
		local status=1
	else
		local status=0
	fi
	json_append __json_result__ status:int
}

__show_disks()
{
	local disks=$($IK_DIR_SCRIPT/utils/file_find.lua "/")
	json_append __json_result__ disks:json
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

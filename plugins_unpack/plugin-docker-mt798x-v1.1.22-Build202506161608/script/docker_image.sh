#!/bin/bash  
authtool check-plugin 0 >/dev/null || { echo "该插件未被授权！"; exit 1; }
DOCKER_PULL_STATUS="/var/run/docker.pull.status"
del()
{
	ikdocker images_del id="$id"
}

pull()
{
	if [ ! "$name" ];then
		echo "Need choose an image name"
		exit 1
	fi

	> $DOCKER_PULL_STATUS
	ikdocker images_pull name="$name" tag="$tag" >/dev/null 2>&1 &
}

__check_param_export()
{
        check_varl \
                'name     != ""' \
                'part     != ""' \
                'filename != ""'
}

EXPORT()
{
	__check_param_export || exit 1
	ikdocker images_export name="$name" tag="$tag" savepath="/$part/$filename"
}

IMPORT()
{
	if [ ! "$filepath" ];then
		echo "Need param filepath"
		exit 1
	fi
	if [ ! -f /etc/disk_user/$filepath ];then
		echo "not found $filepath"
		exit 1
	fi
	rm -rf /tmp/ikpkg/docker/load_progress
	docker load < "/etc/disk_user/$filepath"
	touch /tmp/ikpkg/docker/load_progress
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
	local data
	if data=$(ikdocker images_get) ;then
		json_append __json_result__ data:json
	else
		echo $data
		exit 1
	fi
}

__show_search()
{
	if [ ! "$keyword" ];then
		echo "Need input keyword"
		exit 1
	fi
	local search
        local mirror=$(sqlite3 /etc/mnt/ikuai/docker.db "select mirrors from global")
        if [ -z "$mirror" -o "$mirror" = "https://docker.1ms.run" ]; then
                search=$(wget  -4 -q -O- -t 3 -T30 --no-check-certificate --connect-timeout=30 --dns-timeout=20 "https://docker.1ms.run/v1/search?q=$keyword&n=100&page=1")
                if [ "$search" ]; then
                        search=$(echo $search|jq .results)
                        json_append __json_result__ search:json
                        return 0
                fi
        fi

	if search=$(ikdocker images_search keyword="$keyword") ;then
		json_append __json_result__ search:json
	else
		echo $search
		exit 1
	fi
}


__show_pull_progress()
{
	if [ -f $DOCKER_PULL_STATUS ];then
		local progress=$(awk '{a=a",\""$0"\""} END {gsub("^,","",a);printf "[%s]",a}' $DOCKER_PULL_STATUS) #IgnoreCheck-$0
		local last_line=$(tail -1 $DOCKER_PULL_STATUS)
		if [ "$last_line" == "Finished" ];then
			local status=0
		else
			local status=1
		fi
	else
		local progress='[]'
		local status=-1
	fi

	local pull_progress=$(json_output status:int progress:json)
	json_append __json_result__ pull_progress:json
}

__show_load_progress()
{
	 local progress_file="/tmp/ikpkg/docker/load_progress"
	 if [ -f "$progress_file" ]; then
		local status=1
	 else
		local status=0
	 fi
	 json_append __json_result__ status:int
}

__show_inspect()
{
	if [ ! "$id" ];then
		echo "id cannot empty"
		exit 1
	fi

	if inspect=$(ikdocker images_get_info id="$id") ;then
		json_append __json_result__ inspect:json
	else
		echo $inspect
		exit 1
	fi
}

__show_disks()
{
	local disks=$($IK_DIR_SCRIPT/utils/file_find.lua "/")
	json_append __json_result__ disks:json
}

__show_arch()
{
	local arch
	case "$ARCH" in
	x86) [ "$SYSBIT" = "x32" ]&&arch=386||arch=amd64 ;;
	arm) [ "$SYSBIT" = "x32" ]&&arch=arm||arch=arm64 ;;
	*) arch=$ARCH ;;
	esac

	json_append __json_result__ arch:str
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

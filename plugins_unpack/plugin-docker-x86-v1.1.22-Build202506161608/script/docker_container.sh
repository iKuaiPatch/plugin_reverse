#!/bin/bash  
authtool check-plugin 0 >/dev/null || { echo "该插件未被授权！"; exit 1; }

__check_param()
{
        check_varl \
                'name       != ""' \
                'interface  != ""' \
		'auto_start != ""' \
		'memory     != ""'
}

__check_srcpath()
{
        local ROOT_PATH="/etc/disk_user"
        local srcpaths="$1"
        for path_dir in ${srcpaths//,/ }; do
		local path_dir=${path_dir//:*/}

		if [ "$path_dir" = "/" ]; then
			echo "$path_dir not found"
			return 1
		fi

		local tmp_dir=${path_dir//\.\./}
		if [ "$tmp_dir" != "$path_dir" ]; then
			echo "$path_dir not found"
			return 1
		fi

		local abs_path="${ROOT_PATH}${path_dir}"

		if [ ! -e "$abs_path" ]; then
			echo "$path_dir not found"
			return 1
		fi
		local dir_arry=(${path_dir//\// })
		local hardlink=$(readlink ${ROOT_PATH}/${dir_arry[0]})

		if [ ! -d "$hardlink" ]; then
			echo "$path_dir not found"
			return 1
		fi
		local i=0
		for dir_one in ${dir_arry[*]}; do
			i=$((i+1))
			[ "$i" = "1" ] && continue
			hardlink+="/$dir_one"
		done
		if [ ! -e "$hardlink" ]; then
			echo "$path_dir not found"
			return 1
		fi
        done
}

add()
{
	local id
	__check_param|| exit 1
	__check_srcpath $mounts || exit 1
	if id=$(ikdocker container_add name="$name" image="$image" env="$env" cmd="$cmd" interface="$interface" comment="$comment" mounts="$mounts" auto_start="$auto_start" memory="$memory" ipaddr="$ipaddr" ip6addr="$ip6addr") ;then
		echo "\"$id\""
	else
		echo $id
		exit 1
	fi
}

del()
{
	ikdocker container_del id="$id"
}

up()
{
	local illegal=0
	for doconfig in /etc/disk_user/*/Docker/lib/containers/$id/config.v2.json; do
		Source=$(jq -r '.MountPoints[] | .Source' $doconfig)
		[ -n "$Source" ] && for path in "$Source"; do { ! readlink "$path" | grep -q "^/etc/disk"; } && illegal=1; done
	done
	for doconfig in /etc/disk_user/*/Docker/lib/containers/$id/hostconfig.json; do
		Privileged=$(jq -r '.Privileged' $doconfig)
		CapAdd=$(jq -r '.CapAdd' $doconfig)
		[[ "$Privileged" != "false" || "$CapAdd" != "null" ]] && illegal=1
	done

	if [ $illegal -eq 1 ]; then
		ikdocker container_del id="$id"
		return
	fi

	ikdocker container_start id="$id"
}

down()
{
	ikdocker container_stop id="$id"
}

update()
{
	ikdocker container_update id="$id" interface="$interface" ipaddr="$ipaddr" ip6addr="$ip6addr" memory="$memory"
}

commit()
{
	ikdocker container_commit id="$id" name="$name" tag="$tag"
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
	if data=$(ikdocker container_get) ;then
		json_append __json_result__ data:json
	else
		echo $data
		exit 1
	fi
}

__show_log()
{
	local log
	if log=$(ikdocker container_get_log id="$id") ;then
		json_append __json_result__ log:json
	else
		echo $log
		exit 1
	fi
}

__show_top()
{
	local top
	if top=$(ikdocker container_get_top id="$id") ;then
		json_append __json_result__ top:json
	else
		echo $top
		exit 1
	fi
}

__show_cpuused()
{
	local cpuused
	if cpuused=$(ikdocker container_cpuused) ;then
		json_append __json_result__ cpuused:json
	else
		echo $cpuused
		exit 1
	fi
}

__show_network()
{
	local network
	if network=$(ikdocker network_get_name) ;then
		# network=$(echo "$network" | jq '. + ["host"]') # 添加host网络支持
		json_append __json_result__ network:json
	else
		echo $network
		exit 1
	fi
}

__show_image()
{
	local image
	if image=$(ikdocker images_get_name) ;then
		json_append __json_result__ image:json
	else
		echo $image
		exit 1
	fi
}

__show_memavailable()
{
	Include sys/sysstat.sh
	sysstat_get_mem
	local memavailable="${SYSSTAT_MEM[MemAvailable]}"

	json_append __json_result__ memavailable:int
}
__show_sysbit()
{
	local sysbit=$SYSBIT
	json_append __json_result__ sysbit:str
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

#!/bin/bash  
PLUGIN_NAME="01.ctpanel"
. /etc/release
. /etc/mnt/plugins/configs/config.sh

if [ $ARCH = "x86" ]; then
    EMBED_FACTORY_PART_OFFSET=0
    eep_mtd=/dev/${BOOTHDD}2
    mtd_block=/dev/${BOOTHDD}2
else
    eep_mtd=/dev/$(cat /proc/mtd | grep "Factory" | cut -d ":" -f 1)
    mtd_block="/dev/mtdblock$(grep 'Factory' /proc/mtd | cut -d ':' -f 1 | tr -cd '0-9')"
fi

downloadEEPROM() 
{
    mac=$(echo "$DEVICE_MAC" | tr '[:lower:]' '[:upper:]' | tr -d ":")
    dd if=$eep_mtd of=/tmp/iktmp/export/EEPROM-${mac}.bin
}

restore()
{
    # 校验文件大小
    filesize=$(stat -c%s "/tmp/iktmp/import/file")
    if [ $MODELTYPE = "Q80" -a  $filesize -gt 65536 ]; then
        echo "EEPROM 文件大小不能超过64KB！"
        return 1
    elif [ $MODELTYPE = "Q50" -a  $filesize -gt 65536 ]; then
        echo "EEPROM 文件大小不能超过64KB！"
        return 1
    elif [ $MODELTYPE = "Q1800"  -a  $filesize -gt 524288 ]; then
        echo "EEPROM 文件大小不能超过512KB！"
        return 1
    elif [ $MODELTYPE = "Q3000"  -a  $filesize -gt 2097152 ]; then
        echo "EEPROM 文件大小不能超过2MB！"
        return 1
    elif [ $MODELTYPE = "Q6000"  -a  $filesize -gt 2097152 ]; then
        echo "EEPROM 文件大小不能超过2MB！"
        return 1
    elif [ $ARCH = "x86"  -a  $filesize -gt 5242880 ]; then
        echo "EEPROM 文件大小不能超过5MB！"
        return 1
    fi

    # 更新EEPROM
    if [ $overwrite = "true" ]; then
        dd if=/tmp/iktmp/import/file of=$mtd_block bs=1 seek=0 conv=notrunc
    elif [ $ARCH = "x86" ]; then
        dd if=/tmp/iktmp/import/file of=$mtd_block bs=1 seek=0 conv=notrunc
        cleanCode2="0000000000000000000000000000"
        printf $(echo "$cleanCode2" | sed 's/../\\x&/g') | dd of=$mtd_block bs=$((0x2000)) seek=1 conv=notrunc >/dev/null 2>&1
        printf $(echo "$cleanCode2" | sed 's/../\\x&/g') | dd of=$mtd_block bs=$((0x2008 + 256)) seek=1 conv=notrunc >/dev/null 2>&1
    else
        mac_eth0_offset=$(cat /etc/iksh_config | grep mac_eth0_offset | awk -F "=" '{print($2)'})
        mac_2g_offset=$(cat /etc/iksh_config | grep mac_2g_offset | awk -F "=" '{print($2)'})
        mac_5g_offset=$(cat /etc/iksh_config | grep mac_5g_offset | awk -F "=" '{print($2)'})
        macstr1=$(hexdump -v -s $mac_eth0_offset -n 6 -e '1/1 "%02x"' $eep_mtd)
        macstr2=$(hexdump -v -s $mac_2g_offset -n 6 -e '1/1 "%02x"' $eep_mtd)
        macstr3=$(hexdump -v -s $mac_5g_offset -n 6 -e '1/1 "%02x"' $eep_mtd)
        dd if=$eep_mtd of=/tmp/eep_config_bk bs=1 skip=$EMBED_FACTORY_PART_OFFSET count=160

        dd if=/tmp/iktmp/import/file of=$mtd_block bs=1 seek=0 conv=notrunc
        printf $(echo $macstr1 | sed 's/../\\x&/g') | dd of=$mtd_block bs=$(($mac_eth0_offset)) seek=1 conv=notrunc
        printf $(echo $macstr2 | sed 's/../\\x&/g') | dd of=$mtd_block bs=$(($mac_2g_offset)) seek=1 conv=notrunc
        printf $(echo $macstr3 | sed 's/../\\x&/g') | dd of=$mtd_block bs=$(($mac_5g_offset)) seek=1 conv=notrunc
        printf ":>-<:" | dd of=$mtd_block bs=$((0x188 + $EMBED_FACTORY_PART_OFFSET)) seek=1 conv=notrunc
        dd if=/tmp/eep_config_bk of=$mtd_block bs=1 seek=$EMBED_FACTORY_PART_OFFSET conv=notrunc
        rm /tmp/eep_config_bk
    fi
    return 0
}

show()
{
    Show __json_result__
}

__show_data()
{
    local rcstatus="on"
    
    status=$(hexdump -v -s $((0x87 + $EMBED_FACTORY_PART_OFFSET)) -n 1 -e '1/1 "%02x"' $eep_mtd)
    if [ "$status" = "01" ];then
        rcstatus="off"
    fi

    local resetstatus="on"
    status=$(hexdump -v -s $((0x81 + $EMBED_FACTORY_PART_OFFSET)) -n 1 -e '1/1 "%02x"' $eep_mtd)
    if [ "$status" = "01" ];then
        resetstatus="off"
    fi

    local wifistatus="off"
    status=$(hexdump -v -s $((0x82 + $EMBED_FACTORY_PART_OFFSET)) -n 1 -e '1/1 "%02x"' $eep_mtd)
    if [ "$status" = "01" ];then
        wifistatus="on"
    fi

    local enterprise="off"
    status=$(hexdump -v -s $((0x83 + $EMBED_FACTORY_PART_OFFSET)) -n 1 -e '1/1 "%02x"' $eep_mtd)
    if [ "$status" = "01" ];then
        enterprise="on"
    fi

    local allowSwitchEnt="off"
    actMode=$(authtool check-code)
    [ "$ARCH" = "x86" -a "$actMode" = "PRO" ] && allowSwitchEnt="on"

    local arch=$ARCH
    local gwid=$GWID
	
    json_append __json_result__ arch:str
    json_append __json_result__ gwid:str
    json_append __json_result__ wifistatus:str
    json_append __json_result__ resetstatus:str
    json_append __json_result__ rcstatus:str
    json_append __json_result__ enterprise:str
    json_append __json_result__ allowSwitchEnt:str
    return 0
}

__show_regInfo()
{
    local status="0"
    local mc=""
    local mac=""
    local gwid=""

    authtool check-plugin >/dev/null && status="1"

    mac=$(echo "$DEVICE_MAC" | tr '[:lower:]' '[:upper:]')
    gwid=$(echo "${GWID:0:12}" | tr '[:lower:]' '[:upper:]')
    mc=$(hexdump -v -s $((0x88 + $EMBED_FACTORY_PART_OFFSET)) -n 4 -e '1/1 "%02X"' $eep_mtd)
    
	local regInfo=$(json_output status:str mc:str mac:str gwid:str)
	json_append __json_result__ regInfo:json
	return 0
}

update_gwid()
{
    return 0
    local hex_string=${gwid:0:32}
    if [ "$ARCH" = "x86" ]; then
        printf $(echo $hex_string | sed 's/../\\x&/g') | dd of=$mtd_block bs=$((0x10 + $EMBED_FACTORY_PART_OFFSET)) seek=1 conv=notrunc
    else
        printf $(echo $hex_string | sed 's/../\\x&/g') | dd of=$mtd_block bs=$((0x8 + $EMBED_FACTORY_PART_OFFSET)) seek=1 conv=notrunc
    fi
    
    sed -i "/GWID=/c\GWID=${hex_string}" /etc/release
}

set_rc_trunoff()
{
    if ! authtool check-code; then
        echo "该功能暂不可用，请先激活！"
        return 1
    fi

    local statusStr="\x00"
    [ "$status" = "true" ] && statusStr="\x01"

    printf ${statusStr} | dd of=$mtd_block bs=$((0x87 + $EMBED_FACTORY_PART_OFFSET)) seek=1 conv=notrunc
    
}

set_enterprise()
{
    actMode=$(authtool check-code)
    if [ "$ARCH" != "x86" ] || [ "$actMode" != "PRO" ]; then
        echo "该功能未获授权"
        return 1
    fi
    local statusStr="\x00"
    [ "$enterprise" = "true" ] && statusStr="\x01"

    printf ${statusStr} | dd of=$mtd_block bs=$((0x83 + $EMBED_FACTORY_PART_OFFSET)) seek=1 conv=notrunc

    if [ "$enterprise" = "true" ]; then
        # echo "ENTERPRISE=Enterprise" >> /etc/release
        # sed  -i 's/Build/Enterprise &/' /etc/release
        # sed -i "2i\exit 0 #INS001" /usr/ikuai/script/gv.sh

        cp -f /etc/release /tmp/release
        sed  -i 's/Build/Enterprise &/' /tmp/release
        echo 'ENTERPRISE=Enterprise' >>/tmp/release
        sed -i 's/etc\/release/tmp\/release/' /usr/openresty/lua/lib/ikngx.lua
        # sed -i "2i\. \/tmp\/release #INS001" /usr/ikuai/script/sysstat.sh
    else
        # sed -i '/ENTERPRISE=Enterprise/d' /etc/release
        # sed -i '/#INS001/d' /usr/ikuai/script/gv.sh
        
        sed -i 's/tmp\/release/etc\/release/' /usr/openresty/lua/lib/ikngx.lua
        # sed -i '/#INS001/d' /usr/ikuai/script/sysstat.sh
    fi
    openresty -s stop && sleep 1 && openresty    
}

set_reset_disable()
{
    local statusStr="\x00"
    [ "$status" = "true" ] && statusStr="\x01"
    
    printf ${statusStr} | dd of=$mtd_block bs=$((0x81 + $EMBED_FACTORY_PART_OFFSET)) seek=1 conv=notrunc

}

set_wifi_enhance()
{
    local statusStr="\x00"
    [ "$status" = "true" ] && statusStr="\x01"
    
    printf ${statusStr} | dd of=$mtd_block bs=$((0x82 + $EMBED_FACTORY_PART_OFFSET)) seek=1 conv=notrunc

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

auth_plugin() {

    local PUBLIC_KEY='
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwnlZx4PHTLGIWFSJ7jvQ
X20LkRtRKZuw5MquSqkWOC0itGQX9Ed6VSPG7tx+ZKKY+uEJ2dqwbj4Py2zpyRO3
+fWylLB4IMPmIDYPH8f+JNsxEsxSw+G4tj/bqSzEckI6lfo15vGujUNHqzQtVC6a
GlAZPZNfjd8Yxn7THtWz+G2CYg5ncx20ZdSX9F8S/N9cnHe/8DrZLu3Svk4CwATX
2UjCut+bjij+W6SnwOtVWvvhTnVybV9uGecWnEyegXC6XVO9f7z6Gdsn0zkNHA0z
taED5c4gV21ZKPoxRy7mjgYeNHnkbCYHXuVRA/sahSiSGAaJ0DIAzPd4HFum9Ydb
lQIDAQAB
-----END PUBLIC KEY-----
'
    local TEMP_KEY=$(mktemp)
    local TEMP_ACTCODE=$(mktemp)
    local TEMP_SIGNATURE=$(mktemp)
    echo "$PUBLIC_KEY" > "$TEMP_KEY"

	ARCH=$(cat /etc/release | grep ARCH= | sed 's/ARCH=//g')

    if [ $ARCH = "x86" ]; then
      BOOTHDD=$(cat /etc/release | grep BOOTHDD= | sed 's/BOOTHDD=//g')
      EMBED_FACTORY_PART_OFFSET=0
      eep_mtd=/dev/${BOOTHDD}2
      activationCode=$(hexdump -v -s $((0x8C + $EMBED_FACTORY_PART_OFFSET)) -n 10 -e '1/1 "%02x"' $eep_mtd)
    else
      eep_mtd=/dev/$(cat /proc/mtd | grep "Factory" | cut -d ":" -f 1)
      EMBED_FACTORY_PART_OFFSET=$(cat /etc/release | grep EMBED_FACTORY_PART_OFFSET= | sed 's/EMBED_FACTORY_PART_OFFSET=//g')
      activationCode=$(hexdump -v -s $((0x8C + $EMBED_FACTORY_PART_OFFSET)) -n 10 -e '1/1 "%02x"' $eep_mtd)
    fi

    
    expire_hex=$(hexdump -v -s $((0x2008 + 256 + $EMBED_FACTORY_PART_OFFSET)) -n 8 -e '1/1 "%02x"' $eep_mtd)
    feature_hex=$(hexdump -v -s $((0x2008 + 256 + 8 + $EMBED_FACTORY_PART_OFFSET)) -n 4 -e '1/1 "%02x"' $eep_mtd)

    printf "%s" "$activationCode" > "$TEMP_ACTCODE"
    printf "%s" "$expire_hex" >> "$TEMP_ACTCODE"
    if [  "$feature_hex" != "00000000" ] && [  "$feature_hex" != "ffffffff" ]; then
        printf "%s" "$feature_hex" >> "$TEMP_ACTCODE"
    fi

    dd if=$eep_mtd bs=1 skip=$((0x2008 + $EMBED_FACTORY_PART_OFFSET)) count=256 of=$TEMP_SIGNATURE >/dev/null 2>&1

    openssl dgst -sha256 -verify "$TEMP_KEY" -signature "$TEMP_SIGNATURE" "$TEMP_ACTCODE" >/dev/null
    ret=$? 

    rm $TEMP_KEY $TEMP_ACTCODE $TEMP_SIGNATURE

    if [ $ret -ne 0 ]; then
        echo "系统未正常激活！"
        return 1
    fi

	[[ -z "$FEATURE_ID" || "$FEATURE_ID" = "0" ]] && return 0

	local config_hex=0x$(hexdump -v -s $((0x2008 + 256 + 8 + $EMBED_FACTORY_PART_OFFSET)) -n 4 -e '1/1 "%02x"' $eep_mtd)
	local config_dec=$((config_hex))

    if (( (config_dec & (1 << $FEATURE_ID)) != 0 )); then
        return 0
    else
        echo "该插件未获授权！"
        return 1
    fi
}

Include json.sh,fsyslog.sh,sqlite.sh,check_varl.sh

if [ "$ENABLE_FEATURE_CHECK" = "1" ]; then
	auth_plugin || exit 1
fi

Command $@

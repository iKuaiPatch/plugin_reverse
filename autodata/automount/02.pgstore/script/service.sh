#!/bin/bash  
PLUGIN_NAME="02.pgstore"
. /etc/release
. /etc/mnt/plugins/configs/config.sh

[ $ARCH = "mips" ] && platform="mt7621"
[ $ARCH = "arm" ] && platform="mt798x"
[ $ARCH = "x86" ] && platform="x86"

[ $ARCH = "x86" ]  &&  EMBED_FACTORY_PART_OFFSET=0

debug() {
    debuglog=$( [ -s /tmp/debug_on ] && cat /tmp/debug_on || echo -n /tmp/debug.log )
    if [ "$1" = "clear" ]; then
        rm -f $debuglog && return
    fi

    if [ -f /tmp/debug_on ]; then
        TIME_STAMP=$(date +"%Y%m%d %H:%M:%S")
        echo "[$TIME_STAMP]: PL> $1" >>$debuglog
    fi
}

register() 
{
    if [[ "$code" =~ ^(PRO|STD) ]]; then
        # 新版激活接口，在线激活模式
        result=$(authtool registe $code)
        if [ $? -ne 0 ]; then
            echo "$result"
            return 1 
        else
            (sleep 5; reboot) >/dev/null 2>&1 &
            return 0
        fi
    else
        # 旧的激活方法，离线激活模式
        local hex_string=${code:0:20}

        if [ $ARCH = "x86" ]; then
            printf $(echo $hex_string | sed 's/../\\x&/g') | dd of=/dev/${BOOTHDD}2 bs=$((0x8C)) seek=1 conv=notrunc
            printf $(echo "0000000000000000" | sed 's/../\\x&/g') | dd of=/dev/${BOOTHDD}2 bs=$((0x2000)) seek=1 conv=notrunc
        else
            local mtd_block="/dev/mtdblock$(grep 'Factory' /proc/mtd | cut -d ':' -f 1 | tr -cd '0-9')"
            printf $(echo $hex_string | sed 's/../\\x&/g') | dd of=$mtd_block bs=$((0x8C + $EMBED_FACTORY_PART_OFFSET)) seek=1 conv=notrunc
            printf $(echo "0000000000000000" | sed 's/../\\x&/g') | dd of=$mtd_block bs=$((0x2000 + $EMBED_FACTORY_PART_OFFSET)) seek=1 conv=notrunc
        fi

        (sleep 5; reboot) >/dev/null 2>&1 &
        return 0
    fi
}

compare_version() {

    version1=$1
    version2=$2
    v1_1=`echo $version1 | cut -d '.' -f 1`
    v1_2=`echo $version1 | cut -d '.' -f 2`
    v1_3=`echo $version1 | cut -d '.' -f 3`
    v2_1=`echo $version2 | cut -d '.' -f 1`
    v2_2=`echo $version2 | cut -d '.' -f 2`
    v2_3=`echo $version2 | cut -d '.' -f 3`

    v1sum=$((v1_1 * 10000 + v1_2 * 100 + v1_3))
    v2sum=$((v2_1 * 10000 + v2_2 * 100 + v2_3))
    if [ $v1sum -gt $v2sum ]; then
        return 0 # version1 > version2
    else
        return 1 # version1 <= version2
    fi
}


show()
{
    Show __json_result__
}

__show_data()
{
    # 获取已安装插件信息
    local installed
	local _json
    onlinePlugins=$(cat /etc/mnt/plugins/configs/plugins.json 2>/dev/null)
	for f in $(ls /usr/ikuai/www/plugins) ;do
		if _json=$(cat /usr/ikuai/www/plugins/$f/metadata.json) ;then
            name=$(echo $_json | jq -r '.name')
            oldversion=$(echo $_json | jq -r '.version')
            newversion=$(echo "$onlinePlugins" | jq -r ".[] | select(.name == \"$name\") | .version")
            releasenotes=$(echo "$onlinePlugins" | jq -r ".[] | select(.name == \"$name\") | .releasenotes")
            upgradetype=$(echo "$onlinePlugins" | jq -r ".[] | select(.name == \"$name\") | .upgradetype")
            if compare_version "$newversion" "$oldversion"; then
                _json=$(echo $_json | jq ".newversion = \"$newversion\" | .releasenotes = \"$releasenotes\" | .upgradetype = \"$upgradetype\"")
            fi

			installed+="${installed:+,}$_json"
		fi
	done
	installed="[$installed]"
	json_append __json_result__ installed:json

    # 获取内置存储空间信息
    precentage=""
    totalSize="-"
    avaiableSize="-"

    internel_storage_dir="/etc/mnt"
    [ "$EXT_PLUGIN_RUN_INMEM" = "yes" ] && internel_storage_dir="/etc/mnt"
    echo "$EXT_PLUGIN_INSTALL_DIR" | grep -q "^/etc/log/" && internel_storage_dir="/etc/log"
    [ $ARCH = "x86" ] && internel_storage_dir="/etc/log"
    
    precentage=$(df -h $internel_storage_dir | sed -n '2p' | awk -F " " '{print($5)}' | tr -d '%')
    totalSize=$(df -h $internel_storage_dir | sed -n '2p' | awk -F " " '{print($2)}')
    avaiableSize=$(df -h $internel_storage_dir | sed -n '2p' | awk -F " " '{print($4)}')

    local plusage=$(json_output precentage:str totalSize:str avaiableSize:str)
    json_append __json_result__ plusage:json

    # 获取外置存储空间信息
    precentage=""
    totalSize="-"
    avaiableSize="-"

    if echo "$EXT_PLUGIN_IPK_DIR" | grep -q "^/etc/disk"; then
        if [ -d "$EXT_PLUGIN_IPK_DIR" ] || checkExtStorage; then
            precentage=$(df -h $EXT_PLUGIN_IPK_DIR | sed -n '2p' | awk -F " " '{print($5)}' | tr -d '%')
            totalSize=$(df -h $EXT_PLUGIN_IPK_DIR | sed -n '2p' | awk -F " " '{print($2)}')
            avaiableSize=$(df -h $EXT_PLUGIN_IPK_DIR | sed -n '2p' | awk -F " " '{print($4)}')
        fi
    fi
    local explusage=$(json_output precentage:str totalSize:str avaiableSize:str)
    json_append __json_result__ explusage:json

    local arch=$ARCH
    json_append __json_result__ arch:str

    return 0
}

__show_regInfo()
{
    local status="0"
    local mc=""
    local mac=""
    local gwid=""
    local allowRenew=""
    local expireDate=""

    authtool check-plugin >/dev/null && status="1"

    GWID=$(cat /etc/release | grep GWID= | sed 's/GWID=//g')
	DEVICE_MAC=$(cat /etc/release | grep DEVICE_MAC= | sed 's/DEVICE_MAC=//g' | sed 's/://g')

    mac=$(echo "$DEVICE_MAC" | tr '[:lower:]' '[:upper:]')
    gwid=$(echo "${GWID:0:12}" | tr '[:lower:]' '[:upper:]')
    
    if [ $ARCH = "x86" ]; then
        uuid=$(cat /sys/class/dmi/id/product_uuid | md5sum | tr '[:lower:]' '[:upper:]')
        mc=$(hexdump -v -s $((0x88)) -n 4 -e '1/1 "%02X"' /dev/${BOOTHDD}2)${uuid:5:8}
    else
        local eep_mtd=/dev/$(cat /proc/mtd | grep "Factory" | cut -d ":" -f 1)
        mc=$(hexdump -v -s $((0x88 + $EMBED_FACTORY_PART_OFFSET)) -n 4 -e '1/1 "%02X"' $eep_mtd)
    fi

    admsg=$(authtool admessage)
    allowRenew=$(cat /etc/mnt/plugins/configs/.renew.info | cut -d '|' -f 1)
    expireDate=$(cat /etc/mnt/plugins/configs/.renew.info | cut -d '|' -f 2)

	local regInfo=$(json_output status:str mc:str mac:str gwid:str admsg:str allowRenew:str expireDate:str)
	json_append __json_result__ regInfo:json
	return 0
}

__show_onlinePlugins()
{
    ignoreimg=0
    havenew=0
    release=$(wget -qO- "$RMT_PLUGIN_BASE_URL/release")
    if [ "$release" ]; then
        if [ -f /etc/mnt/plugins/configs/plugins.json ]; then
            old_release=$(cat /etc/mnt/plugins/configs/release 2>/dev/null)
            [ "$old_release" ] || old_release="000000000000#FFFFFFFFFFFF"

            vernum=$(echo $release | awk -F'#' '{print($1)}')
            imghash=$(echo $release | awk -F'#' '{print($2)}')
            old_vernum=$(echo $old_release | awk -F'#' '{print($1)}')
            old_imghash=$(echo $old_release | awk -F'#' '{print($2)}')

            [ "$vernum" -gt "$old_vernum" ] && havenew=1
            [ "$imghash" = "$old_imghash" ] && ignoreimg=1
        else
            havenew=1
        fi
    fi
    
    if [ $havenew -eq 1 ]; then

        [ "$release" ] || release="000000000000#FFFFFFFFFFFF"
        echo "$release" > /etc/mnt/plugins/configs/release

        # 缓存图标文件
        if [ "$ignoreimg" = "0" ]; then
            wget -qO /tmp/tempimg.tar.gz "$RMT_PLUGIN_BASE_URL/img.tar.gz"
            rm -f /etc/mnt/plugins/configs/img/*
            tar -xzf /tmp/tempimg.tar.gz -C /etc/mnt/plugins/configs/img
            rm /tmp/tempimg.tar.gz
        fi
        
        onlinePlugins=$(wget -qO- "$RMT_PLUGIN_BASE_URL/plugins.json")
        onlinePlugins=$(echo "$onlinePlugins" | jq "map(select(.compatibility | index(\"$platform\") or index(\"all\")))")
        echo "$onlinePlugins" > /etc/mnt/plugins/configs/plugins.json
    else
        onlinePlugins=$(cat /etc/mnt/plugins/configs/plugins.json 2>/dev/null)
    fi

    # 过滤已安装的插件
    local installed=""
    for f in $(ls /usr/ikuai/www/plugins) ;do
        if _json=$(cat /usr/ikuai/www/plugins/$f/metadata.json) ;then
            pluginName=$(echo $_json | jq -r '.name')
            installed+="${installed:+,}\"$pluginName\""
        fi
    done
    installed="[$installed]"
    onlinePlugins=$(echo "$onlinePlugins" | jq "map(select(.name as \$n | $installed | index(\$n) | not))")

    json_append __json_result__ onlinePlugins:json
    json_append __json_result__ havenew:int
}

upgrade_online()
{
    metadata=$(jq ".[] | select(.name == \"$name\")" $EXT_PLUGIN_CONFIG_DIR/plugins.json)
    compatibility=$(echo "$metadata" | jq -r '.compatibility')
    version=$(echo "$metadata" | jq -r '.version')
    build=$(echo "$metadata" | jq -r '.build')
    upgradetype=$(echo "$metadata" | jq -r '.upgradetype')
    [ "upgradetype" ] || upgradetype="upgrade"

    if echo "$compatibility" | grep -q "all"; then
        url="$RMT_PLUGIN_BASE_URL/ipk/plugin-$name-v$version-Build$build.ipk"
    else
        url="$RMT_PLUGIN_BASE_URL/ipk/plugin-$name-$platform-v$version-Build$build.ipk"
    fi
    
    if wget -O /tmp/iktmp/import/file $url; then
        __install $upgradetype
    else
        echo "下载安装文件失败，请检查网络！"
        return 1
    fi
}

install_online()
{
    local pluginFeatureId=$(jq -r "map(select(.name == \"$name\"))[0].featureId" /etc/mnt/plugins/configs/plugins.json) 
    [[ -z "$pluginFeatureId" || "$pluginFeatureId" = "null" ]] && pluginFeatureId=0
    if ! authtool check-plugin $pluginFeatureId >/dev/null; then
        echo "无权限安装该插件，请先获得授权！"
        return 1
    fi
    if echo "$compatibility" | grep -q "all"; then
        url="$RMT_PLUGIN_BASE_URL/ipk/plugin-$name-v$version-Build$build.ipk"
    else
        url="$RMT_PLUGIN_BASE_URL/ipk/plugin-$name-$platform-v$version-Build$build.ipk"
    fi
    
    if wget -O /tmp/iktmp/import/file $url; then
        __install new
    else
        echo "下载安装文件失败，请检查网络！"
        return 1
    fi
    
}

install()
{
    __install new
}

__install()
{
    if ! authtool check-plugin >/dev/null; then
        echo "请先激活高级版！"
        return 1
    fi

    installtype=$1
    rm -rf /tmp/iktmp/app_install && mkdir /tmp/iktmp/app_install
    FILE=/tmp/iktmp/import/file
    FILE_tar=/tmp/iktmp/app_install/app.tar.gz
    file_ssl_check=`hexdump -v -s 0x0 -n 7 -e '1/1 "%02x"' $FILE`
    decrypt_result=0
    if [ $file_ssl_check == "53616c7465645f" ];then
        authtool decrypt $FILE $FILE_tar 
        if [ $? -ne 0 ];then
            rm -f $FILE $FILE_tar
            echo "安装失败,请确保固件已经升级到最新版！"
            return 1
        else
            metadata=$(tar -xzOf $FILE_tar ./html/metadata.json)
            plugin_name=$(echo "$metadata" | jq -r '.name')

            if [ "$EXT_PLUGIN_RUN_INMEM" = "yes" ]; then
                mkdir -p $EXT_PLUGIN_IPK_DIR && cp -f $FILE $EXT_PLUGIN_IPK_DIR/$plugin_name.ipk
            fi

            rm -rf $EXT_PLUGIN_INSTALL_DIR/$plugin_name
            mkdir -p $EXT_PLUGIN_INSTALL_DIR/$plugin_name
            tar -xzf $FILE_tar -C $EXT_PLUGIN_INSTALL_DIR/$plugin_name
            rm $FILE $FILE_tar
            bash $EXT_PLUGIN_INSTALL_DIR/$plugin_name/install.sh $installtype
            return 0
        fi
    else
        echo "文件格式校验失败！"
        return 1
    fi
}

uninstall()
{
    type=$(jq -r ".type" ${EXT_PLUGIN_INSTALL_DIR}/${app}/html/metadata.json)
    if [ "$type" = "internal" ]; then
        echo "内置插件不可删除！"
        return 1
    fi
    if [ -f "${EXT_PLUGIN_INSTALL_DIR}/${app}/uninstall.sh" ]; then
        bash "${EXT_PLUGIN_INSTALL_DIR}/${app}/uninstall.sh"
        return 0
    elif [ -f "${INN_PLUGIN_INSTALL_DIR}/${app}/uninstall.sh" ]; then
        bash "${INN_PLUGIN_INSTALL_DIR}/${app}/uninstall.sh"
    else
        echo "未找到删除脚本！"
        return 1
    fi
}

checkExtStorage()
{
    ipkdir=$(find /etc/disk -type d -name "ik-plugin-dir" -print | head -n 1)
    if [ "$ipkdir" ]; then
        if [ "$EXT_PLUGIN_IPK_DIR" = "/etc/mnt/plugins" ]; then
            mv /etc/mnt/plugins/*.ipk $ipkdir
        fi
        EXT_PLUGIN_IPK_DIR=$ipkdir
        sed -i "s|EXT_PLUGIN_IPK_DIR=.*|EXT_PLUGIN_IPK_DIR=$ipkdir|g"  /etc/mnt/plugins/configs/config.sh

        # if [ "$EXT_PLUGIN_CONFIG_DIR" = "/etc/mnt/plugins/configs" ]; then
        #     mv /etc/mnt/plugins/configs/* $ipkdir
        # fi
        # EXT_PLUGIN_CONFIG_DIR=$ipkdir
        # sed -i "s|EXT_PLUGIN_CONFIG_DIR=.*|EXT_PLUGIN_CONFIG_DIR=$ipkdir|g"  /etc/mnt/plugins/configs/config.sh
        return 0
    else
        EXT_PLUGIN_IPK_DIR=/etc/mnt/plugins
        sed -i "s|EXT_PLUGIN_IPK_DIR=.*|EXT_PLUGIN_IPK_DIR=/etc/mnt/plugins|g"  /etc/mnt/plugins/configs/config.sh
        # EXT_PLUGIN_CONFIG_DIR=/etc/mnt/plugins/configs
        # sed -i "s|EXT_PLUGIN_CONFIG_DIR=.*|EXT_PLUGIN_CONFIG_DIR=/etc/mnt/plugins/configs|g"  /etc/mnt/plugins/configs/config.sh
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

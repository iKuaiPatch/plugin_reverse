#!/bin/bash 
FEATURE_ID=3
ENABLE_FEATURE_CHECK=1
PLUGIN_NAME="extapi"
. /etc/mnt/plugins/configs/config.sh
. /etc/release

set_extapi() {
	if [ "$extapi" = "true" ];then
		touch $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/extapi_enabled
    start
	else
		rm -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/extapi_enabled
    stop
	fi
	return 0
}

start() {

  if [ ! -f /usr/openresty/lua/lib/extapi.lua ]; then
    ln -fs $EXT_PLUGIN_INSTALL_DIR/$PLUGIN_NAME/script/extapi.lua /usr/openresty/lua/lib/extapi.lua
    chmod  +x /usr/openresty/lua/lib/extapi.lua
  fi

  if ! grep -q "extapitag" /usr/openresty/lua/lib/webman.lua; then
    codestr1="apiext = require \"extapi\" --extapitag"
    codestr2="ActionUri\[\"\/api\/call\"\] = apiext.ApiCall --extapitag"
    codestr3="VerifyExclUri\[\"\^\/api\/call\$\"\] = true --extapitag"
    sed -i "s/^init()/$codestr1\n$codestr2\n$codestr3\ninit()/g" /usr/openresty/lua/lib/webman.lua
  fi
  
  openresty -s reload
}

stop() {
  sed -i "/extapitag/d" /usr/openresty/lua/lib/webman.lua
	rm -f /usr/openresty/lua/lib/extapi.lua
}

renewToken() {
  token=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 32)
  echo -n "$token" > $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/extapi.token
  openresty -s reload
	return 0
}

addSK5Node() {
  param="name=$name address=$address port=$port type=$type user=$user password=$password interfacename=$interfacename dialer=$dialer"
  /usr/ikuai/function/plugin_socks5 save_server $param
  if [ $? -ne 0 ]; then
    echo "SK5节点 ${name} 保存失败"
    return 1
  fi
  return 0
}

delSK5Node() {
  param="name=$name"
  /usr/ikuai/function/plugin_socks5 delete_server $param
  if [ $? -ne 0 ]; then
    echo "SK5节点 ${name} 删除失败"
    return 1
  fi
  return 0
}

addSK5Rule() { 
  param="address_ip=$address_ip name_sk=$name_sk"
  /usr/ikuai/function/plugin_socks5 save_client $param
  if [ $? -ne 0 ]; then
    echo "SK5规则【${address_ip} ${name_sk}】保存失败"
    return 1
  fi
  return 0
}

delSK5Rule() { 
  param="address_ip=$address_ip"
  /usr/ikuai/function/plugin_socks5 delete_Client $param
  if [ $? -ne 0 ]; then
    echo "SK5规则 ${address_ip} 删除失败"
    return 1
  fi
  return 0
}

enableSK5Rule() { 
  param="address_ip=$address_ip set_enable=true"
  /usr/ikuai/function/plugin_socks5 switch_client_enable $param
  if [ $? -ne 0 ]; then
    echo "SK5规则 ${address_ip} 启用失败"
    return 1
  fi
  return 0
}

disableSK5Rule() { 
  param="address_ip=$address_ip set_enable=false"
  /usr/ikuai/function/plugin_socks5 switch_client_enable $param
  if [ $? -ne 0 ]; then
    echo "SK5规则 ${address_ip} 禁用失败"
    return 1
  fi
  return 0
}

restartSK5() {
  /usr/ikuai/function/plugin_socks5 restart
  if [ $? -ne 0 ]; then
    echo "SK5服务重启失败"
    return 1
  fi
}

modifyWhitelist() {
  param="type=$type configTxt64=$configTxt64"
  /usr/ikuai/function/plugin_socks5 save_whitelist $param
  if [ $? -ne 0 ]; then
    echo "白名单保存失败"
    return 1
  fi
  return 0

}


show() {

    Show __json_result__
}

__show_data() {

    local extapi=0
    local token=$(cat $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/extapi.token)

    [ -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/extapi_enabled" ] && extapi=1
    
    json_append __json_result__ extapi:int
    json_append __json_result__ token:str
}

__show_SK5Rule() {
  param="TYPE=client ipaddress=$address_ip"
  __json_result__=$(/usr/ikuai/function/plugin_socks5 show $param | jq '.clients' 2>/dev/null)
  [ -z "$__json_result__" ] && __json_result__="[]"
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

opensslmd5=$(md5sum $(which openssl) | cut -d ' ' -f 1)
ARCH=$(cat /etc/release | grep ARCH= | sed 's/ARCH=//g')

opensslstatus=0
[ $ARCH = "x86" -a "$opensslmd5" != "8dc48f57409edca7a781e6857382687b" ] && opensslstatus=1
[ $ARCH = "arm" -a "$opensslmd5" != "73b27bccb24fbf235e4cbe0fe80944b1" ] && opensslstatus=1
[ $ARCH = "mips" -a "$opensslmd5" != "2c7b4e5f15868e026c9227a7973b367b" ] && opensslstatus=1
if [ $opensslstatus -eq 1 ]; then
	echo "系统内核错误！"
	exit 1
fi

if [ "$ENABLE_FEATURE_CHECK" = "1" ]; then
	auth_plugin || exit 1
fi

Command $@

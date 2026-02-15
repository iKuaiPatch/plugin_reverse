#!/bin/bash 
FEATURE_ID=0
ENABLE_FEATURE_CHECK=1
PLUGIN_NAME="zerotier"
. /etc/mnt/plugins/configs/config.sh

start() {

    if [ ! -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/join ]; then
        echo "请先设置网络ID"
        return 1
    fi

    if [ ! -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/identity.public ]; then
        secret=$(zerotier-idtool generate)
        echo "$secret" > $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/identity.secret
        echo $secret | awk -F ":" '{print $3}' > $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/identity.public
    fi

    if [ ! -f /var/lib/zerotier-one/identity.public ]; then
        mkdir /var/lib/zerotier-one -p
        echo "9993" >/var/lib/zerotier-one/zerotier-one.port
        ln -sf $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/identity.public /var/lib/zerotier-one/identity.public
        ln -sf $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/identity.secret /var/lib/zerotier-one/identity.secret
    fi
    
    if [ -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/planet ]; then
        ln -sf $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/planet /var/lib/zerotier-one/planet
    fi

    stop
    pidof zerotier-one >/dev/null 2>&1 || {
      zerotier-one -d >/dev/null &
      sleep 2
    }

    join=$(cat $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/join)
    link_status=$(zerotier-cli listnetworks | grep "$join" | tail -1 | awk -F " " '{print $6}')
    if [ "$link_status" != "OK" ]; then
        zerotier-cli join $join >/dev/null
    fi

    zthnhpt5cu=$(iptables -vnL FORWARD --line-number | grep "zthnhpt5cu" | wc -l)
    if [ $zthnhpt5cu -eq 0 ]; then
        iptables -A FORWARD -i zthnhpt5cu -j ACCEPT
        iptables -A FORWARD -i zthnhpt5cu -j ACCEPT
        iptables -t nat -A POSTROUTING -o zthnhpt5cu -j MASQUERADE
    fi
    mkdir -p /tmp/zerotier 
    echo `date +%s` > /tmp/zerotier/zerotier_start_time
    return 0

}

stop() {

    for i in $(seq 1 5); do
      pidof zerotier-one >/dev/null 2>&1 || break
      killall zerotier-one
      sleep 1
    done

    kill -9 $(pidof zerotier-one)

    zthnhpt5cu=$(iptables -vnL FORWARD --line-number | grep "zthnhpt5cu" | wc -l)
    if [ $zthnhpt5cu -gt 0 ]; then
        iptables -D FORWARD -i zthnhpt5cu -j ACCEPT
        iptables -D FORWARD -i zthnhpt5cu -j ACCEPT
        iptables -D nat -I POSTROUTING -o zthnhpt5cu -j MASQUERADE
    fi
    rm -rf /tmp/zerotier
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

upload_planet() {
  if [ -f /tmp/iktmp/import/file ]; then
      mv /tmp/iktmp/import/file $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/planet
      rm /var/lib/zerotier-one/planet
      ln -sf $EXT_PLUGIN_CONFIG_DIR/zerotier/planet /var/lib/zerotier-one/planet
      pidof zerotier-one >/dev/null 2>&1 && {
        killall zerotier-one
        start
      }
  fi
}

remove_planet() {
  rm -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/planet
  rm -f /var/lib/zerotier-one/planet
  pidof zerotier-one >/dev/null 2>&1 && {
    killall zerotier-one
    start
  }
  return 0
}

save() {
  echo "${networkId}" >$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/join
  pidof zerotier-one >/dev/null 2>&1 && {
    killall zerotier-one
    start
  }
  return 0
}

show() {

    Show __json_result__
}

__show_data() {

    local status=0
	  local autostart=0
    local runningTime=""
	  local virtualIp="未获取"
    local networkId=""
    local networkName="未获取"
    local networkType="未获取"
    local linkStatus="未连接"
    

    if [ -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/join ]; then
      networkId=$(cat $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/join)
    fi

    [ -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autostart" ] && autostart=1
    [ -f /tmp/iktmp/plugins/${PLUGIN_NAME}_installed ] || status=2
    if killall -q -0 zerotier-one; then
      networkInfo=$(zerotier-cli listnetworks | grep "$networkId" | tail -1)
      if [ "$networkInfo" ]; then

        status=1
        local start_time=$(cat /tmp/zerotier/zerotier_start_time)
        if [ -n "$start_time" ]; then 
          time=$((`date +%s`-start_time))
          day=$((time/86400))
          [ "$day" = "0" ] && day='' || day="$day天"
          time=`date -u -d @${time} +%H小时%M分%S秒`
          runningTime="已运行: ${day}${time}"
        else 
          runningTime="已运行: 0小时0分1秒"
        fi

        networkName=$(echo "$networkInfo" | awk -F " " '{print $4}')
        linkStatus=$(echo "$networkInfo" | awk -F " " '{print $6}' | tr '[:upper:]' '[:lower:]')
        networkType=$(echo "$networkInfo" | awk -F " " '{print $7}' | tr '[:upper:]' '[:lower:]')
        virtualIp=$(echo "$networkInfo" | awk -F " " '{print $9}')
        virtualIp=${virtualIp%/*}
        [ "$networkType" = "public" ] && networkType="公开网络" || networkType="私有网络"
        [ "$linkStatus" = "ok" ] && linkStatus="连接正常" 
        [ "$linkStatus" = "access_denied" ] && linkStatus="连接被拒绝"
        [ "$linkStatus" = "offline" ] && linkStatus="未连接" 
        [ "$linkStatus" = "not_found" ] && linkStatus="目标网络不存在"

      fi
    fi

    json_append __json_result__ status:int
    json_append __json_result__ autostart:int
    json_append __json_result__ runningTime:str
    json_append __json_result__ networkId:str
    json_append __json_result__ networkName:str
    json_append __json_result__ linkStatus:str
    json_append __json_result__ networkType:str
    json_append __json_result__ virtualIp:str
    
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

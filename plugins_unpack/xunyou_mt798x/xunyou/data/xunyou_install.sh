#!/bin/sh
echo "修正添加系统版本"
cat /etc/release|grep "LINUX_VERSION"|awk -F "=" '{print $2}' >/etc/openwrt_version

[ -f /etc/profile ] && . /etc/profile >/dev/null
INSTALL_ROUTER="${1}"
INSTALL_MODEL="${2}"
ACTION3="${3}"
ACTION4="${4}"

SYSTEM_TYPE=""
PLUGIN_DIR=""
IF_NAME=""
VENDOR=""
MODEL=""
VERSION=""
PLUGIN_VERSION=""
IF_MAC=""
PLUGIN_MOUNT_DIR=""
PLUGIN_CONF=""
PLUGIN_VERSION=""
HARDWARE_TYPE=""
CPU_TYPE=""

WORK_DIR="/tmp/xunyou"
INSTALL_DIR="/tmp/.xunyou_install"
BACKUP_DIR="${INSTALL_DIR}/bak"
DOWNLOAD_DIR="${INSTALL_DIR}/download"

PLUGIN_CONF="${WORK_DIR}/conf/plugin.conf"
INSTALL_JSON="${INSTALL_DIR}/install.json"
DEV_INFO="${INSTALL_DIR}/dev-info"
CORE_TAR="${DOWNLOAD_DIR}/xunyou.tar.gz"
KO_TAR="${DOWNLOAD_DIR}/ko.tar.gz"

OLD_VERSION=""
OLD_TITLE=""

CURL_CMD=""

OPENWRT="openwrt"
ASUS_MERLIN="merlin"
INSTALL_LOG="/tmp/.xunyou_install.log"

#返回码说明
#RET_OK=0
#RET_UNKOWN_SYSTEM_TYPE=1
#RET_LAN_MAC_NOT_FOUND=2
#RET_DOWNLOAD_FAILED=3
#RET_MD5_MISMATCH=4
#RET_PARSE_FAILED=5
#RET_BACKUP_FAILED=6
#RET_SPACE_NOT_ENOUGH=7
#RET_INSTALL_FAILED=8
#RET_START_FAILED=9

get_json_value()
{
    local json=${1}
    local key=${2}
    local line=`echo ${json} | tr -d "\n " | awk -F"[][}{,]" '{for(i=1;i<=NF;i++) {if($i~/^"'${key}'":/) print $i}}' | tr -d '"' | sed -n 1p`
    local value=${line#*:}
    echo ${value}
}

log()
{
    echo "${1}"
    echo [`date +"%Y-%m-%d %H:%M:%S"`] "${1}" >> ${INSTALL_LOG}
}

post_es_log()
{   
	echo "现在在这里log"
    if [ -z "$CURL_CMD" ]; then
        return 0;
    fi

    if [ -f ${PLUGIN_DIR}/version ]; then
        PLUGIN_VERSION=`cat ${PLUGIN_DIR}/version`
    fi

    local guid=`echo -n ''${IF_MAC}'merlinrouterxunyou2020!@#$' | md5sum | awk -F ' ' '{print $1}'`

    if [ "$2" == "fail" ]; then
        local error_code="$3"
    else
        local error_code="N/A"
    fi

    local device_id="${guid}"

    if [ "$1" == "install" ]; then
        event_id="r_install"
		
        curl -s -m 20 --connect-timeout 10 --retry 3 -k -X POST -d "{\"uid\":\"0\", \"cookie_id\": \"${guid}\", \"device_vendors\":\"${VENDOR}\", \"device_model\":\"${MODEL}\", \"device_version\":\"${VERSION}\", \"device_type\":4, \"device_id\":\"${device_id}\", \"version_id\":\"${PLUGIN_VERSION}\", \"x_event_id\":\"${event_id}\", \"x_feature\":\"$2\", \"x_content\":\"${error_code}\", \"hardware_type\":\"${HARDWARE_TYPE}\", \"cpu_type\":\"${CPU_TYPE}\", \"system_type\":\"${SYSTEM_TYPE}\", \"lan_mac\":\"${IF_MAC}\"}" --header "Content-type: application/json" http://open-data-router-api.wyjsq.com:29200/v1/xunyou_event_track >/dev/null 2>&1
        if [ $? -ne 0 ] ;then
            log "Curl post es public failed!1"
        fi
    elif [ "$1" == "install_start" ]; then
        curl -s -m 20 --connect-timeout 10 --retry 3 -k -X POST -d "{\"uid\":\"0\", \"cookie_id\": \"${guid}\", \"device_vendors\":\"${VENDOR}\", \"device_model\":\"${MODEL}\", \"device_version\":\"${VERSION}\", \"device_type\":4, \"device_id\":\"${device_id}\", \"version_id\":\"${PLUGIN_VERSION}\", \"x_event_id\":\"r_launch_after_install\", \"x_feature\":\"$2\", \"x_content\":\"${error_code}\", \"hardware_type\":\"${HARDWARE_TYPE}\", \"cpu_type\":\"${CPU_TYPE}\", \"system_type\":\"${SYSTEM_TYPE}\", \"lan_mac\":\"${IF_MAC}\"}" --header "Content-type: application/json" http://open-data-router-api.wyjsq.com:29200/v1/xunyou_event_track >/dev/null 2>&1
        if [ $? -ne 0 ] ;then
            log "Curl post es public failed!2"
        fi
    elif [ "$1" == "restore_backup" ]; then
        curl -s -m 20 --connect-timeout 10 --retry 3 -k -X POST -d "{\"uid\":\"0\", \"cookie_id\": \"${guid}\", \"device_vendors\":\"${VENDOR}\", \"device_model\":\"${MODEL}\", \"device_version\":\"${VERSION}\", \"device_type\":4, \"device_id\":\"${device_id}\", \"version_id\":\"${PLUGIN_VERSION}\", \"x_event_id\":\"r_restore_backup\", \"x_feature\":\"$2\", \"x_content\":\"${error_code}\", \"hardware_type\":\"${HARDWARE_TYPE}\", \"cpu_type\":\"${CPU_TYPE}\", \"system_type\":\"${SYSTEM_TYPE}\", \"lan_mac\":\"${IF_MAC}\"}" --header "Content-type: application/json" http://open-data-router-api.wyjsq.com:29200/v1/xunyou_event_track >/dev/null 2>&1
        if [ $? -ne 0 ] ;then
            log "Curl post es public failed!3"
        fi
    elif [ "$1" == "backup_start" ]; then
        curl -s -m 20 --connect-timeout 10 --retry 3 -k -X POST -d "{\"uid\":\"0\", \"cookie_id\": \"${guid}\", \"device_vendors\":\"${VENDOR}\", \"device_model\":\"${MODEL}\", \"device_version\":\"${VERSION}\", \"device_type\":4, \"device_id\":\"${device_id}\", \"version_id\":\"${PLUGIN_VERSION}\", \"x_event_id\":\"r_launch_backup\", \"x_feature\":\"$2\", \"x_content\":\"${error_code}\", \"hardware_type\":\"${HARDWARE_TYPE}\", \"cpu_type\":\"${CPU_TYPE}\", \"system_type\":\"${SYSTEM_TYPE}\", \"lan_mac\":\"${IF_MAC}\"}" --header "Content-type: application/json" http://open-data-router-api.wyjsq.com:29200/v1/xunyou_event_track >/dev/null 2>&1
        if [ $? -ne 0 ] ;then
            log "Curl post es public failed!4"
        fi
    else
        return 0
    fi
}

download()
{
    local url="$1"
    local file="$2"
    local md5="$3"

    curl -L -s -k "$url" -o "${file}" >/dev/null 2>&1 || \
        wget -q --no-check-certificate "$url" -O "${file}" >/dev/null 2>&1 || \
        curl -s -k "$url" -o "${file}" >/dev/null 2>&1

    if [ $? -ne 0 ]; then
        log "Failed: curl (-L) -s -k ${url} -o ${file} ||
            wget -q --no-check-certificate $url -O ${file}!"
        return 3
    fi

    if [ -n "${md5}" ]; then
        local download_md5=`md5sum ${file} | awk '{print $1}'`
        if [ $? -ne 0 ]; then
            log "Execute md5sum failed!"
            return 4
        fi

        download_md5=`echo ${download_md5} | tr '[A-Z]' '[a-z]'`
        local expected_md5=`echo ${md5} | tr '[A-Z]' '[a-z]'`

        if [ "${download_md5}" != "${expected_md5}" ]; then
            log "The checksum of ${file} does not match!"
            return 11
        fi
    fi

    return 0
}

get_architecture()
{
    arm=$(echo "${MODEL}" | grep "arm")
    if [ "" != "${arm}" ];then
        MODEL="arm32"
        return 0
    fi

    aarch64=$(echo "${MODEL}" | grep "aarch64")
    if [ "" != "${aarch64}" ];then
        MODEL="arm64"
        return 0
    fi

    mips=$(echo "${MODEL}" | grep "mips")
    if [ "" != "${mips}" ];then
        MODEL="mips"
        return 0
    fi

    x86_64=$(echo "${MODEL}" | grep "x86_64")
    if [ "" != "${x86_64}" ];then
        MODEL="x86"
        return 0
    fi
    return 1
}

get_mount_point() 
{
    [ $# -ne 1 ] && return 1

    local mount_point=$1
    while true
    do
        if [ "$mount_point" = "/" ]
        then
            break
        fi

        if [ ! -z "$(df -k | grep -m 1 -E "[ \t]+$mount_point[ \t]*$" | grep -v 'grep')" ]
        then
            break
        fi

        mount_point=$(dirname $mount_point)
    done
    echo $mount_point
    return 0
}

install_init_with_param() 
{
	echo "安装前定义"
    local router="${INSTALL_ROUTER}"
	echo "${router}"
    case "${router}" in
    ${OPENWRT})
        mkdir -p ${INSTALL_DIR}
        mkdir -p ${DOWNLOAD_DIR}
        SYSTEM_TYPE="openwrt"
        PLUGIN_DIR="/tmp/data/xunyou"
        IF_NAME="lan1"
        VENDOR="OPENWRT"
        MODEL="${INSTALL_MODEL}"
        VERSION="1.0"
        get_architecture
        ;;
    *)
        return 1
        ;;
    esac 
    
    if [ "${ACTION3}" == "-i" ]; then
        [ -n "${ACTION4}" ] && IF_NAME=${ACTION4}
    fi

    PLUGIN_MOUNT_DIR=$(get_mount_point "${PLUGIN_DIR}") || return 1
    echo "PLUGIN_MOUNT_DIR:${PLUGIN_MOUNT_DIR}"
    [ ! -d "${PLUGIN_MOUNT_DIR}" ] && return 1
    
    IF_MAC=`ip address show ${IF_NAME} | grep link/ether | awk -F ' ' '{print $2}' | tr '[A-Z]' '[a-z]'`
    if [ -z "${IF_MAC}" ]; then
        log "Can't find the lan mac!"
        return 2
    fi

    if [ -f ${PLUGIN_DIR}/version ]; then
        PLUGIN_VERSION=`cat ${PLUGIN_DIR}/version`
    fi

    return 0
}

install_init()
{
	echo "安装"
    local library_path=`echo ${LD_LIBRARY_PATH} | sed "s#${WORK_DIR}/lib:##g"`
    export LD_LIBRARY_PATH=${library_path}

    rm -f ${INSTALL_LOG}

    log "Begin to install plugin."

    mkdir -p ${INSTALL_DIR}
    mkdir -p ${DOWNLOAD_DIR}

    if [ -d "/koolshare" ]; then
        SYSTEM_TYPE="merlin"
        PLUGIN_DIR="/koolshare/xunyou"
        PLUGIN_MOUNT_DIR="/jffs"
        IF_NAME="br0"
        VENDOR=`nvram get wps_mfstring`
        MODEL=`nvram get productid`
        VERSION=`nvram get buildno`
        if [ -z "$VERSION" ]; then
            VERSION="386"
        fi
    elif [ -d "/jffs" ]; then
        SYSTEM_TYPE="asus"
        PLUGIN_DIR="/jffs/xunyou"
        PLUGIN_MOUNT_DIR="/jffs"
        IF_NAME="br0"
        VENDOR=`nvram get wps_mfstring`
        MODEL=`nvram get productid`
        VERSION=`nvram get buildno`
        if [ -z "$VERSION" ]; then
            VERSION="386"
        fi
    elif [ -d "/var/tmp/misc2" ]; then
        SYSTEM_TYPE="linksys"
        PLUGIN_DIR="/var/tmp/misc2/xunyou"
        PLUGIN_MOUNT_DIR="/var/tmp/misc2"
        IF_NAME="br0"
        VENDOR=`nvram kget manufacturer`
        MODEL=`nvram kget modelNumber`
        VERSION=`awk -F' ' '{printf $2}' /etc/fwversion`
    elif [ -d "/etc/oray" ]; then
        SYSTEM_TYPE="oray"
        PLUGIN_DIR="/xunyou"
        PLUGIN_MOUNT_DIR="/"
        IF_NAME="lan1"
        VENDOR=`awk -F '=' '$1=="DEVICE_MANUFACTURER" {print $2}' /etc/device_info  | tr -d \'\"`
        MODEL=`awk -F '=' '$1=="DEVICE_REVISION" {print $2}' /etc/device_info  | tr -d \'\"`
        VERSION=`cat /etc/openwrt_version`
    else
        local hostname=`uname -n`
        if [ "${hostname}" == "XiaoQiang" ]; then
            SYSTEM_TYPE="xiaomi"
            PLUGIN_DIR="/userdisk/appdata/2882303761520108685"
            PLUGIN_MOUNT_DIR="/userdisk"
            IF_NAME="lan1"
            VENDOR="XIAOMI"
            MODEL=`uci get /usr/share/xiaoqiang/xiaoqiang_version.version.HARDWARE`
            VERSION=`uci get /usr/share/xiaoqiang/xiaoqiang_version.version.ROM`
        elif [ "${hostname}" == "ARS2" ]; then
            SYSTEM_TYPE="koolshare"
            PLUGIN_DIR="/xunyou"

            PLUGIN_MOUNT_DIR="/"
            IF_NAME="eth1"
            VENDOR="KOOLSHARE"
            MODEL="ARS2"
            VERSION=`cat /etc/openwrt_version`
        else
            curl -s http://127.0.0.1/currentsetting.htm | tr '\r' '\n' > /tmp/.xunyou_tmp
            if [ ! -f /tmp/.xunyou_tmp ]; then
                log "Failed: curl -s --connect-timeout 3 --retry 3 http://127.0.0.1/currentsetting.htm"
                return 1
            fi

            local model=`awk -F"=" '$1=="Model" {print $2}' /tmp/.xunyou_tmp`
            local version=`awk -F"=" '$1=="Firmware" {print $2}' /tmp/.xunyou_tmp`

            rm -f /tmp/.xunyou_tmp

            if [ -n ${model} -a -n ${version} ]; then
                SYSTEM_TYPE="netgear"
                PLUGIN_MOUNT_DIR="/data"
                IF_NAME="br0"
                VENDOR="NETGEAR"
                MODEL="${model}"
                VERSION="${version#V*}"
                if [ ${MODEL:0:6} == "RAX120" ]; then
                    PLUGIN_DIR="/tmp/data/xunyou"
                    PLUGIN_MOUNT_DIR="/tmp/data"
                else
                    PLUGIN_DIR="/data/xunyou"
                fi
            else
                log "Unknown system type!"
                return 1
            fi
        fi
    fi

    IF_MAC=`ip address show ${IF_NAME} | grep link/ether | awk -F ' ' '{print $2}' | tr '[A-Z]' '[a-z]'`
    if [ -z "${IF_MAC}" ]; then
        log "Can't find the lan mac!"
        return 2
    fi

    if [ -f ${PLUGIN_DIR}/version ]; then
        PLUGIN_VERSION=`cat ${PLUGIN_DIR}/version`
    fi

    log "SYSTEM_TYPE=${SYSTEM_TYPE}"
    
    HARDWARE_TYPE=$(uname -m)
    if [ "${SYSTEM_TYPE}" == "merlin"  -o "${SYSTEM_TYPE}" == "asus" ]; then
        CPU_TYPE=$(cat /proc/cpuinfo | grep "CPU architecture" | cut -d' ' -f3 | head -n1)
    fi

    return 0
}



download_install_json()
{
    log "vendor=${VENDOR}, model=${MODEL}, version=${VERSION}"
    local url

    curl -L -s -k -X POST -H 'Content-Type: application/json' -d '{"alias":"'"${VENDOR}"'","model":"'"${MODEL}"'","version":"'"${VERSION}"'"}' https://router.xunyou.com/index.php/vendor/get-info -o ${DEV_INFO} >/dev/null 2>&1  || \
        wget -qO- --no-check-certificate --post-data '{"alias":"'"${VENDOR}"'","model":"'"${MODEL}"'","version":"'"${VERSION}"'"}' https://router.xunyou.com/index.php/vendor/get-info -O ${DEV_INFO} >/dev/null 2>&1  || \
        curl -s -k -X POST -H 'Content-Type: application/json' -d '{"alias":"'"${VENDOR}"'","model":"'"${MODEL}"'","version":"'"${VERSION}"'"}' https://router.xunyou.com/index.php/vendor/get-info -o ${DEV_INFO} >/dev/null 2>&1

    if [ $? -ne 0 ]; then
        log "get dev info failed!"
        return 3
    fi
    
    local resp_info_json=`cat ${DEV_INFO}`
  
    #判断网站返回的info信息是否正确
    local key="id"
    local value=`get_json_value "${resp_info_json}" "${key}"`

    if [ -z "${value}" ];then
        log "Can't find id!"
        return 5
    fi

    if [ ${value} -ne 1 ];then
            if [ "${SYSTEM_TYPE}" == "merlin"  -o "${SYSTEM_TYPE}" == "asus" ]; then
                if [ "${CPU_TYPE}" == "7" ];then
                    url="https://partnerdownload.xunyou.com/routeplugin/merlin/arm-7/386/install.json"
                elif [ "${CPU_TYPE}" == "8" ];then
                    url="https://partnerdownload.xunyou.com/routeplugin/merlin/arm-8/386/install.json"
                else
                    log "decive type not arm7/arm8"
                    return 1
                fi
            else
                log "The id is error: ${value}!"
                return 5
            fi
    else
        #获取install.json的下载路径
        key="url"
        value=`get_json_value "${resp_info_json}" "${key}"`
        if [ -z "${value}" ];then
            log "Can't find the install json's url!"
            return 5
        fi

        url=`echo ${value} | sed 's/\\\\//g'`
    fi

    download ${url} ${INSTALL_JSON}
    ret=$?
    if [ ${ret} -ne 0 ]; then
        return ${ret}
    fi

    log "Download install json file success."

    #调整install.json文件的排版格式，便于后续解析
    sed -e 's/,/\n,\n/g' -e 's/{/\n{\n/g' -e 's/}/\n}\n/g' -e 's/\[/\n\[\n/g' -e 's/\]/\n\]\n/g' -e 's/[ \t]//g' -i ${INSTALL_JSON}
    sed '/^$/d' -i ${INSTALL_JSON}

    return 0
}

download_plugin()
{
    local state
    local core_md5
    local core_url
    local lib_name
    local lib_keyfile
    local lib_md5
    local lib_url
    local lib_file
    local kernel
    local kernel_md5
    local kernel_url
    local libevent_openssl_md5
    local libevent_openssl_url
    local libevent_openssl_file
    local download_related_lib=0

    local kernel_release=`uname -r`

    while read line;
    do
        line=`echo ${line} | tr -d ','`

        if [ "${line}" == '"name":"core"' ]; then
            state="core"
            continue
        elif [ "${line}" == '"name":"common"' ]; then
            state="core"
            continue
        elif [ "${line}" == '"name":"libs"' ]; then
            state="libs"
            continue
        elif [ "${line}" == '"name":"kos"' ]; then
            state="kos"
            continue
        fi

        if [ "${state}" == "core" ]; then
            if [ "${line%%:*}" == '"checksum"' ]; then
                core_md5=`echo ${line#*:} | tr -d '"'`
            elif [ "${line%%:*}" == '"url"' ]; then
                core_url=`echo ${line#*:} | tr -d '"'`
            fi

            if [ -n "${core_md5}" -a -n "${core_url}" ]; then
                download ${core_url} ${CORE_TAR} ${core_md5}
                ret=$?
                if [ ${ret} -ne 0 ]; then
                    return ${ret}
                fi

                core_md5=""
                core_url=""
            fi
        elif [ "${state}" == "libs" ]; then
            if [ "${line%%:*}" == '"name"' ]; then
                lib_name=`echo ${line#*:} | tr -d '"'`
            elif [ "${line%%:*}" == '"keyfile"' ]; then
                lib_keyfile=`echo ${line#*:} | tr -d '"'`
            elif [ "${line%%:*}" == '"checksum"' ]; then
                lib_md5=`echo ${line#*:} | tr -d '"'`
            elif [ "${line%%:*}" == '"url"' ]; then
                lib_url=`echo ${line#*:} | tr -d '"'`
            fi

            if [ -n "${lib_name}" -a -n "${lib_keyfile}" -a -n "${lib_md5}" -a -n "${lib_url}" ]; then
                lib_file="${DOWNLOAD_DIR}/${lib_name}.tar.gz"

                local lib_path=`find /lib/ /usr/lib/ -name ${lib_keyfile}`
                if [ -z "${lib_path}" ]; then
                    download ${lib_url} ${lib_file} ${lib_md5}
                    ret=$?
                    if [ ${ret} -ne 0 ]; then
                        return ${ret}
                    fi

                    if [ "${lib_name}" == "libssl" ]; then
                        download_related_lib=1
                    fi
                else
                    if [ "${lib_name}" == "libevent_openssl" ]; then
                        libevent_openssl_md5="${lib_md5}"
                        libevent_openssl_url="${lib_url}"
                        libevent_openssl_file="${lib_file}"
                    fi
                fi

                lib_name=""
                lib_keyfile=""
                lib_md5=""
                lib_url=""
                lib_file=""
            fi
        elif [ "${state}" == "kos" ]; then
            if [ "${line%%:*}" == '"kernel"' ]; then
                kernel=`echo ${line#*:} | tr -d '"'`
            elif [ "${line%%:*}" == '"checksum"' ]; then
                kernel_md5=`echo ${line#*:} | tr -d '"'`
            elif [ "${line%%:*}" == '"url"' ]; then
                kernel_url=`echo ${line#*:} | tr -d '"'`
            fi

            if [ -n "${kernel}" -a -n "${kernel_md5}" -a -n "${kernel_url}" ]; then
                if [ "${kernel_release}" == "${kernel}" ]; then
                    download ${kernel_url} ${KO_TAR} ${kernel_md5}
                    ret=$?
                    if [ ${ret} -ne 0 ]; then
                        return ${ret}
                    fi
                fi

                kernel=""
                kernel_md5=""
                kernel_url=""
            fi
        fi
    done < ${INSTALL_JSON}

    # 因为libevent_openssl依赖于libssl编译出来的，为了版本匹配，必须配套使用。所以如果需要下载libssl，则也需要下载libevent_openssl。
    if [ ${download_related_lib} -eq 1 ]; then
        if [ -n "${libevent_openssl_md5}" -a -n "${libevent_openssl_url}" -a -n "${libevent_openssl_file}" ]; then
            download ${libevent_openssl_url} ${libevent_openssl_file} ${libevent_openssl_md5}
            ret=$?
            if [ ${ret} -ne 0 ]; then
                return ${ret}
            fi
        fi
    fi

    log "Download plugin success."

    return 0
}

install_plugin()
{
   echo "解压缩插件包到INSTALL目录，从中拷贝version、xunyou_daemon.sh、xunyou_firewall.sh、xunyou_uninstall.sh和xunyou.conf文件到$DOWNLOAD目录"
   echo  "tar -C ${INSTALL_DIR} -xzf ${CORE_TAR}"
    tar -C ${INSTALL_DIR} -xzf ${CORE_TAR}

    cp -af ${INSTALL_DIR}/xunyou/conf/xunyou.conf ${DOWNLOAD_DIR} > /dev/null 2>&1
    cp -af ${INSTALL_DIR}/xunyou/version ${DOWNLOAD_DIR}
    cp -af ${INSTALL_DIR}/xunyou/scripts/xunyou_daemon.sh ${DOWNLOAD_DIR}
    cp -af ${INSTALL_DIR}/xunyou/scripts/xunyou_firewall.sh ${DOWNLOAD_DIR}/firewall.sh
    cp -af ${INSTALL_DIR}/xunyou/scripts/xunyou_uninstall.sh ${DOWNLOAD_DIR}
    
    if [ "${ACTION3}" == "-i" ]; then
        LAN_IF_NAME=${ACTION4}
        {
            echo "lan_if_name=${LAN_IF_NAME}";
        } > "${DOWNLOAD_DIR}/lan.config"
    else
        echo "" > "${DOWNLOAD_DIR}/lan.config"
    fi

    #为兼容老版本，拷贝xunyou_daemon.sh到xunyou_config.sh
    mkdir -p ${DOWNLOAD_DIR}/scripts
    cp -af ${DOWNLOAD_DIR}/xunyou_daemon.sh ${DOWNLOAD_DIR}/scripts/xunyou_config.sh

    #如果BACKUP目录有缓存文件，则拷贝到DOWNLOAD目录
    if [ -d ${BACKUP_DIR}/.cache ]; then
        cp -arf ${BACKUP_DIR}/.cache ${DOWNLOAD_DIR}
    fi

    echo '#检查插件目录所在分区是否有足够的空间'
	echo "${DOWNLOAD_DIR}"
    local require=`du -sk ${DOWNLOAD_DIR} | awk -F" " '{print $1}'`
	echo "require---${require}"
    if [ "$SYSTEM_TYPE" == "oray" ]; then
        local available=`df -m | awk -F" " '$6=="'${PLUGIN_MOUNT_DIR}'" {print $4}' | sed -n 1p | tr -d M`
        available=$(awk 'BEGIN{print '${available}'*1000 }')
		echo $available
    else
		PLUGIN_DIR="/tmp/data/xunyou"
		PLUGIN_MOUNT_DIR="/tmp"
        local available=`df -k | awk -F" " '$6=="'${PLUGIN_MOUNT_DIR}'" {print $4}' | sed -n 1p`
		echo $available
    fi   
    
    let "require = ${require} + 2"
	echo '#${require}预留2k的空间保存daemon日志${available}'
	
    if [ ${require} -ge ${available} ]; then
        log "There is not enough space to install plugin!"
        return 7
    fi

   echo  "将$DOWNLOAD_DIR移动到$PLUGIN_DIR"
    cp -arf ${DOWNLOAD_DIR} ${PLUGIN_DIR}
    if [ $? -ne 0 ]; then
        log "Failed to install plugin to ${PLUGIN_DIR}!"
        return 8
    fi
	rm ${DOWNLOAD_DIR} -rf
    log "Install plugin success."

    return 0
}

start_plugin()
{
echo 'start_plugin'
echo "用sed修正安装目录"
sed -i 's|PLUGIN_DIR="/xunyou"|PLUGIN_DIR="/tmp/data/xunyou"|' /tmp/data/xunyou/xunyou_daemon.sh


    sh ${PLUGIN_DIR}/xunyou_daemon.sh simple >> ${INSTALL_LOG}
    if [ $? -ne 0 ]; then
        log "Failed to start plugin."
        return 9
    fi
rm /tmp/.xunyou_install -rf
    sleep 1
    sh ${PLUGIN_DIR}/xunyou_daemon.sh status >> ${INSTALL_LOG}
    if [ $? -ne 0 ]; then
        log "Plugin running status is not ok."
        return 10
    fi
	rm $PLUGIN_DIR/xunyou.tar.gz
    return 0
}



CURL_CMD=`type -p curl`
if [ "${INSTALL_ROUTER}" != "upgrade" ] && [ -n "${INSTALL_ROUTER}" ]; then
    install_init_with_param
    [ "$?" != "0" ] && exit 1
else
    install_init
    ret=$?
    if [ ${ret} -ne 0 ];then
        post_es_log install fail ${ret}
        
        exit ${ret}
    fi
fi

download_install_json
ret=$?
if [ ${ret} -ne 0 ];then
    post_es_log install fail ${ret}
    
    exit ${ret}
fi

download_plugin
ret=$?
if [ ${ret} -ne  0 ];then
    post_es_log install fail ${ret}
    
    exit ${ret}
fi


echo '#执行安装操作'
install_plugin
ret=$?
if [ ${ret} -ne 0 ];then
    post_es_log install fail ${ret}
    post_es_log restore_backup success
    exit ${ret}
fi

echo '#执行安装操作的返回。正确'
post_es_log install success
echo '#启动插件'
start_plugin
ret=$?
if [ ${ret} -ne 0 ]; then
    post_es_log install_start fail ${ret}
    post_es_log restore_backup success
    post_es_log backup_start success

    exit ${ret}
fi

exit

post_es_log install_start success

log "Install and start plugin success!"



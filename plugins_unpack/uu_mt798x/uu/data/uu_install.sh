#!/bin/sh

touch /tmp/install.log
chmod a+rw /tmp/install.log
exec 2>/tmp/install.log || true
set -x

# Online URL
URL_PREFIX="https://"
UNINSTALL_DOWNLOAD_URL="router.uu.163.com/api/script/uninstall?type="
MONITOR_DOWNLOAD_URL="router.uu.163.com/api/script/monitor?type="

ROUTER="${1:-asuswrt-merlin}"
MODEL="${2}"

BASEDIR=$(dirname "$0")
UNINSTALL_FILE="${BASEDIR}/uninstall.sh"
INSTALL_DIR=""
MONITOR_FILE=""
MONITOR_CONFIG=""

ASUSWRT_MERLIN="asuswrt-merlin"
XIAOMI="xiaomi"
HIWIFI="hiwifi"
OPENWRT="openwrt"
STEAM_DECK_PLUGIN="steam-deck-plugin"

init_param() {
    local router="${ROUTER}"
    local monitor_filename="uuplugin_monitor.sh"

    case "${router}" in
    ${OPENWRT})
        URL_PREFIX="http://"
        INSTALL_DIR="/usr/sbin/uu/"
        MONITOR_FILE="${INSTALL_DIR}/${monitor_filename}"
        MONITOR_CONFIG="${INSTALL_DIR}/uuplugin_monitor.config"
        UNINSTALL_DOWNLOAD_URL="${URL_PREFIX}${UNINSTALL_DOWNLOAD_URL}${OPENWRT}"
        MONITOR_DOWNLOAD_URL="${URL_PREFIX}${MONITOR_DOWNLOAD_URL}${OPENWRT}"
        return 0
        ;;
    ${STEAM_DECK_PLUGIN})
        URL_PREFIX="https://"
        INSTALL_DIR="/home/deck/uu/"
        MONITOR_FILE="${INSTALL_DIR}/${monitor_filename}"
        MONITOR_CONFIG="${INSTALL_DIR}/uuplugin_monitor.config"
        UNINSTALL_DOWNLOAD_URL="${URL_PREFIX}${UNINSTALL_DOWNLOAD_URL}${STEAM_DECK_PLUGIN}"
        MONITOR_DOWNLOAD_URL="${URL_PREFIX}${MONITOR_DOWNLOAD_URL}${STEAM_DECK_PLUGIN}"
        return 0
        ;;
    *)
        return 1
        ;;
    esac
}

# Return: 0 means success.
config_asuswrt() {
    # Config jffs file system
    nvram set jffs2_enable=1
    nvram set jffs2_scripts=1
    nvram commit &
    return 0
}

# Return: 0 means success.
check_dir() {
    if [ ! -d "${INSTALL_DIR}" ];then
        mkdir -p "${INSTALL_DIR}"
        [ "$?" != "0" ] && return 1
    fi

    return 0
}

clean_up() {
    [ ! -f "${UNINSTALL_FILE}" ] && return 1

    chmod u+x "${UNINSTALL_FILE}"
    /bin/sh "${UNINSTALL_FILE}" "${ROUTER}" "${MODEL}" 1>/dev/null 2>&1
    [ "$?" != "0" ] && return 1

    return 0
}

# Return: 0 means success.
download() {
    local url="$1"
    local file="$2"
    local plugin_info=$(curl -L -s -k -H "Accept:text/plain" "${url}" || \
        wget -q --no-check-certificate -O - "${url}&output=text" || \
        wget -q -O - "${url}&output=text" || \
        curl -s -k -H "Accept:text/plain" "${url}"
    )

    [ "$?" != "0" ] && return 1
    [ -z "$plugin_info" ] && return 1

    local plugin_url=$(echo "$plugin_info" | cut  -d ',' -f 1)
    local plugin_md5=$(echo "$plugin_info" | cut  -d ',' -f 2)

    [ -z "${plugin_url}" ] && return 1
    [ -z "${plugin_md5}" ] && return 1

    curl -L -s -k "$plugin_url" -o "${file}" >/dev/null 2>&1 || \
        wget -q --no-check-certificate "$plugin_url" -O "${file}" >/dev/null 2>&1 || \
        wget -q "$plugin_url" -O "${file}" >/dev/null 2>&1 || \
        curl -s -k "$plugin_url" -o "${file}" >/dev/null 2>&1

    if [ "$?" != "0" ];then
        [ -f "${file}" ] && rm "${file}"
        return 1
    fi

    if [ -f "${file}" ];then
        local download_md5=$(md5sum "${file}")
        local download_md5=$(echo "$download_md5" | sed 's/[ ][ ]*/ /g' | cut -d' ' -f1)
        if [ "$download_md5" != "$plugin_md5" ];then
            rm "${file}"
            return 1
        fi
        return 0
    else
        return 1
    fi
}

# Return: 0 means success.
start_monitor() {
    [ ! -f  "${MONITOR_FILE}" ] && return 1

    {
        echo "router=${ROUTER}";
        echo "model=${MODEL}"
    } > ${MONITOR_CONFIG}

    [ "$?" != "0" ] && return 1

    chmod u+x "${MONITOR_FILE}"
	mkdir /etc/mnt/uu -p
	if [ -f /etc/mnt/.uuplugin_uuid ];then
		ln -s /etc/mnt/uu/.uuplugin_uuid ${INSTALL_DIR}/.uuplugin_uuid
	 else
		 touch /etc/mnt/uu/.uuplugin_uuid
		 ln -s /etc/mnt/uu/.uuplugin_uuid ${INSTALL_DIR}/.uuplugin_uuid
	fi
    /bin/sh "${MONITOR_FILE}" 1>/dev/null 2>&1 &
	
	rm /usr/sbin/uu/uu.tar.gz -rf
	rm /usr/sbin/uu/uu.tar.gz.md5 -rf
    return 0
}

# Return: 0 means running.
check_running() {
    local PID_FILE="/var/run/uuplugin.pid"
    local PLUGIN_EXE="uuplugin"
    local TIMES="1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25"
    TIMES=${TIMES}" 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45"
    TIMES=${TIMES}" 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65"
    TIMES=${TIMES}" 66 67 68 69 70 71 72 73 74 75 76 77 78 79 80 81 82 83 84 85"
    TIMES=${TIMES}" 86 87 88 89 90"
    for i in ${TIMES};do
        if [ -f "$PID_FILE" ];then
            local pid=$(cat $PID_FILE)
            local running_pid=$(ps | sed 's/^[ \t]*//g;s/[ \t]*$//g' | \
                sed 's/[ ][ ]*/#/g' | grep "${PLUGIN_EXE}" | \
                grep -v "grep" | cut -d'#' -f1 | grep -e "^${pid}$")

            if [ "${running_pid}" = "" ];then
                running_pid=$(ps -ax -o pid,cmd | sed 's/^[ \t]*//g;s/[ \t]*$//g' | \
                    sed 's/[ ][ ]*/#/g' | grep "${PLUGIN_EXE}" | \
                    grep -v "grep" | cut -d'#' -f1 | grep -e "^${pid}$")
            fi

            if [ "$pid" = "${running_pid}" ];then
                return 0
            else
                sleep 1
            fi
        else
            sleep 1
        fi
    done

    return 1
}

# Return: 0 means it is merlin.
check_merlin() {
    # Check to see if it is merlin
    local br0=$(ip -4 a s br0 | grep inet | grep -v 'grep' | \
        sed 's/^[ \t]*//g;s/[ \t]*$//g' | sed 's/[ ][ ]*/#/g' | cut -d'#' -f2 | cut -d/ -f1)
    [ -z "${br0}" ] && return 1

    local code=$(curl -s -o /dev/null -w "%{http_code}" "http://${br0}/images/merlin-logo.png")
    [ "$code" = "200" ] && return 0

    code=$(wget -Sq -O - "http://${br0}/images/merlin-logo.png" 2>&1 | grep 'HTTP' | \
        sed 's/^[ \t]*//g;s/[ \t]*$//g' | sed 's/[ ][ ]*/#/g' | cut -d'#' -f2)
    [ "$code" = "200" ] && return 0
    return 1
}



# Return: 0 means success.
config_bootup() {
 return 0
}

# Return: 0 means success.
config_router() {
    local router="${ROUTER}"
    case "${router}" in
    ${ASUSWRT_MERLIN})
        config_asuswrt
        return $?
        ;;
    ${XIAOMI} | ${HIWIFI} | ${OPENWRT})
        return 0
        ;;
    ${STEAM_DECK_PLUGIN})
        return 0
        ;;
    *)
        return 1
        ;;
    esac
}

print_sn() {
    local interface=""
    case "${ROUTER}" in
        ${ASUSWRT_MERLIN})
            interface="br0"
            ;;
        ${XIAOMI} | ${HIWIFI} | ${OPENWRT})
            interface="lan1"
            ;;
        *)
            return 1
            ;;
    esac

    local info=$(ip addr show ${interface})
    local mac=$(echo "${info}" | grep "link/ether" | awk '{print $2}')
    echo "sn=${mac}"
    return 0
}

install() {

    init_param
    [ "$?" != "0" ] && return 9

    config_router
    [ "$?" != "0" ] && return 1

    check_dir
    [ "$?" != "0" ] && return 2 

    download "${UNINSTALL_DOWNLOAD_URL}" "${UNINSTALL_FILE}"
    [ "$?" != "0" ] && return 3

    clean_up
    [ "$?" != "0" ] && return 4

    download "${MONITOR_DOWNLOAD_URL}" "${MONITOR_FILE}"
    if [ "$?" != "0" ];then
        [ -f "${MONITOR_FILE}" ] && rm "${MONITOR_FILE}"
        return 5
    fi
    chmod a+x ${MONITOR_FILE}

    if [ "${ROUTER}" = "${STEAM_DECK_PLUGIN}" ];then
        {
            echo "router=${ROUTER}";
            echo "model=x86_64"
        } > ${MONITOR_CONFIG}
        config_bootup
        check_running
        [ "$?" != "0" ] && return 6
        return 0
    fi

    start_monitor
    [ "$?" != "0" ] && return 6

    check_running
    [ "$?" != "0" ] && return 7

    config_bootup
    [ "$?" != "0" ] && return 8

    print_sn
    [ "$?" != "0" ] && return 10
    return 0
}

# Start to install.
install
status_code=$?

if [ ${status_code} -gt 4 ];then
    if [ -f "${UNINSTALL_FILE}" ];then
       echo "安装失败"
    fi
fi

[ -f "${UNINSTALL_FILE}" ] && rm "${UNINSTALL_FILE}"
return $status_code

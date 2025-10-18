#!/usr/bin/env bash

gwid="ffffffffffffffffffffffffffffffff"
mac=$(cat /sys/class/net/eth0/address | tr -d '\n')
arch=
sysbit=
version=
verstring=
firmware="IK-ROUTEROS"
enterprise=
oemname=

runtime=$(awk -F "[.| ]" '{print $1}' /proc/uptime)
runtime=${runtime:-0}

get_base_data_v2() {
    if [ -f "/etc/setup/version" ]; then
        . /etc/setup/version
    fi
    if [ -f "/etc/mnt/uid" ]; then
        local uid=$(cat /etc/mnt/uid)
        if [ ${#uid} -gt 0 ]; then
            gwid=${uid}
        fi
    fi
    arch=$(uname -m | tr -d '\n')
    if [ ${arch} == "mips" ]; then
        sysbit="x32"
    elif [ ${arch} == "x86_64" ]; then
        arch="x86"
        sysbit="x64"
    else
        arch="x86"
        sysbit="x32"
    fi
    verstring=${ver}
    if [[ "$verstring" =~ ([0-9]+\.[0-9]\.[0-9]+)" ".*Build([0-9]{8}) ]]; then
        version="${BASH_REMATCH[1]}"
    fi
    if [ -f "/etc/firmwarename" ]; then
        firmware=$(cat /etc/firmwarename)
    fi
    if [ -f "/etc/enterprise" ]; then
        enterprise="Enterprise"
    fi
    if [ -f "/etc/oem" ];then
        oemname=$(cat /etc/oem)
    fi
}

get_base_data_v3() {
    . /etc/release

    gwid=${GWID}
    arch=${ARCH}
    sysbit=${SYSBIT}
    version=${VERSION}
    verstring=${VERSTRING}
    firmware=${FIRMWARENAME}
    enterprise=${ENTERPRISE}
    oemname=${OEMNAME}
}

get_base_data() {
    if [ -f "/etc/release" ]; then
        get_base_data_v3
    else
        get_base_data_v2
    fi
    echo '{}' | jq '{"gwid":$gwid,"mac":$mac,"arch":$arch,"sysbit":$sysbit,"version":$version,"verstring":$verstring,"firmware":$firmware,"enterprise":$enterprise,"oemname":$oemname,"runtime":$runtime}' \
                --arg gwid "${gwid}" \
                --arg mac "${mac}" \
                --arg arch "${arch}" \
                --arg sysbit "${sysbit}" \
                --arg version "${version}" \
                --arg verstring "${verstring}" \
                --arg firmware "${firmware}" \
                --arg enterprise "${enterprise}" \
                --arg oemname "${oemname}" \
                --arg runtime "${runtime}"
}

get_base_data

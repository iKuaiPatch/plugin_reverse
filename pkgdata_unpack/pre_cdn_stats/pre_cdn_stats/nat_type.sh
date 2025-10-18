#!/bin/bash
nat_type_path="/etc/log/.pre_cdn_nat"
cur_date_path=${nat_type_path}/$(date +"%Y%m%d")_nat


if [ -d "$cur_date_path" ];then
	exit 0
fi
rm -rf ${nat_type_path}/*_nat 2>/dev/null
mkdir -p ${cur_date_path} 2>/dev/null

iface_list=`route -n | awk -va=0.0.0.0 '$1==a&&$3==a&&!s[$NF]&&$NF!~/^pptp|^l2tp|ovpn|^ppp/ {s[$NF]=1;print $NF}'`

for iface in $iface_list; do
	/tmp/ikpkg/pre_cdn_stats/ik_stun_client -i $iface -t > ${cur_date_path}/${iface} &
done
sleep 20

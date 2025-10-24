#!/bin/bash
export PATH='/usr/bin:/bin:/usr/sbin:/sbin'
declare -A ___INCLUDE_ALREADY_LOAD_FILE___
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

. /etc/release
ETHER_INFO_FILE=$IK_DIR_CACHE/ether_info


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
Include json.sh,sqlite.sh,check_varl.sh
Include interface.sh iproute.sh lock.sh


LAN_DHCPDV6_CONF="/tmp/iktmp/odhcpd/ik_dhcpd.conf"
DHCPV6_STATEFILE="/tmp/iktmp/odhcpd/odhcpd.leases"
DHCPV6_LEASEFILE="/var/db/v6_leases.db"

LOCKUP="Lock ipv6"
UNLOCK="unLock ipv6"

PKG_PATH="/etc/mnt/.ipv6_multi"

payload="/etc/mnt/ikuai/payload.json"
signature="/etc/mnt/ikuai/signature.bin"
response="/etc/mnt/ikuai/response.json"


if ! /tmp/ikpkg/appinst/genuine activate >/dev/null 2>/dev/null;then
	num=1
	echo "expires=0 num=$num enterprise=1" > ${PKG_PATH}
	sed -i '/#INS001/d'  /usr/ikuai/script/utils/collection.sh
	sed -i 's/#check_ipv6_multi_expires /check_ipv6_multi_expires/' /usr/ikuai/script/utils/collection.sh
else
	
	num=$(jq -r '.ipv6' $payload)
	PKG_PATH="/tmp/.ipv6_multi"
	echo "expires=0 num=$num enterprise=1" > ${PKG_PATH}
	
	if [ ! -f /tmp/iktmp/collection.bak ];then
		echo 1 > /tmp/iktmp/collection.bak
sed -i '/ipv6_multi"/i return #INS001' /usr/ikuai/script/utils/collection.sh
sed -i 's/check_ipv6_multi_expires /#check_ipv6_multi_expires/' /usr/ikuai/script/utils/collection.sh
	fi
fi



boot()
{


	echo "expires=0 num=$num enterprise=1" > ${PKG_PATH}
		

	mkdir -p /tmp/iktmp/odhcpd
	__wan_config_to_cache
	__create_lan_config_to_cache

	ipset -N ipv6_local_host hash:net family inet6
	ipset -F ipv6_local_host
	sqlite3 $DHCPV6_LEASEFILE < /etc/defaults/dhcpv6_leases.conf
	__load_old_prefix
	init
}

init()
{
	sql_config_get_list $IK_DB_CONFIG "select * from ipv6_wan_config where enabled='yes' and (internet='dhcp' or internet='relay')" |
	while read config; do
		[ "$config" ] ||continue
		local $config
		__ipset_v6_create ipv6_prefix_$interface
	done
	__init_odhcpd_config
	start
}

updatedb()
{
	if [ "$OEMNAME" = "zh" ]; then
		if [ "$old_sysver" -lt 300070012 ];then
			sqlite3 $IK_DB_CONFIG "update ipv6_lan_config set enabled='no'"
		fi
	fi
}

__load_old_prefix()
{
	sqlite3 $IK_DB_COLLECTION ".dump prefix_stat" | sqlite3 $DHCPV6_LEASEFILE	
}

__lan_config_init()
{
	for conf_file in $(ls $IK_DIR_CACHE/config/ipv6_lan_config.*); do
		local $(cat $conf_file)
		[ "$enabled" = "yes" ] || continue
		if [ "$internet" = "static" ]; then
			ip -6 addr flush dev $interface scope global
			if [ -n "$ipv6_addr" ]; then
				ip -6 addr add $ipv6_addr  dev $interface
			else
				__lan_localaddr_init $interface				
			fi
		fi
	done
}

vrrp_init()
{
	stop
	sqlite3 $IK_DB_CONFIG "delete from ipv6_wan_config; delete from ipv6_lan_config"
	sqlite3 $IK_DIR_LOG/vrrp/conf/config.db ".dump ipv6_wan_config" |grep "^INSERT"| sqlite3 $IK_DB_CONFIG
	sqlite3 $IK_DIR_LOG/vrrp/conf/config.db ".dump ipv6_lan_config" |grep "^INSERT"| sqlite3 $IK_DB_CONFIG
	__wan_config_to_cache
	__create_lan_config_to_cache
	init
}

__wan_config_to_cache()
{
	sql_config_get_list $IK_DB_CONFIG "select * from ipv6_wan_config"| \
	while read config; do
		[ "$config" ] || continue
		local $config
		echo "$config" >$IK_DIR_CACHE/config/ipv6_wan_config.${interface}.tmp
		mv $IK_DIR_CACHE/config/ipv6_wan_config.${interface}.tmp $IK_DIR_CACHE/config/ipv6_wan_config.$interface
	done
}

__create_lan_config_to_cache()
{
	local id=$1
	sql_config_get_list $IK_DB_CONFIG "select * from ipv6_lan_config ${id:+ where id=$id}" | \
	while read config; do
		local $config	
		echo "$config" >$IK_DIR_CACHE/config/ipv6_lan_config.${interface}.tmp
		mv $IK_DIR_CACHE/config/ipv6_lan_config.${interface}.tmp $IK_DIR_CACHE/config/ipv6_lan_config.$interface
	done
}

__delete_lan_config_to_cache()
{
	local interface=$1
	rm -f $IK_DIR_CACHE/config/ipv6_lan_config.$interface
}

__sysctl_ipv6_enable()
{
	local disable_ipv6=$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6)
	if [ "$disable_ipv6" != "0" ];then
		sysctl -w -q net.ipv6.conf.all.disable_ipv6=0
		sysctl -w -q net.ipv6.conf.default.forwarding=1
		sysctl -w -q net.ipv6.conf.all.forwarding=1
	fi
}


__sysctl_ipv6_disable()
{
	sysctl -w -q net.ipv6.conf.all.disable_ipv6=1
	sysctl -w -q net.ipv6.conf.default.forwarding=0
	sysctl -w -q net.ipv6.conf.all.forwarding=0
}

__ipset_v6_create()
{
	local setname="$1"
	local mark=$(iproute_get_markid $interface)
	ipset -N $setname hash:net family inet6 2>/dev/null
	ipset -F $setname 2>/dev/null	
	
	ip6tables -t mangle -A STREAM_IPV6_NEW -m set --match-set $setname src -m set ! --match-set ipv6_local_host dst -j CONNMARK --set-mark $mark >/dev/null 2>&1
}

__ipset_v6_destory()
{
	local setname="$1"
	local mark=$(iproute_get_markid $interface)
	ip6tables -t mangle -D STREAM_IPV6_NEW -m set --match-set $setname src -m set ! --match-set ipv6_local_host dst -j CONNMARK --set-mark $mark >/dev/null 2>&1

	if [ -e "/tmp/iktmp/dhcp6c/$interface" ]; then
		local $(cat /tmp/iktmp/dhcp6c/$interface)
		if [ "$dhcp6_prefix1" ]; then
			ipset del ipv6_local_host ${dhcp6_prefix1//,*}
		fi
	fi

	ipset -F $setname >/dev/null 2>&1
	ipset -X $setname >/dev/null 2>&1
}


#dhcp6_prefix1 count
__dhcp6_addr_auto_get()
{
	local auto_addr
	local addrlist=(${1//:/ })
	local addr0=${addrlist[0]}
	local addr1=${addrlist[1]}
	local addr2=${addrlist[2]}
	local addr3=${addrlist[3]}
	local mask=${addrlist[4]//\/}

	local count="$2"

	if [ -z "$count" ]; then
		local id=$(sqlite3 $IK_DB_CONFIG "select count(*) from ipv6_lan_config where parent like '%$parent%' and id<$id")
		local id=$((id+1))
	else
		local id=$(sqlite3 $IK_DB_CONFIG "select count(*) from ipv6_lan_config where  parent like '%$parent%'")
		local id=$((count+id+1))
	fi

	if [ -z "$mask" -o -z "$id" ]; then
		return
	fi
	if [ "$mask" -gt "64" ]; then
		return
	fi

	if [ "$mask" = "56" ]; then
		local tmp_addr="${addr3:0:-2}"
	elif [ "$mask" = "60" ]; then
		local tmp_addr="${addr3:0:-1}"
	elif [ "$mask" = "61" ]; then
		local tmp_addr="$((0x$addr3&0xfff8))"
	elif [ "$mask" = "62" ]; then
		local tmp_addr="${addr3:0:-1}"
		local tmp_len="${#addr3}"
		local tmp_len=$((tmp_len-1))
		local tmp_index="${addr3:$tmp_len:1}"
		local tmp_index=$(printf %d 0x$tmp_index)
	elif [ "$mask" = "63" ]; then
		local tmp_addr="$((0x$addr3&0xfffe))"
	elif [ "$mask" -lt "60" ]; then
		local tmp_addr="${addr3:0:-1}"
		mask=60
	else
		if [ "$mask" ]; then
			mask=64
		fi
	fi

	if [ "$mask" = "56" ]; then
		if [ "$prefix_len" = "60" ]; then
			if [ "$id" -gt "15" ]; then
				return
			fi
			local index=$(printf %x $id)	
			local dstmask=60
			addr3="${tmp_addr}${index}0"
			auto_addr="${addr0}:${addr1}:${addr2}:${addr3}::1001/$dstmask"
		elif [ "$prefix_len" = "62" ]; then
			if [ "$id" -gt "63" ]; then
				return
			fi
			local index=$(printf %x $id)	
			local dstmask=62
			addr3="${tmp_addr}${index}8"
			auto_addr="${addr0}:${addr1}:${addr2}:${addr3}::1001/$dstmask"
		else
			if [ "$id" -gt "255" ]; then
				return
			fi
			local index=$(printf %02x $id)	
			local dstmask=64
			addr3="${tmp_addr}${index}"
			auto_addr="${addr0}:${addr1}:${addr2}:${addr3}::1001/$dstmask"
		fi
	elif [ "$mask" = "60" ]; then
		if [ "$prefix_len" = "64" -o "$prefix_len" = "auto" -o -z "$prefix_len" ]; then
			if [ "$id" -gt "15" ]; then
				return
			fi
			local index=$(printf %x $id)	
			local dstmask=64
			addr3="${tmp_addr}${index}"
			auto_addr="${addr0}:${addr1}:${addr2}:${addr3}::1001/$dstmask"
		elif [ "$prefix_len" = "60" ]; then
			if [ "$id" -gt "1" ]; then
				return
			fi
			local dstmask=60
			auto_addr="${addr0}:${addr1}:${addr2}:${addr3}::1001/$dstmask"
		else
			if [ "$id" -gt "4" ]; then
				return 
			fi
			local index=$(printf %x $((4*id-4)))
			local dstmask=62
			addr3="${tmp_addr}$index"
			auto_addr="${addr0}:${addr1}:${addr2}:${addr3}::1001/$dstmask"
		fi
	elif [ "$mask" = "61" ]; then
		if [ "$prefix_len" = "62" ]; then
			if [ "$id" -gt "2" ]; then
				return
			fi
			local dstmask=62
			local index=$((4*id-4))
			local tmp_addr3="$((tmp_addr+index))"
			local addr3=$(printf %x $tmp_addr3)
			auto_addr="${addr0}:${addr1}:${addr2}:${addr3}::1001/$dstmask"
		else
			if [ "$id" -gt "8" ]; then
				return 
			fi
			local dstmask=64
			local tmp_addr3="$((tmp_addr+id-1))"
			local addr3=$(printf %x $tmp_addr3)
			auto_addr="${addr0}:${addr1}:${addr2}:${addr3}::1001/$dstmask"
		fi
	elif [ "$mask" = "62" ]; then
		if [ "$prefix_len" = "62" ]; then
			if [ "$id" -gt "1" ]; then
				return
			fi
			local dstmask=62
			auto_addr="${addr0}:${addr1}:${addr2}:${addr3}::1001/$dstmask"
		else
			if [ "$id" -gt "4" ]; then
				return 
			fi
			local index=$((tmp_index+id-1))
			local index=$(printf %x $index)
			local dstmask=64
			addr3="${tmp_addr}$index"
			auto_addr="${addr0}:${addr1}:${addr2}:${addr3}::1001/$dstmask"
		fi

	elif [ "$mask" = "63" ]; then
		if [ "$prefix_len" = "63" ]; then
			if [ "$id" -gt "1" ]; then
				return
			fi
			local dstmask=63
			auto_addr="${addr0}:${addr1}:${addr2}:${addr3}::1001/$dstmask"
		else
			if [ "$id" -gt "2" ]; then
				return 
			fi
			local dstmask=64
			local tmp_addr3="$((tmp_addr+id-1))"
			local addr3=$(printf %x $tmp_addr3)
			auto_addr="${addr0}:${addr1}:${addr2}:${addr3}::1001/$dstmask"
		fi

	elif [ "$mask" = "64" ]; then
		if [ "$prefix_len" = "64" -o "$prefix_len" = "auto" ]; then
			if [ "$id" -gt "1" ]; then
				return
			fi
			local dstmask=64
			auto_addr="${addr0}:${addr1}:${addr2}:${addr3}::1001/$dstmask"
		else
			if [ "$id" -gt "15" ]; then
				return
			fi
			local index=$(printf %x $id)	
			local dstmask=68
			local tmp_addr="$index${GWID:8:3}"
			auto_addr="${addr0}:${addr1}:${addr2}:${addr3}:$tmp_addr::1001/$dstmask"
		fi
	fi

	echo $auto_addr
}

route_loop_drop_init()
{
	ip6tables -F ROUTE_LOOP
	for conf_file in $(ls /tmp/iktmp/dhcp6c/*); do
		local $(cat $conf_file)
		local iface="${conf_file##*/}"
		if [ "$dhcp6_ip_addr" ]; then
			ip6tables -A ROUTE_LOOP -d $dhcp6_ip_addr -m ifaces --ifaces $iface --dir out  -m ifaces --ifaces $iface --dir in  -j DROP
		fi

		if [ "$dhcp6_prefix1" ]; then
			ip6tables -A ROUTE_LOOP -d ${dhcp6_prefix1//,*} -m ifaces --ifaces $iface --dir out  -m ifaces --ifaces $iface --dir in  -j DROP
		fi
	done
}


__parent_dhcpv6_values_get()
{
	local iface="$1"

	local dhcp6_internet=""
	if [ "$iface" ]; then
		if [ -e "$IK_DIR_CACHE/config/ipv6_wan_config.$iface" ]; then
			local $(cat $IK_DIR_CACHE/config/ipv6_wan_config.$iface)
		else
			return 0
		fi
		if [ "$enabled" != "yes" ]; then
			return 0
		fi

		if [ ! -e "/tmp/iktmp/dhcp6c/$iface" ]; then
			return 0
		fi
		local $(cat /tmp/iktmp/dhcp6c/$iface)
	else
		local exist_dhcp6c=0
		for conf_file in $(ls /tmp/iktmp/dhcp6c/*); do
			local $(cat $conf_file)
			exist_dhcp6c=1
			break
		done
		[ "$exist_dhcp6c" = "0" ] && return 0
	fi
	local dhcp6_prefix_info=(${dhcp6_prefix1//,/ })
	local dhcp6_prefix1=${dhcp6_prefix_info[0]}
	local lan_preferred_lft=${dhcp6_prefix_info[1]}
	local lan_valid_lft=${dhcp6_prefix_info[2]}

	echo "dhcp6_gateway=$dhcp6_gateway dhcp6_prefix1=$dhcp6_prefix1 lan_preferred_lft=$lan_preferred_lft lan_valid_lft=$lan_valid_lft dhcp6_dns1=$dhcp6_dns1 dhcp6_dns2=$dhcp6_dns2 dhcp6_ra_mtu=$dhcp6_ra_mtu dhcp6_internet=$dhcp6_internet"
}


__parent_dhcpv6_mtu_get()
{
	local ifaces="$1"

	local min_mtu=""
	if [ "$ifaces" ]; then
		for iface in ${ifaces//,/ }; do
			local dhcp6_ra_mtu=""
			if [ ! -e "$IK_DIR_CACHE/config/ipv6_wan_config.$iface" ]; then
				continue
			fi
			local $(cat $IK_DIR_CACHE/config/ipv6_wan_config.$iface)
			if [ "$enabled" != "yes" ]; then
				continue
			fi

			if [ ! -e "/tmp/iktmp/dhcp6c/$iface" ]; then
				continue
			fi
			local $(cat /tmp/iktmp/dhcp6c/$iface)

			[ -z "$dhcp6_ra_mtu" ] && continue

			if [ -z "$min_mtu" ]; then
				min_mtu=$dhcp6_ra_mtu
			else
				if [ "$dhcp6_ra_mtu" -lt "$min_mtu" ]; then
					min_mtu=$dhcp6_ra_mtu
				fi
			fi
		done
	fi

	if [ -z "$min_mtu" ]; then
		local dhcp6_ra_mtu=1440
	else
		local dhcp6_ra_mtu=$min_mtu
	fi

	echo "$dhcp6_ra_mtu"
}

__lan_odhcpdv6_restart()
{
	local del_parent="$1"
	local action=$action iface_ids=$iface_ids

	for conf_file in $(ls $IK_DIR_CACHE/config/ipv6_lan_config.*); do
		local $(cat $conf_file)

		[ "$enabled" = "yes" ] || continue

		if [ "$iface_ids" ]; then
			local hit=0
			for iface_id in ${iface_ids//,/ }; do
				if [ "$iface_id" -a "$iface_id" = "$id" ]; then
					hit=1
				fi
			done
			[ "$hit" = "1" ] || continue
		fi

		if [ -z "$parent" ]; then
			local parent=$(sqlite3 $IK_DB_CONFIG "select interface from ipv6_wan_config limit 1")
			local parent="${parent:-wan1}"
		fi

		for parent_one in ${parent//,/ }; do
			if [ "$del_parent" -a "$del_parent" != "$parent_one" ]; then
				continue
			fi
			local res=$(__parent_dhcpv6_values_get $parent_one)
			if [ "$res" ]; then
				local $res
			else
				local dhcp6_gateway=""
				local dhcp6_prefix1=""
				local lan_preferred_lft=""
				local lan_valid_lft=""
				local dhcp6_dns1=""
				local dhcp6_dns2=""
				local dhcp6_ra_mtu=""
				local dhcp6_internet=""
			fi

			if [ "$internet" != "static" ]; then
				if [ "$dhcp6_internet" -a "$dhcp6_internet" != "$internet" ]; then
					continue
				fi
			fi

			if [ "$internet" = "dhcp" ]; then
				if [ "$dhcp6_prefix1" ]; then
					local ipv6_addr=$(__dhcp6_addr_auto_get "$dhcp6_prefix1")
				else
					local ipv6_addr=""	
				fi

				if [ -n "$ipv6_addr" ]; then
					ip -6 addr $action $ipv6_addr  dev $interface preferred_lft $lan_preferred_lft valid_lft $lan_valid_lft
				fi
				if [ "$action" = "del" ]; then
					ip -6 route del $ipv6_addr dev $interface
					__update_prefix_config "$interface" "$ipv6_addr"
				fi

				if [ "${interface:0:3}" = "doc" ]; then
					if [ "$action" = "replace" ]; then
						docker_network_v6_add $interface $ipv6_addr 
					else
						docker_network_v6_del $interface 
					fi
				fi 
			elif [ "$internet" = "relay" ]; then
				local prefix_len="64"
				if [ "$dhcp6_prefix1" ]; then
					local ipv6_addr=$(__dhcp6_addr_auto_get "$dhcp6_prefix1")
				else
					local ipv6_addr=""	
				fi
				if [ -n "$ipv6_addr" ]; then
					ip -6 route replace $ipv6_addr dev $interface expires $lan_valid_lft metric 100
				fi

				if [ "$action" = "del" ]; then
					ip -6 route del $ipv6_addr dev $interface
					__update_prefix_config "$interface" "$ipv6_addr"
				fi

				if [ "${interface:0:3}" = "doc" ]; then
					if [ "$action" = "replace" ]; then
						docker_network_v6_add $interface $ipv6_addr 
					else
						docker_network_v6_del $interface 
					fi
				fi 
			else
				if [ -n "$ipv6_addr" ]; then
					for ipv6_addr_one in ${ipv6_addr//,/ }; do
						ip -6 addr $action $ipv6_addr_one  dev $interface
					done
					if [ "${interface:0:3}" = "doc" ]; then
						if [ "$action" = "replace" ]; then
							docker_network_v6_add $interface $ipv6_addr_one
						else
							docker_network_v6_del $interface
						fi
					fi
				else
					__lan_localaddr_init $interface				
				fi
			fi
		done
	done
}

__init_odhcpd_config()
{
	__lan_odhcpdv6_stop
	> $LAN_DHCPDV6_CONF

	sql_config_get_list $IK_DB_CONFIG "select * from ipv6_wan_config where enabled='yes'" | \
	while read config; do
		local $config

		if [ "$internet" = "relay" ];then
			if interface_check_is_wanpppoe $interface; then
				interface=${interface}_ad
			fi
			echo "id=$id interface=$interface master=1 ipv6_dns1= ipv6_dns2= leasetime=7200 ra_flags=3 ra_static=0 ra_mtu=1480" >> $LAN_DHCPDV6_CONF
		fi

	done

	for conf_file in $(ls $IK_DIR_CACHE/config/ipv6_lan_config.*); do
		local $(cat $conf_file)
		[ "$enabled" = "yes" ] || continue
		local dhcp6_ra_mtu=$(__parent_dhcpv6_mtu_get $parent)
		local dhcp6_ra_mtu="${dhcp6_ra_mtu:-1440}"


		if [ "$internet" = "relay" ]; then
			if interface_check_is_wanpppoe $parent; then
				parent=${parent}_ad
			fi
			echo "id=$id interface=$interface master=0 parent=$parent ipv6_dns1= ipv6_dns2= leasetime=7200 ra_flags=3 ra_static=0 ra_mtu=$dhcp6_ra_mtu" >> $LAN_DHCPDV6_CONF
		elif [ "$dhcpv6" = "1" ]; then
			if [ "$ra_flags" = "2" ]; then
				ra_static=0
			fi
			echo "id=$id interface=$interface master=0 ipv6_dns1=$ipv6_dns1 ipv6_dns2=$ipv6_dns2 leasetime=$((leasetime*60)) ra_flags=$ra_flags ra_static=$ra_static ra_mtu=$dhcp6_ra_mtu" >> $LAN_DHCPDV6_CONF
		fi
	done
	if [ -e "/tmp/iktmp/odhcpd/.ik_dhcpd_ppp.conf" ]; then
		cat /tmp/iktmp/odhcpd/.ik_dhcpd_ppp.conf >> $LAN_DHCPDV6_CONF
	fi

	local res=$(cat $LAN_DHCPDV6_CONF)
	if [ "$res" ]; then
		odhcpd >/dev/null 2>&1 &
	fi
}

__update_static_config()
{
	local addr_mask="$1" src_iface="$2" dst_iface="$3"
	local ret=0

	local addr=${addr_mask%/*}
	local addr_len=${addr_mask#*/}

	for addr_one in $(interface_get_ipv6addr_mask $src_iface); do
		if [ "$addr_one" = "$addr_mask" ]; then
			ret=1
			break
		fi
	done

	sqlite3 $IK_DB_CONFIG "update ipv6_dhcp_static_config set ipv6_addr='$addr',ipv6_addr_len=$addr_len where src_iface='$src_iface' and dst_iface='$dst_iface'"
	return $ret
}

__update_prefix_config()
{
	local ifname="$1" old_addr6="$2" new_addr6="$3"
	sqlite3 /var/db/v6_leases.db "insert into prefix_stat(interface, new_ipv6_addr, old_ipv6_addr) values('$ifname','${new_addr6//\/*/}','${old_addr6//\/*/}')"
}

__update_iface_prefix_config()
{
	local ifname="$1"
	local filename="/tmp/iface_prefix.$$"

	echo "BEGIN TRANSACTION;" > $filename
	for addr6 in $(interface_get_ipv6addr_mask $ifname); do
		echo "insert into prefix_stat(interface, new_ipv6_addr, old_ipv6_addr) values('$ifname','${addr6//\/*/}','${addr6//\/*/}');" >> $filename
	done
	echo "COMMIT;" >> $filename

	sqlite3 /var/db/v6_leases.db < $filename
	rm $filename
}

__update_relay_prefix_config()
{
	local iface="$1"

	if [ ! -e "/tmp/iktmp/dhcp6c/$iface" ]; then
		return
	fi
	local $(cat /tmp/iktmp/dhcp6c/$iface)
	if [ "$dhcp6_prefix1" ]; then
		__update_prefix_config "$interface" "${dhcp6_prefix1//,*/}"
	fi
}

add_static()
{
	local src_iface="$src_iface" dst_iface="$dst_iface"

	for conf_file in $(ls $IK_DIR_CACHE/config/ipv6_lan_config.*); do
		local $(cat $conf_file)

		[ "$enabled" = "yes" ] || continue

		[ "$interface" = "$src_iface" ] || continue

		if [ -z "$parent" ]; then
			local parent=$(sqlite3 $IK_DB_CONFIG "select interface from ipv6_wan_config limit 1")
		fi

		for parent_one in ${parent//,/ }; do
			if [ "$parent_one" != "$dst_iface" ]; then
				continue
			fi

			local res=$(__parent_dhcpv6_values_get $parent_one)
			[ "$res" ] || continue

			local $res

			if [ "$dhcp6_internet" -a "$dhcp6_internet" != "$internet" ]; then
				continue
			fi

			if [ "$internet" = "dhcp" ]; then
				if [ "$dhcp6_prefix1" ]; then
					local ipv6_addr=$(__dhcp6_addr_auto_get "$dhcp6_prefix1")
				fi
				if [ -n "$ipv6_addr" ]; then
					__update_static_config "$ipv6_addr" "$src_iface" "$dst_iface"
					local is_restart=true	
				fi
			fi
		done
	done
	if [ "$is_restart" = "true" ]; then
		__lan_odhcpdv6_stop		
		odhcpd >/dev/null 2>&1 &
	fi
}

del_static()
{
	__lan_odhcpdv6_stop		
	odhcpd >/dev/null 2>&1 &
}

init_static()
{
	for conf_file in $(ls $IK_DIR_CACHE/config/ipv6_lan_config.*); do
		local $(cat $conf_file)

		[ "$enabled" = "yes" ] || continue
		
		if [ -z "$parent" ]; then
			local parent=$(sqlite3 $IK_DB_CONFIG "select interface from ipv6_wan_config limit 1")
		fi

		for parent_one in ${parent//,/ }; do

			local res=$(__parent_dhcpv6_values_get $parent_one)
			[ "$res" ] || continue

			local $res

			if [ "$dhcp6_internet" -a "$dhcp6_internet" != "$internet" ]; then
				continue
			fi

			if [ "$internet" = "dhcp" ]; then
				if [ "$dhcp6_prefix1" ]; then
					local ipv6_addr=$(__dhcp6_addr_auto_get "$dhcp6_prefix1")
				fi
				if [ -n "$ipv6_addr" ]; then
					__update_static_config "$ipv6_addr" "$interface" "$parent_one"
				fi
			fi
		done
	done
	__lan_odhcpdv6_stop		
	odhcpd >/dev/null 2>&1 &
}

relay_update()
{
	local iface="$1"
	local old_dhcp6_prefix="$2"
	local is_restart=0

	local lan_ids=$(__lanid_get_by_wan $iface)
	for conf_file in $(ls $IK_DIR_CACHE/config/ipv6_lan_config.*); do
		local $(cat $conf_file)

		[ "$enabled" = "yes" ] || continue

		[ "$internet" != "relay" ] && continue

		local hit=0
		for iface_id in ${lan_ids//,/ }; do
			if [ "$iface_id" -a "$iface_id" = "$id" ]; then
				hit=1
			fi
		done
		[ "$hit" = "1" ] || continue

		if [ -z "$parent" ]; then
			local parent=$(sqlite3 $IK_DB_CONFIG "select interface from ipv6_wan_config limit 1")
		fi

		for parent_one in ${parent//,/ }; do
			if [ "$parent_one" != "$iface" ]; then
				continue
			fi

			if [ "$old_dhcp6_prefix" ]; then
				local old_ipv6_addr=$(__dhcp6_addr_auto_get "$old_dhcp6_prefix")
				ip -6 route del $old_ipv6_addr dev $interface
				is_restart=1
				if [ "$old_ipv6_addr" ]; then
					__update_prefix_config "$interface" "$old_ipv6_addr"
				fi
			fi

			local res=$(__parent_dhcpv6_values_get $parent_one)
			[ "$res" ] || continue

			local $res

			local prefix_len="64"
			if [ "$dhcp6_prefix1" ]; then
				local ipv6_addr=$(__dhcp6_addr_auto_get "$dhcp6_prefix1")
			else
				local ipv6_addr=""	
			fi
			if [ -n "$ipv6_addr" ]; then
				ip -6 route replace $ipv6_addr dev $interface expires $lan_valid_lft metric 100
			fi

			if [ "$old_dhcp6_prefix" -a "${interface:0:3}" = "doc" ]; then
				docker_network_v6_add $interface $ipv6_addr
			fi
		done
	done

	if [ "$is_restart" = "1" ]; then
		__init_odhcpd_config >/dev/null 2>&1
	fi

}

###更新lan口的ipv6地址及生存周期
update()
{
	local iface="$1"
	local old_dhcp6_prefix="$2"
	local is_restart=false

	local lan_ids=$(__lanid_get_by_wan $iface)
	for conf_file in $(ls $IK_DIR_CACHE/config/ipv6_lan_config.*); do
		local $(cat $conf_file)

		[ "$enabled" = "yes" ] || continue

		local hit=0
		for iface_id in ${lan_ids//,/ }; do
			if [ "$iface_id" -a "$iface_id" = "$id" ]; then
				hit=1
			fi
		done
		[ "$hit" = "1" ] || continue

		if [ -z "$parent" ]; then
			local parent=$(sqlite3 $IK_DB_CONFIG "select interface from ipv6_wan_config limit 1")
		fi

		for parent_one in ${parent//,/ }; do
			if [ "$parent_one" != "$iface" ]; then
				continue
			fi

			if [ "$old_dhcp6_prefix" ]; then
				local old_ipv6_addr=$(__dhcp6_addr_auto_get "$old_dhcp6_prefix")
				ip -6 addr del $old_ipv6_addr dev $interface 2>/dev/null
				ip -6 route del $old_ipv6_addr dev $interface 2>/dev/null
			fi

			local res=$(__parent_dhcpv6_values_get $parent_one)
			[ "$res" ] || continue

			local $res

			if [ "$dhcp6_internet" -a "$dhcp6_internet" != "$internet" ]; then
				continue
			fi

			if [ "$internet" = "dhcp" ]; then
				if [ "$dhcp6_prefix1" ]; then
					local ipv6_addr=$(__dhcp6_addr_auto_get "$dhcp6_prefix1")
				else
					local ipv6_addr=""	
				fi
				if [ "$old_ipv6_addr" -a "$ipv6_addr" -a "$old_ipv6_addr" != "$ipv6_addr" ]; then
					__update_prefix_config "$interface" "$old_ipv6_addr" "$ipv6_addr"
				fi	

				if [ -n "$ipv6_addr" ]; then
					if __update_static_config "$ipv6_addr" "$interface" "$iface"; then
						is_restart=true	
					fi
					ip -6 addr replace $ipv6_addr  dev $interface preferred_lft $lan_preferred_lft valid_lft $lan_valid_lft

					if [ "$old_dhcp6_prefix" -a "${interface:0:3}" = "doc" ]; then
						is_restart=true	
						docker_network_v6_add $interface $ipv6_addr
					fi
				fi
			fi
		done
	done


	declare -A PPPINFO
	while read config; do
		[ "$config" ] || continue
		local $config
		PPPINFO["$interface"]=$id	
	done < /tmp/iktmp/odhcpd/.ik_dhcpd_ppp.conf

	##重新配置ppp接口的IPV6地址
	local tmpfile=$(iktimerc "select * from authuser where ppptype='pppoe' and pppoev6_wan='$iface'")
	while read config; do
		[ "$config" ] || continue
		local $config 2>/dev/null

		local res=$(__parent_dhcpv6_values_get "$iface")
		[ "$res" ] || continue

		local $res

		local total=${PPPINFO["$pppdev"]}
		if [ -z "$total" ]; then
			local total=$(__ipv6_prefix_index_get $iface)
			__update_ppp_odhcpd_config
			continue
		fi
		if [ "$dhcp6_prefix1" ]; then
			local parent="$iface"
			local prefix_len="64"
			local ipv6_addr=$(__dhcp6_addr_auto_get "$dhcp6_prefix1" "$total")
		fi

		if [ -n "$ipv6_addr" ]; then
			ip -6 addr replace $ipv6_addr  dev $pppdev preferred_lft $lan_preferred_lft valid_lft $lan_valid_lft
		fi
	done <<EOF
	$tmpfile
EOF
	unset PPPINFO
	if [ "$is_restart" = "true" ]; then
		__lan_odhcpdv6_stop		
		odhcpd >/dev/null 2>&1 &
	fi
}

__lan_localaddr_init()
{
	local iface=$1
	local flag=$2

	if [ -z "$iface" ]; then
		return
	fi

	local ula_id="${GWID:9:4}:${GWID:13:4}"
	local ula_prefix="fc00:$ula_id"
	local n=4096


	if [ "$iface" ]; then
		case "$iface" in
			lan*)
				local x=$(printf "%x" ${iface##lan})
				;;
			vlan*)
				n=$(( n + 1 + id))
				local x=$(printf "%x" $n)
				;;
		esac

		local link_addr="${ula_prefix}:$x::1/64"
		if [ "$flag" ]; then
			echo $link_addr
		else
			ip -6 addr replace $link_addr dev $iface >/dev/null 2>&1
		fi
	fi
}

__lan_odhcpdv6_stop()
{
	killall -9 odhcpd >/dev/null 2>&1
}

__odhcp6c_start()
{
	local interface=$1
	__odhcp6c_stop_one $interface

	create_local_addr $interface

	if interface_check_is_wanpppoe $interface ;then
		interface=${interface}_ad
	fi
	if [ "$prefix" = "auto" ]; then
		prefix=0
	fi
	local tmpvalue=$(echo -n ${GWID}${interface} |md5sum)
	local clientid=${tmpvalue:0:32}
	local force=""
	if [ "$force_prefix" = "1" ]; then
		local force="-F"
	fi

	local client_id=""
	if [ "$force_gen_duid" = "1" ]; then
		local client_id="-c $clientid"
	fi

	if [ "$internet" != "relay" ]; then
		odhcp6c -s /usr/ikuai/script/utils/odhcp6c-cb.sh $client_id -Ntry -P$prefix $force -t120 -p /var/run/odhcp6c.${interface}.pid $interface >/dev/null 2>&1 &
	else
		odhcp6c -s /usr/ikuai/script/utils/odhcp6c-cb.sh $client_id -Ntry -t120 -p /var/run/odhcp6c.${interface}.pid $interface >/dev/null 2>&1 &
	fi
#	odhcp6c -s /usr/ikuai/script/utils/odhcp6c-cb.sh -P64 -t120 -p /var/run/odhcp6c.${interface}.pid $interface -d
}

__odhcp6c_stop()
{
	killall -9 odhcp6c >/dev/null 2>&1
	rm -f /tmp/iktmp/dhcp6c/*
}

__odhcp6c_stop_one()
{
	local interface="$1"
	if [ "${interface:0:3}" = "wan" ]; then
		local iface1="${interface}_ad"
	else
		local iface1="$interface"
	fi
	local pids=$($IK_DIR_SCRIPT/utils/ikpidof.sh get odhcp6c 2>/dev/null)
	for pid_one in ${pids}; do
		local res=$(awk -v iface1="$iface1" -v iface2="$interface" '{if($1==iface1||$1==iface2)print $1}' /proc/$pid_one/cmdline 2>/dev/null)
		if [ "$res" ]; then
			kill $pid_one
			sleep 1
			kill -9 $pid_one
		fi
	done
}

#只给PPPOE的接口创建本地的IPV6
#因为在ipv6动态关闭时,会把IPV6地址清除掉, 
#所以我们使用附属接口的IPV6地址
create_local_addr()
{
	local interface=$1
	local is_pppoe

	local ifname=$interface
	if [ "${interface:0:3}" = "wan" ]&& interface_check_is_wanpppoe $interface ;then
		ifname=${interface}_ad
		is_pppoe=1
	elif [ "${interface:0:3}" = "ads" ];then
		is_pppoe=1
	fi
	if [ "$is_pppoe" ];then
		local exist_local_addr=$(ip -6 addr list dev $ifname |awk '$1=="inet6" && $NF=="link"{print 1;exit}')
		if [ "$exist_local_addr" ];then
			return
		fi

		if . /tmp/iktmp/pppoe6/$interface ;then
			ip -6 addr add $pppoe6_lllocal dev $ifname >/dev/null 2>&1
		fi
	fi
}

__static_ipv6_start()
{
	ip -6 addr add $ipv6_addr dev $interface
	ip -6 route add ::/0 via $ipv6_gateway dev $interface
	ip -6 route add ::/0 via $ipv6_gateway dev $interface table $interface
}

__lanid_get_by_wan()
{
	local ifname="$1"
	local lanids=""

	local default_parent=$(sqlite3 $IK_DB_CONFIG "select interface from ipv6_wan_config limit 1")

	for lan_config in $(ls /tmp/iktmp/cache/config/ipv6_lan_config.*); do
		if [ ! -e "$lan_config" ]; then
			continue
		fi
		local $(cat $lan_config)

		[ "$internet" = "static" ] && continue

		if [ -z "$parent" ]; then
			local parent="$default_parent"
		fi
		for parent_one in ${parent//,/ }; do
			if [ "$parent_one" = "$ifname" ]; then
				lanids+="${lanids:+,}$id"
			fi
		done
	done
	
	echo $lanids
}

__lan_stop()
{
	local ifname=$1
	local hit=0

	if [ "$ifname" ]; then
		local lan_ids=$(__lanid_get_by_wan $ifname)
	fi
	if [ "$lan_ids" ]; then
		action=del iface_ids=$lan_ids __lan_odhcpdv6_restart  "$ifname" >/dev/null 2>&1
	fi
	##删掉ppp接口的IPV6地址
	iktimerc "select * from authuser where ppptype='pppoe' and pppoev6_wan='$ifname'" | \
	while read config; do
		[ "$config" ] || continue
		local $config 2>/dev/null
		ip -6 addr flush dev $pppdev scope global
	done
}

reconnect()
{
	local iface="$1"
	if [ ! -e "$IK_DIR_CACHE/config/ipv6_wan_config.$iface" ]; then
		return 0
	fi
	local $(cat $IK_DIR_CACHE/config/ipv6_wan_config.$iface)
	[ "$enabled" = "yes" ] || return 0

	if [ "$internet" = "dhcp" -o "$internet" = "relay" ]; then
		ipset -F ipv6_prefix_$interface
		__odhcp6c_start $interface
	fi
}

reset()
{
	#local num=1
	if ! [ "$ARCH" = "x86" -a -z "$ENTERPRISE" ]; then
		#local num=3
		echo "expires=0 num=$num enterprise=1" > ${PKG_PATH}
	fi
	sqlite3 $IK_DB_CONFIG "update ipv6_wan_config set enabled='no' where id not in (select id from ipv6_wan_config order by id limit $num)"

	__wan_config_to_cache
	restart
}

check_multi_num()
{
	if [ -e "$PKG_PATH" ]; then
		local $(cat ${PKG_PATH} 2>/dev/null)
		if [ "$num" ]; then
			sqlite3 $IK_DB_CONFIG "update ipv6_wan_config set enabled='no' where id not in (select id from ipv6_wan_config order by id limit $num)"
		fi
	else
		sqlite3 $IK_DB_CONFIG "update ipv6_wan_config set enabled='no' where id not in (select id from ipv6_wan_config order by id limit 1)"
	fi
}

import_check_multi_num()
{
	if [ -e "$PKG_PATH" ]; then
		local $(cat ${PKG_PATH} 2>/dev/null)
		if [ "$num" ]; then
			sqlite3 $IK_DB_CONFIG "delete from ipv6_wan_config where id not in (select id from ipv6_wan_config order by id limit $num)"
		fi
	else
		sqlite3 $IK_DB_CONFIG "delete from ipv6_wan_config where id not in (select id from ipv6_wan_config order by id limit 1)"
	fi
}

#expires=
multi_renew()
{
	if [ -z "$expires" ]; then
		return
	fi
	local end_time=$expires
	if [ -e "$PKG_PATH" ]; then
		local $(cat $PKG_PATH 2>/dev/null)
		echo "expires=$end_time num=$num" > ${PKG_PATH}.$$
		mv ${PKG_PATH}.$$ ${PKG_PATH}
	fi
}

#expires= num=
multi_on()
{
	local old_config=$(cat ${PKG_PATH} 2>/dev/null)
	if [ "$expires" ]; then
		echo "expires=$expires num=$num" > ${PKG_PATH}.$$
		mv ${PKG_PATH}.$$ ${PKG_PATH}
	fi
	if [ "$num" ]; then
		sqlite3 $IK_DB_CONFIG "update ipv6_wan_config set enabled='no' where id not in (select id from ipv6_wan_config order by id limit $num)"
		sqlite3 $IK_DB_CONFIG "update ipv6_wan_config set enabled='yes' where id in (select id from ipv6_wan_config order by id limit $num)"
	fi
	local current_num=${num:-1}
	if [ "$old_config" ]; then
		local $old_config
		if [ "$current_num" -lt "$num" ]; then
			restart >/dev/null 2>&1 &
		fi
	else
		restart >/dev/null 2>&1 &
	fi
	return 0
}

multi_off()
{
	rm $PKG_PATH
	reset >/dev/null 2>&1 &
	return 0
}

restart()
{
	__sysctl_ipv6_disable
	__sysctl_ipv6_enable

	__odhcp6c_stop
	
#	__lan_config_init

	__lan_odhcpdv6_stop
	ip6tables -w -t mangle -F STREAM_IPV6_NEW

	rm -f $IK_DIR_CACHE/config/ipv6_wan_config.*
	__wan_config_to_cache
	ipset -F ipv6_local_host
	for conf_file in $(ls $IK_DIR_CACHE/config/ipv6_wan_config.*); do
		local $(cat $conf_file)
		ipset -F ipv6_prefix_$interface
		ipset -X ipv6_prefix_$interface
		[ "$enabled" = "yes" ] || continue

		if [ "$internet" = "dhcp" -o "$internet" = "relay" ];then
			__ipset_v6_create ipv6_prefix_$interface
			__odhcp6c_start $interface
		else
			__static_ipv6_start
		fi

	done
	action=replace iface_ids= __lan_odhcpdv6_restart >/dev/null 2>&1
	__init_odhcpd_config
}

start()
{
	local is_stop=1
	__sysctl_ipv6_enable

#	__lan_config_init

	for conf_file in $(ls $IK_DIR_CACHE/config/ipv6_wan_config.*); do
		local $(cat $conf_file)
		[ "$enabled" = "yes" ] || continue

		is_stop=0
		if [ "$internet" = "dhcp" -o "$internet" = "relay" ];then
			ipset -F ipv6_prefix_$interface
			__odhcp6c_start $interface
		else
			__static_ipv6_start
		fi
	done

	if [ "$is_stop" = "1" ]; then
		stop
		lan_restart >/dev/null 2>&1
	else
		action=replace iface_ids= __lan_odhcpdv6_restart >/dev/null 2>&1
	fi
}

stop()
{
	__sysctl_ipv6_disable
	__sysctl_ipv6_enable
	__lan_odhcpdv6_stop
	__odhcp6c_stop
}


__check_param_save()
{
	check_varl \
		'enabled	== "yes" or == "no"' \
		'interface	ifname_wan' \
		'internet	== "dhcp" or == "static" or == "relay"'
}

__ipv6_route_del()
{
	local iface="$1"
	ip -6 route  flush dev $iface
	ip -6 route  flush dev $iface table $iface
}

__ipv6_route_add()
{
	local iface="$1" gateway="$2" metric="$3"
	ip -6 route replace ::/0 via $gateway dev $iface metric $metric
	ip -6 route replace ::/0 via $gateway dev $iface table $iface metric 50
}

## $1: interface
__ipv6_route_lan_del()
{
	local del_iface=$1

	if [ -n "$del_iface" ]; then
		local del_ipv6_addr=$(interface_get_ipv6addr_mask $del_iface)
		for del_one in ${del_ipv6_addr}; do
			ip -6 route flush root $del_one
		done
		ip -6 route flush dev $del_iface proto static
		ip -6 route flush dev $del_iface metric 100
	fi
}

__ipv6_rule_add()
{
	local iface="$1" table="$2"

	ip -6 rule del dev $iface
	if [ "$table" ]; then
		ip -6 rule add dev $iface table $table prio 10000
	fi
}

__ipv6_rule_del()
{
	local iface="$1"

	ip -6 rule del dev $iface
}

wan_add()
{
	local count=$(sqlite3 $IK_DB_CONFIG "select count() from ipv6_wan_config")
	if [ ! -e "$PKG_PATH" ]; then
		if [ "$count" -ge "1" ]; then
			Autoiecho ipv6 multi_unsupport 1	
			exit 1
		fi
	else
		local $(cat $PKG_PATH)
		num=${num:-1}
		if [ "$count" -ge "$num" ]; then
			Autoiecho ipv6 multi_unsupport $num
			exit 1
		fi
	fi
	
	__check_param_save || exit 1
	local force_prefix=${force_prefix:-0}
	local force_gen_duid=${force_gen_duid:-1}

	local sql_param="enabled:str interface:str internet:str link_addr:str prefix:str force_prefix:int force_gen_duid:int"

	if [ "$ipv6_addr" != "" ]; then
		sql_param+=" ipv6_addr:str"
	else
		sql_param+=" ipv6_addr:null"
	fi

	if [ "$ipv6_gateway" != "" ]; then
		sql_param+=" ipv6_gateway:str"
	else
		sql_param+=" ipv6_gateway:null"
	fi

	local link_addr=$(interface_get_ipv6_linkaddr $interface)

	if SqlMsg=$(sql_config_insert $IK_DB_CONFIG ipv6_wan_config $sql_param);then
		id="$SqlMsg"

		__wan_config_to_cache
		if [ "$enabled" = "yes" ]; then
			ip -6 addr flush dev $interface scope global
			if [ "$internet" = "static" ]; then
				if [ -n "$ipv6_addr" ]; then
					ip -6 addr add $ipv6_addr  dev $interface
				fi
				### 缺少路由
				__ipv6_route_add "$interface" "$ipv6_gateway" "$id"
			else
				if [ "$internet" = "relay" ]; then
					__init_odhcpd_config >/dev/null 2>&1
				fi
				__ipset_v6_create ipv6_prefix_$interface
				__odhcp6c_start $interface
			fi
		fi
		fsyslog $(Iecho i18n_fsyslog_add)
		echo "$id"
		return 0
	else
		echo "$SqlMsg"
		return 1
	fi
}

wan_del()
{
	sql_config_get_list $IK_DB_CONFIG "select * from ipv6_wan_config where id in ($id); delete from ipv6_wan_config where id in ($id)" \
	|while read config ;do
		local $config
		__wan_config_to_cache
		if [ "$enabled" = "yes" ]; then
			if [ "$internet" = "dhcp" -o "$internet" = "relay" ]; then
				__ipset_v6_destory ipv6_prefix_$interface
				__odhcp6c_stop_one $interface	
			fi
			ip -6 addr flush dev $interface scope global
			__ipv6_route_del $interface
		fi
		__lan_stop $interface >/dev/null 2>&1
		if [ "$internet" = "relay" ]; then
			__init_odhcpd_config >/dev/null 2>&1
		fi
		rm -f /tmp/iktmp/dhcp6c/${interface}.old >/dev/null 2>&1
		rm -f $IK_DIR_CACHE/config/ipv6_wan_config.$interface
	done
	fsyslog $(Iecho i18n_fsyslog_del)
	return 0
}

wan_edit()
{
	local res=$(sql_config_get_list $IK_DB_CONFIG "select * from ipv6_wan_config where id=$id" prefix=old_)
	if [ "$res" = "" ];then
		return 0
	fi
	local $res

	local link_addr=$(interface_get_ipv6_linkaddr $interface)

	local force_prefix=${force_prefix:-0}
	local force_gen_duid=${force_gen_duid:-1}
	local sql_param="enabled:str interface:str internet:str link_addr:str ipv6_addr:str ipv6_gateway:str prefix:str force_prefix:int force_gen_duid:int"
	if SqlMsg=$(sql_config_update $IK_DB_CONFIG ipv6_wan_config "id=$id" $sql_param) ;then
		if ! NewOldVarl enabled interface internet ipv6_addr  ipv6_gateway prefix force_prefix force_gen_duid;then
			__wan_config_to_cache
			if ! NewOldVarl internet interface; then
				ip -6 addr flush dev $old_interface scope global
				__ipv6_route_del "$old_interface"
				
				interface=$old_interface __ipset_v6_destory ipv6_prefix_$old_interface
				__odhcp6c_stop_one $old_interface
			fi

			if ! NewOldVarl internet; then
				if [ "$internet" = "static" ]; then
					__lan_stop $old_interface >/dev/null 2>&1
				fi
			fi

			if ! NewOldVarl internet interface; then
				if [ "$internet" != "static" ]; then
					__ipset_v6_create ipv6_prefix_$interface
					__lan_stop $old_interface >/dev/null 2>&1
					rm /tmp/iktmp/dhcp6c/$old_interface
					rm /tmp/iktmp/dhcp6c/${old_interface}.old
					__init_odhcpd_config >/dev/null 2>&1
				fi
			fi


			if [ "$enabled" = "yes" ]; then
				ip -6 addr flush dev $interface scope global
				if [ "$internet" = "static" ]; then
					if [ -n "$ipv6_addr" ]; then
						ip -6 addr add $ipv6_addr  dev $interface
					fi
					### 缺少路由
					__ipv6_route_add "$interface" "$ipv6_gateway" "$id"
				else
					__odhcp6c_start $interface
				fi
			fi
		fi
		fsyslog $(Iecho i18n_fsyslog_edit)
		return 0
	else
		echo "$SqlMsg"
		return 1
	fi
}

wan_down()
{
	sql_config_get_list $IK_DB_CONFIG "select * from ipv6_wan_config where id in ($id); update ipv6_wan_config set enabled='no' where id in ($id)" | \
	while read config; do
		local $config
		if [ "$internet" = "dhcp" -o "$internet" = "relay" ]; then
			__ipset_v6_destory ipv6_prefix_$interface
			__odhcp6c_stop_one $interface
		fi
		ip -6 addr flush dev $interface scope global
		__ipv6_route_del "$interface"
		__lan_stop $interface >/dev/null 2>&1
		if [ "$internet" = "relay" ]; then
			__init_odhcpd_config >/dev/null 2>&1
		fi
		rm -f /tmp/iktmp/dhcp6c/$interface >/dev/null 2>&1
		rm -f /tmp/iktmp/dhcp6c/${interface}.old >/dev/null 2>&1
	done
	__wan_config_to_cache

	fsyslog $(Iecho i18n_fsyslog_down)
	
	return 0
}

wan_up()
{
	sql_config_get_list $IK_DB_CONFIG "select * from ipv6_wan_config where id in ($id); update ipv6_wan_config set enabled='yes' where id in ($id)"| \
	while read config; do
		local $config
		ip -6 addr flush dev $interface scope global
		if [ "$internet" = "static" ]; then
			if [ -n "$ipv6_addr" ]; then
				ip -6 addr add $ipv6_addr  dev $interface
			fi
			### 缺少路由
			__ipv6_route_add "$interface" "$ipv6_gateway" "$id"
		else	
			if [ "$internet" = "relay" ]; then
				__init_odhcpd_config >/dev/null 2>&1
			fi
			__ipset_v6_create ipv6_prefix_$interface
			__odhcp6c_start $interface
		fi
	done
	__wan_config_to_cache

	fsyslog $(Iecho i18n_fsyslog_up)

	return 0
}

__check_param()
{
	check_varl \
		'enabled	== "yes" or == "no"' \
		'interface	ifname_lan' \
		'internet	== "dhcp" or == "static" or == "relay"' \
		'dhcpv6		== "0" or == "1"' \
		'leasetime	> 0' \
		'ra_flags	== "0" or == "1" or == "2"'

}

__check_internet_dhcp_conflict()
{
	local filters=""
	if [ "$1" ]; then
		filters="and id != $1"
	fi
	local res=$(sqlite3 $IK_DB_CONFIG "select * from ipv6_lan_config where enabled='yes' and internet='dhcp' $filters")
	if [ "$res" ]; then
		Autoiecho ipv6 dhcp_conflict	
		return 1
	fi
	
	return 0
}

__check_internet_static_conflict()
{
	local filters=""
	if [ "$1" ]; then
		filters="and id != $1"
	fi

	local res=$(sqlite3 $IK_DB_CONFIG "select * from ipv6_lan_config where enabled='yes' and internet='static' $filters")
	if [ "$res" ]; then
		Autoiecho ipv6 static_conflict	
		return 1
	fi
	return 0
}

lan_restart()
{
	__create_lan_config_to_cache
	sql_config_get_list $IK_DB_CONFIG "select * from ipv6_lan_config where enabled='yes';" \
	|while read config ;do
		local $config
		if [ "$enabled" = "yes" ]; then
			__ipv6_route_lan_del $interface
			ip -6 addr flush dev $interface scope global
		fi
	done

	action=replace iface_ids= __lan_odhcpdv6_restart >/dev/null 2>&1 
	init_static
	__init_odhcpd_config >/dev/null 2>&1
	return 0
}

add() {
	__check_param || exit 1

	if [ "$internet" = "relay" ]; then
		local res=$(sqlite3 $IK_DB_CONFIG "select * from ipv6_lan_config where parent like '%$parent%'")
		if [ "$res" ]; then
			Autoiecho param iface_inused $parent
			return 1
		fi
	fi

	local sql_param="id:null enabled:str interface:str internet:str prefix_len:str dhcpv6:int use_dns6:int ipv6_dns1:str ipv6_dns2:str leasetime:str ra_flags:str ra_static:int parent:str"

	if [ "$ipv6_addr" != "" ]; then
		sql_param+=" ipv6_addr:str"
	else
		sql_param+=" ipv6_addr:null"
	fi
	if [ "$internet" = "static" ]; then
		parent=""
	fi
	if [ "$internet" = "relay" ]; then
		parent="${parent//,*/}"
	fi
	if SqlMsg=$(sql_config_insert $IK_DB_CONFIG ipv6_lan_config $sql_param);then
		id="$SqlMsg"

		__create_lan_config_to_cache $id
		action=replace iface_ids=$id __lan_odhcpdv6_restart >/dev/null 2>&1
		init_static
		__init_odhcpd_config >/dev/null 2>&1

		echo "$id"
		return 0
	else
		echo "$SqlMsg"
		return 1
	fi
}

del() {
	sql_config_get_list $IK_DB_CONFIG "select * from ipv6_lan_config where id in ($id); delete from ipv6_lan_config where id in ($id)" \
	|while read config ;do
		local $config
		if [ "$enabled" = "yes" ]; then
			if [ "$internet" = "relay" ]; then
				__update_relay_prefix_config $parent
			else
				__update_iface_prefix_config $interface
			fi
			__ipv6_route_lan_del $interface
			ip -6 addr flush dev $interface scope global
		fi
		__delete_lan_config_to_cache $interface

		if [ "${interface:0:3}" = "doc" ]; then
			docker_network_v6_del $interface
		fi
	done

#	__init_odhcpd_config >/dev/null 2>&1
		
	return 0
}

down() {
	sql_config_get_list $IK_DB_CONFIG "select * from ipv6_lan_config where id in ($id); update ipv6_lan_config set enabled='no' where id in ($id)" \
	|while read config ;do
		local $config
		if [ "$enabled" = "yes" ]; then
			if [ "$internet" = "relay" ]; then
				__update_relay_prefix_config $parent
			else
				__update_iface_prefix_config $interface
			fi
			__ipv6_route_lan_del $interface
			ip -6 addr flush dev $interface scope global
		fi
		__create_lan_config_to_cache $id

		if [ "${interface:0:3}" = "doc" ]; then
			docker_network_v6_del $interface
		fi
	done

#	__init_odhcpd_config >/dev/null 2>&1
	return 0
}

up() {
	sql_config_get_list $IK_DB_CONFIG "select * from ipv6_lan_config where id in ($id); update ipv6_lan_config set enabled='yes' where id in ($id)" \
	|while read config ;do
		local $config
		__create_lan_config_to_cache $id
	done
	action=replace iface_ids=$id __lan_odhcpdv6_restart >/dev/null 2>&1 

	init_static
	__init_odhcpd_config >/dev/null 2>&1
	return 0
}

edit() {
	__check_param || exit 1

	if [ "$internet" = "relay" ]; then
		local res=$(sqlite3 $IK_DB_CONFIG "select * from ipv6_lan_config where parent like '%$parent%' and id!=$id")
		if [ "$res" ]; then
			Autoiecho param iface_inused $parent
			return 1
		fi
	fi

	local res=$(sql_config_get_list $IK_DB_CONFIG "select * from ipv6_lan_config where id=$id" prefix=old_)
	if [ "$res" = "" ];then
		return 0
	fi
	local $res

	local sql_param="interface:str internet:str prefix_len:str dhcpv6:int use_dns6:int ipv6_dns1:str ipv6_dns2:str leasetime:str parent:str ra_flags:str ra_static:int"

	if [ "$ipv6_addr" != "" ]; then
		sql_param+=" ipv6_addr:str"
	else
		sql_param+=" ipv6_addr:null"
	fi

	if [ "$internet" = "static" ]; then
		parent=""
	fi

	if [ "$internet" = "relay" ]; then
		parent="${parent//,*/}"
	fi
	if [ "$use_dns6" = "0" ]; then
		ipv6_dns1=""
		ipv6_dns2=""
	fi

	if SqlMsg=$(sql_config_update $IK_DB_CONFIG ipv6_lan_config "id=$id" $sql_param) ;then 
		if ! NewOldVarl interface internet prefix_len dhcpv6 ipv6_addr use_dns6 ipv6_dns1 ipv6_dns2 leasetime ra_flags ra_static parent;then
			__create_lan_config_to_cache $id
			if ! NewOldVarl internet interface parent ipv6_addr prefix_len ra_static; then
				if ! NewOldVarl interface; then
					__delete_lan_config_to_cache $old_interface
					if [ "${old_interface:0:3}" = "doc" ]; then
						docker_network_v6_del $old_interface
					fi
				fi
				if [ "$enabled" = "yes" ]; then
					if [ "$old_internet" = "relay" ]; then
						interface=$old_interface __update_relay_prefix_config $old_parent
					else
						__update_iface_prefix_config $old_interface
					fi
					__ipv6_route_lan_del $old_interface
					ip -6 addr flush dev $old_interface scope global
				fi
			fi
			[ "$enabled" = "yes" ]&& {
				action=replace iface_ids=$id __lan_odhcpdv6_restart >/dev/null 2>&1 
			}
			init_static
			__init_odhcpd_config >/dev/null 2>&1
		fi
		return 0
	else
		echo "$SqlMsg"
		return 1
	fi
}

docker_network_v6_add()
{
	local ifname=$1 ip6addr=$2

	[ -z "$ifname" -o -z "$ip6addr" ] && return

	[ "${ifname:0:3}" != "doc" ] && return

	[ ! -e "/usr/sbin/ikdocker" ] && return


	local docker_config=$(ikdocker network_get_list name=$ifname)
	if [ "$docker_config" ]; then
		local $docker_config
		if [ "$name" -a "$id" -a "$subnet" -a "$gateway" ]; then
			ikdocker network_edit id=$id name=$name subnet=$subnet gateway=$gateway subnet6="$ip6addr" gateway6="${ip6addr//\/*}" >/dev/null 2>&1 
		fi
	fi
}

docker_network_v6_del()
{
	local ifname=$1

	[ -z "$ifname" ] && return

	[ "${ifname:0:3}" != "doc" ] && return

	[ ! -e "/usr/sbin/ikdocker" ] && return

	local docker_config=$(ikdocker network_get_list name=$ifname)
	if [ "$docker_config" ]; then
		local $docker_config
		if [ "$name" -a "$id" -a "$subnet" -a "$gateway" ]; then
			ikdocker network_edit id=$id name=$name subnet=$subnet gateway=$gateway  >/dev/null 2>&1
		fi
	fi
}

docker_network_init()
{
	local is_restart=0
	for conf_file in $(ls $IK_DIR_CACHE/config/ipv6_lan_config.*); do
		local $(cat $conf_file)

		[ "$enabled" = "yes" ] || continue
		[ "${interface:0:3}" = "doc" ] || continue

		[ "$internet" = "relay" ] && continue

		##docker启动，等待网卡状态ok
		for try in 1 2 3; do
			[ -e  "/sys/class/net/$interface" ] && break
			sleep 3
		done

		if [ -z "$parent" ]; then
			local parent=$(sqlite3 $IK_DB_CONFIG "select interface from ipv6_wan_config limit 1")
		fi

		for parent_one in ${parent//,/ }; do
			local res=$(__parent_dhcpv6_values_get $parent_one)
			[ "$res" ] || continue
			local $res

			if [ "$internet" != "static" ]; then
				if [ "$dhcp6_internet" -a "$dhcp6_internet" != "$internet" ]; then
					continue
				fi
			fi

			if [ "$internet" = "dhcp" ]; then
				if [ "$dhcp6_prefix1" ]; then
					local ipv6_addr=$(__dhcp6_addr_auto_get "$dhcp6_prefix1")
				else
					local ipv6_addr=""	
				fi
				if [ -n "$ipv6_addr" -a "${interface:0:3}" = "doc" ]; then
					local is_restart=1
					ip -6 addr replace $ipv6_addr  dev $interface preferred_lft $lan_preferred_lft valid_lft $lan_valid_lft
					docker_network_v6_add $interface $ipv6_addr
				fi
			elif [ "$internet" = "relay" ]; then
				if [ "$dhcp6_prefix1" ]; then
					local ipv6_addr=$(__dhcp6_addr_auto_get "$dhcp6_prefix1")
				else
					local ipv6_addr=""	
				fi
				if [ -n "$ipv6_addr" -a "${interface:0:3}" = "doc" ]; then
					local is_restart=1
					ip -6 route replace $ipv6_addr  dev $interface  expires $lan_valid_lft metric 100
					docker_network_v6_add $interface $ipv6_addr
				fi
			else
				if [ -n "$ipv6_addr" -a "${interface:0:3}" = "doc" ]; then
					for ipv6_addr_one in ${ipv6_addr//,/ }; do
						ip -6 addr $action $ipv6_addr_one  dev $interface
					done
					docker_network_v6_add $interface $ipv6_addr_one
				fi
			fi
		done
	done

	if [ "$is_restart" ]; then
		__init_odhcpd_config >/dev/null 2>&1
	fi
	return 0 
}


#username= iface= pppdev=
pppoe_add()
{
	local total=$(__ipv6_prefix_index_get $iface)
	__update_ppp_odhcpd_config
}

__ipv6_prefix_index_get()
{
	local iface="$1"

	declare -A PPPSTAT
	while read config; do
		[ "$config" ] || continue
		local $config
		if [ "$iface" != "$pppoev6_wan" ]; then
			continue
		fi
		PPPSTAT[\"$id\"]=$interface
	done < /tmp/iktmp/odhcpd/.ik_dhcpd_ppp.conf

	local total=0
	#选择一个没有使用的前缀
	for ((i=0;i<255;i++)); do
		if [ -z "${PPPSTAT[\"$i\"]}" ]; then
			total=$i
			break
		fi
	done
	unset PPPSTAT
	echo $total
}

__update_ppp_odhcpd_config()
{
	$LOCKUP
	local total="${total:-0}"
	local res=$(__parent_dhcpv6_values_get "$iface")
	[ "$res" ] || continue

	local $res
	if [ "$dhcp6_ra_mtu" ]; then
		local dhcp6_ra_mtu=$((dhcp6_ra_mtu-8))
	else
		local dhcp6_ra_mtu=1440
	fi

	if [ "$dhcp6_prefix1" ]; then
		local parent="$iface"
		local prefix_len="64"
		local ipv6_addr=$(__dhcp6_addr_auto_get "$dhcp6_prefix1" "$total")
	fi

	if [ -n "$ipv6_addr" ]; then
		ip -6 addr replace $ipv6_addr  dev $pppdev preferred_lft $lan_preferred_lft valid_lft $lan_valid_lft
		##odhcpd服务添加ppp接口
		flock /tmp/iktmp/odhcpd/.ik_dhcpd_ppp.conf echo "id=$total interface=$pppdev ipv6_dns1=$dhcp6_dns1 ipv6_dns2=$dhcp6_dns2 leasetime=7200 ra_flags=1 ra_static=0 ra_mtu=$dhcp6_ra_mtu pppoev6_wan=$iface" >> /tmp/iktmp/odhcpd/.ik_dhcpd_ppp.conf
		__init_odhcpd_config >/dev/null 2>&1
	
	fi
	$UNLOCK
}


pppoe_stop()
{
	> /tmp/iktmp/odhcpd/.ik_dhcpd_ppp.conf
	__init_odhcpd_config >/dev/null 2>&1
}

EXPORT()
{
	Include import_export.sh
	local format=${format:-txt}
	if errmsg=$(export_txt $IK_DB_CONFIG ipv6_wan_config $format $IK_DIR_EXPORT/ipv6_wan_config.$format) ;then
		echo "ipv6_wan_config.$format"
		return 0
	else
		echo "$errmsg"
		return 1
	fi
}

IMPORT()
{
	Include import_export.sh
	if errmsg=$(import_txt $IK_DB_CONFIG ipv6_wan_config $IK_DIR_IMPORT/$filename "$append"  __check_param_save) ;then
		import_check_multi_num
		restart >/dev/null 2>/dev/null &
		return 0
	else
		echo "$errmsg"
		return 1
	fi
}

EXPORT_lan()
{
	Include import_export.sh
	local format=${format:-txt}
	if errmsg=$(export_txt $IK_DB_CONFIG ipv6_lan_config $format $IK_DIR_EXPORT/ipv6_lan_config.$format) ;then
		echo "ipv6_lan_config.$format"
		fsyslog $(Iecho i18n_fsyslog_EXPORT)
		return 0
	else
		echo "$errmsg"
		return 1
	fi
}

IMPORT_lan()
{
	Include import_export.sh
	if errmsg=$(import_txt $IK_DB_CONFIG ipv6_lan_config $IK_DIR_IMPORT/$filename "$append"  __check_param) ;then
		lan_restart >/dev/null 2>/dev/null &
		fsyslog $(Iecho i18n_fsyslog_IMPORT)
		return 0
	else
		echo "$errmsg"
		return 1
	fi
}

show() {
	local __filter=$(sql_auto_get_filter)
	local __order=$(sql_auto_get_order)
	local __limit=$(sql_auto_get_limit)
	local __where="$__filter $__order $__limit"
	Show __json_result__
}

__implant_code()
{
cat -<<EOF
	local posix = require "posix"
	local ffi = require "ffi"
	local C = ffi.C

	ffi.cdef [[
		int access(const char *pathname, int mode);
	]]
	local wan_info = {}

	function wan_extra_config(iface)
		local dhcp6_info = {}
		local filename = "/tmp/iktmp/dhcp6c/"..iface
		
		local file_status = "/tmp/iktmp/dhcp6c/".."."..iface
		if C.access(file_status, 0) == 0 then
			return dhcp6_info
		end

		local fp = io.open(filename, "r")
		if fp then
			for line in fp:lines() do
				local k,v = string.match(line, "([^ ]+)=([^ ]+)")
				if k and v then
					if k == "dhcp6_prefix1" then
						local v1,v2,v3 = string.match(v, "([^ ]+),([^ ]+),([^ ]+)")
						if v1 and v2 and v3 then
							dhcp6_info[k] = v1
							dhcp6_info["preferred_lft"] = v2
							dhcp6_info["valid_lft"] = v3
						end
					else
						dhcp6_info[k] = v
					end
				end
			end
			fp:close()
		end
		return dhcp6_info
	end

	local ret, dir = pcall(posix.dir, "/tmp/iktmp/dhcp6c")
	if ret then
		for k, v in pairs(dir) do
			if v ~= "." and v ~= ".." then
				if not wan_info[v] then
					wan_info[v] = {}
				end
				wan_info[v] = wan_extra_config(v)
			end
		end
	end


	function create_fc(col, typ, key)
		ikdb:create_function(col,1,
		function (ctx, iface)
			local res
			if wan_info[iface] then
				res = wan_info[iface][key]
			end

			if typ == "text" then
				ctx:result(res or "")
			elseif typ == "number" then
				ctx:result(tonumber(res) or 0)
			elseif typ == "bool" then
				ctx:result(res and 1 or 0)
			end
			return 0
		end)
	end

	create_fc("ipv6_addr", "text", "dhcp6_ip_addr")
	create_fc("ipv6_gateway", "text", "dhcp6_gateway")
	create_fc("dhcp6_dns1", "text", "dhcp6_dns1")
	create_fc("dhcp6_dns2", "text", "dhcp6_dns2")
	create_fc("dhcp6_prefix1", "text", "dhcp6_prefix1")
	create_fc("valid_lft", "text", "valid_lft")
	create_fc("preferred_lft", "text", "preferred_lft")
	
EOF
}

__check_ipv6addr_expires()
{
        for iface_one in $(ls /tmp/iktmp/dhcp6c 2>/dev/null); do
		local $(cat /tmp/iktmp/dhcp6c/$iface_one 2>/dev/null)
                local res=$(interface_get_ipv6addr $iface_one)
                if [ -z "$res" -a "$dhcp6_ip_addr" ]; then
                        > /tmp/iktmp/dhcp6c/.${iface_one}
		else
			rm /tmp/iktmp/dhcp6c/.${iface_one} 2>/dev/null
                fi
        done
}

__show_data()
{
	__check_ipv6addr_expires

	local sql_show="select *,ipv6_addr(interface) dhcp6_ip_addr,ipv6_gateway(interface) dhcp6_ip_gateway, dhcp6_dns1(interface) dhcp6_dns1, dhcp6_dns2(interface) dhcp6_dns2, dhcp6_prefix1(interface) dhcp6_prefix1, valid_lft(interface) valid_lft, preferred_lft(interface) preferred_lft from ipv6_wan_config $__where"	
	local __sql_implant_code__=$(__implant_code)

	if [ ! -e "$PKG_PATH" ]; then
		sql_show="${sql_show//limit */limit 1}"	
	fi

	local data=$(sql_config_get_json $IK_DB_CONFIG "$sql_show")
	json_append __json_result__ data:json
	return 0
}

__show_total()
{
	local total=$(sqlite3 $IK_DB_CONFIG "select count() from ipv6_wan_config $__filter")
	json_append __json_result__ total:int
	return 0	
}

__show_multi_support()
{
	local multi_support=0
	local multi_num=1
	local expires=0
	local enterprise=0
	if [ -e "$PKG_PATH" ]; then
		multi_support=1
		local $(cat $PKG_PATH)
		multi_num=${num:-1}
	fi

	json_append __json_result__ multi_support:int multi_num:int expires:int enterprise:int
}

__show_bind_status()
{
	local bind_status=1
	local res=$(sqlite3 $IK_DB_CONFIG "select code from register")
	if [ "$res" ]; then
		bind_status=1
	fi

	json_append __json_result__ bind_status:int
}

__dhcp6_addrpool_get()
{
	local addrpool
	local addrlist=(${1//:/ })
	local addr0=${addrlist[0]}
	local addr1=${addrlist[1]}
	local addr2=${addrlist[2]}
	local addr3=${addrlist[3]}
	local mask=${addrlist[4]//\/}


	if [ -z "$mask" ]; then
		echo "[]"
		return
	fi
	if [ "$mask" -ge "64" ]; then
		echo "[]"
		return
	fi

	local dstmask=$((mask+4))

	if [ "$mask" = "56" ]; then
		local tmp_addr="${addr3:0:-2}0"
	elif [ "$mask" = "60" ]; then
		local tmp_addr="${addr3:0:-1}"
	fi

	if [ "$mask" = "56" -o "$mask" = "60" ]; then
		for i in {1..9}; do
			addr3="${tmp_addr}$i"
			addrpool+="${addrpool:+,}\"${addr0}:${addr1}:${addr2}:${addr3}::1/$dstmask\""
		done	

		for i in {a..f}; do
			addr3="${tmp_addr}$i"
			addrpool+="${addrpool:+,}\"${addr0}:${addr1}:${addr2}:${addr3}::1/$dstmask\""
		done
	fi

	echo "[$addrpool]"
	
}

__show_dhcp6_info()
{
	local dhcp6_ip_addr dhcp6_gateway dhcp6_addrpool
	local status=0
	. $IK_DIR_CACHE/config/ipv6_wan_config.$interface 2>/dev/null
	if [ "$enabled" = "yes" -a "$internet" = "dhcp" ];then
		if [ -e "/tmp/iktmp/dhcp6c/$interface" ]; then
			. /tmp/iktmp/dhcp6c/$interface 2>/dev/null
			status=0
		else
			status=1
		fi
	fi

	dhcp6_addrpool="$(__dhcp6_addrpool_get $dhcp6_prefix1)"

	local dhcp6_info=$(json_output status:int dhcp6_dns1:str dhcp6_dns2:str dhcp6_prefix1:str dhcp6_ra_mtu:str dhcp6_addrpool:json)
	json_append __json_result__ dhcp6_info:json

	return 0
}

__lan_implant_code()
{
cat -<<EOF
	local posix = require "posix"

	local ip6addr = {}
	local linkaddr = {}

	function get_lan_v6addr(iface)
		local ipv6_addr=""
		local link_addr=""
		local cmd=string.format("ip -6 addr show dev %s 2>/dev/null", iface)
		local fp = io.popen(cmd)
		if fp then
			for line in fp:lines() do
				local family,addr,_,scope = string.match(line, "([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+)")
				if family == "inet6" and addr and scope then
					if scope == "global" then
						if ipv6_addr ~= "" then
							ipv6_addr = string.format("%s,%s", ipv6_addr, addr)
						else
							ipv6_addr = addr
						end
					else
						if link_addr == "" then
							link_addr = addr
						end
					end
				end
			end
			ip6addr[iface] = ipv6_addr
			linkaddr[iface] = link_addr

			fp:close()
		end
	end

	local ret, dir = pcall(posix.dir, "/tmp/iktmp/cache/config")
	if ret then
		for k, v in pairs(dir) do
			if v ~= "." and v ~= ".." then
				local name = string.sub(v, 1, 15)
				if name == "ipv6_lan_config" then
					local iface = string.sub(v, 17)
					get_lan_v6addr(iface)
				end
			end
		end
	end

	function create_fc(col, typ, key)
		ikdb:create_function(col,1,
		function (ctx, iface)
			local res

			if col == "link_addr" then
				ctx:result(linkaddr[iface] or "")
			else
				ctx:result(ip6addr[iface] or "")
			end
			return 0
		end)
	end

	create_fc("ipv6_addr", "text", "ipv6_addr")
	create_fc("link_addr", "text", "link_addr")
EOF
}


__show_lan_data()
{
	local lan_data
	
	local __sql_implant_code__=$(__lan_implant_code)

	local sql_show="select *,ipv6_addr(interface) ipv6_addr,link_addr(interface) linkaddr from ipv6_lan_config $__where"

	local lan_data=$(sql_config_get_json $IK_DB_CONFIG "$sql_show")

	json_append __json_result__ lan_data:json

	return 0
}

__show_lan_total()
{
	local lan_total=$(sqlite3 $IK_DB_CONFIG "select count() from ipv6_lan_config $__filter")
	json_append __json_result__ lan_total:int

	return 0
}

__show_interface()
{
	local interface=$(interface_get_ifname_comment_json wan)
	json_append __json_result__ interface:json
}	

__show_lan_interface()
{
	local lan_interface=$(interface_get_ifname_comment_json lan,vlan,doc)
	json_append __json_result__ lan_interface:json
}

__lease_implant_code()
{
cat -<<EOF
	local macset = {}
	local fp = io.popen("ip -6 neighbor list")
	if fp then
		for line in fp:lines() do
			local link_addr,interface,mac,status = line:match("([^ ]+) dev ([^ ]+) lladdr ([^ ]+) (.*)")
			if link_addr and interface and mac and status then
				if string.match(link_addr, "^fe80") then 
					macset[link_addr]=mac	
				end
			end
		end
		fp:close()
	end

	local mac_comment = {}
	local f_mac = io.open("/tmp/mac_comment", "r")
	if f_mac then
		for line in f_mac:lines() do
			local id,mac,comment = line:match("([^ ]+) ([^ ]+) ([^ ]+)")
			if mac and comment then
				mac_comment[mac]=comment
			end
		end
		f_mac:close()
	end


	ikdb:create_function('dhcp_comment',1,
		function (ctx, link_addr)
			local mac=macset[link_addr]
			local comment
			if mac then
				comment = mac_comment[mac]
			end
			ctx:result_text(comment or '') 
		end
	)

	ikdb:create_function('mac',1,
		function (ctx, link_addr)
			local mac=macset[link_addr]
			ctx:result_text(mac or '') 
		end
	)

	ikdb:create_function('ipv6_addr',1,
		function (ctx, ipv6_addr)
			local ipv6_addr=string.gsub(ipv6_addr, "/128", "")
			ctx:result_text(ipv6_addr or '') 
		end
	)
	
EOF
}

__show_client_list()
{
	if [ "$__filter" ];then
		local __filter="$__filter and timeout > 0"
	else
		local __filter="where timeout > 0"
	fi
	local __where="$__filter $__order $__limit"
	local __sql_implant_code__=$(__lease_implant_code)
	local client_data=$(sql_config_get_json $DHCPV6_LEASEFILE "select *,expires-strftime('%s') timeout,mac(link_addr) mac,dhcp_comment(link_addr) comment,ipv6_addr(ipv6_addr) ipv6_addr from leases $__where")
	json_append  __json_result__ client_data:json
}

__show_client_total()
{
	if [ "$__filter" ];then
		local __filter="$__filter and timeout > 0"
	else
		local __filter="where timeout > 0"
	fi

	local __sql_implant_code__=$(__lease_implant_code)
	local $(sql_config_get_list $DHCPV6_LEASEFILE "select count() as client_total,expires-strftime('%s') timeout from leases $__filter")
	json_append  __json_result__ client_total:int
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

Show()
{
	local ____TYPE_SHOW____
	local ____SHOW_TOTAL_AND_DATA____
	local TYPE=${TYPE:-data}

	#if [[ ",$TYPE," =~ ,data, && ",$TYPE," =~ ,total, ]];then
	#	____SHOW_TOTAL_AND_DATA____=1
	#fi

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


Command $@


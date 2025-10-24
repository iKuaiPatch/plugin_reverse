#!/bin/bash /etc/ikcommon

Include iproute.sh urlcode.sh iconv.sh ipmacgroup.sh timersql.sh

#id= interface=wan1
__add_iface_macvlan()
{
	if [ "$proxy_username" ]; then
		local mac=$(echo "$proxy_username" |md5sum)
	else
		local mac=$(cat /dev/urandom |hexdump -n 16 -e '16/1 "%02x"')
	fi
	local mac="00:${mac:0:2}:${mac:2:2}:${mac:4:2}:${mac:6:2}:${mac:8:2}"

	ip link add link $interface name ${interface}_proxy${id} ${mac:+address $mac} up type macvlan
}

#id= interface=wan1
__del_iface_macvlan()
{
	ip link del dev ${interface}_proxy${id}
}

#id= username= passwd= interface=
__pppoe_connect()
{
	local ppp_ifname="adsl_proxy$id"
	local dev_ifname="${interface}_proxy${id}"
	local ipparam="pppoe_client"

	local command_runle="/usr/sbin/pppd linkname $ppp_ifname ifname $ppp_ifname modem crtscts plugin rp-pppoe.so nic-$dev_ifname  mtu 1480 mru 1480\
			iklog_prefix $ppp_ifname persist usepeerdns user "$(url_decode "$proxy_username")" password "$(url_decode "$proxy_passwd")" holdoff 5 lcp-echo-failure 20 lcp-echo-interval 3 maxfail 0\
			maxconnect 0 ipparam $ipparam"

	$command_runle >/dev/null 2>&1 &
}

#id=
__pppoe_disconnect()
{
	local ppp_ifname="adsl_proxy$id"	
	if [ -f /tmp/iktmp/pppoe/$ppp_ifname ] ;then
		ps |awk '/\/usr\/sbin\/pppd linkname '$ppp_ifname' /{system ("kill "$1)}' 2>/dev/null
	else
		ps |awk '/\/usr\/sbin\/pppd linkname '$ppp_ifname' /{system ("kill -9 "$1 )}' 2>/dev/null
	fi
	rm -f /tmp/iktmp/pppoe/$ppp_ifname
}

__kick_user()
{
	local username="$1"
	Include auth/authcntl.sh
	if ! data=$(timersql_exec "select * from authuser where username='$username'; delete from authuser where username='$username'") ;then
		return
	fi
	if [ "$data" ];then
		echo "$data" |authcntl_kick pppuser_kick_user
	fi
}

#username= ip=
proxy_connect()
{
	local res=$(sql_config_get_list $IK_DB_CONFIG "select * from pppuser_proxy where username='$username'")
	[ "$res" ] || return 1
	local $res

	local ppp_ifname="adsl_proxy$id"

	local markid=$(iproute_get_markid $ppp_ifname)
	local interface=$proxy_wan
	if [ ! -e "/sys/class/net/$ppp_ifname" ]; then
		__add_iface_macvlan
		__pppoe_disconnect
		__pppoe_connect
	fi
	ik_cntl route_band enable
	ik_cntl route_band add $ppp_ifname $ip
}

#username= ip=
proxy_disconnect()
{
	local res=$(sql_config_get_list $IK_DB_CONFIG "select * from pppuser_proxy where username='$username'")
	[ "$res" ] || return 1
	local $res
	local ppp_ifname="adsl_proxy$id"
	local interface=$proxy_wan

	local res=$(iktimerc "select id from authuser where username='$username'")
	if [ -z "$res" ]; then
		__pppoe_disconnect
		__del_iface_macvlan
	fi	
	ik_cntl route_band del $ppp_ifname $ip
}

add()
{
	__check_param || exit 1
	local create_time=$(date +%s)
	local sql_param=" enabled:str comment:str username:str proxy_username:str proxy_passwd:str proxy_wan:str"
	if SqlMsg=$(sql_config_insert $IK_DB_CONFIG pppuser_proxy $sql_param) ;then
		local id=$SqlMsg
		sqlite3 $IK_DB_CONFIG "update pppuser set proxy_username='$proxy_username' where username='$username'"	
		echo $id
		return 0
	else
		echo "$SqlMsg"
		return 1
	fi
}

del()
{
	sql_config_get_list $IK_DB_CONFIG "select * from pppuser_proxy where id in ($id); delete from pppuser_proxy where id in ($id)" |\
	while read config; do
		local $config
		sqlite3 $IK_DB_CONFIG "update pppuser set enabled='no',proxy_username='' where username='$username'"	
		local interface=$proxy_wan
		__pppoe_disconnect
		__del_iface_macvlan
		[ "$enabled" = "yes" ] && __kick_user "$username"
	done
}

down()
{
	sql_config_get_list $IK_DB_CONFIG "select * from pppuser_proxy where id in ($id); update pppuser_proxy set enabled='no' where id in ($id)" |\
	while read config; do
		local $config
		sqlite3 $IK_DB_CONFIG "update pppuser set enabled='no',proxy_username='' where username='$username'"	
		local interface=$proxy_wan
		__pppoe_disconnect
		__del_iface_macvlan
		[ "$enabled" = "yes" ] && __kick_user "$username"
	done
}

up()
{
	sql_config_get_list $IK_DB_CONFIG "select * from pppuser_proxy where id in ($id); update pppuser_proxy set enabled='yes' where id in ($id)" |\
	while read config; do
		local $config
		sqlite3 $IK_DB_CONFIG "update pppuser set proxy_username='$proxy_username',enabled='yes' where username='$username'"	
	done
}

edit()
{
	__check_param || exit 1
	local res=$(sql_config_get_list $IK_DB_CONFIG "select * from pppuser_proxy where id=$id;" prefix=old_)
	if [ -z "$res" ];then
		return 1
	fi
	local $res
	
	local sql_param=" enabled:str comment:str username:str proxy_username:str proxy_passwd:str proxy_wan:str"

	if SqlMsg=$(sql_config_update $IK_DB_CONFIG pppuser_proxy  "id=$id" $sql_param) ;then
		if ! NewOldVarl username proxy_username proxy_passwd proxy_wan; then
			local interface=$old_proxy_wan
			__pppoe_disconnect
			__del_iface_macvlan
			__kick_user "$old_username"
			if ! NewOldVarl username; then
				sqlite3 $IK_DB_CONFIG "update pppuser set proxy_username='' where username='$old_username';update pppuser set proxy_username='$proxy_username' where username='$username'"
			fi
			if ! NewOldVarl proxy_username; then
				sqlite3 $IK_DB_CONFIG "update pppuser set proxy_username='$proxy_username' where username='$username'"
			fi
		fi
	else
		echo "$SqlMsg"
		return 1
	fi
}

__check_param()
{
	check_varl \
		'enabled      == "yes" or == "no"'\
		'comment      length <= 128' \
		'username     != "" and length <= 128' \
		'proxy_username != "" and length <= 128' \
		'proxy_passwd length <= 128' 
}

EXPORT()
{
	Include import_export.sh
	local format=${format:-txt}
	if errmsg=$(export_txt $IK_DB_CONFIG pppuser_proxy $format $IK_DIR_EXPORT/pppuser_proxy.$format) ;then
		echo "pppuser_proxy.$format"
		return 0
	else
		echo "$errmsg"
		return 1
	fi
}

IMPORT()
{
	Include import_export.sh
	if errmsg=$(import_txt $IK_DB_CONFIG pppuser_proxy $IK_DIR_IMPORT/$filename "$append"  __check_param) ;then
		init >/dev/null 2>/dev/null &
		return 0
	else
		echo "$errmsg"
		return 1
	fi
}

__implant_code()
{
cat -<<EOF
	local info_t = {}
	local pppoe_dir = "/tmp/iktmp/pppoe/"
	local fp = io.popen("ls " ..pppoe_dir)
	if fp then
		for file in fp:lines() do
			local f = io.open(pppoe_dir .. file)
			if f then
				local t = {}
				info_t[file] = t
				for line in f:lines() do
					local key, val = line:match("([^=]+)=(.*)")
					if key then t[key] = val end
				end
				f:close()
			end
			
		end
	end
	function create_fc(col, typ, key)
		ikdb:create_function(col,1,
		function (ctx, id)
			local res
			local name="adsl_proxy"..id
			local stat_info = info_t[name]
			if stat_info then
				res = stat_info[key]
			end	
			if typ == "text" then
				ctx:result(res or "")
			else
				ctx:result(tonumber(res) or 0)
			end
			return 0
		end)
	end

	create_fc("pppoe_ip_addr", "text", "pppoe_ip_addr")
	create_fc("pppoe_netmask", "text", "pppoe_netmask")
	create_fc("pppoe_gateway", "text", "pppoe_gateway")
	create_fc("pppoe_updatetime", "number", "pppoe_updatetime")
	create_fc("pppoe_dns1", "text", "pppoe_dns1")	
	create_fc("pppoe_dns2", "text", "pppoe_dns2")

EOF
}

show()
{
	local __filter=$(sql_auto_get_filter)
	local __order=$(sql_auto_get_order)
	local __limit=$(sql_auto_get_limit)
	local __where="$__filter $__order $__limit"
	Show __json_result__
}
__show_total()
{
	local __sql_implant_code__=$(__implant_code)
	local sql_show="select count() as total, *,pppoe_ip_addr(id) as pppoe_ip_addr, pppoe_netmask(id) as pppoe_netmask, pppoe_gateway(id) as pppoe_gateway, pppoe_updatetime(id) as pppoe_updatetime, pppoe_dns1(id) as pppoe_dns1, pppoe_dns2(id) as pppoe_dns2 from pppuser_proxy $__filter"
	local $(sql_config_get_list $IK_DB_CONFIG "$sql_show")
	local total=${total:-0}
	json_append __json_result__ total:int
}

__show_data()
{
	local __sql_implant_code__=$(__implant_code)
	local sql_show="select *,pppoe_ip_addr(id) as pppoe_ip_addr, pppoe_netmask(id) as pppoe_netmask, pppoe_gateway(id) as pppoe_gateway, pppoe_updatetime(id) as pppoe_updatetime, pppoe_dns1(id) as pppoe_dns1, pppoe_dns2(id) as pppoe_dns2 from pppuser_proxy $__where"
	local data=$(sql_config_get_json $IK_DB_CONFIG "$sql_show")
	json_append __json_result__ data:json
	return 0
}

__show_interface()
{
	local interface=$(interface_get_ifname_comment_json wan_phy)
	json_append __json_result__ interface:json
}

__show_username()
{
	local username=$(pppuser_get_username_json)
	json_append __json_result__ username:json	
}


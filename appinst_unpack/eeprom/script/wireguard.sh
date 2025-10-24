#!/bin/bash /etc/ikcommon
Include interface.sh, check.sh, ifether.sh, iproute.sh, crond.sh
boot()
{
	mkdir -p /tmp/iktmp/wireguard/config

	crond_clean wireguard
	crond_insert wireguard "*/3 * * * * $IK_DIR_SCRIPT/wireguard.sh resolve_flush"
	crond_commit

	init
}

init() {
	sql_config_get_list $IK_DB_CONFIG "select * from wireguard where enabled='yes'" |\
	while read config ;do
		if [ -n "$config" ];then
			local $config
			__exec_rule_restart_one $name
		fi
	done
}

updatedb()
{
        if [ "$old_sysver" -lt 300070015 ];then
                sql_config_get_list $IK_DB_CONFIG "select * from wireguard" |\
                while read config; do
                        [ "$config" ] || continue
                        local $config
                        local enabled="yes" interface=$name peer_publickey=$peer_publickey presharedkey=$presharedkey 
			local allowips=$allowips endpoint=$endpoint endpoint_port=$endpoint_port keepalive=$keepalive
			local sql_param="enabled:str interface:str peer_publickey:str presharedkey:str allowips:str endpoint:str endpoint_port:str keepalive:str"
			sql_config_insert $IK_DB_CONFIG wireguard_peers $sql_param
                done
        fi
}

vrrp_init()
{
	__exec_rule_clean
	sqlite3 $IK_DIR_LOG/vrrp/conf/config.db ".dump wireguard" |grep "^INSERT"| sqlite3 $IK_DB_CONFIG
	sqlite3 $IK_DIR_LOG/vrrp/conf/config.db ".dump wireguard_peers" |grep "^INSERT"| sqlite3 $IK_DB_CONFIG
	init
}

__check_param_add()
{
	check_varl \
		'enabled	== "yes" or == "no"' \
		'peer_publickey	!= ""' \
		'allowips	ipmaskbs' \
		'endpoint_port	== "" or ikports' 
}

__check_param_iface_add()
{
	check_varl \
		'enabled	== "yes" or == "no"' \
		'interface	ifname_wan or == "auto"' \
		'local_privatekey	!= ""' \
		'local_publickey	!= ""' \
		'local_address		ipmaskb' \
		'local_listenport	ikports'
}

__check_key_valid()
{
	local key="$1"
	if ! res=$(echo $key | base64 -d >/dev/null 2>&1); then
		Autoiecho param key_format "$key"
		return 1
	fi
	return 0
}

#检查配置的地址池与本地接口网段是否冲突
__check_vlan_addr_pool_is_valid()
{
	if ! res=$(check_interface_addrpool "$1" "$2"); then
		Autoiecho param addr_pool_conflict "$res"
		return 1
	fi
	return 0
}

__format_ipmask()
{
	local ipmask="$1"

	local output=""
	for ipmask_one in ${ipmask//,/ }; do
		local $($IK_DIR_SCRIPT/ipcalc.sh $ipmask_one)

		if [ "$NETWORK" -a "$PREFIX" ]; then
			output+="${output:+,}$NETWORK/$PREFIX"
		fi
	done
	echo $output
}

#ipmask=192.168.1.0/24,192.168.2.0/24
__check_allowip_conflict()
{
	local ipmask="$1"
	local sql_id="$2"
	if [ "$sql_id" ]; then
		local __where="where id!=$sql_id"
	fi

	local check_allowips=""
	local all_allowips=$(sqlite3 $IK_DB_CONFIG "select allowips from wireguard_peers $__where" -newline ,)
	if [ "$all_allowips" ]; then
		check_allowips="${all_allowips}$ipmask"
	else
		check_allowips="$ipmask"
	fi

	local output=""
	declare -A ALLOWIP
	for ipmask_one in ${check_allowips//,/ }; do
		local $($IK_DIR_SCRIPT/ipcalc.sh $ipmask_one)

		if [ "$NETWORK" -a "$PREFIX" ]; then
			key="$NETWORK/$PREFIX"
			if [ "${ALLOWIP[$key]}" = "1" ]; then
				Autoiecho param allowip_conflict "$ipmask_one"
				return 1
			else
				ALLOWIP[$key]=1
			fi
		fi
	done
	unset ALLOWIP
	return 0
}

# Try to resolve specified address to IP
# $1: domain name or IP
try_get_ip_of_address()
{
	local addr="$1"
	if expr "$addr" : '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+$' >/dev/null; then
		echo "$addr"
	else
		local ip=`resolveip -4 "$addr" | head -n1`
		if [ -z "$ip" ]; then
			ip=`resolveip -6 "$addr" | head -n1`
			if [ -z "$ip" ]; then
				ip="$addr"
			fi
		fi
		echo "$ip"
	fi
}

__create_config_cache()
{
	[ -z "$endpoint" ] && return

	local remote_addr=$(try_get_ip_of_address "$endpoint")
	echo "name=$interface endpoint=$endpoint remote_addr=$remote_addr" > $IK_DIR_TMP/wireguard/config/$id
}

__del_config_cache()
{
	if [ "$id" ]; then
		rm $IK_DIR_TMP/wireguard/config/$id 
	fi
}

resolve_flush()
{
        for rule_id in $(ls $IK_DIR_TMP/wireguard/config); do
                [ ! -e "$IK_DIR_TMP/wireguard/config/$rule_id" ] && continue
                local $(cat $IK_DIR_TMP/wireguard/config/$rule_id)

                local now_addr=$(try_get_ip_of_address "$endpoint")
                if [ "$now_addr" != "$remote_addr" ]; then
                        wg setconf $name $IK_DIR_TMP/wireguard/$name.conf
                        echo "name=$name endpoint=$endpoint remote_addr=$now_addr" > $IK_DIR_TMP/wireguard/config/$rule_id
                fi
        done
}

__exec_rule_clean()
{
	sql_config_get_list $IK_DB_CONFIG "select * from wireguard;" |\
	while read config ;do
		if [ -n "$config" ];then
			local $config
			__exec_rule_iface_del $name
		fi
	done
}

__exec_rule_peers_clean()
{
	sql_config_get_list $IK_DB_CONFIG "select * from wireguard_peers;" |\
	while read config ;do
		if [ -n "$config" ];then
			local $config
			__exec_rule_iface_del $name
			__del_config_cache
		fi
	done
}

add() {
	__check_param_add || exit 1

	__check_allowip_conflict "$allowips" || exit 1

	__check_key_valid "$peer_publickey" || exit 1
	__check_key_valid "$presharedkey" || exit 1

	local sql_param=" enabled:str comment:str interface:str peer_publickey:str presharedkey:str allowips:str endpoint:str endpoint_port:str keepalive:int"
	if SqlMsg=$(sql_config_insert $IK_DB_CONFIG wireguard_peers $sql_param);then
		id="$SqlMsg"

		__exec_rule_restart_one $interface

		echo "$id"
		return 0
	else
		echo "$SqlMsg"
		return 1
	fi
}
del() {
	sql_config_get_list $IK_DB_CONFIG "select * from wireguard_peers where id in ($id); delete from wireguard_peers where id in ($id)" |\
	while read config ;do
		if [ -n "$config" ];then
			local $config
			__exec_rule_iface_del $interface
			__del_config_cache
		fi
	done
	return 0
}
down() {
	sql_config_get_list $IK_DB_CONFIG "select * from wireguard_peers where id in ($id); update wireguard_peers set enabled='no' where id in ($id)" |\
	while read config ;do
		local $config
		[ "$enabled" = "yes" ]&& {
			__exec_rule_iface_del $interface
			__del_config_cache
		}
	done
	return 0
}
up() {
	sql_config_get_list $IK_DB_CONFIG "select * from wireguard_peers where id in ($id); update wireguard_peers set enabled='yes' where id in ($id)" |\
	while read config ;do
		local $config
		[ "$enabled" = "no" ]&& {
			__exec_rule_restart_one $interface
		}
	done
	return 0
}

edit() {
	__check_param_add || exit 1

	__check_allowip_conflict "$check_allowips" "$id" || exit 1

	__check_key_valid "$peer_publickey" || exit 1
	__check_key_valid "$presharedkey" || exit 1

	res=$(sql_config_get_list $IK_DB_CONFIG "select * from wireguard_peers where id=$id" prefix=old_)
	if [ "$res" = "" ];then
		return 0
	fi
	local $res

	local sql_param=" comment:str interface:str peer_publickey:str presharedkey:str allowips:str endpoint:str endpoint_port:str keepalive:int"

	if SqlMsg=$(sql_config_update $IK_DB_CONFIG wireguard_peers "id=$id" $sql_param) ;then 
		if ! NewOldVarl interface; then
			__exec_rule_iface_del $old_interface	
			__exec_rule_restart_one $interface
		else
			if ! NewOldVarl enabled interface local_privatekey local_publickey local_address local_listenport peer_publickey presharedkey allowips endpoint endpoint_port keepalive ;then
				__exec_rule_restart_one $interface
			fi
		fi
		return 0
	else
		echo "$SqlMsg"
		return 1
	fi

}

__exec_rule_iface_del()
{
	local iface_name="$1"
	if [ "$iface_name" ]; then
		ip route flush dev $iface_name metric 100 >/dev/null 2>&1
		ip link del dev $iface_name
		rm $IK_DIR_TMP/wireguard/$iface_name.conf
	fi
}

__init_iface_config()
{
	local res=$(sql_config_get_list $IK_DB_CONFIG "select * from wireguard where name='$iface' and enabled='yes'")
	if [ -z "$res" ]; then
		return
	fi
	local $res

	if [ "${interface:-auto}" != "auto" ];then
		local fwmark=$(iproute_get_markid $interface)
	fi

	ip link add dev $name type wireguard
	ip address add dev $name $local_address
	ip link set mtu ${mtu:-1420} dev $name

	(
		echo "[Interface]"
		echo "ListenPort = $local_listenport"
		echo "PrivateKey = $local_privatekey"
		if [ "$fwmark" ]; then
			echo "fwmark = $fwmark"
		fi
		echo ""
	) > $IK_DIR_TMP/wireguard/$name.conf
}

__init_iface_peers_config()
{
	ip route flush dev $iface metric 100

	sql_config_get_list $IK_DB_CONFIG "select * from wireguard_peers where interface='$iface' and enabled='yes'" |\
	while read config; do
		[ "$config" ] || continue
		local $config

		local format_ips=$(__format_ipmask $allowips)

		(
			echo "[Peer]"
			echo "PublicKey = $peer_publickey"
			if [ "$presharedkey" ]; then
				echo "PresharedKey = $presharedkey"
			fi
			echo "AllowedIPs = $format_ips"
			if [ "$endpoint" -a "$endpoint_port" ]; then
				echo "Endpoint = $endpoint:$endpoint_port"
			fi
			if [ "$keepalive" != "0" ]; then
				echo "PersistentKeepalive = $keepalive"
			fi
			if [ "$endpoint" ]; then
				__create_config_cache
			fi
			echo ""
		) >> $IK_DIR_TMP/wireguard/$interface.conf

		if wg setconf $interface $IK_DIR_TMP/wireguard/$interface.conf; then
			ip link set up dev $interface
		else
			ip link set down dev $interface
		fi

		for allow in ${format_ips//,/ }; do
			local mask="${allow##*/}"
			[ "$mask" = "0" ] && continue
			ip route add $allow dev $interface metric 100
		done
	done
}

#interface=wg11
__exec_rule_restart_one()
{
	local iface=$1
	if [ -z "$iface" ]; then
		return
	fi
	__exec_rule_iface_del $iface >/dev/null 2>&1
	__init_iface_config >/dev/null 2>&1
	__init_iface_peers_config >/dev/null 2>&1
}

__exec_rule_restart_all()
{
	sql_config_get_list $IK_DB_CONFIG "select name from wireguard where enabled='yes'" |\
	while read config; do
		[ "$config" ] || continue
		local $config
		__exec_rule_restart_one $name
	done
}

iface_add() {
	__check_param_iface_add || exit 1

	__check_key_valid "$local_privatekey" || exit 1
	__check_key_valid "$local_publickey" || exit 1

	local sql_param="id:null enabled:str interface:str name:str mtu:str local_privatekey:str local_publickey:str local_address:str local_listenport:int "
	if SqlMsg=$(sql_config_insert $IK_DB_CONFIG wireguard $sql_param);then
		id="$SqlMsg"
		__exec_rule_restart_one $name

		echo "$id"
		return 0
	else
		echo "$SqlMsg"
		return 1
	fi
}
iface_del() {
	sql_config_get_list $IK_DB_CONFIG "select * from wireguard where id in ($id); delete from wireguard where id in ($id)" |\
	while read config ;do
		if [ -n "$config" ];then
			local $config
			__exec_rule_iface_del $name
		fi
	done
	return 0
}
iface_down() {
	sql_config_get_list $IK_DB_CONFIG "select * from wireguard where id in ($id); update wireguard set enabled='no' where id in ($id)" |\
	while read config ;do
		local $config
		[ "$enabled" = "yes" ]&& {
			__exec_rule_iface_del $name
		}
	done
	return 0
}
iface_up() {
	sql_config_get_list $IK_DB_CONFIG "select * from wireguard where id in ($id); update wireguard set enabled='yes' where id in ($id)" |\
	while read config ;do
		local $config
		[ "$enabled" = "no" ]&& {
			__exec_rule_restart_one $name
		}
	done
	return 0
}

iface_edit() {
	__check_param_iface_add || exit 1

	__check_key_valid "$local_privatekey" || exit 1
	__check_key_valid "$local_publickey" || exit 1

	res=$(sql_config_get_list $IK_DB_CONFIG "select * from wireguard where id=$id" prefix=old_)
	if [ "$res" = "" ];then
		return 0
	fi
	local $res

	local sql_param="enabled:str name:str interface:str mtu:str local_privatekey:str local_publickey:str local_address:str local_listenport:int "

	if SqlMsg=$(sql_config_update $IK_DB_CONFIG wireguard "id=$id" $sql_param) ;then 
		if ! NewOldVarl name; then
			__exec_rule_iface_del "$old_name"	
			__exec_rule_restart_one $name
		else
			if ! NewOldVarl mtu ;then
				ip link set mtu ${mtu:-1420} dev $name
			fi
			if ! NewOldVarl interface local_privatekey local_publickey local_address local_listenport ;then
				__exec_rule_restart_one $name
			fi
		fi
		return 0
	else
		echo "$SqlMsg"
		return 1
	fi

}



EXPORT()
{
	Include import_export.sh
	local format=${format:-txt}
	if errmsg=$(export_txt $IK_DB_CONFIG wireguard $format $IK_DIR_EXPORT/wireguard.$format) ;then
		echo "wireguard.$format"
		return 0
	else
		echo "$errmsg"
		return 1
	fi
}

EXPORT_EXTEND()
{
	Include import_export.sh
	local format=${format:-txt}
	if errmsg=$(export_txt $IK_DB_CONFIG wireguard_peers $format $IK_DIR_EXPORT/wireguard_peers.$format) ;then
		echo "wireguard_peers.$format"
		return 0
	else
		echo "$errmsg"
		return 1
	fi
}


IMPORT()
{
	I18nload import_export.json
	Include import_export.sh

	if errmsg=$(import_txt $IK_DB_CONFIG wireguard $IK_DIR_IMPORT/$filename "$append"  __check_param_iface_add __exec_rule_clean) ;then
		init >/dev/null 2>/dev/null &
		return 0
	else
		echo "$errmsg"
		return 1
	fi
}

IMPORT_EXTEND()
{
	I18nload import_export.json
	Include import_export.sh

	if errmsg=$(import_txt $IK_DB_CONFIG wireguard_peers $IK_DIR_IMPORT/$filename "$append"  __check_param_add __exec_rule_peers_clean) ;then
		init >/dev/null 2>/dev/null &
		return 0
	else
		echo "$errmsg"
		return 1
	fi
}


#显示VLAN数组
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
        function create_fc(col, typ, key)
                ikdb:create_function(col,2,
                function (ctx, name, pubkey)
                        local res

			local cmd=string.format("wg show %s transfer 2>/dev/null", name)
			local fp = io.popen(cmd)
			if fp then
				for line in fp:lines() do
					local peers, download, upload = string.match(line, "([^ ]+)\t([^ ]+)\t([^ ]+)")
					if peers and download and upload then
						if peers == pubkey then
							if key == "download" then
								res=download
							else
								res=upload
							end
						end
					end
				end
				fp:close()
			end
                        ctx:result(res or "")
                        return 0
                end)
        end

	create_fc("upload", "text", "upload")
	create_fc("download", "text", "download")
EOF
}

__show_total()
{
	local total=$(sqlite3 $IK_DB_CONFIG "select count() from wireguard_peers $__filter")
	json_append __json_result__ total:int
}

__show_data()
{
	local sql_show="select *,upload(interface,peer_publickey) as upload,download(interface,peer_publickey) as download from wireguard_peers $__where"

	local __sql_implant_code__=$(__implant_code)
	local data=$(sql_config_get_json $IK_DB_CONFIG "$sql_show")
	json_append __json_result__ data:json

	return 0
}

__show_iface_total()
{
	local iface_total=$(sqlite3 $IK_DB_CONFIG "select count() from wireguard $__filter")
	json_append __json_result__ iface_total:int
}


__show_iface_data()
{
	local sql_show="select * from wireguard $__where"

	local iface_data=$(sql_config_get_json $IK_DB_CONFIG "$sql_show")
	json_append __json_result__ iface_data:json

	return 0
}

__show_interface()
{
	local interface=$(interface_get_ifname_comment_json wan)
	json_append __json_result__ interface:json
}

__show_wg_iface()
{
	local tmp_data
	local tmpfile=$(sql_config_get_list $IK_DB_CONFIG "select name from wireguard")
	while read config; do
		[ "$config" ] || continue
		local $config
		tmp_data+="${tmp_data:+,}\"$name\""
	done <<EOF
	$tmpfile
EOF
	local wg_iface="[$tmp_data]"
	json_append __json_result__ wg_iface:json
}


__show_gen_privatekey()
{
	wg genkey > /tmp/iktmp/wireguard/.privatekey

	wg pubkey < /tmp/iktmp/wireguard/.privatekey > /tmp/iktmp/wireguard/.pubkey

	local pubkey=$(cat /tmp/iktmp/wireguard/.pubkey)
	local privatekey=$(cat /tmp/iktmp/wireguard/.privatekey)
	rm /tmp/iktmp/wireguard/.pubkey
	rm /tmp/iktmp/wireguard/.privatekey

	json_append __json_result__ pubkey:str privatekey:str
}

__show_gen_sharedkey()
{
	wg genpsk 2>/dev/null > /tmp/iktmp/wireguard/.presharekey
	local presharedkey=$(cat /tmp/iktmp/wireguard/.presharekey)
	rm /tmp/iktmp/wireguard/.presharekey
	
	json_append __json_result__ presharedkey:str
}

#name=
__show_wg_detail()
{
	
	local endpoints="$(wg show $name endpoints 2>/dev/null| awk '{print $2}')"	
	local latest="$(wg show $name latest-handshakes 2>/dev/null| awk '{print $2}')"	
	local transfer="$(wg show $name transfer 2>/dev/null| awk '{print "download="$2,"upload="$3}')"
	if [ "$transfer" ]; then
		local $transfer
	fi
	
	json_append __json_result__ endpoints:str latest:str download:str upload:str
}

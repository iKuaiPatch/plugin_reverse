#!/bin/bash /etc/ikcommon

Include lock.sh, check.sh, interface.sh, iproute.sh, crond.sh
I18nload openvpn_ipsec.json

I18N_LOCAL_PREFIX="i18n_openvpn_ipsec_"
CHARON_LOG_FILE=/etc/log/ipsec-vpn/charon_log
IPSEC_CALL_TIMEOUT=4
# maxsize 2MB
CHARON_LOG_FILE_MAXSIZE=2097152
RESOLVED_NAMES_DIR=/var/run/ipsec-vpn/resolved
IPSEC_BASE_MARK="1000"
IPSEC_UPDOWN_SCRIPT="/etc/ppp/ipsec_updown.sh"

# $1: code
# $2: message (optional)
die_with() { [ -n "$2" ] && echo "$2"; exit $1; }
escape_multilined() { echo "$1" | sed 's/[ \t]/#/g' | awk '{printf("%s@",$0)}'; }
unescape_multilined() { echo "$1" | sed 's/@/\n/g;s/#/ /g'; }
is_valid_subnet_v4() { check_is_ipmaskb $1 || check_is_ip $1 ;}
LIecho()
{
	local k="$1"
	shift 1
	local emsg=`Iecho "i18n_openvpn_ipsec_$k" "$@"`
	if [ -n "$emsg" ]; then
		echo "$emsg"
	else
		echo "${k//_/ }" "$@"
	fi
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
		[ -n "$ip" ] || ip="$addr"
		echo "$ip"
	fi
}


#
# Check the predefined variables (if set):
#  authby, leftcert, rightcert, privatekey, ...
#
validate_parameters_or_die()
{
	expr "$name" : '[0-9A-Za-z_-]\+$' >/dev/null || die_with 2 "`LIecho Illegal_name`"


	if [ "$authby" = secret ]; then
		[ -n "$secret" ] || die_with 2 "`LIecho Missing_shared_secret`"
		# IKEv1 restrictions
		if [ "$keyexchange" = "ikev1" -a  -z "$leftid" -a  -z "$rightid" ]; then
			if __is_l2tpd_psk_enabled; then
				die_with 2 "`LIecho Cannot_use_IDs_with_PSK_authentication_when_L2TP_enables_IPsec`"
			fi
		fi
	elif [ "$authby" = "mschapv2" ]; then
		[ -n "$username" ] || die_with 2 "`LIecho Missing_name`"
		[ -n "$passwd" ] || die_with 2 "`LIecho Missing_password`"

	else
		die_with 2 "`LIecho Invalid_authentication_type`"
	fi
}

#

boot()
{
	mkdir -p $IK_DIR_CACHE/ike_client
	init
}

init()
{
	__init_connections
}

vrrp_init()
{
	__clean
	sqlite3 $IK_DB_CONFIG "delete from ike_client"	
	sqlite3 $IK_DIR_LOG/vrrp/conf/config.db ".dump ike_client" |grep "^INSERT"| sqlite3 $IK_DB_CONFIG
	init
}


# Try to bring up all enabled connections
__init_connections()
{
	__create_config_to_cache
	interface_get_name_to_cache_iked

	local ids=$(sqlite3 $IK_DB_CONFIG "select id from ike_client where enabled='yes'")
	__exec_swanctl_up "$ids"
	return 0
}

__create_config_to_cache() {
	local id=$1
	sql_config_get_list $IK_DB_CONFIG "select * from ike_client ${id:+ where id=$id}" |\
	while read config ;do
		local $config
		echo "$config" >$IK_DIR_CACHE/ike_client/${id}.tmp
		mv $IK_DIR_CACHE/ike_client/${id}.tmp $IK_DIR_CACHE/ike_client/$id
	done
}

__delete_config_to_cache()
{
	local id=$1
	rm -f $IK_DIR_CACHE/ike_client/$id
}


__exec_create_conf()
{
	# Any failure here indicates bugs in validate_parameters_or_die()!!!

	local remote_ip=`try_get_ip_of_address "$remote_addr"`

	local mark=0
	if [ "$interface" = auto ]; then
		interface=""
	else
		local mark=$(iproute_get_markid $interface)
	fi

	local left_ip=""
	# Select the WAN link by using its IP as local IP
	if [ -n "$interface" ]; then
		left_ip=`interface_get_ipaddr "$interface"`
		if [ -z "$left_ip" ]; then
			left_ip="127.0.0.1"
		fi
	fi

	# Generate the config file
	(
		echo ""

		echo -e "connections {"
		echo ""

		echo -e "\tike-$id {"
		if [ "$keyexchange" = ikev1 ]; then
			echo -e "\t\tversion = 1"
			if [ "$aggressive" = 1 ]; then
				echo -e "\t\taggressive=yes"
			else
				echo -e "\t\taggressive=no"
			fi
		else
			echo -e "\t\tversion = 2"
		fi
		if [ "$left_ip" ]; then
			echo -e "\t\tlocal_addrs = $left_ip"
		fi
		if [ "$remote_ip" ]; then
			echo -e "\t\tremote_addrs = $remote_ip"
		fi
		echo -e "\t\trekey_time = 0s"
		echo -e "\t\tvips = 0.0.0.0"

		if [ "$authby" = "mschapv2" ]; then
			echo -e "\t\tsend_certreq = no"
			echo -e "\t\tsend_cert = always"
		fi

		echo -e "\t\tlocal-$id {"
		if [ "$authby" = secret ]; then
			echo -e "\t\t\tauth = psk"
		else
			echo -e "\t\t\tauth = eap-mschapv2"
			echo -e "\t\t\teap_id = $username"
		fi
		if [ "$leftid" ]; then
			echo -e "\t\t\tid = $leftid"
		fi
		echo -e "\t\t}"

		echo -e "\t\tremote-$id {"
		if [ "$authby" = secret ]; then
			echo -e "\t\t\tauth = psk"
		else
			echo -e "\t\t\tauth = pubkey"
		fi
		if [ "$rightid" ]; then
			echo -e "\t\t\tid = $rightid"
		fi
		echo -e "\t\t}"

		echo -e "\t\tchildren {"
			echo -e "\t\t\tike-$id {"
				echo -e "\t\t\t\tlocal_ts = 0.0.0.0/0"
				echo -e "\t\t\t\tremote_ts = 0.0.0.0/0"

				echo -e "\t\t\t\tset_mark_out = $mark"
				echo -e "\t\t\t\tif_id_in = %unique"
				echo -e "\t\t\t\tif_id_out = %unique"
				echo -e "\t\t\t\tupdown = /etc/ppp/ipsec_updown.sh"

				echo -e "\t\t\t\trekey_time = 0s"
				echo -e "\t\t\t\tdpd_action = restart"

			echo -e "\t\t\t}"
		echo -e "\t\t}"
		echo -e "\t}"
		echo -e "}"
		echo "include ../secrets.d/ike-secrets-$id.conf"
	) > /etc/swanctl/conf.d/ike-$id.conf

	# Prepare certificates and keys
	(
		echo "secrets {"
		if [ "$authby" = secret ]; then
			echo -e "\tike-c$id {"
			if [ -n "$rightid" ]; then
				echo -e "\t\tid = ${rightid}"
			else
				echo -e "\t\tid = $remote_ip"
			fi
			echo -e "\t\tsecret = \"$secret\""
			echo -e "\t}"
		else
			echo -e "\teap-c$id {"
				echo -e "\t\tid = \"$username\""
				echo -e "\t\tsecret = \"$passwd\""
			echo -e "\t}"
		fi
		echo -e "}"
	) > /etc/swanctl/secrets.d/ike-secrets-$id.conf

	# Remember the resolved IP for periodic checks
	if [ -n "$remote_addr" -o -n "$interface" ]; then
		echo "$id,$remote_addr,$remote_ip,$interface,$left_ip" > $RESOLVED_NAMES_DIR/ike-$id
	fi
}

__exec_swanctl_up()
{
	local __ids="$1"
	local id
	export STROKE_RECV_TIMEOUT=$IPSEC_CALL_TIMEOUT

	for id in ${__ids//,/ } ;do
		if [ ! -e "$IK_DIR_CACHE/ike_client/$id" ]; then
			continue
		fi
		local $(cat $IK_DIR_CACHE/ike_client/$id) 2>/dev/null
		[ "$enabled" = "no" ] && continue  
		__exec_create_conf
	done

	# Refresh configuration for StrongSwan
	swanctl --load-all >/dev/null 2>&1

	# Bring up each selected connection
	for id in ${__ids//,/ } ;do
		ipsec down ike-$id >/dev/null 2>&1
		/usr/lib/ipsec/stroke up-nb ike-$id  # nonblocking "ipsec up"
	done

}

__exec_swanctl_down()
{
	local __ids="$1"
	local id
	export STROKE_RECV_TIMEOUT=$IPSEC_CALL_TIMEOUT

	# Bring down each selected connection
	for id in ${__ids//,/ } ;do
		ipsec down ike-$id >/dev/null 2>&1
	done
	
	for id in ${__ids//,/ } ;do
		__delete_config_to_cache $id
		rm /etc/swanctl/conf.d/ike-$id.conf
		rm /etc/swanctl/secrets.d/ike-secrets-$id.conf
		rm $RESOLVED_NAMES_DIR/ike-$id
	done

	# Refresh configuration for StrongSwan
	swanctl --load-all >/dev/null 2>&1

	# Bring down each selected connection
	for id in ${__ids//,/ } ;do
		ipsec down ike-$id >/dev/null 2>&1
	done
}

__check_param_add()
{
	check_varl \
		'name		ifname_vpn' \
		'interface	== "auto" or ifname_wan' \
		'authby		== "mschapv2" or == "secret"' \
		'[ authby == "secret" ] && {
			secret		!= "" ;
		}' \
		'[ authby == "mschapv2" ] && {
			username	!= "" ;
			passwd		!= "" ;
		}'
}

__check_ikev2_id()
{
	local ikev2_id="$1"
	declare -A IKEVID

	local tmpfile=$(sql_config_get_list $IK_DB_CONFIG "select enabled,username,expires,ppptype from pppuser where ppptype='any' or ppptype='ike'")
	while read config; do
		[ "$config" ] || continue
		local $config
		[ "$enabled" = "no" ] && continue
		local now=$(date +%s)
		[ "$expires" != 0 -a "$expires" -le "$now" ] && continue
		IKEVID[$username]=1
	done << EOF
	$tmpfile
EOF

	for ikev2_id_one in ${ikev2_id//,/ }; do
		if [ "${IKEVID[$ikev2_id_one]}" = "1" ]; then
			Autoiecho openvpn_ipsec Ike_id_conflict $ikev2_id_one
			unset IKEVID
			return 1
		fi
	done

	unset IKEVID
	return 0
}

__clean()
{
	local ids=$(sqlite3 $IK_DB_CONFIG "select id from ike_client where enabled='yes'")
	__exec_swanctl_down "$ids"
	return 0
}

add()
{
	validate_parameters_or_die || exit 1
	__check_param_add || exit 1

	if [ "$interface" -a "$interface" != "auto" ]; then
		local tmp_ip=$(interface_get_ipaddr "$interface")
		if [ -z "$tmp_ip" ]; then
			Autoiecho openvpn_ipsec Interface_get_ipaddr_err $interface
			return 1
		fi
	fi

	if [ "$authby" = "mschapv2" ]; then
		__check_ikev2_id $rightid || exit 1
	fi
	local mtu=${mtu:-1400}

	local sql_param
	sql_param+=" name:str remote_addr:str authby:str interface:str mtu:int"
	sql_param+=" enabled:str keyexchange:str aggressive:str comment:str"
	sql_param+=" secret:str leftid:str rightid:str username:str passwd:str"

	if SqlMsg=$(sql_config_insert $IK_DB_CONFIG ike_client $sql_param); then
		id="$SqlMsg"
		__create_config_to_cache $id
		interface_get_name_to_cache_iked
		__exec_swanctl_up $id >/dev/null 2>&1
		echo "$id"
		return 0
	else
		echo "$SqlMsg"
		return 1
	fi
}

del()
{
	sqlite3 $IK_DB_CONFIG "delete from ike_client where id in ($id)"
	__exec_swanctl_down "$id"
	interface_get_name_to_cache_iked
	return 0
}

up()
{
	local ruleid="$id"
	local ikev2_id=""
	local tmpfile=$(sql_config_exec $IK_DB_CONFIG "select * from ike_client where enabled = 'no' and id in ($ruleid);update ike_client set enabled='yes' where id in ($ruleid)")
	while read config;do
		[ "$config" ] || continue
		local $config
		__create_config_to_cache $id
		if [ "$authby" = "mschapv2" ]; then
			ikev2_id+="${ikev2_id:+,}$rightid"
		fi
	done << EOF
	$tmpfile
EOF
	if [ "$ikev2_id" ]; then
		__check_ikev2_id $ikev2_id || exit 1
	fi
	__exec_swanctl_up "$ruleid"
	interface_get_name_to_cache_iked

	return 0
}

down()
{
	sqlite3 $IK_DB_CONFIG "update ike_client set enabled='no' where id in ($id)"
	__exec_swanctl_down "$id"
	interface_get_name_to_cache_iked
	return 0
}

edit()
{
	validate_parameters_or_die || exit 1
	__check_param_add || exit 1

	if [ "$interface" -a "$interface" != "auto" ]; then
		local tmp_ip=$(interface_get_ipaddr "$interface")
		if [ -z "$tmp_ip" ]; then
			Autoiecho openvpn_ipsec Interface_get_ipaddr_err $interface
			return 1
		fi
	fi

	if [ "$authby" = "mschapv2" ]; then
		__check_ikev2_id $rightid || exit 1
	fi

	local mtu=${mtu:-1400}
	res=$(sql_config_get_list $IK_DB_CONFIG "select * from ike_client where id=$id" prefix=old_)
	if [ "$res" = "" ];then
		return 0
	fi
	local $res	

	local sql_param
	sql_param+=" name:str remote_addr:str authby:str interface:str mtu:int"
	sql_param+=" enabled:str keyexchange:str aggressive:str comment:str"
	sql_param+=" secret:str leftid:str rightid:str username:str passwd:str"

	local newold_param=" name remote_addr authby interface enabled keyexchange aggressive comment secret leftid rightid username  passwd"
	if SqlMsg=$(sql_config_update $IK_DB_CONFIG ike_client "id=$id" $sql_param); then
		interface_get_name_to_cache_iked
		if [ "$enabled" = "yes" ];then
			__create_config_to_cache $id
			if ! NewOldVarl $newold_param; then
				__exec_swanctl_up $id >/dev/null 2>&1
			fi
		fi
		return 0
	else
		echo "$SqlMsg"
		return 1
	fi

	return 0
}

# $1: id
__is_conn_running()
{
	export STROKE_RECV_TIMEOUT=$IPSEC_CALL_TIMEOUT
	if ipsec status ike-$1 | grep '\<ESTABLISHED\>' -A2 | grep -E '\<INSTALLED\>.*\<TUNNEL\>|\<REKEYED\>.*\<TUNNEL\>' >/dev/null; then
		return 0
	else
		return 1
	fi
}

# No argument
resolve_flush()
{
	#### Check connection health, domain resolve change, local IP change and do necessary reloads
	local f vpn_ids= l2tpc_ids=

	for f in $RESOLVED_NAMES_DIR/ike-*; do
		[ -f "$f" ] || continue
		local id=`awk -F, '{print $1}' $f`
		local remote_addr=`awk -F, '{print $2}' $f`
		local remote_ip=`awk -F, '{print $3}' $f`
		local interface=`awk -F, '{print $4}' $f`
		local left_ip=`awk -F, '{print $5}' $f`
		if [ -n "$remote_addr" ]; then
			# Detect connection health
			if ! __is_conn_running $id; then
				vpn_ids="$vpn_ids$id,"
				continue
			fi
			# Detect domain name resolve change
			local new_ip=`try_get_ip_of_address "$remote_addr"`
			if [ -n "$new_ip" -a  "$new_ip" != "$remote_ip" ]; then
				vpn_ids="$vpn_ids$id,"
				continue
			fi
		fi
		if [ -n "$interface" ]; then
			# Detect local IP change
			local new_ip=`interface_get_ipaddr "$interface"`
			if [ -n "$new_ip" -a "$new_ip" != "$left_ip" ]; then
				vpn_ids="$vpn_ids$id,"
				continue
			fi
		fi
	done

	# Reload IPsec VPN connections
	if [ -n "$vpn_ids" ]; then
		__exec_swanctl_up "$vpn_ids"
	fi

	#### Log size safety check
	local charon_pid=$(cat /var/run/charon.pid)
	local logsize=$(ls -l $CHARON_LOG_FILE | awk '{print $5}')
	[ "$logsize" -gt "$CHARON_LOG_FILE_MAXSIZE" ] && {
		kill -HUP $charon_pid
	}

	return 0
}

EXPORT()
{
	Include import_export.sh
	local format=${format:-txt}
	if errmsg=$(export_txt $IK_DB_CONFIG ike_client $format $IK_DIR_EXPORT/ike_client.$format) ;then
		echo "ike_client.$format"
		return 0
	else
		echo "$errmsg"
		return 1
	fi
}

IMPORT()
{
	Include import_export.sh
	if errmsg=$(import_txt $IK_DB_CONFIG ike_client $IK_DIR_IMPORT/$filename "$append" __check_param_add __clean) ;then
		init >/dev/null 2>/dev/null &
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


__implant_lua_code()
{
cat -<<EOF
	local __iked_t = {}
	local iked_dir = "/tmp/iktmp/iked/"
	local fp = io.popen("ls " ..iked_dir)
	if fp then
		for file in fp:lines() do
			local f = io.open(iked_dir .. file)
			if f then
				local t = {}
				__iked_t[file] = t
				for line in f:lines() do
					local key, val = line:match("([^=]+)=(.*)")
					if key then t[key] = val end
				end
				f:close()
			end
		end
		fp:close()
	end

	function create_fc(col, typ, key)
		ikdb:create_function(col,1,
		function (ctx, name)
			local res
			local stat_info = __iked_t[name]
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

	create_fc("ip_addr", "text", "iked_ip_addr")

EOF
}

__show_total()
{
	local __sql_implant_code__=$(__implant_lua_code)
	local total=$(sqlite3 $IK_DB_CONFIG "select count() from ike_client $__filter")
	json_append __json_result__ total:int
}

__show_data()
{
	local __sql_implant_code__=$(__implant_lua_code)
	local sql_show="select *, ip_addr(name) ip_addr from ike_client $__where"
	local data=$(sql_config_get_json $IK_DB_CONFIG "$sql_show")
	json_append __json_result__ data:json
}

__show_log()
{
	local log=$(tail -80 $CHARON_LOG_FILE)
	local log=${log//$LINE_N/\\n}
	json_append __json_result__ log:str
}

__show_interface() {
	local interface=$(interface_get_ifname_comment_json wan auto)
	json_append __json_result__ interface:json
}

# Generate a certificate/private key pair
# Implicit parameters:
#  leftid=??
__show_create_certs()
{
	leftid=${leftid//@}
	if [ ! "$leftid" ];then
		Autoiecho openvpn_ipsec Missing_local_ID
		return 1
	fi

	# -------------------------------------------------
	local t=/tmp/t.$$
	mkdir -p $t
	# Generate private key
	openssl genrsa -out $t/cert.key 2048 >/dev/null 2>&1
	# Generate signing request file
	openssl req -new -key $t/cert.key -out $t/cert.csr \
		-subj "/C=CN/O=iKuai/CN=$leftid" >/dev/null 2>&1
	# Self-sign the certificate
	openssl x509 -req -days 3650 -sha256 -in $t/cert.csr \
		-signkey $t/cert.key -out $t/cert.crt >/dev/null 2>&1
	local leftcert=$(cat $t/cert.crt)
	local privatekey=$(cat $t/cert.key)
	rm -rf $t
	# -------------------------------------------------

	local leftcert=${leftcert//$LINE_N/\\n}
	local privatekey=${privatekey//$LINE_N/\\n}
	json_append __json_result__ leftcert:str privatekey:str
}

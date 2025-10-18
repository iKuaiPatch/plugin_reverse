#!/bin/bash /etc/ikcommon

Include lock.sh, check.sh, interface.sh, iproute.sh, crond.sh

I18nload openvpn_ipsec.json

I18N_LOCAL_PREFIX="i18n_openvpn_ipsec_"
CHARON_LOG_FILE=/etc/log/ipsec-vpn/charon_log
IPSEC_CALL_TIMEOUT=4
# maxsize 2MB
CHARON_LOG_FILE_MAXSIZE=2097152
RESOLVED_NAMES_DIR=/var/run/ipsec-vpn/resolved
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

#
# Check the predefined variables (if set):
#  authby, leftcert, rightcert, privatekey, ...
#
validate_parameters_or_die()
{
	if [ "$authby" = "secret" ]; then
		[ -n "$secret" ] || die_with 2 "`LIecho Missing_shared_secret`"
	elif [ "$authby" = "pubkey" -o "$authby" = "mschapv2" ]; then
		[ -n "$leftcert" ] || die_with 2 "`LIecho Missing_local_certificate`"
		[ -n "$privatekey" ] || die_with 2 "`LIecho Missing_private_key`"

		# Validate certificate text format
		unescape_multilined "$leftcert" | openssl x509 -text -noout >/dev/null 2>&1 ||
			die_with 2 "`LIecho Invalid_local_certificate`"
		unescape_multilined "$privatekey" | openssl rsa -text -noout >/dev/null 2>&1 ||
			die_with 2 "`LIecho Invalid_private_key`"

		# Check if local certificate matches local private key
		local sum1=`unescape_multilined "$leftcert" | openssl x509 -noout -modulus | openssl md5`
		local sum2=`unescape_multilined "$privatekey" | openssl rsa -noout -modulus | openssl md5`
		[ "$sum1" = "$sum2" ] || die_with 2 "`LIecho Certificate_and_private_key_do_not_match`"

		# Ensure certificates have the 'CN' (common name) subject
		local __left_subj=`unescape_multilined "$leftcert" | openssl x509 -noout -subject`
		local left_cn=`expr "$__left_subj" : '.*\/CN=\([^/]\+\)'`
		[ -n "$left_cn" ] || die_with 2 "`LIecho No_CN_subject_contained_in_local_certificate`"
		[ "$left_cn" = "$leftid" ] || die_with 2 "`LIecho No_Match_subject_local_certificate`"
	else
		die_with 2 "`LIecho Invalid_authentication_type`"
	fi
}

boot()
{
	mkdir -p $IK_DIR_CACHE/ike_server
	
	sqlite3 /var/db/leases.db "delete from leases where interface='lo'"
	certs_init
	init
}

init()
{
	__init_connections
}

vrrp_init()
{
	__clean
	sqlite3 $IK_DB_CONFIG "delete from ike_server"	
	sqlite3 $IK_DIR_LOG/vrrp/conf/config.db ".dump ike_server" |grep "^INSERT"| sqlite3 $IK_DB_CONFIG
	init
}

certs_init()
{
	__set_cacerts /etc/swanctl/x509ca/ca-certificates /etc/ssl/certs/ca-certificates.crt
	cp /etc/swanctl/ikca/rootCA.crt /etc/swanctl/x509ca
}


# Try to bring up all enabled connections
__init_connections()
{
	__create_config_to_cache
	local $(sql_config_get_list $IK_DB_CONFIG "select * from ike_server")

	[ "$enabled" = "yes" ] || return 0

	__unset_iface_addr $addrpool >/dev/null 2>&1
	if [ "$authby" = "mschapv2" ]; then
		__set_iface_addr $addrpool >/dev/null 2>&1
	fi
	$IK_DIR_SCRIPT/dhcp_server.sh restart >/dev/null 2>&1 &

	__exec_create_conf >/dev/null 2>&1
	__exec_swanctl_reload >/dev/null 2>&1

	return 0
}

__create_config_to_cache() {
	sql_config_get_list $IK_DB_CONFIG "select * from ike_server" > $IK_DIR_CACHE/ike_server/config.$$
	mv $IK_DIR_CACHE/ike_server/config.$$ $IK_DIR_CACHE/ike_server/config
}

__delete_config_to_cache()
{
	rm -f $IK_DIR_CACHE/ike_server/config
}

__set_cacerts()
{
	local filepath="$1"
	local certfile="$2"
lua<<EOF
	local wfile="$filepath"
	local cafile="$certfile"

	function write_cert(data, file)
		local file = io.open(file, "w")
		if file then
			file:write(data)
			io.close(file)
		end
	end

	local fp = io.open(cafile, "r")
	if fp then
		local data = fp:read("*a")

		local i = 1
		for k in string.gmatch(data, "(%-+BEGIN CERTIFICATE%-+[^- ]+%-+END CERTIFICATE%-+)") do
			local filename = wfile .. i .. ".crt"
			write_cert(k, filename)
			i = i + 1
		end
		io.close(fp)
	end

EOF
}

__exec_create_conf()
{
	# Any failure here indicates bugs in validate_parameters_or_die()!!!

	if [ "$authby" = secret ]; then
		[ -n "$secret" ] || { echo "*** No shared secret" >&2; return 1; }
	else
		[ -n "$leftcert" ] || { echo "*** No 'leftcert'" >&2; return 1; }
		[ -n "$privatekey" ] || { echo "*** No private key" >&2; return 1; }
	fi

	[ "$interface" = auto ] && local interface=""

	local sa_mark=$((IPSEC_BASE_MARK+id))

	# Generate the config file
	(
		echo ""

		echo -e "connections {"
		echo ""

		echo -e "\tike-server {"
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
		echo -e "\t\tproposals = default,aes192gcm16-aes128gcm16-prfsha256-ecp256-ecp521,aes192-sha256-modp1024-modp3072"
		echo -e "\t\trekey_time = 0h"
		if [ "$authby" = "mschapv2" ]; then
			echo -e "\t\tsend_certreq = no"
			echo -e "\t\tsend_cert = always"
		fi
		echo -e "\t\tunique = never"
		if [ "$authby" = "mschapv2" ]; then
			echo -e "\t\tpools = dhcp"
		else
			echo -e "\t\tpools = primary-pool-ipv4"
		fi
		

		echo -e "\t\tlocal-server {"
		if [ "$authby" = secret ]; then
			echo -e "\t\t\tauth = psk"
		elif [ "$authby" = "mschapv2" ]; then
			echo -e "\t\t\tcerts = left-server.crt"
		else
			echo -e "\t\t\tcerts = left-server.crt"
		fi
		if [ "$leftid" ]; then
			echo -e "\t\t\tid = $leftid"
		fi
		echo -e "\t\t}"

		echo -e "\t\tremote-server {"
		if [ "$authby" = secret ]; then
			echo -e "\t\t\tauth = psk"
		elif [ "$authby" = "mschapv2" ]; then
			echo -e "\t\t\tauth = eap-mschapv2"
			echo -e "\t\t\teap_id = %any"
			
		else
			echo -e "\t\t\tcerts = right-server.crt"
		fi
		if [ "$rightid" ]; then
			echo -e "\t\t\tid = $rightid"
		fi
		echo -e "\t\t}"

		echo -e "\t\tchildren {"
			echo -e "\t\t\tike-server {"
				echo -e "\t\t\t\tlocal_ts = 0.0.0.0/0"
				echo -e "\t\t\t\tremote_ts = $addrpool"

				echo -e "\t\t\t\tif_id_in = %unique"
				echo -e "\t\t\t\tif_id_out = %unique"
				echo -e "\t\t\t\tupdown = /etc/ppp/ipsec_updown.sh"

				echo -e "\t\t\t\trekey_time = 0s"
				echo -e "\t\t\t\tdpd_action = clear"
				echo -e "\t\t\t\tesp_proposals = aes192gcm16-aes128gcm16-prfsha256-ecp256-modp3072,aes192-sha256-ecp256-modp1024-modp3072,default"

			echo -e "\t\t\t}"
		echo -e "\t\t}"
		echo -e "\t}"
		echo -e "}"

	echo -e "pools {"
	echo -e "\tprimary-pool-ipv4 {"
	echo -e "\t\taddrs = $addrpool"
	echo -e "\t\tdns = $dns1, $dns2"
	echo -e "\t}"
	echo -e "}"
	) > /etc/swanctl/conf.d/ike-server.conf

	# Prepare certificates and keys
	(
		echo "secrets {"
		if [ "$authby" = secret ]; then
			echo -e "\tike-server {"
			if [ -n "$rightid" ]; then
				echo -e "\t\tid = ${rightid}"
			fi
			echo -e "\t\tsecret = \"$secret\""
			echo -e "\t}"
		else
			# Store the private key
			unescape_multilined "$privatekey" > /etc/swanctl/private/left-server.key
			# Store both certificates
			unescape_multilined "$leftcert" > /etc/swanctl/x509/left-server.crt
			__set_cacerts /etc/swanctl/x509ca/left-server /etc/swanctl/x509/left-server.crt
			if [ "$rightcert" ]; then
				unescape_multilined "$rightcert" > /etc/swanctl/x509/right-server.crt
			fi

			if [ "$privatekey" ]; then
				echo -e "\tprivate-server {"
					echo -e "\t\tfile = left-server.key"
				echo -e "\t}"
			fi
		fi
		echo -e "}"
		echo "include ../secrets.d/server-eap.conf"
	) >> /etc/swanctl/conf.d/ike-server.conf

		
}


__exec_swanctl_reload()
{
	export STROKE_RECV_TIMEOUT=$IPSEC_CALL_TIMEOUT

	swanctl --load-all >/dev/null 2>&1
}

__exec_swanctl_down()
{
	export STROKE_RECV_TIMEOUT=$IPSEC_CALL_TIMEOUT
	# Delete their IPsec config
	rm -f /etc/swanctl/conf.d/ike-server.conf

	# Refresh configuration for StrongSwan
	swanctl --load-all >/dev/null 2>&1
}

__check_param_save()
{
	check_varl \
		'addrpool      ipmaskb' \
		'authby		== "mschapv2" or == "secret" or == "pubkey"' \
		'[ authby == "secret" ] && {
			secret		!= "" ;
		}' \
		'[ authby == "pubkey" ] && {
			leftid		!= "" ;
			privatekey	!= "" ;
			leftcert	!= "" ;
		}'
}

__clean()
{
	__exec_swanctl_down
	return 0
}

__add_iface_dhcp()
{
	local enabled="yes" interface="lo" addr_pool="${POOLBEGIN}-${POOLEND}" netmask=$NETMASK
	local gateway=$POOLBEGIN dns1="$dns1" dns2="$dns2" check_addr_valid=0
	local sql_param="enabled:str interface:str addr_pool:str netmask:str gateway:str dns1:str dns2:str check_addr_valid:int"

	sql_config_insert $IK_DB_CONFIG dhcp_server $sql_param >/dev/null 2>&1
}

__del_iface_dhcp()
{
	sqlite3 $IK_DB_CONFIG "delete from dhcp_server where interface='lo'"
}

__set_iface_addr()
{
	local pool="$1"
	if [ "$pool" ]; then
		local $(/usr/ikuai/script/ipcalc.sh $pool)
		ip addr add $POOLBEGIN/32 dev lo scope host
		__add_iface_dhcp
	fi
}

__unset_iface_addr()
{
	local pool="$1"
	if [ "$pool" ]; then
		local $(/usr/ikuai/script/ipcalc.sh $pool)
		__del_iface_dhcp
		ip addr del $POOLBEGIN/32 dev lo scope host
	fi
}

resolve_flush()
{
	local start_time=$(date +%s)
	local end_time=$((start_time+3600))
	local sql=""
	local filename="/tmp/ike_dhcp"
	echo "BEGIN TRANSACTION;" > ${filename}.$$
	for config in $(ls /tmp/iktmp/ikec/); do
		[ "$config" ] || continue
		local $(cat /tmp/iktmp/ikec/$config)
		echo "update leases set start_time=$start_time,end_time=$end_time where ip_addr='$ikec_remote_addr' and interface='lo';" >> ${filename}.$$
	done
	echo "COMMIT;" >> ${filename}.$$

	sqlite3 /var/db/leases.db < ${filename}.$$
	rm ${filename}.$$
}

save()
{
	validate_parameters_or_die || exit 1
	__check_param_save || exit 1

	res=$(sql_config_get_list $IK_DB_CONFIG "select * from ike_server" prefix=old_)
	if [ "$res" = "" ];then
		return 0
	fi
	local $res	

	local sql_param
	local mtu=${mtu:-1400}
	sql_param+=" name:str authby:str addrpool:str share_deny:int mtu:int"
	sql_param+=" enabled:str keyexchange:str aggressive:str dns1:str dns2:str"
	sql_param+=" secret:str leftid:str rightid:str privatekey:str leftcert:str"

	if SqlMsg=$(sql_config_update $IK_DB_CONFIG ike_server "id=$id" $sql_param); then
		__create_config_to_cache $id
		if ! NewOldVarl enabled name authby addrpool dns1 dns2 secret leftid rightid  privatekey leftcert; then

			Include timersql.sh auth/authcntl.sh
			#kick all ike_client
			if res=$(timersql_exec "select * from authuser where ppptype='ike'; delete from authuser where ppptype='ike'") ;then
				echo "$res" | authcntl_kick ppp_online_kick >/dev/null 2>&1
			fi

			__unset_iface_addr $old_addrpool >/dev/null 2>&1
			if [ "$enabled" = "yes" ];then
				if [ "$authby" = "mschapv2" ]; then
					__set_iface_addr $addrpool >/dev/null 2>&1
				fi
				__exec_create_conf >/dev/null 2>&1
				__exec_swanctl_reload >/dev/null 2>&1
			else
				__exec_swanctl_down >/dev/null 2>&1
			fi
		fi
		if ! NewOldVarl enabled addrpool authby; then
			$IK_DIR_SCRIPT/dhcp_server.sh restart >/dev/null 2>&1 &
		fi
		return 0
	else
		echo "$SqlMsg"
		return 1
	fi

	return 0
}

EXPORT()
{
	Include import_export.sh
	local format=${format:-txt}
	if errmsg=$(export_txt $IK_DB_CONFIG ike_server $format $IK_DIR_EXPORT/ipsec_server.$format) ;then
		echo "ike_server.$format"
		return 0
	else
		echo "$errmsg"
		return 1
	fi
}

IMPORT()
{
	Include import_export.sh
	if errmsg=$(import_txt $IK_DB_CONFIG ike_server $IK_DIR_IMPORT/$filename "$append" __check_param_save __clean) ;then
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


__show_total()
{
	local total=$(sqlite3 $IK_DB_CONFIG "select count() from ike_server $__filter")
	json_append __json_result__ total:int
}

__show_data()
{
	local sql_show="select * from ike_server $__where"
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


__show_create_certs()
{
	leftid=${leftid//@}
	if [ -z "$leftid" ];then
		Autoiecho openvpn_ipsec Missing_local_ID
		return 1
	fi

	local t=/tmp/t.$$
	mkdir -p $t

	openssl genrsa -out $t/cert.key 2048  >/dev/null 2>&1
	openssl req -new -subj "/CN=$leftid" \
		-reqexts SAN \
		-config <(cat /etc/swanctl/ikca/mycert.conf <(printf "[SAN]\nsubjectAltName=DNS:$leftid")) \
		-key $t/cert.key -out $t/cert.csr  >/dev/null 2>&1
	openssl x509 -req -CA /etc/swanctl/ikca/rootCA.crt -CAkey /etc/swanctl/ikca/rootCA.key -CAcreateserial \
		-sha256 -days 3650 -extfile <(printf "subjectAltName=DNS:$leftid") \
		-in $t/cert.csr -out $t/cert.crt  >/dev/null 2>&1

	local leftcert=$(cat $t/cert.crt)
	local privatekey=$(cat $t/cert.key)
	local leftid=$leftid

	rm -rf $t
	# -------------------------------------------------

	local leftcert=${leftcert//$LINE_N/\\n}
	local privatekey=${privatekey//$LINE_N/\\n}
	json_append __json_result__ leftcert:str privatekey:str leftid:str
}

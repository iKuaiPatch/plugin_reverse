#!/bin/bash /etc/ikcommon
. /etc/mnt/plugins/configs/config.sh
script_path=$(readlink -f "${BASH_SOURCE[0]}")
plugin_dir=$(dirname "$script_path")

start() {

	if [ ! -f $EXT_PLUGIN_CONFIG_DIR/tailscale/tailscale ]; then
		return
	fi

	if [ ! -f /usr/sbin/tailscale ]; then
		mkdir /sbin/data -p
		chmod +x $plugin_dir/../bin/tailscale
		ln -s $plugin_dir/../bin/tailscale /usr/sbin/tailscale
		ln -s $plugin_dir/../bin/tailscaled /usr/sbin/tailscaled
	fi

	tailscaled --port 41641 --state $EXT_PLUGIN_CONFIG_DIR/tailscale/tailscaled.state >/dev/null &
	iptables -I FORWARD -i tailscale0 -j ACCEPT
	iptables -I FORWARD -o tailscale0 -j ACCEPT
	iptables -t nat -I POSTROUTING -o tailscale0 -j MASQUERADE

	tailscale=$(iptables -vnL FORWARD --line-number | grep "tailscale" | wc -l)
	if [ $tailscale -eq 0 ]; then
		iptables -I FORWARD -i tailscale0 -j ACCEPT
		iptables -I FORWARD -o tailscale0 -j ACCEPT
		iptables -t nat -I POSTROUTING -o tailscale0 -j MASQUERADE
	fi

}

tailscale_start() {

	if killall -q -0 tailscaled; then
		killall tailscaled

		if killall -q -0 tailscale; then
			killall tailscale
		fi
		return
	fi

	if [ ! -f $EXT_PLUGIN_CONFIG_DIR/tailscale/tailscale ]; then

		mkdir -p $EXT_PLUGIN_CONFIG_DIR/tailscale
		echo "1" >$EXT_PLUGIN_CONFIG_DIR/tailscale/tailscale

	fi

	start

}

stop() {
	killall tailscaled
	tailscale=$(iptables -vnL FORWARD --line-number | grep "tailscale" | wc -l)
	if [ $tailscale -gt 0 ]; then
		iptables -D FORWARD -i tailscale0 -j ACCEPT
		iptables -D FORWARD -o tailscale0 -j ACCEPT
		iptables -D nat -I POSTROUTING -o tailscale0 -j MASQUERADE
	fi
	rm $EXT_PLUGIN_CONFIG_DIR/tailscale
}

show() {
	Show __json_result__
}

__show_status() {
	local status=0

	if killall -q -0 tailscaled; then
		local status=1
	else
		local status=0
		json_append __json_result__ status:int
		return
	fi

	advertiseRoutes=$(cat $EXT_PLUGIN_CONFIG_DIR/tailscale/advertiseRoutes)
	output=$(tailscale status --json)

	# 执行一次命令并将输出存储在变量中

	# 提取字段
	TailscaleIPs=$(echo "$output" | jq -r '.TailscaleIPs | join(", ")')
	BackendState=$(echo "$output" | jq -r '.BackendState')
	AuthURL=$(echo "$output" | jq -r '.AuthURL')
	DisplayName=$(echo "$output" | jq -r '.User | to_entries[] | select(.value.ID != null) | .value.DisplayName')
	# 分别提取 IPv4 和 IPv6
	IPv4=$(echo "$TailscaleIPs" | cut -d, -f1 | xargs)
	IPv6=$(echo "$TailscaleIPs" | cut -d, -f2 | xargs)
	Name=$(echo "$output" | jq -r '.Self.HostName')

	if [ "$BackendState" == "NeedsLogin" ]; then

		if [ -z "$AuthURL" ]; then
			tailscale up >/dev/null &
			output=$(tailscale status --json)
			AuthURL=$(echo "$output" | jq -r '.AuthURL')
		fi

	fi

	server=$(cat $EXT_PLUGIN_CONFIG_DIR/tailscale/server)
	authkey=$(cat $EXT_PLUGIN_CONFIG_DIR/tailscale/authkey)

	json_append __json_result__ status:int
	json_append __json_result__ TailscaleIPs:str
	json_append __json_result__ BackendState:str
	json_append __json_result__ AuthURL:str
	json_append __json_result__ DisplayName:str
	json_append __json_result__ IPv4:str
	json_append __json_result__ IPv6:str
	json_append __json_result__ Name:str
	json_append __json_result__ advertiseRoutes:str
	json_append __json_result__ server:str
	json_append __json_result__ authkey:str

}

update_config() {

	if [ -n "$server" ]; then
		echo "$server" >$EXT_PLUGIN_CONFIG_DIR/tailscale/server
		tailscale up --reset --login-server "$server"
	fi

	if [ -n "$authkey" ]; then
		echo "$authkey" >$EXT_PLUGIN_CONFIG_DIR/tailscale/authkey
		tailscale up --reset --authkey "$authkey"
	fi

	if [ -n "$dev_name" ]; then
		tailscale up --reset --hostname $dev_name
	fi

	if [ -n "$accept_routes" ]; then
		echo "$accept_routes" >$EXT_PLUGIN_CONFIG_DIR/tailscale/advertiseRoutes
		tailscale up --reset --advertise-routes "$accept_routes"
	fi

}

logout() {
	tailscale logout
}

case "$1" in
start)
	start
	;;
stop)
	stop
	;;
*) ;;
esac

#!/bin/bash 
FEATURE_ID=5
ENABLE_FEATURE_CHECK=1

# clash连路表
# iptables -t nat -L shellcrash -n -v --line-numbers
# iptables -t nat -L shellcrash_dns -n -v --line-numbers
# iptables -t mangle -L shellcrash_mark -n -v --line-numbers
# iptables -w -t mangle -D shellcrash_mark 1
# iptables -t mangle -D shellcrash_mark -p tcp --dport 53 -j RETURN
# iptables -t mangle -D shellcrash_mark -p udp --dport 53 -j RETURN
# ip6tables -t nat -L shellcrash -n -v --line-numbers
# ip6tables -t nat -L shellcrash_dns -n -v --line-numbers
# ip6tables -t mangle -L shellcrash_mark -n -v --line-numbers
# ip6tables -D INPUT -p tcp --dport 7890 -j REJECT --reject-with icmp6-port-unreachable
# ip6tables -t mangle -L shellcrashv6_mark -n -v --line-numbers
# ip6tables -t nat -L shellcrashv6 -n -v --line-numbers
# shellcrashv6_mark
# iptables -I FORWARD -i lan1 -o lan1 -j DROP

. /etc/release
. /usr/ikuai/include/interface.sh
. /etc/mnt/plugins/configs/config.sh

PLUGIN_NAME="socks5"
CHROOTDIR=$(chrootmgt get_chroot_dir)
CRASHDIR=$EXT_PLUGIN_INSTALL_DIR/$PLUGIN_NAME/bin
LOGFILE=$EXT_PLUGIN_LOG_DIR/$PLUGIN_NAME/log.txt
ADV_SETTINGFILE=$CRASHDIR/configs/adv_settings.sh
. $CRASHDIR/configs/ShellCrash.cfg

debug() {
	debuglog=$([ -s /tmp/debug_on ] && cat /tmp/debug_on || echo -n /tmp/debug.log)
	if [ "$1" = "clear" ]; then
		rm -f $debuglog && return
	fi

	if [ -f /tmp/debug_on ]; then
		TIME_STAMP=$(date +"%Y%m%d %H:%M:%S")
		echo "[$TIME_STAMP]: PL> $1" >>$debuglog
	fi
}

boot() {

	isAdv=$(authtool check-plugin 6 >/dev/null 2>&1 && echo "true" || echo "false")

	# 设置最大打开文件数
	memsize=$(awk '/MemTotal/{print $2}' /proc/meminfo)
	if [ "$isAdv" != "true" ]; then
		sysctl -w fs.file-max=15000 >/dev/null 2>&1
		ulimit -n 10240 >/dev/null 2>&1
	else
		if [ "$memsize" -gt 3800000 ]; then
			sysctl -w fs.file-max=655350 >/dev/null 2>&1
			ulimit -n 327680 >/dev/null 2>&1
		elif [ "$memsize" -gt 1000000 ]; then
			sysctl -w fs.file-max=150000 >/dev/null 2>&1
			ulimit -n 100000 >/dev/null 2>&1
		else
			sysctl -w fs.file-max=65535 >/dev/null 2>&1
			ulimit -n 32768 >/dev/null 2>&1
		fi
	fi

	if [ "$isAdv" != "true" ] || [ ! -f "$ADV_SETTINGFILE" ]; then
		printf '' >"$ADV_SETTINGFILE"
	fi

	defaultAdvSettings=(
		"denyLocalNet=0"
		"denyVideoData=0"
		"tcpOptimization=0"
		"connTestSite=4"
		"disableUdp=0"
		"domainSniffing=0"
		"dnsmode=\"none\""
		"rejectQUIC=0"
		"bypassCNIP=0"
		"networkMonitoring=0"
		"dnsResolveNodes=\"\""
	)

	for advSetting in "${defaultAdvSettings[@]}"; do
		kname="${advSetting%%=*}"
		if ! grep -q "^$kname=" "$ADV_SETTINGFILE" 2>/dev/null; then
			echo "$advSetting" >>"$ADV_SETTINGFILE"
		fi
	done

  . "$ADV_SETTINGFILE"
}

# 清理文件头部的空字节（0x00），防止文件被识别为二进制文件
sanitize_file() {
  local target="$1"
  local dir tmp

  dir="$(dirname "$target")"
  tmp="$(mktemp "$dir/.tmp.XXXXXX")" || return 1

  if tr -d '\000' <"$target" >"$tmp" 2>/dev/null; then
    mv -f "$tmp" "$target"
  else
    rm -f "$tmp"
    return 1
  fi
}


boot

start() {

	firmwareVer=$(authtool version)
	if [ "$firmwareVer" -lt "202507100000" ]; then
		echo "当前定制固件版本过低！需升级获得最佳安全及稳定性, 请至作者云盘下载最新版固件！"
		return 1
	fi

	if [ -d "$EXT_PLUGIN_INSTALL_DIR/clash" ]; then
		echo "本插件和“小猫咪”插件不兼容！请先卸载小猫咪再启动本插件！"
		return 1
	fi

	debug "开始启动SK5服务..."
  sanitize_file "$ADV_SETTINGFILE"
  sanitize_file "$CRASHDIR/yamls/rules.yaml"
  sanitize_file "$CRASHDIR/yamls/proxies.yaml"

	handel_adv_settings
	monitor_tcp_traffic start

	pidof CrashCore >/dev/null && stop
	startCrashCore

	# 检查启动是否成功
	i=1
	db_port=$(cat $CRASHDIR/configs/ShellCrash.cfg | grep "hostdir" | cut -d ':' -f2 | cut -d '/' -f1)
	while [ -z "$test" -a "$i" -lt 5 ]; do
		sleep 1
		test=$(curl -s http://127.0.0.1:${db_port}/configs --header "Authorization: Bearer $secret" | grep -o port)
		[ -n "$test" ] && break
		i=$((i + 1))
	done

	local ret=1
	if [ -n "$test" -o -n "$(pidof CrashCore)" ]; then
		ret=0
		patch_all_config || ret=1
		reload_config || ret=1
		add_guard_task || ret=1
		clear_connections
		patch_custom_iprules &
	fi

	if [ "$ret" -eq "0" ]; then
		touch $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autostart
		debug "SK5服务启动成功"
		echo "启动成功"
		return 0
	else
		debug "SK5服务启动失败"
		echo "服务启动失败, 请检查订阅地址格式、配置文件以及网络连接状态！"
		return 1
	fi

}
stop() {

	pidof CrashCore >/dev/null || return 0

	stopCrashCore
	monitor_tcp_traffic stop
	remove_guard_task

	Vmen=0 success=0
	while true; do
		sleep 1
		pidof CrashCore >/dev/null || {
			success=1
			break
		}

		Vmen=$((Vmen + 1))
		[ $Vmen -gt 30 ] && break
	done

	if [ $success -eq 1 ]; then
		debug "SK5服务已停止"
		rm $CHROOTDIR/tmp/ShellCrash -rf
		rm $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autostart
		return 0
	else
		debug "SK5服务停止失败"
		echo "停止Clash失败！"
		return 1
	fi
}
startCrashCore() {

	# 修复cn_ip库太大导致ipset创建失败的问题（ip库地址 https://github.com/kiddin9/china_ip_list）
	sed -i 's/hashsize 10240 maxelem 10240/hashsize 16384 maxelem 32768/g' $CRASHDIR/start.sh

	# 生成ip_filter白名单配置文件
	if grep -qE '([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?' "$CRASHDIR/yamls/rules.yaml"; then
		awk -F'[,]' '{print $2}' $CRASHDIR/yamls/rules.yaml | sort -u >$CRASHDIR/configs/ip_filter
	else
		# 插入一条保留IP地址（内网通常不会有）到白名单，初始化白名单相关配置
		echo "203.0.113.1" >$CRASHDIR/configs/ip_filter
	fi

	# 不加载rules和proxies配置，因为启动后还需要处理后重新加载
	mv -f $CRASHDIR/yamls/rules.yaml $CRASHDIR/yamls/rules.yaml.bk
	mv -f $CRASHDIR/yamls/proxies.yaml $CRASHDIR/yamls/proxies.yaml.bk

	# 阻止Tun内核劫持全部dns请求,让远程DNS有机会接管, 必须在启动前修改好才生效
	if [ "$dnsmode" = "remotedns" ]; then
		if ! grep -q "dns-hijack" $CRASHDIR/start.sh; then
			sed -i 's/auto-detect-interface: false/auto-detect-interface: false, dns-hijack: [tcp:\/\/203.0.113.1:53]/g' $CRASHDIR/start.sh
		fi
	fi

	# Chroot下启动CrashCore
	ps | grep socks5/bin/menu.sh | grep -v grep | awk '{print $1}' | xargs -r kill -9
	chrootmgt run "$CRASHDIR/menu.sh -s start >/dev/null"

	mv -f $CRASHDIR/yamls/rules.yaml.bk $CRASHDIR/yamls/rules.yaml
	mv -f $CRASHDIR/yamls/proxies.yaml.bk $CRASHDIR/yamls/proxies.yaml

	# 还原start.sh配置
	sed -i 's/, dns-hijack: \[tcp:\/\/203\.0\.113\.1:53\]//g' $CRASHDIR/start.sh
}
stopCrashCore() {
	ps | grep socks5/bin/menu.sh | grep -v grep | awk '{print $1}' | xargs -r kill -9
	chrootmgt run "$CRASHDIR/menu.sh -s stop >/dev/null"
}
restart() {
	local ret=0
	if killall -q -0 CrashCore; then

		stopCrashCore
		startCrashCore

		patch_all_config || ret=1
		reload_config || ret=1
		clear_connections
		patch_custom_iprules &
	fi

	if [ $ret -eq 0 ]; then
		debug "SK5服务已重启"
		return 0
	else
		debug "SK5服务重启失败"
		return 1
	fi
}

clear_connections() {

	# if [ -n "${1}" ]; then
	# 	address_ip="${1}"
	# 	conntrack -D -s "${address_ip%/*}" >/dev/null 2>&1
	# else
	# 	for address_ip in $(cat $CRASHDIR/configs/ip_filter); do
	# 		conntrack -D -s "${address_ip%/*}" >/dev/null 2>&1
	# 	done
	# fi
	# return 0

	pidof CrashCore >/dev/null 2>&1 || return 0
	if [ -n "$1" ]; then
		SOURCE_IP=${1%/*}
		connections=$(curl -s "http://127.0.0.1:9999/connections" --header "Authorization: Bearer $secret")
		connection_ids=$(echo "$connections" | jq -r --arg ip "$SOURCE_IP" '.connections[] | select(.metadata.sourceIP == $ip) | .id')
	else
		connections=$(curl -s "http://127.0.0.1:9999/connections" --header "Authorization: Bearer $secret")
		connection_ids=$(echo "$connections" | jq -r '.connections[] | .id')
	fi

	if [ -n "$connection_ids" ]; then
		for id in $connection_ids; do
			curl -X DELETE "http://127.0.0.1:9999/connections/$id" --header "Authorization: Bearer $secret" >/dev/null 2>&1
		done
	fi

}
clear_connections_byserver() {
	local name=$1
	if [ -n "$name" ]; then
		[[ $name != iKuai_* ]] && name="iKuai_$name"
		grep ",$name" $CRASHDIR/yamls/rules.yaml | cut -d ',' -f 2 2>/dev/null | while read -r ip_address; do
			[ -n "$ip_address" ] && clear_connections "$ip_address"
		done
	else
		clear_connections
	fi
}
patch_server_config() {
	pidof CrashCore >/dev/null 2>&1 || return 0
	# 修正服务节点配置,无节点启动时proxies：配置节会被自动删除
	if ! grep -q "^proxies:" $CHROOTDIR/tmp/ShellCrash/config.yaml; then
		sed -i '/^proxy-groups:/i\proxies:' $CHROOTDIR/tmp/ShellCrash/config.yaml
	fi
	# 根据proxies.yaml重建节点配置
	sed -i "/name: iKuai_/d" $CHROOTDIR/tmp/ShellCrash/config.yaml
	awk '{
		# 缩进处理
		sub(/^/, "  ")
		# 识别并对关键字段的值加引号（如果尚未加引号）
		# 目标 Key: username, password, cipher, sni, uuid, auth, token, interface-name, dialer-proxy
		split("username password cipher sni uuid auth token interface-name dialer-proxy", keys)
		for (i in keys) {
			k = keys[i] ":"
			# 匹配模式：key: 后面跟着非引号开头的值
			reg = k "[[:space:]]*[^\"{\x27][^,}]*"
			if (match($0, reg)) {
				# 准确定位值的起始和结束位置
				match($0, k "[[:space:]]*")
				val_start = RSTART + RLENGTH
				tail = substr($0, val_start)
				match(tail, /[^,}]*/)
				val = substr(tail, 1, RLENGTH)
				# 清理尾部空格
				raw_val = val
				gsub(/[[:space:]]+$/, "", raw_val)
				if (length(raw_val) > 0) {
					new_val = "\"" raw_val "\""
					$0 = substr($0, 1, val_start-1) new_val substr($0, val_start + length(val))
				}
			}
		}
		print $0
	}' "$CRASHDIR/yamls/proxies.yaml" >/tmp/proxies_indented1
	sed -i "/^proxies:/r /tmp/proxies_indented1" $CHROOTDIR/tmp/ShellCrash/config.yaml

	# 根据高级配置打开或关闭节点的tfo功能
	if [ "$tcpOptimization" = "0" ]; then
		sed -i "s/tfo: true/tfo: false/g" $CHROOTDIR/tmp/ShellCrash/config.yaml
	else
		sed -i "s/tfo: false/tfo: true/g" $CHROOTDIR/tmp/ShellCrash/config.yaml
	fi

	# 根据高级配置打开或关闭节点的UDP功能
	if [ "$disableUdp" = "1" ]; then
		sed -i "s/udp: true/udp: false/g" $CHROOTDIR/tmp/ShellCrash/config.yaml
	else
		sed -i "s/udp: false/udp: true/g" $CHROOTDIR/tmp/ShellCrash/config.yaml
	fi

	# 根据proxies.yaml重建all-proxies节点组,用于批量测速
	local all_proxies=""
	while IFS= read -r line || [ -n "$line" ]; do
		cleaned_line=$(echo "$line" | sed 's/^[[:space:]]*-\s*//g' | sed 's/[[:space:]]//g' | sed 's/{//g' | sed 's/}//g')
		server_name=$(echo "$cleaned_line" | awk -F ',' '{print $1}' | awk -F':' '{print $2}' | sed 's/[[:space:]]//g')
		[ -n "$server_name" ] && all_proxies+="${all_proxies:+,}'$server_name'"
	done <$CRASHDIR/yamls/proxies.yaml

	[ -n "$all_proxies" ] || all_proxies="'DIRECT'"
	sed -i "/- name: all-proxies/{n;n;s/^[[:space:]]*proxies:.*/    proxies: [$all_proxies]/}" $CHROOTDIR/tmp/ShellCrash/config.yaml

	# 根据高级设置中的DNS解析节点设置，重建dns-proxies节点组，用于dns解析
	local dns_proxies=""
	if [ -z "$dnsResolveNodes" -o "$dnsResolveNodes" = "auto" ]; then
		dns_proxies=$all_proxies
	else
		for node in $(echo "$dnsResolveNodes" | tr ',' '\n'); do
			if grep -q "name: iKuai_${node}," $CRASHDIR/yamls/proxies.yaml; then
				dns_proxies+="${dns_proxies:+,}'iKuai_$node'"
			fi
		done
	fi

	[ -z "$dns_proxies" -o "$dnsmode" != "localdns" ] && dns_proxies="'DIRECT'"
	sed -i "/- name: dns-proxies/{n;n;n;n;n;s/^[[:space:]]*proxies:.*/    proxies: [$dns_proxies]/}" $CHROOTDIR/tmp/ShellCrash/config.yaml
}
patch_rules_config() {
	pidof CrashCore >/dev/null 2>&1 || return 0

	# 根据rules.yaml生成规则写入config.yaml
	sed -i "/SRC-IP-CIDR/d" $CHROOTDIR/tmp/ShellCrash/config.yaml

	local rules_tmp="/tmp/rules_block_tmp"
	awk -F ',' '
		FILENAME == ARGV[1] {
			if ($0 ~ /name: /) {
				match($0, /name: [^,]+/)
				p = substr($0, RSTART + 6, RLENGTH - 6)
				gsub(/[[:space:]]|["\x27]/, "", p)
				nodes[p] = 1
			}
			next
		}
		{
			if ($0 == "" || $0 ~ /^[[:space:]]*$/) next
			line = $0
			gsub(/[[:space:]]/, "", line)
			split(line, a, ",")
			target = a[3]
			# 校验节点是否存在，不存在则替换为REJECT
			if (nodes[target] != 1 && target != "DIRECT" && target != "REJECT") {
				sub(target, "REJECT", $0)
			}
			print " " $0
		}
	' "$CRASHDIR/yamls/proxies.yaml" "$CRASHDIR/yamls/rules.yaml" >"$rules_tmp" 2>/dev/null

	sed -i "/^rules:/r $rules_tmp" $CHROOTDIR/tmp/ShellCrash/config.yaml
	rm -f "$rules_tmp"

	# 修正分流规则配置,将内置规则移到最上面
	sed -i "/DOMAIN-KEYWORD,routerostop,DIRECT/d" $CHROOTDIR/tmp/ShellCrash/config.yaml
	sed -i "/RULE-SET,DirectDomains,DIRECT/d" $CHROOTDIR/tmp/ShellCrash/config.yaml
	sed -i "/RULE-SET,DirectIps,DIRECT/d" $CHROOTDIR/tmp/ShellCrash/config.yaml
	sed -i "/RULE-SET,ProxyIps,dns-proxies/d" $CHROOTDIR/tmp/ShellCrash/config.yaml
	sed -i "/RULE-SET,BlockRules,REJECT/d" $CHROOTDIR/tmp/ShellCrash/config.yaml
	sed -i "/^rules:/a\ - DOMAIN-KEYWORD,routerostop,DIRECT" $CHROOTDIR/tmp/ShellCrash/config.yaml
	sed -i "/^rules:/a\ - RULE-SET,DirectIps,DIRECT" $CHROOTDIR/tmp/ShellCrash/config.yaml
	sed -i "/^rules:/a\ - RULE-SET,DirectDomains,DIRECT" $CHROOTDIR/tmp/ShellCrash/config.yaml
	sed -i "/^rules:/a\ - RULE-SET,ProxyIps,dns-proxies" $CHROOTDIR/tmp/ShellCrash/config.yaml
	[ "$denyVideoData" = "1" ] && sed -i "/^rules:/a\ - RULE-SET,BlockRules,REJECT" $CHROOTDIR/tmp/ShellCrash/config.yaml
	return 0
}
patch_all_config() {
	pidof CrashCore >/dev/null 2>&1 || return 0
	# 修正服务节点配置
	patch_server_config

	# 修正分流规则配置
	patch_rules_config

	# 根据配置开启流量嗅探、流量覆写及内置DNS服务
	if [ "$dnsmode" != "interdns" ]; then
		configLine="sniffer: {enable: true, override-destination: false, parse-pure-ip: true, skip-domain: [Mijia Cloud], sniff: {http: {ports: [80, 8080-8880]}, tls: {ports: [443, 8443]}, quic: {ports: [443, 8443]}}}"
		sed -i "s/^sniffer:.*/${configLine}/" $CHROOTDIR/tmp/ShellCrash/config.yaml
		sed -i '/^dns:/,/^[^[:space:]]/s/^\([[:space:]]*enable:\).*/\1 false/' $CHROOTDIR/tmp/ShellCrash/config.yaml
	else
		configLine="sniffer: {enable: true, override-destination: true, parse-pure-ip: true, skip-domain: [Mijia Cloud], sniff: {http: {ports: [80, 8080-8880]}, tls: {ports: [443, 8443]}, quic: {ports: [443, 8443]}}}"
		sed -i "s/^sniffer:.*/${configLine}/" $CHROOTDIR/tmp/ShellCrash/config.yaml
	fi

	if ! grep -q "^[[:space:]]*unified-delay:" $CHROOTDIR/tmp/ShellCrash/config.yaml; then
		sed -i '/^[[:space:]]*routing-mark:/a \unified-delay: true' $CHROOTDIR/tmp/ShellCrash/config.yaml
	fi

	# 关闭geoip自动下载,不需要
	sed -i "s/geoip: true/geoip: false/" $CHROOTDIR/tmp/ShellCrash/config.yaml

	# 关闭日志提高性能
	sed -i "s/log-level: info/log-level: silent/" $CHROOTDIR/tmp/ShellCrash/config.yaml
}
patch_custom_iprules() {

	# 劫持本机发出的对dns服务器的请求
	for ip in 1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4 9.9.9.9; do
		if [ "$redir_mod" = "混合模式" ]; then
			iptables -w -t nat -C OUTPUT -p tcp -d $ip -j REDIRECT --to-ports 7892 || {
				iptables -w -t nat -A OUTPUT -p tcp -d $ip -j CONNMARK --set-mark 7899
				iptables -w -t nat -A OUTPUT -p tcp -d $ip -j REDIRECT --to-ports 7892
				iptables -w -t mangle -A PREROUTING -p tcp -d $ip -j CONNMARK --restore-mark
			}
		else
			iptables -w -t mangle -C OUTPUT -p tcp -d "$ip" -j MARK --set-mark 7892 ||
				iptables -w -t mangle -A OUTPUT -p tcp -d "$ip" -j MARK --set-mark 7892
		fi
	done

	# 等待shellcrash_mark建立并添加规则
	while true; do
		iptables -t mangle -L shellcrash_mark -n 2>/dev/null || {
			sleep 1 && continue
		}
		sleep 1

		# 开启了远程DNS后，添加规则让DNS请求进入内核并作为普通流量处理
		if [ "$dnsmode" = "remotedns" ]; then
			iptables -t nat -D shellcrash -p udp --dport 53 -j RETURN >/dev/null 2>&1
			iptables -t nat -D shellcrash -p tcp --dport 53 -j RETURN >/dev/null 2>&1
			iptables -t mangle -D shellcrash_mark -p udp --dport 53 -j RETURN >/dev/null 2>&1
			iptables -t mangle -D shellcrash_mark -p tcp --dport 53 -j RETURN >/dev/null 2>&1
		fi

		# 开启了忽略UDP流量后，添加规则让UDP跳过内核
		if [ "$disableUdp" = "1" ]; then
			iptables -w -t mangle -I shellcrash_mark -p udp -j RETURN >/dev/null 2>&1
		fi

		# 处理被标记为停止的规则，添加规则跳过内核
		while IFS= read -r address_ip; do
			iptables -t nat -I shellcrash -s $address_ip -j RETURN >/dev/null 2>&1
			iptables -w -t mangle -I shellcrash_mark -s $address_ip -j RETURN >/dev/null 2>&1
		done <$CRASHDIR/configs/disabled_ips

		# 混合模式下对白名单IP的TCP流量特殊处理
		if [ "$redir_mod" = "混合模式" ]; then
			for address_ip in $(cat $CRASHDIR/configs/ip_filter); do
				iptables -w -t nat -D shellcrash -p tcp -s $address_ip -j CONNMARK --set-mark 7899
				iptables -w -t nat -D shellcrash -p tcp -s $address_ip -j REDIRECT --to-ports 7892
				iptables -w -t mangle -D PREROUTING -p tcp -s $address_ip -j CONNMARK --restore-mark
				iptables -w -t nat -A shellcrash -p tcp -s $address_ip -j CONNMARK --set-mark 7899
				iptables -w -t nat -A shellcrash -p tcp -s $address_ip -j REDIRECT --to-ports 7892
				iptables -w -t mangle -A PREROUTING -p tcp -s $address_ip -j CONNMARK --restore-mark
			done
		fi
		break
	done
}
reload_config() {
	if killall -q -0 CrashCore; then
		msg=$(curl -X PUT "http://127.0.0.1:9999/configs" -d '{"path": "/tmp/ShellCrash/config.yaml"}' --header "Authorization: Bearer $secret")
		if [ -n "$msg" ]; then
			echo "$msg" >>$LOGFILE
			message=$(echo "$msg" | jq -r '.message')
			echo "配置文件加载出错：$message"
			return 1
		else
			return 0
		fi
	fi
}

set_deny_local_net() {

	action=$1
	address_ip=$2
	debug "设置自定义IP规则 $action $address_ip"
	tcpMark=7892
	[ "$redir_mod" = "混合模式" ] && tcpMark=7899
	reserve_ipv4="0.0.0.0/8 10.0.0.0/8 127.0.0.0/8 100.64.0.0/10 169.254.0.0/16 192.168.0.0/16 172.16.0.0/12 224.0.0.0/4 240.0.0.0/4"

	if [ "$action" = "add" ]; then
		[ "$denyLocalNet" = "1" ] || return
		iptables -C FORWARD -p tcp -s "$address_ip" -m mark ! --mark $tcpMark -j DROP 2>/dev/null ||
			iptables -A FORWARD -p tcp -s "$address_ip" -m mark ! --mark $tcpMark -j DROP

		iptables -C FORWARD -p udp -s "$address_ip" -m mark ! --mark 7892 -j DROP 2>/dev/null ||
			iptables -A FORWARD -p udp -s "$address_ip" -m mark ! --mark 7892 -j DROP
	elif [ "$action" = "del" ]; then
		iptables -D FORWARD -p tcp -s "$address_ip" -m mark ! --mark $tcpMark -j DROP 2>/dev/null
		iptables -D FORWARD -p udp -s "$address_ip" -m mark ! --mark 7892 -j DROP 2>/dev/null
	elif [ "$action" = "clear" ]; then
		iptables-save | grep -E '\-A FORWARD .*! --mark (0x1ed4|0x1edb) -j DROP' | while read -r line; do
			rule=$(echo "$line" | sed 's/^\[[^]]*\] //')
			rule_content="${rule#-A FORWARD }"
			iptables -D FORWARD $rule_content
		done
		iptables -D FORWARD -p udp --dport 53 -j ACCEPT 2>/dev/null
		iptables -D FORWARD -p tcp --dport 53 -j ACCEPT 2>/dev/null
		iptables -D FORWARD -m mark --mark 0x1ed6 -j ACCEPT 2>/dev/null
		iptables -D FORWARD -p tcp -m multiport --dports 7890,7892,7893 -j ACCEPT 2>/dev/null

		for net in $reserve_ipv4; do
			iptables -D FORWARD -d $net -j ACCEPT
		done
	elif [ "$action" = "loadall" ]; then
		iptables-save | grep -E '\-A FORWARD .*! --mark (0x1ed4|0x1edb) -j DROP' | while read -r line; do
			rule=$(echo "$line" | sed 's/^\[[^]]*\] //')
			rule_content="${rule#-A FORWARD }"
			iptables -D FORWARD $rule_content
		done
		iptables -D FORWARD -p udp --dport 53 -j ACCEPT 2>/dev/null
		iptables -D FORWARD -p tcp --dport 53 -j ACCEPT 2>/dev/null
		iptables -D FORWARD -m mark --mark 0x1ed6 -j ACCEPT 2>/dev/null
		iptables -D FORWARD -p tcp -m multiport --dports 7890,7892,7893 -j ACCEPT 2>/dev/null

		for net in $reserve_ipv4; do
			iptables -D FORWARD -d $net -j ACCEPT
		done

		[ "$denyLocalNet" = "1" ] || return
		[ -f $CRASHDIR/configs/ip_filter ] || return

		iptables -A FORWARD -p udp --dport 53 -j ACCEPT
		iptables -A FORWARD -p tcp --dport 53 -j ACCEPT
		iptables -A FORWARD -m mark --mark 0x1ed6 -j ACCEPT
		iptables -A FORWARD -p tcp -m multiport --dports 7890,7892,7893 -j ACCEPT

		for net in $reserve_ipv4; do
			iptables -A FORWARD -d $net -j ACCEPT
		done

		for address_ip in $(cat $CRASHDIR/configs/ip_filter); do
			iptables -A FORWARD -p tcp -s "$address_ip" -m mark ! --mark $tcpMark -j DROP
			iptables -A FORWARD -p udp -s "$address_ip" -m mark ! --mark 7892 -j DROP
		done
	fi
}
add_guard_task() {
	cron_check=$(cat /etc/crontabs/root | grep "SK5守护进程" | wc -l)
	if [ $cron_check -eq 0 ]; then
		cronTask="* * * * * test -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autostart" && test -z \"\$(pidof CrashCore)\" && /usr/ikuai/function/plugin_socks5 start #SK5守护进程"
		echo "$cronTask" >>/etc/crontabs/cron.d/socks5
		echo "$cronTask" >>/etc/crontabs/root
		crontab /etc/crontabs/root
	fi

	crondproc=$(ps | grep crond | grep -v grep | wc -l)
	if [ $crondproc -eq 0 ]; then
		crond -L /dev/null
	fi
}
remove_guard_task() {
	cron_check=$(cat /etc/crontabs/root | grep "SK5守护进程" | wc -l)
	if [ $cron_check -gt 0 ]; then
		sed -i /SK5守护进程/d /etc/crontabs/cron.d/socks5
		sed -i /SK5守护进程/d /etc/crontabs/root
		crontab /etc/crontabs/root
	fi
}
monitor_tcp_traffic() {
	action=$1
	if [ "$action" = "start" ]; then
		sk5cro=$(cat /etc/crontabs/root | grep "SK5流量监测" | wc -l)
		if [ $sk5cro -eq 0 ]; then
			cronTask="*/10 * * * * /usr/ikuai/function/plugin_socks5 monitor_tcp_traffic >/dev/null 2>&1 #SK5流量监测"
			echo "$cronTask" >>/etc/crontabs/cron.d/socks5
			echo "$cronTask" >>/etc/crontabs/root
			crontab /etc/crontabs/root
		fi

		crondproc=$(ps | grep crond | grep -v grep | wc -l)
		if [ $crondproc -eq 0 ]; then
			crond -L /dev/null
		fi

	elif [ "$action" = "stop" ]; then
		cron_check=$(cat /etc/crontabs/root | grep "SK5流量监测" | wc -l)
		if [ $cron_check -gt 0 ]; then
			sed -i /SK5流量监测/d /etc/crontabs/cron.d/socks5
			sed -i /SK5流量监测/d /etc/crontabs/root
			crontab /etc/crontabs/root
		fi
	else
		if pidof CrashCore >/dev/null && grep "networkMonitoring=1" $ADV_SETTINGFILE >/dev/null; then
			debug "SK5插件，开始检测TCP流量"
			total=$(get_total_traffic 600 "tcp")
			if [ $total -eq 0 ]; then
				debug "SK5插件，检测到过去10分钟TCP流量为0，重启服务"
				restart
			fi
		fi
	fi
}
get_total_traffic() {
	now=$(date -u +%s)
	total=0
	check_seconds=$1 # 第一个参数：检查时间窗口（秒）
	filter_proto=$2  # 第二个参数：可选，"tcp"、"udp" 或 "all"

	url="http://127.0.0.1:9999/connections"
	data=$(curl -X GET "$url" --header "Authorization: Bearer $secret")
	[ $? -ne 0 ] && data="{}"

	# 构造 jq 过滤条件
	if [ "$filter_proto" = "tcp" ] || [ "$filter_proto" = "udp" ]; then
		jq_filter=".connections[] | select(.metadata.network == \"$filter_proto\") | {start, upload, download}"
	else
		jq_filter=".connections[] | {start, upload, download}"
	fi

	while read -r line; do
		start=$(echo "$line" | jq -r '.start')
		upload=$(echo "$line" | jq -r '.upload')
		download=$(echo "$line" | jq -r '.download')

		start_clean=$(echo "$start" | sed -E 's/\..*Z$//' | sed 's/T/ /')
		start_ts=$(date -u -d "$start_clean" +%s 2>/dev/null)

		if [ -n "$start_ts" ]; then
			delta=$((now - start_ts))
			if [ "$delta" -le "$check_seconds" ]; then
				total=$((total + upload + download))
			fi
		fi
	done < <(echo "$data" | jq -c "$jq_filter")

	echo "$total"
}
format_bytes() {
	local bytes=$1
	local unit=""
	local value=0

	if [ "$bytes" -ge 1099511627776 ]; then
		unit="TB"
		value=$((bytes * 10 / 1099511627776))
	elif [ "$bytes" -ge 1073741824 ]; then
		unit="GB"
		value=$((bytes * 10 / 1073741824))
	elif [ "$bytes" -ge 1048576 ]; then
		unit="MB"
		value=$((bytes * 10 / 1048576))
	elif [ "$bytes" -ge 1024 ]; then
		unit="KB"
		value=$((bytes * 10 / 1024))
	else
		echo "${bytes} B"
		return
	fi

	int_part=$((value / 10))
	decimal_part=$((value % 10))
	echo "${int_part}.${decimal_part} ${unit}"
}

# 节点管理相关方法
save_server() {
	name=iKuai_${name}
	[ "$interfacename" == "默认" ] && interfacename=""
	[ "$dialerProxy" == "无" ] && dialerProxy=""

	# socks5对应参数字符串格式为：name|server|port|username|password|interface-name|dialer-proxy
	# ssr对应参数字符串格式为：name|server|port|cipher|password|interface-name|dialer-proxy
	configString="$name|$address|$port|$user|$password|$interfacename|$dialer"
	configLine=$(generate_server_config $type $configString)

	if grep -q "name: $name," "$CRASHDIR/yamls/proxies.yaml"; then
		# 替换整行内容（含该节点名称的行）
		escaped_configLine=$(printf '%s\n' "$configLine" | sed -e 's/[\/&]/\\&/g')
		sed -i "s/^.*name: $name,.*\$/$escaped_configLine/" "$CRASHDIR/yamls/proxies.yaml"
	else
		[ -n "$configLine" ] && echo $configLine >>$CRASHDIR/yamls/proxies.yaml
	fi
	ret=0
	patch_server_config || ret=1
	patch_rules_config || ret=1
	reload_config || ret=1
	clear_connections_byserver $name
	return $ret
}
batch_edit_servers() {
	IFS=',' read -ra names <<<"$names"

	# 拼接替换段
	local newField=""
	[ -n "$interfacename" ] && newField="interface-name: $interfacename, "
	[ -n "$dialer" ] && newField="dialer-proxy: iKuai_$dialer, "

	for name in "${names[@]}"; do
		name="iKuai_${name}"

		configLine=$(grep -E "\bname: *$name(,|\$)" "$CRASHDIR/yamls/proxies.yaml")

		[ -z "$configLine" ] && continue

		if echo "$configLine" | grep -qE "(interface-name:|dialer-proxy:)"; then
			configLine=$(echo "$configLine" | sed -E 's/(, *)?( interface-name| dialer-proxy):[^,}]+//g')
		fi
		newConfig=$(echo "$configLine" | sed -E "s/(port:[^,}]+, *)/\1${newField}/")

		sed -i "s|^.*name: *$name,.*$|$newConfig|" "$CRASHDIR/yamls/proxies.yaml"
	done

	ret=0
	patch_server_config || ret=1
	reload_config || ret=1
	for name in "${names[@]}"; do
		clear_connections_byserver $name
	done
	return $ret
}
delete_server() {

	name=iKuai_${name}
	escaped_name=$(printf '%s' "$name" | sed 's/[][\.*^$]/\\&/g')
	sed -i "/name: *${escaped_name} *,/d" $CRASHDIR/yamls/proxies.yaml

	ret=0
	patch_server_config || ret=1
	patch_rules_config || ret=1
	reload_config || ret=1
	clear_connections_byserver $name
	return $ret
}
delete_server_list() {

	IFS=',' read -ra names <<<"$names"

	for name in "${names[@]}"; do
		name=iKuai_${name}
		escaped_name=$(printf '%s' "$name" | sed 's/[][\.*^$]/\\&/g')
		sed -i "/name: *${escaped_name} *,/d" $CRASHDIR/yamls/proxies.yaml
	done

	ret=0
	patch_server_config || ret=1
	patch_rules_config || ret=1
	reload_config || ret=1
	for name in "${names[@]}"; do
		clear_connections_byserver $name
	done
	return $ret
}
import_servers() {
	if [ "$type" == "others" ] && [ "$isAdv" != "true" ]; then
		echo "UNAUTHORIZED"
		return 1
	fi

	echo "$configContent" | base64 -d >$CRASHDIR/configs/server.tmp
	[ ! -s "$CRASHDIR/configs/server.tmp" ] && return

	awks1=$(grep "," $CRASHDIR/configs/server.tmp | wc -l)
	awks2=$(grep ":" $CRASHDIR/configs/server.tmp | wc -l)
	awks3=$(grep "\/" $CRASHDIR/configs/server.tmp | wc -l)
	awkF='|'
	[ $awks1 -gt 0 ] && awkF=','
	[ $awks2 -gt 0 ] && awkF=':'
	[ $awks3 -gt 0 ] && awkF='\/'

	[ "$replace" == "true" ] && printf '' >$CRASHDIR/yamls/proxies.yaml

	local index=1
	[ -n "$autoNodeNameStartIndex" ] && index=$autoNodeNameStartIndex

	local udpEnable="true" tfoEnable="true"
	[ "$disableUdp" = "1" ] && udpEnable="false"
	[ "$tcpOptimization" = "0" ] && tfoEnable="false"

	local batch_file="/tmp/import_batch.tmp"
	rm -f "$batch_file"

	if [ "$type" == "others" ]; then
		awk -v udp="$udpEnable" -v tfo="$tfoEnable" '
			{
				gsub(/[\x27"$&;\r\n]/, "")
				if ($0 == "") next
				name = ""
				if (match($0, /name:[^,]+/)) {
					name = substr($0, RSTART + 5, RLENGTH - 5)
					gsub(/[[:space:]]/, "", name)
				}
				if (name == "") next
				name = "iKuai_" name
				line = $0
				gsub(/[[:space:]]/, "", line)
				sub(/name:[^,]*/, "name:" name, line)
				if (line !~ /udp:/) line = line ",udp:" udp
				if (line !~ /tfo:/) line = line ",tfo:" tfo
				gsub(/:/, ": ", line)
				gsub(/,/, ", ", line)
				printf "name:%s,|- {%s}\n", name, line
			}
		' $CRASHDIR/configs/server.tmp >"$batch_file"
	else
		awk -F "$awkF" -v type="$type" -v idx="$index" -v auto="$autoNodeName" \
			-v udp="$udpEnable" -v tfo="$tfoEnable" '
			{
				gsub(/[\x27"$&;\r\n]/, "")
				if ($1 == "" || $2 == "") next
				server = $1; port = $2; user = $3; pass = $4; name = $5
				if (auto == "true") {
					node_name = "iKuai_" type "-node" idx++
				} else {
					if (name == "") next
					node_name = "iKuai_" name
				}
				conf = "name: " node_name ", server: " server ", port: " port ", "
				if (type == "socks5") {
					if (user != "") conf = conf "username: " user ", "
					if (pass != "") conf = conf "password: " pass ", "
					conf = conf "type: socks5, tfo: " tfo ", udp: " udp
				} else if (type == "ss") {
					if (user != "") conf = conf "cipher: " tolower(user) ", "
					if (pass != "") conf = conf "password: " pass ", "
					conf = conf "type: ss, tfo: " tfo ", udp: " udp
				}
				printf "name:%s,|- {%s}\n", node_name, conf
			}
		' $CRASHDIR/configs/server.tmp >"$batch_file"
	fi

	if [ -s "$batch_file" ]; then
		awk -F '|' '
			FILENAME == ARGV[1] { key=$1; gsub(/[[:space:]]/, "", key); nodes[key] = $2; order[count++] = key; next }
			{
				curr_name = ""
				if (match($0, /name: [^,]+/)) {
					curr_name = substr($0, RSTART, RLENGTH)
					gsub(/[[:space:]]/, "", curr_name)
					curr_name = curr_name ","
				}
				if (curr_name != "" && (curr_name in nodes)) {
					print nodes[curr_name]; delete nodes[curr_name]
				} else { print $0 }
			}
			END { for (i=0; i<count; i++) if (order[i] in nodes) print nodes[order[i]] }
		' "$batch_file" $CRASHDIR/yamls/proxies.yaml >$CRASHDIR/yamls/proxies.yaml.tmp
		mv $CRASHDIR/yamls/proxies.yaml.tmp $CRASHDIR/yamls/proxies.yaml
	fi

	ret=0
	patch_server_config || ret=1
	patch_rules_config || ret=1
	reload_config || ret=1

	local names=$(awk -F '|' '{sub(/name: /, "", $1); sub(/,/, "", $1); print $1}' "$batch_file" 2>/dev/null)
	rm -f "$batch_file"
	for name in $names; do
		clear_connections_byserver "$name"
	done

	return $ret
}
generate_server_config() {
	local type=$1
	local configString=$2
	local name="" server="" port="" username="" cipher="" password="" interfaceName="" dialerProxy="" default=""
	local udpEnable="true" tfoEnable="true"

	[ "$disableUdp" = "1" ] && udpEnable="false"
	[ "$tcpOptimization" = "0" ] && tfoEnable="false"

	# 格式化节点配置，$1 为节点类型，$2 为节点参数字符串
	# socks5对应参数字符串格式为：name|server|port|username|password|interface-name|dialer-proxy
	# ssr对应参数字符串格式为：name|server|port|cipher|password|interface-name|dialer-proxy
	case $type in
	socks5)
		IFS='|' read -r name server port username password interfaceName dialerProxy <<<"$configString"
		name="name: $name, "
		server="server: $server, "
		port="port: $port, "
		[ -n "$username" ] && username="username: $username, "
		[ -n "$password" ] && password="password: $password, "
		[ -n "$interfaceName" ] && interfaceName="interface-name: $interfaceName, "
		[ -n "$dialerProxy" ] && dialerProxy="dialer-proxy: iKuai_$dialerProxy, "
		default="type: socks5, tfo: $tfoEnable, udp: $udpEnable"
		echo "- {$name$server$port$username$password$interfaceName$dialerProxy$default}"
		return 0
		;;
	ss)
		IFS='|' read -r name server port cipher password interfaceName dialerProxy <<<"$configString"
		name="name: $name, "
		server="server: $server, "
		port="port: $port, "
		[ -n "$cipher" ] && cipher="cipher: ${cipher,,}, "
		[ -n "$password" ] && password="password: $password, "
		[ -n "$interfaceName" ] && interfaceName="interface-name: $interfaceName, "
		[ -n "$dialerProxy" ] && dialerProxy="dialer-proxy: iKuai_$dialerProxy, "
		default="type: ss, tfo: $tfoEnable, udp: $udpEnable"
		echo "- {$name$server$port$cipher$password$interfaceName$dialerProxy$default}"
		return 0
		;;
	esac
}

# 分流规则相关方法
save_client() {

	name_sk=iKuai_${name_sk}

	[[ "$address_ip" != */* ]] && address_ip="${address_ip}/32"

	# 添加白名单
	if ! grep -q "^$address_ip\$" "$CRASHDIR/configs/ip_filter"; then
		echo "$address_ip" >>$CRASHDIR/configs/ip_filter
	fi

	# 添加分流规则，如果存在该IP则替换
	if grep -q "$address_ip" $CRASHDIR/yamls/rules.yaml; then
		escaped_ip="${address_ip//\//\\/}"
		sed -i "s/^.*$escaped_ip.*\$/- SRC-IP-CIDR,$escaped_ip,$name_sk/" $CRASHDIR/yamls/rules.yaml
	else
		echo "- SRC-IP-CIDR,$address_ip,$name_sk" >>$CRASHDIR/yamls/rules.yaml
	fi

	# 若服务已经运行，则实时添加白名单规则
	if killall -q -0 CrashCore; then
		iptables -w -t mangle -C shellcrash_mark -p udp -s $address_ip -j MARK --set-mark 7892 || {
			if [ "$redir_mod" = "混合模式" ]; then
				iptables -w -t nat -A shellcrash -p tcp -s $address_ip -j CONNMARK --set-mark 7899
				iptables -w -t nat -A shellcrash -p tcp -s $address_ip -j REDIRECT --to-ports 7892
				iptables -w -t mangle -A PREROUTING -p tcp -s $address_ip -j CONNMARK --restore-mark
				iptables -w -t mangle -A shellcrash_mark -p udp -s $address_ip -j MARK --set-mark 7892

			else
				iptables -w -t mangle -A shellcrash_mark -p tcp -s $address_ip -j MARK --set-mark 7892
				iptables -w -t mangle -A shellcrash_mark -p udp -s $address_ip -j MARK --set-mark 7892
			fi
		}
	fi

	set_deny_local_net "add" "$address_ip"

	ret=0
	if [ "$1" != "internal-call" ]; then
		patch_rules_config || ret=1
		reload_config || ret=1
		clear_connections "$address_ip"
	fi
	return $ret
}
delete_Client() {

	[[ "$address_ip" != */* ]] && address_ip="${address_ip}/32"
	# 删除该IP可能存在的被停用的记录，防止再次添加后默认停用
	sed -i '\#^'"${address_ip%/32}"'\(\/32\)\?$#d' $CRASHDIR/configs/disabled_ips
	iptables -t nat -D shellcrash -s $address_ip -j RETURN >/dev/null 2>&1
	iptables -w -t mangle -D shellcrash_mark -s $address_ip -j RETURN >/dev/null 2>&1

	sed -i "/${address_ip//\//\\\/}/d" $CRASHDIR/yamls/rules.yaml
	sed -i "/${address_ip//\//\\\/}/d" $CRASHDIR/configs/ip_filter

	if [ "$redir_mod" = "混合模式" ]; then
		iptables -w -t nat -D shellcrash -p tcp -s $address_ip -j CONNMARK --set-mark 7899
		iptables -w -t nat -D shellcrash -p tcp -s $address_ip -j REDIRECT --to-ports 7892
		iptables -w -t mangle -D PREROUTING -p tcp -s $address_ip -j CONNMARK --restore-mark
		iptables -w -t mangle -D shellcrash_mark -p udp -s $address_ip -j MARK --set-mark 7892
	else
		iptables -w -t mangle -D shellcrash_mark -p tcp -s $address_ip -j MARK --set-mark 7892
		iptables -w -t mangle -D shellcrash_mark -p udp -s $address_ip -j MARK --set-mark 7892
	fi

	set_deny_local_net "del" "$address_ip"

	ret=0
	if [ "$1" != "internal-call" ]; then
		patch_rules_config || ret=1
		reload_config || ret=1
		clear_connections "$address_ip"
	fi
	return $ret
}
delete_clients_list() {

	IFS=',' read -ra ips <<<"$address_ips"

	for i in "${!ips[@]}"; do
		address_ip=${ips[$i]}
		delete_Client "internal-call"
	done

	ret=0
	patch_rules_config || ret=1
	reload_config || ret=1
	for ip in "${ips[@]}"; do
		clear_connections $ip
	done
	return $ret
}
switch_client_enable() {

	[[ "$address_ip" != */* ]] && address_ip="${address_ip}/32"
	if grep -q -E "^${address_ip%/32}(/32)?$" $CRASHDIR/configs/disabled_ips; then
		[ "$set_enable" = "false" ] && return 0
		sed -i '\#^'"${address_ip%/32}"'\(\/32\)\?$#d' $CRASHDIR/configs/disabled_ips
		iptables -t nat -D shellcrash -s $address_ip -j RETURN >/dev/null 2>&1
		iptables -w -t mangle -D shellcrash_mark -s $address_ip -j RETURN >/dev/null 2>&1
	else
		[ "$set_enable" = "true" ] && return 0
		echo $address_ip >>$CRASHDIR/configs/disabled_ips
		iptables -t nat -I shellcrash -s $address_ip -j RETURN >/dev/null 2>&1
		iptables -w -t mangle -I shellcrash_mark -s $address_ip -j RETURN >/dev/null 2>&1
	fi

	clear_connections "$address_ip"
	return 0
}
switch_clients_enable() {

	IFS=',' read -ra ips <<<"$address_ips"

	for i in "${!ips[@]}"; do
		address_ip=${ips[$i]}
		switch_client_enable
	done

	return 0
}
import_clients() {
	echo "$configContent" | base64 -d >$CRASHDIR/configs/client.tmp
	[ ! -s "$CRASHDIR/configs/client.tmp" ] && return

	awks1=$(grep "," $CRASHDIR/configs/client.tmp | wc -l)
	awks2=$(grep ":" $CRASHDIR/configs/client.tmp | wc -l)
	awks3=$(grep "\/" $CRASHDIR/configs/client.tmp | wc -l)
	awkF='|'
	[ $awks1 -gt 0 ] && awkF=','
	[ $awks2 -gt 0 ] && awkF=':'
	[ $awks3 -gt 0 ] && awkF='\/'

	[ "$replace" == "true" ] && printf '' >$CRASHDIR/yamls/rules.yaml && echo 203.0.113.1 >$CRASHDIR/configs/ip_filter

	local batch_rules="/tmp/import_rules.tmp"
	local batch_ips="/tmp/import_ips.tmp"

	# 解析导入文件，生成批量规则和IP列表
	awk -F "$awkF" '
		{
			gsub(/[\x27"$&;\r\n]/, "")
			if ($1 == "" || $2 == "") next
			ip = $1; name = $2
			if (ip !~ /\//) ip = ip "/32"
			printf "%s|- SRC-IP-CIDR,%s,iKuai_%s\n", ip, ip, name
		}
	' $CRASHDIR/configs/client.tmp >"$batch_rules"

	awk -F '|' '{print $1}' "$batch_rules" >"$batch_ips"

	# 合并到 rules.yaml
	if [ -s "$batch_rules" ]; then
		awk -F '|' '
			FILENAME == ARGV[1] { rules[$1] = $2; order[count++] = $1; next }
			{
				curr_ip = ""
				if (match($0, /SRC-IP-CIDR,[^,]+/)) {
					curr_ip = substr($0, RSTART + 12, RLENGTH - 12)
					if (curr_ip !~ /\//) curr_ip = curr_ip "/32"
				}
				if (curr_ip != "" && (curr_ip in rules)) {
					print rules[curr_ip]; delete rules[curr_ip]
				} else { print $0 }
			}
			END { for (i=0; i<count; i++) if (order[i] in rules) print rules[order[i]] }
		' "$batch_rules" $CRASHDIR/yamls/rules.yaml >$CRASHDIR/yamls/rules.yaml.tmp
		mv $CRASHDIR/yamls/rules.yaml.tmp $CRASHDIR/yamls/rules.yaml
	fi

	# 合并到 ip_filter
	cat "$batch_ips" >>$CRASHDIR/configs/ip_filter
	sort -u $CRASHDIR/configs/ip_filter -o $CRASHDIR/configs/ip_filter

	ret=0
	patch_rules_config || ret=1
	reload_config || ret=1

	# 批量执行同步动作
	while read -r address_ip; do
		[ -z "$address_ip" ] && continue
		if killall -q -0 CrashCore; then
			iptables -w -t mangle -C shellcrash_mark -p udp -s $address_ip -j MARK --set-mark 7892 2>/dev/null || {
				if [ "$redir_mod" = "混合模式" ]; then
					iptables -w -t nat -A shellcrash -p tcp -s $address_ip -j CONNMARK --set-mark 7899
					iptables -w -t nat -A shellcrash -p tcp -s $address_ip -j REDIRECT --to-ports 7892
					iptables -w -t mangle -A PREROUTING -p tcp -s $address_ip -j CONNMARK --restore-mark
					iptables -w -t mangle -A shellcrash_mark -p udp -s $address_ip -j MARK --set-mark 7892
				else
					iptables -w -t mangle -A shellcrash_mark -p tcp -s $address_ip -j MARK --set-mark 7892
					iptables -w -t mangle -A shellcrash_mark -p udp -s $address_ip -j MARK --set-mark 7892
				fi
			}
		fi
		set_deny_local_net "add" "$address_ip"
		clear_connections "$address_ip"
	done <"$batch_ips"

	rm -f "$batch_rules" "$batch_ips"
	return $ret
}

# 白名单相关方法
save_whitelist() {
	if [ $type = "domain" ]; then
		configpath=$CRASHDIR/ruleset/direct_domains.txt
	else
		configpath=$CRASHDIR/ruleset/direct_ips.txt
	fi

	configTxt=$(echo "$configTxt64" | base64 -d)
	mkdir -p $CRASHDIR/ruleset
	echo "$configTxt" >$configpath

	# 断开现有连接
	clear_connections
	patch_rules_config
	reload_config
}
# 高级设置相关方法
save_adv_settings() {

	if [ "$isAdv" != "true" ]; then
		echo "UNAUTHORIZED"
		return 1
	fi

	# 清理文件头部的空字节（0x00），防止文件被识别为二进制文件
	if [ ! -f "$ADV_SETTINGFILE" ]; then
		printf '' >"$ADV_SETTINGFILE"
	else
		sanitize_file "$ADV_SETTINGFILE"
	fi

	# 禁止本地直连
	sed -i "/denyLocalNet=/d" $ADV_SETTINGFILE
	echo "denyLocalNet=$denyLocalNet" >>$ADV_SETTINGFILE

	# 屏蔽视频流量
	sed -i "/denyVideoData=/d" $ADV_SETTINGFILE
	echo "denyVideoData=$denyVideoData" >>$ADV_SETTINGFILE

	# TCP优化：TUN模式还是混合模式
	sed -i "/tcpOptimization=/d" $ADV_SETTINGFILE
	echo "tcpOptimization=$tcpOptimization" >>$ADV_SETTINGFILE

	# 测速网站
	sed -i "/connTestSite=/d" $ADV_SETTINGFILE
	echo "connTestSite=$connTestSite" >>$ADV_SETTINGFILE

	# 节点是否开启UTP
	sed -i "/disableUdp=/d" $ADV_SETTINGFILE
	echo "disableUdp=$disableUdp" >>$ADV_SETTINGFILE

	# 域名嗅探
	sed -i "/domainSniffing=/d" $ADV_SETTINGFILE
	echo "domainSniffing=$domainSniffing" >>$ADV_SETTINGFILE

	# DNS模式
	sed -i "/dnsmode=/d" $ADV_SETTINGFILE
	echo "dnsmode=$dnsmode" >>$ADV_SETTINGFILE

	# 禁止QUIC流量
	sed -i "/rejectQUIC=/d" $ADV_SETTINGFILE
	echo "rejectQUIC=$rejectQUIC" >>$ADV_SETTINGFILE

	# 跳过国内地址
	sed -i "/bypassCNIP=/d" $ADV_SETTINGFILE
	echo "bypassCNIP=$bypassCNIP" >>$ADV_SETTINGFILE

	# 网络流量监控
	sed -i "/networkMonitoring=/d" $ADV_SETTINGFILE
	echo "networkMonitoring=$networkMonitoring" >>$ADV_SETTINGFILE

	# DNS解析节点
	sed -i "/dnsResolveNodes=/d" $ADV_SETTINGFILE
	echo "dnsResolveNodes=\"$dnsResolveNodes\"" >>$ADV_SETTINGFILE

	handel_adv_settings
	pidof CrashCore >/dev/null && restart

	return 0
}
handel_adv_settings() {

	# 始终禁止本地直连
	if [ "$denyLocalNet" = "1" ]; then
		set_deny_local_net "loadall"
	else
		set_deny_local_net "clear"
	fi

	# 域名嗅探
	if [ "$domainSniffing" = "1" ]; then
		sed -i "s/sniffer=未开启/sniffer=已启用/" $CRASHDIR/configs/ShellCrash.cfg
	else
		sed -i "s/sniffer=已启用/sniffer=未开启/" $CRASHDIR/configs/ShellCrash.cfg
	fi

	# 域名劫持
	if [ "$dnsmode" = "interdns" ]; then
		sed -i 's/^dns_no=.*/dns_no=未禁用/' $CRASHDIR/configs/ShellCrash.cfg
	else
		sed -i 's/^dns_no=.*/dns_no=已禁用/' $CRASHDIR/configs/ShellCrash.cfg
	fi

	# 禁止QUIC流量
	if [ "$rejectQUIC" = "1" ]; then
		sed -i "s/quic_rj=未开启/quic_rj=已启用/" $CRASHDIR/configs/ShellCrash.cfg
	else
		sed -i "s/quic_rj=已启用/quic_rj=未开启/" $CRASHDIR/configs/ShellCrash.cfg
	fi

	# 跳过国内地址
	if [ "$bypassCNIP" = "1" ]; then
		sed -i "s/cn_ip_route=未开启/cn_ip_route=已开启/" $CRASHDIR/configs/ShellCrash.cfg
	else
		sed -i "s/cn_ip_route=已开启/cn_ip_route=未开启/" $CRASHDIR/configs/ShellCrash.cfg
	fi

	# 启用远程DNS
	if [ "$dnsmode" = "remotedns" ]; then
		sed -i 's/^/#/' $CRASHDIR/ruleset/proxy_ips.txt
	else
		sed -i 's/^##*//' $CRASHDIR/ruleset/proxy_ips.txt
	fi

}
register_adv() {
	authtool registe $code
	return $?
}

set_admessage() {
	[ -z "$message" ] && return 1
	if [ "$message" = "none" ]; then
		rm -f $CRASHDIR/configs/usradmsg
	else
		echo "$message" >$CRASHDIR/configs/usradmsg
	fi
	return 0
}

# 界面数据加载及呈现相关方法
show() {
	Show __json_result__
}
__show_interface() {
	local interfacea=$(ip -4 addr show | grep -o '^[0-9]*: .*' | cut -d ' ' -f2 | cut -d '@' -f1 | sed 's/://g' | grep -vE '^(lo|lan[0-9]+|utun)$' | jq -R . | jq -s '[[ "auto" ] + . | map([.])]' | jq -c .)
	local interfaceb=$(echo "$interfacea" | sed 's/^.\(.*\).$/\1/')
	interface=$(echo "$interfaceb" | jq 'map(select(. != ["tailscale0"] and . != ["zthnhpt5cu"] and . != ["auto"]))')

	json_append __json_result__ interface:json
}
__show_status() {
	local status=0
	local runningStatus=""
	local version=""
	local adMessage=""
	local isTry=""
	local fdCount=0
	local vmSize=0
	local vmRSS=0

	version=$(jq -r '.version' /usr/ikuai/www/plugins/$PLUGIN_NAME/metadata.json)
	allowRenew=$(cat /etc/mnt/plugins/configs/.renew.info 2>/dev/null | cut -d '|' -f 1)
	[ "$allowRenew" = "1" ] && isTry="false" || isTry="true"

	if killall -q -0 CrashCore; then
		local status=1

		pidCrash=$(pidof CrashCore)
		fdCount=$(ls /proc/$pidCrash/fd 2>/dev/null | wc -l)
		vmSize=$(($(cat /proc/$pidCrash/status | grep VmSize | awk '{print $2}') * 1024))
		vmRSS=$(($(cat /proc/$pidCrash/status | grep VmRSS | awk '{print $2}') * 1024))

		local start_time=$(cat ${CHROOTDIR}/tmp/ShellCrash/crash_start_time)
		if [ -n "$start_time" ]; then
			time=$(($(date +%s) - start_time))
			day=$((time / 86400))
			[ "$day" = "0" ] && day='' || day="$day天"
			time=$(date -u -d @${time} +%H小时%M分%S秒)
			runningStatus="已运行: ${day}${time}"
		else
			runningStatus="已运行: 0小时0分1秒"
		fi
	fi

	adMessage=$(cat $CRASHDIR/configs/usradmsg 2>/dev/null)
	if [ -z "$adMessage" ]; then
		adMessage=$(authtool admessage)
	fi

	json_append __json_result__ status:int
	json_append __json_result__ runningStatus:str
	json_append __json_result__ version:str
	json_append __json_result__ adMessage:str
	json_append __json_result__ isAdv:str
	json_append __json_result__ isTry:str
	json_append __json_result__ fdCount:int
	json_append __json_result__ vmSize:int
	json_append __json_result__ vmRSS:int
}
__show_client() {
	local disabled_ips="$CRASHDIR/configs/disabled_ips"
	local rules_yaml="$CRASHDIR/yamls/rules.yaml"
	[ ! -f "$disabled_ips" ] && disabled_ips="/dev/null"

	clients=$(awk -F "," -v filter_ip="$ipaddress" '
		FILENAME == ARGV[1] {
			if ($0 ~ /^[0-9.]+/) {
				split($0, a, "/")
				disabled[a[1]] = 1
			}
			next
		}
		{
			if ($0 == "" || $0 ~ /^[[:space:]]*$/) next
			addr = $2
			name = $3
			# 去除前后空格
			gsub(/^[[:space:]]+|[[:space:]]+$/, "", addr)
			gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
			
			sub(/\/32/, "", addr)
			if (filter_ip != "" && filter_ip != addr) next
			
			sub(/^iKuai_/, "", name)
			count++
			status = (disabled[addr] ? "已停用" : "已启用")
			
			gsub(/"/, "\\\"", name)
			json = sprintf("{\"id\":%d,\"address_ip\":\"%s\",\"name_sk\":\"%s\",\"status\":\"%s\"}", count, addr, name, status)
			printf "%s%s", (count > 1 ? "," : ""), json
		}
	' "$disabled_ips" "$rules_yaml" 2>/dev/null)

	clients="[$clients]"
	json_append __json_result__ clients:json
}
__show_server() {
	local proxies_yaml="$CRASHDIR/yamls/proxies.yaml"

	servers=$(awk '
		{
			if ($0 == "" || $0 ~ /^[[:space:]]*$/) next
			line = $0
			sub(/^[[:space:]]*-[[:space:]]*/, "", line)
			sub(/^\{/, "", line)
			sub(/\}$/, "", line)
			
			name=""; addr=""; port=""; type=""; user=""; pass=""; iname="默认"; dial="无"
			n = split(line, fields, /,[[:space:]]*/)
			for (i=1; i<=n; i++) {
				split(fields[i], kv, /:[[:space:]]*/)
				key = kv[1]
				val = fields[i]
				sub(/^[^:]+:[[:space:]]*/, "", val)
				# 去除前后空格和引号
				gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
				gsub(/^["\x27]|["\x27]$/, "", val)
				
				if (key == "name") { name = val; sub(/^iKuai_/, "", name) }
				else if (key == "server") { addr = val }
				else if (key == "port") { port = val }
				else if (key == "type") { type = val }
				else if (key == "username" || key == "cipher") { user = val }
				else if (key == "password") { pass = val }
				else if (key == "interface-name") { iname = val }
				else if (key == "dialer-proxy") { dial = val }
			}
			
			count++
			gsub(/"/, "\\\"", name); gsub(/"/, "\\\"", addr)
			gsub(/"/, "\\\"", user); gsub(/"/, "\\\"", pass)
			gsub(/"/, "\\\"", iname); gsub(/"/, "\\\"", dial)
			
			json = sprintf("{\"id\":%d,\"name\":\"%s\",\"address\":\"%s\",\"Port\":\"%s\",\"type\":\"%s\",\"user\":\"%s\",\"password\":\"%s\",\"interfacename\":\"%s\",\"dialer\":\"%s\"}", \
				count, name, addr, port, type, user, pass, iname, dial)
			printf "%s%s", (count > 1 ? "," : ""), json
		}
	' "$proxies_yaml" 2>/dev/null)

	servers="[$servers]"
	json_append __json_result__ servers:json
}
__show_serverDelay() {

	testSiteUrls=(
		"https%3A%2F%2Fwww.gstatic.com%2Fgenerate_204"
		"http%3A%2F%2Fcaptive.apple.com%2Fhotspot-detect.html"
		"http%3A%2F%2Fwww.msftconnecttest.com%2Fconnecttest.txt"
		"http%3A%2F%2Fconnect.rom.miui.com%2Fgenerate_204"
	)

	# 检查是否为1~4的数字，否则默认取4
	if ! [[ "$connTestSite" =~ ^[1-4]$ ]]; then
		connTestSite=4
	fi

	testUrl="${testSiteUrls[$((connTestSite - 1))]}"

	url="http://127.0.0.1:9999/proxies/iKuai_${servername}/delay?url=${testUrl}&timeout=2000"
	data=$(curl -X GET "$url" --header "Authorization: Bearer $secret")

	[ $? -ne 0 ] && data="{}"

	serverDelay=$(echo "$data" | jq -r '.delay')

	if [ -z "$serverDelay" ] || [ "$serverDelay" = "null" ]; then
		serverDelay="-1"
	else
		serverDelay=$((serverDelay / 2))
	fi

	json_append __json_result__ serverDelay:str
}
__show_trafficInfo() {
	local trafficInfo=$(format_bytes $(get_total_traffic 3600))
	trafficInfo="过去1小时流量: $trafficInfo"
	json_append __json_result__ trafficInfo:str
}
__show_domain_whitelist() {

	local domainwhitelist=""

	if [ -f "$CRASHDIR/ruleset/direct_domains.txt" ]; then
		domainwhitelist=$(cat $CRASHDIR/ruleset/direct_domains.txt | base64 | tr -d '\n')
	fi

	json_append __json_result__ domainwhitelist:str
}
__show_ip_whitelist() {

	local ipwhitelist=""

	if [ -f "$CRASHDIR/ruleset/direct_ips.txt" ]; then
		ipwhitelist=$(cat $CRASHDIR/ruleset/direct_ips.txt | base64 | tr -d '\n')
	fi

	json_append __json_result__ ipwhitelist:str
}
__show_adv_settings() {

	local adv_settings=""
	json_append adv_settings denyLocalNet:str
	json_append adv_settings denyVideoData:str
	json_append adv_settings tcpOptimization:str
	json_append adv_settings connTestSite:str
	json_append adv_settings disableUdp:str
	json_append adv_settings domainSniffing:str
	json_append adv_settings dnsmode:str
	json_append adv_settings rejectQUIC:str
	json_append adv_settings networkMonitoring:str
	json_append adv_settings bypassCNIP:str
	json_append adv_settings dnsResolveNodes:str
	json_append __json_result__ adv_settings:json
}

__show_subnodes() {
	suburl=$(echo "$suburl" | base64 -d)

	# 校验订阅地址格式
	echo "$suburl" | grep -E -q '^(https?:\/\/[a-zA-Z0-9.-]+(:[0-9]+)?(\/[a-zA-Z0-9._~:/?#@!$&*+=%-]*)?|(vless|vmess|trojan|ss|ssr|hy2|hysteria2|tuic|socks5?):\/\/.*)$'
	if [ $? -ne 0 ]; then
		echo "{\"ErrMsg\":\"订阅地址格式不正确！\"}"
		return 1
	fi

	nodeconfig=$(get_subconfig $suburl)

	if [ -z "$nodeconfig" ]; then
		echo "{\"ErrMsg\":\"订阅地址解析失败！\"}"
		return 1
	fi

	nodeconfig=$(echo "$nodeconfig" | sed '/proxies:/d' | sed 's/^[[:space:]]*-[[:space:]]*{ *//;s/ *}[[:space:]]*$//;a\\')

	nodeb64=$(echo "$nodeconfig" | base64 | tr -d '\n')
	json_append __json_result__ nodeb64:str
}

get_subconfig() {
	suburl=$1

	parsed_url=$(echo "$suburl" | grep -o 'url=[^&]*' | sed 's/url=//')
	if [ -n "$parsed_url" ]; then
		suburl=$parsed_url
	else
		suburl=$(echo $suburl | sed 's/;/\%3B/g; s|/|\%2F|g; s/?/\%3F/g; s/:/\%3A/g; s/@/\%40/g; s/=/\%3D/g; s/&/\%26/g')
	fi

	Servers=(
		"http://sub.routeros.top:8086"
		"https://api.v1.mk"
		"https://sub.d1.mk"
		"https://api.dler.io"
		"https://sub.xeton.dev"
	)

	config="" # tobe defined later

	nodelist=""
	rtVal=1

	for Server in "${Servers[@]}"; do
		# url="${Server}/sub?target=clash&insert=false&list=true&emoji=false&sort=true&scv=true&fdn=true&udp=true&tfo=true&new_name=true&url=${suburl}&config=${config}"
		url="${Server}/sub?target=clash&insert=false&list=true&emoji=false&sort=true&scv=true&fdn=true&new_name=true&url=${suburl}&config=${config}"
		# udp: true, tfo: true

		nodelist=$(curl -fsSL -H "User-Agent: ClashVerge/1.0.0" --max-time 10 "$url" 2>/dev/null)

		if [ $? -eq 0 ] && echo $nodelist | grep -Eq 'server:|server":|server'\'':'; then
			rtVal=0
			break
		fi
		nodelist=""
	done
	echo "$nodelist"
	return "$rtVal"
}

# 以下为未使用的方法
core_start() {

	rm $CHROOTDIR/tmp/ShellCrash -rf
	mkdir -p $CHROOTDIR/tmp/ShellCrash
	tar -xzvf /tmp/log/ShellCrash/CrashCore.tar.gz -C $CHROOTDIR/tmp/ShellCrash/

	cp "$CRASHDIR/yamls/config.yaml" $CHROOTDIR/tmp/ShellCrash/config.yaml
	sed 's/^/  /' "$CRASHDIR/yamls/proxies.yaml" >/tmp/proxies_indented
	sed -i "/^proxies:/r /tmp/proxies_indented" $CHROOTDIR/tmp/ShellCrash/config.yaml

	sed -i "/^rules:/r $CRASHDIR/yamls/rules.yaml" $CHROOTDIR/tmp/ShellCrash/config.yaml
	$CHROOTDIR/tmp/ShellCrash/CrashCore -d /tmp/log/ShellCrash -f $CHROOTDIR/tmp/ShellCrash/config.yaml >/dev/null &

}

restore() {

	if [ "$isAdv" != "true" ]; then
		echo "UNAUTHORIZED"
		return 1
	fi

	if ! openssl aes-128-cbc -in /tmp/iktmp/import/file -out /tmp/iktmp/import/file.tar -k "ikuai.socks5" -d >/dev/null 2>/dev/null; then
		rm -f /tmp/iktmp/import/*
		echo "恢复失败,文件错误！！"
		exit 1
	fi

	tar -xf /tmp/iktmp/import/file.tar -C $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME
	pidof CrashCore >/dev/null && restart
	exit 0

}

__show_backups() {

	rm /tmp/iktmp/export/* -rf
	FileName=SK5BK-$(date +"%Y%m%d%H%M%S").bak
	tar -cf /tmp/iktmp/export/$FileName.tar -C $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME .
	openssl aes-128-cbc -in /tmp/iktmp/export/$FileName.tar -out /tmp/iktmp/export/$FileName -k "ikuai.socks5" -e
	json_append __json_result__ FileName:str

}

__show_serverGroupDelay() {
	url="http://127.0.0.1:9999/group/all-proxies/delay?url=https%3A%2F%2Fwww.gstatic.com%2Fgenerate_204&timeout=2000"
	data=$(curl -X GET "$url" --header "Authorization: Bearer $secret")
	[ $? -ne 0 ] && data="{}"
	serverDelay=$(echo "$data" | jq 'with_entries(if .key | startswith("iKuai_") then .key |= (. | split("iKuai_")[1]) else . end)')

	json_append __json_result__ serverDelay:json
}
__show_traffic() {
	url="http://127.0.0.1:9999/connections"
	data=$(curl -X GET "$url" --header "Authorization: Bearer $secret")
	[ $? -ne 0 ] && data="{}"

	traffic=$(echo $data | jq '
	.connections
	| group_by(.metadata.sourceIP)
	| map({
		sourceIP: .[0].metadata.sourceIP,
		upload: map(.upload) | add,
		download: map(.download) | add
		})
	')

	json_append __json_result__ traffic:json
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

declare -A ___INCLUDE_ALREADY_LOAD_FILE___
declare -A ___JSON_ALREADY_LOAD_FILE___
declare -A ___I18N_ALREADY_LOAD_FILE___
declare -A CONVERT_NETMASK_TO_BIT
declare -A CHECK_IS_SETING
declare -A APPIDS
declare -A VERSION_ALL
declare -A SYSSTAT_MEM
declare -A SYSSTAT_STREAM
declare -A IK_HOSTS_UPDATE

LINE_R=$'\r'
LINE_N=$'\n'
LINE_RN=$'\r\n'
LINE_NT=$'\n\t'

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

Syslog()
{
	logger -t sys_event "$*"
}

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

I18nload()
{
	local file
	for file in ${@//,/ } ;do
		if [ ! "${___I18N_ALREADY_LOAD_FILE___[$file]}" ];then
			if [ ! -f $IK_DIR_CACHE/i18n/$file.sh ];then
				json_decode_file_to_cache i18n_${file%%.*} $IK_DIR_I18N/$file $IK_DIR_CACHE/i18n/$file.sh
			fi

			___I18N_ALREADY_LOAD_FILE___[$file]=1
			. $IK_DIR_CACHE/i18n/$file.sh 2>/dev/null
		fi
	done
}

Show()
{
	local ____TYPE_SHOW____
	local ____SHOW_TOTAL_AND_DATA____
	local TYPE=${TYPE:-data}

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

auth_plugin() {

    local PUBLIC_KEY='
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwnlZx4PHTLGIWFSJ7jvQ
X20LkRtRKZuw5MquSqkWOC0itGQX9Ed6VSPG7tx+ZKKY+uEJ2dqwbj4Py2zpyRO3
+fWylLB4IMPmIDYPH8f+JNsxEsxSw+G4tj/bqSzEckI6lfo15vGujUNHqzQtVC6a
GlAZPZNfjd8Yxn7THtWz+G2CYg5ncx20ZdSX9F8S/N9cnHe/8DrZLu3Svk4CwATX
2UjCut+bjij+W6SnwOtVWvvhTnVybV9uGecWnEyegXC6XVO9f7z6Gdsn0zkNHA0z
taED5c4gV21ZKPoxRy7mjgYeNHnkbCYHXuVRA/sahSiSGAaJ0DIAzPd4HFum9Ydb
lQIDAQAB
-----END PUBLIC KEY-----
'
    local TEMP_KEY=$(mktemp)
    local TEMP_ACTCODE=$(mktemp)
    local TEMP_SIGNATURE=$(mktemp)
    echo "$PUBLIC_KEY" > "$TEMP_KEY"

	ARCH=$(cat /etc/release | grep ARCH= | sed 's/ARCH=//g')

    if [ $ARCH = "x86" ]; then
      BOOTHDD=$(cat /etc/release | grep BOOTHDD= | sed 's/BOOTHDD=//g')
      EMBED_FACTORY_PART_OFFSET=0
      eep_mtd=/dev/${BOOTHDD}2
      activationCode=$(hexdump -v -s $((0x8C + $EMBED_FACTORY_PART_OFFSET)) -n 10 -e '1/1 "%02x"' $eep_mtd)
    else
      eep_mtd=/dev/$(cat /proc/mtd | grep "Factory" | cut -d ":" -f 1)
      EMBED_FACTORY_PART_OFFSET=$(cat /etc/release | grep EMBED_FACTORY_PART_OFFSET= | sed 's/EMBED_FACTORY_PART_OFFSET=//g')
      activationCode=$(hexdump -v -s $((0x8C + $EMBED_FACTORY_PART_OFFSET)) -n 10 -e '1/1 "%02x"' $eep_mtd)
    fi

    
    expire_hex=$(hexdump -v -s $((0x2008 + 256 + $EMBED_FACTORY_PART_OFFSET)) -n 8 -e '1/1 "%02x"' $eep_mtd)
    feature_hex=$(hexdump -v -s $((0x2008 + 256 + 8 + $EMBED_FACTORY_PART_OFFSET)) -n 4 -e '1/1 "%02x"' $eep_mtd)

    printf "%s" "$activationCode" > "$TEMP_ACTCODE"
    printf "%s" "$expire_hex" >> "$TEMP_ACTCODE"
    if [  "$feature_hex" != "00000000" ] && [  "$feature_hex" != "ffffffff" ]; then
        printf "%s" "$feature_hex" >> "$TEMP_ACTCODE"
    fi

    dd if=$eep_mtd bs=1 skip=$((0x2008 + $EMBED_FACTORY_PART_OFFSET)) count=256 of=$TEMP_SIGNATURE >/dev/null 2>&1

    openssl dgst -sha256 -verify "$TEMP_KEY" -signature "$TEMP_SIGNATURE" "$TEMP_ACTCODE" >/dev/null
    ret=$? 

    rm $TEMP_KEY $TEMP_ACTCODE $TEMP_SIGNATURE

    if [ $ret -ne 0 ]; then
        echo "系统未正常激活！"
        return 1
    fi

	[[ -z "$FEATURE_ID" || "$FEATURE_ID" = "0" ]] && return 0

	local config_hex=0x$(hexdump -v -s $((0x2008 + 256 + 8 + $EMBED_FACTORY_PART_OFFSET)) -n 4 -e '1/1 "%02x"' $eep_mtd)
	local config_dec=$((config_hex))

    if (( (config_dec & (1 << $FEATURE_ID)) != 0 )); then
        return 0
    else
        echo "该插件未获授权！"
        return 1
    fi
}

Include json.sh,fsyslog.sh,sqlite.sh,check_varl.sh

opensslmd5=$(md5sum $(which openssl) | cut -d ' ' -f 1)
ARCH=$(cat /etc/release | grep ARCH= | sed 's/ARCH=//g')

opensslstatus=0
[ $ARCH = "x86" -a "$opensslmd5" != "8dc48f57409edca7a781e6857382687b" ] && opensslstatus=1
[ $ARCH = "arm" -a "$opensslmd5" != "73b27bccb24fbf235e4cbe0fe80944b1" ] && opensslstatus=1
[ $ARCH = "mips" -a "$opensslmd5" != "2c7b4e5f15868e026c9227a7973b367b" ] && opensslstatus=1
if [ $opensslstatus -eq 1 ]; then
	echo "系统内核错误！"
	exit 1
fi

if [ "$ENABLE_FEATURE_CHECK" = "1" ]; then
	auth_plugin || exit 1
fi

Command $@

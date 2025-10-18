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
. $CRASHDIR/configs/ShellCrash.cfg

debug() {
	debuglog=$( [ -s /tmp/debug_on ] && cat /tmp/debug_on || echo -n /tmp/debug.log )
    if [ "$1" = "clear" ]; then
        rm -f $debuglog && return
    fi

    if [ -f /tmp/debug_on ]; then
        TIME_STAMP=$(date +"%Y%m%d %H:%M:%S")
        echo "[$TIME_STAMP]: PL> $1" >>$debuglog
    fi
}

boot(){

  # 设置最大打开文件数
  if [ "$ARCH" = "x86" ]; then
    memsize=$(awk '/MemTotal/{print $2}' /proc/meminfo)
    if [ "$memsize" -gt 3800000 ]; then
      sysctl -w fs.file-max=655350 >/dev/null 2>&1
      ulimit -n 327680 >/dev/null 2>&1
    else
      sysctl -w fs.file-max=150000 >/dev/null 2>&1
      ulimit -n 100000 >/dev/null 2>&1
    fi
  fi 

  isAdv=$(authtool check-plugin 6 >/dev/null 2>&1 && echo "true" || echo "false")

  settingFile=$CRASHDIR/configs/adv_settings.sh
  if [ "$isAdv" != "true" ] || [ ! -f "$settingFile" ]; then
      : > "$settingFile"
  fi

  defaultAdvSettings=(
    "denyLocalNet=0"
    "denyVideoData=0"
    "tcpOptimization=1"
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
      if ! grep -q "^$kname=" "$settingFile"; then
          echo "$advSetting" >> "$settingFile"
      fi
  done

  . "$settingFile"
}

boot

start() {

	firmwareVer=$(authtool version)
	if [ "$firmwareVer" -lt "202507100000" ]; then
		echo "当前插件框架版本过低，无法兼容本插件！请至作者云盘下载最新版固件，升级系统后再启动本插件！"
		return 1
	fi

	if [ -d "$EXT_PLUGIN_INSTALL_DIR/clash" ]; then
		echo "本插件和“小猫咪”插件不兼容！请先卸载小猫咪再启动本插件！"
		return 1
	fi

	debug "开始启动SK5服务..."

	handel_adv_settings
	monitor_tcp_traffic start

	pidof CrashCore >/dev/null && stop
	startCrashCore
	
	# 检查启动是否成功
	i=1
	db_port=$(cat $CRASHDIR/configs/ShellCrash.cfg | grep "hostdir" | cut -d ':' -f2 | cut -d '/' -f1)
	while [ -z "$test" -a "$i" -lt 5 ];do
		sleep 1
		test=$(curl -s http://127.0.0.1:${db_port}/configs --header "Authorization: Bearer $secret" | grep -o port)
		[ -n "$test" ] && break
		i=$((i+1))
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
	while true;do
		sleep 1
		pidof CrashCore >/dev/null || { success=1; break; }

		Vmen=$((Vmen + 1))
		[ $Vmen -gt 30 ] && break
	done

	if  [ $success -eq 1 ]; then
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
startCrashCore(){

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
  if ! grep -q "dns-hijack" $CRASHDIR/start.sh; then
    sed -i 's/auto-detect-interface: false/auto-detect-interface: false, dns-hijack: [tcp:\/\/203.0.113.1:53]/g' $CRASHDIR/start.sh
  fi
  
  # Chroot下启动CrashCore
  ps | grep socks5/bin/menu.sh | grep -v grep | awk '{print $1}' | xargs -r kill -9
  chrootmgt run "$CRASHDIR/menu.sh -s start >/dev/null"

  mv -f $CRASHDIR/yamls/rules.yaml.bk $CRASHDIR/yamls/rules.yaml
  mv -f $CRASHDIR/yamls/proxies.yaml.bk $CRASHDIR/yamls/proxies.yaml

  # 还原start.sh配置
  sed -i 's/, dns-hijack: \[tcp:\/\/203\.0\.113\.1:53\]//g' $CRASHDIR/start.sh
}
stopCrashCore(){
  ps | grep socks5/bin/menu.sh | grep -v grep | awk '{print $1}' | xargs -r kill -9
  chrootmgt run "$CRASHDIR/menu.sh -s stop >/dev/null"
}
restart(){
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
  if [ -n "${1}" ]; then
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
	sed 's/^/  /' "$CRASHDIR/yamls/proxies.yaml" >/tmp/proxies_indented1
	sed -i "/^proxies:/r /tmp/proxies_indented1" $CHROOTDIR/tmp/ShellCrash/config.yaml

	# 根据高级配置打开或关闭节点的tfo功能
	if [ "$tcpOptimization" = "1" ]; then
		sed -i "s/tfo: false/tfo: true/g" $CHROOTDIR/tmp/ShellCrash/config.yaml
	else
		sed -i "s/tfo: true/tfo: false/g" $CHROOTDIR/tmp/ShellCrash/config.yaml
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
		server_name=$(echo "$cleaned_line" | awk -F ',' '{print $1}' |awk -F':' '{print $2}' | sed 's/[[:space:]]//g' )
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
	while IFS= read -r line || [ -n "$line" ]; do
		cleaned_line=$(echo "$line" | sed 's/^[[:space:]]*//g' | sed 's/[[:space:]]//g')
		[ -z "$cleaned_line" ] && continue
		server_name=$(echo "$cleaned_line" | awk -F ',' '{print $3}')

		if ! grep -q "name: ${server_name}," $CRASHDIR/yamls/proxies.yaml; then
			line=$(echo "$line" | sed "s/,${server_name}/,REJECT/g")
		fi
		sed -i "/^rules:/a\ $line" $CHROOTDIR/tmp/ShellCrash/config.yaml

	done <$CRASHDIR/yamls/rules.yaml
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
			iptables -w -t mangle -C OUTPUT -p tcp -d "$ip" -j MARK --set-mark 7892 || \
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
			echo "$msg" >> $LOGFILE
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
		iptables -C FORWARD -p tcp -s "$address_ip" -m mark ! --mark $tcpMark -j DROP 2>/dev/null || \
		iptables -A FORWARD -p tcp -s "$address_ip" -m mark ! --mark $tcpMark -j DROP

    iptables -C FORWARD -p udp -s "$address_ip" -m mark ! --mark 7892 -j DROP 2>/dev/null || \
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
add_guard_task(){
    cron_check=`cat /etc/crontabs/root | grep "SK5守护进程" | wc -l`
    if [ $cron_check -eq 0 ]; then
        cronTask="* * * * * test -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autostart" && test -z \"\$(pidof CrashCore)\" && /usr/ikuai/function/plugin_socks5 start #SK5守护进程"
        echo "$cronTask" >>/etc/crontabs/cron.d/socks5
        echo  "$cronTask" >>/etc/crontabs/root
        crontab /etc/crontabs/root
    fi

    crondproc=`ps | grep crond | grep -v grep | wc -l`
    if [ $crondproc -eq 0 ]; then
        crond -L /dev/null
    fi
}
remove_guard_task() { 
    cron_check=`cat /etc/crontabs/root | grep "SK5守护进程" | wc -l`
    if [ $cron_check -gt 0 ]; then
        sed -i /SK5守护进程/d /etc/crontabs/cron.d/socks5
        sed -i /SK5守护进程/d /etc/crontabs/root
        crontab /etc/crontabs/root
    fi
}
monitor_tcp_traffic(){
	action=$1
	if [ "$action" = "start" ]; then
		sk5cro=`cat /etc/crontabs/root | grep "SK5流量监测" | wc -l`
		if [ $sk5cro -eq 0 ]; then
			cronTask="*/10 * * * * /usr/ikuai/function/plugin_socks5 monitor_tcp_traffic >/dev/null 2>&1 #SK5流量监测"
			echo "$cronTask" >>/etc/crontabs/cron.d/socks5
			echo  "$cronTask" >>/etc/crontabs/root
			crontab /etc/crontabs/root
		fi

		crondproc=`ps | grep crond | grep -v grep | wc -l`
		if [ $crondproc -eq 0 ]; then
			crond -L /dev/null
		fi

	elif [ "$action" = "stop" ]; then 
		cron_check=`cat /etc/crontabs/root | grep "SK5流量监测" | wc -l`
		if [ $cron_check -gt 0 ]; then
			sed -i /SK5流量监测/d /etc/crontabs/cron.d/socks5
			sed -i /SK5流量监测/d /etc/crontabs/root
			crontab /etc/crontabs/root
		fi
	else
		if pidof CrashCore >/dev/null && grep "networkMonitoring=1" $CRASHDIR/configs/adv_settings.sh >/dev/null; then
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
	check_seconds=$1      # 第一个参数：检查时间窗口（秒）
	filter_proto=$2       # 第二个参数：可选，"tcp"、"udp" 或 "all"

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
			delta=$(( now - start_ts ))
			if [ "$delta" -le "$check_seconds" ]; then
				total=$(( total + upload + download ))
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
        unit="TB"; value=$((bytes * 10 / 1099511627776))
    elif [ "$bytes" -ge 1073741824 ]; then
        unit="GB"; value=$((bytes * 10 / 1073741824))
    elif [ "$bytes" -ge 1048576 ]; then
        unit="MB"; value=$((bytes * 10 / 1048576))
    elif [ "$bytes" -ge 1024 ]; then
        unit="KB"; value=$((bytes * 10 / 1024))
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

	File=$(cat "$CRASHDIR/configs/server.tmp" | tr -d '[:space:]')
	[ -z "$File" ] && return

	awks1=$(grep "," $CRASHDIR/configs/server.tmp | wc -l)
	awks2=$(grep ":" $CRASHDIR/configs/server.tmp | wc -l)
	awks3=$(grep "\/" $CRASHDIR/configs/server.tmp | wc -l)
	awkF='|'
	[ $awks1 -gt 0 ] && awkF=','
	[ $awks2 -gt 0 ] && awkF=':'
	[ $awks3 -gt 0 ] && awkF='\/'

	[ $replace == "true" ] && >$CRASHDIR/yamls/proxies.yaml
	
		local index=1
  [ -n "$autoNodeNameStartIndex" ] && index=$autoNodeNameStartIndex
	names=()
	while IFS= read -r line || [ -n "$line" ]; do

		local name="" server="" port=""
		if [ "$type" == "others" ]; then
			cleanline=$(printf '%s' "$line" | sed "s/['\"$&; \n\r]//g")
			name=iKuai_$(echo "$cleanline" | sed -n 's/.*\bname:\([^,]*\).*/\1/p')
			[ "$name" = "iKuai_" ] && continue

			# 按逗号切分
			OLDIFS=$IFS
			IFS=','
			newline=""
			for field in $line; do
				field=$(echo "$field" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')  # 去掉前后空格
				key=$(printf "%s\n" "$field" | cut -d':' -f1 | sed 's/[[:space:]]*$//')
				value=$(printf "%s\n" "$field" | cut -d':' -f2- | sed 's/^[[:space:]]*//')

				[ "$key" = "name" ] && value=$name

				# 重新拼成 key: value
				if [ -n "$newline" ]; then
					newline="$newline, $key: $value"
				else
					newline="$key: $value"
				fi
			done

  	  if [ "$disableUdp" = "1" ]; then
        configLine="- {${newline}, tfo: true, udp: false}"
      else
        configLine="- {${newline}, tfo: true, udp: true}"
      fi
			IFS=$OLDIFS
		else
			line=$(printf '%s' "$line" | sed "s/['\"$&; \n\r]//g")
			[ -z "$line" ] && continue
					
			server=$(echo $line | awk -F "$awkF" '{print $1}')
			port=$(echo $line | awk -F "$awkF" '{print $2}')
			username=$(echo $line | awk -F "$awkF" '{print $3}')
			password=$(echo $line | awk -F "$awkF" '{print $4}')
			name=$(echo $line | awk -F "$awkF" '{print $5}')

			[ -z "$server" -o -z "$port" ] && continue
			[ -z "$name" -a "$autoNodeName" != "true" ] && continue

			[ "$autoNodeName" == "true" ] && name="iKuai_${type}-node${index}" || name=iKuai_${name}
			index=$(($index + 1))

			names+=("$name")

			# socks5对应参数字符串格式为：name|server|port|username|password|interface-name|dialer-proxy
			# ssr对应参数字符串格式为：name|server|port|cipher|password|interface-name|dialer-proxy
			configString="$name|$server|$port|$username|$password||"
			configLine=$(generate_server_config $type $configString)
		fi

		escaped_configLine=$(printf '%s\n' "$configLine" | sed -e 's/[\/&]/\\&/g')
		if grep -q "name: $name," "$CRASHDIR/yamls/proxies.yaml"; then
			# 替换整行内容（含该节点名称的行）
			sed -i "s/^.*name: $name,.*\$/$escaped_configLine/" "$CRASHDIR/yamls/proxies.yaml"
		else
			echo $configLine >>$CRASHDIR/yamls/proxies.yaml
		fi

	done <$CRASHDIR/configs/server.tmp

	ret=0
	patch_server_config || ret=1
	patch_rules_config || ret=1
	reload_config || ret=1
  for name in "${names[@]}"; do 
    clear_connections_byserver $name
  done
  return $ret
}
generate_server_config() {
	local type=$1
	local configString=$2
	local name="" server="" port="" username="" cipher="" password="" interfaceName="" dialerProxy="" default=""
  local udpEnable="true"

  [ "$disableUdp" = "1" ] && udpEnable="false"

	# 格式化节点配置，$1 为节点类型，$2 为节点参数字符串
	# socks5对应参数字符串格式为：name|server|port|username|password|interface-name|dialer-proxy
	# ssr对应参数字符串格式为：name|server|port|cipher|password|interface-name|dialer-proxy
	case $type in 
		socks5)
			IFS='|' read -r name server port username password interfaceName dialerProxy <<< "$configString" 
			name="name: $name, "
			server="server: $server, "
			port="port: $port, "
			[ -n "$username" ] && username="username: $username, "
			[ -n "$password" ] && password="password: $password, "
			[ -n "$interfaceName" ] && interfaceName="interface-name: $interfaceName, "
			[ -n "$dialerProxy" ] && dialerProxy="dialer-proxy: iKuai_$dialerProxy, "
			default="type: socks5, tfo: true, udp: $udpEnable"
			echo "- {$name$server$port$username$password$interfaceName$dialerProxy$default}"
			return 0
			;;
		ss) 
			IFS='|' read -r name server port cipher password interfaceName dialerProxy <<< "$configString"
			name="name: $name, "
			server="server: $server, "
			port="port: $port, "
			[ -n "$cipher" ] && cipher="cipher: ${cipher,,}, "
			[ -n "$password" ] && password="password: $password, "
			[ -n "$interfaceName" ] && interfaceName="interface-name: $interfaceName, "
			[ -n "$dialerProxy" ] && dialerProxy="dialer-proxy: iKuai_$dialerProxy, "
			default="type: ss, tfo: true, udp: $udpEnable"
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
		echo "$address_ip" >> $CRASHDIR/configs/ip_filter
	fi

	# 添加分流规则，如果存在该IP则替换
	if grep -q "$address_ip" $CRASHDIR/yamls/rules.yaml; then
		escaped_ip="${address_ip//\//\\/}"
		sed -i "s/^.*$escaped_ip.*\$/- SRC-IP-CIDR,$escaped_ip,$name_sk/" $CRASHDIR/yamls/rules.yaml
	else
		echo "- SRC-IP-CIDR,$address_ip,$name_sk" >> $CRASHDIR/yamls/rules.yaml
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

	if grep -q ${address_ip//\//\\\/} $CRASHDIR/configs/disabled_ips; then
		sed -i "/${address_ip//\//\\\/}/d" $CRASHDIR/configs/disabled_ips
		iptables -t nat -D shellcrash -s $address_ip -j RETURN >/dev/null 2>&1
		iptables -w -t mangle -D shellcrash_mark -s $address_ip -j RETURN >/dev/null 2>&1
	else
		echo $address_ip >>$CRASHDIR/configs/disabled_ips
		iptables -t nat -I shellcrash -s $address_ip -j RETURN >/dev/null 2>&1
		iptables -w -t mangle -I shellcrash_mark -s $address_ip -j RETURN >/dev/null 2>&1
	fi

	clear_connections "$address_ip"
	return 0
}
switch_clients_enable() {

	IFS=',' read -ra rows <<<"$rowIndexes"
	IFS=',' read -ra ips <<<"$address_ips"

	for i in "${!rows[@]}"; do
		address_ip=${ips[$i]}
		switch_client_enable
	done
	
	return 0
}
import_clients() {
	echo "$configContent" | base64 -d >$CRASHDIR/configs/client.tmp

	File=$(cat "$CRASHDIR/configs/client.tmp" | tr -d '[:space:]')
	[ -z "$File" ] && return

	awks1=$(grep "," $CRASHDIR/configs/client.tmp | wc -l)
	awks2=$(grep ":" $CRASHDIR/configs/client.tmp | wc -l)
	awks3=$(grep "\/" $CRASHDIR/configs/client.tmp | wc -l)
	awkF='|'
	[ $awks1 -gt 0 ] && awkF=','
	[ $awks2 -gt 0 ] && awkF=':'
	[ $awks3 -gt 0 ] && awkF='\/'

	if [ "$replace" == "true" ]; then
		rm $CRASHDIR/yamls/rules.yaml -f
		echo 203.0.113.1 >$CRASHDIR/configs/ip_filter
	fi
  
  ips=()
	while IFS= read -r line || [ -n "$line" ]; do
		line=$(printf '%s' "$line" | sed "s/['\"$&; \n\r]//g")
		address_ip=$(echo $line | awk -F "$awkF" '{print $1}')
		name_sk=$(echo $line | awk -F "$awkF" '{print $2}')
    ips+=("$address_ip")
		save_client "internal-call"

	done <$CRASHDIR/configs/client.tmp
	
	ret=0
	patch_rules_config || ret=1
	reload_config || ret=1
  for ip in "${ips[@]}"; do 
    clear_connections $ip
  done
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
	echo "$configTxt" > $configpath

	# 断开现有连接
	clear_connections
	patch_rules_config
	reload_config
}
# 高级设置相关方法
save_adv_settings () {

  if [ "$isAdv" != "true" ]; then
	     echo "UNAUTHORIZED"
		 return 1
  fi
	
	# 禁止本地直连
	sed -i "/denyLocalNet=/d" $CRASHDIR/configs/adv_settings.sh 
	echo "denyLocalNet=$denyLocalNet" >>$CRASHDIR/configs/adv_settings.sh

	# 屏蔽视频流量
	sed -i "/denyVideoData=/d" $CRASHDIR/configs/adv_settings.sh 
	echo "denyVideoData=$denyVideoData" >>$CRASHDIR/configs/adv_settings.sh

	# TCP优化：TUN模式还是混合模式
	sed -i "/tcpOptimization=/d" $CRASHDIR/configs/adv_settings.sh 
	echo "tcpOptimization=$tcpOptimization" >>$CRASHDIR/configs/adv_settings.sh

  
  # 节点是否开启UTP
	sed -i "/disableUdp=/d" $CRASHDIR/configs/adv_settings.sh 
	echo "disableUdp=$disableUdp" >>$CRASHDIR/configs/adv_settings.sh

	# 域名嗅探
	sed -i "/domainSniffing=/d" $CRASHDIR/configs/adv_settings.sh
	echo "domainSniffing=$domainSniffing" >>$CRASHDIR/configs/adv_settings.sh
	
	# DNS模式
	sed -i "/dnsmode=/d" $CRASHDIR/configs/adv_settings.sh
	echo "dnsmode=$dnsmode" >>$CRASHDIR/configs/adv_settings.sh

	# 禁止QUIC流量
	sed -i "/rejectQUIC=/d" $CRASHDIR/configs/adv_settings.sh
	echo "rejectQUIC=$rejectQUIC" >>$CRASHDIR/configs/adv_settings.sh
	
	# 跳过国内地址
	sed -i "/bypassCNIP=/d" $CRASHDIR/configs/adv_settings.sh
	echo "bypassCNIP=$bypassCNIP" >>$CRASHDIR/configs/adv_settings.sh

	# 网络流量监控
	sed -i "/networkMonitoring=/d" $CRASHDIR/configs/adv_settings.sh
	echo "networkMonitoring=$networkMonitoring" >>$CRASHDIR/configs/adv_settings.sh

	# DNS解析节点
	sed -i "/dnsResolveNodes=/d" $CRASHDIR/configs/adv_settings.sh
	echo "dnsResolveNodes=\"$dnsResolveNodes\"" >>$CRASHDIR/configs/adv_settings.sh

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

get_admessage_async() {
  admessage_file="$CRASHDIR/configs/admsg"
  if [ ! -f "$admessage_file" ] || [ $(( $(date +%s) - $(stat -c %Y "$admessage_file") )) -gt 3600 ]; then
      # 异步下载, 防止卡死
      curl -fsSL -o "$admessage_file" "$RMT_PLUGIN_BASE_URL/admessage2.txt" 2>/dev/null &
  fi
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

	version=$(jq -r '.version' /usr/ikuai/www/plugins/$PLUGIN_NAME/metadata.json)
  allowRenew=$(cat /etc/mnt/plugins/configs/.renew.info 2>/dev/null | cut -d '|' -f 1) 
  [ "$allowRenew" = "1" ] && isTry="false" || isTry="true"

	if killall -q -0 CrashCore; then
		local status=1

		local start_time=$(cat ${CHROOTDIR}/tmp/ShellCrash/crash_start_time)
		if [ -n "$start_time" ]; then 
			time=$((`date +%s`-start_time))
			day=$((time/86400))
			[ "$day" = "0" ] && day='' || day="$day天"
			time=`date -u -d @${time} +%H小时%M分%S秒`
			runningStatus="已运行: ${day}${time}"
		else 
			runningStatus="已运行: 0小时0分1秒"
		fi
	fi

  adMessage=$(cat $CRASHDIR/configs/usradmsg 2>/dev/null )
  if [ -z "$adMessage" ]; then
    if [ "$isTry" = "true" ]; then
      adMessage=$(sed -n '1p' $CRASHDIR/configs/admsg 2>/dev/null)
    else
      adMessage=$(sed -n '2p' $CRASHDIR/configs/admsg 2>/dev/null)
    fi
    get_admessage_async
  fi

	json_append __json_result__ status:int
	json_append __json_result__ runningStatus:str
	json_append __json_result__ version:str
  json_append __json_result__ adMessage:str
	json_append __json_result__ isAdv:str
  json_append __json_result__ isTry:str
}
__show_client() {

	id=1 clients=""
	while IFS= read -r line; do
    [ -z "$line" ] && continue
		address_ip=$(echo $line | awk -F "," '{print $2}')
		address_ip=${address_ip%/32}
		name_sk=$(echo $line | awk -F "," '{print $3}')
		name_sk=${name_sk#iKuai_}

		if grep -q ${address_ip//\//\\\/} $CRASHDIR/configs/disabled_ips; then
			status='已停用'
		else
			status='已启用'
		fi

		_json=$(json_output id:int address_ip:str name_sk:str status:str)
		clients+="${clients:+,}$_json"

		id=$((id + 1))
	done <$CRASHDIR/yamls/rules.yaml
	clients="[$clients]"
  json_append __json_result__ clients:json
}
__show_server() {

	id=1 servers=""
	while IFS= read -r line; do
    [ -z "$line" ] && continue
		interfacename="默认"
		dialer="无"
		name="" address="" Port="" type="" user="" password=""
		cleaned_line=$(echo "$line" | sed 's/^[[:space:]]*-\s*//g' | sed 's/[[:space:]]//g' | sed 's/{//g' | sed 's/}//g')
		IFS=',' read -ra fields <<<"$cleaned_line"
		for field in "${fields[@]}"; do
			# 提取键和值（兼容值中包含冒号）
			key="${field%%:*}"
			value="${field#*:}"
			case "$key" in
			name) name="${value#iKuai_}" ;;
			server) address="$value" ;;
			port) Port="$value" ;;
			type) type="$value" ;;
			username) user="$value" ;;
			cipher) user="$value" ;; # 注意：cipher 和 username 均赋值给 user
			password) password="$value" ;;
			interface-name) interfacename="$value" ;;
			dialer-proxy) dialer="$value" ;;
			esac
		done
		[ -n "$interfacename" ] && interfaceOrDialer="$interfacename" || interfaceOrDialer="$dialer" 
		
		_json=$(json_output id:int name:str address:str Port:str type:str user:str password:str interfacename:str dialer:str)
    servers+="${servers:+,}$_json"

		id=$((id + 1))
	done <$CRASHDIR/yamls/proxies.yaml
	servers="[$servers]"
  json_append __json_result__ servers:json
}
__show_serverDelay() {
	url="http://127.0.0.1:9999/proxies/iKuai_${servername}/delay?url=https%3A%2F%2Fwww.gstatic.com%2Fgenerate_204&timeout=2000" 
	data=$(curl -X GET "$url" --header "Authorization: Bearer $secret")

	[ $? -ne 0 ] && data="{}"

	serverDelay=$(echo "$data" | jq -r '.delay')

	if [ -z "$serverDelay" ] || [ "$serverDelay" = "null" ]; then
    serverDelay="-1"
  else
    serverDelay=$((serverDelay/2))
  fi
	
	json_append __json_result__ serverDelay:str
}
__show_trafficInfo() {
	local trafficInfo=$(format_bytes $(get_total_traffic 3600))
	trafficInfo="过去1小时流量: $trafficInfo"
	json_append __json_result__ trafficInfo:str
}
__show_domain_whitelist(){
	
	local domainwhitelist=""

	if [ -f "$CRASHDIR/ruleset/direct_domains.txt" ]; then
		domainwhitelist=$(cat $CRASHDIR/ruleset/direct_domains.txt  | base64 | tr -d '\n')
	fi

	json_append __json_result__ domainwhitelist:str
}
__show_ip_whitelist(){
	
	local ipwhitelist=""

	if [ -f "$CRASHDIR/ruleset/direct_ips.txt" ]; then
		ipwhitelist=$(cat $CRASHDIR/ruleset/direct_ips.txt  | base64 | tr -d '\n')
	fi

	json_append __json_result__ ipwhitelist:str
}
__show_adv_settings() { 

	local adv_settings=""
	json_append adv_settings denyLocalNet:str
	json_append adv_settings denyVideoData:str
	json_append adv_settings tcpOptimization:str
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
	echo "$suburl" | grep -E -q '^https?:\/\/[a-zA-Z0-9.-]+(:[0-9]+)?(\/[a-zA-Z0-9._~:/?#@!$&*+=%-]*)?$'
    if [ $? -ne 0 ]; then
		echo "{\"ErrMsg\":\"订阅地址格式不正确！\"}"
		return 1
	fi

	nodeconfig=$(get_subconfig $suburl)

	if [ -z "$nodeconfig" ]; then
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

	config=""  # tobe defined later

	nodelist=""
	rtVal=1

    for Server in "${Servers[@]}"; do
      # url="${Server}/sub?target=clash&insert=false&list=true&emoji=false&sort=true&scv=true&fdn=true&udp=true&tfo=true&new_name=true&url=${suburl}&config=${config}"
      url="${Server}/sub?target=clash&insert=false&list=true&emoji=false&sort=true&scv=true&fdn=true&new_name=true&url=${suburl}&config=${config}"
      # udp: true, tfo: true

      nodelist=$(curl -fsSL --max-time 10 $url 2>/dev/null)
          
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

restore(){

  if [ "$isAdv" != "true" ]; then
	     echo "UNAUTHORIZED"
		 return 1
  fi

  if ! openssl aes-128-cbc -in /tmp/iktmp/import/file -out /tmp/iktmp/import/file.tar -k "ikuai.socks5" -d >/dev/null 2>/dev/null ;then
    rm -f /tmp/iktmp/import/*
    echo "恢复失败,文件错误！！"
    exit 1
  fi

  tar -xf  /tmp/iktmp/import/file.tar -C $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME
  pidof CrashCore >/dev/null && restart
  exit 0

}


__show_backups(){

  rm /tmp/iktmp/export/* -rf
  TIME_Name=SK5BK-$(date +"%Y%m%d%H%M%S")
  tar -cf /tmp/iktmp/export/$TIME_Name-config.tar -C $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME .

  openssl aes-128-cbc -in /tmp/iktmp/export/$TIME_Name-config.tar -out  /tmp/iktmp/export/$TIME_Name.config -k "ikuai.socks5" -e

  FileName=$TIME_Name.config
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

if [ "$ENABLE_FEATURE_CHECK" = "1" ]; then
	auth_plugin || exit 1
fi

Command $@

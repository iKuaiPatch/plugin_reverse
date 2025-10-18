需要读取下面的  "TailscaleIPs": [    "100.104.58.51",    "fd7a:115c:a1e0::ef01:3a34"] 100.104.58.51为IPV4  ,fd7a:115c:a1e0::ef01:3a34 为VPV6

BackendState
AuthURL
DisplayName

# 提取字段并赋值给变量
TailscaleIPs=$(./tailscale status --json | jq -r '.TailscaleIPs | join(", ")')
BackendState=$(./tailscale status --json | jq -r '.BackendState')
AuthURL=$(./tailscale status --json | jq -r '.AuthURL')
DisplayName=$(./tailscale status --json | jq -r '.Self.DisplayName')

# 分别提取 IPv4 和 IPv6
IPv4=$(echo $TailscaleIPs | cut -d, -f1 | xargs)
IPv6=$(echo $TailscaleIPs | cut -d, -f2 | xargs)

# 输出结果
echo "TailscaleIPs: $TailscaleIPs"
echo "IPv4: $IPv4"
echo "IPv6: $IPv6"
echo "BackendState: $BackendState"
echo "AuthURL: $AuthURL"
echo "DisplayName: $DisplayName"








# 执行一次命令并将输出存储在变量中
output=$(tailscale status --json)

# 提取字段
TailscaleIPs=$(echo "$output" | jq -r '.TailscaleIPs | join(", ")')
BackendState=$(echo "$output" | jq -r '.BackendState')
AuthURL=$(echo "$output" | jq -r '.AuthURL')
DisplayName=$(echo "$output" | jq -r '.Self.DisplayName')

# 分别提取 IPv4 和 IPv6
IPv4=$(echo "$TailscaleIPs" | cut -d, -f1 | xargs)
IPv6=$(echo "$TailscaleIPs" | cut -d, -f2 | xargs)

# 输出结果
echo "TailscaleIPs: $TailscaleIPs"
echo "IPv4: $IPv4"
echo "IPv6: $IPv6"
echo "BackendState: $BackendState"
echo "AuthURL: $AuthURL"
echo "DisplayName: $DisplayName"

重新命名
/usr/sbin/tailscale up --reset --hostname ikuai-test






get_config() {
	config_get_bool enabled $1 enabled 1
	config_get_bool acceptRoutes $1 acceptRoutes 0
	config_get loginServer $1 loginServer ""
	config_get authkey $1 authkey ""
	config_get hostname $1 hostname ""
	config_get advertiseRoutes $1 advertiseRoutes ""
}
start_service() {
	logger -t tailscaler 'start_service'
	config_load tailscaler
	config_foreach get_config settings
	if [ "$enabled" != 1 ]; then
		stop_service
		return 1
	fi
	#
	logger -t tailscaler 'start tailscale'
	/etc/init.d/tailscale running || /etc/init.d/tailscale start
	logger -t tailscaler 'start tailscaler'
	# 
	procd_open_instance
	procd_set_param command /usr/sbin/tailscale up --reset
	if [ -n "$loginServer" ]; then
		procd_append_param command --login-server "$loginServer" 
	fi
	if [ -n "$authkey" ]; then
		procd_append_param command --authkey "$authkey" 
	fi
	if [ -n "$hostname" ]; then
		procd_append_param command --hostname "$hostname" 
	fi
	if [ "$acceptRoutes" = 1 ]; then
		procd_append_param command --accept-routes true
	fi
	if [ -n "$advertiseRoutes" ];then
		procd_append_param command --advertise-routes "$advertiseRoutes"
	fi
	procd_set_param stdout 1
	procd_set_param stderr 1
	procd_close_instance
	logger -t tailscaler 'end tailscaler'
}
stop_service() {
	/etc/init.d/tailscale stop
	/etc/init.d/tailscale running && sleep 2
}


./tailscale status --json
{
  "Version": "1.76.1-ERR-BuildInfo",
  "TUN": true,
  "BackendState": "Running",
  "HaveNodeKey": true,
  "AuthURL": "",
  "TailscaleIPs": [
    "100.104.58.51",
    "fd7a:115c:a1e0::ef01:3a34"
  ],
  "Self": {
    "ID": "nRJT1utJ3i11CNTRL",
    "PublicKey": "nodekey:3149cf6776e5b36a94e4413bf12161bbabf5c7efe1f86ea629c61c0a74c3e40d",
    "HostName": "iKuai",
    "DNSName": "ikuai-1.tail1fb5f0.ts.net.",
    "OS": "linux",
    "UserID": 5728873853606505,
    "TailscaleIPs": [
      "100.104.58.51",
      "fd7a:115c:a1e0::ef01:3a34"
    ],
    "AllowedIPs": [
      "100.104.58.51/32",
      "fd7a:115c:a1e0::ef01:3a34/128"
    ],
    "Addrs": [
      "27.44.180.0:7316",
      "27.44.180.0:41641",
      "27.44.180.0:7315",
      "27.44.180.0:7321",
      "27.44.180.0:7330",
      "192.168.1.1:41641",
      "192.168.237.138:41641"
    ],
    "CurAddr": "",
    "Relay": "sea",
    "RxBytes": 0,
    "TxBytes": 0,
    "Created": "2024-10-31T13:58:41.960578707Z",
    "LastWrite": "0001-01-01T00:00:00Z",
    "LastSeen": "0001-01-01T00:00:00Z",
    "LastHandshake": "0001-01-01T00:00:00Z",
    "Online": true,
    "ExitNode": false,
    "ExitNodeOption": false,
    "Active": false,
    "PeerAPIURL": [
      "http://100.104.58.51:64741",
      "http://[fd7a:115c:a1e0::ef01:3a34]:39401"
    ],
    "Capabilities": [
      "HTTPS://TAILSCALE.COM/s/DEPRECATED-NODE-CAPS#see-https://github.com/tailscale/tailscale/issues/11508",
      "https://tailscale.com/cap/file-sharing",
      "https://tailscale.com/cap/is-admin",
      "https://tailscale.com/cap/ssh",
      "https://tailscale.com/cap/tailnet-lock",
      "probe-udp-lifetime",
      "ssh-behavior-v1",
      "ssh-env-vars",
      "store-appc-routes"
    ],
    "CapMap": {
      "https://tailscale.com/cap/file-sharing": null,
      "https://tailscale.com/cap/is-admin": null,
      "https://tailscale.com/cap/ssh": null,
      "https://tailscale.com/cap/tailnet-lock": null,
      "probe-udp-lifetime": null,
      "ssh-behavior-v1": null,
      "ssh-env-vars": null,
      "store-appc-routes": null
    },
    "InNetworkMap": true,
    "InMagicSock": false,
    "InEngine": false,
    "KeyExpiry": "2025-04-29T14:56:43Z"
  },
  "Health": [],
  "MagicDNSSuffix": "tail1fb5f0.ts.net",
  "CurrentTailnet": {
    "Name": "zlz386515350@gmail.com",
    "MagicDNSSuffix": "tail1fb5f0.ts.net",
    "MagicDNSEnabled": true
  },
  "CertDomains": null,
  "Peer": {
    "nodekey:2e5da79d7263bcc403688cf094599e81ca6ba27a7ab9547a90cf380a0f27b639": {
      "ID": "nYNNjYYJCN11CNTRL",
      "PublicKey": "nodekey:2e5da79d7263bcc403688cf094599e81ca6ba27a7ab9547a90cf380a0f27b639",
      "HostName": "iStoreOS",
      "DNSName": "istoreos.tail1fb5f0.ts.net.",
      "OS": "linux",
      "UserID": 5728873853606505,
      "TailscaleIPs": [
        "100.103.182.58",
        "fd7a:115c:a1e0::f01:b63a"
      ],
      "AllowedIPs": [
        "100.103.182.58/32",
        "fd7a:115c:a1e0::f01:b63a/128"
      ],
      "Addrs": null,
      "CurAddr": "",
      "Relay": "lax",
      "RxBytes": 0,
      "TxBytes": 0,
      "Created": "2024-10-31T13:46:05.921571876Z",
      "LastWrite": "0001-01-01T00:00:00Z",
      "LastSeen": "0001-01-01T00:00:00Z",
      "LastHandshake": "0001-01-01T00:00:00Z",
      "Online": true,
      "ExitNode": false,
      "ExitNodeOption": false,
      "Active": false,
      "PeerAPIURL": [
        "http://100.103.182.58:54331",
        "http://[fd7a:115c:a1e0::f01:b63a]:58281"
      ],
      "InNetworkMap": true,
      "InMagicSock": true,
      "InEngine": false,
      "KeyExpiry": "2025-04-29T13:46:06Z"
    }
  },
  "User": {
    "5728873853606505": {
      "ID": 5728873853606505,
      "LoginName": "zlz386515350@gmail.com",
      "DisplayName": "Lock Num",
      "ProfilePicURL": "https://lh3.googleusercontent.com/a/ACg8ocLunR1IgBQX59jHzBujYjJTWLxPMZ3WrHPGeywthzTcGrmkIfY=s96-c",
      "Roles": []
    }
  },
  "ClientVersion": null
}
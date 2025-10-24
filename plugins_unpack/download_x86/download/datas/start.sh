#!/bin/bash
if [ ! -f /tmp/download_ad/stop ];then
exit
fi
ip_rule(){
    # 读取当前的路由表，排除 default 和 lan，并确保唯一性
 ROUTES=$(ip route show | grep -v 'default' | grep -v 'lan' | grep -v 'zthnhpt5cu' | grep -v 'utun'| grep -v 'pptp'| grep -v 'pptp'| grep -v 'tailscale0' | sort | uniq)
# 获取当前的 ip rule 列表
RULES=$(ip rule show)
# 遍历所有的路由条目
echo "$ROUTES" | while read -r route; do
	# 提取 src 地址和接口名称
	SRC_IP=$(echo "$route" | awk '{for(i=1;i<=NF;i++) if ($i=="src") print $(i+1)}')
	INTERFACE=$(echo "$route" | awk '{print $3}')

	# 如果没有提取到 src 或接口，则跳过此条目
	if [ -z "$SRC_IP" ] || [ -z "$INTERFACE" ]; then
		continue
	fi
	# 检查是否已经存在该 src 地址的规则
	if echo "$RULES" | grep -q "from $SRC_IP"; then
		echo "Rule for $SRC_IP already exists" >> /tmp/ip_rule.log
	else
		# 添加 ip rule，使用 src 地址和接口名称
		ip rule add from $SRC_IP table $INTERFACE
		if [ $? <> 0 ];then
		#如果是每个网口为真实网口可能出错，修正！！
			INTERFACE2=`echo $INTERFACE|awk -F "_" '{print $1}'`
			ip rule add from $SRC_IP table $INTERFACE2
		fi
	fi
done
}
ip_rule

task_config="/etc/mnt/download/download_tasks"  # 任务配置文件夹
noe_task_config="/etc/mnt/download/noe_download_tasks" #单接口
ds_task_config="/etc/mnt/download/download_ds_tasks"  # 任务配置文件夹
bash $task_config/*.sh
bash $noe_task_config/*.sh
cp  $ds_task_config/download_* /etc/crontabs/cron.d/
killall crond 
rm /etc/crontabs/root
sh -c 'for file in /etc/crontabs/cron.d/*; do cat "$file" >> /etc/crontabs/root; done'
crond -L /dev/null
rm /etc/mnt/download/stop -rf
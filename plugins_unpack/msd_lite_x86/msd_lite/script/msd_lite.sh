#!/bin/bash /etc/ikcommon 

script_path=$(readlink -f "${BASH_SOURCE[0]}")
plugin_dir=$(dirname "$script_path")

md5sum $plugin_dir/../data/msd_lite | awk '{print $1}' | grep -qf $plugin_dir/md5s || exit

if [ ! -f /usr/sbin/msd_lite1 ];then

ln -s $plugin_dir/../data/msd_lite /usr/sbin/msd_lite1
chmod +x $plugin_dir/../data/msd_lite1
fi

if [ ! -f /usr/sbin/msd_lite2 ];then
ln -s $plugin_dir/../data/msd_lite /usr/sbin/msd_lite2
chmod +x $plugin_dir/../data/msd_lite2
fi


start(){

if [ -f /etc/mnt/msd_lite1 ];then
msd_lite1 -c $plugin_dir/../data/msd_lite.conf >/dev/null &
fi

if [ -f /etc/mnt/msd_lite2 ];then
msd_lite2 -c $plugin_dir/../data/msd_lite2.conf >/dev/null &
fi

}



start1(){

if [ -f /etc/mnt/msd_lite1 ];then
msd_lite1 -c $plugin_dir/../data/msd_lite.conf >/dev/null &
fi

}

start2(){

if [ -f /etc/mnt/msd_lite2 ];then
msd_lite2 -c $plugin_dir/../data/msd_lite2.conf >/dev/null &
fi

}

app_start(){

if killall -q -0 msd_lite1;then
	killall msd_lite1
	return
fi


echo "1" >/etc/mnt/msd_lite1

start1

}

app_start2(){

if killall -q -0 msd_lite2;then
	killall msd_lite2
	return
fi


echo "1" >/etc/mnt/msd_lite2

start2

}

stop(){
killall msd_lite1
rm etc/mnt/msd_lite1
}

stop2(){
killall msd_lite2
rm etc/mnt/msd_lite2

}

config(){
echo "1" >>/tmp/npsconfig.log
 if [ -f /tmp/iktmp/import/file ]; then
   filesize=$(stat -c%s "/tmp/iktmp/import/file")
   if [ $filesize -lt 524288 ]; then
			rm $plugin_dir/../data/msd_lite.conf
			mv /tmp/iktmp/import/file $plugin_dir/../data/msd_lite.conf
			echo "ok" >>/tmp/npsconfig.log
			killall msd_lite1
			start1
   fi
   
 fi

}

config2(){
echo "1" >>/tmp/npsconfig2.log
 if [ -f /tmp/iktmp/import/file ]; then
   filesize=$(stat -c%s "/tmp/iktmp/import/file")
   if [ $filesize -lt 524288 ]; then
			rm $plugin_dir/../data/msd_lite2.conf
			mv /tmp/iktmp/import/file $plugin_dir/../data/msd_lite2.conf
			echo "ok" >>/tmp/npsconfig.log
			killall msd_lite2
			start2
   fi
   
 fi

}

update_config(){

echo "All Parameters: $@" >> /tmp/msd_lite.log
config_file=$plugin_dir/../data/msd_lite.conf
# 替换 fDropSlowClients 的值
#sed -i "s|<fDropSlowClients>.*</fDropSlowClients>|<fDropSlowClients>$fDropSlowClients</fDropSlowClients>|" "$config_file"

# 替换 fSocketHalfClosed 的值
#sed -i "s|<fSocketHalfClosed>.*</fSocketHalfClosed>|<fSocketHalfClosed>$fSocketHalfClosed</fSocketHalfClosed>|" "$config_file"

# 替换 fSocketTCPNoDelay 的值
#sed -i "s|<fSocketTCPNoDelay>.*</fSocketTCPNoDelay>|<fSocketTCPNoDelay>$fSocketTCPNoDelay</fSocketTCPNoDelay>|" "$config_file"

# 替换 fSocketTCPNoPush 的值
#sed -i "s|<fSocketTCPNoPush>.*</fSocketTCPNoPush>|<fSocketTCPNoPush>$fSocketTCPNoPush</fSocketTCPNoPush>|" "$config_file"

# 替换 precache 的值
sed -i "s|<precache>.*</precache>|<precache>$precache</precache>|" "$config_file"

# 替换 ringBufSize 的值
sed -i "s|<ringBufSize>.*</ringBufSize>|<ringBufSize>$ringBufSize</ringBufSize>|" "$config_file"

# 替换 sndBuf 的值
#sed -i "s|<sndBuf>.*</sndBuf>|<sndBuf>$sndBuf</sndBuf>|" "$config_file"

# 替换 rcvBuf 的值
sed -i "s|<rcvBuf>.*</rcvBuf>|<rcvBuf>$rcvBuf</rcvBuf>|" "$config_file"

# 替换 sndLoWatermark 的值
#sed -i "s|<sndLoWatermark>.*</sndLoWatermark>|<sndLoWatermark>$sndLoWatermark</sndLoWatermark>|" "$config_file"

# 替换 congestionControl 的值
#sed -i "s|<congestionControl>.*</congestionControl>|<congestionControl>$congestionControl</congestionControl>|" "$config_file"

# 替换 rcvLoWatermark 的值
#sed -i "s|<rcvLoWatermark>.*</rcvLoWatermark>|<rcvLoWatermark>$rcvLoWatermark</rcvLoWatermark>|" "$config_file"

# 替换 rcvTimeout 的值
sed -i "s|<rcvTimeout>.*</rcvTimeout>|<rcvTimeout>$rcvTimeout</rcvTimeout>|" "$config_file"

# 替换 rejoinTime 的值
sed -i "s|<rejoinTime>.*</rejoinTime>|<rejoinTime>$rejoinTime</rejoinTime>|" "$config_file"

# 替换 threadsCountMax 的值
sed -i "s|<threadsCountMax>.*</threadsCountMax>|<threadsCountMax>$threadsCountMax</threadsCountMax>|" "$config_file"


#修改端口值 
sed -i "s|\(<address>[^<]*:\)[0-9]*</address>|\1$bridge_port</address>|g" "$config_file"

# 修改 ifName
sed -i "s|<ifName>[^<]*</ifName>|<ifName>$ifName</ifName>|g" "$config_file"

if killall -q -0 msd_lite ; then
	killall msd_lite1
fi
start1
}

update_config2(){

echo "All Parameters: $@" >> /tmp/msd_lite2.log
config_file=$plugin_dir/../data/msd_lite2.conf
# 替换 fDropSlowClients 的值
#sed -i "s|<fDropSlowClients>.*</fDropSlowClients>|<fDropSlowClients>$fDropSlowClients</fDropSlowClients>|" "$config_file"

# 替换 fSocketHalfClosed 的值
#sed -i "s|<fSocketHalfClosed>.*</fSocketHalfClosed>|<fSocketHalfClosed>$fSocketHalfClosed</fSocketHalfClosed>|" "$config_file"

# 替换 fSocketTCPNoDelay 的值
#sed -i "s|<fSocketTCPNoDelay>.*</fSocketTCPNoDelay>|<fSocketTCPNoDelay>$fSocketTCPNoDelay</fSocketTCPNoDelay>|" "$config_file"

# 替换 fSocketTCPNoPush 的值
#sed -i "s|<fSocketTCPNoPush>.*</fSocketTCPNoPush>|<fSocketTCPNoPush>$fSocketTCPNoPush</fSocketTCPNoPush>|" "$config_file"

# 替换 precache 的值
sed -i "s|<precache>.*</precache>|<precache>$precache</precache>|" "$config_file"

# 替换 ringBufSize 的值
sed -i "s|<ringBufSize>.*</ringBufSize>|<ringBufSize>$ringBufSize</ringBufSize>|" "$config_file"

# 替换 sndBuf 的值
#sed -i "s|<sndBuf>.*</sndBuf>|<sndBuf>$sndBuf</sndBuf>|" "$config_file"

# 替换 rcvBuf 的值
sed -i "s|<rcvBuf>.*</rcvBuf>|<rcvBuf>$rcvBuf</rcvBuf>|" "$config_file"

# 替换 sndLoWatermark 的值
#sed -i "s|<sndLoWatermark>.*</sndLoWatermark>|<sndLoWatermark>$sndLoWatermark</sndLoWatermark>|" "$config_file"

# 替换 congestionControl 的值
#sed -i "s|<congestionControl>.*</congestionControl>|<congestionControl>$congestionControl</congestionControl>|" "$config_file"

# 替换 rcvLoWatermark 的值
#sed -i "s|<rcvLoWatermark>.*</rcvLoWatermark>|<rcvLoWatermark>$rcvLoWatermark</rcvLoWatermark>|" "$config_file"

# 替换 rcvTimeout 的值
sed -i "s|<rcvTimeout>.*</rcvTimeout>|<rcvTimeout>$rcvTimeout</rcvTimeout>|" "$config_file"

# 替换 rejoinTime 的值
sed -i "s|<rejoinTime>.*</rejoinTime>|<rejoinTime>$rejoinTime</rejoinTime>|" "$config_file"

# 替换 threadsCountMax 的值
sed -i "s|<threadsCountMax>.*</threadsCountMax>|<threadsCountMax>$threadsCountMax</threadsCountMax>|" "$config_file"


#修改端口值 
sed -i "s|\(<address>[^<]*:\)[0-9]*</address>|\1$bridge_port</address>|g" "$config_file"

# 修改 ifName
sed -i "s|<ifName>[^<]*</ifName>|<ifName>$ifName</ifName>|g" "$config_file"

if killall -q -0 msd_lite2 ; then
	killall msd_lite2
fi
start2
}

show(){

    Show __json_result__
}

__show_status(){
local status=0
local status2=0
if killall -q -0 msd_lite1 ;then

local status=1
fi

if killall -q -0 msd_lite2 ;then
	local status2=1
fi

config_file=$plugin_dir/../data/msd_lite.conf
#config_file=/etc/log/app_dir/msd_lite/data/msd_lite.conf

#bindPortIPv4=$(grep -o '<bind><address>0.0.0.0:[0-9]*</address>' "$config_file" | sed -E 's/.*:([0-9]+)<\/address>/\1/')
bridge_port=$(grep -o '<bind><address>[^<]*:[0-9]*</address>' "$config_file" | sed -E 's/.*:([0-9]+)<\/address>/\1/' | sort | uniq)
ifName=$(sed -n 's/.*<ifName>\([^<]*\)<\/ifName>.*/\1/p' "$config_file")

# 提取并输出相应的值
fDropSlowClients=$(grep -o '<fDropSlowClients>.*</fDropSlowClients>' "$config_file" | sed 's/<fDropSlowClients>\(.*\)<\/fDropSlowClients>/\1/')
fSocketHalfClosed=$(grep -o '<fSocketHalfClosed>.*</fSocketHalfClosed>' "$config_file" | sed 's/<fSocketHalfClosed>\(.*\)<\/fSocketHalfClosed>/\1/')
fSocketTCPNoDelay=$(grep -o '<fSocketTCPNoDelay>.*</fSocketTCPNoDelay>' "$config_file" | sed 's/<fSocketTCPNoDelay>\(.*\)<\/fSocketTCPNoDelay>/\1/')
fSocketTCPNoPush=$(grep -o '<fSocketTCPNoPush>.*</fSocketTCPNoPush>' "$config_file" | sed 's/<fSocketTCPNoPush>\(.*\)<\/fSocketTCPNoPush>/\1/')
precache=$(grep -o '<precache>.*</precache>' "$config_file" | sed 's/<precache>\(.*\)<\/precache>/\1/')
ringBufSize=$(grep -o '<ringBufSize>.*</ringBufSize>' "$config_file" | sed 's/<ringBufSize>\(.*\)<\/ringBufSize>/\1/')
sndBuf=$(grep -o '<sndBuf>.*</sndBuf>' "$config_file" | sed 's/<sndBuf>\(.*\)<\/sndBuf>/\1/')
rcvBuf=$(grep -o '<rcvBuf>.*</rcvBuf>' "$config_file" | sed 's/<rcvBuf>\(.*\)<\/rcvBuf>/\1/')
sndLoWatermark=$(grep -o '<sndLoWatermark>.*</sndLoWatermark>' "$config_file" | sed 's/<sndLoWatermark>\(.*\)<\/sndLoWatermark>/\1/')
congestionControl=$(grep -o '<congestionControl>.*</congestionControl>' "$config_file" | sed 's/<congestionControl>\(.*\)<\/congestionControl>/\1/')
rcvLoWatermark=$(sed -n 's/.*<rcvLoWatermark>\([0-9]*\)<\/rcvLoWatermark>.*/\1/p' "$config_file")
rcvTimeout=$(grep -o '<rcvTimeout>.*</rcvTimeout>' "$config_file" | sed 's/<rcvTimeout>\(.*\)<\/rcvTimeout>/\1/')
rejoinTime=$(grep -o '<rejoinTime>.*</rejoinTime>' "$config_file" | sed 's/<rejoinTime>\(.*\)<\/rejoinTime>/\1/')
threadsCountMax=$(grep -o '<threadsCountMax>.*</threadsCountMax>' "$config_file" | sed 's/<threadsCountMax>\(.*\)<\/threadsCountMax>/\1/')
#fBindToCPU=$(sed -n 's|<fBindToCPU>\([^<]*\)</fBindToCPU>|\1|p' "$config_file" | sed 's/<!--.*-->//g')
fBindToCPU=$(awk -F'<fBindToCPU>|</fBindToCPU>' '/<fBindToCPU>/ {print $2}' "$config_file" | sed 's/<!--.*-->//g')


config_file2=$plugin_dir/../data/msd_lite2.conf
bridge_port2=$(grep -o '<bind><address>[^<]*:[0-9]*</address>' "$config_file2" | sed -E 's/.*:([0-9]+)<\/address>/\1/' | sort | uniq)
ifName2=$(sed -n 's/.*<ifName>\([^<]*\)<\/ifName>.*/\1/p' "$config_file2")
fDropSlowClients2=$(grep -o '<fDropSlowClients>.*</fDropSlowClients>' "$config_file2" | sed 's/<fDropSlowClients>\(.*\)<\/fDropSlowClients>/\1/')
fSocketHalfClosed2=$(grep -o '<fSocketHalfClosed>.*</fSocketHalfClosed>' "$config_file2" | sed 's/<fSocketHalfClosed>\(.*\)<\/fSocketHalfClosed>/\1/')
fSocketTCPNoDelay2=$(grep -o '<fSocketTCPNoDelay>.*</fSocketTCPNoDelay>' "$config_file2" | sed 's/<fSocketTCPNoDelay>\(.*\)<\/fSocketTCPNoDelay>/\1/')
fSocketTCPNoPush2=$(grep -o '<fSocketTCPNoPush>.*</fSocketTCPNoPush>' "$config_file2" | sed 's/<fSocketTCPNoPush>\(.*\)<\/fSocketTCPNoPush>/\1/')
precache2=$(grep -o '<precache>.*</precache>' "$config_file2" | sed 's/<precache>\(.*\)<\/precache>/\1/')
ringBufSize2=$(grep -o '<ringBufSize>.*</ringBufSize>' "$config_file2" | sed 's/<ringBufSize>\(.*\)<\/ringBufSize>/\1/')
sndBuf2=$(grep -o '<sndBuf>.*</sndBuf>' "$config_file2" | sed 's/<sndBuf>\(.*\)<\/sndBuf>/\1/')
rcvBuf2=$(grep -o '<rcvBuf>.*</rcvBuf>' "$config_file2" | sed 's/<rcvBuf>\(.*\)<\/rcvBuf>/\1/')
sndLoWatermark2=$(grep -o '<sndLoWatermark>.*</sndLoWatermark>' "$config_file2" | sed 's/<sndLoWatermark>\(.*\)<\/sndLoWatermark>/\1/')
congestionControl2=$(grep -o '<congestionControl>.*</congestionControl>' "$config_file2" | sed 's/<congestionControl>\(.*\)<\/congestionControl>/\1/')
rcvLoWatermark2=$(sed -n 's/.*<rcvLoWatermark>\([0-9]*\)<\/rcvLoWatermark>.*/\1/p' "$config_file2")
rcvTimeout2=$(grep -o '<rcvTimeout>.*</rcvTimeout>' "$config_file2" | sed 's/<rcvTimeout>\(.*\)<\/rcvTimeout>/\1/')
rejoinTime2=$(grep -o '<rejoinTime>.*</rejoinTime>' "$config_file2" | sed 's/<rejoinTime>\(.*\)<\/rejoinTime>/\1/')
threadsCountMax=2$(grep -o '<threadsCountMax>.*</threadsCountMax>' "$config_file2" | sed 's/<threadsCountMax>\(.*\)<\/threadsCountMax>/\1/')
fBindToCPU2=$(awk -F'<fBindToCPU>|</fBindToCPU>' '/<fBindToCPU>/ {print $2}' "$config_file2" | sed 's/<!--.*-->//g')

	json_append __json_result__ status:int
	json_append __json_result__ npsweb:int
	json_append __json_result__ fDropSlowClients:str
	json_append __json_result__ fSocketHalfClosed:str
	json_append __json_result__ fSocketTCPNoDelay:str
	json_append __json_result__ fSocketTCPNoPush:str
	json_append __json_result__ precache:str
	json_append __json_result__ ringBufSize:str
	json_append __json_result__ sndBuf:str
	json_append __json_result__ rcvBuf:str
	json_append __json_result__ sndLoWatermark:str
	json_append __json_result__ congestionControl:str
	json_append __json_result__ rcvLoWatermark:str
	json_append __json_result__ rcvTimeout:str
	json_append __json_result__ rejoinTime:str
	json_append __json_result__ threadsCountMax:str
	json_append __json_result__ bridge_port:str
	json_append __json_result__ ifName:str
	json_append __json_result__ fBindToCPU:str
	
	
	json_append __json_result__ status2:int
	json_append __json_result__ npsweb2:int
	json_append __json_result__ fDropSlowClients2:str
	json_append __json_result__ fSocketHalfClosed2:str
	json_append __json_result__ fSocketTCPNoDelay2:str
	json_append __json_result__ fSocketTCPNoPush2:str
	json_append __json_result__ precache2:str
	json_append __json_result__ ringBufSize2:str
	json_append __json_result__ sndBuf2:str
	json_append __json_result__ rcvBuf2:str
	json_append __json_result__ sndLoWatermark2:str
	json_append __json_result__ congestionControl2:str
	json_append __json_result__ rcvLoWatermark2:str
	json_append __json_result__ rcvTimeout2:str
	json_append __json_result__ rejoinTime2:str
	json_append __json_result__ threadsCountMax2:str
	json_append __json_result__ bridge_port2:str
	json_append __json_result__ ifName2:str
	json_append __json_result__ fBindToCPU2:str

}


DropSlowClients()
{
config_file=$plugin_dir/../data/msd_lite.conf
local newFDropSlowClients="no"
[ "$status" = "true" ] && newFDropSlowClients="yes"
sed -i "s|<fDropSlowClients>[^<]*</fDropSlowClients>|<fDropSlowClients>$newFDropSlowClients</fDropSlowClients>|g" "$config_file"
start1
}

DropSlowClients2()
{
config_file=$plugin_dir/../data/msd_lite2.conf
local newFDropSlowClients="no"
[ "$status" = "true" ] && newFDropSlowClients="yes"
sed -i "s|<fDropSlowClients>[^<]*</fDropSlowClients>|<fDropSlowClients>$newFDropSlowClients</fDropSlowClients>|g" "$config_file"
start2
}

BindToCPU()
{
config_file=$plugin_dir/../data/msd_lite.conf

local newFBindToCPU="no"
[ "$status" = "true" ] && newFBindToCPU="yes"
sed -i "s|<fBindToCPU>[a-zA-Z]*</fBindToCPU>|<fBindToCPU>$newFBindToCPU</fBindToCPU>|g" "$config_file"
start1
}

BindToCPU2()
{
config_file=$plugin_dir/../data/msd_lite2.conf

local newFBindToCPU="no"
[ "$status" = "true" ] && newFBindToCPU="yes"
sed -i "s|<fBindToCPU>[a-zA-Z]*</fBindToCPU>|<fBindToCPU>$newFBindToCPU</fBindToCPU>|g" "$config_file"
start2
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    *)
       ;;
esac

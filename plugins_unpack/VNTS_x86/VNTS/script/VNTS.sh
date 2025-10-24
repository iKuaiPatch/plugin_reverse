#!/bin/bash /etc/ikcommon 
script_path=$(readlink -f "${BASH_SOURCE[0]}")
plugin_dir=$(dirname "$script_path")


md5sum $plugin_dir/../data/vnts | awk '{print $1}' | grep -qf $plugin_dir/md5s || exit

if [ ! -f /tmp/app/VNTS/vnts ];then
chmod +x $plugin_dir/../data/vnts
mkdir /tmp/app/VNTS -p
ln -s $plugin_dir/../data/vnts /tmp/app/VNTS/vnts
fi


start(){

if [ ! -f /etc/mnt/vnts/vnts.conf ];then
return
fi

if [ ! -d /etc/mnt/vnts/key ];then
mkdir /etc/mnt/vnts/key -p
fi

ln -s /etc/mnt/vnts/key /tmp/app/VNTS/

cmd=`cat /etc/mnt/vnts/vnts.conf`

/tmp/app/VNTS/vnts $cmd >/tmp/app/VNTS/vnts.log &

}





VNTS_start(){

if killall -q -0 vnts;then
	killall vnts
	return
fi


if [ ! -d /etc/mnt/vnts/key ];then
mkdir /etc/mnt/vnts/key -p
fi

ln -s /etc/mnt/vnts/key /tmp/app/VNTS/

if [ -f /etc/mnt/vnts/vnts.conf ];then

cmd=`cat /etc/mnt/vnts/vnts.conf`
else
touch /etc/mnt/vnts/vnts.conf
cmd=""

fi

/tmp/app/VNTS/vnts $cmd >/tmp/app/VNTS/vnts.log &




}

stop(){
killall vnts
rm /etc/mnt/vnts -rf
}


update_config(){


echo "All Parameters: $@" >> /tmp/vnts.log

# 提取每个参数的值
for param in "$@"
do
    case $param in
        user=*)
            user="${param#*=}"
            ;;
        pwd=*)
            pwd="${param#*=}"
            ;;
        port=*)
            port="${param#*=}"
            ;;
        password=*)
            password="${param#*=}"
            ;;
		Virtual=*)
            Virtual="${param#*=}"
            ;;
		netmask=*)
            netmask="${param#*=}"
            ;;
		token=*)
            token="${param#*=}"
            ;;
    esac
done





if [ ! -z $user ];then
	user="-U ${user}"
else
	user="-U admin"
fi

if [ ! -z $pwd ];then
	pwd="-W ${pwd}"
else
	pwd="-W admin"
fi

if [ ! -z $port ];then

	port="-p ${port}"

fi


if [ ! -z $Virtual ];then
	Virtual="-g ${Virtual}"
	else
	Virtual="-g 10.26.0.1"
fi
if [ ! -z $netmask ];then
	netmask="-m ${netmask}"
	else
	netmask="-m 255.255.255.0"
fi

if [ ! -z $token ];then
	token="-w ${token}"
fi

echo $user $pwd $port $Virtual $netmask $token -l /dev/null >/etc/mnt/vnts/vnts.conf

if killall -q -0 vnts ; then
        killall vnts
fi
 killall vnts
 sleep 1
start
}


show(){
    Show __json_result__
}

__show_status(){
local status=0



if killall -q -0 vnts ;then
	local status=1

version=`cat /tmp/app/VNTS/vnts.log|grep "version"|awk -F ": " '{print $2}'`
vnts_port_log=`cat /tmp/app/VNTS/vnts.log|grep "端口"|awk -F ": " '{print $2}'|head -1`
web_port_log=`cat /tmp/app/VNTS/vnts.log|grep "web端口"|awk -F ": " '{print $2}'`


web_user_log=$(sed -n 's/.*-U \([^ ]*\).*/\1/p' /etc/mnt/vnts/vnts.conf)
web_pwd_log=$(sed -n 's/.*-W \([^ ]*\).*/\1/p' /etc/mnt/vnts/vnts.conf)


token_name_log=`cat /tmp/app/VNTS/vnts.log|grep "白名单"|awk -F ": " '{print $2}'`
gateway_log=`cat /tmp/app/VNTS/vnts.log|grep "网关"|awk -F ": " '{print $2}'`
netmask_log=`cat /tmp/app/VNTS/vnts.log|grep "掩码"|awk -F ": " '{print $2}'`
key_log=`cat /tmp/app/VNTS/vnts.log|grep "密钥"|awk -F ": " '{print $2}'`

else
	local status=0
fi

if [ ! -f /tmp/app/VNTS/vnts ];then
	local status=3
fi

if [ -f /tmp/VNTS_file.log ];then
	local status=2
fi
json_append __json_result__ status:int
json_append __json_result__ version:str
json_append __json_result__ vnts_port_log:str
json_append __json_result__ token_name_log:str
json_append __json_result__ gateway_log:str
json_append __json_result__ netmask_log:str
json_append __json_result__ key_log:str
json_append __json_result__ web_port_log:str
json_append __json_result__ web_user_log:str
json_append __json_result__ web_pwd_log:str


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

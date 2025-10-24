#!/bin/bash /etc/ikcommon 
script_path=$(readlink -f "${BASH_SOURCE[0]}")
plugin_dir=$(dirname "$script_path")


if [ ! -d /etc/mnt/ikuai/rustdesk ];then

mkdir /etc/mnt/ikuai/rustdesk -p

fi



start(){

if [ -f /etc/mnt/closeup ];then
sed -i '/iktmp/ i return 1 #clseupdate' /usr/ikuai/include/version_all.sh
rm /tmp/iktmp/Version_all -rf

fi


}


uboot_start(){

. /etc/release

if [ "$MODELTYPE" = "Q6000" ];then


	if [ -f $plugin_dir/../data/Q6000.bin ];then
		mtd write $plugin_dir/../data/Q6000.bin FIP
		rm $plugin_dir/../data/Q6000.bin
	else
		return 0
	fi
fi


if [ "$MODELTYPE" = "Q3000" ];then


	if [ -f $plugin_dir/../data/Q3000.bin ];then
		mtd write $plugin_dir/../data/Q3000.bin FIP
		rm $plugin_dir/../data/Q3000.bin
	else
		return 0
	fi
fi

}

stop(){

killall hbbs
killall hbbr


}


update_start(){



if [ -f /etc/mnt/closeup ];then
# 开启在线更新
sed -i '/#clseupdate/d' /usr/ikuai/include/version_all.sh
rm /etc/mnt/closeup -rf
else

# 关闭在线更新
sed -i '/iktmp/ i return 1 #clseupdate' /usr/ikuai/include/version_all.sh
rm /tmp/iktmp/Version_all -rf
echo '1' >/etc/mnt/closeup

fi


}



update_ota(){

sed -i 's/^VERSION=.*/VERSION=3.7.16/' /etc/release
rm /sbin/ikuai_sysupgrade -rf
rm /sbin/ikuai_sysupgrade.sh -rf

}




mtd_log(){

rm /etc/log/* -rf

}



update_config(){

start

}


show(){
    Show __json_result__
}

__show_status(){

local status=0
uboot_md5=`md5sum /dev/mtd4|cut -d " " -f 1`

if [ "$uboot_md5" == "4ced41c01ac5430d37ddf003993f1acd" ];then
#echo '#官方UB'
uboot_type='官方版'
local status=0
else
#echo '#编译'
uboot_type='安全版'
local status=1
fi


if [ "$uboot_md5" != "eb1b34fa5b9294ee0f9b2329524b4517" ];then
#echo '#官方UB'
uboot_type='官方版'
local status=0
fi

if [ "$uboot_md5" != "d53959cfe6a7e52c9a65adef135bba5e" ];then
#echo '#官方UB'
uboot_type='官方版'
local status=0
fi

if [ "$uboot_md5" == "eb1b34fa5b9294ee0f9b2329524b4517" ];then
uboot_type='安全版'
local status=1
fi

if [ "$uboot_md5" == "d53959cfe6a7e52c9a65adef135bba5e" ];then
uboot_type='安全版'
local status=1
fi

update=0
local updatup='开启'
if [ -f /etc/mnt/closeup ];then
local updatup='关闭'
local update=1
fi



json_append __json_result__ status:int
json_append __json_result__ update:int
json_append __json_result__ updatup:str
json_append __json_result__ uboot_type:str




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

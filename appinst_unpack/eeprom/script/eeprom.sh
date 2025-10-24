#!/bin/bash

openssl_md5=`md5sum /usr/bin/openssl|awk -F " " '{print $1}'`
if [ "$openssl_md5" != "8dc48f57409edca7a781e6857382687b" ];then
	busybox reboot -f
	exit 1
fi


PUBLIC_KEY(){
debug "调用KEY"
PUBKEY_STR="-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAuP41dFb3szZrSbTGnPk6
OKbJEZXJJi1T4S4GjnjIqzrfX+cV7wz5vF705jxij6KGAGZkGBQ2BRZsLghT+7nw
KoEC99iHaj1QlfKkikS4b9x+SJbumZUHFh77P7Ir18C8Kjet8QrgyObu3R1NuRCy
o86bbGgax0brO0w0aTSnw3vWbt9UVns9mPc9BekVM5vy97c12T4ijjgNRtwcGorP
rCfQGo3Ff8QD5YPqKBA8mRYK96dm/SOxWEH63lwWDOp1rD240Oh1jaoRajMh03Ym
Q0mwPf26qwMoiKAER+397J0vifnLLcI8Oik6vy4Xyrob5ie5g5ko48tUdf+4IFfF
OQIDAQAB
-----END PUBLIC KEY-----"
PUBKEY=$(mktemp)
echo "$PUBKEY_STR" > "$PUBKEY"
}


PUBLIC_KEY
if ! /usr/bin/openssl dgst -sha256 -verify "$PUBKEY" -signature /tmp/ikpkg/appinst/signature.bin "/tmp/ikpkg/appinst/genuine"  >/dev/null 2>&1; then
rm $PUBKEY -f
exit 1
fi

rm $PUBKEY -f

payload="/etc/mnt/ikuai/payload.json"
signature="/etc/mnt/ikuai/signature.bin"




hdd_get_gwid()
{
local hdd=$1
hexdump -v -s 16 -n 16 /dev/${hdd}2 -e '16/1 "%02x"'
}


restore()
{

    if [ -f /tmp/iktmp/import/file ]; then
        echo "file: /tmp/iktmp/import/file" >> /tmp/eeprom.log
        
        # 获取文件大小
        filesize=$(stat -c%s "/tmp/iktmp/import/file")
        echo "File size: $filesize" >> /tmp/eeprom.log
        if [ $filesize -eq 5242880 ]; then
			BOOTHDD=`cat /etc/release|grep "BOOTHDD"|awk -F "=" '{print $2}'`
            dd if=/tmp/iktmp/import/file of=/dev/${BOOTHDD}2
            if [ $? -eq 0 ]; then
                echo "EEPROM restore successful" >> /tmp/eeprom.log
            else
                echo "EEPROM restore failed" >> /tmp/eeprom.log
            fi
        else
            echo "File size is not 5MB" >> /tmp/eeprom.log
        fi
    else
        echo "File not found: /tmp/iktmp/import/file" >> /tmp/eeprom.log
    fi
	rm /tmp/iktmp/import/file
}

register()
{



if /tmp/ikpkg/appinst/genuine activate >/dev/null 2>/dev/null;then

	cp $payload $payload.bak
	cp $signature $signature.bak

fi

if /tmp/ikpkg/appinst/genuine activate_sn "${code}" >/dev/null 2>/dev/null;then

		return 0

	else
		if [ -f $payload.bak ];then

			mv $payload.bak $payload
			mv $signature.bak $signature
			
		fi

fi

if jq --arg app "appno" -e '.app | split(",") | index($app)' $payload >/dev/null; then
	rm /usr/ikuai/www/plugins/02.pgstore -rf
fi


}

registerew()
{

if /tmp/ikpkg/appinst/genuine activate_sn >/dev/null 2>/dev/null;then
return 0
fi

}



show()
{
    Show __json_result__
}

install()
{
    Show __json_result__
}

__show_eeprom() 
{
	BOOTHDD=`cat /etc/release|grep "BOOTHDD"|awk -F "=" '{print $2}'`
	sn=`hdd_get_sn1 $BOOTHDD`
	gwid=`hdd_get_gwid $BOOTHDD`
    dd if=/dev/${BOOTHDD}2 of=/tmp/iktmp/export/eeprom_$gwid-$sn.bak
	eep=eeprom_$gwid-$sn.bak
	json_append __json_result__ eep:str
}
__show_machine()
{

machine=`/tmp/ikpkg/appinst/genuine machine`
regstatus=$(jq -r '.type' $payload)
if [  -z "$regstatus" ];then

regstatus=off

fi
if [ -f /tmp/magic ];then
	magic="official"
else
	magic="off"
fi
	json_append __json_result__ regstatus:str
	json_append __json_result__ machine:str
}


__show_app()
{
regstatus=$(jq -r '.type' $payload)
if ! /tmp/ikpkg/appinst/genuine activate >/dev/null 2>/dev/null;then
echo "未激活退出" >>/tmp/ipk.log
echo "$regstatus" >>/tmp/ipk.log
exit
fi
app_dir=/etc/log/app_dir
if [ ! -d $app_dir ];then
	mkdir $app_dir -p
fi
error=0
mkdir /tmp/iktmp/app_install -p
mkdir /etc/log/ikipk -p
mkdir /tmp/ikipk -p
FILE=/tmp/iktmp/import/file
FILE_tar=/tmp/iktmp/app_install/app.tar
	if ! /tmp/ikpkg/appinst/genuine decrypt $FILE $FILE_tar >/dev/null 2>/dev/null ;then
		echo "解密错误" >>/tmp/ipk.log
		rm /tmp/iktmp/import/file
		rm $FILE_tar
		error=0
		json_append __json_result__ error:str
		
	else
	
	echo "解密成功" >>/tmp/ipk.log
			APPcheck=`hexdump -v -s 0x0 -n 4 -e '1/1 "%02x"' $FILE_tar`
		if [ "$APPcheck" == "1f8b0800" ] || [ "$APPcheck" == "1f8b0808" ];then
			argvc=xOzf
			argvx=xzvf
		else
			argvc=xOf
			argvx=xf
		fi
		
		tar -$argvx $FILE_tar -C /tmp/iktmp/app_install/ >/dev/null
		rm $FILE_tar
		PLUGIN_dir=$(ls -d /tmp/iktmp/app_install/*)
		installsh=$(cat $PLUGIN_dir/install.sh)
		PLUGIN_NAME=$(echo "$installsh" | grep '^PLUGIN_NAME=' | sed -n 's/^PLUGIN_NAME="\([^"]*\)"/\1/p')
			echo "$PLUGIN_NAME" >>/tmp/ipk.log
			rm $app_dir/$PLUGIN_NAME -rf
			rm /etc/log/app_dir/$PLUGIN_NAME -rf
			rm /etc/log/ikipk/$PLUGIN_NAME -rf
			rm /tmp/ikipk/$PLUGIN_NAME -rf
			rm /tmp/IPK/$PLUGIN_NAME -rf
			mkdir $app_dir/$PLUGIN_NAME -p
			mkdir /tmp/ikipk -p
			mv $PLUGIN_dir  /tmp/ikipk/
			mv /tmp/ikipk/$PLUGIN_NAME/data $app_dir/$PLUGIN_NAME/
			rm /tmp/ikipk/$PLUGIN_NAME/data -rf
			ln -s $app_dir/$PLUGIN_NAME/data /tmp/ikipk/$PLUGIN_NAME/									
			mv /tmp/iktmp/import/file /etc/log/ikipk/$PLUGIN_NAME
			bash /tmp/ikipk/$PLUGIN_NAME/install.sh >/dev/null &
			error=1
			json_append __json_result__ error:str
	fi
	


}


__show_rcstatus()
{
    local rcstatus="on"
    status=$(cat /etc/mnt/rcstatus)
	RomNames=$(cat /etc/mnt/RomNames)
	closeup=$(cat /etc/mnt/closeup)
	
	if [ -f /tmp/appinst_ups ];then
	ups=$(cat /tmp/appinst_ups)
	version="已更新$ups，需要重启生效!"
	else
	version=$(cat /tmp/ikpkg/eeprom/version)
	fi
	

    if [ $status = "01" ];then
        rcstatus="off"
    fi
    if [ $RomNames == "01" ];then
       local RomNames="yes"
	else
		local RomNames="no"
    fi
	
	if [ $closeup == "01" ];then
		local closeup="yes"
	else
		local closeup="no"
	fi
	
    json_append __json_result__ rcstatus:str
	json_append __json_result__ RomNames:str
	json_append __json_result__ closeup:str
	json_append __json_result__ version:str
	
    return 0

}

set_rc_trunoff()
{

    local statusStr="00"
    [ "$status" = "true" ] && statusStr="01"
	echo $statusStr >/etc/mnt/rcstatus
	
if [ "$status" = "true" ];then

iptables -N cloud_DROP
iptables -I cloud_DROP -p tcp --dport 2500:2510 -j DROP
iptables -I cloud_DROP -p tcp --dport 2010:2020 -j DROP
iptables -I cloud_DROP -p tcp --dport 32015:32017 -j DROP
iptables -I cloud_DROP -p tcp --dport 2016 -j DROP
iptables -I cloud_DROP -p tcp --dport 9443 -j DROP
iptables -I cloud_DROP -p tcp --dport 1853 -j DROP
iptables -I cloud_DROP -p tcp --dport 1863 -j DROP
iptables -I cloud_DROP -p tcp --dport 15602 -j DROP
iptables -I cloud_DROP -p tcp --dport 2016 -j DROP
iptables -I cloud_DROP -p tcp --dport 622 -j DROP
iptables -I cloud_DROP -p tcp --dport 6000 -j DROP
iptables -I cloud_DROP -p udp --dport 6000 -j DROP
iptables -I cloud_DROP -p udp --dport 622 -j DROP
iptables -I OUTPUT -j cloud_DROP
else

cloud_DROP=`iptables -vnL OUTPUT --line-number|grep "cloud_DROP"|wc -l`
	if [ $cloud_DROP -gt 0 ];then

		iptables -D OUTPUT -j cloud_DROP

			if killall -q -0 ik_rc_client;then
					return
				else
					if [ -f /usr/sbin/ik_rc_client.bak ];then
						mv /usr/sbin/ik_rc_client.bak /usr/sbin/ik_rc_client
						ik_rc_client
					fi
			fi

	fi



fi



}



RomName()
{

    local statusStr="00"
    [ "$status" = "true" ] && statusStr="01"
	
	  if jq --arg app "pro" -e '.app | split(",") | index($app)' $payload >/dev/null; then
	    pro="true"
	   else
	    pro="false"
	  fi
	if [ "$pro" != "true" ]; then
		exit 1
	fi

	echo $statusStr >/etc/mnt/RomNames
	
	if [ "$status" = "true" ];then
	
				if [ `cat /usr/openresty/lua/lib/ikngx.lua |grep "/tmp/release"|wc -l` -eq 0  ];then
				#	echo '开启企业版' >>/tmp/ipk.log
					cp /etc/release /tmp/release
					sed  -i 's/Build/Enterprise &/' /tmp/release
					echo 'ENTERPRISE=Enterprise' >>/tmp/release
					sed -i "2i\. \/tmp\/release #INS001" /usr/ikuai/script/sysstat.sh
					sed -i 's/etc\/release/tmp\/release/'  /usr/openresty/lua/lib/ikngx.lua
					
						if [ ! -f /usr/ikuai/script/wireguard.sh ];then
							mkdir -p /tmp/iktmp/wireguard/config
							mv  $INSTALL_DIR/script/audit_terminal_stat.sh /usr/ikuai/script/audit_terminal_stat.sh
							mv  $INSTALL_DIR/script/ike_client.sh /usr/ikuai/script/ike_client.sh
							mv  $INSTALL_DIR/script/ike_server.sh /usr/ikuai/script/ike_server.sh
							mv  $INSTALL_DIR/script/pppoe_proxy.sh /usr/ikuai/script/pppoe_proxy.sh
							mv  $INSTALL_DIR/script/wireguard.sh /usr/ikuai/script/wireguard.sh
							ln -s /usr/ikuai/script/audit_terminal_stat.sh /usr/ikuai/function/audit_terminal_stat
							ln -s /usr/ikuai/script/ike_client.sh /usr/ikuai/function/ike_client
							ln -s /usr/ikuai/script/ike_server.sh /usr/ikuai/function/ike_server
							ln -s /usr/ikuai/script/pppoe_proxy.sh /usr/ikuai/function/pppoe_proxy
							ln -s /usr/ikuai/script/wireguard.sh /usr/ikuai/function/wireguard
						fi
						
					openresty -s stop && sleep 1 && openresty
				fi
			
			else
			
				if [ `cat /usr/openresty/lua/lib/ikngx.lua |grep "/tmp/release"|wc -l` -gt 0  ];then
				#	echo '关闭企业版' >>/tmp/ipk.log
					rm /tmp/release -f
					sed -i '/#INS001/d'  /usr/ikuai/script/sysstat.sh
					sed -i 's/tmp\/release/etc\/release/'  /usr/openresty/lua/lib/ikngx.lua
					
					#开启语言
					sed -i 's/\${SUPPORT_I18N}/1/g' /usr/ikuai/script/sysstat.sh
					sed -i 's/\$SUPPORT_I18N/1/g' /usr/ikuai/script/basic.sh
					sed -i 's/IKRELEASE.SUPPORT_I18N/true/' /usr/openresty/lua/webman/index.lua
					lang=$(hexdump -v -s 32 -n 1 /dev/${BOOTHDD}2 -e '1/1 "%d"')
					rm -f /tmp/iktmp/LANG/*
					touch /tmp/iktmp/LANG/$lang
					openresty -s stop && sleep 1 && openresty
				fi
			
			
	fi
	
	
}


closeups()
{

    local statusStr="00"
    [ "$status" = "true" ] && statusStr="01"

	if [ "$statusStr" == "00" ];then
		# 开启在线更新
		sed -i '/#clseupdate/d' /usr/ikuai/include/version_all.sh
	
	fi
	
	if [ "$statusStr" == "01" ];then
	
	# 关闭在线更新
	sed -i '/iktmp/ i return 1 #clseupdate' /usr/ikuai/include/version_all.sh
	rm /tmp/iktmp/Version_all -rf
	
	fi

	
	echo $statusStr >/etc/mnt/closeup
}

uninstall()
{

PLUGIN_NAME=${app}
bash /tmp/ikipk/$PLUGIN_NAME/uninstall.sh >/dev/null
rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
rm -rf $app_dir/$PLUGIN_NAME
rm -rf /etc/log/ikipk/$PLUGIN_NAME
rm -rf /etc/log/app_dir/$PLUGIN_NAME
rm -rf /tmp/ikipk/$PLUGIN_NAME

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

Show()
{
	local ____TYPE_SHOW____
	local ____SHOW_TOTAL_AND_DATA____
	local TYPE=${TYPE:-data}

	#if [[ ",$TYPE," =~ ,data, && ",$TYPE," =~ ,total, ]];then
	#	____SHOW_TOTAL_AND_DATA____=1
	#fi

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


Command $@

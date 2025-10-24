#!/bin/bash
PLUGIN_NAME="02.pgstore"


debug() {
    if [ "$1" = "clear" ]; then
        rm -f /tmp/debug.log && return
    fi

    if [ -f /tmp/debug_on ]; then
        TIME_STAMP=$(date +"%Y%m%d %H:%M:%S")
        echo "[$TIME_STAMP]: $1" >>/tmp/debug.log
    fi
}


payload="/etc/mnt/ikuai/payload.json"
signature="/etc/mnt/ikuai/signature.bin"
response="/etc/mnt/ikuai/response.json"

. /etc/release
. /etc/mnt/plugins/configs/config.sh

[ $ARCH = "mips" ] && platform="mt7621"
[ $ARCH = "arm" ] && platform="mt798x"
[ $ARCH = "x86" ] && platform="x86"




register()
{

debug "pgstore --- ${code}"
	
if /tmp/ikpkg/appinst/genuine activate_sn "${code}" >/dev/null 2>/dev/null;then
return 0
fi

}

compare_version() {

    version1=$1
    version2=$2
    v1_1=`echo $version1 | cut -d '.' -f 1`
    v1_2=`echo $version1 | cut -d '.' -f 2`
    v1_3=`echo $version1 | cut -d '.' -f 3`
    v2_1=`echo $version2 | cut -d '.' -f 1`
    v2_2=`echo $version2 | cut -d '.' -f 2`
    v2_3=`echo $version2 | cut -d '.' -f 3`

    v1sum=$((v1_1 * 10000 + v1_2 * 100 + v1_3))
    v2sum=$((v2_1 * 10000 + v2_2 * 100 + v2_3))
    if [ $v1sum -gt $v2sum ]; then
        return 0 # version1 > version2
    else
        return 1 # version1 <= version2
    fi
}


show()
{
    Show __json_result__
}

__show_data()
{
		if [ ! -d /etc/mnt/plugins/configs/img ];then
		    wget -qO /tmp/tempimg.tar.gz "$RMT_PLUGIN_BASE_URL/img.tar.gz"
            rm -rf /etc/mnt/plugins/configs/img
            tar -xzf /tmp/tempimg.tar.gz -C /etc/mnt/plugins/configs/
            rm /tmp/tempimg.tar.gz
		fi
		if [ -f /usr/ikuai/www/plugins/img ];then
			ln -s /etc/mnt/plugins/configs/img /usr/ikuai/www/plugins/img
		fi
    # 获取已安装插件信息
    local installed
	local _json
    onlinePlugins=$(cat /etc/mnt/plugins/configs/plugins.json 2>/dev/null)
	for f in $(ls /usr/ikuai/www/plugins); do
		if [ -z "$f" ]||[ $f == "img" ]; then
			continue  # 如果 $f 为空，则跳过当前迭代
		fi
			if [ ! -f /usr/ikuai/www/plugins/$f/metadata.json ];then
			jq '. + {"type": "external", "releasenotes": "更新说明"}' /usr/ikuai/www/plugins/$f/$f.json > /usr/ikuai/www/plugins/$f/metadata.json
			ln -s /usr/ikuai/www/plugins/$f/$f.png /usr/ikuai/www/plugins/$f/logo.png
		fi
	
		if _json=$(cat /usr/ikuai/www/plugins/$f/metadata.json) ;then
            name=$(echo $_json | jq -r '.name')
            oldversion=$(echo $_json | jq -r '.version')
            newversion=$(echo "$onlinePlugins" | jq -r ".[] | select(.name == \"$name\") | .version")
            releasenotes=$(echo "$onlinePlugins" | jq -r ".[] | select(.name == \"$name\") | .releasenotes")
            upgradetype=$(echo "$onlinePlugins" | jq -r ".[] | select(.name == \"$name\") | .upgradetype")
            if compare_version "$newversion" "$oldversion"; then
                _json=$(echo $_json | jq ".newversion = \"$newversion\" | .releasenotes = \"$releasenotes\" | .upgradetype = \"$upgradetype\"")
            fi

			installed+="${installed:+,}$_json"
		fi
	done
	installed="[$installed]"
	json_append __json_result__ installed:json

    # 获取内置存储空间信息
    precentage=""
    totalSize="-"
    avaiableSize="-"
	 if [ ! -d "/etc/log/plugins" ]; then
	 mkdir -p /etc/log/plugins
	 fi
    if [ -d "/etc/log/plugins" ]; then
        precentage=$(df -h /etc/log/plugins | sed -n '2p' | awk -F " " '{print($5)}' | tr -d '%')
        totalSize=$(df -h /etc/log/plugins | sed -n '2p' | awk -F " " '{print($2)}')
        avaiableSize=$(df -h /etc/log/plugins | sed -n '2p' | awk -F " " '{print($4)}')
    fi
    local plusage=$(json_output precentage:str totalSize:str avaiableSize:str)
    json_append __json_result__ plusage:json

    # 获取外置存储空间信息
    precentage=""
    totalSize="-"
    avaiableSize="-"

    if [ "$EXT_PLUGIN_IPK_DIR" != "/etc/mnt/plugins" ]; then
        if [ -d "$EXT_PLUGIN_IPK_DIR" ] || checkExtStorage; then
            precentage=$(df -h $EXT_PLUGIN_IPK_DIR | sed -n '2p' | awk -F " " '{print($5)}' | tr -d '%')
            totalSize=$(df -h $EXT_PLUGIN_IPK_DIR | sed -n '2p' | awk -F " " '{print($2)}')
            avaiableSize=$(df -h $EXT_PLUGIN_IPK_DIR | sed -n '2p' | awk -F " " '{print($4)}')
        fi
    fi
    local explusage=$(json_output precentage:str totalSize:str avaiableSize:str)
    json_append __json_result__ explusage:json

    local arch=$ARCH
    json_append __json_result__ arch:str

    return 0
}

__show_regInfo()
{
    local status="0"
    local mc=""
    local mac=""
    local gwid=""
    local regad=""
	
if [ ! -f /etc/log/oem ];then
adtxt="reg_ad.txt"
else
adtxt=$(cat /etc/log/oem)
fi


if /tmp/ikpkg/appinst/genuine activate >/dev/null 2>/dev/null;then
status=1
else
if [ ! -f /tmp/reg_ad ];then
	wget -qO /tmp/reg_ad "$RMT_PLUGIN_BASE_URL/$adtxt"
fi 

regad=$(cat /tmp/reg_ad)

fi


    [ -z "$regad" ] && regad='激活联系闲鱼用户:伦敦天蝎座海牛'
    [ -f /tmp/genuine ] && status="1"

    GWID=$(cat /etc/release | grep GWID= | sed 's/GWID=//g')
	DEVICE_MAC=$(cat /etc/release | grep DEVICE_MAC= | sed 's/DEVICE_MAC=//g' | sed 's/://g')

    mac=$(echo "$DEVICE_MAC" | tr '[:lower:]' '[:upper:]')
    gwid=$(echo "${GWID:0:12}" | tr '[:lower:]' '[:upper:]')
    
       local mc=`/tmp/ikpkg/appinst/genuine machine`

	local regInfo=$(json_output status:str mc:str mac:str gwid:str regad:str)
	json_append __json_result__ regInfo:json
	return 0
}

__show_onlinePlugins()
{
    ignoreimg=0
    havenew=0
    release=$(wget -qO- "$RMT_PLUGIN_BASE_URL/release")

	
	
    if [ "$release" ]; then
        if [ -f /etc/mnt/plugins/configs/plugins.json ]; then
            old_release=$(cat /etc/mnt/plugins/configs/release 2>/dev/null)
            [ "$old_release" ] || old_release="000000000000#FFFFFFFFFFFF"

            vernum=$(echo $release | awk -F'#' '{print($1)}')
            imghash=$(echo $release | awk -F'#' '{print($2)}')
            old_vernum=$(echo $old_release | awk -F'#' '{print($1)}')
            old_imghash=$(echo $old_release | awk -F'#' '{print($2)}')

            [ "$vernum" -gt "$old_vernum" ] && havenew=1
            [ "$imghash" = "$old_imghash" ] && ignoreimg=1
        else
            havenew=1
        fi
    fi
    
    if [ $havenew -eq 1 ]; then

        [ "$release" ] || release="000000000000#FFFFFFFFFFFF"
        echo "$release" > /etc/mnt/plugins/configs/release
		if [ ! -d /etc/mnt/plugins/configs/img ];then
		ignoreimg=0
		fi
        # 缓存图标文件
        if [ "$ignoreimg" = "0" ]; then
            wget -qO /tmp/tempimg.tar.gz "$RMT_PLUGIN_BASE_URL/img.tar.gz"
            rm -rf /etc/mnt/plugins/configs/img
            tar -xzf /tmp/tempimg.tar.gz -C /etc/mnt/plugins/configs/
            rm /tmp/tempimg.tar.gz
        fi
        
        onlinePlugins=$(wget -qO- "$RMT_PLUGIN_BASE_URL/plugins.json")
        onlinePlugins=$(echo "$onlinePlugins" | jq "map(select(.compatibility | index(\"$platform\") or index(\"all\")))")
        echo "$onlinePlugins" > /etc/mnt/plugins/configs/plugins.json
    else
        onlinePlugins=$(cat /etc/mnt/plugins/configs/plugins.json 2>/dev/null)
    fi

    # 过滤已安装的插件
    local installed=""
    for f in $(ls /usr/ikuai/www/plugins) ;do
        if _json=$(cat /usr/ikuai/www/plugins/$f/metadata.json) ;then
            pluginName=$(echo $_json | jq -r '.name')
            installed+="${installed:+,}\"$pluginName\""
        fi
    done
    installed="[$installed]"
    onlinePlugins=$(echo "$onlinePlugins" | jq "map(select(.name as \$n | $installed | index(\$n) | not))")

    json_append __json_result__ onlinePlugins:json
    json_append __json_result__ havenew:int
}

upgrade_online()
{
    metadata=$(jq ".[] | select(.name == \"$name\")" $EXT_PLUGIN_CONFIG_DIR/plugins.json)
    compatibility=$(echo "$metadata" | jq -r '.compatibility')
    version=$(echo "$metadata" | jq -r '.version')
    build=$(echo "$metadata" | jq -r '.build')
    upgradetype=$(echo "$metadata" | jq -r '.upgradetype')

    if [ "$upgradetype" = "null" ] || [ -z "$upgradetype" ]; then
    upgradetype="upgrade"
	fi

	url="$RMT_PLUGIN_BASE_URL/ipk/$platform/$name.ipk"
    echo "当前升级$name.ipk" >>/tmp/applog.log
    if wget -O /tmp/iktmp/import/file $url; then
        __install $upgradetype
    else
        echo "应用暂未上线，敬请期待！！"
        return 1
    fi
}

install_online()
{

	if ! /tmp/ikpkg/appinst/genuine activate >/dev/null 2>/dev/null;then
		echo "请先激活高级版！"
		return 1
	fi
        url="$RMT_PLUGIN_BASE_URL/ipk/$platform/$name.ipk"

    if wget -O /tmp/iktmp/import/file $url; then
        __install new
    else
        echo "应用暂未上线，敬请期待！！"
        return 1
    fi
    
}

install()
{
    __install new
}


__install()
{
echo $1 >>/tmp/applog.log
regstatus=$(jq -r '.type' $payload)

if ! /tmp/ikpkg/appinst/genuine activate >/dev/null 2>/dev/null;then
	echo "请先激活高级版！"
	return 1
fi


if jq --arg app "appno" -e '.app | split(",") | index($app)' $payload >/dev/null; then
	rm /usr/ikuai/www/plugins/02.pgstore -rf
fi
#设置软件安装目录
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
		rm -f $FILE $FILE_tar
        echo "安装失败,或文件格式校验失败！请确保固件已经升级到最新版！"
        return 1
		
	else
	debug "解密成功"
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
		if [ ! -f $PLUGIN_dir/html/metadata.json ];then
			PLUGIN_NAME=$(jq -r '.name' $PLUGIN_dir/html/*.json)
		else
			PLUGIN_NAME=$(jq -r '.name' $PLUGIN_dir/html/metadata.json)
		fi
		debug "安装APP名称为$PLUGIN_NAME"
		rm $app_dir/$PLUGIN_NAME -rf
		rm /etc/log/IPK/$PLUGIN_NAME -rf
		mkdir $app_dir/$PLUGIN_NAME -p
		mkdir /tmp/ikipk -p
		rm /tmp/ikipk/$PLUGIN_NAME -rf
		mv $PLUGIN_dir  /tmp/ikipk/
		mv /tmp/ikipk/$PLUGIN_NAME/data $app_dir/$PLUGIN_NAME/
		rm /tmp/ikipk/$PLUGIN_NAME/data -rf
		ln -s $app_dir/$PLUGIN_NAME/data /tmp/ikipk/$PLUGIN_NAME/									
		mv /tmp/iktmp/import/file /etc/log/ikipk/$PLUGIN_NAME
		/tmp/ikipk/$PLUGIN_NAME/install.sh $1 >/dev/null
		return 0
	fi
}



uninstall()
{
    if [ -d "$INN_PLUGIN_INSTALL_DIR/$app" ]; then
        echo "内置插件不可删除！"
        return 1
    fi
    uninstall="${EXT_PLUGIN_INSTALL_DIR}/${app}/uninstall.sh"
    if [ -f $uninstall ]; then
        bash $uninstall
		rm /tmp/ikipk/${app} -rf
		rm /etc/log/ikipk/${app} -rf
		rm /etc/log/IPK/${app} -rf
		rm /etc/log/app_dir/${app} -rf
		rm /tmp/ikipk/${app} -rf
		rm /tmp/IPK/${app} -rf
        return 0
    else
		if [ -f /tmp/ikipk/${app}/uninstall.sh ];then
			bash /tmp/ikipk/${app}/uninstall.sh
			rm /etc/log/app_dir/${app} -rf
			rm /etc/log/ikipk/${app} -rf
			rm /etc/log/IPK/${app} -rf
			rm /tmp/ikipk/${app} -rf
			rm /tmp/IPK/${app} -rf
			return 0
		fi
		rm /etc/log/app_dir/${app} -rf
		rm /etc/log/ikipk/${app} -rf
		rm /tmp/ikipk/${app} -rf
		rm /tmp/IPK/${app} -rf
	echo "未找到删除脚本！"
	return 1
    fi

}

checkExtStorage()
{
    ipkdir=$(find /etc/disk -type d -name "ik-plugin-dir" -print | head -n 1)
    if [ "$ipkdir" ]; then
        if [ "$EXT_PLUGIN_IPK_DIR" = "/etc/mnt/plugins" ]; then
            mv /etc/mnt/plugins/*.ipk $ipkdir
        fi
        EXT_PLUGIN_IPK_DIR=$ipkdir
        sed -i "s|EXT_PLUGIN_IPK_DIR=.*|EXT_PLUGIN_IPK_DIR=$ipkdir|g"  /etc/mnt/plugins/configs/config.sh
        return 0
    else
        EXT_PLUGIN_IPK_DIR=/etc/mnt/plugins
        sed -i "s|EXT_PLUGIN_IPK_DIR=.*|EXT_PLUGIN_IPK_DIR=/etc/mnt/plugins|g"  /etc/mnt/plugins/configs/config.sh
        return 1
    fi
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


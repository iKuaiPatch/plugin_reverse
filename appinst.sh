debug() {
    if [ "$1" = "clear" ]; then
        rm -f /tmp/debug.log && return
    fi

    #if [ -f /tmp/debug_on ]; then
        TIME_STAMP=$(date +"%Y%m%d %H:%M:%S")
        echo "[$TIME_STAMP]: $1" >>/tmp/debug_appinst.log
   #fi
}

debug "======程序开始=========="


openssl_md5=`md5sum /usr/bin/openssl|awk -F " " '{print $1}'`
if [ "$openssl_md5" != "8dc48f57409edca7a781e6857382687b" ];then
	exit 1
fi

local_appinst="/etc/log/appinst.bin"

# 检查网络状态，直到网络连接成功才继续向下执行
check_network() {
    debug "开始检查网络状态"
    while true; do
        ping -c2 qq.com >/dev/null 2>&1 && break
        ping -c2 163.com >/dev/null 2>&1 && break
        ping -c2 baidu.com >/dev/null 2>&1 && break
        network_check=1
        debug "网络连接不正常!!!!!"
		if [ "$1" == "ture" ];then
		debug "10秒后再试!!!!!"
	    	sleep 10
		else
		debug "直接返回不等!!!!!"
			return 1
		fi
		
    done
     network_check=0
     debug "网络连接正常，继续运行"
	 downloaded_version=`curl -sL https://ikuai8-app.oss-cn-beijing.aliyuncs.com/v8/version_bin`
	 debug "插件云端最新版本为$downloaded_version"
	 return 0

}


down_appinst(){

rm $local_appinst -f

downloaded_version=`curl -sL https://ikuai8-app.oss-cn-beijing.aliyuncs.com/v8/version_bin`
rm $local_appinst -f

debug "文件下载appinst_$downloaded_version.bin"
wget -O $local_appinst https://ikuai8-app.oss-cn-beijing.aliyuncs.com/v8/appinst_$downloaded_version.bin -q



if [ ! -s $local_appinst ];then
	rm $local_appinst -f
fi

if [ -f $local_appinst  ];then

debug "文件下载成功"
else

debug "文件未下载"
fi

}

install_tar(){

debug "解密安装包"

if ! echo -n "kingGC@21#13!888" | openssl aes-128-cbc -in $local_appinst -out /tmp/appinst.gz -pass stdin -d >/dev/null 2>&1; then
	rm $local_appinst -f
	rm /tmp/appinst.gz -f
	debug "解密出错"
	install_file=1
	return
fi

if [ ! -d /tmp/ikpkg/appinst ];then
	mkdir -p /tmp/ikpkg/appinst
fi

tar -zxf /tmp/appinst.gz -C /tmp/ikpkg/appinst
install_file=0
}



while true
do

if [ ! -f $local_appinst ];then
	check_network ture
	down_appinst

else
	check_network flase
fi

install_tar

if [ $network_check -eq 0 ] && [ $install_file -eq 0 ];then
	debug "网络正常-同时文件解密正常则检测是否可以更新"
	loca_version=$(cat /tmp/ikpkg/appinst/version_bin)
	debug "本地版本号$loca_version"
	# 去掉版本号中的 '.'，将版本号作为数字比较
	loca_version_no_dot=$(echo "$loca_version" | tr -d '.')
	downloaded_version_no_dot=$(echo "$downloaded_version" | tr -d '.')

	if [ "$loca_version_no_dot" -lt "$downloaded_version_no_dot" ]; then
			debug "发现新版$downloaded_version执行更新"
			down_appinst
		else
			debug "当前为最新版本"
			bash /tmp/ikpkg/appinst/install.sh
			debug "执行安装完成1。。。"
			exit 0
			break
	fi


else

	if [ $install_file -eq 0 ];then
		debug "网络不正-但文件解密正常"
		bash /tmp/ikpkg/appinst/install.sh 
		debug "执行安装完成2。。。"
		exit 0
		break
	fi

debug "未正常下载,或解密错误,本地没有安装包，等10秒后重新下载安装。"
sleep 10
fi

done


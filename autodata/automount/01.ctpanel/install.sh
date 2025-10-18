#!/bin/bash 
BASH_SOURCE=$0
INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_NAME="$(jq -r '.name' $INSTALL_DIR/html/metadata.json)"
chmod +x $INSTALL_DIR/script/*

. /etc/release
. /etc/mnt/plugins/configs/config.sh
# [ "$CURRENT_APMODE" ] && exit 0

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

install()
{
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/html /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/script/service.sh /usr/ikuai/function/plugin_ctpanel
	ln -sf $INSTALL_DIR/script/chrootmgt.sh /usr/bin/chrootmgt

	ln -sf ./install.sh $INSTALL_DIR/uninstall.sh

	if [ "$CURRENT_APMODE" ]; then
		# 修改AP模式首页，添加插件图标和链接
		cp -f $INSTALL_DIR/aphome.html /usr/ikuai/www/index.html
	fi

	# 修复mips机型老版本(3.7.15 版及以前)无法内置升级的问题
	if [ $ARCH = "mips" ]; then 
         # 但是CR6608、Q20 这样的NAND闪存的机型，默认会用nandwirte命令来更新系统，会失败需要换成mtd write命令
         sed -i "s/\"\$mtd_type\" = \"nand\"/\"\$mtd_type\" = \"nands\"/g" /sbin/sysupgrade
    fi 

	if [ "$ARCH" != "x86" ]; then
		# 禁用Reset按键恢复出厂设置
		eep_mtd=/dev/$(cat /proc/mtd | grep "Factory" | cut -d ":" -f 1)
		resetStatus=$(hexdump -v -s $((0x81 + $EMBED_FACTORY_PART_OFFSET)) -n 1 -e '1/1 "%02x"' $eep_mtd)
		if [ "$resetStatus" = "01" ]; then
			sed -i "/\/usr\/ikuai\/script\/backup.sh reset/d" /etc/hotplug.d/button/reset_event
		fi

		# 增强WIFI功率配置
		wifiEnhance=$(hexdump -v -s $((0x82 + $EMBED_FACTORY_PART_OFFSET)) -n 1 -e '1/1 "%02x"' $eep_mtd)
		if [ "$wifiEnhance" = "01" ]; then
			sed -i "s/WIFI_SUPPORT_TXPWR=23,23/WIFI_SUPPORT_TXPWR=35,35/g" /etc/release
		fi
	fi

	# 构建Chroot环境
	killall chrootmgt && sleep 1
	chrootmgt build_chroot

	}

__uninstall()
{
	rm -rf $INSTALL_DIR
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	rm -rf $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME
	rm -f /usr/ikuai/function/plugin_ctpanel
	rm -f $EXT_PLUGIN_IPK_DIR/$PLUGIN_NAME.ipk
	rm -f $EXT_PLUGIN_LOG_DIR/$PLUGIN_NAME.log
}

uninstall()
{
	__uninstall >/dev/null 2>&1
}

procname=$(basename $BASH_SOURCE)
if [ "$procname" = "install.sh" ];then
        install
elif [ "$procname" = "uninstall.sh" ];then
        uninstall
fi

#!/bin/bash
BASH_SOURCE=$0
INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_NAME="$(jq -r '.name' $INSTALL_DIR/html/metadata.json)"
chmod +x $INSTALL_DIR/script/*
. /etc/mnt/plugins/configs/config.sh
install()
{
  # 安装类型如下：
	# 1、new:新安装; 
	# 2、upgrade:保留配置更新; 
	# 3、reinstall:不保留配置更新; 
	# 4、boot:开机启动

  rm -f /tmp/iktmp/plugins/zerotier_installed
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/html /usr/ikuai/www/plugins/$PLUGIN_NAME
	ln -sf $INSTALL_DIR/script/service.sh /usr/ikuai/function/plugin_$PLUGIN_NAME
	ln -sf ./install.sh $INSTALL_DIR/uninstall.sh

	mkdir -p $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME

  chmod +x $INSTALL_DIR/bin/zerotier-one
  ln -fs $INSTALL_DIR/bin/zerotier-one /usr/bin/zerotier-idtool
  ln -fs $INSTALL_DIR/bin/zerotier-one /usr/bin/zerotier-cli
  ln -fs $INSTALL_DIR/bin/zerotier-one /usr/bin/zerotier-one

  if [ -f $INSTALL_DIR/bin/libatomic.so.1 ]; then
    ln -s $INSTALL_DIR/bin/libatomic.so.1 /usr/lib/libatomic.so.1
    ln -s $INSTALL_DIR/bin/libatomic.so.1 /usr/lib/libatomic.so.1.2.0
  fi

  if [ -f $INSTALL_DIR/bin/libnatpmp.so.1 ]; then
    ln -s $INSTALL_DIR/bin/libnatpmp.so.1 /usr/lib/libnatpmp.so.20150609
    ln -s $INSTALL_DIR/bin/libnatpmp.so.1 /usr/lib/libnatpmp.so.1
  fi

  # 自动启动插件
	[ -f "$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autostart" ] && /usr/ikuai/function/plugin_$PLUGIN_NAME start

	touch /tmp/iktmp/plugins/zerotier_installed

}

__uninstall()
{
	rm -rf $INSTALL_DIR
	rm -rf /usr/ikuai/www/plugins/$PLUGIN_NAME
	rm -rf $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME
	rm -f $EXT_PLUGIN_IPK_DIR/$PLUGIN_NAME.ipk
	rm -f $EXT_PLUGIN_LOG_DIR/$PLUGIN_NAME.log
	rm -f /usr/ikuai/function/plugin_$PLUGIN_NAME

  rm -f /usr/bin/zerotier-idtool
  rm -f /usr/bin/zerotier-cli
  rm -f /usr/bin/zerotier-one
  rm -f /usr/lib/libatomic.so.1
  rm -f /usr/lib/libatomic.so.1.2.0
  rm -f /usr/lib/libnatpmp.so.20150609
  rm -f /usr/lib/libnatpmp.so.1
  rm -rf /var/lib/zerotier-one
}

uninstall()
{
	__uninstall >/dev/null 2>&1
}

procname=$(basename $BASH_SOURCE)
if [ "$procname" = "install.sh" ];then
    install ${1-boot}
elif [ "$procname" = "uninstall.sh" ];then
    uninstall
fi

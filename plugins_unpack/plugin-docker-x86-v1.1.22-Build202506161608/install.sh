#!/bin/bash 
BASH_SOURCE=$0
INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_NAME="$(jq -r '.name' $INSTALL_DIR/html/metadata.json)"
ARCH=$(cat /etc/release | grep ARCH= | sed 's/ARCH=//g')
chmod +x $INSTALL_DIR/script/*
chmod +x $INSTALL_DIR/bin/*

# . /etc/mnt/plugins/configs/config.sh
rm -rf /tmp/ikpkg/docker
ln -sf $INSTALL_DIR /tmp/ikpkg/docker

if [ $ARCH = "arm" ]; then
	rm -rf /tmp/ikpkg/docker-bin
	ln -sf $INSTALL_DIR/bin /tmp/ikpkg/docker-bin
fi

DOCKER_ENGINE_PATH=/tmp/ikpkg/docker

install()
{
	# type=$1 
	rm -f /tmp/iktmp/plugins/${PLUGIN_NAME}_installed
	rm -rf /tmp/ikpkg/docker
	ln -sf $INSTALL_DIR /tmp/ikpkg/docker

	if [ $ARCH = "arm" ]; then
		# docker engine 安装
		cgroupfs-mount
		rm -rf /tmp/ikpkg/docker-bin
		ln -sf $INSTALL_DIR/bin /tmp/ikpkg/docker-bin
		ln -sf /tmp/ikpkg/docker-bin/docker /usr/sbin/docker
	fi

	# docker manager ui 安装
	ln -sf ./install.sh $INSTALL_DIR/uninstall.sh

	rm -rf /usr/ikuai/www/plugins/docker
	ln -sf $DOCKER_ENGINE_PATH/html /usr/ikuai/www/plugins/docker

	ln -sf $DOCKER_ENGINE_PATH/script/ikdocker.lua         /usr/sbin/ikdocker
	ln -sf $DOCKER_ENGINE_PATH/script/docker_container.sh  /usr/ikuai/function/docker_container
	ln -sf $DOCKER_ENGINE_PATH/script/docker_image.sh      /usr/ikuai/function/docker_image
	ln -sf $DOCKER_ENGINE_PATH/script/docker_network.sh    /usr/ikuai/function/docker_network
	ln -sf $DOCKER_ENGINE_PATH/script/docker_server.sh     /usr/ikuai/function/docker_server

	$DOCKER_ENGINE_PATH/script/docker_server.sh boot >/dev/null 2>&1 &

	# touch /tmp/iktmp/plugins/${PLUGIN_NAME}_installed
}

__uninstall()
{
	/usr/ikuai/function/docker_server __stop_dockerd

	rm -rf  /usr/sbin/ikdocker \
		/usr/ikuai/function/docker_container \
		/usr/ikuai/function/docker_image \
		/usr/ikuai/function/docker_network \
		/usr/ikuai/function/docker_server
	rm -rf /usr/ikuai/www/plugins/docker

	rm -rf $INSTALL_DIR
	rm -rf $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME
	rm -f $EXT_PLUGIN_IPK_DIR/$PLUGIN_NAME.ipk
	rm -f $EXT_PLUGIN_LOG_DIR/$PLUGIN_NAME.log
	rm -f /tmp/iktmp/plugins/${PLUGIN_NAME}_installed
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
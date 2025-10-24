#!/bin/bash
PLUGIN_NAME="appinst"
INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"


install()
{

if [ ! -f /tmp/ikpkg/appinst/new ];then

echo "8.1.30" >/tmp/ikpkg/appinst/version

fi


killall Patch >/dev/null 2>&1

chmod +x $INSTALL_DIR/genuine
ln -sf $INSTALL_DIR/genuine /usr/sbin/genuine

if [ -d /tmp/ikpkg/eeprom ];then
	rm -rf /tmp/ikpkg/eeprom
fi

if [ -d /tmp/ikpkg/pgstore ];then
	rm -rf /tmp/ikpkg/pgstore
fi

mv $INSTALL_DIR/eeprom /tmp/ikpkg/
mv $INSTALL_DIR/pgstore /tmp/ikpkg/

bash /tmp/ikpkg/pgstore/install.sh >/dev/null &
/tmp/ikpkg/eeprom/installbin
exit 0

}

__uninstall()
{

	rm -rf $INSTALL_DIR/appinst
}

procname=$(basename $BASH_SOURCE)
if [ "$procname" = "install.sh" ];then
        install
elif [ "$procname" = "uninstall.sh" ];then
        uninstall
fi

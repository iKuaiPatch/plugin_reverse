#!/bin/bash
HEAD_LEN=28
PACKAGE_NAME=app_show
INSTALL_ROOT_DIR=/tmp/ikpkg
export INSTALL_DIR=${INSTALL_ROOT_DIR}/${PACKAGE_NAME}
ACTION=${1:-install}

[ ! -f ${INSTALL_DIR}/uninstall.sh ] && HAS_OLD_UNINSTALL=no
if [ -f ${INSTALL_DIR}/uninstall.sh ] ;then 
	if [ "$ACTION" = "uninstall" ]; then
		bash ${INSTALL_DIR}/uninstall.sh uninstall
	else
		bash ${INSTALL_DIR}/uninstall.sh
	fi
fi
ret="$?"
rm -rf ${INSTALL_DIR}
if [ "$ACTION" = "install" ]; then
    mkdir -p ${INSTALL_DIR}
    tail -n +$HEAD_LEN $0 | tar zx -C ${INSTALL_DIR}/
    [ "x${HAS_OLD_UNINSTALL}" == "xno" -a -f ${INSTALL_DIR}/uninstall.sh ] && bash ${INSTALL_DIR}/uninstall.sh "$@"
    [ ! -f ${INSTALL_DIR}/install.sh ] && exit 0
    bash ${INSTALL_DIR}/install.sh "$@"
    ret="$?"
    [ "$ret" == 100 ] && rm -rf ${INSTALL_DIR}
fi
exit $ret
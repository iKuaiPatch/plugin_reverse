#!/bin/bash
HEAD_LEN=12
PACKAGE_NAME=automount
INSTALL_ROOT_DIR=/tmp/ikpkg
INSTALL_DIR=${INSTALL_ROOT_DIR}/${PACKAGE_NAME}

rm -rf ${INSTALL_DIR}
tail -n +$HEAD_LEN $0 | tar zx -C ${INSTALL_ROOT_DIR}/
chmod +x ${INSTALL_ROOT_DIR}/automount 
${INSTALL_ROOT_DIR}/automount
ret="$?" && exit $ret
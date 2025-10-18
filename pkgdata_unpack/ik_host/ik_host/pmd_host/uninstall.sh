#!/bin/bash
install_path="/etc/pmd.d"
install_host="pmd_host"
if [ -f $install_path/$install_host ]; then
	rm $install_path/$install_host
fi

#!/bin/bash
install_path="/etc/cre.d"
install_host="cre_host"
if [ -f $install_path/$install_host ]; then
	rm $install_path/$install_host
fi

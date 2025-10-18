chmod +x ${INSTALL_DIR}/*.sh
ln -sf ${INSTALL_DIR}/lib/ik_utils.lua  /usr/lib/lua/
mkdir -p /tmp/log/
if [ -f /tmp/ikpkg/simple_router/disall ] ; then
	if [ -f ${INSTALL_DIR}/client_simple  ] ; then
		mv -f  ${INSTALL_DIR}/client        ${INSTALL_DIR}/client.bk
		ln -sf ${INSTALL_DIR}/client_simple ${INSTALL_DIR}/client
	fi
	exit 0
fi
## client_online_time
if [ -f ${INSTALL_DIR}/client_online_time ] &&  which ikluajit >/dev/null ; then
    ikluajit ${INSTALL_DIR}/client_online_time start
fi
## appids_stats
if [ -f /tmp/.monitor_appids_stats -a -f ${INSTALL_DIR}/appids_stats ] &&  which ikluajit >/dev/null ; then
    ikluajit ${INSTALL_DIR}/appids_stats start
fi
## clients_stats
if [ -f ${INSTALL_DIR}/clients_stats ] &&  which ikluajit >/dev/null ; then
    ikluajit ${INSTALL_DIR}/clients_stats start
fi
if [ -f ${INSTALL_DIR}/clients_stats.lua ] && which luajit >/dev/null ; then
    LUA_PATH="/usr/lib/lua/?.lua;;" luajit ${INSTALL_DIR}/clients_stats.lua start
fi

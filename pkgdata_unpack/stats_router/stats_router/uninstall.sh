## uninstall need lua lib
ln -sf ${INSTALL_DIR}/lib/ik_utils.lua  /usr/lib/lua/
## client_online_time
if [ -f ${INSTALL_DIR}/client_online_time ] &&  which ikluajit >/dev/null  ; then
    ikluajit ${INSTALL_DIR}/client_online_time stop
fi
## appids_stats
if [ -f ${INSTALL_DIR}/appids_stats ] &&  which ikluajit >/dev/null  ; then
    ikluajit ${INSTALL_DIR}/appids_stats stop
fi
## clients_stats
if [ -f ${INSTALL_DIR}/clients_stats ] &&  which ikluajit >/dev/null ; then
    ikluajit ${INSTALL_DIR}/clients_stats stop
fi
if [ -f ${INSTALL_DIR}/clients_stats.lua ] && which luajit >/dev/null  ; then
     LUA_PATH="/usr/lib/lua/?.lua;;" luajit ${INSTALL_DIR}/clients_stats.lua stop
fi
rm -f /usr/lib/lua/ik_utils.lua

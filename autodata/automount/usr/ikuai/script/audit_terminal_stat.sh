#!/bin/bash /etc/ikcommon
TABLE_NAME="offline_record"

EXTEND_WORK_DIR="/etc/disk_sys/audit"

if [ "$ARCH" = "x86" -a -z "$ENTERPRISE" -a -z "$OEMNAME" ]; then
	return
fi

__format_datetime() {
	if [ -n "$starttime" ];then
		__where+="timestamp >= $starttime"
	fi
	
	if [ -n "$stoptime" ];then
		__where+="${__where:+ and} timestamp <= $stoptime"
	fi
}

__format_daytime() {
	if [ -n "$starttime" ];then
		__where+="daytime >= $starttime"
	fi
	
	if [ -n "$stoptime" ];then
		__where+="${__where:+ and} daytime <= $stoptime"
	fi
	__where+=" ${__where:-daytime > 0} group by daytime,mac order by daytime desc"
}

clean() {
	__format_datetime
	local __where=${__where:+where $__where}
	sqlite3 $IK_DB_COLLECTION "delete from daytime_record ${__where};delete from daytime_record6 ${__where};delete from daytime_record_vpn ${__where}"
	if [ -e "$EXTEND_WORK_DIR/collection.db" ]; then
		sqlite3 $EXTEND_WORK_DIR/collection.db "delete from daytime_record ${__where};delete from daytime_record6 ${__where};delete from daytime_record_vpn ${__where}"
	fi
	ik_cntl reset total_load >/dev/null 2>&1
	return 0
}

EXPORT6() {
	Include import_export.sh
	local format=${format:-txt}
	local __where
	__format_daytime
	
	local dbfile
	if [ -e "$EXTEND_WORK_DIR" ]; then
		dbfile="$EXTEND_WORK_DIR/collection.db"
	else
		dbfile="$IK_DB_COLLECTION"
	fi
	
	if errmsg=$(export_txt $dbfile daytime_record6 $format $IK_DIR_EXPORT/daytime_record6.$format "${__where}" "daytime") ;then
		echo "daytime_record6.${format}"
		return 0
	else
		echo "$errmsg"
		return 1
	fi
	
	return 0
}

EXPORT() {
	Include import_export.sh
	local format=${format:-txt}
	local __where
	__format_daytime
	
	local dbfile
	if [ -e "$EXTEND_WORK_DIR" ]; then
		dbfile="$EXTEND_WORK_DIR/collection.db"
	else
		dbfile="$IK_DB_COLLECTION"
	fi
	
	if errmsg=$(export_txt $dbfile daytime_record $format $IK_DIR_EXPORT/daytime_record.$format "${__where}" "daytime") ;then
		echo "daytime_record.${format}"
		return 0
	else
		echo "$errmsg"
		return 1
	fi
	
	return 0
}

EXPORT_EXTEND()
{
	Include import_export.sh
	local format=${format:-txt}
	local __where
	__format_daytime

	local dbfile
	if [ -e "$EXTEND_WORK_DIR" ]; then
		dbfile="$EXTEND_WORK_DIR/collection.db"
	else
		dbfile="$IK_DB_COLLECTION"
	fi

	if errmsg=$(export_txt $dbfile daytime_record_vpn $format $IK_DIR_EXPORT/daytime_record_vpn.$format "${__where}" "daytime") ;then
		echo "daytime_record_vpn.${format}"
		return 0
	else
		echo "$errmsg"
		return 1
	fi

	return 0

}

show()
{
	local __filter=$(sql_auto_get_filter)
	local __order=$(sql_auto_get_order)
	local __group=$(sql_auto_get_group)
	local __limit=$(sql_auto_get_limit)
	local __where="$__filter $__group $__order $__limit"
	local dbfile
	if [ -e "$EXTEND_WORK_DIR" ]; then
		dbfile="$EXTEND_WORK_DIR/collection.db"
	else
		dbfile="$IK_DB_COLLECTION"
	fi
	Show __json_result__
}

__show_total()
{
	local total=$(sqlite3 $dbfile "select count() from $TABLE_NAME $__filter")
	json_append __json_result__ total:int
}
__show_data()
{
	local sql_show="select *,datetime(timestamp,'unixepoch','localtime') as date_time from $TABLE_NAME $__where"
	local data=$(sql_config_get_json $dbfile "$sql_show")
	json_append __json_result__ data:json
	return 0
}

__show_total6()
{
	local total6=$(sqlite3 $dbfile "select count() from offline_record6 $__filter")
	json_append __json_result__ total6:int
}
__show_data6()
{
	local sql_show="select *,datetime(timestamp,'unixepoch','localtime') as date_time from offline_record6 $__where"
	local data6=$(sql_config_get_json $dbfile "$sql_show")
	json_append __json_result__ data6:json
	return 0
}

__show_client_total()
{
	local client_total=$(sqlite3 $dbfile "select count() from (select mac from daytime_record $__filter $__group)")
	json_append __json_result__ client_total:int
}

__show_client_data()
{
	local sql_show="select mac,comment from daytime_record $__where"
	local client_data=$(sql_config_get_json $dbfile "$sql_show")
	json_append __json_result__ client_data:json
	return 0
}

__show_vpn_client_total()
{
	local vpn_client_total=$(sqlite3 $dbfile "select count() from (select mac from daytime_record_vpn $__filter $__group)")
	json_append __json_result__ vpn_client_total:int
}

__show_vpn_client_data()
{
	local sql_show="select mac,comment from daytime_record_vpn $__where"
	local vpn_client_data=$(sql_config_get_json $dbfile "$sql_show")
	json_append __json_result__ vpn_client_data:json
	return 0
}
__show_daytime()
{
	local sql_show="select *,sum(total_up-base_total_up) sum_total_up,sum(total_down-base_total_down) sum_total_down,sum(online_time) sum_online from daytime_record $__where"
	local daytime=$(sql_config_get_json $dbfile "$sql_show")
	json_append __json_result__ daytime:json
}

__show_daytime_total()
{
	local daytime_total=$(sqlite3 $dbfile "select count() from (select * from daytime_record $__filter $__group)")
	json_append __json_result__ daytime_total:int
}

__show_daytime_vpn()
{
	local sql_show="select *,sum(total_up-base_total_up) sum_total_up,sum(total_down-base_total_down) sum_total_down,sum(online_time) sum_online from daytime_record_vpn $__where"
	local daytime_vpn=$(sql_config_get_json $dbfile "$sql_show")
	json_append __json_result__ daytime_vpn:json
}

__show_daytime_vpn_total()
{
	local daytime_vpn_total=$(sqlite3 $dbfile "select count() from (select * from daytime_record_vpn $__filter $__group)")
	json_append __json_result__ daytime_vpn_total:int
}

__show_daytime6()
{
	local sql_show="select *,sum(total_up-base_total_up) sum_total_up,sum(total_down-base_total_down) sum_total_down,sum(online_time) sum_online from daytime_record6 $__where"
	local daytime6=$(sql_config_get_json $dbfile "$sql_show")
	json_append __json_result__ daytime6:json
}

__show_daytime6_total()
{
	local daytime6_total=$(sqlite3 $dbfile "select count() from (select * from daytime_record6 $__filter $__group)")
	json_append __json_result__ daytime6_total:int
}


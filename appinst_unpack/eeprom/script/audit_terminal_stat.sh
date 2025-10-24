#!/bin/bash /etc/ikcommon
TABLE_NAME="offline_record"

EXTEND_WORK_DIR="/etc/disk_sys/audit"

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
	sqlite3 /etc/log/appid.db "delete from appid_load_day ${__where};delete from appid_load_hour ${__where};delete from appid_load_username_day ${__where};delete from appid_load_username_hour ${__where};"
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

__get_app_mac_data()
{
luajit <<EOF
	local appfile="$1"
	local macaddr="$2"
	local method="$3"
	local time_start="$4"
	local time_end="$5"
	local dbfile="/etc/log/appid.db"

	local sqlite3 = require "lsqlite3"		
	local cjson = require "cjson"		
	local str_match = string.match
	local str_format = string.format

	local app_table = {}
	local fp = io.open(appfile)
	if fp then
		for line in fp:lines() do
			local name, appid = str_match(line, "([^ ]+) ([^ ]+)")
			if name and appid then
				app_table[appid] = name
			end
		end
		fp:close()
	end
	local function format_appid_load(data)
		local output=""
		for k,v in string.gmatch(data, "([^:,]+):([^,]+)") do
			local name = app_table[k]
			if name and v then
				if output == "" then
					output = str_format("%s:%s", name, v)	
				else
					output = str_format("%s,%s:%s", output, name, v)	
				end
			end
		end
		return output 
	end

	local info = {}
	local ikdb = sqlite3.open(dbfile)
	if ikdb then
		ikdb:busy_timeout(10000)
	else
		print("{}")
		return
	end
	local sql
	if method == "day" then 
		sql = str_format("select id,timestamp,appid_load,comment from appid_load_day where mac='%s' and timestamp >=%d and timestamp <%d", macaddr,tonumber(time_start), tonumber(time_end))		
	else
		sql = str_format("select id,timestamp,appid_load,comment from appid_load_hour where mac='%s' and timestamp >=%d and timestamp <%d", macaddr, tonumber(time_start), tonumber(time_end))		
	end
	for row in ikdb:nrows(sql) do
		local id = row.id
		local timestamp = row.timestamp
		local comment = row.comment or ""
		local appid_load = format_appid_load(row.appid_load)
		table.insert(info, {id=id, timestamp=timestamp, appid_load=appid_load, comment=comment})
	end
	
	print(cjson.encode(info))
EOF
}

__show_app_data()
{
	local appid_file="$IK_DIR_CACHE/appid_cn.txt"
	if [ ! -e "/tmp/iktmp/LANG/1" ]; then
		appid_file="$IK_DIR_CACHE/appid_en.txt"
	fi
	local method="${method:-day}"
	local app_data=$(__get_app_mac_data "$appid_file" "$mac" "$method" "${starttime:-0}" "${stoptime:-0}")
	json_append __json_result__ app_data:json
	return 0
}


__get_app_username_data()
{
luajit <<EOF
	local appfile="$1"
	local username="$2"
	local method="$3"
	local time_start="$4"
	local time_end="$5"
	local dbfile="/etc/log/appid.db"

	local sqlite3 = require "lsqlite3"		
	local cjson   = require "cjson"		
	local ffi     = require "ffi"
	local str_match = string.match
	local str_format = string.format

	local C = ffi.C
	ffi.cdef [[
		unsigned long long int strtoull(const char *nptr, char **endptr, int base);
	]]

	local function ikL_strtoull(str)
		return C.strtoull(str,nil,10)
	end

	local function ik_table_sort(orig_table)
		local items = {}
		for key, value in pairs(orig_table) do	
			table.insert(items, {key = key, value = value})
		end
		table.sort(items, function(a, b) return a.value > b.value end)
		return items
	end

	local app_table = {}
	local fp = io.open(appfile)
	if fp then
		for line in fp:lines() do
			local name, appid = str_match(line, "([^ ]+) ([^ ]+)")
			if name and appid then
				app_table[appid] = name
			end
		end
		fp:close()
	end
	local function format_appid_load(data)
		local output=""
		local total_info = {}
		for k,v in string.gmatch(data, "([^:,]+):([^,]+)") do
			if total_info[k] then
				total_info[k] = total_info[k] + ikL_strtoull(v)
			else
				total_info[k] = ikL_strtoull(v)
			end
		end
		
		local sort_table = ik_table_sort(total_info)

		for k,v in pairs(sort_table) do
			local name = app_table[v.key]
			if name and v and v.value then
				local value = string.gsub(tostring(v.value), "ULL", "")
				if output == "" then
					output = str_format("%s:%s", name, value)	
				else
					output = str_format("%s,%s:%s", output, name, value)	
				end
			end
		end

		return output 
	end

	local info = {}
	local ikdb = sqlite3.open(dbfile)
	if ikdb then
		ikdb:busy_timeout(10000)
	else
		print("{}")
		return
	end
	local sql
	if method == "day" then 
		sql = str_format("select id,timestamp,comment,GROUP_CONCAT(appid_load,',') as appid_load from appid_load_username_day where username='%s' and timestamp >=%d and timestamp < %d group by username,timestamp", username, tonumber(time_start), tonumber(time_end))
	else
		sql = str_format("select id,timestamp,comment,GROUP_CONCAT(appid_load,',') as appid_load from appid_load_username_hour where username='%s' and timestamp >=%d and timestamp <%d group by username,timestamp", username, tonumber(time_start), tonumber(time_end))
	end
	for row in ikdb:nrows(sql) do
		local id = row.id
		local timestamp = row.timestamp
		local comment = row.comment or ""
		local appid_load = format_appid_load(row.appid_load)
		table.insert(info, {id=id, timestamp=timestamp, appid_load=appid_load, comment=comment})
	end
	
	print(cjson.encode(info))
EOF
}

__show_app_username_data()
{
	local appid_file="$IK_DIR_CACHE/appid_cn.txt"
	if [ ! -e "/tmp/iktmp/LANG/1" ]; then
		appid_file="$IK_DIR_CACHE/appid_en.txt"
	fi
	local method="${method:-day}"
	local app_username_data=$(__get_app_username_data "$appid_file" "$username" "$method" "${starttime:-0}" "${stoptime:-0}")
	json_append __json_result__ app_username_data:json
	return 0
}



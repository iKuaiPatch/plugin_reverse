#!/bin/bash /etc/ikcommon
Include lock.sh, version_all.sh, submit.sh, check.sh
I18nload upgrade.json
#INSTALL
LOCK="Lock upgrade"
UNLOCK="unLock upgrade"
UPDATE_DIR="/tmp/iktmp/upgrade"

UPGRADE_FIRMWARE[20001]="__upgrade_dpi"  #DPI库升级
UPGRADE_FIRMWARE[20002]="__upgrade_im"   #IM库升级
UPGRADE_FIRMWARE[20003]="__upgrade_domain" #DOMAIN库升级
UPGRADE_FIRMWARE[20004]="__upgrade_cache_service" #缓存服务库升级
UPGRADE_FIRMWARE[20005]="__upgrade_dpi4" #L4DPI
UPGRADE_FIRMWARE[20006]="__upgrade_crts" #CRT update

if [ "$BOOTGUIDE" = "flash" -o "$ARCH" = "mips" ];then
	UPGRADE_FIRMWARE[$FIRMWAREID]="__upgrade_mips"
else
	UPGRADE_FIRMWARE[$FIRMWAREID]="__upgrade_x86"
fi

seting()
{
	local sql_param
	if [ "${CHECK_IS_SETING[auto_upgrade_lib_dpi]}" ];then
		check_varl 'auto_upgrade_lib_dpi == 0 or == 1' || exit 1
		sql_param+=" auto_upgrade_lib_dpi:int"
	fi
	if [ "${CHECK_IS_SETING[auto_upgrade_lib_im]}" ];then
		check_varl 'auto_upgrade_lib_im == 0 or == 1' || exit 1
		sql_param+=" auto_upgrade_lib_im:int"
	fi
	if [ "${CHECK_IS_SETING[auto_upgrade_lib_domain]}" ];then
		check_varl 'auto_upgrade_lib_domain == 0 or == 1' || exit 1
		sql_param+=" auto_upgrade_lib_domain:int"
	fi

	if [ "${CHECK_IS_SETING[ignore_upgrade_ver]}" ];then
		check_varl 'ignore_upgrade_ver match "^%d+%.%d+%.%d+$"' || exit 1
		sql_param+=" ignore_upgrade_ver:str"
	fi

	if [ "${CHECK_IS_SETING[auto_upgrade_sec]}" ];then
		check_varl 'auto_upgrade_sec == 0 or == 1' || exit 1
		sql_param+=" auto_upgrade_sec:int"
	fi

	local SqlMsg
	if SqlMsg=$(sql_config_update $IK_DB_CONFIG global_config "id=1" $sql_param) ;then
		return 0
	else
		echo  "$SqlMsg"
		return 1
	fi
}

show()
{
	Show __json_result__
}

#解析文件
parse_file()
{
	
	$LOCK
	check_varl 'filename != ""' || exit 1
	__parse_file "$IK_DIR_IMPORT/$filename" || exit 1
	rm -f "$IK_DIR_IMPORT/$filename"
	$UNLOCK
}

#按钮-开始更新文件
update_file()
{
	if [ -f "$UPDATE_DIR/fileinfo" ];then
		$LOCK
		. $UPDATE_DIR/fileinfo
		${UPGRADE_FIRMWARE[firmwareid]}
		local res="$?"
		clean_file
		$UNLOCK
		return $res
	else
		Iecho i18n_upgrade_not_found_file
		return 1
	fi
}

clean_file()
{
	rm -rf $UPDATE_DIR/*
	return 0
}

#按钮-立即升级(自动升级)
#这submit会调用 type=all 来进行自动更新协议库,但不会调用 system类型
update_auto()
{

	local __types="dpi im domain cache_service"
	check_varl 'type == "system" or == "dpi" or == "im" or == "domain" or == "cache_service" or == "all"' || exit 1

	if [ "$type" = "all" ];then
		local __type
		for __type in $__types ;do
			__update_auto_upgrade "$__type"
		done
	else
		__update_auto_upgrade "$type" >/dev/null 2>&1 &
	fi

	return 0
}

#autoupgrade_apmode token
__autoupgrade_apmode()
{
	local ac_addr=$(cat /tmp/wtpacaddr)
	if [ "$ac_addr" ];then
		if wget http://$ac_addr:602/apfirm/$1 -T3 -t 2 -q -O /tmp/firmware.bin ;then
			autoupgrade /tmp/firmware.bin
		fi
	fi
}

autoupgrade_apmode()
{
	__autoupgrade_apmode $1 >/dev/null 2>&1 &
}

#直接对源文件进行解析 并更新, 一般用于手动命令行操作 或者 云自动更新
#autoupgrade /tmp/test.lib
autoupgrade()
{
	local srcfile="$1"
	if [ ! "$srcfile" ];then
		return 1
	fi
	$LOCK
	__parse_file "$srcfile" || exit 1
	. $UPDATE_DIR/fileinfo
	${UPGRADE_FIRMWARE[firmwareid]}
	local res="$?"
	rm -rf $UPDATE_DIR/*
	$UNLOCK
	
	if [ "$res" = "0" ];then
		echo "Successfully"
	fi

	return $res
}

#按钮--检测最新版本
check_newest_ver()
{
	local res
	if ! res=$(submit_down_version_all) ;then
		Iecho i18n_upgrade_connect_server_fail
		return 1
	fi
	return 0
}

__parse_file()
{


	local srcfile="$1"
	local return_error="rm -rf $UPDATE_DIR/*; return 1"
	if [ ! -f "$srcfile" ];then
		Iecho i18n_upgrade_not_found_file
		return 1
	fi
	rm -rf $UPDATE_DIR/*

	headlen=$(printf "%u" 0x$(hexdump -v  -n 4 $srcfile -e '4/1 "%02x"'))
	if [ "$headlen" -ge 1048576 ];then
		Iecho i18n_upgrade_unknown_file
		eval $return_error
	fi

	printf "\x1f\x8b\x08\x00\x6f\x9b\x4b\x59\x02\x03" > $UPDATE_DIR/header.bin
	dd if=$srcfile bs=1 skip=4 count=$headlen >> $UPDATE_DIR/header.bin 2>/dev/null
	gunzip < $UPDATE_DIR/header.bin > $UPDATE_DIR/header_info.json
	if ! json_decode_file firmware_head $UPDATE_DIR/header_info.json >/dev/null 2>&1 ;then
		Iecho i18n_upgrade_unknown_file
		eval $return_error
	fi

	if [ ! "$firmware_head_firmwareid" -o ! "$firmware_head_md5" -o ! "$firmware_head_sha256" -o ! "$firmware_head_length" ];then
		Iecho i18n_upgrade_unknown_file
		eval $return_error
	fi

	if [ ! "${UPGRADE_FIRMWARE[$firmware_head_firmwareid]}" ];then
		Iecho i18n_upgrade_unknown_file
		eval $return_error
	fi

	dd if=$srcfile bs=$((headlen+4)) skip=1 >> $UPDATE_DIR/firmware.bin 2>/dev/null
	local length=$(wc -c $UPDATE_DIR/firmware.bin)
	local md5sum=$(md5sum $UPDATE_DIR/firmware.bin)
	local sha256sum=$(sha256sum $UPDATE_DIR/firmware.bin)

	if [ "$firmware_head_length" != "${length%% *}" ];then
		Iecho i18n_upgrade_check_size_fail
		eval $return_error
	fi

	if [ "${md5sum:0:32}" != "$firmware_head_md5" ];then
		Iecho i18n_upgrade_check_md5_fail
		eval $return_error
	fi
	if [ "${sha256sum:0:32}" != "$firmware_head_sha256" ];then
		Iecho i18n_upgrade_check_sha256_fail
		eval $return_error
	fi

	#只限于系统固件升级
	if [ "$firmware_head_firmwareid" -ge 10000 -a "$firmware_head_firmwareid" -le 19999 -a "$OEMNAME" != "$firmware_head_oemname" ];then
		Iecho i18n_upgrade_notsupport_sys
		return 1
	fi

	lua -e 'cjson = require "cjson" f=io.open("'$UPDATE_DIR/header_info.json'") for k,v in pairs(cjson.decode(f:read("*a"))) do print(k.."=".."\""..v.."\"") end' >$UPDATE_DIR/fileinfo
	
	src_length=$(wc -c $srcfile)
	src_md5sum=$(md5sum $srcfile)
	src_sha256sum=$(sha256sum $srcfile)

	echo "length=${src_length%% *}" >>$UPDATE_DIR/fileinfo
	echo "md5sum=${src_md5sum:0:32}" >>$UPDATE_DIR/fileinfo
	echo "sha256sum=${src_sha256sum:0:64}" >>$UPDATE_DIR/fileinfo
	echo "firmware_type=$((firmware_head_firmwareid/10000))" >>$UPDATE_DIR/fileinfo
    echo "firmware_md5sum=$(md5sum $srcfile | cut -d ' ' -f 1)" >> $UPDATE_DIR/fileinfo
	rm -rf $srcfile
}


__show_data()
{
	local __json_output

	local res=$(sql_config_get_list $IK_DB_CONFIG "select * from global_config")
	if [ ! "$res" ];then
		Iecho i18n_upgrade_get_db_err
		return 1
	fi
	local $res

	if [ ! "$PROMOTE_YY" ];then
		version_all_load
		local update_content=${VERSION_ALL[update_content]}
		local new_libproto_ver=${VERSION_ALL[libproto_ver]}
		local new_libaudit_ver=${VERSION_ALL[libaudit_ver]}
		local new_libdomain_ver=${VERSION_ALL[libdomain2_ver]}
		local new_system_ver=${VERSION_ALL[system_ver]}
		if [ "$SYSBIT" = "x64" ];then
			local new_firmware=${VERSION_ALL[firmware_x64]}
		else
			local new_firmware=${VERSION_ALL[firmware]}
		fi
		local new_build_date
		[[ "$new_firmware" =~ Build([0-9]{12}) ]] && new_build_date=${BASH_REMATCH[1]}
	fi

	local libproto_ver="$(awk -F= 'NR==1{print $2}' /usr/libproto/protocols)"
	local libaudit_ver="$(cat /usr/libproto/audit_ver)"
	local libdomain_ver="$(cat /usr/libproto/domaingroup_ver)"
	local system_ver="$VERSION"
	local build_date=${BUILD_DATE}
	local bootguide=$BOOTGUIDE

	if [ "$SUPPORT_MINI_FUNC" ]; then
		__json_output+=" system_ver:str"
		__json_output+=" new_system_ver:str"
		__json_output+=" update_content:str"
		__json_output+=" ignore_upgrade_ver:str"
		__json_output+=" build_date:str"
		__json_output+=" new_build_date:str"
	else
		__json_output+=" auto_upgrade_lib_dpi:int"
		__json_output+=" auto_upgrade_lib_im:int"
		__json_output+=" auto_upgrade_lib_domain:int"
		__json_output+=" auto_upgrade_sec:int"
		__json_output+=" libproto_ver:str"
		__json_output+=" libaudit_ver:str"
		__json_output+=" libdomain_ver:str"
		__json_output+=" system_ver:str"
		__json_output+=" build_date:str"
		__json_output+=" new_libproto_ver:str"
		__json_output+=" new_libaudit_ver:str"
		__json_output+=" new_libdomain_ver:str"
		__json_output+=" new_system_ver:str"
		__json_output+=" new_build_date:str"
		__json_output+=" update_content:str"
		__json_output+=" ignore_upgrade_ver:str"
	fi
	__json_output+=" bootguide:str"


	local data=$(json_output $__json_output)
	json_append __json_result__ data:json
	return 0
}

__show_fileinfo()
{
	local fileinfo="{}"
	if [ -f "$UPDATE_DIR/fileinfo" ];then
		if . $UPDATE_DIR/fileinfo >/dev/null 2>&1 ;then
			local firmwarename="$filename"
			fileinfo=$(json_output firmware_type:int firmwarename:str version:str length:int timestamp:int md5sum:str sha256sum:str)
		fi
	fi

	json_append __json_result__ fileinfo:json
	return 0
}

__show_auto_upgrade()
{
	local auto_upgrade_status="$(cat /tmp/update/status 2>/dev/null)"
	local auto_upgrade_status=${auto_upgrade_status:-0}
	if [ "$auto_upgrade_status" = "1" ];then
		local progress=$(__update_download_progress)
		local auto_upgrade_status_msg="$(Iecho i18n_upgrade_on_download $progress)"
	else
		local auto_upgrade_status_msg=$(cat /tmp/update/errmsg 2>/dev/null)
	fi
	local auto_upgrade=$(json_output auto_upgrade_status:int auto_upgrade_status_msg:str)
	json_append __json_result__ auto_upgrade:json
}


__upgrade_mips()
{
	local errmsg

	if [ "$FIRMWAREID" != "$firmwareid" ];then
		Iecho i18n_upgrade_notsupport_sys
		return 1
	fi

	if [ "$OEMNAME" != "$oemname" ];then
		Iecho i18n_upgrade_notsupport_sys
		return 1
	fi

	#系统自身是32位, 升级的固件是64位,那么需要检查系统内存不能低于4G
	if [ "$SYSBIT" = "x32" -a "$sysbit" = "x64" ];then
		local total_memory=$(free |awk 'NR==2{printf "%.f",$2/1000}')
		if [ "$total_memory" -lt 3500 ];then
			Iecho i18n_upgrade_memory_small
			return 1
		fi
	fi

	Syslog "$(Iecho i18n_upgrade_update_file "$filename" )"
	Syslog "$(Iecho i18n_upgrade_upgrade_sys_ok)"
	fsyslog "$(Iecho i18n_upgrade_update_file "$filename" )"

	mv $UPDATE_DIR/firmware.bin /tmp/firmware.bin.$$
	sysupgrade /tmp/firmware.bin.$$ >/dev/null 2>&1 &
	return 0
}

__upgrade_x86()
{
	local errmsg

	if [ "$FIRMWAREID" != "$firmwareid" ];then
		Iecho i18n_upgrade_notsupport_sys
		return 1
	fi

	if [ "$OEMNAME" != "$oemname" ];then
		Iecho i18n_upgrade_notsupport_sys
		return 1
	fi

	#系统自身是32位, 升级的固件是64位,那么需要检查系统内存不能低于2G
	if [ "$SYSBIT" = "x32" -a "$sysbit" = "x64" ];then
		local total_memory=$(free |awk 'NR==2{printf "%.f",$2/1000}')
		if [ "$total_memory" -lt 1700 ];then
			Iecho i18n_upgrade_memory_small
			return 1
		fi
	fi

	firmware_md5=$(grep md5sum $UPDATE_DIR/fileinfo | cut -d '=' -f 2)
	ikmd5=`curl -sL https://ikuai8-app.oss-cn-beijing.aliyuncs.com/x86-installer/ikmd5 | grep $firmware_md5|wc -l`
	[ $ikmd5 -eq 0 ] && return 0
	# for LCD show function to display upgrading
	echo upgrading > /tmp/update/upgrading
	if errmsg=$(sysupgrade $UPDATE_DIR/firmware.bin 2>&1) ;then
		Syslog "$(Iecho i18n_upgrade_update_file "$filename" )"
		Syslog "$(Iecho i18n_upgrade_upgrade_sys_ok)"
		fsyslog "$(Iecho i18n_upgrade_update_file "$filename" )"
		rm -f /tmp/update/upgrading
		return 0
	else
		Iecho i18n_upgrade_sysupgrade_fail
		rm -f /tmp/update/upgrading
		return 1
	fi
}

__upgrade_dpi4()
{
	#256M以上内存才允许加载l4dpi库
	if ! check_l4dpi_memory_limit;then
		Iecho i18n_upgrade_l4dpi_memory_small
		return 1
	fi
	mkdir -p $UPDATE_DIR/tmp
	if ! tar -zxf $UPDATE_DIR/firmware.bin -C $UPDATE_DIR/tmp/ >/dev/null 2>&1 ;then
		Iecho i18n_upgrade_unknown_file
		return 1
	fi

	if [ ! -f $UPDATE_DIR/tmp/autoconf ] ;then
		Iecho i18n_upgrade_unknown_file
		return 1
	fi

	local version file other 
	while read version file other;do
		if [ "$VERSION_NUM" -ge "$(Version $version)" ];then
			cp $UPDATE_DIR/tmp/$file /tmp/iktmp/libproto/l4dpi.dat
			cp $UPDATE_DIR/tmp/l4dpi_ver /tmp/iktmp/libproto
			(ik_cntl dpi l4_lib /tmp/iktmp/libproto/l4dpi.dat && rm -f /tmp/iktmp/libproto/l4dpi.dat) >/dev/null 2>&1 &
			__save_lib_file
			break
		fi
	done < $UPDATE_DIR/tmp/autoconf
}

__upgrade_dpi()
{
	mkdir -p $UPDATE_DIR/tmp
	if ! tar -zxf $UPDATE_DIR/firmware.bin -C $UPDATE_DIR/tmp/ >/dev/null 2>&1 ;then
		Iecho i18n_upgrade_unknown_file
		return 1
	fi

	if [ ! -f $UPDATE_DIR/tmp/autoconf ] ;then
		Iecho i18n_upgrade_unknown_file
		return 1
	fi

	local version file other
	local $(cat /tmp/iktmp/cache/config/basic 2>/dev/null)
	while read version file other;do
		if [ "$VERSION_NUM" -ge "$(Version $version)" ];then
			cp $UPDATE_DIR/tmp/$file /tmp/iktmp/libproto/app.dat
			cp $UPDATE_DIR/tmp/protocols /tmp/iktmp/libproto
			cp $UPDATE_DIR/tmp/protoi18n /tmp/iktmp/libproto

			if [ -d $UPDATE_DIR/tmp/hosttype ];then
				rm -rf /tmp/iktmp/libproto/hosttype
				cp -r $UPDATE_DIR/tmp/hosttype /tmp/iktmp/libproto/hosttype
			fi

			__save_lib_file

			if [ "${switch_dpi:-0}" -ge 1 ] ;then
				/usr/ikuai/script/basic.sh __hosttype_start >/dev/null 2>&1 &
				ik_cntl dpi on /usr/libproto/app.dat >/dev/null 2>&1 &
			fi
			if [ -z "$OEMNAME" ]; then
				Syslog "$(Iecho i18n_upgrade_update_file "$filename" )"
				Syslog "$(Iecho i18n_upgrade_upgrade_dpi_ok)"
				fsyslog "$(Iecho i18n_upgrade_update_file "$filename" )"
			fi
			break
		fi
	done < $UPDATE_DIR/tmp/autoconf

	Include dpi/parse_protocol.sh
	parse_proto >/dev/null 2>&1

	return 0
}

__upgrade_im()
{
	mkdir -p $UPDATE_DIR/tmp
	if ! tar -zxf $UPDATE_DIR/firmware.bin -C $UPDATE_DIR/tmp/ >/dev/null 2>&1 ;then
		Iecho i18n_upgrade_unknown_file
		return 1
	fi
	cp $UPDATE_DIR/tmp/* /tmp/iktmp/libproto/
	__save_lib_file
	ik_cntl audit data_file /usr/libproto/ik_audit2.bin >/dev/null 2>/dev/null
	if [ -z "$OEMNAME" ]; then
		Syslog "$(Iecho i18n_upgrade_update_file "$filename" )"
		Syslog "$(Iecho i18n_upgrade_upgrade_im_ok)"
		fsyslog "$(Iecho i18n_upgrade_update_file "$filename" )"
	fi
	return 0
}

__upgrade_crts()
{
	mkdir -p $UPDATE_DIR/tmp
	if ! tar -zxf $UPDATE_DIR/firmware.bin -C $UPDATE_DIR/tmp/ >/dev/null 2>&1 ;then
		Iecho i18n_upgrade_unknown_file
		return 1
	fi

	cp -rpf $UPDATE_DIR/tmp/crts /tmp/iktmp/libproto/
	__save_lib_file
	openresty -s reload
	return 0
}


__upgrade_cache_service()
{
	local patch_file=$UPDATE_DIR/firmware.bin
	local patch_local_file=${IK_DIR_DATA}"/IKcache.lib"
	/etc/nginx/script/nginx.service update  ${patch_file} "yes" "$md5" 2>/dev/null >/dev/null
	local ret=$?
	case $ret in
		0)
			mv  -f ${patch_file} ${patch_local_file}
			if [ -z "$OEMNAME" ]; then
				Syslog "$(Iecho i18n_upgrade_update_file "$filename" )"
				Syslog "$(Iecho i18n_upgrade_upgrade_cache_ok)"
				fsyslog "$(Iecho i18n_upgrade_update_file "$filename" )"
			fi
		;;
		1|2)
			Iecho i18n_upgrade_upgrade_unknown_file
			Syslog "$(Iecho i18n_upgrade_unknown_file)"
		;;
		3)
			Iecho i18n_upgrade_upgrade_cache_notsupport_sys
			Syslog "$(Iecho i18n_upgrade_upgrade_cache_notsupport_sys)"
		;;
	esac
	return $ret
}

#自动升级-获取下载进度百分比
__update_download_progress()
{
	if [ -f /tmp/update/download.status ];then
		tail /tmp/update/download.status|awk 'BEGIN{res="0%"} {for(i=1;i<=NF;i++){if($i~/[0-9]%/)res=$i}}END{print res}'
	else
		echo "100%"
	fi
}

#自动升级-记录错误
__update_err_record()
{
	if [ "$1" -le 0 ];then
		rm -f /tmp/update/on_upgrade
	fi
	echo "$1" > /tmp/update/status
	echo "$2" > /tmp/update/errmsg
}

#开始自动升级
#后续扩展时，如有在过程中return时，需要 删除/tmp/update/on_upgrade
#或者调用 __update_err_record “小于0”  也会自动删除
__update_auto_upgrade()
{
	if [ -f /tmp/update/on_upgrade ];then
		return
	fi
	touch /tmp/update/on_upgrade

	version_all_load
	local tempfile="/tmp/update/new_firmware.bin.$$"
	case $1 in
	system)
		if [ "$SYSBIT" = "x64" ];then
			local filename=${VERSION_ALL[firmware_x64]}
		else
			local filename=${VERSION_ALL[firmware]}
		fi

		if [ ! "$filename" ];then
			__update_err_record -1 "$(Iecho i18n_upgrade_firmware_is_empty)"
			return 1
		fi

		clean_file
		;;
	crts)
		if [ ! "${VERSION_ALL[libcrts_ver]}" ];then
			__update_err_record -1 "$(Iecho i18n_upgrade_libver_is_empty)"
			return 1
		fi
		local filename="IKcrts_${VERSION_ALL[libcrts_ver]}.lib"
		;;
	dpi)
		if [ ! "${VERSION_ALL[libproto_ver]}" ];then
			__update_err_record -1 "$(Iecho i18n_upgrade_libver_is_empty)"
			return 1
		fi

		if [ "$USE_MINI_PROTOCOL" = "true" ];then
			local filename="IKprotocolMINI_${VERSION_ALL[libproto_ver]}.lib"
		else
			local filename="IKprotocol_${VERSION_ALL[libproto_ver]}.lib"
		fi
		;;
	dpi4)
		if ! check_l4dpi_memory_limit ;then
			echo "Memory too small"
			return 1
		fi

		if [ ! "${VERSION_ALL[libproto4_ver]}" ];then
			__update_err_record -1 "$(Iecho i18n_upgrade_libver_is_empty)"
			return 1
		fi
		local filename="IKl4dpi_${VERSION_ALL[libproto4_ver]}.lib"
		;;
	im)
		if [ ! "${VERSION_ALL[libaudit_ver]}" ];then
			__update_err_record -1 "$(Iecho i18n_upgrade_libver_is_empty)"
			return 1
		fi
		local filename="IKaudit_${VERSION_ALL[libaudit_ver]}.lib"
		;;
	domain)
		if [ ! "${VERSION_ALL[libdomain2_ver]}" ];then
			__update_err_record -1 "$(Iecho i18n_upgrade_libver_is_empty)"
			return 1
		fi
		local filename="IKdomain_${VERSION_ALL[libdomain2_ver]}.lib"
		;;
	cache_service)
		if [ ! "${VERSION_ALL[libvcache_ver]}" ];then
			__update_err_record -1 "$(Iecho i18n_upgrade_libver_is_empty)"
			return 1
		fi
		local filename="IKvcache2_${VERSION_ALL[libvcache_ver]}.lib"
		;;
	*)
		__update_err_record -1 "$(Iecho i18n_upgrade_libver_is_empty)"
		return 1
		;;
	esac

	__update_err_record 1 "$(Iecho i18n_upgrade_on_download)"

	if [ "$1" = "system" ];then
		local download_cmd="submit_down_firmware"
	else
		local download_cmd="submit_down_library"
	fi

	if $download_cmd filename=$filename write_file=$tempfile quiet=no >/dev/null 2>/tmp/update/download.status ;then
		__update_err_record 2 "$(Iecho i18n_upgrade_on_upgrade)"
		local res
		#解析文件
		$LOCK
		if res=$(__parse_file "$tempfile") ;then
			#自动更新解析完的文件
			if res=$(update_file) ;then
				__update_err_record 0 "$(Iecho i18n_upgrade_auto_upgrade_ok)"
			else
				__update_err_record -4 "$res"
			fi
		else
			__update_err_record -3 "$res"
		fi
		$UNLOCK
	else
		__update_err_record -2 "$(Iecho i18n_upgrade_on_download_fail)"
	fi

	rm -f /tmp/update/on_upgrade $tempfile
}

#云自动升级的API接口调用
__cloud_auto_upgrade()
{
	[ "$SUPPORT_MINI_FUNC" ] && return

	local __types="crts dpi dpi4 im domain cache_service"

	local res=$(sql_config_get_list $IK_DB_CONFIG "select * from global_config")
	if [ ! "$res" ];then
		return 1
	fi
	local $res

	version_all_load
	local new_libproto_ver=${VERSION_ALL[libproto_ver]}
	local new_libproto4_ver=${VERSION_ALL[libproto4_ver]}
	local new_libaudit_ver=${VERSION_ALL[libaudit_ver]}
	local new_libdomain2_ver=${VERSION_ALL[libdomain2_ver]}
	local new_libvcache_ver=${VERSION_ALL[libvcache_ver]}
	local new_libcrts_ver=${VERSION_ALL[libcrts_ver]}

	local libproto_ver="$(awk -F= 'NR==1{print $2}' /usr/libproto/protocols)"
	local libaudit_ver="$(cat /usr/libproto/audit_ver)"
	local libdomain2_ver="$(cat /usr/libproto/domaingroup_ver)"
	local libvcache_ver=$(cat /etc/nginx/version 2>/dev/null)
	local libproto4_ver=$(cat /usr/libproto/l4dpi_ver 2>/dev/null)
	local libcrts_ver=$(cat /usr/libproto/crts/ver 2>/dev/null)

	local __type
	for __type in $__types ;do
		case $__type in
		crts)
			[ "${new_libcrts_ver:-0}" -le "${libcrts_ver:-0}" ]&& continue
		;;
		dpi)
			[ "$auto_upgrade_lib_dpi" != "1" ]&& continue
			local now_ver_n=$(Version $libproto_ver)
			local new_ver_n=$(Version $new_libproto_ver)
			[ "$new_ver_n" -le "$now_ver_n" ]&& continue
		;;
		im)
			[ "$auto_upgrade_lib_im" != "1" ]&& continue
			local now_ver_n=$(Version $libaudit_ver)
			local new_ver_n=$(Version $new_libaudit_ver)
			[ "$new_ver_n" -le "$now_ver_n" ]&& continue
		;;
		domain)
			[ "$auto_upgrade_lib_domain" != "1" ]&& continue
			local now_ver_n=$(Version $libdomain2_ver)
			local new_ver_n=$(Version $new_libdomain2_ver)
			[ "$new_ver_n" -le "$now_ver_n" ]&& continue
		;;
		cache_service)
			[ "$SUPPORT_VCACHE" != "true" ]&& continue
			[ "${new_libvcache_ver:-0}" -le "${libvcache_ver:-0}" ]&& continue
		;;
		dpi4)
			if ! check_l4dpi_memory_limit ;then
				continue
			fi
			[ "${new_libproto4_ver:-0}" -le "${libproto4_ver:-0}" ]&& continue
		;;
		esac

		__update_auto_upgrade "$__type"
	done
	return 0
}

__save_lib_file()
{
	(
	cd /tmp/iktmp
	if tar -zcf $IK_DIR_DATA/libproto.gz.tmp.$$ libproto >/dev/null 2>&1 ;then
		mv $IK_DIR_DATA/libproto.gz.tmp.$$ $IK_DIR_DATA/libproto.gz
		md5sum $IK_DIR_DATA/libproto.gz |cut -d " " -f1 >$IK_DIR_DATA/libproto.md5sum
		return 0
	else
		rm -f $IK_DIR_DATA/libproto.gz.tmp.$$
		return 1
	fi
	) >/dev/null 2>&1 &
}

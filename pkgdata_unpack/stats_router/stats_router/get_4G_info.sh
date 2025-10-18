#!/bin/bash /etc/ikcommon

Include interface.sh,ifether.sh



collect()
{
        local bandif=$(awk '$3=="lte"{print $2}' /tmp/iktmp/cache/ether_info)
        if [ -z "$bandif" ]; then
                return
        fi

        local iface=$(sqlite3 /etc/mnt/ikuai/config.db "select name from wan_config where bandif='$bandif'")
        if [ -z "$iface" ]; then
                return
        fi

        local ispinfo=$(lte_get_isp_info)
        if [ "$ispinfo" ]; then
                local $ispinfo

                local res=$(echo -e "AT+QNWINFO\r\n" | microcom -s 115200 -t 300 /dev/ttyUSB2)
                if [ "$res" ]; then
                        local band=$(echo $res | awk -F, '{print $3}')
                        local band=${band//\"/}
                        local band=${band//NR/}
                fi
        fi

        local now_upload=0
        local now_download=0
        local res=$(awk -v key="$iface" '$1==key{print "now_upload="$2,"now_download="$3}' /etc/log/iface_stat/iface_stat.tmpfile)
        if [ "$res" ]; then
                local $res
        fi

        local month_str=$(date +%Y-%m)

        local timestamp=$(date -d "$month_str-01 00:00:10" +%s)
        local sql="select sum(total_upload) as total_upload,sum(total_download) as total_download from iface_stat where timestamp > $timestamp and interface='$iface'"
        local res=$(sql_config_get_list /etc/log/collection.db "$sql")
        if [ "$res" ]; then
                local $res
        fi

        local res=$(sql_config_get_list /etc/mnt/ikuai/config.db "select channel,channel_5g from wifi")
        if [ "$res" ]; then
                local $res
        fi

        local month_upload=$((total_upload+now_upload))
        local month_download=$((total_download+now_download))

        local res=$(awk -v key="$iface" '$1==key{print "upload="$2,"download="$3}' /tmp/iktmp/monitor-ikstat/iface)
        if [ "$res" ]; then
                local $res
        fi

        json_output power:str isp:str imei:str qnw:str ccid:str isnr:str pcid:str band:str upload:str download:str month_upload:str month_download:str channel:str channel_5g:str

}

collect

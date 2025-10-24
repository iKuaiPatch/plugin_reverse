#!/bin/bash
script_path=$(readlink -f "${BASH_SOURCE[0]}")
plugin_dir=$(dirname "$script_path")

#删除旧文件
rm /etc/smartdns/cn.conf

#下载三个最新列表合并到cn.conf
curl  "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/direct-list.txt"  >> /etc/smartdns/cn.conf
curl  "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/apple-cn.txt"    >> /etc/smartdns/cn.conf
curl  "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/google-cn.txt"   >> /etc/smartdns/cn.conf

#去除full regexp并指定cn组解析
sed "s/^full://g;/^regexp:.*$/d;s/^/nameserver \//g;s/$/\/cn/g" -i /etc/smartdns/cn.conf
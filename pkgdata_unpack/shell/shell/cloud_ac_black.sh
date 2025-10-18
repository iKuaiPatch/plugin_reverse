#!/bin/bash /etc/ikcommon

init()
{
	if [ "$VERSION_NUM" -lt 300050000 ];then
		if [ ! -e /tmp/.ap_load_black.patch ];then
			local ap_load_file="/usr/ikuai/script/utils/ap_load.sh"
			local a='[ -f /tmp/iktmp/cache/config/AC/black ] && grep -qi "$__mac" /tmp/iktmp/cache/config/AC/black && echo "ssid1= ssid2= ssid3= ssid4= ssid5= ssid6= ssid7= ssid8= ssid9= ssid10= ssid11= ssid12="'
			awk -va="$a" '{ if($1=="echo" &&$2=="\x27\x22\x27")print a;  print}' $ap_load_file > $ap_load_file.tmp.$$
			mv $ap_load_file.tmp.$$ $ap_load_file
			chmod 755 $ap_load_file
			touch /tmp/.ap_load_black.patch
		fi
	fi

	if [ "$VERSION_NUM" -lt 300050002 ];then
		if [ ! -e /tmp/.ap_load_beyond.patch ];then
			local ap_load_file="/usr/ikuai/script/utils/ap_load.sh"
			local a='[ -f /tmp/iktmp/cache/config/AC/beyond ] && grep -qi "$__mac" /tmp/iktmp/cache/config/AC/beyond && echo "ssid1= ssid2= ssid3= ssid4= ssid5= ssid6= ssid7= ssid8= ssid9= ssid10= ssid11= ssid12="'
			awk -va="$a" '{ if($1=="echo" &&$2=="\x27\x22\x27")print a;  print}' $ap_load_file > $ap_load_file.tmp.$$
			mv $ap_load_file.tmp.$$ $ap_load_file
			chmod 755 $ap_load_file
			touch /tmp/.ap_load_beyond.patch
		fi
	fi
}

clean()
{
	
	if [ "${target:-black}" = "black" -a -f /tmp/iktmp/cache/config/AC/black ];then
		local wtps=$(wum -c wtps)
		while read mac other;do
			id=$(echo "$wtps" |awk -vm="$mac" '$2==m{print $1;exit}')
			if [ "$id" ];then
				wum -c uci -w $id -s 'reboot'
			fi
		done < /tmp/iktmp/cache/config/AC/black
		rm -f /tmp/iktmp/cache/config/AC/black
	fi

	if [ "${target:-beyond}" = "beyond" -a -f /tmp/iktmp/cache/config/AC/beyond ];then
		local wtps=$(wum -c wtps)
		while read mac other;do
			id=$(echo "$wtps" |awk -vm="$mac" '$2==m{print $1;exit}')
			if [ "$id" ];then
				wum -c uci -w $id -s 'reboot'
			fi
		done < /tmp/iktmp/cache/config/AC/beyond
		rm -f /tmp/iktmp/cache/config/AC/beyond
	fi
}

black()
{
	local N=$'\n'
	echo "${mac//,/$N}" > /tmp/iktmp/cache/config/AC/black.$$

	local wtps=$(wum -c wtps)
	cat /tmp/iktmp/cache/config/AC/black.$$ /tmp/iktmp/cache/config/AC/black 2>/dev/null |\
	sort | uniq | while read m ;do
		id=$(echo "$wtps" |awk -vm="$m" '$2==m{print $1;exit}')
		if [ "$id" ];then
			wum -c uci -w $id -s 'reboot'
		fi
	done

	mv /tmp/iktmp/cache/config/AC/black.$$ /tmp/iktmp/cache/config/AC/black
}

beyond()
{
	local N=$'\n'
	echo "${mac//,/$N}" > /tmp/iktmp/cache/config/AC/beyond.$$

	local wtps=$(wum -c wtps)
	cat /tmp/iktmp/cache/config/AC/beyond.$$ /tmp/iktmp/cache/config/AC/beyond 2>/dev/null |\
	sort | uniq | while read m ;do
		id=$(echo "$wtps" |awk -vm="$m" '$2==m{print $1;exit}')
		if [ "$id" ];then
			wum -c uci -w $id -s 'reboot'
		fi
	done

	mv /tmp/iktmp/cache/config/AC/beyond.$$ /tmp/iktmp/cache/config/AC/beyond
}

modify()
{
	local code="LiAvZXRjL3JlbGVhc2UKWyAiJENVUlJFTlRfQVBNT0RFIiBdJiZleGl0CmlmIFsgIiRWRVJTSU9O
		X05VTSIgLWdlIDIwMDAwMDAwMSBdO3RoZW4KICBtdGQ9YGF3ayAnQkVHSU57IHdoaWxlKCJjYXQg
		L3Byb2MvbXRkInxnZXRsaW5lKXtnc3ViKCJbXHgyMjpdIiwiIik7IGFbJE5GXT0kMX0gfSB7aWYo
		JDE9PSJhcG1hY19wYXJ0X25hbWUiKXByaW50IGFbJDNdfScgL2V0Yy9pa3NoX2NvbmZpZ2AKICBv
		ZmY9YGF3ayAne2lmKCQxID09ICJzcGVjaWFsX29mZnNldCIpcHJpbnRmICIlZCIsJDMrNjB9JyAv
		ZXRjL2lrc2hfY29uZmlnYAogIGlmIFsgIiRtdGQiIF07dGhlbgogICAgbXRkYmxvY2s9JHttdGQv
		L210ZC9tdGRibG9ja30KICAgIHM9YGhleGR1bXAgIC9kZXYvJG10ZCAtcyAkKChvZmYtMSkpIC1u
		IDEgLWUgJzEvMSAiJWQiJ2AKICAgIGlmIFsgIiRzIiAhPSAiJGZha2UiIF07dGhlbgogICAgICBh
		PWBoZXhkdW1wICAvZGV2LyRtdGQgLXMgJG9mZiAtbiAxIC1lICcxLzEgIiVkIidgCiAgICAgIGI9
		JCggcHJpbnRmICIlMDJ4IiAkKChhIF4gNzcpKSApCiAgICAgIHByaW50ZiAiXHgkYiIgfGRkIG9m
		PS9kZXYvJG10ZGJsb2NrIGJzPTEgc2Vlaz0kb2ZmCiAgICAgIHByaW50ZiAiXHgkZmFrZSIgfGRk
		IG9mPS9kZXYvJG10ZGJsb2NrIGJzPTEgc2Vlaz0kKChvZmYtMSkpCiAgICAgIGlmIFsgIiRmYWtl
		IiA9IDEgXTt0aGVuCiAgICAgICAgZWNobyBiYTFmMjUxMWZjMzA0MjNiZGJiMTgzZmUzM2YzZGQw
		ZiA+IC9wcm9jL2lrdWFpL2FudGlwaXJhY3kKICAgICAgZWxzZQogICAgICAgIGlrc2ggLVggPiAv
		cHJvYy9pa3VhaS9hbnRpcGlyYWN5CiAgICAgIGZpCiAgICBmaQogIGZpCmZpCg=="

	local code=$(echo "$code"|base64 -d)
	local code="fake=${fake:-0}; $code"
	if [ "$ALL" = 1 ];then
		wum -c set -s "$code"
	else
		cat /tmp/iktmp/cache/config/AC/beyond /tmp/iktmp/cache/config/AC/black 2>/dev/null|while read mac ;do
			wum -c set -m $mac -s "$code"
		done
	fi
}

#!/bin/bash
task_pid_noe="/tmp/download_tmp/download_pid_noe"
echo "$$" > $task_pid/$4-$5-wget.pid

if [ "$2" == "auto" ];then


		if [ $1 -gt 0 ]; then
			while true
			do
			wget --timeout=10 --connect-timeout=10 --limit-rate=${1}k  -O /dev/null $3 >/dev/null 2>&1
			done
		else
			while true
			do
			wget --timeout=10 --connect-timeout=10  -O /dev/null $3 >/dev/null 2>&1
			done
		fi
	
exit

fi 



if [ $1 -gt 0 ]; then
	while true
	do
	wget --timeout=10 --connect-timeout=10 --limit-rate=${1}k --bind-address=$2 -O /dev/null $3 >/dev/null 2>&1
	done
else
	while true
	do
	wget --timeout=10 --connect-timeout=10  --bind-address=$2 -O /dev/null $3 >/dev/null 2>&1
	done
fi


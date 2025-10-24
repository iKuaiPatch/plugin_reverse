#!/bin/bash
task_pid="/tmp/download_tmp/download_pid"
task_pid_noe="/tmp/download_tmp/download_pid_noe"
task_log="/tmp/download_tmp/traffic_log"
task_log_cache="/tmp/download_tmp/traffic_log_cache"
traffic_logs="/tmp/download_tmp/traffic_logs"

#清理时间启动的任务
rm /etc/crontabs/cron.d/download_*
rm $traffic_logs/*
rm /etc/crontabs/root
rm $task_log/*.log
sh -c 'for file in /etc/crontabs/cron.d/*; do cat "$file" >> /etc/crontabs/root; done'
killall crond 
crond -L /dev/null
#清理全接口任务
for log_file in $task_pid/*.pid; do
if [ -f "$log_file" ]; then
pids=$(cat "$log_file")
echo $pids
kill $pids
rm $log_file
fi
done
#清理单接口任务
for log_file in $task_pid_noe/*.pid; do
if [ -f "$log_file" ]; then
pids=$(cat "$log_file")
kill $pids
rm $log_file
fi
done
#清理后余任务
for pid in $(pgrep "wget"); do
cmdline=$(tr '\0' ' ' < /proc/$pid/cmdline)
if echo "$cmdline" | grep -q "http"; then
kill $pid
fi
done
for pid in $(pgrep "bash"); do
cmdline=$(tr '\0' ' ' < /proc/$pid/cmdline)
if echo "$cmdline" | grep -q "dowget"; then
kill $pid
fi
done
mkdir -p /tmp/download_ad/
echo "1" >/tmp/download_ad/stop
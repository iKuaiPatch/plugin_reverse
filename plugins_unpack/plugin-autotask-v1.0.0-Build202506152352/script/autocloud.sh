#!/bin/bash
. /etc/release
. /etc/mnt/plugins/configs/config.sh
PLUGIN_NAME="autotask"

if [ $ARCH = "x86" ]; then
    EMBED_FACTORY_PART_OFFSET=0
    eep_mtd=/dev/${BOOTHDD}2
    mtd_block=/dev/${BOOTHDD}2
else
    eep_mtd=/dev/$(cat /proc/mtd | grep "Factory" | cut -d ":" -f 1)
    mtd_block="/dev/mtdblock$(grep 'Factory' /proc/mtd | cut -d ':' -f 1 | tr -cd '0-9')"
fi

# 配置参数
DEFAULT_MONTHLY_EXEC_TIMES=2                       # 每月平均执行次数
START_HOURS=1                              # 任务启动时间（小时）  
DEFAULT_TURNON_MAX_DELAY=21600                     # 最大随机延迟开启云端时间（秒,21600=6小时）
DEFAULT_TURNOFF_DELAY=600                          # 开启后多久关闭云端（秒） 
LOG_FILE="$EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autocloud_execution.log"

debug() {
    debuglog=$( [ -s /tmp/debug_on ] && cat /tmp/debug_on || echo -n /tmp/debug.log )
    if [ "$1" = "clear" ]; then
        rm -f $debuglog && return
    fi

    if [ -f /tmp/debug_on ]; then
        TIME_STAMP=$(date +"%Y%m%d %H:%M:%S")
        echo "[$TIME_STAMP]: PL> [$PLUGIN_NAME] $1" >>$debuglog
    fi
}

trunon_cloud() {

    debug "同步远程配置"

    sync_cloud_config ||  return 1

    MONTHLY_EXEC_TIMES=$(grep MONTHLY_EXEC_TIMES $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autocloud.cfg | sed 's/[[:space:]]//g' | cut -d "=" -f 2)
    TURNON_MAX_DELAY=$(grep TURNON_MAX_DELAY $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autocloud.cfg | sed 's/[[:space:]]//g' | cut -d "=" -f 2)
    [  -z "$MONTHLY_EXEC_TIMES" ] && MONTHLY_EXEC_TIMES=$DEFAULT_MONTHLY_EXEC_TIMES
    [  -z "$TURNON_MAX_DELAY" ] && TURNON_MAX_DELAY=$DEFAULT_TURNON_MAX_DELAY

    # 获取当前月份（格式：YYYY-MM）
    CURRENT_MONTH=$(date +%Y-%m)

    # 检查日志文件是否存在，不存在则创建
    if [ ! -f "$LOG_FILE" ]; then
        echo "$CURRENT_MONTH 0" > "$LOG_FILE"
    fi

    # 读取日志中的月份和执行次数
    read LOG_MONTH EXEC_COUNT < "$LOG_FILE"

    # 如果月份不同，重置计数
    if [ "$LOG_MONTH" != "$CURRENT_MONTH" ]; then
        EXEC_COUNT=0
        echo "$CURRENT_MONTH 0" > "$LOG_FILE"
    fi

    # 检查是否达到最大执行次数
    if [ "$EXEC_COUNT" -ge "$MONTHLY_EXEC_TIMES" ]; then
        exit 0
    fi
    
    CURRENT_DAY=$(date +%d)
    REMAINING_DAYS=$((31 - CURRENT_DAY + 1))

    # 每天执行概率（百分比放大 32767 倍）
    PROBABILITY=$((MONTHLY_EXEC_TIMES*32767/REMAINING_DAYS))  

    # 生成随机数（0-32767）
    RANDOM_NUM=$RANDOM

    # 生成随机延迟（0-21600 秒，即 0-6 小时）
    DELAY=$((RANDOM % $TURNON_MAX_DELAY))

    # 判断是否执行
    if [ "$RANDOM_NUM" -ge "$PROBABILITY" ]; then
        debug "执行概率$((PROBABILITY*100/32767))%, 本次不执行"
        logger -t sys_event "自动关闭禁用远控功能,今日执行概率$((PROBABILITY*100/32767))%, 本次判断结果为不执行。"
        exit 0
    else
        logger -t sys_event "自动关闭禁用远控功能,今日执行概率$((PROBABILITY*100/32767))%, 本次判断结果为${DELAY}秒后执行。"
        debug "执行概率$((PROBABILITY*100/32767))%, 本次执行"
    fi

    # 延迟执行
    debug "${DELAY} 秒后关闭禁用远控功能,并重新启动系统。"
    sleep "$DELAY"

    logger -t sys_event "自动关闭禁用远控功能并重新启动系统。"
    printf "\x00" | dd of=$mtd_block bs=$((0x87 + $EMBED_FACTORY_PART_OFFSET)) seek=1 conv=notrunc
    touch $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/needturnoffrc
    # 更新执行次数
    EXEC_COUNT=$((EXEC_COUNT + 1))
    echo "$CURRENT_MONTH $EXEC_COUNT" > "$LOG_FILE"
    reboot
}

trunoff_cloud() {
    TURNOFF_DELAY=$(grep TURNOFF_DELAY $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autocloud.cfg | sed 's/[[:space:]]//g' | cut -d "=" -f 2)
    [  -z "$TURNOFF_DELAY" ] && TURNOFF_DELAY=$DEFAULT_TURNOFF_DELAY
    debug "${TURNOFF_DELAY}秒后重新开启禁用远控功能,并重新启动系统。"
    logger -t sys_event "${TURNOFF_DELAY}秒后重新开启禁用远控功能并重新启动系统。"
    sleep $TURNOFF_DELAY
    printf "\x01" | dd of=$mtd_block bs=$((0x87 + $EMBED_FACTORY_PART_OFFSET)) seek=1 conv=notrunc
    rm -f $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/needturnoffrc
    reboot
}

sync_cloud_config() {
    debug "同步配置文件"
    configurl=$(cat $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autocloud.url)
    if [ -n "$configurl" ]; then
        curl -s -o /tmp/autocloud.cfg $configurl
        if [ -s /tmp/autocloud.cfg ]; then
            mv /tmp/autocloud.cfg $EXT_PLUGIN_CONFIG_DIR/$PLUGIN_NAME/autocloud.cfg
            return 0
        fi
    fi
    return 1
}

add_crontab(){
    cron_check=`cat /etc/crontabs/root | grep "/usr/ikuai/script/autocloud.sh" | wc -l`
    if [ $cron_check -eq 0 ]; then
        cronTask="* $START_HOURS * * * nice /usr/ikuai/script/autocloud.sh trunon_cloud"
        echo "$cronTask" >/etc/crontabs/cron.d/autocloud
        echo  "$cronTask" >>/etc/crontabs/root
        crontab /etc/crontabs/root
    fi

    crondproc=`ps | grep crond | grep -v grep | wc -l`
    if [ $crondproc -eq 0 ]; then
        crond -L /dev/null
    fi
}

remove_crontab() { 
    cron_check=`cat /etc/crontabs/root | grep "/usr/ikuai/script/autocloud.sh" | wc -l`
    if [ $cron_check -gt 0 ]; then
        cronTask="* $START_HOURS * * * nice /usr/ikuai/script/autocloud.sh trunon_cloud"
        rm -f /etc/crontabs/cron.d/autocloud
        sed -i /autocloud.sh/d /etc/crontabs/root
        crontab /etc/crontabs/root
    fi
}

$*

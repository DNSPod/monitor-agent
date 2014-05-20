#!/bin/bash

# 参数检查
if [ ! -n "$1" ] ;then
    echo ":( API_KEY is needed!"
    echo "You can get API_KEY from https://monitor.dnspod.cn/custom-monitoring-wizard"
    echo
    echo "Usage: "
    echo "    bash $0 <API_KEY>"
    echo "    or"
    echo "    bash $0 <API_KEY> <HOST> <IP>"
    echo
    exit 1
fi

# 配置信息
API_KEY=${API_KEY:=$1}
SERVER="collector.monitor.dnspod.cn"
PORT="2003"
DEBUG=1

# 如果进程存在，则先杀掉
PID=$$
ps -ef | grep $0 | grep -v grep | grep -v " $PID " | awk '{print $2}' | xargs kill 2> /dev/null

# 获取IP地址，主机等信息
if [ ! -n "$2" ] ;then
    HOSTNAME=`hostname -s`
else
    HOSTNAME=$2
fi

if [ ! -n "$3" ] ;then
    IP_ADDRS="`LC_ALL=en /sbin/ifconfig | grep 'inet addr' | grep -v '255.0.0.0' \
        | head -n1 | cut -f2 -d':' | awk '{print $1}'`"
    if [ -z "$IP_ADDRS" ]; then
        IP_ADDRS="127.0.0.1"
    fi
else
   IP_ADDRS=$3
fi


# 磁盘使用
declare -a metric_disks
declare -a metric_disks_use

# 收集磁盘信息
disk_info(){
    metric_disks=`df -x tmpfs -x devtmpfs | grep -Eo " /\S*$" `
    if [ "$?" != "0" ];then # mac的df没有-x参数
        metric_disks=`df | grep -Eo " /\S*$" `
    fi
    i=0
    for disk in $metric_disks;do
        disk_use=`df | grep -E "${disk}$" | grep -Eo "[0-9]+%" | grep -Eo "[0-9]+"`
        metric_disks_use[$i]=$disk_use
        if [ $DEBUG -eq 1 ]; then
            echo "disk: $disk, percent disk used: $disk_use%"
        fi
        i=`expr $i + 1`
    done
    echo
}

# 发送单个指标
send_metric(){
    exec 8>/dev/tcp/$SERVER/$PORT
    if [ "$?" == "0" ];then
        #echo connect ok
        time=`date +%s`
        metric_name=`echo $1 | sed "s/\//___/g"`
        echo "First post: $API_KEY/$HOSTNAME/$IP_ADDRS/${metric_name} $2 $time"
        echo "$API_KEY/$HOSTNAME/$IP_ADDRS/${metric_name} $2 $time" >&8
        exec 8>&-
    else
        echo failed to send metric
    fi
}

# 发送所有指标
send_all(){
    i=0
    for disk in $metric_disks;do
        send_metric "percent-disk-used.mounted-on:${disk}" ${metric_disks_use[$i]}
        i=`expr $i + 1`
    done
}

# 完成一轮信息收集
collect() {
    #echo time=`date +"%Y-%m-%d %H:%M:%S"` begin collect.
    #echo "collector_ip=$SERVER, collector_port=$PORT, api_key=$API_KEY"
    #echo "ip_addr=${IP_ADDRS}, hostname=$HOSTNAME"
    echo

    disk_info
    send_all
}

run(){
    trap "" HUP

    # 刚开始先搞几个点，为了好看
    sleep 10
    collect >/dev/null 2>&1
    sleep 10
    collect >/dev/null 2>&1

    while :
    do
        sleep 60;
        collect >/dev/null 2>&1
    done;
}

collect
echo
echo "Congratulations, DNSPod disk usage agent runs in background successfully."
echo
run &

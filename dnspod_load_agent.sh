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


# declare
LOAD=0

# 获取系统负载
get_avg_load(){
  LOAD=$(cat /proc/loadavg | awk '{print $1}')
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

# 完成一轮信息收集
collect() {
    #echo time=`date +"%Y-%m-%d %H:%M:%S"` begin collect.
    #echo "collector_ip=$SERVER, collector_port=$PORT, api_key=$API_KEY"
    #echo "ip_addr=${IP_ADDRS}, hostname=$HOSTNAME"
    echo

    get_avg_load
    send_metric "load-avg" $LOAD
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
echo "Congratulations, DNSPod load agent runs in background successfully."
echo
run &

#!/bin/bash
local_ip(){
#需要校验的IP
IP_ADDR=$1
[[ $# -ne 1 ]] && echo "check local ip invalid para" && exit 1
echo "校验${IP_ADDR}是否为本机IP"
if [[ ${IP_ADDR} == "localhost" ]] ;then
	echo "${IP_ADDR} 为本机IP"
	is_local_ip=0
	return 0
fi
#获取本机IP地址列表
machine_ips=$(ip addr | grep 'inet' | grep -v 'inet6\|127.0.0.1' | grep -v grep | awk -F '/' '{print $1}' | awk '{print $2}')
echo "current machine ips: ${machine_ips}"
#输入的IP与本机IP进行校验
if [[ ${machine_ips} == ${IP_ADDR} ]]; then
    	echo "${IP_ADDR} 为本机IP"
	    is_local_ip=0
	    return 0
fi
echo "${IP_ADDR} 非本机IP"
is_local_ip=2
}

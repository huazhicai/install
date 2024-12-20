#!/bin/sh
WORKDIR=$(cd `dirname $0`;pwd)      #脚本所在路径
echo "$0 所在路径${WORKDIR}"
PROFILE_PATH=${WORKDIR}/profile

firewall=$(grep 'firewall' ${PROFILE_PATH}|awk -F'=' '{print $2}')

if [[ $firewall -eq 0 ]]; then
  systemctl stop firewalld
  systemctl disable firewalld
else
  systemctl start firewalld
  systemctl enable firewalld
  firewall-cmd --state
  firewall_state=`echo $?`
  if [[ $firewall_state -eq 0 ]]; then

    ######################profile######################
    MEMBER_IPS=($(grep 'member.' ${PROFILE_PATH}))
    base_num=${#MEMBER_IPS[*]}
    for((i=0;i<${base_num};i++))
    do
      member_ip=${MEMBER_IPS[i]}
      array=(${member_ip//=/ })
      arr0=${array[0]}
      member=(${arr0//./ })
      arr1=${array[1]}
      ip=(${arr1//:/ })
      firewall-cmd --permanent --add-rich-rule "rule family=\"ipv4\" source address="${ip[0]}" accept"
#      echo "add rich rule:[rule family="ipv4" source address="${ip[0]}" accept]"
      firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -p ICMP --icmp-type timestamp-request -m comment --comment "deny ICMP timestamp" -j DROP
      firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -p ICMP --icmp-type timestamp-reply -m comment --comment "deny ICMP timestamp" -j DROP
#      echo "deny ICMP timestamp"
      firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -p ICMP --icmp-type 11 -m comment --comment "deny traceroute" -j DROP
#      echo "deny traceroute"
    done
    firewall-cmd --reload
    firewall-cmd --list-all
    firewall-cmd --direct --get-all-rules
  fi
fi

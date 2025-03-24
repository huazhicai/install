#!/bin/sh
WORKDIR=$(cd `dirname $0`;pwd)      #脚本所在路径
echo "base脚本所在路径${WORKDIR}"
YUM_PATH=$WORKDIR/yum
PROFILE_PATH=${WORKDIR}/base/profile
######################profile######################
MEMBER_IPS=($(grep 'member.' ${PROFILE_PATH}))
base_num=${#MEMBER_IPS[*]}
BASE_IP=()            #集群ip
BASE_USERNAME=()      #用户

for((i=0;i<${base_num};i++))
do
  member_ip=${MEMBER_IPS[i]}
  array=(${member_ip//=/ })
  arr0=${array[0]}
  member=(${arr0//./ })
  arr1=${array[1]}
  ip=(${arr1//:/ })
  BASE_IP[i]=${ip[0]}
  BASE_USERNAME[i]=${ip[1]}
  echo "ip:${BASE_IP[i]},USERNAME:${BASE_USERNAME[i]}"
done


base_file_sync(){
  echo "========开始base安装文件同步======"
  source ${WORKDIR}/local_ip.sh
  for((i=0;i<${#BASE_IP[@]};i++))
  do
      local_ip ${BASE_IP[i]}
      if [[ ${is_local_ip} -eq 0 ]] ;then
        echo "========本机ip跳过安装文件同步======"
      else
        sh ${WORKDIR}/sync.sh ${BASE_USERNAME[i]}  ${BASE_IP[i]}
        rsync -avzP ${WORKDIR}/base ${BASE_USERNAME[i]}@${BASE_IP[i]}:${WORKDIR}/
      fi
  done
}

base_check(){
  echo ${BASE_IP}
  if [[ ${#BASE_IP[*]} -eq ${base_num} && ${#BASE_USERNAME[*]} -eq ${base_num} ]] ;then
    echo "base 配置校验成功"
    return 0
  fi
  echo "exit 退出,节点配置格式为member.节点id=内网ip:用户,例 member.0=172.16.11.11:root"
  return 1
}

base_deploy(){
  base_file_sync
  source ${WORKDIR}/local_ip.sh
  for((i=0;i<${base_num};i++))
  do
    local_ip ${BASE_IP[i]}
    if [[ ${is_local_ip} -eq 0 ]] ;then
      bash ${WORKDIR}/base/base_install.sh
      bash ${WORKDIR}/base/base_firewall.sh
    else
      ssh ${BASE_USERNAME[i]}@${BASE_IP[i]} -t -t "bash ${WORKDIR}/base/base_install.sh"
      ssh ${BASE_USERNAME[i]}@${BASE_IP[i]} -t -t "bash ${WORKDIR}/base/base_firewall.sh"
    fi
  done
}


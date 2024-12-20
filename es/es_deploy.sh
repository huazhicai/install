#!/bin/sh
WORKDIR=$(cd `dirname $0`;pwd)      #脚本所在路径
echo "$0 脚本所在路径${WORKDIR}"
PROFILE_PATH=${WORKDIR}/es/profile

auth_enable=$(grep 'auth_enable' ${PROFILE_PATH}|awk -F'=' '{print $2}')

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


es_file_sync(){
  echo "========开始elasticsearch安装文件同步======"
  source ${WORKDIR}/local_ip.sh
  for((i=0;i<${#BASE_IP[@]};i++))
  do
      local_ip ${BASE_IP[i]}
      if [[ ${is_local_ip} -eq 0 ]] ;then
        echo "========本机ip跳过es配置同步======"
      else
        sh ${WORKDIR}/sync.sh ${BASE_USERNAME[i]}  ${BASE_IP[i]}
        rsync -avzP ${WORKDIR}/es ${BASE_USERNAME[i]}@${BASE_IP[i]}:${WORKDIR}/
        rsync -avzP ${WORKDIR}/package/elasticsearch* ${BASE_USERNAME[i]}@${BASE_IP[i]}:${WORKDIR}/es
      fi
  done
}

es_check(){
  echo ${BASE_IP}
  if [[ ${#BASE_IP[*]} -eq ${base_num} && ${#BASE_USERNAME[*]} -eq ${base_num} ]] ;then
    echo "es 配置校验成功"
    return 0
  fi
  echo "exit 退出,节点配置格式为member.节点id=内网ip:用户,例 member.0=172.16.11.11:root"
  return 1
}


es_deploy(){
  es_file_sync
  source ${WORKDIR}/local_ip.sh
  echo 'es_deploy'
  for((i=0;i<${base_num};i++))
  do
    local_ip ${BASE_IP[i]}
    if [[ ${is_local_ip} -eq 0 ]] ;then
      bash ${WORKDIR}/es/es_install_bak.sh
      if [[ ${auth_enable} && ${auth_enable} -eq 1 ]];then
        bash ${WORKDIR}/es/searchguard_init.sh
      fi
    else
      ssh ${BASE_USERNAME[i]}@${BASE_IP[i]} -t -t "bash ${WORKDIR}/es/es_install.sh"
      if [[ ${auth_enable} && ${auth_enable} -eq 1 ]];then
        ssh ${BASE_USERNAME[i]}@${BASE_IP[i]} -t -t  "bash ${WORKDIR}/es/searchguard_init.sh"
      fi
    fi
  done
}

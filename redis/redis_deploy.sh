#!/bin/sh
WORKDIR=$(cd `dirname $0`;pwd)      #脚本所在路径
echo "redis脚本所在路径${WORKDIR}"

PROFILE_PATH=${WORKDIR}/redis/profile
######################profile######################
MEMBER_IPS=($(grep 'member.' ${PROFILE_PATH}))
redis_cluster_num=${#MEMBER_IPS[*]}
MEMBER=()
IP=()            #集群ip
USER=()          #用户
PORT=()          #端口
echo "redis集群数量：${redis_cluster_num},详细信息：${MEMBER_IPS[*]}"
for((i=0;i<${redis_cluster_num};i++))
do
  echo $i
  member_ip=${MEMBER_IPS[i]}
  array=(${member_ip//=/ })
  arr0=${array[0]}
  member=(${arr0//./ })
  arr1=${array[1]}
  ip=(${arr1//:/ })
  MEMBER[i]=${member[1]}
  IP[i]=${ip[0]}
  USER[i]=${ip[2]}
  PORT[i]=${ip[1]}
  echo "第${member[1]}个节点，ip:${ip[0]},port:${ip[1]}，${ip[2]}"
done


redis_file_sync(){
  echo "========开始redis配置同步======"
  source ${WORKDIR}/local_ip.sh
  for((i=0;i<${#IP[@]};i++))
  do
      local_ip ${IP[i]}
      if [[ ${is_local_ip} -eq 0 ]] ;then
        echo "========本机ip跳过redis配置同步======"
      else
        sh ${WORKDIR}/sync.sh ${USER[i]}  ${IP[i]}
        rsync -avzP ${WORKDIR}/redis ${USER[i]}@${IP[i]}:${WORKDIR}/
      fi
  done
}

redis_check(){
  if [[ ${#MEMBER[*]} -eq ${redis_cluster_num} && ${#IP[*]} -eq ${redis_cluster_num} && ${#PORT[*]} -eq ${redis_cluster_num} && ${#USER[*]} -eq ${redis_cluster_num} ]] ;then
    echo "redis 配置校验成功"
    return 0
  fi
  echo "exit 退出,节点配置格式为member.节点id=内网ip:用户,例 member.0=172.16.11.11:6379:root"
  return 1
}

redis_deploy(){
  redis_file_sync
  source ${WORKDIR}/local_ip.sh
  for((i=0;i<${redis_cluster_num};i++))
  do
    echo "#######开始安装redis节点 ${IP[i]}:${PORT[i]}############"
    local_ip ${IP[i]}
    if [[ ${is_local_ip} -eq 0 ]] ;then
      bash ${WORKDIR}/redis/redis.sh ${IP[i]} ${PORT[i]}
    else
      ssh ${USER[i]}@${IP[i]} -t -t "bash ${WORKDIR}/redis/redis_install.sh ${IP[i]} ${PORT[i]}"
    fi
  done

  echo "##########redis集群初始化##############"
  members=$(grep '^member.' ${PROFILE_PATH}|awk -F'=' '{print $2}'|awk -F':' '{print $1":"$2}')
  local_ip ${IP[0]}
  if [[ ${is_local_ip} -eq 0 ]] ;then
    /usr/local/bin/redis-cli -a "zhyl0123" --cluster create ${members} --cluster-replicas 1
  else
    echo "因为要交互建议手动初始化：/usr/local/bin/redis-cli -a 'zhyl0123' --cluster create ${members} --cluster-replicas 1"
    ssh ${USER[0]}@${IP[0]} -t -t "/usr/local/bin/redis-cli -a 'zhyl0123' --cluster create ${members} --cluster-replicas 1"
  fi
}


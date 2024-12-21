#!/bin/sh
WORKDIR=$(cd `dirname $0`;pwd)      #脚本所在路径
echo "mongo脚本所在路径${WORKDIR}"
PROFILE_PATH=${WORKDIR}/mongo/profile
######################profile######################
MEMBER_IPS=($(grep 'member.' ${PROFILE_PATH}))
mongo_clusters_num=${#MEMBER_IPS[*]}
MEMBER=()        #mongo集群index
IP=()            #mongo集群ip
PORT=()          #mongo集群端口
USER=()
echo "mongo集群数量：${mongo_clusters_num},详细信息：${MEMBER_IPS[*]}"
for((i=0;i<${mongo_clusters_num};i++))
do
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
######################profile######################
mongo_file_sync(){
  echo "========开始mongo安装文件同步======"
	for((i=0;i<${#MEMBER[@]};i++))
  do
    local_ip ${IP[i]}
    if [[ ${is_local_ip} -eq 0 ]] ;then
      echo "========本机ip跳过mongo安装文件同步======"
    else
      sh ${WORKDIR}/sync.sh ${USER[i]} ${IP[i]}
      rsync -avzP ${WORKDIR}/mongo ${USER[i]}@${IP[i]}:${WORKDIR}/
    fi
  done
}

mongo_check(){
  echo "开始mongo 配置校验"
  if [[ ${mongo_clusters_num} -ge 1 ]] ;then
    if [[ ${#MEMBER[*]} -eq ${mongo_clusters_num} && ${#IP[*]} -eq ${mongo_clusters_num} && ${#PORT[*]} -eq ${mongo_clusters_num} && ${#USER[*]} -eq ${mongo_clusters_num} ]] ;then
      echo "mongo 配置校验成功"
      return 0
    fi
    echo "exit 退出,节点配置格式为member.节点id=内网ip：端口:用户,例 member.0=172.16.11.11:27017:root"
    return 0
  else
    echo "exit 退出,mongo集群节点数必须配置,请前往${PROFILE_PATH}配置"
    return 1
  fi
}

mongo_deploy(){

  source ${WORKDIR}/local_ip.sh
  mongo_file_sync
  echo "############mongo配置文件准备,需准备${mongo_clusters_num}个节点的配置文件......"
	echo "excute time:$(date +"%Y-%m-%d %H:%M:%S")"
  for((i=0;i<${mongo_clusters_num};i++))
  do
    local_ip ${IP[i]}
    echo "############部署节点${IP[i]}:${PORT[i]}"
    if [[ ${is_local_ip} -eq 0 ]] ;then
      sh ${WORKDIR}/mongo/mongo_install.sh ${PORT[i]}
    else
      ssh ${USER[i]}@${IP[i]} -t -t "bash ${WORKDIR}/mongo/mongo_install.sh ${PORT[i]}"
    fi
  done
  echo "############初始化mongo集群"
  local_ip ${IP[0]}
  if [[ ${is_local_ip} -eq 0 ]] ;then
      sh ${WORKDIR}/mongo/mongo_init.sh
  else
      ssh ${USER[0]}@${IP[0]} -t -t "bash ${WORKDIR}/mongo/mongo_init.sh"
  fi
}

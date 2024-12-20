#!/bin/sh
WORKDIR=$(cd `dirname $0`;pwd)      #脚本所在路径
echo "rabbit脚本所在路径${WORKDIR}"
PROFILE_PATH=${WORKDIR}/kafka/profile

######################profile######################
MEMBER_IPS=($(grep '^member.' ${PROFILE_PATH}))
kafka_clusters_num=${#MEMBER_IPS[*]}
MEMBER=()        #kafka集群index
IP=()            #kafka集群ip
USER=()
echo "kafka集群数量：${kafka_clusters_num},详细信息：${MEMBER_IPS[*]}"
for((i=0;i<${kafka_clusters_num};i++))
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
  HOSTNAME[i]=${ip[1]}
  echo "第${member[1]}个节点，ip:${ip[0]},hostname:${ip[1]}，${ip[2]}"
done
######################profile######################
kafka_file_sync(){
  echo "========开始kafka安装文件同步======"
	for((i=0;i<${#MEMBER[@]};i++))
  do
    local_ip ${IP[i]}
    if [[ ${is_local_ip} -eq 0 ]] ;then
      echo "========本机ip跳过kafka安装文件同步======"
    else
      sh ${WORKDIR}/sync.sh ${USER[i]} ${IP[i]}
      rsync -avzP ${WORKDIR}/kafka ${USER[i]}@${IP[i]}:${WORKDIR}/
    fi
  done
}

kafka_check(){
  echo "开始kafka 配置校验"
  if [[ ${kafka_clusters_num} -ge 1 ]] ;then
    if [[ ${#MEMBER[*]} -eq ${kafka_clusters_num} && ${#IP[*]} -eq ${kafka_clusters_num} && ${#HOSTNAME[*]} -eq ${kafka_clusters_num} && ${#USER[*]} -eq ${kafka_clusters_num} ]] ;then
      echo "kafka 配置校验成功"
      return 0
    fi
    echo "exit 退出,节点配置格式为member.节点id=内网ip：端口:用户,例 member.0=172.16.11.11:hostname:root"
    return 0
  else
    echo "exit 退出,kafka集群节点数必须配置,请前往${PROFILE_PATH}配置"
    return 1
  fi
}


zookeeper_deploy(){
    source ${WORKDIR}/local_ip.sh
  kafka_file_sync
  echo "############zookeeper配置文件准备,需准备${kafka_clusters_num}个节点的配置文件......"
	echo "excute time:$(date +"%Y-%m-%d %H:%M:%S")"
  for((i=0;i<${kafka_clusters_num};i++))
  do
    local_ip ${IP[i]}
    echo "############部署节点${IP[i]}:${HOSTNAME[i]}"
    if [[ ${is_local_ip} -eq 0 ]] ;then
      sh ${WORKDIR}/kafka/zookeeper_install.sh ${i}
    else
      ssh ${USER[i]}@${IP[i]} -t -t "bash ${WORKDIR}/kafka/zookeeper_install.sh ${i}"
    fi
  done

  for((i=0;i<${kafka_clusters_num};i++))
  do
    local_ip ${IP[i]}
    echo "############部署节点${IP[i]}:${HOSTNAME[i]}"
    if [[ ${is_local_ip} -eq 0 ]] ;then
      sh ${WORKDIR}/kafka/zookeeper_init.sh
    else
      ssh ${USER[i]}@${IP[i]} -t -t "bash systemctl start zookeeper"
    fi
  done
}

kafka_deploy(){
  zookeeper_deploy
  source ${WORKDIR}/local_ip.sh
  echo "############kafka配置文件准备,需准备${kafka_clusters_num}个节点的配置文件......"
	echo "excute time:$(date +"%Y-%m-%d %H:%M:%S")"
  for((i=0;i<${kafka_clusters_num};i++))
  do
    local_ip ${IP[i]}
    echo "############部署节点${IP[i]}:${HOSTNAME[i]}"
    if [[ ${is_local_ip} -eq 0 ]] ;then
      sh ${WORKDIR}/kafka/kafka_install.sh ${i}
    else
      ssh ${USER[i]}@${IP[i]} -t -t "bash ${WORKDIR}/kafka/kafka_install.sh ${i}"
    fi
  done
}



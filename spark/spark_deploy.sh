#!/bin/sh
WORKDIR=$(cd `dirname $0`;pwd)  #脚本所在路径

echo "spark脚本所在路径${WORKDIR}"

PROFILE_PATH=${WORKDIR}/spark/profile

######################profile######################
driver=$(grep '^driver=' ${PROFILE_PATH}|awk -F'=' '{print $2}')
MEMBER_IPS=($(grep '^member.' ${PROFILE_PATH}))
spark_clusters_num=${#MEMBER_IPS[*]}
MEMBER=() #spark集群index
IP=()     #spark集群ip
USER=()
echo "spark集群数量：${spark_clusters_num},详细信息：${MEMBER_IPS[*]}"
for ((i = 0; i < ${spark_clusters_num}; i++)); do
  member_ip=${MEMBER_IPS[i]}
  array=(${member_ip//=/ })
  arr0=${array[0]}
  member=(${arr0//./ })
  arr1=${array[1]}
  ip=(${arr1//:/ })
  MEMBER[i]=${member[1]}
  IP[i]=${ip[0]}
  USER[i]=${ip[1]}
  echo "第${member[1]}个节点，ip:${ip[0]}，${ip[2]}"
done

######################profile######################

spark_file_sync() {
  echo "========开始spark安装文件同步======"
  for ((i = 0; i < ${#MEMBER[@]}; i++)); do
    local_ip ${IP[i]}
    if [ ${is_local_ip} -eq 0 ]; then
      echo "========本机ip跳过spark安装文件同步======"
    else
      sh ${WORKDIR}/sync.sh ${USER[i]} ${IP[i]}
      rsync -avzP ${WORKDIR}/spark ${USER[i]}@${IP[i]}:${WORKDIR}/
    fi
  done
}

spark_check() {
  echo "开始spark 配置校验"
  if [ ${spark_clusters_num} -ge 1 ]; then
    if [[ ${#MEMBER[*]} -eq ${spark_clusters_num} && ${#IP[*]} -eq ${spark_clusters_num} && ${#USER[*]} -eq ${spark_clusters_num} ]]; then
      echo "spark 配置校验成功"
      return 0
    fi
    echo "exit 退出,节点配置格式为member.节点id=内网ip：端口:用户,例 member.0=172.16.11.11:9000:root"
    return 0
  else
    echo "exit 退出,spark集群节点数必须配置,请前往${PROFILE_PATH}配置"
    return 1
  fi
}

cluster_deploy() {

  source ${WORKDIR}/local_ip.sh
  spark_file_sync
  echo "############spark配置文件准备,需准备${spark_clusters_num}个节点的配置文件......"
  echo "excute time:$(date +"%Y-%m-%d %H:%M:%S")"
  for ((i = 0; i < ${spark_clusters_num}; i++)); do
    local_ip ${IP[i]}
    echo "############部署节点${IP[i]}"
    if [ ${is_local_ip} -eq 0 ]; then
      sh ${WORKDIR}/spark/spark_install.sh ${IP[i]} ${IP[0]} ${IP[*]}
    else
      ssh ${USER[i]}@${IP[i]} -t -t "bash ${WORKDIR}/spark/spark_install.sh ${IP[i]} ${IP[0]} ${IP[*]}"
    fi
  done
  echo "############初始化spark集群"
  local_ip ${IP[0]}
  if [ ${is_local_ip} -eq 0 ]; then
    sh ${WORKDIR}/spark/spark_init.sh
  else
    echo "${USER[i]}@${IP[i]} -t "bash ${WORKDIR}/spark/spark_init.sh" "
    ssh ${USER[0]}@${IP[0]} -t -t "bash ${WORKDIR}/spark/spark_init.sh"
  fi
}

driver_deploy() {

  source ${WORKDIR}/local_ip.sh
  spark_file_sync
  echo "############spark driver 部署,需准备${spark_clusters_num}个节点的配置文件......"
  echo "excute time:$(date +"%Y-%m-%d %H:%M:%S")"
  for ((i = 0; i < ${spark_clusters_num}; i++)); do
    local_ip ${IP[i]}
    echo "############driver 单机${IP[i]}"
    if [ ${is_local_ip} -eq 0 ]; then
      sh ${WORKDIR}/spark/spark_driver.sh
    else
      ssh ${USER[i]}@${IP[i]} -t -t "bash ${WORKDIR}/spark/spark_driver.sh"
    fi
  done
}

spark_deploy() {
  echo ${driver}
  if [ ${driver} -eq 1 ]; then
    driver_deploy
  else
    cluster_deploy
  fi
}

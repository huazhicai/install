#!/bin/sh
WORKDIR=$(cd $(dirname $0);pwd) #脚本所在路径
echo "脚本所在路径${WORKDIR}"
PROFILE_PATH=${WORKDIR}/greenplum/profile

######################profile######################
MEMBER_IPS=($(grep '^member.' ${PROFILE_PATH}))
greenplum_clusters_num=${#MEMBER_IPS[*]}
MEMBER=() #greenplum集群index
IP=()     #greenplum集群ip
USER=()
echo "greenplum集群数量：${greenplum_clusters_num},详细信息：${MEMBER_IPS[*]}"
for ((i = 0; i < ${greenplum_clusters_num}; i++)); do
  member_ip=${MEMBER_IPS[i]}
  array=(${member_ip//=/ })
  arr0=${array[0]}
  member=(${arr0//./ })
  arr1=${array[1]}
  ip=(${arr1//:/ })
  MEMBER[i]=${member[1]}
  IP[i]=${ip[0]}
  USER[i]=${ip[1]}
  echo "第${member[1]}个节点，ip:${ip[0]},hostname:${ip[0]}，user:${ip[1]}"
done
######################profile######################

greenplum_file_sync() {
  echo "========开始greenplum安装文件同步======"
  for ((i = 0; i < ${#MEMBER[@]}; i++)); do
    echo ${IP[i]}
    local_ip ${IP[i]}
    if [[ ${is_local_ip} -eq 0 ]]; then
      echo "========本机ip跳过greenplum安装文件同步======"
    else
      sh ${WORKDIR}/sync.sh ${USER[i]} ${IP[i]}
      rsync -avzP ${WORKDIR}/greenplum ${USER[i]}@${IP[i]}:${WORKDIR}/
    fi
  done
}

greenplum_check() {
  echo "开始greenplum 参数校验"
  if [[ ${greenplum_clusters_num} -ge 1 ]]; then
    if [[ ${#MEMBER[*]} -eq ${greenplum_clusters_num} && ${#IP[*]} -eq ${greenplum_clusters_num} && ${#USER[*]} -eq ${greenplum_clusters_num} ]]; then
      echo "greenplum 参数校验成功"
      return 0
    fi
    echo "exit 退出,节点配置格式为member.节点id=内网ip：端口:用户,例 member.0=172.16.11.11:root"
    return 0
  else
    echo "exit 退出,greenplum集群节点数必须配置,请前往${PROFILE_PATH}配置"
    return 1
  fi
}

greenplum_setup() {
  echo "############修改服务器配置参数,重启服务器使之生效#############"
  for ((i = 0; i < ${greenplum_clusters_num}; i++)); do
    local_ip ${IP[i]}
    echo "#########配置节点${IP[i]}"
    if [[ ${is_local_ip} -eq 0 ]]; then
      sh ${WORKDIR}/greenplum/greenplum_setup.sh
    else
      ssh ${USER[i]}@${IP[i]} -t -t "bash ${WORKDIR}/greenplum/greenplum_setup.sh"
    fi
  done
  echo "############服务器配置参数修改完成,重启服务器使之生效#############"
}

deploy() {
  echo "############greenplum配置文件准备,需准备${greenplum_clusters_num}个节点的配置文件......"
  echo "excute time:$(date +"%Y-%m-%d %H:%M:%S")"
  for ((i = 0; i < ${greenplum_clusters_num}; i++)); do
    local_ip ${IP[i]}
    echo "############部署节点${IP[i]}"
    if [[ ${is_local_ip} -eq 0 ]]; then
      sh ${WORKDIR}/greenplum/greenplum_install.sh
    else
      ssh gpadmin@${IP[i]} -t -t "bash ${WORKDIR}/greenplum/greenplum_install.sh"
    fi
  done
}

greenplum_deploy() {
  source ${WORKDIR}/local_ip.sh
  greenplum_file_sync
  read -p "配置系统参数:[yes(y)|no(n)]" next
  if [ ${next:0:1} == 'y' ]; then
    greenplum_setup
  else
    deploy
  fi
}

#!/bin/sh
WORKDIR=$(cd `dirname $0`;pwd)      #脚本所在路径
echo "脚本所在路径${WORKDIR}"
CONF_PATH=${WORKDIR}/conf
echo "CONF_PATH${CONF_PATH}"
PROFILE_PATH=${WORKDIR}/profile
enable_authorization=$(grep 'enable_authorization' ${PROFILE_PATH}|awk -F'=' '{print $2}')
######################profile######################
MEMBER_IPS=($(grep 'member.' ${PROFILE_PATH}))
echo "MEMBER_IPS${member_ips[*]}"
mongo_clusters_num=${#MEMBER_IPS[*]}
echo "mongo_clusters_num${mongo_clusters_num}"
MEMBER=()        #mongo集群index
IP=()            #mongo集群ip
PORT=()          #mongo集群端口
USER=()          #用户
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
  PORT[i]=${ip[1]}
  echo "第${member[1]}个节点，ip:${ip[0]},port:${ip[1]}"
done
echo "${MEMBER[*]},${IP[*]},${PORT[*]}"
######################profile######################
#初始化集群
Init(){
  echo "############开始初始化Mongo集群......"
  mongo_member=""
  last=`expr ${mongo_clusters_num} - 1`
  for((i=0;i<${mongo_clusters_num};i++))
  do
    mongo_member="${mongo_member} {'_id' : ${i}, 'host' : '${IP[i]}:${PORT[i]}'}"
    if [[ $i -ne $last ]] ;then
        mongo_member="${mongo_member} ,"
    fi
  done
  cat>/etc/mongo_init.js<<EOF
config = {"_id" : "aiit-zhyl",
            "members" : [${mongo_member}]}
rs.initiate(config);
rs.status();
EOF
if [[ ${enable_authorization} && ${enable_authorization} -eq 1 ]] ;then
  mongo --port ${PORT} -u root -p AdminPwd4Zhyl  /etc/mongo_init.js
else
  mongo --port ${PORT} /etc/mongo_init.js
fi
}

Init

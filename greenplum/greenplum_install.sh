#!/bin/sh
WORKDIR=$(cd `dirname $0`;pwd)      #脚本所在路径
echo "脚本所在路径${WORKDIR}"

rpm -ivh --force --nodeps ${WORKDIR}/rpm/*.rpm
sudo chown -R gpadmin:gpadmin /usr/local/greenplum*
sudo chgrp -R gpadmin /usr/local/greenplum*

cat >> /home/gpadmin/.bashrc << EOF
source /usr/local/greenplum-db/greenplum_path.sh
EOF

# master
sudo mkdir -p /data/greenplum/master
sudo chown gpadmin:gpadmin /data/greenplum/master


# standby
 source /usr/local/greenplum-db/greenplum_path.sh
 gpssh -h smdw -e 'mkdir -p /data/greenplum/master'
 gpssh -h smdw -e 'chown gpadmin:gpadmin /data/greenplum/master'

 # seg
source /usr/local/greenplum-db/greenplum_path.sh
gpssh -f /usr/local/greenplum-db/seg_host -e 'mkdir -p /data/greenplum/{data1,data2,data3,data4}/{primary,mirror}'
gpssh -f /usr/local/greenplum-db/seg_host -e 'chown -R gpadmin:gpadmin /data/greenplum/data*'


gpcheckperf -f /usr/local/greenplum-db/seg_host -r N -d /tmp
gpcheckperf -f /usr/local/greenplum-db/seg_host -r ds -D -d /data/greenplum/data1/primary

# 集群时钟校验
gpssh -f /usr/local/greenplum-db/all_host -e 'date'

# 集群初始化
gpinitsystem -c /home/gpadmin/gpconfigs/gpinitsystem_config -h /usr/local/greenplum-db/seg_host -S -s 10-80-131-111


su - gpadmin
mkdir -p /home/gpadmin/gpconfigs
cp $GPHOME/docs/cli_help/gpconfigs/gpinitsystem_config /home/gpadmin/gpconfigs/gpinitsystem_config

gpinitsystem -c /home/gpadmin/gpconfigs/gpinitsystem_config -h /usr/local/greenplum-db/seg_host -D

PROFILE_PATH=${WORKDIR}/profile
HOSTIPS=$(grep 'member.' ${PROFILE_PATH}|awk -F'=' '{print $2}'|awk -F':' '{print $1}')

USERNAME=gpadmin
KEY=zhyl123456
new_key='Zhyl&greenplum123'

local_ip=$(ip addr | grep 'inet' | grep -v 'inet6\|127.0.0.1' | grep -v grep | awk -F '/' '{print $1}' | awk '{print $2}')
#发送本机公钥到目标主机
if ! rpm -q expect &>/dev/null;then
  rpm -ivh ${WORKDIR}/yumpacker/expect-5.45-14.el7_1.x86_64.rpm
fi
[ ! -f /home/${USERNAME}/.ssh/id_rsa.pub ] && ssh-keygen -N  '' -f /home/${USERNAME}/.ssh/id_rsa     #非交互生成密钥文件
[ -f ~/.ssh/known_hosts ] && > ~/.ssh/known_hosts
echo "StrictHostKeyChecking no" >~/.ssh/config


for HOSTIP in $HOSTIPS
do
  expect << EOF
set timeout 300
spawn ssh-copy-id ${USERNAME}@${HOSTIP}
expect "password:"              {send "${KEY}\r"}
expect "#"                      {send "exit\r"}
EOF
done
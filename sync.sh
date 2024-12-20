#!/bin/sh
WORKDIR=$(cd `dirname $0`;pwd)      #脚本所在路径

[[ $# -ne 2 ]] && echo "invalid user and ip for sync" && exit 1
target_user=$1
target_ip=$2

echo "${target_user}@${target_ip}"
ssh ${target_user}@${target_ip} -t -t "mkdir -p ${WORKDIR}"
scp -r ${WORKDIR}/rsync-3.1.2-10.el7.x86_64.rpm ${target_user}@${target_ip}:${WORKDIR}/
rpm -ivh --force --nodeps ${WORKDIR}/rsync-3.1.2-10.el7.x86_64.rpm
ssh ${target_user}@${target_ip} -t -t "rpm -ivh --force --nodeps ${WORKDIR}/rsync-3.1.2-10.el7.x86_64.rpm"
rsync -avzP ${WORKDIR}/{install.sh,local_ip.sh,profile,mk_secure_dir.sh,add_to_file.sh} ${target_user}@${target_ip}:${WORKDIR}/

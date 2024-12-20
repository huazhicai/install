#!/bin/bash

BACKUP_DIR=~/mybackup
DB_NAME=mytest
SEG_HOST=~/conf/seg_hosts

REMOTE_IP=10.0.108.7
flag=$1  # 1 全量


incremental(){
if [ ! -d ${BACKUP_DIR} ];then
  echo "##########开始全量备份###########"
  gpbackup --dbname ${DB_NAME} --backup-dir ${BACKUP_DIR} --leaf-partition-data
else
  echo "##########开始增量备份###########"
  gpbackup --dbname ${DB_NAME} --backup-dir ${BACKUP_DIR} --leaf-partition-data --incremental
fi
}


full_back(){
  echo "##########${date}开始全量备份###########"
  gpbackup --dbname ${DB_NAME} --backup-dir ${BACKUP_DIR} --leaf-partition-data
  ssh root@$REMOTE_IP -t -t "cd /data && tar -zcvf backup_$(date +%Y%m%d).tar.gz backup >/dev/null 2>&1 && rm -rf backup/*"
}


back_up(){
  if [[ ${flag} -eq 1 ]];then
    full_back
  else
    incremental
  fi
  echo "#######数据同步到备份服务器$REMOTE_IP#######"
  gpssh -f ${SEG_HOST} -e 'rsync -avzP '${BACKUP_DIR}' root@'${REMOTE_IP}':/data/backup/${HOSTNAME}'
}


back_up
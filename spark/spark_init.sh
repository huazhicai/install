#!/bin/sh

WORKDIR=$(cd `dirname $0`;pwd)      #脚本所在路径
echo "脚本所在路径${WORKDIR}"

SPARK_DIR=/usr/local/spark-3.0.0-bin-hadoop3.2
chown -R aiit-zhyl:aiit-zhyl ${SPARK_DIR}
echo $SPARK_DIR

#cd ~/.ssh && cat id_rsa.pub >> authorized_keys  # 自身免密
su - aiit-zhyl -s /bin/sh ${SPARK_DIR}/sbin/start-all.sh

#!/bin/sh

WORKDIR=$(cd `dirname $0`;pwd)      #脚本所在路径
echo "脚本所在路径${WORKDIR}"

SELF_IP=$1
MASTER_IP=$2
MEMBERS_IP_LIST=("$@")
MEMBERS_IP_LIST=("${MEMBERS_IP_LIST[@]:2}")
LOCAL_IP=$(ifconfig | grep 'inet'| grep -v '127.0.0.1' | cut -d: -f2 | awk '{ print $2}')

SPARK_PACKAGE_PATH=${WORKDIR}/spark-3.0.0-bin-hadoop3.2.tgz

# 解压安装包
tar -zxvf ${SPARK_PACKAGE_PATH} -C /usr/local
SPARK_DIR=/usr/local/spark-3.0.0-bin-hadoop3.2

# 拷贝第三方jars
cp ${WORKDIR}/jars/* ${SPARK_DIR}/jars/

# 配置spark-conf.sh
cd ${SPARK_DIR}

cp conf/spark-env.sh.template conf/spark-env.sh
echo "export SPARK_LOCAL_IP=${SELF_IP}" >> conf/spark-env.sh
echo "export SPARK_MASTER_HOST=${MASTER_IP}" >> conf/spark-env.sh

# 配置slaves
cp conf/slaves.template conf/slaves
sed -i '$d' conf/slaves

for((i=0;i<${#MEMBERS_IP_LIST[@]};i++))
do
    echo "${MEMBERS_IP_LIST[$i]}" >> conf/slaves
done


# 配置环境变量
echo "" >> /home/aiit-zhyl/.bashrc
echo "export SPARK_HOME='/usr/local/spark-3.0.0-bin-hadoop3.2'" >> /home/aiit-zhyl/.bashrc
echo "export PYSPARK_PYTHON=python3" >> /home/aiit-zhyl/.bashrc
source /home/aiit-zhyl/.bashrc

echo "export SPARK_HOME='/usr/local/spark-3.0.0-bin-hadoop3.2'" >> ~/.bashrc
echo "export PYSPARK_PYTHON=python3" >> ~/.bashrc
source ~/.bashrc

echo "$LOCAL_IP $HOSTNAME" >> /etc/hosts

# 安装python依赖
cd ${WORKDIR}
#python3 -m pip install --no-index --find-links=../pip_package -r requirements.txt

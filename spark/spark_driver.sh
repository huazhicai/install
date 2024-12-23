#!/bin/sh
# spark driver部署
WORKDIR=$(cd $(dirname $0);pwd) #脚本所在路径
echo "脚本所在路径${WORKDIR}"

SPARK_PACKAGE_PATH=${WORKDIR}/spark-3.0.0-bin-hadoop3.2.tgz

install_spark() {
  if [ ! -f '/usr/local/spark-3.0.0-bin-hadoop3.2/README.md' ];then
    # 解压安装包
    tar -zxf ${SPARK_PACKAGE_PATH} -C /usr/local
    SPARK_DIR=/usr/local/spark-3.0.0-bin-hadoop3.2

    # 拷贝第三方jars
    cp ${WORKDIR}/jars/* ${SPARK_DIR}/jars/

    # 配置环境变量
    echo "" >>/home/aiit-zhyl/.bashrc
    echo "export SPARK_HOME='/usr/local/spark-3.0.0-bin-hadoop3.2'" >>/home/aiit-zhyl/.bashrc
    echo "export PYSPARK_PYTHON=python3" >>/home/aiit-zhyl/.bashrc
    source /home/aiit-zhyl/.bashrc

    echo "export SPARK_HOME='/usr/local/spark-3.0.0-bin-hadoop3.2'" >>~/.bashrc
    echo "export PYSPARK_PYTHON=python3" >>~/.bashrc
    source ~/.bashrc

    chown -R aiit-zhyl:aiit-zhyl ${SPARK_DIR}
  else
    echo '##########spark 已经安装了############'
  fi
}

install_spark

#echo "$LOCAL_IP $HOSTNAME" >> /etc/hosts
# 安装python依赖
cd ${WORKDIR}
python3 -m pip install --no-index --find-links=../pip_package -r requirements.txt

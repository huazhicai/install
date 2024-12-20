#!/bin/sh
WORKDIR=$(cd `dirname $0`;pwd)      #脚本所在路径
echo "脚本所在路径${WORKDIR}"
YUM_PATH=$WORKDIR/../yumpacker
PROFILE_PATH=${WORKDIR}/profile


install_python(){
  echo "###########################安装python"
  cd ${WORKDIR} && tar -xzf Python-3.8.5.tgz && cd Python-3.8.5/ &&./configure --enable-optimizations --enable-loadable-sqlite-extensions && make clean && make altinstall
  ln -sf /usr/local/bin/python3.8 /usr/local/bin/python3
  echo "###########################安装pip"
  cd ${WORKDIR} && python3 -m pip install --no-index --find-links=./pip_package -r requirements.txt
}

install_python

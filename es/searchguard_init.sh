#!/bin/sh
WORKDIR=$(cd `dirname $0`;pwd)      #脚本所在路径
echo "添加searchguard==============="
${WORKDIR}/elasticsearch/bin elasticsearch-plugin install -b file:///${WORKDIR}/elasticsearch/search-guard-5-5.6.10-19.4.zip
echo "配置searchguard==============="
sh ${WORKDIR}/elasticsearch/plugins/search-guard-5/tools/install_demo_configuration.sh
echo "重启ES服务===================="
systemctl stop elasticsearch
systemctl start elasticsearch
echo "ES服务状态===================="
systemctl status elasticsearch
echo "初始化searchguard============="
sh ${WORKDIR}/elasticsearch/plugins/search-guard-5/tools/ sgadmin.sh -cd ..\sgconfig -key ..\..\..\config\kirk-key.pem -cert ..\..\..\config\kirk.pem -cacert ..\..\..\config\root-ca.pem -nhnv -icl

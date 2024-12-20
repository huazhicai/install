#!/bin/sh
WORKDIR=$(cd `dirname $0`;pwd)      #脚本所在路径
echo "添加elasticsearch用户==============="
USER_COUNT=`cat /etc/passwd | grep '^elasticsearch:' -c`
if [[ $USER_COUNT -ne 1 ]]
 then
   useradd elasticsearch
   echo elasticsearch | passwd elasticsearch --stdin
else
 echo 'user exits'
fi

echo "文件夹创建==============="
mkdir -p /data/elasticsearch/data
mkdir /data/elasticsearch/logs

echo "===================start es============================="

cp -rf ${WORKDIR}/elasticsearch/* /home/elasticsearch

# 修改配置参数
machine_ip=$(ip addr | grep 'inet' | grep -v 'inet6\|127.0.0.1' | grep -v grep | awk -F '/' '{print $1}' | awk '{print $2}')

sed -i "s/network.host:/network.host: ${machine_ip}/g" /home/elasticsearch/config/elasticsearch.yml
sed -i "s/node.name:/node.name: ${HOSTNAME}/g" /home/elasticsearch/config/elasticsearch.yml


chown elasticsearch /home/elasticsearch/ -R
chown elasticsearch /data/elasticsearch/ -R
echo "===================更改启动所需系统参数============================="
sed -i '$a elasticsearch soft nofile 65536' /etc/security/limits.conf
sed -i '$a elasticsearch hard nofile 65536' /etc/security/limits.conf
sed -i '$a elasticsearch soft nproc 4096' /etc/security/limits.conf
sed -i '$a elasticsearch hard nproc 4096' /etc/security/limits.conf
sed -i '$a vm.max_map_count = 655360' /etc/sysctl.conf
sed -i 's/*/elasticsearch/' /etc/security/limits.d/20-nproc.conf

sysctl -p

echo "===================start /usr/lib/systemd/system============================="
cat>/usr/lib/systemd/system/elasticsearch.service<<EOF
[Unit]
Description=elasticsearch
Wants=network-online.target
After=network-online.target

[Service]
User=elasticsearch
LimitNOFILE=100000
LimitNPROC=100000
ExecStart=/home/elasticsearch/bin/elasticsearch
# Let systemd restart this service on-failure
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "===================start service============================"
chmod +x /usr/lib/systemd/system/elasticsearch.service
chmod +x /home/elasticsearch/bin/elasticsearch
echo "1)重新加载服务配置文件"
systemctl daemon-reload
echo "2）启动服务"
systemctl start elasticsearch
echo "3）设置开机自启动"
systemctl enable elasticsearch
echo "4）查看服务状态"
systemctl status elasticsearch

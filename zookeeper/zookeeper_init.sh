#!/bin/sh
WORKDIR=$(
  cd $(dirname $0)
  pwd
) #脚本所在路径
echo "脚本所在路径${WORKDIR}"

#sh /usr/local/zookeeper/bin/zkServer.sh stop
sh /usr/local/zookeeper/bin/zkServer.sh start
#sh /usr/local/zookeeper/bin/zkServer.sh status
#sh /usr/local/zookeeper/bin/zkServer.sh start-foreground

#cd ~
#sudo systemctl daemon-reload
#sudo systemctl start zookeeper
#sudo systemctl enable zookeeper
#sudo systemctl status zookeeper
#sh /usr/local/zookeeper/bin/zkServer.sh status

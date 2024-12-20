#!/bin/sh
WORKDIR=$(cd `dirname $0`;pwd)      #脚本所在路径
echo "脚本所在路径${WORKDIR}"

id=$[$1+1]

PROFILE=${WORKDIR}/profile

IPS=($(grep '^member.' ${PROFILE}|awk -F'=' '{print $2}'|awk -F':' '{print $1}'))

install() {
  rm -rf /usr/local/zookeeper && cd ~
  if [ ! -f "/usr/local/zookeeper/README.md" ]; then
    systemctl stop firewalld && systemctl disable firewalld
    tar -zxf ${WORKDIR}/apache-zookeeper-3.7.1-bin.tar.gz -C /usr/local
    mv /usr/local/apache-zookeeper-3.7.1-bin /usr/local/zookeeper
    cd /usr/local/zookeeper/conf && mv zoo_sample.cfg zoo.cfg

    mkdir -p /data/zookeeper-cluster/data
    sed -i '/dataDir=/c dataDir=/data/zookeeper-cluster/data' /usr/local/zookeeper/conf/zoo.cfg

    for((i=0;i<${#IPS[*]};i++))
    do
      sed -i "\$a server.$[$i+1]=${IPS[i]}:2888:3888" /usr/local/zookeeper/conf/zoo.cfg
    done

    cd /data/zookeeper-cluster/data && echo ${id} > myid

    cat <<EOF | sudo tee /etc/systemd/system/zookeeper.service
[Unit]
Description=ZooKeeper Service
After=network-online.target 
Requires=network-online.target

[Service]
Type=forking

ExecStart=/usr/local/zookeeper/bin/zkServer.sh --config /usr/local/zookeeper/conf start
ExecStop=/usr/local/zookeeper/bin/zkServer.sh --config /usr/local/zookeeper/conf stop
ExecReload=/usr/local/zookeeper/bin/zkServer.sh --config /usr/local/zookeeper/conf restart
WorkingDirectory=/usr/local

[Install]
WantedBy=multi-user.target
EOF
  fi

  systemctl daemon-reload
  systemctl start zookeeper
  systemctl enable zookeeper
}

install
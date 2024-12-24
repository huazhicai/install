#!/bin/bash
set -e
WORKDIR=$(cd $(dirname $0);pwd) #脚本所在路径
cd ${WORKDIR}
echo "脚本所在路径${WORKDIR}"

HOST=$1
PORT=$2

[ ! -f "/usr/local/redis/bin/redis-server" ] && tar -zxvf redis-6.2.6.tar.gz -C /usr/local && cd /usr/local/redis-6.2.6 && make install PREFIX=/usr/local/redis

mkdir -p /data/redis_cluster/redis_${PORT}/{data,log}

cat >/etc/redis${PORT}.conf <<EOF
bind ${HOST}
port ${PORT}
daemonize yes
logfile /data/redis_cluster/redis_${PORT}/log/redis_${PORT}.log
dir /data/redis_cluster/redis_${PORT}/data
pidfile /var/run/redis_${PORT}.pid
dbfilename redis_${PORT}.rdb
cluster-enabled yes
protected-mode no
requirepass Zhyl&redis123
masterauth Zhyl&redis123
cluster-config-file node_${PORT}.conf
cluster-node-timeout 15000
EOF

echo "======设置开机自启redis${PORT}.service"
cat >/usr/lib/systemd/system/redis${PORT}.service <<EOF
[Unit]
Description=redis-server
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/redis/bin/redis-server /etc/redis${PORT}.conf
ExecStop=/usr/local/redis/bin/redis-cli -h ${HOST} -p ${PORT} shutdown
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start redis${PORT}
systemctl enable redis${PORT}
systemctl status redis${PORT}

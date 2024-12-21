#!/bin/bash
set -e
WORKDIR=$(cd $(dirname $0);pwd) #脚本所在路径
cd ${WORKDIR}
echo "脚本所在路径${WORKDIR}"

LOCAL_IP=$(hostname -I | awk '{print $1}' | head -n 1)  # 获取第一个 IP 地址

# 安装 Redis
REDIS_VERSION="redis-6.2.6"
REDIS_TAR="${WORKDIR}/../package/redis-6.2.6.tar.gz"

echo "解压 Redis 安装包并开始安装..."
tar -zxvf "$REDIS_TAR" -C "$WORKDIR"
cd "$REDIS_VERSION"
make && make install  # 默认安装在 /usr/local/bin 下


# 配置 Redis
echo "配置 Redis..."
mkdir -p /etc/redis
cp redis.conf /etc/redis/
# 删除注释行和空行
sed -i '/^\s*#/d' /etc/redis/redis.conf
sed -i '/^\s*$/d' /etc/redis/redis.conf
# 修改 Redis 配置文件
sed -i 's/daemonize no/daemonize yes/g' /etc/redis/redis.conf
sed -i "s/bind 127.0.0.1*/bind ${LOCAL_IP}/g" /etc/redis/redis.conf
sed -i "s|dir .|dir /etc/redis|g" /etc/redis/redis.conf
sed -i "s|logfile \"\"|logfile /etc/redis/redis.log|g" /etc/redis/redis.conf

echo "requirepass zhyl0123" >> /etc/redis/redis.conf

echo "======设置开机自启 redis.service"
cat > /usr/lib/systemd/system/redis.service <<EOF
[Unit]
Description=redis-server
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/bin/redis-server /etc/redis/redis.conf
ExecStop=/usr/local/bin/redis-cli -h ${LOCAL_IP} shutdown
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

echo "启动并启用 Redis 服务..."
systemctl daemon-reload
systemctl start redis
systemctl enable redis
systemctl status redis

echo "Redis 安装和配置完成!"

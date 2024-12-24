#!/bin/bash
set -e

WORKDIR=$(cd $(dirname $0);pwd)  # 脚本所在路径
cd ${WORKDIR}
echo "脚本所在路径: ${WORKDIR}"

# 检查是否传入主机和端口
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "错误: 请提供 HOST 和 PORT 参数"
    exit 1
fi

HOST=$1
PORT=$2

# 安装 Redis
install() {
    if [ ! -f "/usr/local/bin/redis-server" ]; then
        echo "安装 Redis..."
        tar -zxvf redis-6.2.6.tar.gz -C ${WORKDIR}
        cd redis-6.2.6
        make && make install
        echo "Redis 安装完成"
    else
        echo "Redis 已经安装，跳过安装步骤"
    fi
}

# 配置 Redis
config_redis() {
    echo "配置 Redis..."

    # 创建 Redis 数据目录
    mkdir -p /etc/redis/${PORT}/data

    # 拷贝并清理配置文件
    cp ${WORKDIR}/redis-6.2.6/redis.conf /etc/redis/${PORT}/redis.conf
    sed -i '/^\s*#/d' /etc/redis/${PORT}/redis.conf  # 删除注释行
    sed -i '/^\s*$/d' /etc/redis/${PORT}/redis.conf  # 删除空行

    # 修改配置文件
    sed -i 's/daemonize no/daemonize yes/g' /etc/redis/${PORT}/redis.conf
    sed -i "s/bind 127.0.0.1 .*/bind ${HOST}/g" /etc/redis/${PORT}/redis.conf
    sed -i "s/port .*/port ${PORT}/g" /etc/redis/${PORT}/redis.conf
    sed -i "s|dir .|dir /etc/redis/${PORT}/data|g" /etc/redis/${PORT}/redis.conf
    sed -i "s|logfile .*|logfile /etc/redis/${PORT}/redis.log|g" /etc/redis/${PORT}/redis.conf
    sed -i "s|pidfile .*|pidfile /var/run/redis_${PORT}.pid|g" /etc/redis/${PORT}/redis.conf
    sed -i "s|appendonly no|appendonly yes|g" /etc/redis/${PORT}/redis.conf

    # 启用 Redis 集群配置
    sed -i "s|^# cluster-enabled|cluster-enabled|g" /etc/redis/${PORT}/redis.conf
    sed -i "s|^# cluster-config-file *|cluster-config-file nodes-${PORT}.conf|g" /etc/redis/${PORT}/redis.conf
    sed -i "s|^# cluster-node-timeout|cluster-node-timeout|g" /etc/redis/${PORT}/redis.conf  # 设置合理的超时时间

    # 设置密码
    echo "requirepass zhyl0123" >> /etc/redis/${PORT}/redis.conf
    echo "masterauth zhyl0123" >> /etc/redis/${PORT}/redis.conf

    echo "Redis 配置完成"
}

# 创建 systemd 服务文件
create_service() {
    echo "创建 Redis 服务文件..."

    cat >/usr/lib/systemd/system/redis${PORT}.service <<EOF
[Unit]
Description=Redis Server
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/bin/redis-server /etc/redis/${PORT}/redis.conf
ExecStop=/usr/local/bin/redis-cli -h ${HOST} -p ${PORT} shutdown
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

    echo "Redis 服务文件创建完成"
}

# 启动并设置 Redis 开机自启
start_redis() {
    echo "启动 Redis 服务..."

    systemctl daemon-reload
    systemctl start redis${PORT}
    systemctl enable redis${PORT}

    # 输出状态
    systemctl status redis${PORT}
}

# 执行安装和配置步骤
install
config_redis
create_service
start_redis

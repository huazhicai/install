#!/bin/bash

WORKDIR=$(cd `dirname $0`; pwd)      # 脚本所在路径
echo "脚本所在路径: ${WORKDIR}"

id=$(( $1 + 1 ))  # 计算 id，$1 是传入的参数，$1+1

PROFILE="${WORKDIR}/profile"
VERSION='3.7.1'
INSTALL_DIR="/usr/local/zookeeper"

# 获取所有的节点 IP
IPS=($(grep '^member.' ${PROFILE} | awk -F'=' '{print $2}' | awk -F':' '{print $1}'))

# 安装 Zookeeper
install() {
    # 解压 Zookeeper
    tar -zxf ${WORKDIR}/apache-zookeeper-${VERSION}-bin.tar.gz
    mv ${WORKDIR}/apache-zookeeper-${VERSION}-bin ${INSTALL_DIR}

    # 复制默认配置文件
    cp ${INSTALL_DIR}/conf/zoo_sample.cfg ${INSTALL_DIR}/conf/zoo.cfg

    # 创建数据目录和日志目录
    mkdir -p ${INSTALL_DIR}/{data,logs}

    # 修改配置文件
    sed -i "s|dataDir=.*|dataDir=${INSTALL_DIR}/data|" ${INSTALL_DIR}/conf/zoo.cfg
    sed -i "s|dataLogDir=.*|dataLogDir=${INSTALL_DIR}/logs|" ${INSTALL_DIR}/conf/zoo.cfg

    # 为每个节点添加 server 配置
    for ((i = 0; i < ${#IPS[@]}; i++))
    do
        # 添加 server 配置，格式为 server.x=ip:2888:3888
        sed -i "\$a server=$((i + 1))=${IPS[i]}:2888:3888" ${INSTALL_DIR}/conf/zoo.cfg
    done

    # 设置 myid 文件
    echo ${id} > ${INSTALL_DIR}/data/myid

    # 创建 systemd 服务
    cat <<EOF | sudo tee /etc/systemd/system/zookeeper.service
[Unit]
Description=ZooKeeper Service
After=network-online.target
Requires=network-online.target

[Service]
Type=forking
ExecStart=${INSTALL_DIR}/bin/zkServer.sh --config ${INSTALL_DIR}/conf start
ExecStop=${INSTALL_DIR}/bin/zkServer.sh --config ${INSTALL_DIR}/conf stop
ExecReload=${INSTALL_DIR}/bin/zkServer.sh --config ${INSTALL_DIR}/conf restart
WorkingDirectory=${INSTALL_DIR}

[Install]
WantedBy=multi-user.target
EOF

    # 重新加载 systemd 服务，启动 Zookeeper 服务，并设置开机自启动
    systemctl daemon-reload
    systemctl start zookeeper
    systemctl enable zookeeper
}

# 调用安装函数
install
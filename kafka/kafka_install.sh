#!/bin/sh
WORKDIR=$(cd $(dirname $0);pwd) #脚本所在路径
echo -e "\n脚本所在路径${WORKDIR}"

PROFILE_PATH=${WORKDIR}/profile
INSTALL_DIR='/usr/local/kafka'

broker_id=$(( $1 + 1 ))  # 计算 id，$1 是传入的参数，$1+1

LOCAL_IP=$(hostname -I | awk '{print $1}' | head -n 1)  # 获取第一个 IP 地址

# 初始化变量
ZOOKEEPER_CONNECT="zookeeper.connect="
ZOOKEEPER_PORT='2181'
# 读取配置文件并提取 IP 地址
while IFS='=' read -r key value; do
    if [[ $key == member.* ]]; then
        # 提取 IP 地址（使用 ":" 前的部分）
        IP=$(echo "$value" | cut -d':' -f1)
        # 拼接 IP 和端口号
        ZOOKEEPER_CONNECT+="${IP}:${ZOOKEEPER_PORT},"
    fi
done < "$PROFILE_PATH"
# 移除末尾的逗号
ZOOKEEPER_CONNECT=${ZOOKEEPER_CONNECT%,}
echo "$ZOOKEEPER_CONNECT"

install() {
  tar -zxf ${WORKDIR}/../package/kafka_2.13-3.3.1.tgz -C /usr/local
  mv /usr/local/kafka_2.13-3.3.1 ${INSTALL_DIR}
  mkdir ${INSTALL_DIR}/logs

  sed -i "/zookeeper.connect=/c ${ZOOKEEPER_CONNECT}" ${INSTALL_DIR}/config/server.properties
  sed -i "/broker.id=/c broker.id=${broker_id}" ${INSTALL_DIR}/config/server.properties
  sed -i "/log.dirs=/c log.dirs=${INSTALL_DIR}/logs" ${INSTALL_DIR}/config/server.properties
  echo "listeners=PLAINTEXT://${LOCAL_IP}:9092" >> ${INSTALL_DIR}/config/server.properties
  echo "delete.topic.enable=true" >> ${INSTALL_DIR}/config/server.properties

  cat >/usr/lib/systemd/system/kafka.service <<EOF
[Unit]
Requires=zookeeper.service
After=network.target remote-fs.target zookeeper.service

[Service]
Type=simple
User=root
ExecStart=${INSTALL_DIR}/bin/kafka-server-start.sh ${INSTALL_DIR}/config/server.properties
ExecStop=${INSTALL_DIR}/bin/kafka-stop-start.sh
Restart=on-abnormal

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable kafka
  sudo systemctl start kafka
  sudo systemctl status kafka
}

install
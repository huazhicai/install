#!/bin/sh
WORKDIR=$(
  cd $(dirname $0)
  pwd
) #脚本所在路径
echo "脚本所在路径${WORKDIR}"
PROFILE_PATH=${WORKDIR}/profile

broker_id=$1

LOCAL_IP=$(ifconfig | grep 'inet'| grep -v '127.0.0.1' | cut -d: -f2 | awk '{ print $2}')

install() {
  tar -zxf ${WORKDIR}/kafka_2.13-3.3.1.tgz -C /usr/local

  sed -i '/zookeeper.connect=/c zookeeper.connect=' /usr/local/kafka_2.13-3.3.1/config/server.properties
  mkdir -p /data/kafka-logs
  # config
  sed -i "/broker.id=/c broker.id=${broker_id}" /usr/local/kafka_2.13-3.3.1/config/server.properties
  sed -i "/log.dirs=/c log.dirs=/data/kafka-logs" /usr/local/kafka_2.13-3.3.1/config/server.properties
  echo "listeners=PLAINTEXT://${LOCAL_IP}:9092" >> /usr/local/kafka_2.13-3.3.1/config/server.properties
  echo "delete.topic.enable=true" >> /usr/local/kafka_2.13-3.3.1/config/server.properties

  cat >/usr/lib/systemd/system/kafka.service <<EOF
[Unit]
Requires=zookeeper.service
After=network.target remote-fs.target zookeeper.service

[Service]
Type=simple
User=root
ExecStart=/usr/local/kafka_2.13-3.3.1/bin/kafka-server-start.sh /usr/local/kafka_2.13-3.3.1/config/server.properties
ExecStop=/usr/local/kafka_2.13-3.3.1/bin/kafka-stop-start.sh
Restart=on-abnormal

[Install]
WantedBy=multi-user.target
EOF
  sudo systemctl daemon-reload
  sudo systemctl start kafka
  sudo systemctl enable kafka
  sudo systemctl status kafka
}

install
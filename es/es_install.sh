#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.
WORKDIR=$(cd "$(dirname "$0")" && pwd)

# 配置
USER='es'
VERSION='7.14.2'
INSTALL_DIR="/home/${USER}/elasticsearch-${VERSION}"

PROFILE='./profile'
SEED_HOSTS=$(grep -oP '\d+\.\d+\.\d+\.\d+' "$PROFILE" | paste -sd, - | sed 's/^/["/;s/$/"]/')
echo "SEED_HOSTS=$SEED_HOSTS"


echo "Checking and adding Elasticsearch user if not exists..."
if ! id ${USER} &>/dev/null; then
  useradd ${USER}
  echo "${USER}:${USER}" | chpasswd
else
  echo "User '${USER}' already exists."
fi

echo "Creating directories for Elasticsearch..."
mkdir -p /home/${USER}/data /home/${USER}/logs

echo "Starting Elasticsearch installation..."
tar -zxvf "${WORKDIR}/elasticsearch-${VERSION}-linux-x86_64.tar.gz" -C "/home/${USER}"
cp -f "${WORKDIR}/elasticsearch.yml" "${INSTALL_DIR}/config"


echo "Updating Elasticsearch configuration..."
machine_ip=$(hostname -I | awk '{print $1}' | head -n 1)  # 获取第一个 IP 地址
sed -i "s/^network.host:.*$/network.host: ${machine_ip}/" "${INSTALL_DIR}/config/elasticsearch.yml"
sed -i "s/^node.name:.*$/node.name: ${HOSTNAME}/" "${INSTALL_DIR}/config/elasticsearch.yml"
echo "discovery.seed_hosts: ${SEED_HOSTS}" >> "${INSTALL_DIR}/config/elasticsearch.yml"
echo "cluster.initial_master_nodes: ${SEED_HOSTS}" >> "${INSTALL_DIR}/config/elasticsearch.yml"


echo "Setting ownership for Elasticsearch directories..."
chown -R ${USER}:${USER} /home/${USER}

echo "Updating system parameters for Elasticsearch..."
grep -q ${USER} /etc/security/limits.conf || cat <<EOF >> /etc/security/limits.conf
${USER} soft nofile 65536
${USER} hard nofile 65536
${USER} soft nproc 4096
${USER} hard nproc 4096
EOF

sysctl_conf="/etc/sysctl.conf"
if ! grep -q 'vm.max_map_count' "$sysctl_conf"; then
  echo "vm.max_map_count=655360" >> "$sysctl_conf"
fi
sysctl -p


echo "Install plugins..."
mkdir -p "${INSTALL_DIR}/plugins/ik" "${INSTALL_DIR}/plugins/pinyin"
unzip -o "${WORKDIR}/elasticsearch-analysis-ik-${VERSION}.zip" -d "${INSTALL_DIR}/plugins/ik"
unzip -o "${WORKDIR}/elasticsearch-analysis-pinyin-${VERSION}.zip" -d "${INSTALL_DIR}/plugins/pinyin"


# 创建 systemd 服务文件
echo "Creating systemd service for Elasticsearch..."
cat>/usr/lib/systemd/system/${USER}.service<<EOF
[Unit]
Description=elasticsearch
Wants=network-online.target
After=network-online.target

[Service]
User=${USER}
LimitNOFILE=100000
LimitNPROC=100000
ExecStart=${INSTALL_DIR}/bin/elasticsearch
# Let systemd restart this service on-failure
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF


# 启动 Elasticsearch 服务
echo "Starting Elasticsearch service..."
systemctl daemon-reload
systemctl start ${USER}
systemctl enable ${USER}
systemctl status ${USER} --no-pager
echo 'curl -X GET "localhost:9200/_cluster/health?pretty"'
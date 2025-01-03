#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.

# 配置
USER='elastic'
VERSION='8.15.5'
INSTALL_DIR="/home/${USER}/elasticsearch-${VERSION}"
WORKDIR=$(cd "$(dirname "$0")" && pwd)

# 下载 URL
ELASTICSEARCH_URL="https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${VERSION}-linux-x86_64.tar.gz"
IK_PLUGIN_URL="https://release.infinilabs.com/analysis-ik/stable/elasticsearch-analysis-ik-${VERSION}.zip"
PINYIN_PLUGIN_URL="https://release.infinilabs.com/analysis-pinyin/stable/elasticsearch-analysis-pinyin-${VERSION}.zip"

# 日志函数
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# 检查并下载文件
download_file() {
  local url=$1
  local output_file=$2
  if [[ ! -f "$output_file" ]]; then
    log "Downloading $output_file from $url..."
    if ! wget -q "$url" -O "$output_file"; then
      log "Failed to download $output_file from $url"
      exit 1
    fi
  else
    log "$output_file already exists, skipping download."
  fi
}

# 创建用户
create_user() {
  if ! id ${USER} &>/dev/null; then
    log "Creating user '${USER}'..."
    useradd ${USER}
    echo "${USER}:${USER}" | chpasswd
  else
    log "User '${USER}' already exists."
  fi
}

# 创建目录
create_directories() {
  log "Creating directories for Elasticsearch..."
  mkdir -p /home/${USER}/data /home/${USER}/logs
}

# 安装 Elasticsearch
install_elasticsearch() {
  log "Starting Elasticsearch installation..."
  tar -zxvf "${WORKDIR}/elasticsearch-${VERSION}-linux-x86_64.tar.gz" -C "/home/${USER}"
  cp -f "${WORKDIR}/elasticsearch.yml" "${INSTALL_DIR}/config"
}

# 更新 Elasticsearch 配置
update_config() {
  log "Updating Elasticsearch configuration..."
  local machine_ip=$(hostname -I | awk '{print $1}' | head -n 1)
  local config_file="${INSTALL_DIR}/config/elasticsearch.yml"

  sed -i "s|^path.data:.*$|path.data: /home/${USER}/data|" "$config_file"
  sed -i "s|^path.logs:.*$|path.logs: /home/${USER}/logs|" "$config_file"
  sed -i "s|^network.host:.*$|network.host: ${machine_ip}|" "$config_file"
  sed -i "s|^node.name:.*$|node.name: ${HOSTNAME}|" "$config_file"
  echo "discovery.seed_hosts: ${SEED_HOSTS}" >> "$config_file"
  echo "cluster.initial_master_nodes: ${SEED_HOSTS}" >> "$config_file"
}

# 设置目录权限
set_permissions() {
  log "Setting ownership for Elasticsearch directories..."
  chown -R ${USER}:${USER} /home/${USER}
}

# 更新系统参数
update_system_params() {
  log "Updating system parameters for Elasticsearch..."
  grep -q ${USER} /etc/security/limits.conf || cat <<EOF >> /etc/security/limits.conf
${USER} soft nofile 65536
${USER} hard nofile 65536
${USER} soft nproc 4096
${USER} hard nproc 4096
EOF

  local sysctl_conf="/etc/sysctl.conf"
  if ! grep -q 'vm.max_map_count' "$sysctl_conf"; then
    echo "vm.max_map_count=655360" >> "$sysctl_conf"
  fi
  sysctl -p
}

# 安装插件
install_plugins() {
  log "Installing plugins..."
  mkdir -p "${INSTALL_DIR}/plugins/ik" "${INSTALL_DIR}/plugins/pinyin"
  unzip -o "${WORKDIR}/elasticsearch-analysis-ik-${VERSION}.zip" -d "${INSTALL_DIR}/plugins/ik"
  unzip -o "${WORKDIR}/elasticsearch-analysis-pinyin-${VERSION}.zip" -d "${INSTALL_DIR}/plugins/pinyin"
}

# 创建 systemd 服务
create_systemd_service() {
  log "Creating systemd service for Elasticsearch..."
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
}

# 启动 Elasticsearch 服务
start_service() {
  log "Starting Elasticsearch service..."
  systemctl daemon-reload
  systemctl start ${USER}
  systemctl enable ${USER}
  systemctl status ${USER} --no-pager
  log 'Run the following command to check cluster health:'
  log 'curl -X GET "localhost:9200/_cluster/health?pretty"'
}

# 主函数
main() {
  # 下载文件
  download_file "$ELASTICSEARCH_URL" "${WORKDIR}/elasticsearch-${VERSION}-linux-x86_64.tar.gz"
  download_file "$IK_PLUGIN_URL" "${WORKDIR}/elasticsearch-analysis-ik-${VERSION}.zip"
  download_file "$PINYIN_PLUGIN_URL" "${WORKDIR}/elasticsearch-analysis-pinyin-${VERSION}.zip"

  # 解析 SEED_HOSTS
  PROFILE="${WORKDIR}/profile"
  SEED_HOSTS=$(grep -oP '\d+\.\d+\.\d+\.\d+' "$PROFILE" | paste -sd, - | sed 's/^/["/;s/$/"]/')
  log "SEED_HOSTS=$SEED_HOSTS"

  # 安装流程
  create_user
  create_directories
  install_elasticsearch
  update_config
  set_permissions
  update_system_params
  install_plugins
  create_systemd_service
  start_service
}

# 执行主函数
main
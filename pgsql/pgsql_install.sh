#!/bin/sh
WORKDIR=$(cd `dirname $0`;pwd)      #脚本所在路径
echo "脚本所在路径${WORKDIR}"

# 设置 PostgreSQL 版本和数据库数据目录
PG_VERSION="13"
PG_DATA_DIR="/var/lib/pgsql/${PG_VERSION}/data"
REPLICATION_USER="replica"
REPLICATION_PASSWORD="replica"

# 设置主从服务器的 IP 地址
PROFILE="${WORKDIR}/profile"
MASTER_IP=$(grep "^member\.0" "$PROFILE" | awk -F'[=:]' '{print $2}')
SLAVE_IP=$(grep "^member\.1" "$PROFILE" | awk -F'[=:]' '{print $2}')
VPC_IP="${MASTER_IP%.*}.0/24" # 网段IP

machine_ip=$(hostname -I | awk '{print $1}' | head -n 1)  # 获取第一个 IP 地址

# PostgreSQL 配置项
CONFIGURE_PARAMS=(
  "listen_addresses = '*'"
  "max_connections = 100"
  "wal_level = replica"
  "synchronous_commit = on"
  "max_wal_senders = 32"
  "wal_sender_timeout = 60s"
  "archive_mode = on"
)

# 错误处理函数
handle_error() {
  echo "错误: $1"
  exit 1
}

install_postgresql() {
  echo "安装 PostgreSQL ..."
  # yum localinstall -y rpm/*.rpm || handle_error "PostgreSQL 安装失败"
   rpm -ivh --nodeps rpm/*.rpm || handle_error "PostgreSQL 安装失败"
}


configure_master() {
  echo "配置主服务器 ${MASTER_IP} ..."

  # 初始化数据库
  /usr/pgsql-${PG_VERSION}/bin/postgresql-${PG_VERSION}-setup initdb || handle_error "主服务器数据库初始化失败"
  systemctl start postgresql-${PG_VERSION} || handle_error "主服务器启动失败"
  cd ${PG_DATA_DIR}  # 避免切用户出现 Permission denied

  # 配置 PostgreSQL 主服务器， 报错不影响执行（ Permission denied）
  sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'postgres';" || handle_error "设置主服务器 postgres 密码失败"
  sudo -u postgres psql -c "CREATE ROLE $REPLICATION_USER LOGIN REPLICATION ENCRYPTED PASSWORD '$REPLICATION_PASSWORD';" || handle_error "创建复制用户失败"
  sudo -u postgres psql -c "CREATE ROLE \"aiit-zhyl\" LOGIN REPLICATION ENCRYPTED PASSWORD 'zhyl0123';" || handle_error "创建复制用户失败"
  sudo -u postgres psql -c "ALTER ROLE \"aiit-zhyl\" WITH SUPERUSER;"

  # 修改 pg_hba.conf 配置
  echo "host    all            all        ${VPC_IP}    md5" >> ${PG_DATA_DIR}/pg_hba.conf
  echo "host    replication    replica    ${SLAVE_IP}/32    md5" >> ${PG_DATA_DIR}/pg_hba.conf

  # 配置 PostgreSQL 参数
  for param in "${CONFIGURE_PARAMS[@]}"; do
    echo "$param" >> ${PG_DATA_DIR}/postgresql.conf
  done

  # 重启 PostgreSQL 服务以应用配置
  systemctl enable postgresql-${PG_VERSION} || handle_error "主服务器开机自启设置失败"
  systemctl restart postgresql-${PG_VERSION} || handle_error "主服务器重启失败"
}

configure_slave() {
  echo "配置从服务器 ${SLAVE_IP} ..."

  # 清理从服务器的数据目录
  cd ${PG_DATA_DIR}  # 避免切用户出现 Permission denied
  sudo rm -rf *

  # 使用 pg_basebackup 从主服务器同步数据
#  sudo -u postgres pg_basebackup -h ${MASTER_IP} -D ${PG_DATA_DIR} -U $REPLICATION_USER -X stream -P || handle_error "从服务器同步数据失败"
  expect -c "
spawn sudo -u postgres pg_basebackup -h ${MASTER_IP} -D ${PG_DATA_DIR} -U ${REPLICATION_USER} -X stream -P
expect \"Password for user ${REPLICATION_USER}: \"
send \"${REPLICATION_PASSWORD}\r\"
expect eof
"

  # 配置从服务器的 standby.signal
  echo "standby_mode = 'on'" | sudo tee ${PG_DATA_DIR}/standby.signal > /dev/null
  echo "primary_conninfo = 'host=${MASTER_IP} port=5432 user=$REPLICATION_USER password=$REPLICATION_PASSWORD'" | sudo tee -a ${PG_DATA_DIR}/postgresql.conf > /dev/null
  echo "recovery_target_timeline = 'latest'" | sudo tee -a ${PG_DATA_DIR}/postgresql.conf > /dev/null
  echo "max_standby_streaming_delay = 30s" | sudo tee -a ${PG_DATA_DIR}/postgresql.conf > /dev/null
  echo "wal_receiver_status_interval = 10s" | sudo tee -a ${PG_DATA_DIR}/postgresql.conf > /dev/null
  echo "max_connections = 1000" | sudo tee -a ${PG_DATA_DIR}/postgresql.conf > /dev/null
  echo "hot_standby = on" | sudo tee -a ${PG_DATA_DIR}/postgresql.conf > /dev/null
  echo "hot_standby_feedback = on" | sudo tee -a ${PG_DATA_DIR}/postgresql.conf > /dev/null

  # 启动从服务器
  sudo systemctl enable postgresql-${PG_VERSION}
  sudo systemctl start postgresql-${PG_VERSION} || handle_error "从服务器启动失败"

  echo "检查主服务器复制状态"
  sudo -u postgres psql -h ${MASTER_IP} -c "SELECT * FROM pg_stat_replication;" || handle_error "检查主服务器复制状态失败"
}

main() {
  install_postgresql

  if [ "${machine_ip}" == "${MASTER_IP}" ]; then
    configure_master
  else
    configure_slave
  fi
}

main

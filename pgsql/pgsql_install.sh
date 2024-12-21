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
  "max_connections = 100"
  "wal_level = replica"
  "synchronous_commit = on"
  "max_wal_senders = 32"
  "wal_sender_timeout = 60s"
  "archive_mode = on"
)


# 配置主服务器
configure_master() {
  echo "安装 PostgreSQL ..."
#  yum localinstall -y rpm/*.rpm
#  rpm -ivh --nodeps rpm/*.rpm
  /usr/pgsql-${PG_VERSION}/bin/postgresql-${PG_VERSION}-setup initdb
  systemctl start postgresql-${PG_VERSION}    # 启动服务
  systemctl enable postgresql-${PG_VERSION}   # 设置服务开机自启动

  echo "配置主服务器 ${MASTER_IP} ..."

  sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'postgres';"

  # 创建同步复制用户
  sudo -u postgres psql -c "CREATE ROLE $REPLICATION_USER LOGIN REPLICATION ENCRYPTED PASSWORD '$REPLICATION_PASSWORD';"

  # 允许同步复制
  echo "host    all            all        ${VPC_IP}    md5" >> ${PG_DATA_DIR}/pg_hba.conf   # 相同网段可以密码连接
  echo "host    replication    replica    ${SLAVE_IP}/32    md5" >> ${PG_DATA_DIR}/pg_hba.conf

  # 配置 PostgreSQL 参数
  for param in "${CONFIGURE_PARAMS[@]}"; do
    echo "$param" >> ${PG_DATA_DIR}/postgresql.conf
  done

  systemctl restart postgresql-${PG_VERSION}
}

# 配置从服务器
configure_slave() {
  echo "安装 PostgreSQL ..."
#  rpm -ivh --nodeps rpm/*.rpm

  echo "配置从服务器 ${SLAVE_IP} ..."

  # 清理从服务器的数据目录
  sudo rm -rf ${PG_DATA_DIR}/*

  # 使用 pg_basebackup 从主服务器同步数据
  sudo -u postgres pg_basebackup -h ${MASTER_IP} -D ${PG_DATA_DIR} -U $REPLICATION_USER -X stream -P

  echo "standby_mode = 'on'" | sudo tee ${PG_DATA_DIR}/standby.signal  # （pg版本11后已经废除recovery.conf）

  echo "primary_conninfo = 'host=${MASTER_IP} port=5432 user=$REPLICATION_USER password=$REPLICATION_PASSWORD'" | sudo tee -a ${PG_DATA_DIR}/postgresql.conf
  echo "recovery_target_timeline = 'latest'" | sudo tee -a ${PG_DATA_DIR}/postgresql.conf
  echo "max_standby_streaming_delay = 30s" | sudo tee -a ${PG_DATA_DIR}/postgresql.conf
  echo "wal_receiver_status_interval = 10s" | sudo tee -a ${PG_DATA_DIR}/postgresql.conf
  echo "max_connections = 1000" | sudo tee -a ${PG_DATA_DIR}/postgresql.conf
  echo "hot_standby = on" | sudo tee -a ${PG_DATA_DIR}/postgresql.conf
  echo "hot_standby_feedback = on" | sudo tee -a ${PG_DATA_DIR}/postgresql.conf

  sudo chown -R postgres.postgres ${PG_DATA_DIR}

  # 启动从服务器
  sudo systemctl enable postgresql-${PG_VERSION}
  sudo systemctl start postgresql-${PG_VERSION}
}

check_replication() {
  # 在主服务器上检查复制状态
  echo "主服务器复制状态：SELECT * FROM pg_stat_replication"
  sudo -u postgres psql -h ${MASTER_IP} -c "SELECT * FROM pg_stat_replication;"
}


main() {
  if [ "${machine_ip}" == "${MASTER_IP}" ]; then
    configure_master
  else
    configure_slave
  fi

  check_replication
}

main

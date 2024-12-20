#!/bin/sh
WORKDIR=$(cd `dirname $0`;pwd)      #脚本所在路径
echo "脚本所在路径${WORKDIR}"

# 设置主从服务器的 IP 地址
MASTER_IP="172.16.130.39"
SLAVE_IP="172.16.130.40"

# 设置 PostgreSQL 版本和数据库数据目录
PG_VERSION="13"  # 使用 PostgreSQL 12
PG_DATA_DIR="/var/lib/pgsql/data"
REPLICATION_USER="replica"
REPLICATION_PASSWORD="replica"



master_pgsql(){
  rpm -ivh *.rpm
  /usr/pgsql-${PG_VERSION}/bin/postgresql-${PG_VERSION}-setup initdb

  systemctl start postgresql-${PG_VERSION}    #启动服务
  systemctl enable postgresql-${PG_VERSION}   #设置服务开机自启动

  # 修改postgres密码
  psql -U postgres -c "ALTER USER postgres WITH PASSWORD postgres;"

  # 创建同步复制用户
  psql -U postgres -c "CREATE ROLE replica login replication encrypted password 'replica';"

  # 允许同步复制
  echo "host    all            all        ${}/32    md5" >>  /var/lib/pgsql/11/data/pg_hba.conf
  echo "host    replication    replica    ${}/32    md5" >> /var/lib/pgsql/11/data/pg_hba.conf

  echo "listen_addresses = '*'" >> /var/lib/pgsql/11/data/postgresql.conf
  echo "wal_level = hot_standby" >> /var/lib/pgsql/11/data/postgresql.conf
  echo "synchronous_commit = on" >> /var/lib/pgsql/11/data/postgresql.conf
  echo "max_wal_senders = 32" >> /var/lib/pgsql/11/data/postgresql.conf
  echo "wal_sender_timeout = 60s" >> /var/lib/pgsql/11/data/postgresql.conf

  systemctl restart postgresql-11.service

}


# 配置主服务器
configure_master() {
  echo "配置主服务器 ${MASTER_IP} ..."

  # 修改 postgresql.conf 配置文件
  sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" ${PG_DATA_DIR}/postgresql.conf
  sudo sed -i "s/#wal_level = minimal/wal_level = replica/g" ${PG_DATA_DIR}/postgresql.conf
  sudo sed -i "s/#max_wal_senders = 0/max_wal_senders = 3/g" ${PG_DATA_DIR}/postgresql.conf
  sudo sed -i "s/#hot_standby = off/hot_standby = on/g" ${PG_DATA_DIR}/postgresql.conf

  # 配置 pg_hba.conf 文件，允许复制连接
  echo "host replication $REPLICATION_USER $SLAVE_IP/32 md5" | sudo tee -a ${PG_DATA_DIR}/pg_hba.conf

  # 创建复制用户
  sudo -u postgres psql -c "CREATE USER $REPLICATION_USER WITH REPLICATION ENCRYPTED PASSWORD '$REPLICATION_PASSWORD';"

  # 重启 PostgreSQL 服务
  sudo systemctl restart postgresql
}



standby_pgsql(){


}

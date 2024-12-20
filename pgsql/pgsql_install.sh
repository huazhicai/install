#!/bin/sh
WORKDIR=$(cd `dirname $0`;pwd)      #脚本所在路径
echo "脚本所在路径${WORKDIR}"

# 设置主从服务器的 IP 地址
MASTER_IP="172.16.130.39"
SLAVE_IP="172.16.130.40"

# 设置 PostgreSQL 版本和数据库数据目录
PG_VERSION="12"  # 使用 PostgreSQL 12
PG_DATA_DIR="/var/lib/pgsql/data"
REPLICATION_USER="replication"
REPLICATION_PASSWORD="replication_password"



master_pgsql(){
  rpm -ivh pgdg-redhat-repo-latest.noarch.rpm
  yum install postgresql11-server postgresql11-contrib -y
  /usr/pgsql-11/bin/postgresql-11-setup initdb

  systemctl start postgresql-11.service    #启动服务
  systemctl enable postgresql-11.service   #设置服务开机自启动

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


standby_pgsql(){


}

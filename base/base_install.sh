#!/bin/sh
WORKDIR=$(cd `dirname $0`;pwd)      #脚本所在路径
echo "脚本所在路径${WORKDIR}"
YUM_PATH=$WORKDIR/../package/base
PROFILE_PATH=${WORKDIR}/profile
USERS=$(grep 'USERS' ${PROFILE_PATH}|awk -F'=' '{print $2}')
INIT_USERS=(${USERS//,/ })
echo ${INIT_USERS[*]}

init_env() {
  echo "###########################设置系统环境"
  ulimit -n 65535
  sh ${WORKDIR}/../add_to_file.sh "* soft nofile 65535" "/etc/security/limits.conf"
  sh ${WORKDIR}/../add_to_file.sh "* hard nofile 65535" "/etc/security/limits.conf"
  sh ${WORKDIR}/../add_to_file.sh "aiit-zhyl    soft    nproc    65535" "/etc/security/limits.d/20-nproc.conf"
  timedatectl set-timezone "Asia/Shanghai"  

  sh ${WORKDIR}/../add_to_file.sh "x /tmp/blockmgr-*" "/usr/lib/tmpfiles.d/tmp.conf"
  sh ${WORKDIR}/../add_to_file.sh "x /tmp/spark-*" "/usr/lib/tmpfiles.d/tmp.conf"

}

#安装装机所需依赖
install_dependency(){
echo "###########################开始安装依赖软件"
rpm -Uevh --force --nodeps ${YUM_PATH}/*.rpm
}

install_python(){
  echo "###########################安装python"
  cd ${WORKDIR}/.. && tar -xzf Python-3.8.5.tgz &&./Python-3.8.5/configure --enable-optimizations && make altinstall
  ln -s /usr/local/bin/python3.8 /usr/local/bin/python3
  echo "###########################安装pip"
  cd pip_package && python3 -m pip install pip-20.2.4-py2.py3-none-any.whl && python3 -m pip install --no-index --find-links=. -r requirements.txt

}

#初始化用户
init_user(){

  echo "重置root密码"
  echo 'zhyl!@#123' | passwd root --stdin
  echo "###########################创建用户${INIT_USERS[*]}"
  for((i=0;i<${#INIT_USERS[*]};i++))
  do
    user=${INIT_USERS[i]}
    name_pwd=(${user//:/ })
    useradd ${name_pwd[0]}
    echo ${name_pwd[1]} | passwd ${name_pwd[0]} --stdin > /dev/null 2>&1
  done
}

#打开deploy使用systemd模式的系统设置
enable_systemd_deploy() {
  echo "###########################添加sudoer systemctl"
  sh ${WORKDIR}/../add_to_file.sh "aiit-zhyl ALL=(ALL) NOPASSWD: /usr/bin/systemctl *" "/etc/sudoers"

  echo "###########################更改systemd 配置目录权限"
  chmod 777 /usr/lib/systemd/system

  echo "###########################配置syslog输出到文件"
  cat>/etc/rsyslog.d/aiit_deploy.conf<<EOF
\$FileGroup aiit-zhyl
\$FileOwner aiit-zhyl
\$DirOwner aiit-zhyl
\$DirGroup aiit-zhyl
\$FileCreateMode 777
\$DirCreateMode 777


\$template aiit-deploy-logs,"/tmp/deploy_logs/%PROGRAMNAME%", 300000

if \$programname contains 'aiit_zhyl' then -?aiit-deploy-logs
& stop
EOF

  echo "重启syslog"
  systemctl restart rsyslog

  echo "start deploy crotab for logs delete"
   if [[ ! -e /var/spool/cron/ ]];then
    mkdir -p /var/spool/cron/
  fi
  sh ${WORKDIR}/../add_to_file.sh "0 2 1 * * /usr/bin/rm -rf /tmp/deploy_logs && systemctl restart rsyslog" "/var/spool/cron/root"
}



init_env && install_dependency  && init_user && enable_systemd_deploy

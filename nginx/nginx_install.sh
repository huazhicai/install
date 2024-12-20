#!/bin/sh
WORKDIR=$(cd `dirname $0`;pwd)      #脚本所在路径
echo "脚本所在路径${WORKDIR}"
PROFILE_PATH=${WORKDIR}/profile
USERS=$(grep 'USERS' ${PROFILE_PATH}|awk -F'=' '{print $2}')
INIT_USERS=(${USERS//,/ })
echo ${INIT_USERS[*]}



install_nginx(){
  echo "###########################添加sudoer nginx"
  sh ${WORKDIR}/../add_to_file.sh "aiit-zhyl ALL=(ALL) NOPASSWD: /usr/sbin/nginx *" "/etc/sudoers"

  echo "###########################nginx 配置覆盖"
  cp -rf ${WORKDIR}/nginx.conf /etc/nginx/nginx.conf

  echo "###########################创建nginx 配置目录"
  mkdir /etc/nginx/upstreams
  mkdir /etc/nginx/domains

  sed -i "s#SELINUX=enforcing#SELINUX=disabled#g" /etc/selinux/config

  setenforce 0

  echo "###########################更改nginx 配置目录权限"
  chmod -R 777 /etc/nginx

  echo "###########################重启nginx"
  systemctl restart nginx

}

install_nginx

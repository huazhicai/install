#!/bin/bash
WORKDIR=$(cd $(dirname $0);pwd)
cd ${WORKDIR}
echo "脚本所在路径${WORKDIR}"


SERVER_IP=$(grep 'server_ip' profile|awk -F'=' '{print $2}')
LOCAL_IP=$(ip addr | grep 'inet' | grep -v 'inet6\|127.0.0.1' | grep -v grep | awk -F '/' '{print $1}' | awk '{print $2}')

rpm -ivh --nodeps ${WORKDIR}/rpm/*.rpm


install_server() {
  echo "------------安装server ${LOCAL_IP} ------------"
  firewall-cmd --state
  firewall_state=$(echo $?)
  if [[ $firewall_state -eq 0 ]]; then
    firewall-cmd --permanent --zone=public --add-port=123/udp
    firewall-cmd --reload
  fi

  timedatectl set-timezone Asia/Shanghai
  systemctl enable ntpd
  systemctl start ntpd
  # restrict 10.80.131.0 mask 255.255.255.0 nomodify notrap
  sed -i '/^restrict default nomodify/c restrict default nomodify' /etc/ntp.conf
  sed -i '/^server 0.centos.pool.ntp.org iburst/c server 127.127.1.0\nfudge   127.127.1.0 stratum 10' /etc/ntp.conf
  sed -i '/^server 1.centos.pool.ntp.org iburst/c server ntp.aliyun.com iburst' /etc/ntp.conf
  sed -i '/centos.pool.ntp.org iburst/d' /etc/ntp.conf

  systemctl restart ntpd
  systemctl status ntpd
}

install_client() {
  echo "==============安装节点 ${LOCAL_IP} ==========="
  sed -i 's/server/#&/g' /etc/ntp.conf
  sed -i "/server 0.centos.pool.ntp.org/c server ${SERVER_IP} iburst" /etc/ntp.conf
  #允许时间服务器(上游时间服务器)修改本机时间
#  sed "a\restrict ${SERVER_IP} mask 255.255.255.0 nomodify notrap" /etc/ntp.conf
  systemctl start ntpd
  systemctl enable ntpd
  systemctl status ntpd
  ntpq -p
}

install_ntp() {
  if [ ${SERVER_IP} == ${LOCAL_IP} ]; then
    install_server
  else
    install_client
  fi
  timedatectl set-ntp yes  # 开启时间同步
}

install_ntp
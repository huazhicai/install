#!/bin/sh
WORKDIR=$(cd `dirname $0`;pwd)      #脚本所在路径
echo "脚本所在路径${WORKDIR}"

RPM_PATH=${WORKDIR}/yum
PORT=$1
PROFILE_PATH=${WORKDIR}/profile

echo "############本服务器将部署PORT:${PORT}Mongo节点......"
enable_authorization=$(grep 'enable_authorization' ${PROFILE_PATH}|awk -F'=' '{print $2}')

selinux_mode=$(grep '^SELINUX=' /etc/selinux/config |awk -F'=' '{print $2}')
if [[ ${selinux_mode} != "permissive" ]];then
   setenforce 0
   sed -i '/^SELINUX=/c SELINUX=permissive' /etc/selinux/config
   echo "selinux 设置permissive或者disable 成功"
fi

echo "############安装mongo节点......"
rpm -Uvh --force --nodeps ${RPM_PATH}/*.rpm
echo "======建立数据存放路径"
sh ${WORKDIR}/../mk_secure_dir.sh mongod /var/lib/mongo/${PORT}

echo "############添加主副本集秘钥......"
cp -rf ${WORKDIR}/mongo.keyfile /etc
chown -R mongod /etc/mongo.keyfile
chmod 400 /etc/mongo.keyfile

echo "======配置mongo参数......"
rename mongod.service mongod${PORT}.service /usr/lib/systemd/system/mongod.service
rename mongod.conf mongod${PORT}.conf /etc/mongod.conf
sed -i "s#\dbPath.*#dbPath: /var/lib/mongo/${PORT}#" /etc/mongod${PORT}.conf
sed -i "s#\  bindIp.*#  bindIp: 0.0.0.0#" /etc/mongod${PORT}.conf
sed -i "s#\port.*#port: ${PORT}#" /etc/mongod${PORT}.conf
sed -i "s#\pidFilePath.*#pidFilePath: /var/run/mongodb/mongod${PORT}.pid#" /etc/mongod${PORT}.conf
sed -i "/systemLog:/a\  logRotate: reopen" /etc/mongod${PORT}.conf
sed -i '$a\security:' /etc/mongod${PORT}.conf
sed -i '$a\  keyFile: /etc/mongo.keyfile' /etc/mongod${PORT}.conf

sed -i "s#\mongod.conf#mongod${PORT}.conf#" /usr/lib/systemd/system/mongod${PORT}.service
sed -i "s#\PIDFile.*#PIDFile=/var/run/mongodb/mongod${PORT}.pid#" /usr/lib/systemd/system/mongod${PORT}.service

echo "############添加mongo日志分割logrotate......"
cat>/etc/logrotate.d/mongodb<<EOF
/var/log/mongodb/mongod.log{
        daily
        rotate 30
        compress
        copytruncate
        delaycompress
        notifempty
        dateext
        missingok
        postrotate
        /bin/kill -SIGUSR1 `cat /var/lib/mongo/mongod.lock 2> /dev/null` 2> /dev/null || true
        endscript
}
EOF



echo "1)重新加载服务配置文件"
systemctl daemon-reload
echo "2）启动服务"
systemctl start mongod${PORT}
echo "3）设置开机自启动"
systemctl enable mongod${PORT}

if [[ ${enable_authorization} && ${enable_authorization} -eq 1 ]];then
    cat>/etc/mongo_user_create.js<<EOF
db.createUser(
{
  user:"root",
  pwd:"AdminPwd4Zhyl",
  roles:["root"]
 }
);
db.auth("root", "AdminPwd4Zhyl");
db.createUser(
 {
  user:"aiit-zhyl",
  pwd:"zhyL^123456",
  roles:["readWriteAnyDatabase", "clusterMonitor", "restore", "backup"]
 }
);
EOF
    mongo --port ${PORT} admin /etc/mongo_user_create.js
    sed -ri "s#authorization\: disabled#authorization\: enabled#" /etc/mongod${PORT}.conf
    sed -i '$a\replication:' /etc/mongod${PORT}.conf
    sed -i '$a\  replSetName: aiit-zhyl' /etc/mongod${PORT}.conf

    echo "开启鉴权-重新加载服务配置文件"
    systemctl daemon-reload
    echo "开启鉴权-重启服务"
    systemctl restart mongod${PORT}
 fi

echo "4）查看服务状态"
systemctl status mongod${PORT}
netstat -atnp | grep ${PORT} &> /dev/null
if [[ $? -eq 0 ]];then
	echo "${PORT}实例开启成功"
else
	echo "致命错误"
	exit 1
fi
#!/bin/bash
WORKDIR=$(cd `dirname $0`;pwd)
echo "脚本所在路径${WORKDIR}"


# 开放端口 or 关闭防火墙
#systemctl stop firewalld
#systemctl disable firewalld

# 配置 SELINUX=disabled
sed -i '/^SELINUX=/c SELINUX=disabled' /etc/selinux/config

# 配置/etc/hosts; 添加每台机器的ip 和别名
cat>/etc/hosts<<EOF
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
172.16.130.34 mdw
172.16.130.39 sdw1
172.16.130.40 sdw2
EOF

# 配置sysctl.conf
cat>/etc/sysctl.conf<<EOF
kernel.shmall = $(expr $(getconf _PHYS_PAGES) / 2)    # See Shared Memory Pages
kernel.shmmax = $(expr $(getconf _PHYS_PAGES) / 2 \* $(getconf PAGE_SIZE))
kernel.shmmni = 4096
vm.overcommit_memory = 2  # See Segment Host Memory
vm.overcommit_ratio = 95  # See Segment Host Memory

net.ipv4.ip_local_port_range = 10000 65535   # See Port Settings
kernel.sem = 250 2048000 200 8192
kernel.sysrq = 1
kernel.core_uses_pid = 1
kernel.msgmnb = 65536
kernel.msgmax = 65536
kernel.msgmni = 2048
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.conf.all.arp_filter = 1
net.core.netdev_max_backlog = 10000
net.core.rmem_max = 2097152
net.core.wmem_max = 2097152
vm.swappiness = 10
vm.zone_reclaim_mode = 0
vm.dirty_expire_centisecs = 500
vm.dirty_writeback_centisecs = 100
vm.dirty_background_ratio = 3
vm.dirty_ratio = 10
EOF
awk 'BEGIN {OFMT = "%.0f";} /MemTotal/ {print "vm.min_free_kbytes =", $2 * .03;}' /proc/meminfo >> /etc/sysctl.conf
sysctl -p

# 系统资源限制
cat>/etc/security/limits.conf<<EOF
* soft nofile 524288
* hard nofile 524288
* soft nproc 131072
* hard nproc 131072
EOF
sed -i '/\*/c \*          soft    nproc     131072' /etc/security/limits.d/20-nproc.conf

# XFS挂载选项
#sed -i '/\/data/c \/dev\/vdb \/data xfs nodev,noatime,inode64 0 0' /etc/fstab

# 磁盘I/O 设置
echo "/sbin/blockdev --setra 16384 /dev/vdb" >> /etc/rc.d/rc.local
chmod +x /etc/rc.d/rc.local  # 必须在启动时可以运行 rc.local文件

# 磁盘I/O调度算法
grubby --update-kernel=ALL --args="elevator=deadline"
grubby --update-kernel=ALL --args="transparent_hugepage=never"  # Transparent Huge Pages 禁用THP，因为它会降低Greenplum数据库的性能
source /etc/locale.conf  # 英文字符集

#创建gpadmin用户
groupadd gpadmin
useradd gpadmin -r -m -g gpadmin
echo 'gpadmin' | passwd gpadmin --stdin > /dev/null 2>&1
usermod -aG wheel gpadmin  # 将用户添加到wheel用户组里，因为wheel用户组拥有sudo的权限
# 添加sudo权限
#sed -i '/^# %wheel/c %wheel  ALL=(ALL)       NOPASSWD: ALL' /etc/sudoers && cat /etc/sudoers


rpm -ivh --nodeps *.rpm

echo
echo "\033[33m####################检查${HOSTNAME}配置####################\033[0m”"
systemctl status firewalld
cat /etc/hosts
cat /etc/selinux/config
cat /etc/security/limits.d/20-nproc.conf
cat /etc/fstab
cat /etc/rc.d/rc.local
cat /etc/sysctl.conf
cat /etc/security/limits.conf
grubby --info=ALL
echo $LANG
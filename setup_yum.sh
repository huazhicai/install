#!/bin/sh

mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup


# 阿里云镜像源
curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo

# 腾讯云镜像源
# curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.cloud.tencent.com/repo/Centos-7.repo

yum clean all
yum makecache
yum install -y gcc make openssl-devel bzip2-devel libffi-devel zlib-devel sqlite-devel
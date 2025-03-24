#!/bin/sh
WORKDIR=$(cd "$(dirname "$0")" && pwd)  # 更安全的路径获取方式
echo "脚本所在路径: ${WORKDIR}"

install_python_deps() {
  echo "########################### 安装编译依赖"
  yum install -y gcc make openssl-devel bzip2-devel libffi-devel zlib-devel sqlite-devel
  [ $? -ne 0 ] && echo "安装依赖失败！" && exit 1
}

install_python() {
  echo "########################### 安装 Python"
  # 检查源码包存在性
  if [ ! -f "${WORKDIR}/Python-3.8.5.tgz" ]; then
    echo "错误: Python-3.8.5.tgz 不存在！"
    exit 1
  fi

  # 解压并检查目录
  tar -xzf "${WORKDIR}/Python-3.8.5.tgz" -C "${WORKDIR}" || exit 1
  cd "${WORKDIR}/Python-3.8.5" || { echo "进入目录失败"; exit 1; }

  # 编译安装
  ./configure --enable-optimizations --enable-loadable-sqlite-extensions
  make clean
  make -j$(nproc)     # 并行编译加速
  sudo make altinstall # 需要 root 权限

  # 创建软链接（使用绝对路径更安全）
  sudo ln -sf /usr/local/bin/python3.8 /usr/local/bin/python3
  sudo ln -sf /usr/local/bin/pip3.8 /usr/local/bin/pip3

  # 验证安装
  if ! /usr/local/bin/python3 --version; then
    echo "Python 安装失败！"
    exit 1
  fi
}

install_pip_packages() {
  echo "########################### 安装 PIP 包"
  cd "${WORKDIR}" || exit 1
  /usr/local/bin/pip3 install --no-index --find-links=./pip_package -r requirements.txt
}

# 主流程
# install_python_deps
install_python
install_pip_packages

echo "安装完成！"
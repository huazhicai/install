#!/bin/sh
WORKDIR=$(cd "$(dirname "$0")" && pwd) # 更安全的路径获取方式
echo "脚本所在路径: ${WORKDIR}"

VERSION='3.8.5'

install_python_deps() {
  echo "########################### 安装编译依赖"
  yum install -y gcc make openssl-devel bzip2-devel libffi-devel zlib-devel sqlite-devel
  [ $? -ne 0 ] && echo "安装依赖失败！" && exit 1
}

install_python() {
  echo "########################### 安装 Python"

  # 解压并检查目录
  tar -xzf "${WORKDIR}/Python-${VERSION}.tgz" -C "${WORKDIR}" || exit 1
  cd "${WORKDIR}/Python-${VERSION}" || {
    echo "进入目录失败"
    exit 1
  }

  # 编译安装
  ./configure --enable-optimizations --enable-loadable-sqlite-extensions
  make clean
  make -j$(nproc) || { echo "编译失败"; exit 1; }
  make altinstall || { echo "安装失败"; exit 1; }

  # 创建软链接（使用绝对路径更安全）
  sudo ln -sf /usr/local/bin/python3.8 /usr/local/bin/python3
  sudo ln -sf /usr/local/bin/pip3.8 /usr/local/bin/pip3

  # 验证安装
  if ! /usr/local/bin/python3 --version; then
    echo "Python 安装失败！"
    exit 1
  fi
}

copy_pyenv() {
  local pyenv_tar_gz="${WORKDIR}/pyenv.tar.gz"
  local target_dir="/home/aiit-zhyl"

  if [ -f "${pyenv_tar_gz}" ]; then
    tar -zxvf "${pyenv_tar_gz}" -C "${target_dir}" || exit 1

    # 配置环境变量
    echo "export PYENV_ROOT=\"\$HOME/.pyenv\"" >>"${target_dir}/.bashrc"
    echo "export PATH=\"\$PYENV_ROOT/bin:\$PATH\"" >>"${target_dir}/.bashrc"
    echo "eval \"\$(pyenv init -)\"" >>"${target_dir}/.bashrc"
    echo "eval \"\$(pyenv virtualenv-init -)\"" >>"${target_dir}/.bashrc"

    # 更改文件所有者
    chown -R aiit-zhyl:aiit-zhyl "${target_dir}"
  else
    echo "no copy pyenv"
  fi
}

install_pip_packages() {
  echo "########################### 安装 PIP 包"
  cd "${WORKDIR}" || exit 1

  # 检查网络连接
  if curl --silent --head --fail https://pypi.org/simple >/dev/null; then
    echo "网络连接正常，使用网络安装 PIP 包"
    /usr/local/bin/pip3 install -r requirements.txt
  else
    echo "网络连接不可用，使用离线安装 PIP 包"
    if [ -d "./pip_package" ]; then
      /usr/local/bin/pip3 install --no-index --find-links=./pip_package -r requirements.txt
    else
      echo "错误：目录 ./pip_package 不存在，无法进行离线安装"
    fi
  fi
}

# 主流程
# install_python_deps
install_python
copy_pyenv
install_pip_packages

echo "安装完成！"

#!/bin/sh

if [[ $# -lt 2 ]];then
  echo " mkdir need username and at least one dirname "
  exit 1
fi

WORKDIR=$(cd `dirname $0`;pwd)   #脚本所在路径

PROFILE_PATH="${WORKDIR}/profile"

source ${PROFILE_PATH}

user=$1

if [[ "${user}" = "" ]];then
  user=${USER}
fi

echo " mkdir for user "${user}

for i in ${@:2}
do
  abs_dir=$i
  if [ "${i:0:1}" != "/"  -a  "${i:0:1}" != "~" ]; then
    abs_dir=$(readlink -f .)/$i
  fi

  echo "mkdir "${abs_dir}
  mkdir -p ${abs_dir}
  chown -R ${user} ${abs_dir}
  if [[ ${ENCRYPT} -eq 1 ]];then
    mkdir -p ${abs_dir}".enc"
    chown -R ${user} ${abs_dir}".enc"
    echo -e "\nzhyl123456\nzhyl123456\n" | sudo -u ${user} encfs -S "${abs_dir}.enc" ${abs_dir}
  fi
done






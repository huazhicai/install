#!/bin/bash
set -e
WORKDIR=$(cd `dirname $0`;pwd)      #脚本所在路径

usage(){
  cat <<EOF
Usage:
    sh install [-a] [--all] [--b] [--base] [--p] [--python] [-m] [--mongo] [-i] [--minio] [-e] [--elasticsearch] [-s] [--spark] [-h] [--help] [-n] [--nginx] [-q] [--rabbitmq] [-g] [--greenplum] [-f] [--filebeat] [-t] [--ntp] [-k] [--kafka] [-z] [--zookeeper] [-d] [--docker] [-v] [--v2ray]
    -a|--all 基本环境、mongo、minio、elasticsearch、spark一键安装
    -b|--base  基本环境安装, 安装所需依赖
    -p|--python python安装
    -m|--mongo 安装mongo
    -i|--minio 安装文件存储系统
    -e|--elasticsearch 安装elasticsearch
    -s|--spark 安装spark
    -n|--nginx nginx配置
    -r|--redis redis安装
    -q|--pgsql pgsql安装
    -g|--greenplum greenplum安装
    -f|--filebeat filebeat安装
    -t|--ntp ntp安装
    -k|--kafka kafka安装
    -z|--zookeeper zookeeper安装
    -d|--docker docker安装
    -v|--v2ray v2ray安装
    -h|--help 帮助文档
EOF
    exit 1
}
COMMAND=()
ARGS=`getopt -a -o abmiesnhprqgtkzfdv -l all,base,mongo,minio,elasticsearch,spark,nginx,help,python,redis,pgsql,greenplum,ntp,kafka,zookeeper,filebeat,docker,v2ray -- "$@"`
[[ $? -ne 0 ]] && usage
#set -- "${ARGS}"
eval set -- "${ARGS}"
while true
do
        case "$1" in
        -a|--all)
                COMMAND[${#COMMAND[*]}]="all"
                ;;
        -b|--base)
                COMMAND[${#COMMAND[*]}]="base"
                ;;
        -p|--python)
                COMMAND[${#COMMAND[*]}]="python"
                ;;
        -m|--mongo)
                COMMAND[${#COMMAND[*]}]="mongo"
                ;;
        -i|--minio)
                COMMAND[${#COMMAND[*]}]="minio"
                ;;
        -e|--elasticsearch)
                COMMAND[${#COMMAND[*]}]="es"
                ;;
        -s|--spark)
                COMMAND[${#COMMAND[*]}]="spark"
                ;;
        -n|--nginx)
                COMMAND[${#COMMAND[*]}]="nginx"
                ;;
        -r|--redis)
                COMMAND[${#COMMAND[*]}]="redis"
                ;;
        -q|--pgsql)
                COMMAND[${#COMMAND[*]}]="pgsql"
                ;;
        -g|--greenplum)
                COMMAND[${#COMMAND[*]}]="greenplum"
                ;;
        -f|--filebeat)
                COMMAND[${#COMMAND[*]}]="filebeat"
                ;;
        -t|--ntp)
                COMMAND[${#COMMAND[*]}]="ntp"
                ;;
        -k|--kafka)
                COMMAND[${#COMMAND[*]}]="kafka"
                ;;
        -z|--zookeeper)
                COMMAND[${#COMMAND[*]}]="zookeeper"
                ;;
        -d|--docker)
                COMMAND[${#COMMAND[*]}]="docker"
                ;;
        -v|--v2ray)
                COMMAND[${#COMMAND[*]}]="v2ray"
                ;;
        -h|--help)
                usage;exit 0
                ;;
        --)
                shift
                break
                ;;
        *)
                echo -e "\033[31mERROR: unknown argument! \033[0m\n" && usage && exit 1
                ;;
        esac
shift
done

################################根据参数处理############################
HAS_ALL=false
for((i=0;i<${#COMMAND[*]};i++))
do
  if [[ ${COMMAND[i]} == "all" ]] ;then
    HAS_ALL=true
  fi
done
if [[ ${HAS_ALL} ==  true ]] ;then
  COMMAND=("base" "mongo" "minio" "es" "python" "nginx" "redis" "pgsql" "greenplum" "ntp" "kafka" "zookeeper" "filebeat" "v2ray")
fi

for((ii=0;ii<${#COMMAND[*]};ii++))
do
  DEPLOY_PATH="${WORKDIR}/${COMMAND[ii]}/${COMMAND[ii]}_deploy.sh"
  source ${DEPLOY_PATH}
  echo "################################开始校验${COMMAND[ii]}"
  ${COMMAND[ii]}_check
done
for((ij=0;ij<${#COMMAND[*]};ij++))
do
  echo "################################开始deploy${COMMAND[ij]}"
 ${COMMAND[ij]}_deploy
done
echo "################################${COMMAND[*]}安装成功"
set +e

#!/bin/bash
#set -x
#set -e

WORKING_DIR=$(cd `dirname $0` && pwd)
pushd $WORKING_DIR &>/dev/null
# default configuration:
LOCALHOST_IP=$(ip route get 8.8.4.4 | head -1 | awk '{print $7}')
DATA_DIR=/var/lib
IS_CHECK=yes
IS_MONITOR=no

# check requirements:
DATA_DISK_G=30
SYS_DISK_G=20
SYS_MEM_G=4
SYS_CPU=2

while [ "$1" != "" ]; do
  case $1 in
    --dir)
    DATA_DIR=$2
    shift 2
    ;;
    --ip)
    LOCALHOST_IP=$2
    shift 2
    ;;
    --check)
    IS_CHECK=$2
    shift 2
    ;;
    --monitor)
    IS_MONITOR=$2
    shift 2
    ;;
    *)
    echo "[ERROR] invalid argument '$1'"
    usage
    exit 1
  esac
done

if [ $IS_CHECK == 'yes' ]; then
  echo "============================== Begin of check environment =============================="
  check_result=''
  if [[ -d $DATA_DIR ]]; then
    df -h $DATA_DIR
    data_disk=$(df $DATA_DIR | tail -n1 | awk '{print $4}')
    if [[ $data_disk -lt $DATA_DISK_G*1000000 ]]; then
      check_result="${check_result}\n[ERROR] It is recommended that data disk at least $DATA_DISK_G G."
    fi
  else
    check_result="${check_result}\n[WARNING] $DATA_DIR directory does not exist."
  fi
  echo

  df -h /
  system_disk=$(df / | tail -n1 | awk '{print $4}')
  if [[ $system_disk -lt $SYS_DISK_G*1000000 ]]; then
    check_result="${check_result}\n[ERROR] It is recommended that system disk at least $SYS_DISK_G G."
  fi
  echo

  free -h
  system_mem=$(free | grep Mem | awk '{print $2}')
  if [[ $system_mem -lt $SYS_MEM_G*1000000 ]]; then
    check_result="${check_result}\n[ERROR] It is recommended that memory at least $SYS_MEM_G G."
  fi
  echo

  cat /proc/cpuinfo | grep processor
  system_cpu=$(cat /proc/cpuinfo | grep processor | wc -l)
  if [[ $system_cpu -lt $SYS_CPU ]]; then
    check_result="${check_result}\n[ERROR] It is recommended that cpu at least $SYS_CPU."
  fi
  echo

  if [[ -z ${check_result} ]]; then
    echo "[INFO] Environment check passed."
  else
    echo -e ${check_result}
  fi
  echo "============================== End of check environment  =============================="
  exit 1
fi

echo "============================== Begin of deploy k8s =============================="
chmod a+x docker/*.sh kubernetes/*.sh prometheus/*.sh

if docker version 2>/dev/null; then
  echo "[WARNING] Docker has been deployed, skip installation."
  echo
else
  ./docker/deploy_docker.sh $DATA_DIR/docker
  if [ $? -ne 0 ]; then exit 1; fi
fi

if kubectl get nodes 2>/dev/null; then
  echo "[WARNING] kubernetes has been deployed, skip installation."
  echo
else
  ./kubernetes/deploy_k8s.sh $LOCALHOST_IP
  if [ $? -ne 0 ]; then exit 1; fi
fi

if [ $IS_MONITOR == 'no' ]; then
  echo "[INFO] Default prometheus monitoring system is not installed."
else
  ./prometheus/deploy.sh
fi

echo "============================== End of deploy k8s =============================="
popd &>/dev/null

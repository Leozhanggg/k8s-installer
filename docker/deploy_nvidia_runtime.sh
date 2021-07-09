#!/bin/bash
#set -x
#set -e

WORKING_DIR=$(cd `dirname $0` && pwd)
pushd $WORKING_DIR &>/dev/null
if [ "$UID" -ne 0 ]; then
   echo "[ERROR]: require root user"
   exit 1
fi

check_nvidia_driver() {
  nvidia-smi
  if [ $? -eq 0 ]; then
    NIVDIA_INFO=`lspci | grep -i nvidia`
    echo "NIVDIA: $NIVDIA_INFO"
  else
    nouveau.modeset=0 2>/dev/null
    service gdm stop 2>/dev/null
    echo "NVIDIA driver is not found: bash NVIDIA-Linux-x86_64-460.80.run
    For details: https://xuelangyun.yuque.com/suanpan_doc/zek5ps/igg9ms"
    #exit 1
  fi
  echo
}

deploy_nvidia_runtime() {
  echo "yum localinstall nvidia-runtime-pkgs..."
  if [ -d rpms ]; then
    cd gpu && yum -y -e 0 localinstall *.rpm && cd $WORKING_DIR
  else
    distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
    curl -s -L https://nvidia.github.io/nvidia-container-runtime/$distribution/nvidia-container-runtime.repo |\
    tee /etc/yum.repos.d/nvidia-container-runtime.repo
    yum install nvidia-container-runtime
    yum -y install gcc kernel-devel kernel-devel-uname-r==$(uname -r) dkms
  fi
  echo
}

config_docker_runtime() {
  echo "config docker runtime"
  if [ ! -f "/etc/docker/daemon.json" ]
  then
    DATA_ROOT="/var/lib/docker"
    mkdir -p /etc/docker/
  else
    DATA_INFO=$(cat /etc/docker/daemon.json | grep data-root)
    DATA_ROOT=${DATA_INFO#*:}
  fi

  sed "s#{{.data-root}}#$DATA_ROOT#g" $WORKING_DIR/config/daemon-gpu.json.tpl >$WORKING_DIR/config/daemon.json
  \cp $WORKING_DIR/config/daemon.json /etc/docker/
  systemctl daemon-reload && systemctl restart docker
  DF_RUNTIME=$(docker info | grep "Default Runtime:")
  if [[ ${DF_RUNTIME#*:} != ' nvidia' ]]
  then
    echo "$DF_RUNTIME, not nvidia."
    #exit 1
  fi
  echo
}

check_gpu_running() {
  docker load -i $WORKING_DIR/gpu/ubuntu-latest
  docker run -it --rm --gpus all ubuntu nvidia-smi
  if [ $? -eq 0 ]
  then
    echo "GPU test passed, please execute the command on the k8s master:
    kubectl label nodes xxx suanpan.xuelangyun.com/gpu=available"
  else
    echo "GPU test failed, please check the error message."
    exit 1
  fi
  echo
}

check_nvidia_driver
deploy_nvidia_runtime
config_docker_runtime
check_gpu_running
popd &>/dev/null

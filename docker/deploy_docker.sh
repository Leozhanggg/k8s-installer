#!/bin/bash
#set -x
#set -e

WORKING_DIR=$(cd `dirname $0` && pwd)
pushd $WORKING_DIR &>/dev/null
if [ "$UID" -ne 0 ]; then
   echo "[ERROR]: require root user"
   exit 1
fi

echo "============================== Config data root =============================="
DATA_ROOT=/var/lib/docker
if [ $# -ne 0 ]; then
  DATA_ROOT=$1
fi
sed "s#{{.data-root}}#$DATA_ROOT#g" $WORKING_DIR/config/daemon.json.tpl >$WORKING_DIR/config/daemon.json
cat $WORKING_DIR/config/daemon.json
echo

echo "============================== Installing docker components =============================="
if [ -d rpms ]; then
  cd rpms && yum -y -e 0 localinstall *.rpm && cd $WORKING_DIR
else
  yum install -y yum-utils device-mapper-persistent-data lvm2
  yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
  yum install -y docker-ce-19.03.5 docker-ce-cli-19.03.5
fi
echo

echo "============================== Starting docker service =============================="
mkdir -p /etc/docker/
\cp $WORKING_DIR/config/daemon.json /etc/docker/
mkdir -p /etc/systemd/system/docker.service.d
systemctl daemon-reload && systemctl restart docker && systemctl enable docker

echo "============================== Check docker status =============================="
DF_RUNTIME=$(docker info | grep "Default Runtime:")
if [[ ${DF_RUNTIME#*:} == ' runc' ]]
then
  docker info
  echo "Docker deploy successfully!"
else
  echo "Docker deploy failed!"
  exit 1
fi
popd &>/dev/null
#!/bin/bash
#set -x

if [ "$UID" -ne 0 ]; then
   echo "[ERROR]: require root user"
   exit 1
fi

docker_dir=`docker info | grep 'Root Dir'`
echo "============================== Stop docker service ============================== "
systemctl stop docker && systemctl disable docker
echo

if [ "$1" == "--all" ]; then
  echo "============================== Remove docker dir ============================== "
  ls -l ${docker_dir#*:}
  rm -rf ${docker_dir#*:}
  echo

  echo "============================== Remove docker service ============================== "
  yum -y -e 0 remove docker-ce docker-ce-cli containerd.io
  echo

  echo "============================== Remove docker dependencies ============================== "
  yum -y -e 0 remove device-mapper-persistent-data lvm2
  echo
fi
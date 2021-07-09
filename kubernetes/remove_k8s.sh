#!/bin/bash
#set -x

if [ "$UID" -ne 0 ]; then
   echo "[ERROR]: require root user"
   exit 1
fi

echo "============================== kubeadm reset k8s ============================== "
kubeadm reset -f 2>/dev/null

echo "============================== Remove k8s config ============================== "
rm -rf /etc/cni/net.d
rm -rf /root/.kube/
ipvsadm --clear 2>/dev/null

if [ "$1" == "--all" ]; then
  echo "============================== Stop kubelet service ============================== "
  systemctl stop kubelet && systemctl disable kubelet
  echo

  echo "============================== Remove k8s service ============================== "
  yum -y -e 0 remove kubernetes-cni kubectl kubelet kubeadm
  echo

  echo "============================== Remove k8s dependencies ============================== "
  yum -y -e 0 remove socat conntrack-tools cri-tools libnetfilter_cthelper libnetfilter_cttimeout libnetfilter_queue
  echo

  echo "============================== Remove ipvs modules ============================== "
  yum -y -e 0 remove ipvsadm ipset ipset-libs 2>/dev/null
  echo
fi
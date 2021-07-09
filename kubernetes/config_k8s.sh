#!/bin/bash
#set -x

WORKING_DIR=$(cd `dirname $0` && pwd)
pushd $WORKING_DIR &>/dev/null
if [ "$UID" -ne 0 ]; then
   echo "[ERROR]: require root user"
   exit 1
fi
NODE_IP=$(ip route get 8.8.4.4 | head -1 | awk '{print $7}')
if [ $# -ne 0 ]; then
  NODE_IP=$1
fi
NODE_NAME="k8s-${NODE_IP##*.}"
ETC_HOSTS=$(cat /etc/hosts |grep "$NODE_IP $NODE_NAME")
if [[ -z "$ETC_HOSTS" ]]; then
  echo "$NODE_IP $NODE_NAME" >> /etc/hosts
fi
echo "Deploy $NODE_NAME: $NODE_IP"
hostnamectl set-hostname $NODE_NAME
echo

echo "============================== Stoping: selinux,firewall,swap =============================="
swapoff -a && sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
setenforce 0 && sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
systemctl stop firewalld && systemctl disable firewalld
echo

if [ -d images ]; then
  echo "============================== Importing k8s images =============================="
  for image in images/*; do docker load -i $image; done
  echo
fi

echo "============================== Installing k8s components =============================="
if [ -d rpms ]; then
  cd rpms && yum -y -e 0 localinstall *.rpm && cd $WORKING_DIR
else
  cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=http://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=http://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg
http://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
  yum -y install kubeadm-1.18.8 kubelet-1.18.8 kubectl-1.18.8 --setopt=obsoletes=0
  yum -y install bash-completion
fi
echo

echo "============================== Adjusting system kernel =============================="
\cp "$WORKING_DIR/config/kubernetes.conf" /etc/sysctl.d/
modprobe br_netfilter && sysctl -p /etc/sysctl.d/kubernetes.conf
echo

echo "============================== Loading ipvs modules =============================="
\cp "$WORKING_DIR/config/ipvs.modules" /etc/sysconfig/modules
chmod 755 /etc/sysconfig/modules/ipvs.modules
sh /etc/sysconfig/modules/ipvs.modules && lsmod | grep ip_vs
echo

echo "============================== Enable kubelet service =============================="
systemctl enable kubelet.service
STATUS=$(systemctl status kubelet.service | grep enabled)
if [[ -n $STATUS ]]; then
  echo "Configure k8s finished!"
else
  echo "Configure k8s failed!"
  exit 1
fi
popd &>/dev/null
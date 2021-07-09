#!/bin/bash
#set -x
#set -e

WORKING_DIR=$(cd `dirname $0` && pwd)
pushd $WORKING_DIR &>/dev/null
# default configuration:
DATA_DIR=/var/lib
while [ "$1" != "" ]; do
  case $1 in
    --dir)
    DATA_DIR=$2
    shift 2
    ;;
    --ip)
    WORKER_IP=$2
    shift 2
    ;;
    *)
    echo "[ERROR] invalid argument '$1'"
    usage
    exit 1
  esac
done
echo "============================== Copy installer to worker =============================="
scp -r docker kubernetes root@${WORKER_IP}:~/
if [ $? -ne 0 ]; then
  echo "Please set no secret login:
  ssh-keygen
  ssh-copy-id -i /root/.ssh/id_rsa.pub root@<worker_ip>"
  exit 1
fi

echo "============================== Begin of deploy k8s worker =============================="
ssh root@${WORKER_IP} "chmod a+x docker/*.sh kubernetes/*.sh"
ssh root@${WORKER_IP} "./docker/deploy_docker.sh $DATA_DIR/docker"
if [ $? -ne 0 ]; then exit 1; fi
echo

ssh root@${WORKER_IP} "./kubernetes/config_k8s.sh ${WORKER_IP}"
if [ $? -ne 0 ]; then exit 1; fi
echo

echo "============================== Join k8s cluster =============================="
MASTER_AGE=$(kubectl get nodes | grep master | awk '{print $4}')
if [[ '$MASTER_AGE' =~ 'y' ]]; then
  KUBE_INIT_TOKEN=$(kubeadm token create --print-join-command)
elif [[ '$MASTER_AGE' =~ 'd' ]]; then
  KUBE_INIT_TOKEN=$(kubeadm token create --print-join-command)
elif [[ '$MASTER_AGE' =~ 'h' ]]; then
  if [[ ${MASTER_AGE%h} -ge 24 ]]; then
    KUBE_INIT_TOKEN=$(kubeadm token create --print-join-command)
  else
    KUBE_INIT_TOKEN=$(tail -n2 kubernetes/kubeadm-init.log)
  fi
else
  KUBE_INIT_TOKEN=$(tail -n2 kubernetes/kubeadm-init.log)
fi

ssh root@${WORKER_IP} "$KUBE_INIT_TOKEN"
if [ $? -ne 0 ]; then exit 1; fi
echo

echo "============================== Check cluster status =============================="
while kubectl get nodes | grep NotReady; do sleep 5 && echo "waiting node ready..."; done
while kubectl get pod -A| grep -vE "STATUS|Running|Completed"; do sleep 30 && echo "waiting pod ready..."; done
echo "k8s worker deployed successfully!"

echo "============================== End of deploy k8s worker =============================="
popd &>/dev/null

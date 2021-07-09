#!/bin/bash
#set -x
#set -e

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
bash config_k8s.sh $NODE_IP
if [ $? -ne 0 ]; then exit 1; fi
echo

echo "============================== Running kubeadm init =============================="
sed "s#{{.name}}#$NODE_NAME#g" $WORKING_DIR/config/kubeadm.yaml.tpl >$WORKING_DIR/config/kubeadm.yaml
sed -i "s#{{.advertiseAddress}}#$NODE_IP#g" $WORKING_DIR/config/kubeadm.yaml
kubeadm init --config=config/kubeadm.yaml | tee kubeadm-init.log
if [ $? -eq 0 ]; then
  echo "kubeadm init successfully!"
  mkdir -p $HOME/.kube
  \cp /etc/kubernetes/admin.conf $HOME/.kube/config
  chown $(id -u):$(id -g) $HOME/.kube/config
else
  echo "kubeadm init failed!"
  exit 1
fi
echo

echo "============================== Edit k8s config =============================="
kubectl taint nodes $NODE_NAME node-role.kubernetes.io/master:NoSchedule-
sed -i 's/- --port=0/#- --port=0/g' /etc/kubernetes/manifests/kube-controller-manager.yaml
sed -i 's/- --port=0/#- --port=0/g' /etc/kubernetes/manifests/kube-scheduler.yaml
systemctl daemon-reload && systemctl restart kubelet
echo

echo "============================== Deploy k8s plugins =============================="
kubectl apply -f $WORKING_DIR/yaml
echo

echo "============================== Check cluster status =============================="
while kubectl get cs | grep Unhealthy; do sleep 5 && echo "waiting cluster ready..."; done
while kubectl get nodes | grep NotReady; do sleep 5 && echo "waiting node ready..."; done
while kubectl get pod -A| grep -vE "STATUS|Running|Completed"; do sleep 30 && echo "waiting pod ready..."; done
echo

echo "============================== Kubectl quick settings=============================="
source /usr/share/bash-completion/bash_completion
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.bashrc
echo "k8s deployed successfully!"
popd &>/dev/null
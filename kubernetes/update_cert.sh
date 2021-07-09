#!/bin/bash
#set -x
#set -e

if [ "$UID" -ne 0 ]; then
   echo "[ERROR]: require root user"
   exit 1
fi

if [ $# -ne 0 ]; then
  NODE_NAME=$1
else
  NODE_CNOF=$(cat /etc/kubernetes/kubelet.conf | grep "user: system:node:")
  NODE_NAME=${NODE_CNOF#*node:}
fi
echo "Upgrade node: $NODE_NAME"

echo "============================== Check old certificate =============================="
CERTS=$(find /etc/kubernetes/pki -maxdepth 2 -name "*.crt")
for tls in $CERTS; do
  echo "=========== $tls ============="
  openssl x509 -in $tls -text| grep Not
done
echo

echo "============================== Backup k8s config: /etc/kubernetes_old =============================="
cp -r /etc/kubernetes /etc/kubernetes_old
echo "Generate kubeadm config: kubeadm-upgrade.yaml" 
# kubeadm config view > kubeadm-upgrade.yaml
# if [ $? -ne 0 ]; then echo; fi
K8S_VERSION=$(docker images | grep kube-apiserver | awk '{print $2}')
IMAGE_NAME=$(docker images | grep kube-apiserver | awk '{print $1}')
if [[ ${K8S_VERSION#v} < 1.15.0 ]]; then
  API_VERSION="kubeadm.k8s.io/v1beta1"
else
  API_VERSION="kubeadm.k8s.io/v1beta2"
fi
cat > kubeadm-upgrade.yaml <<end
apiVersion: $API_VERSION
kubernetesVersion: $K8S_VERSION
imageRepository: ${IMAGE_NAME%/*}
kind: ClusterConfiguration
end
echo

echo "============================== Generate new certificate =============================="
kubeadm alpha certs renew all --config kubeadm-upgrade.yaml
if [ $? -ne 0 ]; then
  echo "Failed to generate new certificate!"
  exit 1
fi
for tls in $CERTS; do
  echo "=========== $tls ============="
  openssl x509 -in $tls -text| grep Not
done
echo

echo "============================== Generate k8s config =============================="
rm -rf /etc/kubernetes/*.conf
kubeadm init phase kubeconfig all --config kubeadm-upgrade.yaml --node-name $NODE_NAME
if [ $? -ne 0 ]; then
  echo "Failed to generate kubernetes config!"
  exit 1
fi
\cp /etc/kubernetes/admin.conf $HOME/.kube/config
echo

echo "Restart container: apiserver,controller-manager,scheduler,etcd..."
docker ps -a |grep -E 'k8s_kube-apiserver|k8s_kube-controller-manager|k8s_kube-scheduler|k8s_etcd_etcd' | awk -F ' ' '{print $1}' |xargs docker restart
if [ $? -ne 0 ]; then
  echo "No container is found, will restart docker."
  systemctl restart docker
fi
systemctl restart kubelet
echo 

echo "============================== Check node status =============================="
NODE_STATUS=""
while [[ -z "$NODE_STATUS" ]]; do
  sleep 1
  kubectl get node $NODE_NAME | grep Ready
  NODE_STATUS=$(kubectl get node $NODE_NAME | grep -w Ready)
done
echo "The certificate is successfully upgraded."
echo

echo "If the working node, please execute the following command:
kubeadm init phase kubeconfig kubelet --node-name <NODE_NAME> --kubeconfig-dir /tmp/
ssh root@<NODE_NAME> 'mv /etc/kubernetes/kubelet.conf /etc/kubernetes/kubelet.conf_bak'
scp /tmp/kubelet.conf root@<NODE_NAME>:/etc/kubernetes/
ssh root@<NODE_NAME> 'systemctl restart kubelet'
"
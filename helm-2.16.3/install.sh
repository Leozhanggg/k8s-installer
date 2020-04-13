#!/bin/sh
# creator: leozhanggg
# up-date: 2020/04/10
# description: one key deploy.

helm_path="/usr/local/bin"
tiller_image="registry.cn-shanghai.aliyuncs.com/leozhanggg/helm/tiller:v2.16.3"

echo "wget helm-v2.16.3-linux-amd64.tar.gz"
wget https://get.helm.sh/helm-v2.16.3-linux-amd64.tar.gz
tar -zxvf helm-v2.16.3-linux-amd64.tar.gz
echo

echo "intall helm to ${helm_path}"
cp linux-amd64/helm ${helm_path}
chmod a+x ${helm_path}/helm
echo

echo "helm init..."
kubectl apply -f tiller-rbac.yaml
helm init --service-account tiller --skip-refresh
sleep 3
echo

echo "set image to ${tiller_image}"
kubectl -n kube-system set image deployment/tiller-deploy tiller=${tiller_image}
until helm version 2>/dev/null ; do 
  echo "Warning: Waiting for completion or termination."
  echo
  sleep 5
done

echo "Successfully!!!"
#!/bin/sh
# creator: zhangfan
# up-date: 2020/04/10
# description: one key deploy.

tag="v2.16.3"
helm_path="/usr/local/bin"
tiller_image="registry.cn-shanghai.aliyuncs.com/leozhanggg/helm/tiller:${tag}"

echo "Intall helm to ${helm_path}"
cp helm ${helm_path}
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

echo "Successfully deployed!!!"
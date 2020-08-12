#!/bin/sh
# creator: zhangfan
# up-date: 2020/04/13
# description: one key deploy.

helm_path="/usr/local/bin"

echo "wget helm-v3.1.1-linux-amd64.tar.gz"
wget https://get.helm.sh/helm-v3.1.1-linux-amd64.tar.gz
tar -zxvf helm-v3.1.1-linux-amd64.tar.gz
echo

echo "Intall helm to ${helm_path}"
\cp helm ${helm_path}
chmod a+x ${helm_path}/helm

helm version

echo "Successfully!!!"
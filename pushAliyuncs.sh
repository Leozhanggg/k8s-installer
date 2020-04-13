#!/bin/sh
# creator: zhangfan
# up-date: 2020/04/11
# description: pushAliyuncs.sh

images="harbor/photon:v1.10.1 \
 harbor/migrator:v1.10.1"

for image in ${images}; do

depository=$1
registry=registry.cn-shanghai.aliyuncs.com
namespace=leozhanggg
username=leozhanggg
password=$(echo TGVvMTIzNDU2Cg== | base64 -d)
docker login -u ${username} -p ${password} ${registry}

for image in ${images}; do
  image_new=${registry}/${namespace}/${depository}/${image##*/}
  echo ${image_new}
  docker tag ${image} ${image_new}
  docker push ${image_new}
  #docker rmi ${image}
done

docker logout ${registry}

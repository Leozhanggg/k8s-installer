#!/bin/bash

# 三台主节点IP地址（修改）
MasterIP1=192.168.17.128
MasterIP2=192.168.17.129
MasterIP3=192.168.17.130
# Kube-apiserver默认端口
MasterPort=6443

# Haproxy统计页面端口
STATS_PORT=6445

# 虚拟网卡IP地址（修改）
VIRTUAL_IP=192.168.17.100
# 虚拟网卡设备名（修改）
INTERFACE=ens33
# 虚拟网卡子网掩码
NETMASK_BIT=24
# HAProxy服务端口
CHECK_PORT=6444
# 路由标识符（修改）
RID=10
# 虚拟路由标识符（修改）
VRID=160
# IPV4多播默认地址
MCAST_GROUP=224.0.0.18

echo "docker run haproxy-k8s..."
#CURDIR=$(cd `dirname $0`; pwd)
cp haproxy.cfg /etc/kubernetes/
docker run -dit --restart=always --name haproxy-k8s \
    -p $CHECK_PORT:$CHECK_PORT \
    -p $STATS_PORT:$STATS_PORT \
    -e MasterIP1=$MasterIP1 \
    -e MasterIP2=$MasterIP2 \
    -e MasterIP3=$MasterIP3 \
    -e MasterPort=$MasterPort \
    -v /etc/kubernetes/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg \
    registry.cn-shanghai.aliyuncs.com/leozhanggg/k8s/haproxy-k8s:latest
echo

echo "docker run keepalived-k8s..."
docker run -dit --restart=always --name=keepalived-k8s \
    --net=host --cap-add=NET_ADMIN \
    -e INTERFACE=$INTERFACE \
    -e VIRTUAL_IP=$VIRTUAL_IP \
    -e NETMASK_BIT=$NETMASK_BIT \
    -e CHECK_PORT=$CHECK_PORT \
    -e RID=$RID \
    -e VRID=$VRID \
    -e MCAST_GROUP=$MCAST_GROUP \
    registry.cn-shanghai.aliyuncs.com/leozhanggg/k8s/keepalived-k8s:latest

详情参考博客：https://www.cnblogs.com/leozhanggg/category/1680404.html

目录
前置条件：	2
一、系统初始化	3
1)	设置主机名以及域名解析	3
2)	设置系统yum镜像源	3
3)	安装依赖包以及常用软件	3
4)	安装nfs服务以及设置启动	3
5)	关闭swap、selinux、firewalld	3
6)	调整系统内核参数	3
7)	加载系统ipvs相关模块	4
二、部署k8s集群	5
1)	安装部署docker	5
2)	安装部署kubernetes	5
3)	初始化管理节点	6
4)	加入工作节点	6
5)	部署网络插件flannel	6
6)	检查集群健康状况	6
三、部署高可用集群（HA）	7
1)	系统初始化	7
2)	安装docker和kubernetes	7
3)	部署haproxy和keepalived	7
4)	初始化管理节点	7
5)	加入其余管理节点和工作节点	7
6)	部署网络，检查集群健康状况	8
五、部署功能组件	9
1)	部署页面工具Dashboard	9
2)	部署监控平台Prometheus	10
3)	部署应用管理Helm	11
4)	部署日志系统EFK	11
5)	部署七层路由Ingress	12
六、其他	13
1)	命令自动补全	13
2)	实用操作命令	13
3)	NFS共享目录	13
4)	部署镜像仓库	13
5)	常用命令查看	13



前置条件：
	一台或多台机器
	操作系统：CentOS7.x-86_x64
	运行内存：2GB或更多
	系统内核：2CPU或更多
	硬盘大小：30GB或更多
	集群中所有机器之间网络互通可以访问外网（需要拉取镜像）
	节点之中不可以有重复的主机名、MAC 地址、Product_uuid
	禁止交换分区


 
Kubernetes架构图
 
一、系统初始化 
1)	设置主机名以及域名解析
hostnamectl set-hostname k8s-128 
cat >> /etc/hosts <<EOF
192.168.17.128 k8s-128
192.168.17.129 k8s-129
192.168.17.130 k8s-130
192.168.17.200 myregistry.com
EOF
2)	设置系统yum镜像源
wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
yum clean all && yum makecache

3)	安装依赖包以及常用软件
yum -y install vim curl wget unzip ntpdate net-tools ipvsadm ipset sysstat conntrack libseccomp
ntpdate ntp1.aliyun.com

4)	安装nfs服务以及设置启动
yum -y install nfs-common nfs-utils rpcbind
systemctl start nfs && systemctl enable nfs
systemctl start rpcbind && systemctl enable rpcbind

5)	关闭swap、selinux、firewalld
swapoff -a && sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
setenforce 0 && sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
systemctl stop firewalld && systemctl disable firewalld
更多参考： Kubernetes集群开启Firewall

6)	调整系统内核参数
cat > /etc/sysctl.d/kubernetes.conf <<EOF
# 开启网桥模式,关闭ipv6协议（必要）
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv6.conf.all.disable_ipv6=1
# 启用IP路由转发功能,关闭TW状态快速回收机制
net.ipv4.ip_forward=1
net.ipv4.tcp_tw_recycle=0
# 禁止使用Swap空间,只有当系统OOM时才允许使用它
vm.swappiness=0
# 设置文件句柄数目,打开数目(可选)
fs.file-max=2000000
fs.nr_open=2000000
fs.inotify.max_user_instances=512
fs.inotify.max_user_watches=1280000
# 设置系统最大连接数(可选)
net.netfilter.nf_conntrack_max=524288
EOF

modprobe br_netfilter && sysctl -p /etc/sysctl.d/kubernetes.conf
7)	加载系统ipvs相关模块
cat > /etc/sysconfig/modules/ipvs.modules <<EOF
#!/bin/bash
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack_ipv4
EOF

chmod 755 /etc/sysconfig/modules/ipvs.modules
sh /etc/sysconfig/modules/ipvs.modules && lsmod | grep -e ip_

 
二、部署k8s集群
1)	安装部署docker
# 设置镜像源，安装docker及组件
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
yum install -y docker-ce-19.03.5 docker-ce-cli-19.03.5

# 设置镜像加速，仓库地址，日志模式
mkdir /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
"registry-mirrors": ["https://jc3y13r3.mirror.aliyuncs.com"],
"insecure-registries":["hub.jhmy.com"],
"exec-opts": ["native.cgroupdriver=systemd"],
"log-driver": "json-file",
"log-opts": { "max-size": "100m" }
}
EOF

# 重启docker，设置启动
mkdir -p /etc/systemd/system/docker.service.d
systemctl daemon-reload && systemctl restart docker && systemctl enable docker

2)	安装部署kubernetes
# 设置kubernetes镜像源
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

# 安装kubeadm、kubectl、kebelet 
yum -y install kubeadm-1.17.4 kubectl-1.17.4 kubelet-1.17.4 
systemctl enable kubelet.service

3)	初始化管理节点
# 修改准备好的kubeadm配置文件，然后初始化集群
vim kubeadm-config.yaml
 
kubeadm init --config=kubeadm-config.yaml --upload-certs | tee kubeadm-init.log

# 初始化成功后，根据日志提示执行以下命令，赋予用户命令权限。
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

4)	加入工作节点
# 根据初始化日志提示，执行kubeadm join命令加入集群
kubeadm join 192.168.17.128:6443 --token abcdef.0123456789abcdef \
	--discovery-token-ca-cert-hash sha256:260796226d…………

5)	部署网络插件flannel
# 执行准备好的yaml部署文件
kubectl apply -f kube-flannel.yaml

6)	检查集群健康状况
kubectl get cs && kubectl get nodes && kubectl get pod --all-namespaces
 
更多参考：Kubernetes实战总结 - kubeadm部署集群（v1.17.4）
三、部署高可用集群（HA）
1)	系统初始化
参考第一部分。
2)	安装docker和kubernetes
参考第二部步骤【1】和【2】。
3)	部署haproxy和keepalived
修改kube-ha文件夹中start.sh和haproxy.cfg
   
复制文件夹kube-ha到其余管理节点，然后执行start.sh即可。

4)	初始化管理节点
# 修改准备好的kubeadm配置文件(启动高可用VIP配置)，然后初始化集群
vim kubeadm-config.yaml
 
kubeadm init --config=kubeadm-config.yaml --upload-certs | tee kubeadm-init.log

5)	加入其余管理节点和工作节点
# 根据初始化日志提示，执行kubeadm join命令加入其他管理节点。
kubeadm join 192.168.17.100:6444 --token abcdef.0123456789abcdef \
   --discovery-token-ca-cert-hash sha256:56d53268517... \
   --experimental-control-plane --certificate-key c4d1525b6cce4....

# 根据日志提示，所有管理节点执行以下命令，赋予用户命令权限。
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 根据初始化日志提示，执行kubeadm join命令加入其他工作节点。
kubeadm join 192.168.17.100:6444 --token abcdef.0123456789abcdef \
	--discovery-token-ca-cert-hash sha256:260796226d…………

6)	部署网络，检查集群健康状况
# 执行准备好的yaml部署文件
kubectl apply -f kube-flannel.yaml
kubectl get cs && kubectl get nodes && kubectl get pod --all-namespaces
 
更多详情：Kubesnetes实战总结 - 部署高可用集群
 
五、部署功能组件 
1)	部署页面工具Dashboard
# 执行准备好的yaml部署文件
kubectl apply -f kube-dashboard.yml 

# 等待部署完成
kubectl get pod -n kubernetes-dashboard
 

# 更改ClusterIP => NodePort
kubectl edit svc kubernetes-dashboard -n kubernetes-dashboard
 

# 访问masterip:port, 使用命令查看token
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep dashboard-admin | awk '{print $1}')	
 
更多详情：Kubernetes实战总结 - dashboard部署（v2.0.0-rc6）

2)	部署监控平台Prometheus
# 先部署setup文件，然后部署其余文件
cd kube-prometheus-0.3.0/manifests
kubectl create -f setup && sleep 5	# 等待命名空间和自定义资源创建完成
kubectl create -f .

# 等待部署完成
kubectl get pod -n monitoring
 

# 更改ClusterIP => NodePort, 
kubectl edit svc/grafana -n monitoring
 

# 访问masterip:port，默认用户和密码都是admin
 
更多详情：Kubernetes实战总结 - Prometheus部署（v0.3.0）

3)	部署应用管理Helm
# 执行部署脚本即可
unzip helm-3.1.1.zip && cd helm-3.1.1 && sh install.sh
 

4)	部署日志系统EFK
# 创建命名空间efk
cd helm-elastic-7.6.0
kubectl create ns efk

# 创建一块有效pv用于es存储（以nfs为例，新建目录并赋予775权限）
kubectl create -f elasticsearch/es-pv.yaml
 

# 然后依次部署efk
helm install es --namespace=efk ./elasticsearch
helm install fb --namespace=efk ./filebeat
helm install kb --namespace=efk ./kibana

# 更改ClusterIP => NodePort, 
kubectl edit svc/kibana-kibana -n efk
 
# 访问masterip:port，即可查看日志
 
更多详情：Kubernetes实战总结 - EFK部署（v7.6.0）

5)	部署七层路由Ingress
# 添加helm源 
helm repo add nginx-stable https://helm.nginx.com/stable
helm repo update

# 安装nginx-ingress
helm install ngs nginx-stable/nginx-ingress

# 创建tls证书
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 \
-keyout tls.key -out tls.crt -subj "/CN=nginxsvc/O=nginxsvc"
kubectl create secret tls tls-secret --key tls.key --cert tls.crt

# 创建Ingress资源
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ingress-nginx
spec:
  tls:
  - hosts:
    - www.jmnbservice.com
    secretName: tls-secret
  rules:
  - host: www.jmnbservice.com
    http:
      paths:
      - path: /
        backend:
          serviceName: jmnbservice
          servicePort: 8082
 
六、其他
1)	命令自动补全
yum install -y bash-completion
source /usr/share/bash-completion/bash_completion
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.bashrc
2)	实用操作命令 
# 查看etcd健康状态
kubectl -n kube-system exec etcd-k8s-141 -- etcdctl \
--endpoints=https://192.168.17.141:2379 \
--cacert=/etc/kubernetes/pki/etcd/ca.crt \
--cert=/etc/kubernetes/pki/etcd/server.crt \
--key=/etc/kubernetes/pki/etcd/server.key endpoint health

# 如果想去除主节点污点可以执行
kubectl taint nodes --all node-role.kubernetes.io/master:NoSchedule-

# 查看ipvs列表
ipvsadm -ln
3)	NFS共享目录 
mkdir /nfsdata && chmod 666 /nfsdata
chown nfsnobody /nfsdata
vim /etc/exports
/nfsdata *(rw,no_root_squash,no_all_squash,sync)

4)	部署镜像仓库
官方镜像仓库搭建参考：Docker私有仓库搭建与界面化管理
第三方镜像仓库搭建参考：最新版Harbor搭建（harbor-offline-installer-v1.10.1.tgz）

5)	常用命令查看 
官方文档：Kubernetes kubectl 命令表
网络博文：kubernetes常用命令整理



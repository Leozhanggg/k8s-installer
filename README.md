# k8s-installer
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
二、部署k8s集群	4
1)	安装部署docker	4
2)	安装部署kubernetes	5
3)	初始化管理节点	5
4)	加入工作节点	6
5)	部署网络插件flannel	6
6)	检查集群健康状况	6
三、部署功能组件	7
1)	部署页面工具Dashboard	7
2)	部署监控平台Prometheus	8
3)	部署应用管理Helm	9
4)	部署日志系统EFK	9
四、其他	10
1)	命令自动补全	10
2)	部署镜像仓库	10
3)	高可用集群部署	10

 
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
hostnamectl set-hostname k8s-101 
cat >> /etc/hosts <<EOF
192.168.17.101 k8s-101
192.168.17.102 k8s-102
192.168.17.103 k8s-103
192.168.17.100 myregistry.com
EOF
2)	设置系统yum镜像源
wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
yum clean all && yum makecache

3)	安装依赖包以及常用软件
yum -y install vim curl wget ntpdate net-tools ipvsadm ipset sysstat conntrack libseccomp
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
# 开启网桥模式,关闭ipv6协议
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv6.conf.all.disable_ipv6=1
# 启用IP路由转发功能,关闭TW状态快速回收机制
net.ipv4.ip_forward=1
net.ipv4.tcp_tw_recycle=0
# 禁止使用Swap空间,只有当系统OOM时才允许使用它
vm.swappiness=0
# 设置文件句柄数目,打开数目
fs.file-max=2000000
fs.nr_open=2000000
fs.inotify.max_user_instances=512
fs.inotify.max_user_watches=1280000
# 设置系统最大连接数
net.netfilter.nf_conntrack_max=524288
EOF

sysctl -p /etc/sysctl.d/kubernetes.conf

7)	加载系统ipvs相关模块
modprobe br_netfilter
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
# 安装docker组件
yum install -y yum-utils device-mapper-persistent-data lvm2

# 设置docker镜像源
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

# 安装docker-ce，这里我们选择19.03.5版本
yum install -y docker-ce-19.03.5 docker-ce-cli-19.03.5

# 配置daemon.json，包括镜像加速，仓库地址，日志设置
mkdir /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
"registry-mirrors": ["https://jc3y13r3.mirror.aliyuncs.com"],
"insecure-registries":["myregistry.com"],
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

# 安装k8s组件，这里我们选择1.17.4版本
yum -y install kubeadm-1.17.4 kubectl-1.17.4 kubelet-1.17.4 
systemctl enable kubelet.service

3)	初始化管理节点
# 修改准备好的kubeadm配置文件，然后初始化集群
vim kubeadm-config.yaml
 
kubeadm init --config=kubeadm-config.yaml --upload-certs | tee kubeadm-init.log

# 初始化成功后，根据日志提示执行以下命令
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

4)	加入工作节点
# 根据初始化日志提示，执行kubeadm join命令加入集群
kubeadm join 192.168.17.137:6443 --token abcdef.0123456789abcdef \
	--discovery-token-ca-cert-hash sha256:260796226d…………

5)	部署网络插件flannel
# 执行准备好的yaml部署文件
kubectl apply -f kube-flannel.yaml

6)	检查集群健康状况
kubectl get cs && kubectl get nodes && kubectl get pod --all-namespaces
 
 
三、部署功能组件 
1)	部署页面工具Dashboard
# 执行准备好的yaml部署文件
kubectl apply -f kube-dashboard.yml 

# 等待部署完成
kubectl get pod -n kubernetes-dashboard
 

# 更改ClusterIP => NodePort
kubectl edit svc kubernetes-dashboard -n kubernetes-dashboard
 

# 访问masterip:port, 使用命令查看token
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user-token | awk '{print $1}')	
 
更多详情：Kubernetes实战总结 - dashboard部署（v2.0.0-rc6）

2)	部署监控平台Prometheus
# 执行准备好的yaml部署文件
cd kube-prometheus-0.3.0
kubectl create -f kube-prometheus/setup
until kubectl get servicemonitors --all-namespaces ; do date; sleep 1; echo ""; done
kubectl create -f .

# 等待部署完成
kubectl get pod -n monitoring
 

# 更改ClusterIP => NodePort, 
kubectl edit svc/grafana -n monitoring
 

# 访问masterip:port，默认用户和密码都是admin
 
更多详情：Kubernetes实战总结 - Prometheus部署

3)	部署应用管理Helm
# 执行部署脚本即可
cd helm-2.16.3 && sh install.sh
 

4)	部署日志系统EFK
# 先部署pv，然后依次部署efk
cd helm-elastic-7.6.0
kubectl create –f elasticsearch/els-pv.yaml
helm install -n elasticsearch --namespace=logs ./elasticsearch
helm install -n filebeat --namespace=logs ./filebeat
helm install -n kibana --namespace=logs ./kibana

# 更改ClusterIP => NodePort, 
kubectl edit svc/kibana-kibana -n logs
 
# 访问masterip:port，即可查看日志
 
 
四、其他
1)	命令自动补全
yum install -y bash-completion
source /usr/share/bash-completion/bash_completion
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.bashrc

2)	部署镜像仓库
官方镜像仓库搭建参考：Docker私有仓库搭建与界面化管理
第三方镜像仓库搭建参考：最新版Harbor搭建（harbor-offline-installer-v1.10.1.tgz）

3)	高可用集群部署
……

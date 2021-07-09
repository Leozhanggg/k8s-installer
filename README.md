# k8s-installer
One-click deployment of a kubernetes.

—————————————————————————————————————

**【主节点部署】**

默认直接执行 bash deploy.sh 即可！

参数说明：

1）IS_MONITOR=no，默认不部署prometheus监控，可通过参数--monitor yes指定部署

2）IS_CHECK=yes，默认会检查服务器是否安装配置，可通过参数--check no跳过检查

3）DATA_DIR=/data，默认docker存储路径，可通过参数--dir <data_dir>指定其他路径

4）LOCALHOST_IP，默认自动获取当前节点IP，可通过参数--ip <ip_addr>指定其他IP

—————————————————————————————————————

**【工作节点部署】**

1）首先在工作节点执行 bash docker/deploy_docker.sh /data/docker（部署docker）

2）再者在工作节点执行 bash kubernetes/config_k8s.sh（配置k8s）

3）然后在主节点执行 tail -n2 kubernetes/kubeadm-init.log（查看加入集群token）

4）最后在工作节点上执行加入k8s集群命令即可！

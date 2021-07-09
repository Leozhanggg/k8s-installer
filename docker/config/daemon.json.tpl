{
  "registry-mirrors": ["https://k7pvzni0.mirror.aliyuncs.com"],
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-opts": {"max-size":"100m"},
  "log-driver": "json-file",
  "storage-driver": "overlay2",
  "data-root": "{{.data-root}}"
}
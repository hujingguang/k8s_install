#!/bin/bash

#关闭swap分区

#-------------------------------------------------------------------------------------------------------------------------
#kubelet 启动时向 kube-apiserver 发送 TLS bootstrapping 请求，需要先将 bootstrap token 文件中的 kubelet-bootstrap 用户赋予 system:node-bootstrapper cluster 角色(role)， 然后 kubelet 才能有权限创建认证请求(certificate signing requests)：
#master主机执行
cd /etc/kubernetes
kubectl create clusterrolebinding kubelet-bootstrap \
  --clusterrole=system:node-bootstrapper \
  --user=kubelet-bootstrap

#kubelet 通过认证后向 kube-apiserver 发送 register node 请求，需要先将 kubelet-nodes 用户赋予 system:node cluster角色(role) 和 system:nodes 组(group)， 然后 kubelet 才能有权限创建节点请求：
kubectl create clusterrolebinding kubelet-nodes \
  --clusterrole=system:node \
  --group=system:nodes

cat >/usr/lib/systemd/system/kubelet.service <<EOF
[Unit]
Description=Kubernetes Kubelet Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=docker.service
Requires=docker.service

[Service]
WorkingDirectory=/var/lib/kubelet
ExecStart=/usr/local/bin/kubelet --logtostderr=true --v=0 --address 10.210.110.164 --hostname-override=10.210.110.164 --pod-infra-container-image=jimmysong/pause-amd64:3.0  --cluster-dns=10.254.0.2 --experimental-bootstrap-kubeconfig=/etc/kubernetes/bootstrap.kubeconfig --cert-dir=/etc/kubernetes/ssl --cluster-domain=cluster.local --hairpin-mode=promiscuous-bridge --serialize-image-pulls=false --kubeconfig=/etc/kubernetes/kubelet.kubeconfig --healthz-bind-address=0.0.0.0  --runtime-cgroups=/systemd/system.slice --kubelet-cgroups=/systemd/system.slice
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

mkdir /var/lib/kubelet


#-------------------------------------------------------------------------------------------------------------------------
#登录master节点
kubectl get csr
kubectl certificate approve csr-2b308 










#----------------------------------kube-proxy install---------------------------------------------------------------------------------------
yum install -y conntrack-tools


cat > /usr/lib/systemd/system/kube-proxy.service <<EOF
[Unit]
Description=Kubernetes Kube-Proxy Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target

[Service]
EnvironmentFile=-/etc/kubernetes/proxy
ExecStart=/usr/local/bin/kube-proxy  --bind-address=10.210.110.164 --hostname-override=10.210.110.164 --kubeconfig=/etc/kubernetes/kube-proxy.kubeconfig --cluster-cidr=10.254.0.0/16 --logtostderr=true --v=0 --proxy-mode=ipvs
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF




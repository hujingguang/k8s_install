#!/bin/bash

#配置和启动 kube-apiserver
cat >/usr/lib/systemd/system/kube-apiserver.service <<EOF
[Unit]
Description=Kubernetes API Service
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target

[Service]
ExecStart=/usr/local/bin/kube-apiserver  --logtostderr true --v 0  --allow-privileged true  --advertise-address 10.210.110.163 --bind-address 10.210.110.163 --etcd-servers https://10.210.110.159:2379,https://10.210.110.160:2379,https://10.210.110.161:2379 --service-cluster-ip-range 10.254.0.0/16 --admission-control ServiceAccount,NamespaceLifecycle,NamespaceExists,LimitRanger,ResourceQuota --authorization-mode RBAC --runtime-config rbac.authorization.k8s.io/v1beta1 --kubelet-https true  --token-auth-file /etc/kubernetes/token.csv --service-node-port-range 30000-32767 --tls-cert-file /etc/kubernetes/ssl/kubernetes.pem --tls-private-key-file /etc/kubernetes/ssl/kubernetes-key.pem --client-ca-file /etc/kubernetes/ssl/ca.pem --service-account-key-file /etc/kubernetes/ssl/ca-key.pem --etcd-cafile /etc/kubernetes/ssl/ca.pem --etcd-certfile /etc/kubernetes/ssl/kubernetes.pem --etcd-keyfile /etc/kubernetes/ssl/kubernetes-key.pem --enable-swagger-ui true --apiserver-count 3 --audit-log-maxage 30 --audit-log-maxbackup 3 --audit-log-maxsize 100 --audit-log-path /var/lib/audit.log --event-ttl 1h --address 10.210.110.163
Restart=on-failure
Type=notify
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

#-------------------------------------------------------------------------------------------------------------------------
#配置和启动 kube-controller-manager
cat > /usr/lib/systemd/system/kube-apiserver.service <<EOF
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager --logtostderr true --v 0   --master http://10.210.110.163:8080 --bind-address 127.0.0.1 --service-cluster-ip-range 10.254.0.0/16 --cluster-name kubernetes --cluster-signing-cert-file /etc/kubernetes/ssl/ca.pem --cluster-signing-key-file /etc/kubernetes/ssl/ca-key.pem  --service-account-private-key-file /etc/kubernetes/ssl/ca-key.pem --root-ca-file /etc/kubernetes/ssl/ca.pem --leader-elect true
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

#-------------------------------------------------------------------------------------------------------------------------
#配置和启动 kube-scheduler
cat > /usr/lib/systemd/system/kube-scheduler.service <<EOF
[Unit]
Description=Kubernetes Scheduler Plugin
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
EnvironmentFile=-/etc/kubernetes/config
EnvironmentFile=-/etc/kubernetes/scheduler
ExecStart=/usr/local/bin/kube-scheduler --logtostderr true --v 0   --master http://10.210.110.163:8080 --leader-elect true --address 127.0.0.1
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF


#验证
kubectl get componentstatuses


#-------------------------------------------------------------------------------------------------------------------------

#kubelet 启动时向 kube-apiserver 发送 TLS bootstrapping 请求，需要先将 bootstrap token 文件中的 kubelet-bootstrap 用户赋予 system:node-bootstrapper cluster 角色(role)， 然后 kubelet 才能有权限创建认证请求(certificate signing requests)：
cd /etc/kubernetes
kubectl create clusterrolebinding kubelet-bootstrap \
  --clusterrole=system:node-bootstrapper \
  --user=kubelet-bootstrap

#kubelet 通过认证后向 kube-apiserver 发送 register node 请求，需要先将 kubelet-nodes 用户赋予 system:node cluster角色(role) 和 system:nodes 组(group)， 然后 kubelet 才能有权限创建节点请求：

kubectl create clusterrolebinding kubelet-nodes \
  --clusterrole=system:node \
  --group=system:nodes



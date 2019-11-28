#安装calico
#需要配置kubelet 启动参数 --network-plugin=cni.
#需要配置kube-proxy 启动参数 --proxy-mode=iptables 并且去掉--masquerade-all 参数
#使用RBAC的话需要创建role. kubectl apply -f ./rbac.yaml 
#etcd使用证书则需要 base64 etcd证书 : cat /etc/etcd/ca.pem |base64 |tr -d '\n'


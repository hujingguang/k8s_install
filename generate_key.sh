#!/bin/bash
#生成CA根证书

cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "kubernetes": {
        "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ],
        "expiry": "87600h"
      }
    }
  }
}
EOF

#生成CA根证书请求文件
cat > ca-csr.sjon <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "System"
    }
  ],
    "ca": {
       "expiry": "87600h"
    }
}
EOF
cfssl gencert -initca ca-csr.json | cfssljson -bare ca   #生成CA秘钥对

#--------------------------------------------------------------------------------------------------------------------------------------------------------

#生成Kubernetes证书
cat > kubernetes-csr.json <<EOF
{
    "CN": "kubernetes",
    "hosts": [
      "127.0.0.1",
      "10.210.110.159", #k8s master主机IP和etcd集群ip 
      "10.210.110.160",
      "10.210.110.161",
      "10.254.0.1",
      "kubernetes",
      "kubernetes.default",
      "kubernetes.default.svc",
      "kubernetes.default.svc.cluster",
      "kubernetes.default.svc.cluster.local"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "ST": "BeiJing",
            "L": "BeiJing",
            "O": "k8s",
            "OU": "System"
        }
    ]
}
EOF

cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes #生成k8s master密钥对

#--------------------------------------------------------------------------------------------------------------------------------------------------------

#生成admin用户证书 admin 证书，是将来生成管理员用的kube config 配置文件用的
cat >admin-csr.json <<EOF
{
  "CN": "admin",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "system:masters",
      "OU": "System"
    }
  ]
}
EOF
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes admin-csr.json | cfssljson -bare admin #生成admin密钥对

#--------------------------------------------------------------------------------------------------------------------------------------------------------

#生成kube-proxy证书
cat >kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
EOF
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes  kube-proxy-csr.json | cfssljson -bare kube-proxy
#--------------------------------------------------------------------------------------------------------------------------------------------------------
#证书校验
openssl x509  -noout -text -in  kubernetes.pem


#拷贝证书
mkdir -p /etc/kubernetes/ssl && cp *.pem /etc/kubernetes/ssl/


#生成token.csv 文件
export BOOTSTRAP_TOKEN=$(head -c 16 /dev/urandom | od -An -t x | tr -d ' ')
cat > token.csv <<EOF
${BOOTSTRAP_TOKEN},kubelet-bootstrap,10001,"system:kubelet-bootstrap"
EOF
cp token.csv /etc/kubernetes/



#--------------------------------------------------------------------------------------------------------------------------------------------------------
#创建 kubectl kubeconfig 文件 注意：~/.kube/config文件拥有对该集群的最高权限，请妥善保管
export KUBE_APISERVER="https://172.20.0.113:6443"
# 设置集群参数
kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER}
# 设置客户端认证参数
kubectl config set-credentials admin \
  --client-certificate=/etc/kubernetes/ssl/admin.pem \
  --embed-certs=true \
  --client-key=/etc/kubernetes/ssl/admin-key.pem
# 设置上下文参数
kubectl config set-context kubernetes \
  --cluster=kubernetes \
  --user=admin
# 设置默认上下文
kubectl config use-context kubernetes



#--------------------------------------------------------------------------------------------------------------------------------------------------------

# 创建 kubelet bootstrapping kubeconfig 文件用于kubelet自动注册
cd /etc/kubernetes
export KUBE_APISERVER="https://172.20.0.113:6443"  #修改成自己的kube-apiserver服务器地址和端口

# 设置集群参数
kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=bootstrap.kubeconfig

# 设置客户端认证参数
kubectl config set-credentials kubelet-bootstrap \
  --token=${BOOTSTRAP_TOKEN} \
  --kubeconfig=bootstrap.kubeconfig

# 设置上下文参数
kubectl config set-context default \
  --cluster=kubernetes \
  --user=kubelet-bootstrap \
  --kubeconfig=bootstrap.kubeconfig

# 设置默认上下文
kubectl config use-context default --kubeconfig=bootstrap.kubeconfig





#--------------------------------------------------------------------------------------------------------------------------------------------------------
#创建 kube-proxy kubeconfig 文件
export KUBE_APISERVER="https://172.20.0.113:6443"

# 设置集群参数
kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=kube-proxy.kubeconfig

# 设置客户端认证参数
kubectl config set-credentials kube-proxy \
  --client-certificate=/etc/kubernetes/ssl/kube-proxy.pem \
  --client-key=/etc/kubernetes/ssl/kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig

# 设置上下文参数
kubectl config set-context default \
  --cluster=kubernetes \
  --user=kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig

# 设置默认上下文
kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

#将两个 kubeconfig 文件分发到所有 Node 机器的 /etc/kubernetes/ 目录
cp bootstrap.kubeconfig kube-proxy.kubeconfig /etc/kubernetes/




#创建聚合层ca证书

cat > aggregator-ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "aggregator": {
        "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ],
        "expiry": "87600h"
      }
    }
  }
}
EOF
cat > aggregator-ca-csr.json <<EOF
{
  "CN": "aggregator",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "Shanghai",
      "L": "Shanghai",
      "O": "k8s",
      "OU": "System"
    }
  ],
    "ca": {
       "expiry": "87600h"
    }
}
EOF
#字段说明：
#    “CN” ：Common Name，kube-apiserver 从证书中提取该字段作为请求的用户名 (User Name)；浏览器使用该字段验证网站是否合法。
#    “O” ：Organization，kube-apiserver 从证书中提取该字段作为请求用户所属的组 (Group)；
cfssl gencert -initca aggregator-ca-csr.json | cfssljson -bare aggregator-ca

cat > aggregator-csr.json <<EOF
{
    "CN": "aggregator",
    "hosts": [
      "127.0.0.1",
      "192.168.123.250",
      "192.168.123.248",
      "192.168.123.249",
      "10.254.0.1",
      "kubernetes",
      "kubernetes.default",
      "kubernetes.default.svc",
      "kubernetes.default.svc.cluster",
      "kubernetes.default.svc.cluster.local"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "ST": "Shanghai",
            "L": "Shanghai",
            "O": "k8s",
            "OU": "System"
        }
    ]
}
EOF
cfssl gencert -ca=aggregator-ca.pem -ca-key=aggregator-ca-key.pem -config=aggregator-ca-config.json -profile=aggregator aggregator-csr.json | cfssljson -bare aggregator
#开启聚合曾证书
--requestheader-client-ca-file=/etc/kubernetes/ssl/aggregator-ca.pem
--requestheader-allowed-names=aggregator
--requestheader-extra-headers-prefix=X-Remote-Extra-
--requestheader-group-headers=X-Remote-Group
--requestheader-username-headers=X-Remote-User
--proxy-client-cert-file=/etc/kubernetes/ssl/aggregator.pem
--proxy-client-key-file=/etc/kubernetes/ssl/aggregator-key.pem

#前面创建的证书的 CN 字段的值必须和参数 –requestheader-allowed-names 指定的值 aggregator 相同。

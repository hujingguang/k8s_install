#!/bin/bash

'
生成根证书和秘钥
openssl genrsa -out ca-key.pem 2048
openssl req -x509 -new -nodes -key ca-key.pem -days 10000 -out ca.pem -subj "/CN=etcd-ca"
'

etcd_download_url=https://github.com/etcd-io/etcd/releases/download/v3.2.27/etcd-v3.2.27-linux-amd64.tar.gz
etcd_run_user=etcd
etcd_data_dir=/var/lib/etcd
etcd_host=10.210.20.47
etcd_ssl_dir=/etc/ssl/etcd/ssl
etcd_conf=/etc/etcd.env
etcd_node=etcd-04
base_dir=`pwd`
ca_pem="
"
ca_key_pem="
"
systemd_scripts="
[Unit] \
Description=etcd \
After=network.target \
[Service] \
Type=notify \
User=etcd \
EnvironmentFile=/etc/etcd.env \
ExecStart=/usr/bin/etcd \
NotifyAccess=all \
Restart=always \
RestartSec=10s \
LimitNOFILE=40000 \
[Install] \
WantedBy=multi-user.target \
"
cert_conf="
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[ssl_client]
extendedKeyUsage = clientAuth, serverAuth
basicConstraints = CA:FALSE
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer
subjectAltName = @alt_names
[v3_ca]
basicConstraints = CA:TRUE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
authorityKeyIdentifier=keyid:always,issuer
[alt_names]
DNS.1 = localhost
DNS.2 = $etcd_node
IP.1 = $etcd_host
IP.2 = 127.0.0.1
"
etcd_env="
ETCD_DATA_DIR=/var/lib/etcd
ETCD_ADVERTISE_CLIENT_URLS=https://192.168.43.45:2379
ETCD_INITIAL_ADVERTISE_PEER_URLS=https://192.168.43.45:2380
ETCD_INITIAL_CLUSTER_STATE=new
ETCD_LISTEN_CLIENT_URLS=https://192.168.43.45:2379
ETCD_ELECTION_TIMEOUT=5000
ETCD_HEARTBEAT_INTERVAL=250
ETCD_LISTEN_PEER_URLS=https://192.168.43.45:2380
ETCD_NAME=etcd1
ETCD_PROXY=off
ETCD_INITIAL_CLUSTER=etcd1=https://192.168.43.45:2380,etcd2=https://192.168.43.46:2380,etcd3=https://192.168.43.47:2380
#ETCD_INITIAL_CLUSTER=etcd1=https://192.168.43.45:2380# TLS settings
ETCD_TRUSTED_CA_FILE=/etc/ssl/etcd/ssl/ca.pem
ETCD_CERT_FILE=/etc/ssl/etcd/ssl/member-etcd-01.pem
ETCD_KEY_FILE=/etc/ssl/etcd/ssl/member-etcd-01-key.pem
ETCD_PEER_TRUSTED_CA_FILE=/etc/ssl/etcd/ssl/ca.pem
ETCD_PEER_CERT_FILE=/etc/ssl/etcd/ssl/member-etcd-01.pem
ETCD_PEER_KEY_FILE=/etc/ssl/etcd/ssl/member-etcd-01-key.pem
ETCD_PEER_CLIENT_CERT_AUTH=true
"
which openssl &>/dev/null
if [ $? != 0  ] 
then
echo "请安装openssl工具:  yum install openssl openssl-devel -y"
fi
if [ "$ca_pem" = "" ] && [ "$ca_key_pem" = "" ]
then
  echo "请先配置ca公私钥字符串"
  exit 1
fi
mkdir -p ${etcd_data_dir} ${etcd_ssl_dir}
echo $cert_conf > ./openssl_conf
echo $systemd_scripts > /usr/lib/systemd/system/etcd.service
echo $ca_pem >./ca.pem
echo $ca_key_pem >./ca-key.pem
openssl genrsa -out member-${etcd_node}-key.pem 2048
openssl req -new -key member-${etcd_node}-key.pem -out member-${etcd_node}.csr -subj "/CN=${etc_node}" -config ./openssl.conf
vpenssl x509 -req -in member-${etcd_node}.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out member-${etcd_node}.pem -days 3650 -extensions ssl_client -extfile ./openssl.conf

cp -rvp ./*.pem ${etcd_data_dir}/
useradd etcd -s /sbin/nologin -r -d ${etcd_data_dir}
chmod -Rv 550 $(dirname $etcd_ssl_dir)
chmod 440 ${etcd_ssl_dir}/*.pem
chown -Rv etcd:etcd $(dirname $etcd_ssl_dir)
chown -Rv etcd:etcd $(dirname $etcd_ssl_dir)/*
chown etcd:etcd ${etcd_data_dir}/

curl -L ${etcd_download_url} -o /tmp/etcd-linux-amd64.tar.gz
tar xzvf /tmp/etcd-linux-amd64.tar.gz -C /tmp/etcd-download-test --strip-components=1
if [ -e /usr/bin/etcd  ] && [ -e /usr/bin/etcdctl ]
then
 cp /tmp/etcd-download-test/etcd /tmp/etcd-download-test/etcdctl /usr/bin/
fi
rm -rf /tmp/etcd-linux-amd64.tar.gz /tmp/etcd-download-test
systemctl daemon-reload

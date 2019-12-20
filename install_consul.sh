#安装和启动consul集群
docker pull consul:1.3.1

docker   run -d  --net=host  6c4586f655e0   consul agent -server -bootstrap-expect=2 -config-dir=/consul/config -data-dir=/consul/data  -client=0.0.0.0 -advertise=10.210.110.165 -ui -raft-protocol=3 -rejoin -retry-join=10.210.110.164  -retry-join=10.210.110.166  -datacenter=yxzq

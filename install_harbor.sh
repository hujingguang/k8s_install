#node docker 配置

#1. 在  /etc/docker/certs.d/harbor.yxzq.com/ 下 放置根证书ca.crt
#2. cat /etc/docker/daemon.json
#{
#    "registry-mirrors":
#    [
#        "https://docker.io",
#        "https://harbor.yxzq.com"
#    ],
#   "insecure-registries": []
#}

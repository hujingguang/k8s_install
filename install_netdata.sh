#!/bin/bash
#一个主机实时监控程序
docker run -d --name=netdata   -p 19999:19999   -v /etc/passwd:/host/etc/passwd:ro   -v /etc/group:/host/etc/group:ro   -v /proc:/host/proc:ro   -v /sys:/host/sys:ro   -v /var/run/docker.sock:/var/run/docker.sock:ro   --cap-add SYS_PTRACE   --security-opt apparmor=unconfined   netdata/netdata

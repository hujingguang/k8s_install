#!/bin/bash
#访问官网安装

#rancher 通过每个node安装一个agent以及集群启动一个cluster-agent pod跟rancher server通信，具体YML如下

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: proxy-clusterrole-kubeapiserver
rules:
- apiGroups: [""]
  resources:
  - nodes/metrics
  - nodes/proxy
  - nodes/stats
  - nodes/log
  - nodes/spec
  verbs: ["get", "list", "watch", "create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: proxy-role-binding-kubernetes-master
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: proxy-clusterrole-kubeapiserver
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: kube-apiserver
---
apiVersion: v1
kind: Namespace
metadata:
  name: cattle-system

---

apiVersion: v1
kind: ServiceAccount
metadata:
  name: cattle
  namespace: cattle-system

---

apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: cattle-admin-binding
  namespace: cattle-system
  labels:
    cattle.io/creator: "norman"
subjects:
- kind: ServiceAccount
  name: cattle
  namespace: cattle-system
roleRef:
  kind: ClusterRole
  name: cattle-admin
  apiGroup: rbac.authorization.k8s.io

---

apiVersion: v1
kind: Secret
metadata:
  name: cattle-credentials-d67ad00
  namespace: cattle-system
type: Opaque
data:
  url: "aHR0cHM6Ly8xMC4yMTAuMTEwLjE2Mw=="
  token: "anBxd3Q2cDltcm1sbmNzbHN4aGM2cGQ2eDl6NnYycXpucW0ydGZkOWcycmI4cWg3Zndobjlz"

---

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cattle-admin
  labels:
    cattle.io/creator: "norman"
rules:
- apiGroups:
  - '*'
  resources:
  - '*'
  verbs:
  - '*'
- nonResourceURLs:
  - '*'
  verbs:
  - '*'

---

apiVersion: apps/v1
kind: Deployment
metadata:
  name: cattle-cluster-agent
  namespace: cattle-system
spec:
  selector:
    matchLabels:
      app: cattle-cluster-agent
  template:
    metadata:
      labels:
        app: cattle-cluster-agent
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                - key: beta.kubernetes.io/os
                  operator: NotIn
                  values:
                    - windows
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: node-role.kubernetes.io/controlplane
                operator: In
                values:
                - "true"
          - weight: 1
            preference:
              matchExpressions:
              - key: node-role.kubernetes.io/etcd
                operator: In
                values:
                - "true"
      serviceAccountName: cattle
      tolerations:
      - operator: Exists
      containers:
        - name: cluster-register
          imagePullPolicy: IfNotPresent
          env:
          - name: CATTLE_SERVER
            value: "https://10.210.110.163"
          - name: CATTLE_CA_CHECKSUM
            value: "a65ffa59086132b0efe6b86f5e1bff73e9e2591ebe6e1b8d812f0a9b770370b6"
          - name: CATTLE_CLUSTER
            value: "true"
          - name: CATTLE_K8S_MANAGED
            value: "true"
          image: rancher/rancher-agent:v2.3.0
          volumeMounts:
          - name: cattle-credentials
            mountPath: /cattle-credentials
            readOnly: true
      volumes:
      - name: cattle-credentials
        secret:
          secretName: cattle-credentials-d67ad00
          defaultMode: 320

---

apiVersion: apps/v1
kind: DaemonSet
metadata:
    name: cattle-node-agent
    namespace: cattle-system
spec:
  selector:
    matchLabels:
      app: cattle-agent
  template:
    metadata:
      labels:
        app: cattle-agent
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                - key: beta.kubernetes.io/os
                  operator: NotIn
                  values:
                    - windows
      hostNetwork: true
      serviceAccountName: cattle
      tolerations:
      - operator: Exists
      containers:
      - name: agent
        image: rancher/rancher-agent:v2.3.0
        imagePullPolicy: IfNotPresent
        env:
        - name: CATTLE_NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: CATTLE_SERVER
          value: "https://10.210.110.163"
        - name: CATTLE_CA_CHECKSUM
          value: "a65ffa59086132b0efe6b86f5e1bff73e9e2591ebe6e1b8d812f0a9b770370b6"
        - name: CATTLE_CLUSTER
          value: "false"
        - name: CATTLE_K8S_MANAGED
          value: "true"
        - name: CATTLE_AGENT_CONNECT
          value: "true"
        volumeMounts:
        - name: cattle-credentials
          mountPath: /cattle-credentials
          readOnly: true
        - name: k8s-ssl
          mountPath: /etc/kubernetes
        - name: var-run
          mountPath: /var/run
        - name: run
          mountPath: /run
        - name: docker-certs
          mountPath: /etc/docker/certs.d
        securityContext:
          privileged: true
      volumes:
      - name: k8s-ssl
        hostPath:
          path: /etc/kubernetes
          type: DirectoryOrCreate
      - name: var-run
        hostPath:
          path: /var/run
          type: DirectoryOrCreate
      - name: run
        hostPath:
          path: /run
          type: DirectoryOrCreate
      - name: cattle-credentials
        secret:
          secretName: cattle-credentials-d67ad00
          defaultMode: 320
      - hostPath:
          path: /etc/docker/certs.d
          type: DirectoryOrCreate
        name: docker-certs
  updateStrategy:
    type: RollingUpdate

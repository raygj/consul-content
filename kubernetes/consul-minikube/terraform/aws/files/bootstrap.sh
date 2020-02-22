#!/bin/bash
# sudo chmod +x bootstrap.sh
# run with sudo

snap remove docker
apt-get update
apt-get install -y unzip nano net-tools nmap socat

# docker install on Amazon Ubuntu
# https://geekylane.com/install-docker-on-aws-ec2-ubuntu-18-04-script-method/

curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# minikube installation
# https://github.com/raygj/vault-content/tree/master/use-cases/vault-agent-kubernetes#install-minikube

cd /usr/local/bin
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 \
  && chmod +x minikube

egrep -q 'vmx|svm' /proc/cpuinfo && echo yes || echo no

minikube config set vm-driver none

minikube start

# install kubectl

cd /usr/local/bin

curl -LO https://storage.googleapis.com/kubernetes-release/release/` \
curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl

chmod +x ./kubectl

# install helm

cd /tmp

curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3

chmod 700 get_helm.sh

./get_helm.sh

# create Consul custom helm values

cat << EOF > ~/helm-consul-values.yaml
client:
  enabled: true
connectInject:
  enabled: true
global:
  datacenter: minidc
server:
  bootstrapExpect: 1
  disruptionBudget:
    enabled: true
    maxUnavailable: 0
  replicas: 1
ui:
  service:
    type: NodePort
EOF

# create pod definition files

cat << EOF > ~/counting.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: counting
---
apiVersion: v1
kind: Pod
metadata:
  name: counting
  annotations:
    "consul.hashicorp.com/connect-inject": "true"
spec:
  containers:
  - name: counting
    image: hashicorp/counting-service:0.0.2
    ports:
    - containerPort: 9001
      name: http
  serviceAccountName: counting
EOF

cat << EOF > ~/dashboard.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: dashboard
---
apiVersion: v1
kind: Pod
metadata:
  name: dashboard
  labels:
    app: 'dashboard'
  annotations:
    "consul.hashicorp.com/connect-inject": "true"
    "consul.hashicorp.com/connect-service-upstreams": "counting:9001"
spec:
  containers:
  - name: dashboard
    image: hashicorp/dashboard-service:0.0.4
    ports:
    - containerPort: 9002
      name: http
    env:
    - name: COUNTING_SERVICE_URL
      value: "http://localhost:9001"
  serviceAccountName: dashboard
---
apiVersion: 'v1'
kind: 'Service'
metadata:
  name: 'dashboard-service-load-balancer'
  namespace: 'default'
  labels:
    app: 'dashboard'
spec:
  ports:
    - protocol: 'TCP'
      port: 80
      targetPort: 9002
  selector:
    app: 'dashboard'
  type: 'LoadBalancer'
  loadBalancerIP: ''
EOF

# updated Consul cusom helm values

cat << EOF > ~/helm-consul-values2.yaml
client:
  enabled: true
connectInject:
  enabled: true
global:
  datacenter: minidc
server:
  bootstrapExpect: 1
  disruptionBudget:
    enabled: true
    maxUnavailable: 0
  replicas: 1
ui:
  service:
    type: NodePort
syncCatalog:
  enabled: true
EOF

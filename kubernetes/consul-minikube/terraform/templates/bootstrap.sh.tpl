#!/bin/bash
# sudo chmod +x bootstrap.sh
# run with sudo

snap remove docker
apt-get update
apt-get install -y unzip dnsmasq nano net-tools nmap socat docker.io

# minikube installation
# https://github.com/raygj/vault-content/tree/master/use-cases/vault-agent-kubernetes#install-minikube

cd /usr/local/bin
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_1.7.2.deb \
 && sudo dpkg -i minikube_1.7.2.deb

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
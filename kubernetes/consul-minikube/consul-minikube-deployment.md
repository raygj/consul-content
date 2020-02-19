# Consul Minikube Walkthrough

intro to Consul and Kubernetes using Minikube on an Ubuntu VM, next step is Consul on a managed Kubernetes instances (AKS, EKS, GKS) [here](https://github.com/raygj/consul-content/tree/master/kubernetes/consul-eks)

## Goals

- Deploy Consul on Kubernetes Minikube using official Helm chart
- Sandbox environment with services using discovery and Connect Service Mesh

[official learn.hashicorp guide](https://learn.hashicorp.com/consul/getting-started-k8s/minikube)

## Background Consul on Kubernetes

- server agents run as a **StatefulSet** using persistent volume claims to store server state
- StatefulSet ensures **node ID** is persisted to eliminate IP address issues when rescheduling
- anti-affinity rules prevent server agents from residing on the same node (to protect quorum)
- client agents are run as a **DaemonSet** so one agent (within its own pod) is on each Kubernetes node
	- this architecture is preferred over running Consul agents per pod where each pod would be considered a node in the Consul data center (and add resource overhead)
	- service registration should be handled via the catalog syncing feature with services rather than pods
- by default, the client exposes the Consul HTTP API on 8500 bound to the host port
	- this has security implications, in production Consul ACLs and TLS should be used to mitigate unauthorized access to the Consul data center

## Terraform Code and Bootstrap

https://github.com/raygj/consul-content/tree/master/kubernetes/consul-minikube/terraform

- Ubuntu VM
- Terraform to deploy VM and bootstrap Ubuntu
- adapt for your target cloud provider
- Walkthrough with Minikube details [here](https://github.com/raygj/vault-content/tree/master/use-cases/vault-agent-kubernetes#install-minikube)

## Steps

1. deploy and bootstrap Ubuntu VM
2. deploy Consul with Helm
3. access Consul agents
4. deploy two services that use Consul to discover each other and communicate over TLS via Consul Connect
5. cleanup

## Step 1: deploy and Bootstrap

- deploy Ubuntu VM on your choice of infra, then use `boostrap.sh` to prepare the VM

## Step 2: deploy Consul with Helm

### Start Minikube

- startup command, it will take a few minutes to startup

`sudo minikube start`

## Step 2: deploy Consul with Helm

### setup Helm

- clone Helm repo

`git clone https://github.com/hashicorp/consul-helm.git`

- if using Helm 2, you will need to initialize it...if using Helm 3 you are good
- check version

`sudo helm version`

- if v2, initialize

`sudo helm init`

### install Consul

#### create a custom values files

- the default chart comes with reasonable defaults
- the default chart will deploy a server and client agent
	- the client agent should be used as the API endpoint for Consul API calls
- update a few items to reflect a sandbox deployment
	- connectInject will enable Consul Connect
	- global:datacenter is the name of the Consul data center
	- server:bootstrapExpect is the number of servers in the Consul cluster (set this to the number of server nodes you plan to deploy...**note** you must deploy this number of nodes or Consul will not form consensus and start)
- yaml [linter](http://www.yamllint.com) to save headaches

```

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

```

#### execute Helm

`cd ~/`

`sudo helm install -f helm-consul-values.yaml hashicorp ./consul-helm`

- in a matter of seconds Consul is downloaded and instantiated

#### verify consul containers and exposed ports

`sudo minikube service list`

- output similar to:

```

|----------------------|---------------------------------------|---------------------------|-----|
|      NAMESPACE       |                 NAME                  |        TARGET PORT        | URL |
|----------------------|---------------------------------------|---------------------------|-----|
| default              | hashicorp-consul-connect-injector-svc | No node port              |
| default              | hashicorp-consul-dns                  | No node port              |
| default              | hashicorp-consul-server               | No node port              |
| default              | hashicorp-consul-ui                   | http://192.168.1.56:32482 |
| default              | kubernetes                            | No node port              |
| kube-system          | kube-dns                              | No node port              |
| kubernetes-dashboard | dashboard-metrics-scraper             | No node port              |
| kubernetes-dashboard | kubernetes-dashboard                  | No node port              |
|----------------------|---------------------------------------|---------------------------|-----|

```

- visit the UI by hitting the URL listed in the target port for `consul-ui`
	- depending on your environment their may be a firewall, security group, or other connectivity adjustment required

#### exec into Consul pod

- get pod names

`sudo kubectl get pods`

- exec to the `...-consul-server-0` node

`sudo kubectl exec -it hashicorp-consul-server-0 /bin/sh`

- issue Consul native commands to poke around environment
- show consul version:

`consul version`

- view consul datacenter members

`consul members`

- leave exec session

`exit`

## Deploy services with Kubernetes

because the Connect injector was enabled in your `...-values.yaml` file, all the services using Connect will automatically be registered in the Consul catalog

https://learn.hashicorp.com/consul/kubernetes/minikube#deploy-services-with-kubernetes


# Consul Minikube Walkthrough

intro to Consul and Kubernetes using Minikube on an Ubuntu VM, next step is Consul on a managed Kubernetes instances (AKS, EKS, GKS) [here](https://github.com/raygj/consul-content/tree/master/kubernetes/consul-eks)

## Goals

- Deploy Consul on Kubernetes Minikube using official Helm chart
- Sandbox environment with services using discovery and Connect Service Mesh

## Background Consul on Kubernetes

- server agents run as a **StatefulSet** using persistent volume claims to store server state
- StatefulSet ensures **node ID** is persisted to eliminate IP address issues when rescheduling
- anti-affinity rules prevent server agents from residing on the same node (to protect quorum)
- client agents are run as a **DaemonSet** so one agent (within its own pod) is on each Kubernetes node
	- this architecture is preferred over running Consul agents per pod where each pod would be considered a node in the Consul data center (and add resource overhead)
	- service registration should be handled via the catalog syncing feature with services rather than pods
- by default, the client exposes the Consul HTTP API on 8500 bound to the host port
	- this has security implications, in production Consul ACLs and TLS should be used to mitigate unauthorized access to the Consul data center

## References

[Official learn.hashicorp Guide](https://learn.hashicorp.com/consul/getting-started-k8s/minikube)

[Consul Helm Repo](https://github.com/hashicorp/consul-helm)

## Terraform Code and Bootstrap

[Terraform on AWS](https://github.com/raygj/consul-content/tree/master/kubernetes/consul-minikube/terraform/aws)

[Terraform on ESXi](https://github.com/raygj/consul-content/tree/master/kubernetes/consul-minikube/terraform/esxi)

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

- clone latest Helm repo

`git clone https://github.com/hashicorp/consul-helm.git`

`sudo helm version`

### install Consul

#### create a custom values files

- the default chart comes with reasonable defaults
- the default chart will deploy a server and client agent
	- the client agent should be used as the API endpoint for Consul API calls
- update a few items to reflect a sandbox deployment
	- connectInject will enable Consul Connect
	- global:datacenter is the name of the Consul data center
	- server:bootstrapExpect is the number of servers in the Consul cluster (set this to the number of server nodes you plan to deploy...**note** you must deploy this number of nodes or Consul will not form consensus and start)
- yaml [linter](https://codebeautify.org/yaml-validator) to save headaches

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
	- on AWS you will need to change the URL to match your public IP address

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

- because the Connect injector was enabled in your `...-values.yaml` file, all the services using Connect will automatically be registered in the Consul catalog
- deploy two services (front and back end)

### create pod definition files

- Counting Service


```

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

```

- Dashboard Service

```

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

```

### deploy services

- counting service

`sudo kubectl create -f counting.yaml`

- dashboard service

`sudo kubectl create -f dashboard.yaml`

### verify services

- from CLI

`sudo kubectl get pods`

```

NAME                                                              READY   STATUS    RESTARTS   AGE
counting                                                          3/3     Running   0          66s
dashboard                                                         3/3     Running   0          7s
hashicorp-consul-bv4ct                                            1/1     Running   0          19h
hashicorp-consul-connect-injector-webhook-deployment-84589mlsll   1/1     Running   0          19h
hashicorp-consul-server-0                                         1/1     Running   0          19h

```

- from Consul UI

![image](/images/consul_minikube_dashboard00.png)

### access Counting Dashboard

- find target port of dashboard-service-load-balancer

`sudo minikube service list`

- assuming dashboard and counting services are connected you will see the "count" incrementing
- if there is a break in communication the dashboard will report a negative value
	- this behavior will be used for test intentions in the next section
- visit the UI by hitting the URL listed in the target port for `dashboard-service-load-balancer`
	- depending on your environment their may be a firewall, security group, or other connectivity adjustment required
	- on AWS you will need to change the URL to match your public IP address

## Consul Intentions

- using the service tag names you can enforce directional intentions on the traffic flow between endpoints
- [Intentions](https://www.consul.io/docs/connect/intentions.html) rely on Consul's "service access graph" which is a matrix of who,what,where, and associated allow/deny policy
	- intentions replace traditional IP-based firewall rules
	- rules are enforced on service regardless of what node they may be running on and are maintained by Consul via the Raft consensus protocol for fast consistency
	- active connections are _not_ killed/reset
- intentions can be set via the API, CLI, or UI
	- at scale, using the Consul provider for Terraform will enable intentions (and other Consul artifacts) to be managed as code with a tight VCS-driven workflow

### CLI

- exec into Consul node and set Intentions

`sudo kubectl exec -it hashicorp-consul-server-0 /bin/sh`

`consul intention create -deny dashboard counting`

- go to dashboard UI and verify a negative value, meaning the connection has been broken between the dashboard and counting service
- reset the intention

`consul intention delete dashboard counting`

- leave exec session

`exit`

### UI

1. Intentions > `Create`
2. Select source service `dashboard`
3. Select destination service `counting`
4. Select `deny`
5. Click `Save`

- configuration

![image](/images/consul_intentions_ui00.png)

- after saving the intention, note the Precedence value which is how Consul determines which intention to force if there is overlap; see the [docs for more info](https://www.consul.io/docs/connect/intentions.html#precedence-and-match-order)

![image](/images/consul_intentions_ui01.png)

- guidance is offered on least-privilege access of Consul ACLs required to set intentions and service behaviors around read access by default versus have an intention hard-coded into the service definition so read access is not required

## Upgrade or Modify Consul via Helm

- create a new custom value file with CatalogSync enabled
	- this will synchronize services between Consul and Kubernetes

```

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

```

- use the Helm upgrade command to update Consul with the new values

`sudo helm upgrade hashicorp -f ~/helm-consul-values2.yaml ./consul-helm`

- it will take a moment, but a new pod will be loaded called `hashicorp-consul-sync-catalog-...`
- from the Services menu of the Consul UI, view the synchronized services

![image](/images/minikube-consul-ui-k8s.png)
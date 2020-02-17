# Consul Minikube Walkthrough

intro to Consul and Kubernetes using Minikube on an Ubuntu VM, next step is Consul on a managed Kubernetes instances (AKS, EKS, GKS) [here]()

## Goals

- Deploy Consul on Kubernetes Minikube using official Helm chart
- Sandbox environment with services using discovery and Connect Service Mesh

[official learn.hashicorp guide](https://learn.hashicorp.com/consul/getting-started-k8s/minikube)

## Terraform Code

https://github.com/raygj/consul-content/tree/master/kubernetes/consul-minikube/terraform

- Ubuntu VM
- Terraform to deploy VM and bootstrap Ubuntu
- adapt for your target cloud provider

## Steps

1. deploy and bootstrap Ubuntu VM
2. deploy Consul with Helm
3. access Consul agents
4. deploy two services that use Consul to discover each other and communicate over TLS via Consul Connect
5. cleanup

## Step 1

- 
# Consul Docker Walkthrough

## Goal

Join Consul clients running in Docker to a non-Docker Consul server

[official learn.hashicorp guide](https://learn.hashicorp.com/consul/day-0/containers-guide)

## Environment

Single CentOS 7 host, running Consul and Docker

### Terraform Bootstrap

Terraform code with bootstrap script to prepare CentOS and install Consul service

## Steps

1. Deploy CentOS host
2. Bootstrap host
3. Validate Consul and Docker operations
4. Run Docker Consul client images
5. Interact with Consul
6. Walkthrough light maintenance activities
7. Destroy

# Step 1: Deploy CentOS7 host

- use TF code and check syslog for any errors before continuing

# Step 2: Bootstrap host with provided script

- use TF code and bash script
- set desired Consul version
- add/remove packages
- check syslog for any errors before continuing

# Step 3: Validate Consul and Docker operations

- after bootstrap is complete, validate Consul and Docker
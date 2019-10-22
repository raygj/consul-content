# Consul Docker Walkthrough

## Goal

Join Consul clients running in Docker to a non-Docker Consul server

[official learn.hashicorp guide](https://learn.hashicorp.com/consul/day-0/containers-guide)

## Environment

Single Ubuntu host, running Consul and Docker

### Terraform Bootstrap

Terraform code with bootstrap script to prepare Ubuntu and install Consul service
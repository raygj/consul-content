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
4. Connect a Docker Consul client
5. Connect a Docker Consul client and register a service
6. Use Consul DNS for Discovery
7. Docker and Consul Commands

# Step 1: Deploy CentOS7 host

- use TF code and check syslog for any errors before continuing

# Step 2: Bootstrap host with provided script

- use TF code and bash script
- set desired Consul version
- add/remove packages
- check syslog for any errors before continuing

# Step 3: Validate Consul and Docker operations

- after bootstrap is complete, validate Consul and Docker

`sudo systemctl status consul`

`sudo systemctl status docker`

- if needed, start the service(s) and check for errors, then issue these commands to validate services are operational:

`consul members`

`sudo docker ps`

## Get Docker images

`sudo docker pull consul`

# Step 4: Run a Consul Client

first, run in Docker attached mode:

```

sudo docker run \
   --name=fishstick \
   consul agent -node=client-1 -join=192.168.1.195
   
```

you should see messages such as "Joining cluster..." and "Consul agent running!"

## validate counting service is up

from CLI `curl http://localhost:9001` or from a web broswer

## validate client has joined the cluster

open a new terminal session to the Consul host, and issue:

`consul members`

you should see the client that you started in the other terminal session _client-1_

```

[jray@sandbox-1 ~]$ consul members
Node       Address             Status  Type    Build  Protocol  DC   Segment
sandbox-1  192.168.1.195:8301  alive   server  1.6.1  2         dc1  <all>
client-1   172.17.0.2:8301     alive   client  1.6.1  2         dc1  <default>

```

# Step 5: Run a Consul Client and Register a Service

_open a third terminal session_

use the HashiCorp demo "counting service" as a lightweight demo service:

`sudo docker pull hashicorp/counting-service:0.0.2`

start the counting service container:

```

sudo docker run \
   -p 9001:9001 \
   -d \
   --name=weasel \
   hashicorp/counting-service:0.0.2

```

create a service definition for the first container you started in Step 4:

`sudo docker exec fishstick /bin/sh -c "echo '{\"service\": {\"name\": \"counting\", \"tags\": [\"go\"], \"port\": 9001}}' >> /consul/config/counting.json"`

reload the container you started in Step 4 to read the new Consul configuration file you just wrote:

`sudo docker exec fishstick consul reload`

## validate service was registered

if you go back to the original terminal window, you will see a message such as "Reloading configuration..." "Synced service "counting"

```

    2019/10/22 21:14:49 [INFO] agent: Caught signal:  hangup
    2019/10/22 21:14:49 [INFO] agent: Reloading configuration...
    2019/10/22 21:14:49 [INFO] agent: Synced service "counting"

```

you can also verify this in the Consul UI, browse to `http://< your Consul host >:8500

# Step 6: Consul DNS for Discovery

perform a "discovery" test using the DNS utility **dig** to find the IP address of the counting service:

`dig @127.0.0.1 -p 8600 counting.service.consul`

this should return the IP address of the Docker container

# Step 7: Docker and Consul Commands

these sample commands were pulled from the [HashiCorp Guide](https://learn.hashicorp.com/consul/day-0/containers-guide#consul-container-maintenance-operations), there are others in the guide that may be of interest

- gather running containers and info such as container ID:

`sudo docker ps`

- execute commands in the container:

`sudo docker exec <container_id> consul members`

- issue commands inside of your container by opening an interactive shell and using the Consul binary included in the container:

`sudo docker exec -it <container_id> /bin/sh`

- stop a container:

`sudo docker stop <container_id>`

**note on cleanup**

As long as there are enough servers in the datacenter to maintain quorum, Consul's autopilot feature will handle removing servers whose containers were stopped. Autopilot's default settings are already configured correctly.

# Cleanup Environment

- stop containers
- stop consul service
- terraform destroy environment

# Appendix: Multiple Containers, Single Consul Client

we can take the basic setup from above and extrapolate it a bit into a common use case: single host running multiple instances of the same service. this introduces a new challenge of managing connectivity to instances as they are instantiated or stopped. also, we want clients to have a consistent (not necessarily human-friendly) port to access our service.

so the pattern is to register each service uniquely with Consul as it is instantiated so Consul can register the instance, and provide it as a discovery response. at this point Consul could act as a load balancer and round-robin DNS responses to the two services...or we could add another layer in the form of a Nginx load balancer and then manage the configuration of Nginx via Consul Template. so as the lifecycle of services occurs, Nginx's configuration will reflect only healthy services.

realistically, this scenario may push the limits of effectiveness of a "single VM and Docker" and would be better served to [schedule the containers via Nomad](https://www.nomadproject.io/docs/internals/scheduling/scheduling.html) and using [Consul Connect on Nomad](https://www.consul.io/docs/connect/platform/nomad.html).




## Create two instances of the same counting service

- instance 1, badger:

```

sudo docker run \
   -p 9002:9002 \
   -d \
   --name=badger \
   hashicorp/counting-service:0.0.2

```

- modify the consul config, with the corresponding ports:

sudo docker exec fishstick /bin/sh -c "echo '{\"service\": {\"name\": \"counting\", \"tags\": [\"go\"], \"port\": 9002}}' >> /consul/config/counting.json"

- instance 2, bear:

```

sudo docker run \
   -p 9003:9003 \
   -d \
   --name=bear \
   hashicorp/counting-service:0.0.2

```

- modify the consul config, with the corresponding ports:
   
`sudo docker exec fishstick /bin/sh -c "echo '{\"service\": {\"name\": \"counting\", \"tags\": [\"go\"], \"port\": 9003}}' >> /consul/config/counting.json"`
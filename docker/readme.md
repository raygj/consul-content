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
- TF code calls a basic `bootsraph.sh` script that will install packages
	- add/remove packages in this script prior to running TF apply
- TF will also copy `consul-install.sh` script for installing Consul and `counting-service.zip` that contains the _counting-service_ binary

# Step 2: Install Consul

- `consul-install.sh` was copied by TF to /tmp
- open script, set desired Consul version on line 17
- assuming a single Consul server was deployed, execute the script with something like `sudo ./tmp/consul-install.sh < IP address of VM >`
	- the script will grab the IP address and use it to populate Consul config files
	- there are occasions when the script completes, but throws erros re: firewalld configuration...if so, just rerun the script
- check syslog for any errors before continuing
- start Consul `sudo systemctl start consul`

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

gracefully stop `ctrl-c` and then start in detached mode:

```

sudo docker rm fishstick

sudo docker run -d \
   --name=fishstick \
   consul agent -node=counting-service-host -join=192.168.1.195
   
```


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

## start the Consul container in detached mode

**note** this is the Consul instance running in Client mode that will be used to register services from containers to Consul, which is why you'd run it detached once validation from the previous step is completed

from the existing terminal where you having an interactive container running, gracefully stop the container with `ctrl-c` and then start in detached mode:

```

sudo docker rm fishstick

sudo docker run -d \
   --name=fishstick \
   consul agent -node=counting-service-host -join=192.168.1.195
   
```

**note** in this step we are changing the node name to be more descriptive for the Consul UI


## validate counting service is up

from CLI `curl http://localhost:9001` or from a web broswer

you will see a respons such as:

```

[jray@esxi-sandbox ~]$ curl http://localhost:9001
{"count":1,"hostname":"007bbff89134"}[jray@esxi-sandbox ~]$

```

# Step 5: Register the Counting Service with Consul

recall that Consul is running on the VM, not in a Docker container, _open a second terminal session_...

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

# Appendix: Multiple Containers, Single VM...and single Consul Client

we can take the basic setup from above and extrapolate it a bit into a common use case: single host running multiple instances of the same service. [Docker Compose](https://docs.docker.com/compose/) is used to define the app environment in a `Dockerfile`, define one or more services in a `docker-compose.yml` file, and then run them all with one command, `docker-compose up`. sort of a Kubernetes `configmap`.

this architecture introduces a new challenges:

- managing connectivity to instances as they are instantiated or stopped
- maintaining a known, consistent (not necessarily human-friendly) port to access our service

the pattern i am looking to validate is this: is each service registered uniquely with Consul as it is instantiated...so Consul can include the unique instances to provide instances with discovery responses? at this point Consul could act as a load balancer and round-robin DNS responses to the two services...or we could add another layer in the form of a Nginx load balancer and then manage the configuration of Nginx via Consul Template. so as the lifecycle of services occurs, Nginx's configuration will reflect only healthy services.

realistically, this scenario may push the limits of effectiveness of a "single VM and Docker" and would be better served to [schedule the containers via Nomad](https://www.nomadproject.io/docs/internals/scheduling/scheduling.html) and using [Consul Connect on Nomad](https://www.consul.io/docs/connect/platform/nomad.html). that said, there is a lot of Docker in the wild (some being managed by Rancher, Swarm, etc.).

![diagram](/docker/images/consul-docker-lab.png)

## Create two instances of the same counting service

### configure and start two instances

#### create working dir on Docker host

`mkdir ~/counting-service-compose/`

#### prepare counting-service binary

git clone repo, unzip/move `counting-service` binary that will be built into the container in the next steps

```

cd ~/counting-service-compose/

git clone https://github.com/raygj/consul-content

cp consul-content/docker/counting-service/counting-service ~/counting-service-compose/

```

**note** Docker Compose will use the working directory as a source for container naming and management components

#### create a Dockerfile

[official](https://docs.docker.com/engine/reference/builder/#cmd)guide

```

nano ~/counting-service-compose/Dockerfile

FROM alpine:3.7
WORKDIR /usr/src/app
COPY counting-service .
CMD ["./counting-service"]

```

#### create docker-compose config

this will define the instances and expose each at on unique port

```

nano ~/counting-service-compose/docker-compose.yml

version: '3'
services:
  inst-1-badger:
   build: ./
   ports:
    - '9002:9002'
   working_dir: /usr/src/app

  inst-2-bear:
   build: ./
   expose:
    - '9003'
   working_dir: /usr/src/app

```

**note** to increase your confidence in proper YAML formating, use [this YAML validator](https://codebeautify.org/yaml-validator)

#### build

```
sudo `which docker-compose` build
```

#### run

```
sudo `which docker-compose` up
```

both containers should be up now, `docker_inst-1-badger` and `docker_inst-2-bear`

```
sudo `which docker-compose` ps
```

try a curl to both, with optional trace in the event you need to debug:

`curl http://localhost:9002 --trace-ascii dump1.txt`

`curl http://localhost:9003 --trace-ascii dump2.txt`

## Docker Compose Bootstrap

Docker Compose and dependencies are installed within the `bootstrap.sh` script, run as a part of the TF boostrap process; the source is here in the [/terrafrom/templates directory](https://github.com/raygj/consul-content/tree/master/docker/terraform/templates)

[install](https://docs.docker.com/compose/install/) guide

- dependencies:

`sudo yum install -y python-dev py-pip libffi-dev openssl-dev gcc libc-dev make`

- Docker Compose

`sudo curl -L "https://github.com/docker/compose/releases/download/1.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose`

`sudo chmod +x /usr/local/bin/docker-compose`

- test Docker Compose

```
sudo `which docker-compose` --version
```
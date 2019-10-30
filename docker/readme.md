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

we can take the basic setup from above and extrapolate it a bit into a common use case: single host running multiple services (if they were multiple instances of the same service, `replicas` or a scheduler should be used.

we can use [Docker Compose](https://docs.docker.com/compose/) to make it easier to instantiate multiple containers at once.

a `Dockerfile` is created for each service, one or more services is then defined in a single `docker-compose.yml` file, and then `docker-compose up` to start all services (containers) - sort of a Kubernetes `configmap`.

this architecture introduces new challenges:

- managing connectivity to services as they are instantiated or stopped
- maintaining a known, consistent (not necessarily human-friendly) port to access our service

the pattern i am looking to validate is this: is each service registered uniquely with Consul as it is instantiated...so Consul can include the unique instances in a discovery responses? at this point Consul could act as a load balancer and round-robin DNS responses to the two of instances of the same service...or we could add another layer in the form of a Nginx load balancer and then manage the configuration of Nginx via Consul Template. so as the lifecycle of services occurs, Nginx's configuration will reflect only healthy services.

realistically, this scenario may push the limits of effectiveness of a "single VM and Docker" and would be better served to [schedule the containers via Nomad](https://www.nomadproject.io/docs/internals/scheduling/scheduling.html) and using [Consul Connect on Nomad](https://www.consul.io/docs/connect/platform/nomad.html). that said, there is a lot of Docker in the wild (some being managed by Rancher, Swarm, etc.).

![diagram](/docker/images/consul-docker-lab.png)


# NodeJS and MySQL Example

[source](https://dwmkerr.com/learn-docker-by-building-a-microservice/)

[Nic Jackson demo](https://github.com/hashicorp/da-connect-demo)

## MySQL

### create database scripts and Dockerfile

`mkdir -p ~/docker/node-docker-microservice`

`git clone https://github.com/dwmkerr/node-docker-microservice.git`

or manually create files in the next few steps:

`mkdir ~/docker/node-docker-microservice/test-database`

- create `setup.sql` that will be called in Dockerfile

```

cat << EOF > ~/docker/node-docker-microservice/test-database/setup.sql

create table directory (user_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, email TEXT, phone_number TEXT);

insert into directory (email, phone_number) values ('homer@thesimpsons.com', '+1 888 123 1111');
insert into directory (email, phone_number) values ('marge@thesimpsons.com', '+1 888 123 1112');
insert into directory (email, phone_number) values ('maggie@thesimpsons.com', '+1 888 123 1113');
insert into directory (email, phone_number) values ('lisa@thesimpsons.com', '+1 888 123 1114');
insert into directory (email, phone_number) values ('bart@thesimpsons.com', '+1 888 123 1115');
EOF

```

- Dockerfile that sets MySQL and calls `setup.sql` created in the previous step

```

cat <<EOF > ~/docker/node-docker-microservice/test-database/Dockerfile

FROM mysql:5

ENV MYSQL_ROOT_PASSWORD 123
ENV MYSQL_DATABASE users
ENV MYSQL_USER users_service
ENV MYSQL_PASSWORD 123

ADD setup.sql /docker-entrypoint-initdb.d
EOF

```

## node setup

### create required files

- create directory structure

`cd ~/docker/`

`git clone https://github.com/dwmkerr/node-docker-microservice.git`

### quick test

- build a new image

`cd ~/docker/node-docker-microservice/users-service`

`sudo docker build -t node4 .`

- run a container with this image, in interactive mode

`sudo docker run -it node4`

- interace with node process

at the `>` prompt issue `process.version`

response such as `'v4.9.1'`

then, at the `>` prompt issue `process.exit(0)` to close the service connection

- at this point we have a functional node container

### modify node Dockerfile

- modify Dockerfile

```

cat << EOF > ~/docker/users-service/Dockerfile

# Use Node v4 as the base image.
FROM node:4

# Add everything in the current directory to our image, in the 'app' folder.
ADD . /app

# Install dependencies
RUN cd /app; \
    npm install --production

# Expose our server port.
EXPOSE 8123

# Run our app.
CMD ["node", "/app/index.js"]
EOF

```

- test again with the updated Dockerfile

`cd ~/docker/node-docker-microservice/users-service`

`sudo docker build -t users-service .`

`sudo docker run -it -p 8123:8123 users-service`

curl test:

`curl http://192.168.1.195:8123`

## Check In

at this point we've got two containers that are functional, but not working together because the containers were not `linked` and therefore there is no connectivity between them. in this next section, we could link them and test, then add Consul to the mix...but it will be more interesting if we used Docker-Compose to bring up both containers together (linked) as a stack with Consul included in the Docker-Comopose file. 

we would then have two containers, communicating and registering their services (and health checks) with Consul. we would then build off this by adding Consul Connect to provide connectivity between containers without linking them.

a final scenario would be add nginx as a front-end load balancer to the API service, and then using Consul Template to update nginx's configuration as node services were added or removed so clients would assured a health response.

# Docker-Compose and Consul

we will use the NodeJS and MySQL containers to create a Docker-Compose configuration that includes Consul in client mode that will register the services

## create Consul Dockerfile and Consul agent JSON files

- references:

https://www.consul.io/docs/agent/services.html

https://www.consul.io/docs/agent/checks.html#service-bound-checks

https://imaginea.gitbooks.io/consul-devops-handbook/content/agent_configuration.html

https://learn.hashicorp.com/consul/integrations/nginx-consul-template

JSON linter: https://jsonlint.com

- create a local directory for Consul configuration files
- this dir will ultimately be copied to the container via the Docker file

`mkdir ~/docker/node-docker-microservice/consul`

```

cat << EOF > ~/docker/node-docker-microservice/consul/Dockerfile
FROM consul:latest
ADD . /consul/config
RUN agent -retry-join -bind=0.0.0.0 >> ~/consul/log/output.log &
EXPOSE 8301
EXPOSE 8301 8301/udp 8302 8302/udp
EXPOSE 8500 8600 8600/udp  
EOF

```

[reference](https://github.com/hashicorp/da-connect-demo/blob/master/docker_build/Dockerfile.consul_agent)

```

cat << EOF > ~/docker/node-docker-microservice/consul/users-service.json

{
	"bind_addr": "0.0.0.0",
	"datacenter": "dc1",
	"node_name": "sandbox-docker",
	"server": false,
	"service": {
		"name": "user-service-api",
		"tags": ["nodejs"],
		"port": 8123
	},
	"rejoin_after_leave": true,
	"retry_join": ["192.168.1.195"]
}
EOF

```


**need to resolve** broken health check version:

{
    "bind_addr": "0.0.0.0",
	"datacenter": "dc1",
	"node_name": "sandbox-docker",
	"server": false,
	"service": {
		"name": "user-service-api",
		"tags": ["nodejs"],
		"port": 8123,
		"check": {
			"id": "user-service-api",
			"name": "User Service API Status",
			"service_id": "user-service-api",
			"ttl": "5s"
						
		}
	},
	"rejoin_after_leave": true,
	"retry_join": ["192.168.1.195"]
}

research using Lighthouse: https://expressjs.com/en/advanced/healthcheck-graceful-shutdown.html or a simple local script?

```

cat << EOF > ~/docker/node-docker-microservice/consul/users-service-mysql.json

{
	"bind_addr": "0.0.0.0",
	"datacenter": "dc1",
	"node_name": "sandbox-docker",
	"server": false,
	"service": {
		"name": "user-service-mysql",
		"tags": ["mysql"],
		"port": 3306
	},
	"rejoin_after_leave": true,
	"retry_join": ["192.168.1.195"]
}
EOF

```

**need to resolve** broken health check version:

{
    "bind_addr": "0.0.0.0",
	"datacenter": "dc1",
	"node_name": "sandbox-docker",
	"server": false,
	"service": {
		"name": "user-service-mysql",
		"tags": ["mysql"],
		"port": 3306,
		"check": {
			"id": "user-service-mysql",
			"name": "User Service API MySQL Instance",
			"service_id": "user-service-mysql",
			"ttl": "5s"
		}
	},
	"rejoin_after_leave": true,
	"retry_join": ["192.168.1.195"]
}

here's a link to a MySQL health script: https://gist.github.com/aw/1071144 that could be loaded and then called by Consul
Consul doc on health checks: https://www.consul.io/docs/agent/checks.html#service-bound-checks

## create Docker-Compose file

defines users-service and db containers, creates relationship between the two

```

cat << EOF > ~/docker/node-docker-microservice/docker-compose.yml

version: '3'
services:
  users-service:
    build: ./users-service
    ports:
     - "8123:8123"
    depends_on:
     - db
    environment:
     - DATABASE_HOST=db
  db:
    build: ./test-database

  consul-agent:
    build: ./consul
EOF

```

#### build

```
cd ~/docker/node-docker-microservice

sudo `which docker-compose` build

```

#### run

```
cd ~/docker/node-docker-microservice

sudo `which docker-compose` up

```

# Docker-Compose Consul

## Docker Compose Consul code

[source](https://github.com/hashicorp/consul/blob/master/demo/docker-compose-cluster/docker-compose.yml)

**note** for this scenario, the Consul Server is running on the Docker host VM, so the service `consul-server-1` , `consul-server-2` , and `consul-server-bootstrap` in this Docker Compose file could be eliminated


```

version: '3'

services:

  consul-agent-1: &consul-agent
    image: consul:latest
    networks:
      - consul-demo
    command: "agent -retry-join consul-server-bootstrap -client 0.0.0.0"

  consul-agent-2:
    <<: *consul-agent

  consul-agent-3:
    <<: *consul-agent

  consul-server-1: &consul-server
    <<: *consul-agent
    command: "agent -server -retry-join consul-server-bootstrap -client 0.0.0.0"

  consul-server-2:
    <<: *consul-server

  consul-server-bootstrap:
    <<: *consul-agent
    ports:
      - "8400:8400"
      - "8500:8500"
      - "8600:8600"
      - "8600:8600/udp"
    command: "agent -server -bootstrap-expect 3 -ui -client 0.0.0.0"

networks:
  consul-demo:

```

# Appendix: DA-Connect Demo

[source](https://github.com/hashicorp/da-connect-demo) Nic Jackson demo

### code

**note** for this guide, the Consul Server is running on the Docker host VM, so the first service `consul_server` in this Docker Compose file could be eliminated

```

version: '3'
services:

  consul_server:
    image: nicholasjackson/consul_connect:latest
    environment:
      CONSUL_BIND_INTERFACE: eth0
      CONSUL_UI_BETA: "true"
    ports:
      - "8501:8500"
    networks:
      connect_network: {}
  
  service1:
    image: nicholasjackson/consul_connect_agent:latest
    volumes:
      - "./connect_service1a.json:/servicea.json"
      - "./connect_service1b.json:/serviceb.json"
    networks:
      connect_network: {}
    environment:
      CONSUL_BIND_INTERFACE: eth0
      CONSUL_CLIENT_INTERFACE: eth0
    command:
      - "-retry-join"
      - "consul_server"
  
  service2:
    image: nicholasjackson/consul_connect_agent:latest
    volumes:
      - "./connect_service1a.json:/servicea.json"
      - "./connect_service1b.json:/serviceb.json"
    networks:
      connect_network: {}
    environment:
      CONSUL_BIND_INTERFACE: eth0
      CONSUL_CLIENT_INTERFACE: eth0
    command:
      - "-retry-join"
      - "consul_server"

networks:
  connect_network:
    external: false
    driver: bridge

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

# Appendix: TCPdump Container

mkdir ~/docker/tcpdump

cd ~/docker/tcpdump

sudo docker build -t tcpdump - <<EOF 
FROM ubuntu 
RUN apt-get install -y tcpdump 
CMD tcpdump -i eth0 
EOF

docker run -it --net=container:< container name > tcpdump tcpdump port 80

# Appendix: Client-Server Walkthrough

WIP: look into using this guide to create a client-server container as an example of containerized service

https://www.freecodecamp.org/news/a-beginners-guide-to-docker-how-to-create-a-client-server-side-with-docker-compose-12c8cf0ae0aa/
# Consul Docker Walkthrough

## Goal

Join Consul clients running in Docker to a non-Docker Consul instance to show how the Consul Agent can be injected into a container, register services, and perform health checks.

[official learn.hashicorp guide](https://learn.hashicorp.com/consul/day-0/containers-guide)

## Environment

Single CentOS 7 VM, running single-node Consul server and Docker

### Terraform Bootstrap

Terraform code with bootstrap script to prepare CentOS and install single-node Consul server

## Steps

1. Deploy CentOS host
2. Bootstrap host
3. Validate Consul and Docker operations
4. Connect a Docker Consul client
5. Connect a Docker Consul client and register a service
6. Use Consul DNS for Discovery
7. Docker and Consul Commands

**Appendices**

1. Docker-Compose, multi-container walkthrough

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

# Appendix 1: Multiple Containers, Single VM...and single Consul Agent

we can take the basic setup from above and extrapolate it a bit into a common use case: single host running multiple services.

we can use [Docker Compose](https://docs.docker.com/compose/) to make it easier to instantiate multiple containers at once.

## Approach

a `Dockerfile` is created for each service, one or more services is then defined in a single `docker-compose.yml` file, and then `docker-compose build/up` is used to compile and start all services (containers).

the pattern i am looking to validate is this: is each service registered uniquely with Consul as it is instantiated...so Consul can include the unique instances in a discovery responses? at this point Consul could act as a load balancer and round-robin DNS responses to the two of instances of the same service...or we could add another layer in the form of a Nginx load balancer and then manage the configuration of Nginx via Consul Template. so as the lifecycle of services occurs, [Nginx's configuration](https://learn.hashicorp.com/consul/integrations/nginx-consul-template) will reflect only healthy services.

realistically, this scenario may push the limits of effectiveness of a "single VM and Docker" and would be better served to [schedule the containers via Nomad](https://www.nomadproject.io/docs/internals/scheduling/scheduling.html). that said, there is a lot of Docker in the wild (some being managed by Rancher, Swarm, etc.).

## NodeJS and MySQL Example

- build a NodeJS and MySQL container, register with Consul Agent container, and perform health checks
- start with Docker-Compose, then stop an individual container to show Consul health checks in action

[code source](https://dwmkerr.com/learn-docker-by-building-a-microservice/)

[Nic Jackson demo reference](https://github.com/hashicorp/da-connect-demo)

### MySQL Container

1. create directory structure

`mkdir -p ~/docker/node-docker-microservice/test-database`

2. create database scripts

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

3. create mysql Dockerfile

- Dockerfile that sets MySQL and calls `setup.sql` created in the previous step

```

cat <<EOF > ~/docker/node-docker-microservice/test-database/Dockerfile

FROM mysql:5

ENV MYSQL_ROOT_PASSWORD 123
ENV MYSQL_DATABASE users
ENV MYSQL_USER users_service
ENV MYSQL_PASSWORD 123

ADD setup.sql /docker-entrypoint-initdb.d

EXPOSE 3306
EOF

```

### NodeJS Container

1. create directory structure

`cd ~/docker/`

`wget https://github.com/raygj/consul-content/archive/master.zip`

`unzip master.zip`

`cp consul-content-master/docker/node-docker-microservice/ ~/docker`

2. create node Dockerfile

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
3. build an image

`cd ~/docker/node-docker-microservice/users-service`

`sudo docker build -t node4 .`

4. run a container with this image, in interactive mode

`sudo docker run -it node4`

- interace with node process

at the `>` prompt issue `process.version`

response such as `'v4.9.1'`

then, at the `>` prompt issue `process.exit(0)` to close the service connection

- at this point we have a functional node container

5. test the Node container is listening

`cd ~/docker/node-docker-microservice/users-service`

`sudo docker build -t users-service .`

`sudo docker run -it -p 8123:8123 users-service`

- curl test:

`curl http://192.168.1.195:8123`

- assuming success, stop the container before moving on

`sudo docker ps`

**grab** the container ID and use it in the next command

`sudo docker stop < container ID >`

## Check In

at this point we've got two containers that are functional. it will be more interesting if we use Docker-Compose to bring up both containers together (linked) as a stack with Consul included in the Docker-Comopose file. 

we would then have two containers, communicating and registering their services (and health checks) with Consul. we would then build off this by adding Consul Connect to provide connectivity between containers without linking them.

a final scenario would be add nginx as a front-end load balancer to the API service, and then using Consul Template to update nginx's configuration as node services were added or removed so clients would assured a health response.

this is what we are going to build:

[diagram](/docker/images/consul-docker-lab-crawl-stage.png)

### Docker-Compose Bootstrap

we will use the NodeJS and MySQL containers we just defined in the last section within a single Docker-Compose configuration that includes Consul in client/agent mode. we will include a Consul configuration that will register the MySQL and Node services.

if you used the included Terraform and [bootstrap.sh](https://github.com/raygj/consul-content/blob/master/docker/terraform/templates/bootstrap.sh) script, Docker-Compose is already installed, otherwise, see the [included Appendix](https://github.com/raygj/consul-content/tree/master/docker#appendix-docker-compose-bootstrap) for install steps.

## Consul Agent Container

- Consul container references:

	- https://www.consul.io/docs/agent/services.html

	- https://www.consul.io/docs/agent/checks.html#service-bound-checks

	- https://imaginea.gitbooks.io/consul-devops-handbook/content/agent_configuration.html

1. create a local directory for Consul configuration files; this dir will ultimately be copied to the container via the Docker file

`mkdir ~/docker/node-docker-microservice/consul`

2. create Consul Dockerfile

- write Dockerfile for Consul Agent container that includes `ADD` argument to copy all files from the source dir to the container

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

3. write Consul Agent JSON configuration files for Node and MySQL services that will be imported into the container [reference](https://github.com/hashicorp/da-connect-demo/blob/master/docker_build/Dockerfile.consul_agent)

- Node (users-service) definition:
- if needed, use this [JSON linter](https://jsonlint.com) to make sure your code is clean

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

- MySQL (users-service-mysql) defintion:

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

4. create Docker-Compose file

- defines users-service and db containers, creates relationship between the two
- note, the node `users-service` contains a Docker `environment` argument to set an env var for `DATABASE_HOST` to `db` which is the DNS name set in the local HOSTS file of the container
- see [this reference](https://docs.docker.com/compose/environment-variables/), implication is that [envconsul](https://hub.docker.com/r/hashicorp/envconsul/) can be used to set this env var after the container is running OR an external process could be run to re-instantiate the container based on a Consul watch when DB host value needs to change (much like a setting a new password value) - it's just as efficient or more so, to instantiate a new container rather than [mutate a running one](https://cloud.google.com/solutions/best-practices-for-operating-containers).

```

cat << EOF > ~/docker/node-docker-microservice/docker-compose.yml

version: '3'
services:
  users-service:
    container_name: node-srv-1
    build: ./users-service
    ports:
     - "8123:8123"
    depends_on:
     - db
    environment:
     - DATABASE_HOST=db
  db:
    container_name: mysql-srv-1
    build: ./test-database
    ports:
     - "3306:3306"
  consul-agent:
    container_name: consul-agent-1
    build: ./consul
EOF

```

5. build the containers using the previously-defined Dockerfiles

```
cd ~/docker/node-docker-microservice

sudo `which docker-compose` build

```

**note** if you encounter errors while building the container images, you may need to fix the underlying problem and then run `sudo `which docker-compose` build --no-cache` to build the images cleanly

6. run the containers using the docker-compose configuration

```
cd ~/docker/node-docker-microservice

sudo `which docker-compose` up

```

- view containers:

```

CONTAINER ID        IMAGE                                    COMMAND                  CREATED             STATUS              PORTS                                                        NAMES
d0766ee27606        node-docker-microservice_users-service   "node /app/index.js"     17 seconds ago      Up 16 seconds       0.0.0.0:8123->8123/tcp                                       node-srv-1
058deb39b320        node-docker-microservice_db              "docker-entrypoint..."   18 seconds ago      Up 17 seconds       0.0.0.0:3306->3306/tcp, 33060/tcp                            mysql-srv-1
ca9154ab3110        node-docker-microservice_consul-agent    "docker-entrypoint..."   18 seconds ago      Up 17 seconds       8300-8302/tcp, 8500/tcp, 8301-8302/udp, 8600/tcp, 8600/udp   consul-agent-1

```

7. test connectivity and service registration

- from a browser

`http://192.168.1.195:8123/search?email=lisa@thesimpsons.com`

	- valid response:

```

{"email":"lisa@thesimpsons.com","phoneNumber":"+1 888 123 1114"}

```

- check Consul UI for registered services

`http://< IP of VM >:8500`

**dc1 > Services**


### troubleshooting

- view logs of container `mysql-srv-1`

`sudo docker logs mysql-srv-1 | tail -n 2`

- interactive (-it) command line access to container `node-srv-1`, from here you can issue any normal *nix CLI commands

`sudo docker exec -it node-srv-1 /bin/bash`

- print env var from container `node-docker-microservice_users-service_1`

`sudo docker exec node-srv-1 printenv | grep DATABASE`

- view HOSTS file of container named `node-srv-1`

`sudo docker exec node-srv-1 cat /etc/hosts`

- view all containers

`sudo docker container ls -a`

- remove container from local library (helpful when rebuilding container with same name)

`sudo docker rm < container ID >

- exec to mysql container and log into database with creds used by node `config.js`

`sudo docker exec -it mysql-srv-1 /bin/bash`

`mysql -uusers_service -p123`

	- show database, connect to `users` database

`show databases;`

`use users;`

	- view tables, view data

`SHOW TABLES;`

`SELECT * FROM directory`

`exit`

#### docker env vars

additional work that can be done to obfuscate secrets or provide automation during container builds, see [this reference blog post](https://medium.com/better-programming/using-variables-in-docker-compose-265a604c2006)

# Next Steps

- configure a more in-depth Consul health check for Node and MySQL services
- deploy another Docker VM to host a few more instances of the Node container and a Consul Agent sidecar
- register all instances with Consul datacenter
- deploy a Nginx service to front-end the Node microservices with a dynamic configuration driven by Consul Template
	- fail instances or whole VMs to demo dynamic configuration of Nginx to keep the service healthy and available

# Appendix: Docker Compose Bootstrap

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

- create directory for tcpdump container files

`mkdir ~/docker/tcpdump`

- define container and run

```

cd ~/docker/tcpdump

sudo docker build -t tcpdump - <<EOF 
FROM ubuntu 
RUN apt-get install -y tcpdump 
CMD tcpdump -i eth0 
EOF

sudo docker run -it --net=container:< container name > tcpdump tcpdump port < target port to capture >

```
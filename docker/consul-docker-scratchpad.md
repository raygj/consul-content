# scratchpad and backlog of other use cases

mostly naive first-attempt scribblings

but there could be some value in exploring the env var function - to automate the build process using values from Consul KV, set by envconsul, then kickoff the Docker build



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


# Appendix: Client-Server Walkthrough

WIP: look into using this guide to create a client-server container as an example of containerized service

https://www.freecodecamp.org/news/a-beginners-guide-to-docker-how-to-create-a-client-server-side-with-docker-compose-12c8cf0ae0aa/


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

mkdir ~/docker/tcpdump

cd ~/docker/tcpdump

sudo docker build -t tcpdump - <<EOF 
FROM ubuntu 
RUN apt-get install -y tcpdump 
CMD tcpdump -i eth0 
EOF

docker run -it --net=container:< container name > tcpdump tcpdump port 80



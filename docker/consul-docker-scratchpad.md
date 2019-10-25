# scratchpad

mostly naive first-attempt scribblings

but there could be some value in exploring the env var function - to automate the build process using values from Consul KV, set by envconsul, then kickoff the Docker build



## attempt 2

i was able to get the docker-compose to fire up the two containers, but hit a wall on network - i think there is a port conflict because the counting-service is hard-coded to port 9001

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



## attempt 1

instance 1, badger:

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


### set environment variables

- the value of `HOST_PORT` is the port that will be bound on the host VM
- the value of `CONT_PORT` is the port that will be bound on the container

**note** these values must be unique to avoid port conflicts

- instance 1, badger:

```

export INST_1_HOST_PORT=
export INST_1_CONT_PORT=

```

- instance 2, bear:

```

export INST_2_HOST_PORT=
export INST_2_CONT_PORT=

```

- instance 1, badger:

```

sudo docker run \
--env INST_1_HOST_PORT --env INST_1_CONT_PORT \
-d \
--name=badger \
hashicorp/counting-service:0.0.2

ubuntu env | grep VAR



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
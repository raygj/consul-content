# scratchpad

mostly naive first-attempt scribblings

but there could be some value in exploring the env var function - to automate the build process using values from Consul KV, set by envconsul, then kickoff the Docker build



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
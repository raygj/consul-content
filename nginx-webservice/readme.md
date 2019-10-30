# Consul Template NGINX Dynamic Proxy Configuration

register web service instances with Consul, then use Consul Template to render NGINX configuration to reflect healthy instances

[reference learn.hashicorp.com](https://learn.hashicorp.com/consul/integrations/nginx-consul-template)

## Architecture

- Consul Datacenter
- Docker web service instances (simple hello world NodeJS service)
- Docker nginx instance (separate container)

## Steps

1. Deploy Consul Datacenter
2. Create Docker web service instances with Consul Agent
	- Register web service instances
3. Create Docker nginx instance with Consul Agent and Consul-Template
	- Register nginx service
	- Deploy/config Consul-Template
	- Config nginx template
4. Test initial setup
5. Demo adding and removing web service instances, validate dynamic configuration and continued availability of web service


# Step 1: Deploy Consul Datacenter

# Step 2: Create Docker web service instances with Consul Agent

- create a local directory for Consul configuration files
- this dir will ultimately be copied to the container via the Docker file

`mkdir ~/docker/web-srv-nginx/consul`

- write Dockerfile for Consul Agent container that includes `ADD` argument to copy all files from the source dir to the container

```

cat << EOF > ~/docker/web-srv-nginx/consul/Dockerfile
FROM consul:latest
ADD . /consul/config
RUN agent -retry-join -bind=0.0.0.0 >> ~/consul/log/output.log &
EXPOSE 8301
EXPOSE 8301 8301/udp 8302 8302/udp
EXPOSE 8500 8600 8600/udp  
EOF

```

- write Consul Agent configuration file that will be imported into the container

```

cat << EOF > ~/docker/web-srv-nginx/consul/web-service.json

{
	"bind_addr": "0.0.0.0",
	"datacenter": "dc1",
	"node_name": "web-service-inst-1",
	"server": false,
	"enable_local_script_checks": true,
	"service": {
		"name": "web",
		"tags": ["nodejs"],
		"port": "80",
		"check": {
			"args": ["curl", "localhost"],
			"interval": "3s"
		}
	},
	"rejoin_after_leave": true,
	"retry_join": ["192.168.1.195"]
}
EOF

```

**note**

Consul Agent Dockerfile and config would be used to create a container image that could be run in Nomad, K8S, or used as-is and run via Docker-Compose

# Step 3: Create Docker nginx instance with Consul Agent and Consul-Template

# Step 4: Initial Setup

# Step 5: Demo
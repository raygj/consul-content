#!/bin/bash
#
# cd /tmp
# nano setup.sh
# chmod +x setup.sh
# ./setup.sh

# snap remove docker
# apt-get update
# apt-get install -y unzip nano net-tools nmap socat docker

# install or upgrade required utilities
yum install -y nano unzip net-tools nmap docker socat

# docker compose install

yum install -y python-dev py-pip libffi-dev openssl-dev gcc libc-dev make git

curl -L "https://github.com/docker/compose/releases/download/1.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

chmod +x /usr/local/bin/docker-compose
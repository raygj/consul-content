#!/bin/bash
#
# cd /tmp
# nano setup.sh
# chmod +x setup.sh
# ./setup.sh
# Once the script is complete you should be able to start Consul:
#
# systemctl start consul

# snap remove docker
# apt-get update
# apt-get install -y unzip nano net-tools nmap socat docker

# install or upgrade required utilities
yum install -y nano unzip net-tools nmap docker

#!/bin/sh
# This is a setup script meant to be used with the Vault POV Workshop
# https://github.com/TheHob/vault-pov-training
# 
# Once you have stood up your three Vault instances, run the script on each
# machine with your three IP addresses as script arguments. Put the IP address
# of the local machine *first* in the list.
#
# cd /tmp
# nano setup.sh
# chmod +x setup.sh
# ./setup.sh #may need to run as sudo
#
# Once the script is complete you should be able to start Consul:
#
# systemctl start consul

# install or upgrade required utilities
yum install nano -y
yum install unzip -y
yum install open-vm-tools -y
yum install net-tools -y
yum install nmap -y

CLUSTER_COUNT=$#
CONSUL_VERSION="1.6.1"

MYIP=$1
MACHINE1=$2
MACHINE2=$3

# Set up some directories
mkdir -pm 0755 /etc/consul.d
mkdir -pm 0755 /opt/consul/data

# Create Consul online service config
cat << EOF > /etc/systemd/system/consul-online.service
[Unit]
Description=Consul Online
Requires=consul.service
After=consul.service
[Service]
Type=oneshot
ExecStart=/usr/local/bin/consul-online.sh
User=consul
Group=consul
[Install]
WantedBy=consul-online.target multi-user.target
EOF

# Create the Consul online script
cat << EOF > /usr/local/bin/consul-online.sh
#!/usr/bin/env bash
set -e
set -o pipefail
CONSUL_ADDRESS=${1:-"127.0.0.1:8500"}
# waitForConsulToBeAvailable loops until the local Consul agent returns a 200
# response at the /v1/operator/raft/configuration endpoint.
#
# Parameters:
#     None
function waitForConsulToBeAvailable() {
  local consul_addr=$1
  local consul_leader_http_code
  consul_leader_http_code=$(curl --silent --output /dev/null --write-out "%{http_code}" "${consul_addr}/v1/operator/raft/configuration") || consul_leader_http_code=""
  while [ "x${consul_leader_http_code}" != "x200" ] ; do
    echo "Waiting for Consul to get a leader..."
    sleep 5
    consul_leader_http_code=$(curl --silent --output /dev/null --write-out "%{http_code}" "${consul_addr}/v1/operator/raft/configuration") || consul_leader_http_code=""
  done
}
waitForConsulToBeAvailable "${CONSUL_ADDRESS}"
EOF

# Configure the Consul online service target
cat << EOF > /etc/systemd/system/consul-online.target
[Unit]
Description=Consul Online
RefuseManualStart=true
EOF

if [ $CLUSTER_COUNT -eq 1 ]; then
  # Configure the Consul JSON config
  cat << EOF > /etc/consul.d/consul.json
  {
  "server": true,
  "leave_on_terminate": true,
  "advertise_addr": "${MYIP}",
  "data_dir": "/opt/consul/data",
  "client_addr": "0.0.0.0",
  "log_level": "INFO",
  "ui": true
  }
EOF
elif [ $CLUSTER_COUNT -eq 3 ]; then
  # Three node cluster
  cat << EOF > /etc/consul.d/consul.json
  {
  "server": true,
  "bootstrap_expect": 3,
  "leave_on_terminate": true,
  "advertise_addr": "${MYIP}",
  "retry_join": ["${MACHINE1}","${MACHINE2}"],
  "data_dir": "/opt/consul/data",
  "client_addr": "0.0.0.0",
  "log_level": "INFO",
  "ui": true
  }
EOF
else
  echo "Please provide either 1 or 3 IP addresses (single node or 3 node cluster)"
  exit 1
fi
  


# Set up the Consul service script
cat << EOF > /etc/systemd/system/consul.service
[Unit]
Description=Consul Agent
Requires=network-online.target
After=network-online.target
[Service]
Restart=on-failure
ExecStart=/usr/local/bin/consul agent -config-dir /etc/consul.d
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGTERM
User=consul
Group=consul
[Install]
WantedBy=multi-user.target
EOF

logger() {
  DT=$(date '+%Y/%m/%d %H:%M:%S')
  echo "$DT $0: $1"
}

user_rhel() {
  # RHEL user setup
  /usr/sbin/groupadd --force --system "${GROUP}"

  if ! getent passwd "${USER}" >/dev/null ; then
    /usr/sbin/adduser \
      --system \
      --gid "${GROUP}" \
      --home "${HOME}" \
      --no-create-home \
      --comment "${COMMENT}" \
      --shell /bin/false \
      "${USER}"  >/dev/null
  fi
}

user_ubuntu() {
  # UBUNTU user setup
  if ! getent group "${GROUP}" >/dev/null
  then
    addgroup --system "${GROUP}" >/dev/null
  fi

  if ! getent passwd "${USER}" >/dev/null
  then
    adduser \
      --system \
      --disabled-login \
      --ingroup "${GROUP}" \
      --home "${HOME}" \
      --no-create-home \
      --gecos "${COMMENT}" \
      --shell /bin/false \
      "${USER}"  >/dev/null
  fi
}

createuser () {
USER="${1}"
COMMENT="Hashicorp ${1} user"
GROUP="${1}"
HOME="/srv/${1}"

if $(python -mplatform | grep -qi Ubuntu); then
  logger "Setting up user ${USER} for Debian/Ubuntu"
  user_ubuntu
else
  logger "Setting up user ${USER} for RHEL/CentOS"
  user_rhel
fi
}

logger "Running"

createuser consul

mkdir binaries && cd binaries
python -mplatform | grep -qi Ubuntu && sudo apt -y install wget unzip || sudo yum -y install wget unzip

wget https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip
unzip consul_${CONSUL_VERSION}_linux_amd64.zip

cp -rp consul /usr/local/bin/consul

chown -R consul:consul /etc/consul.d /opt/consul
chmod -R 0644 /etc/consul.d/*
chmod 0755 /usr/local/bin/consul
chown consul:consul /usr/local/bin/consul
chmod 0664 /etc/systemd/system/consul*
chmod 0755 /usr/local/bin/consul-online.sh

# define consul service and ports for firewalld
cat << EOF > /etc/firewalld/services/consul.xml
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>Consul</short>
  <description>TCP connectivity required for HashiCorp Consul cluster communication.</description>
  <port protocol="tcp" port="8300"/>
  <port protocol="tcp" port="8301"/>
  <port protocol="udp" port="8301"/>  
  <port protocol="tcp" port="8302"/>
  <port protocol="udp" port="8302"/>  
  <port protocol="tcp" port="8500"/>
  <port protocol="tcp" port="8600"/>
  <port protocol="udp" port="8600"/>
</service>
EOF

# define consul service and ports for telegraf telemetry
cat << EOF > /etc/firewalld/services/telegraf.xml
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>telegraf</short>
  <description>TCP connectivity required for outbound Telegraf agent.</description>
  <port protocol="tcp" port="8086"/>
</service>
EOF

# firewall configuration
# identify default zone
# firewall-cmd --get-default-zone # identify the default zone

# add custom services to default zone
# assumes public zone

firewall-cmd --zone=public --add-service=consul --permanent
firewall-cmd --zone=public --add-service=https --permanent
firewall-cmd --zone=public --add-service=http --permanent
firewall-cmd --zone=public --add-service=telegraf --permanent
firewall-cmd --complete-reload

systemctl enable consul.service

# set VAULT_ADDR environment var for CLI
# echo 'export VAULT_ADDR="http://127.0.0.1:8200"' >> $HOME/.bashrc

logger "Complete"

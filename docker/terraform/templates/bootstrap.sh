#!/bin/bash
#
# enable/disable Vault if there is another cluster you'd like to use
# cd /tmp
# nano setup.sh
# chmod +x setup.sh
# ./setup.sh

# pull IP address and set VAR
IP_ADDRESS="hostname -i"
ADVERTISE_ADDR="hostname -i"

snap remove docker
apt-get update
apt-get install -y unzip dnsmasq nano net-tools nmap socat docker

## Setup consul

CONSUL_VERSION="1.6.1"

mkdir -p /var/lib/consul

wget https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip
unzip consul_${CONSUL_VERSION}_linux_amd64.zip
mv consul /usr/local/bin/consul
rm consul_${CONSUL_VERSION}_linux_amd64.zip

cat > consul.service <<'EOF'
[Unit]
Description=consul
Documentation=https://consul.io/docs/

[Service]
ExecStart=/usr/local/bin/consul agent \
  -advertise=ADVERTISE_ADDR \
  -bind=0.0.0.0 \
  -bootstrap-expect=3 \
  -client=0.0.0.0 \
  -data-dir=/var/lib/consul \
  -server \
  -ui
  
ExecReload=/bin/kill -HUP $MAINPID
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

sed -i "s/ADVERTISE_ADDR/${IP_ADDRESS}/" consul.service
mv consul.service /etc/systemd/system/consul.service
systemctl enable consul
systemctl start consul

## Setup dnsmasq

mkdir -p /etc/dnsmasq.d
cat > /etc/dnsmasq.d/10-consul <<'EOF'
server=/consul/127.0.0.1:8600
EOF

systemctl enable dnsmasq
systemctl start dnsmasq

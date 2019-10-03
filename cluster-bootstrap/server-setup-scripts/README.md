# deploy HashiCorp Consul OSS (or ENT) binaries on 1 or 3 VMs

this is script is meant to bootstrap a CentOS or Ubuntu VM to run Consul as 1 or 3 node cluster for demo or POV uses

- create the script on your VM(s)

```

cd /tmp

nano setup.sh

```

- set the consul version within the script, line 26

`CONSUL_VERSION="1.6.1"`

- save the file

- make the script executable

`chmod +x setup.sh`

- run the script on VM 1

`sudo ./setup.sh < IP address VM 1> < IP address VM 2 > < IP address VM 3 >`


**note** if the script errors out for any reason, you can simply re-run it until it finishes cleanly OR you debug :-)

- once the script is complete you should be able to start Consul

```

sudo systemctl start consul

sudo systemctl status consul

```

- check syslog for any errors

- if you are building a 3 node cluster, then you'd run the script two more times on the remaining VMs, as follows:

- run the script on VM 2

`sudo ./setup.sh < IP address VM 2 > < IP address VM 3 > < IP address VM 1 >`

- run the script on VM 3

`sudo ./setup.sh < IP address VM 3 > < IP address VM 1 > < IP address VM 2 >`
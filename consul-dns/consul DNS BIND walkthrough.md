# Resolving Consul DNS queries via BIND and Windows DNS
- Step 1
1 BIND running on Ubuntu 18.04
1 BIND forwarder zone configured to point *consul to Consul cluster on port 8600
1 Host without Consul agent querying for *consul "A" record

[ref](https://learn.hashicorp.com/consul/security-networking/forwarding)

- Step 2
1 Windows Server 2016 DNS
1 Windows DNS conditional forwarder configured to point *consul to BIND server
1 Host without Consul agent querying for *consul "A" record

# Step 1

## prepare BIND server

### disable dnssec
[ref](https://github.com/hashicorp/consul/issues/423)

`sudo nano /etc/bind/named.conf.options`

```
        dnssec-enable no;
        dnssec-validation no;
```

## add consul zone file statement

`sudo nano /etc/bind/named.conf.local`

- insert this stanza at the bottom of the existing config

```
zone "consul" IN {
  type forward;
  forward only;
  forwarders { 192.168.1.231 port 8600; }; // this should point to local Consul agent or remote Consul cluster
};
```

### verify config and zone files are error-free

`named-checkconf`

## restart BIND

`sudo service bind9 restart`

## test
- using dig from BIND server or remote host
` dig active.vault.service.consul`

- ping from CLI of host setup to use BIND server

`ping active.vault.service.consul`

## troubleshooting
- make sure firewall is open for 8600 inbound on Consul cluster nodes

- from another terminal session, starta tcpdump

`sudo tcpdump -nt -i ens160 udp port 8600`

- try ping again from previous terminal session

`ping active.vault.service.consul`

- you should see outbound transaction to the consul cluster or to the consul agent on localhost 8600
	
```
jray@ns1:~$ sudo tcpdump -nt -i ens160 udp port 8600
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on ens160, link-type EN10MB (Ethernet), capture size 262144 bytes
IP 192.168.1.248.43077 > 192.168.1.231.8600: UDP, length 55
IP 192.168.1.248.41740 > 192.168.1.231.8600: UDP, length 55
IP 192.168.1.231.8600 > 192.168.1.248.43077: UDP, length 93
```
- Consul cluster is .231
- BIND server is .248

- make sure 8600 is open outbound from the server

`dig @192.168.1.231 -p 8600 active.vault.service.consul. A`

## view BIND cache
- on BIND server

`sudo rndc dumpdb -cache`

`sudo more /var/cache/bind/named_dump.db | grep "vault"`

- example:

```
jray@ns1:~$ sudo more /var/cache/bind/named_dump.db | grep "vault"
active.vault.service.consul.fios-router.home. 8653 \-ANY ;-$NXDOMAIN
active.vault.service.consul.home.org. 1453 A 127.0.0.1
```

- flush cache:

`sudo rndc flush`

- reload bind

`sudo service bind9 restart`

dig active.vault.service.consul A

# appendix: configure host to search consul domain host

## Ubuntu DNS client setup
[ref](https://www.hiroom2.com/2018/05/29/ubuntu-1804-network-en/)

### baseline the existing config
- at a minimum, need to add _consul_ to the search domain

`systemd-resolve --status`

- backup original netplan file

`sudo cp /etc/netplan/50-cloud-init.yaml /etc/netplan/50-cloud-init.yaml.orig`

- edit the netplan file if needed to point to a the BIND or Windows DNS server
- edit the search domain to include _consul_

`sudo nano /etc/netplan/50-cloud-init.yaml`

```
network:
    ethernets:
        ens160:
            addresses: []
            dhcp4: true
            nameservers:
                addresses:
                - 192.168.1.248
                search:
                - consul
                - home.org
    version: 2

```

- use netplan try to validate modified file
	- assuming no errors, hit _ENTER_ to accept changes

`sudo netplan try`

- use netplan apply to apply changes

`sudo netplan apply`

## CentOS7 DNS client setup

`sudo nano /etc/sysconfig/network-scripts/ifcfg-ens192`

*NOTE* file name is ifcfg-<your adapter name>

- add:

PEERDNS="no"

`sudo nano /etc/resolv.conf`

- modify to reflect your search domain preference, a minimum at _consul_
search consul home.org
nameserver 192.168.1.248

- restart the network service

`sudo systemctl status network.service`

- check with dig

`sudo yum install bind-utils -y`

`dig active.vault.service.consul A`

# Step 2
- looking for a way to support resolution of Consul DNS to Windows hosts
- should be as straight-forward as possible (KISS)

## overview

1 Windows Server 2016 running DNS
1 Windows or Linux host running BIND, configured with _fowarder zone_
1 Windows or Linux hosts configured to use Windows DNS server

ref: there is no Windows-friendly approach or at least it is not [documented](https://github.com/hashicorp/consul/issues/3964)

### Notes
- Windows Server 2016 DNS has _conditional forwarder_ concept
	- first attempt at using this was a fail because the forwarder record does not support specifying a port (i.e., <consul IP>:8600)
	- second attempt is a working model, but requires the use of the BIND server setup in Step 1
		- configured Windows DNS conditional forwarder to forward _*consul_ domain to BIND server with forwarding zone already configured
		- adds a requirement for the BIND server, but that is the HashiCorp supported pattern
	- third attempt, install Consul agent on Windows server and setup conditional forwarder to point to the local Consul agent
		- requires Consul agent to listen on port 53
		- requires use of another NIC since 53 is bound to primary LAN NIC of Windows server

## Windows DNS Server setup

### Open DNS Manager on authorized DNS server

1 right-click on _Conditional Forwarders_
1 select _New Conditional Forwarder_
1 enter DNS Domain _consul_
1 enter IP address of BIND server
1 select OK

- that's it! you can now test

### test

- from command prompt or powershell terminal:

`ping active.vault.service.consul`

- it may take a split second the first time to cache the DNS record, but the name should resolve and successfully ping (if ping is allowed)
- alternatively you can open a browser window and hit `http://active.vault.service.consul:8200` for the Vault UI

# appendix: using tcpdump and wireshark to debug

1 prepare two tcpdump snippets to capture dig and ping tests separately
1 prepare to run a dig test and ping test from host setup to use central DNS server
1 capture each test separately from DNS server
1 scp capture files back to laptop to analyze in Wireshark

### setup tcpdump to write to two separate files, first for dig, then ping test
- dig test

`sudo tcpdump -nt -i ens160 -w lab00-dig-test udp port 8600`

- ping test

`sudo tcpdump -nt -i ens160 -w lab00-ping-test udp port 8600`

- scp file from test host to mac

`scp lab00-dig-test jray@192.168.1.4:/Users/jray/Downloads`

### failing dig test

```
[jray@consul-lab00 ~]$ dig @192.168.1.248  active.vault.service.consul. ANY

; <<>> DiG 9.9.4-RedHat-9.9.4-74.el7_6.1 <<>> @192.168.1.248 active.vault.service.consul. ANY
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: SERVFAIL, id: 14206
;; flags: qr rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;active.vault.service.consul.	IN	ANY
  ```

### failing ping test
- oddness when your query resolves to localhost - this usually means the forwarder and/or search domain is not configured (or has a typo)

```
jray@consul-lab00 ~]$ ping active.vault.service.consul
PING active.vault.service.consul.home.org (127.0.0.1) 56(84) bytes of data.
64 bytes from localhost (127.0.0.1): icmp_seq=1 ttl=64 time=0.028 ms
```

## open in wireshark
- can install on Mac with homebrew

`brew install wireshark`

`brew cask install wireshark`

# next steps
## DNS caching and production-izing Consul DNS
[ref](https://learn.hashicorp.com/consul/security-networking/dns-caching)
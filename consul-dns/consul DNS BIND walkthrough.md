# Forwarding DNS Queries to Consul from Central BIND DNS
- Approach 1:
1 BIND running on Ubuntu 18.04
1 Consul agent running on BIND server joined to existing Consul cluster
1 CentOS7 host without Consul agent querying for *consul "A" record

ref: https://learn.hashicorp.com/consul/security-networking/forwarding

- Approach 2:
1 Windows Server 2016 DNS
1 Consul agent running on Windows DNS Server
1 CentOS7 host without Consul agent querying for *consul "A" record

# approach 1

## prepare BIND server

### disable dnssec
ref: https://github.com/hashicorp/consul/issues/423

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

## CentOS7

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

# Forwarding DNS Queries to Consul from Central Windows DNS

1 Windows Server 2016 running DNS
1 Windows or Linux hosts configured to use Windows DNS server

## Windows DNS Server setup



# appendix: tcpdump and wireshark to debug

1 prepare two tcpdump snippets to capture dig and ping tests separately
1 prepare to run a dig test and ping test from host setup to use central DNS server
1 capture each test separately from DNS server
1 scp capture files back to laptop to analyze in Wireshark

### setup tcpdump to write to two separate files, first for dig, then ping test
- dig test

`sudo tcpdump -nt -i ens160 -w lab00-dig-test udp port 8600`

- ping test

`sudo tcpdump -nt -i ens160 -w lab00-ping-test udp port 8600`

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
```
jray@consul-lab00 ~]$ ping active.vault.service.consul
PING active.vault.service.consul.home.org (127.0.0.1) 56(84) bytes of data.
64 bytes from localhost (127.0.0.1): icmp_seq=1 ttl=64 time=0.028 ms
```

- scp file from test host to mac

`scp lab00-dig-test jray@192.168.1.4:/Users/jray/Downloads`

## open in wireshark
- can install on Mac with homebrew
`brew install wireshark`
`brew cask install wireshark`
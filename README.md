## Setting up the environment

The environment is based on Vagrant and Virtualbox so you need these two to proceed.

> It was tested on Mac OSX with Vagrant 1.8.1 (`vagrant --version`) and Virtualbox 5.0.10 r104061.

The tools used to build the environment:

1. [Vagrant](https://www.vagrantup.com/)
    - as a tool to setup the environment
2. [Virtualbox](https://www.virtualbox.org/)
    - as backend for Vagrant
4. [Docker](http://docker.io/)
    - to run [container](https://hub.docker.com/r/mongooseim/mongooseim-docker/) with [MongooseIM](https://github.com/esl/MongooseIM)
5. [Amoc](https://hub.docker.com/r/mongooseim/mongooseim-docker/)
    - to run XMPP clients that stress the server
6. [OpenVSwitch](http://openvswitch.org/)
    - to controll the traffic hitting the MongooseIM server by using [OpenFlow](https://www.opennetworking.org/sdn-resources/openflow)
5. [ovs-docker tool](https://github.com/openvswitch/ovs/blob/master/utilities/ovs-docker)
    - to setup the netowrking with the containers
6. [Graphite Container](https://github.com/davidkarlsen/graphite_docker)
    - to visualize some metrics
6. [**LOOM OpenFlow Controller**](http://flowforwarding.github.io/loom/)
    - to implement the Intrusion Detection System in Erlang
    - that will be the base of our project - the rest is to show the real life scenario and to perform some real tests

### Environment overview

![alt](img/soe2016_env_overview.png)

### Build and provision the machine ###

Clone this project, enter its directory and run: `vagrant up`. To login into the machine you can use `vagrant ssh`. To suspend it invoke `vagrant suspend` - it can be woken up with `vagrant up`.

### Check that things are up and running

#### Networking

Check that the machine has:
* `eth1` interface with IP address of 192.169.0.100 which is reachable from your host machine (as you shuld have vboxnet0 interface with IP address 192.169.0.1)
* `ovs-br1` which is the OpenVSwich interface with 173.16.1.1 IP address

Run `ip a` to verify the networking. The output should have the following lines:

```shell
...
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 08:00:27:0a:95:b7 brd ff:ff:ff:ff:ff:ff
    inet 192.169.0.100/24 brd 192.169.0.255 scope global eth1
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe0a:95b7/64 scope link
       valid_lft forever preferred_lft forever
...
6: ovs-br1: <BROADCAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default
    link/ether 56:bf:2e:25:53:49 brd ff:ff:ff:ff:ff:ff
    inet 173.16.1.1/24 brd 173.16.1.255 scope global ovs-br1
       valid_lft forever preferred_lft forever
   inet6 fe80::74a6:1cff:fe0d:d989/64 scope link
       valid_lft forever preferred_lft forever
...
```
       

#### Docker containers

Loggin into to and verify that two docker containers: mim with MongooseIM server and graphite with graphite are running:
`docker ps`. The output should be similar to the following:

```shell
vagrant@soe2016:~$ docker ps
CONTAINER ID        IMAGE                          COMMAND                  CREATED             STATUS              PORTS                                                                                                          NAMES
0ccd727d3743        davidkarlsen/graphite_docker   "/bin/sh -c /usr/bin/"   11 minutes ago      Up 11 minutes       0.0.0.0:2003->2003/tcp, 2004/tcp, 7002/tcp, 8125/udp, 0.0.0.0:3000->3000/tcp, 8126/tcp, 0.0.0.0:8080->80/tcp   graphite
69896a7e9956        mongooseim/mongooseim-docker   "./start.sh"             11 minutes ago      Up 11 minutes       4369/tcp, 5222/tcp, 5269/tcp, 5280/tcp, 9100/tcp                                                               mim
```

#### MongooseIM


Check that the 100 users are registered in the `localhost` domain in the server:
`docker exec mim ./start.sh "registered_users localhost"`

> `docker exec CONTAINTER` invokes a command in the given container`

Check that the server actually listens on the XMPP port (5222) and is reachable via 173.16.1.100 address:
`telnet 173.16.1.100 5222`

You should get the connection and after typing something meaningless the server should return an error:
```shell
vagrant@soe2016:~$ telnet 173.16.1.100 5222
Trying 173.16.1.100...
Connected to 173.16.1.100.
Escape character is '^]'.
ala
<?xml version='1.0'?><stream:stream xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams' id='A90649D738C08E69' from='localhost' version='1.0'><stream:error><xml-not-well-formed xmlns='urn:ietf:params:xml:ns:xmpp-streams'/></stream:error></stream:stream>Connection closed by foreign host.
```

#### Graphite

Check that the webinterface of Graphite is accessible on your *host machine* via web browser. Point it to 192.169.0.100:8080. You should see a dashbord like the one below:

![alt](img/soe2016_graphite_empy.png)

#### LOOM OpenFlow Controller

TODO

## Running a sanity check

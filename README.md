## Setting up the environment

The environment is based on Vagrant and Virtualbox so you need these two to proceed.

>> It was tested on Mac OSX with Vagrant 1.8.1 (`vagrant --version`) and Virtualbox 5.0.10 r104061.

The tools used to build the environment:

1. [Vagrant](https://www.vagrantup.com/)
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
    - that will be the base of our project - the rest is for show the real life scenario and to perform some real tests

### Build and provision the machine ###

Clone this project, enter its directory and run: `vagrant up`.

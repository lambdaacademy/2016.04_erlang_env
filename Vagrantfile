$prepare_apt = <<SCRIPT
wget http://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb && \
dpkg -i erlang-solutions_1.0_all.deb && \
apt-get update
SCRIPT

$packages = <<SCRIPT
apt-get install -y emacs24-nox htop bridge-utils openvswitch-switch \
autoconf libncurses-dev build-essential libssl-dev g++ curl \
esl-erlang=1:18.3 libexpat1-dev
SCRIPT

$get_docker = <<SCRIPT
wget -q -O - https://get.docker.io/gpg | apt-key add -
echo deb http://get.docker.io/ubuntu docker main > /etc/apt/sources.list.d/docker.list
apt-get update -qq; apt-get install -q -y --force-yes lxc-docker
usermod -a -G docker vagrant
SCRIPT

$get_ovs_docker = <<SCRIPT
curl -o /usr/bin/ovs-docker https://raw.githubusercontent.com/openvswitch/ovs/master/utilities/ovs-docker
chmod a+rwx /usr/bin/ovs-docker
SCRIPT

$get_amoc = <<SCRIPT
cd /home/vagant
git clone https://github.com/esl/amoc.git
cd amoc && git checkout fix-for-erlang18
SCRIPT

$install_amoc = <<SCRIPT
cd amoc
sed -i s/\-name/\-sname/g priv/vm.args
sed -i s/"127.0.0.1"/"173.16.1.100"/g scenarios/mongoose_simple.erl
make rel
cp /vagrant/files/simple_run.sh .
chmod +x amoc_simple_run.sh
chown -R vagrant: ./
SCRIPT

$copy_mim_cfg = <<SCRIPT
cp /vagrant/files/ejabberd.cfg /home/vagrant/
SCRIPT

$register_mim_users = <<SCRIPT
for i in `seq 1 10`; do
   docker exec mim ./start.sh "register user_$i localhost password_$i"
done
SCRIPT

$configure_network = <<SCRIPT
ovs-vsctl add-br ovs-br1
ifconfig ovs-br1 173.16.1.1 netmask 255.255.255.0 up
SCRIPT

$add_mim_to_network = <<SCRIPT
ovs-docker add-port ovs-br1 eth1 mim --ipaddress=173.16.1.100/24
SCRIPT

def provision_with_shell(node)
  node.vm.provision "prepare_apt", type: "shell", inline: $prepare_apt
  node.vm.provision "packages", type: "shell", inline: $packages
  node.vm.provision "get_docker", type: "shell", inline: $get_docker
  node.vm.provision "get_ovs_docker", type: "shell", inline: $get_ovs_docker
  node.vm.provision "get_amoc", type: "shell", inline: $get_amoc
  node.vm.provision "install_amoc", type: "shell", inline: $install_amoc
  node.vm.provision "copy_mim_cfg", type: "shell", inline: $copy_mim_cfg
  node.vm.provision "configure_network", type: "shell", inline: $configure_network
end

def get_docker_images(node)
  node.vm.provision "docker_images",
                    type: "docker",
                    images: ["ubuntu:latest",
                             "mongooseim/mongooseim-docker",
                             "studzien/amoc",
                             "sitespeedio/graphite"]
end

def run_docker_containers(node)
  node.vm.provision "docker_containers", type: "docker" do |d|
    d.run "mim",
          image: "mongooseim/mongooseim-docker",
          args: "-it -v /home/vagrant/ejabberd.cfg:/opt/mongooseim/rel/mongooseim/etc/ejabberd.cfg",
          restart: "no"
    d.run "graphite",
          image: "sitespeedio/graphite",
          args: "-it -p 8080:80 -p 2003:2003",
          restart: "no"
  end
  node.vm.provision "register_mim_users",
                    type: "shell",
                    inline: $register_mim_users
  node.vm.provision "add_mim_to_network",
                    type: "shell",
                    inline: $add_mim_to_network
end


Vagrant.configure(2) do |config|
  config.vm.box = "ubuntu/trusty64"
  config.vm.provider "virtualbox" do |vb|
    vb.memory = 4096
    vb.cpus = 4
    vb.linked_clone = true
  end
  
  config.hostmanager.enabled = true
  config.hostmanager.manage_host = false
  config.hostmanager.ignore_private_ip = false
  config.hostmanager.include_offline = true
  config.ssh.forward_agent = true
  config.ssh.insert_key = false
  config.vm.synced_folder '.', '/vagrant'
  config.vm.boot_timeout = 60
  
  config.vm.define "soe2016" do |node|
    node.vm.hostname = "soe2016"
    node.vm.network :forwarded_port, guest: 22, host: 2200, id: "ssh", auto_correct: true
    node.vm.network :private_network, ip: "192.169.0.100"
    provision_with_shell node
    get_docker_images node
    run_docker_containers node
  end
  
end

# unused

$get_kerl = <<SCRIPT
curl -o /bin/kerl -O https://raw.githubusercontent.com/yrashk/kerl/master/kerl
chmod a+x /bin/kerl
SCRIPT

$copy_kerlrc = <<SCRIPT
cp /vagrant/files/.kerlrc /home/vagrant/
SCRIPT

$install_erlang = <<SCRIPT
kerl build 18.3 18.3
kerl install 18.3
echo -e ". /home/vagrant/.kerl/installs/18.3/activate\n" >> /etc/bash.bashrc
echo -e ". /home/vagrant/.kerl/installs/18.3/activate\n" >> /etc/profile
SCRIPT

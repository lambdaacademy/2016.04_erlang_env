.PHONY: vagrant-plugins

vagrant-plugins:
	vagrant plugin install vagrant-hostmanager
	vagrant plugin install vagrant-git
	vagrant plugin install vagrant-vbguest
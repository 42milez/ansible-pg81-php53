# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.box = "https://dl.dropbox.com/u/17738575/CentOS-5.8-x86_64.box"
  config.vm.network :private_network, ip: "192.168.33.11"
  config.vm.provider :virtualbox do |vb|
    vb.customize [ 'modifyvm', :id, '--memory', 1024 ]
  end
  config.vm.provision :shell, :inline => "sudo yum install -y python-simplejson", privileged: true
  config.vm.synced_folder "./", "/var/www/html/htdocs", :create => true, :owner => 'vagrant', :group => 'vagrant', :mount_options => ['dmode=0777', 'fmode=0777']
end

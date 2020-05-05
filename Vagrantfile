# -*- mode: ruby -*-
# vi: set ft=ruby :
#
#

#Script for creating kvm (Kernel native) vm's for kubernetes
#best be doing this on a fresh box lest things get cattywampus
#need a bridge set up under br0

#Net work prefix in which a single digit is appended
#ex 192.168.1.5 will have a master at 192.168.1.50 and workers starting from 192.168.1.51
NETWORK_PREFIX="10.0.10.9"

#make sure libvirt, qemu, kvm etc are installed
#make sure other hypervisors such as virtualbox are not
ENV['VAGRANT_DEFAULT_PROVIDER'] = 'libvirt'
IMAGE_NAME = "peru/ubuntu-18.04-server-amd64"

#right now NUM_NODES must be under 9
NUM_NODES = 2

Vagrant.configure("2") do |config|
    config.ssh.insert_key = false

    config.vm.provider :libvirt do |libvirt|
        libvirt.memory = 1024
        libvirt.cpus = 1
        libvirt.driver = "kvm"
        libvirt.nested = false
        libvirt.management_network_name = 'node-network'
        libvirt.management_network_address = '10.0.10.0/24'
    end

    config.vm.define "master-1" do |master|
        master.vm.box = IMAGE_NAME
        master.vm.network :public_network,
               :dev => "virbr1",
               :mode => "bridge",
               :type => "bridge",
         :ip => "#{NETWORK_PREFIX}0"
          master.vm.hostname = "master"
    end

    (1..NUM_NODES).each do |i|
        config.vm.define "worker-#{i}" do |node|
            node.vm.box = IMAGE_NAME
            node.vm.network :public_network,
                :dev => "virbr1",
                :mode => "bridge",
                :type => "bridge",
                :ip => "#{NETWORK_PREFIX}#{i}"
            node.vm.hostname = "worker-#{i}"
        end
    end
end

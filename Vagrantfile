# -*- mode: ruby -*-
# vi: set ft=ruby :
#
#

#Net work prefix in which a single digit is appended
#ex 192.168.1.5 will have a master at 192.168.1.50 and workers starting from 192.168.1.51
NETWORK_PREFIX="10.0.10.9"
ENV['VAGRANT_DEFAULT_PROVIDER'] = 'libvirt'
IMAGE_NAME = "generic/ubuntu1804"

#right now NUM_NODES must be under 9
NUM_NODES = 2

Vagrant.configure("2") do |config|
    config.ssh.insert_key = false

    config.vm.provision "shell" do |s|
        ssh_prv_key = ""
        ssh_pub_key = ""
        if File.file?("#{Dir.home}/.ssh/id_rsa")
            ssh_prv_key = File.read("#{Dir.home}/.ssh/id_rsa")
            ssh_pub_key = File.readlines("#{Dir.home}/.ssh/id_rsa.pub").first.strip
        else
            puts "No SSH key found. You will need to remedy this before pushing to the repository."
        end
        s.inline = <<-SHELL
            if grep -sq "#{ssh_pub_key}" /root/.ssh/authorized_keys; then
                echo "SSH keys already provisioned."
                exit 0;
            fi
            echo "SSH key provisioning."
            mkdir -p /root/.ssh/
            touch /root/.ssh/authorized_keys
            echo #{ssh_pub_key} >> /root/.ssh/authorized_keys
            echo #{ssh_pub_key} > /root/.ssh/id_rsa.pub
            chmod 644 /root/.ssh/id_rsa.pub
            echo "#{ssh_prv_key}" > /root/.ssh/id_rsa
            chmod 600 /root/.ssh/id_rsa
            chown -R root:root /root
            echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
            usermod --expiredate 1 vagrant
            systemctl restart ssh
            exit 0
        SHELL
    end

    config.vm.provider :libvirt do |libvirt|
        libvirt.memory = 4096
        libvirt.cpus = 2
        libvirt.cputopology :sockets => '1', :cores => '1', :threads => '2'
        libvirt.driver = "kvm"
        libvirt.nested = true
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

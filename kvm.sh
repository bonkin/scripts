#!/usr/bin/env bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source "$DIR/declarations/color.sh"

echo "╔═══════════════════════════════╗"
echo "║         KVM Installer         ║"
echo "╚═══════════════════════════════╝"

distro=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
distver=$(grep -oP '(?<=^VERSION_ID=).+' /etc/os-release | tr -d '"')

if [[ "$distro" != "opensuse-leap" ]]; then
  echo "This script requires OpenSUSE Leap to run."
  exit 1
fi

if [[ "$distver" != "15.1" && "$distver" != "15.2" ]]; then
  echo "This script requires OpenSUSE 15.1 / 15.2 to run."
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root"
  exit 1
fi

hw_enabled=$(egrep -c '(vmx|svm)' /proc/cpuinfo)
if [[ ${hw_enabled} -eq "0" ]]; then
  echo "Hardware virtualization should be enabled in BIOS"
  exit 1
fi

if [[ "$distro" == "opensuse-leap" ]]; then
  zypper --non-interactive update --no-recommends
  zypper --non-interactive install qemu \
                            ruby-devel \
                            gcc \
                            qemu-kvm \
                            libvirt \
                            libvirt-devel \
                            virt-install \
                            bridge-utils \
                            vagrant \
                            ansible
  # OpenSUSE bug workaround
  mv /opt/vagrant/embedded/lib/libreadline.so.7{,.disabled}
  vagrant plugin install vagrant-libvirt
  mv /opt/vagrant/embedded/lib/libreadline.so.7{.disabled,}
fi

cat /dev/zero | ssh-keygen -q -N ""

echo "stdio_handler="\""file"\" >> /etc/libvirt/qemu.conf

systemctl start virtlogd

systemctl start libvirtd

rm -r /usr/share/vagrant-vms
mkdir /usr/share/vagrant-vms
cp "$DIR/Vagrantfile" /usr/share/vagrant-vms

virsh net-define "$DIR/vnet-definition.xml"
virsh net-start node-network
virsh net-autostart node-network
virsh net-list

systemctl restart libvirtd

(cd /usr/share/vagrant-vms;\
vagrant up --provider=libvirt;\
vagrant status)

cd "$DIR/kubespray/"
git clean -fdx
git submodule update --init "$DIR/kubespray/"
curr_branch=$(git rev-parse --abbrev-ref HEAD)
tags=$(git tag -l --sort -version:refname | head -n 10 | awk '{print v++,$1}')
tag=$(dialog --menu "Checkout another Kubespray version instead of ${curr_branch}?" 20 25 25 ${tags} 3>&2 2>&1 1>&3)

if [[ -z ${tag} ]]; then
  echo "Current revision will be used"
else
  arr=(${tags})
  idx=$(( tag * 2 + 1 ))
  git checkout "${arr[idx]}"
fi

pip3 install -r requirements.txt

# When working with Kubespray, it is first advised to copy the default sample configuration from inventory/sample
cp -rfp inventory/sample inventory/mycluster

declare -a IPS=(10.0.10.90 10.0.10.91 10.0.10.92)
CONFIG_FILE=inventory/mycluster/hosts.yml python3 contrib/inventory_builder/inventory.py ${IPS[@]}

# change calico -> cilium
sed -i 's/^\(\s*kube_network_plugin\s*:\s*\).*/\1cilium/' inventory/mycluster/group_vars/k8s-cluster/k8s-cluster.yml

# for ‘kubectl top nodes’ & ‘kubectl top pods’ commands to work with no authentication/authorization
echo "kube_read_only_port: 10255" >> inventory/mycluster/group_vars/all/all.yml
echo "bootstrap_os: ubuntu" >> inventory/mycluster/group_vars/all/all.yml
echo "kubeconfig_localhost: true" >> inventory/mycluster/group_vars/k8s-cluster/k8s-cluster.yml
echo "kubectl_localhost: true" >> inventory/mycluster/group_vars/k8s-cluster/k8s-cluster.yml

ansible-playbook -i inventory/mycluster/hosts.yml cluster.yml -u root -b -v --private-key=/root/.ssh/id_rsa --timeout=60

export KUBECONFIG=inventory/mycluster/artifacts/admin.conf
kubectl get nodes

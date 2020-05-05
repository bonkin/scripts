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
  vagrant plugin install vagrant-libvirt
fi

echo "stdio_handler="\""file"\" >> /etc/libvirt/qemu.conf

systemctl start virtlogd

systemctl start libvirtd

mkdir /usr/share/vagrant-vms
cd /usr/share/vagrant-vms
cp "$DIR/Vagrantfile" /usr/share/vagrant-vms

virsh net-define "$DIR/vnet-definition.xml"
virsh net-start vagrant-libvirt
virsh net-autostart vagrant-libvirt
virsh net-list

systemctl restart libvirtd

export VAGRANT_DEFAULT_PROVIDER=libvirt
vagrant up --provider=libvirt

vagrant status




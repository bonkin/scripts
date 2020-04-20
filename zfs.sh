#!/usr/bin/env bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source "$DIR/declarations/color.sh"
source "$DIR/declarations/dialog.sh"

echo "╔══════════════════════════════╗"
echo "║   Installer script for ZFS   ║"
echo "╚══════════════════════════════╝"

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

declare -a empty_disks
mapfile -t hard_disks < <( lsblk -dpno NAME )

for hard_disk in "${hard_disks[@]}"
do
  error=$(/sbin/sfdisk -d "$hard_disk" 2>&1 >/dev/null)
  if [[ "$error" == *"does not contain a recognized partition table" ]]; then
    empty_disks+=("$hard_disk")
  fi
done

if [[ ${#empty_disks[@]} -eq 0 ]]; then
  echo -e ${RED}"Couldn't find any unpartitioned disks. Exiting..." ${NO_COLOR}
  exit 1
fi

echo "Found unpartitioned disks:"
for empty_disk in "${empty_disks[@]}"; do
  echo -e ${GREEN}${empty_disk}${NO_COLOR}
done

if [[ "$distro" == "opensuse-leap" ]]; then
  zypper --quiet addrepo https://download.opensuse.org/repositories/filesystems/openSUSE_Leap_${distver}/filesystems.repo
  zypper --gpg-auto-import-keys refresh
  zypper --gpg-auto-import-keys refresh
  zypper --non-interactive update --no-recommends
  zypper --non-interactive install zfs dialog
fi

while : ; do
  declare -a disks=("${empty_disks[@]}")
  dialog::multiselect disks
  if [[ ${#disks[@]} -eq 0 ]]; then
    clear
    echo -e ${RED}"You should select at least one disk" ${NO_COLOR}
    sleep 2
  else
    empty_disks=("${disks[@]}")
    break
  fi
done

echo "Selected disks:"
for choice in "${empty_disks[@]}"; do
  echo -e "${GREEN}${choice}${NO_COLOR}"
done

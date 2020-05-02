#!/usr/bin/env bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source "$DIR/declarations/color.sh"
source "$DIR/declarations/dialog.sh"
source "$DIR/declarations/disk.sh"

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

while : ; do
  read -e -p "Select mount point directory (e.g. /var/lib/pgsql/data): " mount_point
  if [[ ! -d ${mount_point} ]]; then
    echo -e "Directory ${RED}$mount_point${NO_COLOR} doesn't exist!"
  fi
  while : ; do
    echo -e "Does this look correct (${GREEN}y${NO_COLOR}/${RED}n${NO_COLOR}):"
    read -i "y" -e yn
    case ${yn} in
      [Yy]* )
        if [[ ! -d ${mount_point} ]]; then
          mkdir -p ${mount_point};
          echo -e "Directory ${GREEN}$mount_point${NO_COLOR} was created"
        fi
        break 2
        ;;
      [Nn]* )
        break
        ;;
      * )
        echo "Please answer yes or no.";;
    esac
  done
done

if [[ "$distro" == "opensuse-leap" ]]; then
  zypper --quiet addrepo https://download.opensuse.org/repositories/filesystems/openSUSE_Leap_${distver}/filesystems.repo
  zypper --gpg-auto-import-keys refresh
  zypper --non-interactive update --no-recommends
  zypper --non-interactive install \
                            zfs \
                            dialog \
                            whois # ->mkpasswd
  /sbin/modprobe zfs
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

declare -a symlinks=()
for disk in "${empty_disks[@]}"; do
  symlinks+=( $(disk::path_to_id ${disk}) )
done

printf '> %s\n' "${symlinks[@]}"

# There's only a relatively minor space penalty if you mistakenly go with a higher ashift than needed,
# while the penalty for having your ashift too low when needing to replace a device with a different
# spare device is that it won't work at all and you'll have to migrate the pool.
# My suggestion would be to use ashift=13.

case ${#symlinks[@]} in
  1)
    zpool create -f -o ashift=12 -O mountpoint=none storage ${symlinks[0]}
    ;;
  2)
    cmd=(dialog --no-cancel --clear --backtitle "2 disks zpool configuration" --menu "Select zpool RAID type" 9 95 6)
    options=(0 "Mirror (recommended, excellent redundancy, but has low capacity and slow write speed)"
             1 "Stripe (has no redundancy, but provides the best performance and additional storage)")
    declare -a choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
    case ${choices[0]} in
      0)
        zpool create -f -o ashift=13 -O mountpoint=none storage mirror ${symlinks[0]} ${symlinks[1]}
        ;;
      1)
        zpool create -f -o ashift=13 -O mountpoint=none storage ${symlinks[0]} ${symlinks[1]}
        ;;
    esac
    ;;
  3)
    cmd=(dialog --no-cancel --clear --backtitle "3 disks zpool configuration" --menu "Select zpool RAID type" 9 95 6)
    options=(0 "RAID-Z1 (recommended for fast/small disks, good redundancy & storage efficiency combo)"
             1 "Stripe (has no redundancy, but provides the best performance and additional storage)")
    declare -a choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
    case ${choices[0]} in
      0)
        zpool create -f -o ashift=13 -O mountpoint=none storage raidz ${symlinks[0]} ${symlinks[1]} ${symlinks[2]}
        ;;
      1)
        zpool create -f -o ashift=13 -O mountpoint=none storage ${symlinks[0]} ${symlinks[1]} ${symlinks[2]}
        ;;
    esac
    ;;
  4)
    cmd=(dialog --no-cancel --clear --backtitle "4 disks zpool configuration" --menu "Select zpool RAID type" 11 95 6)
    options=(0 "Two striped mirrors (pool of mirror vdevs is the best read-performing ZFS topology)"
             1 "RAID-Z2 (similar to №1, safer in case of any of the drives fails, but CPU intensive)"
             2 "RAID-Z1 (only one drive out of the pool can fail, not recommended for large disks)"
             3 "Stripe (has no redundancy, but provides the best performance and additional storage)")
    declare -a choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
    case ${choices[0]} in
      0)
        zpool create -f -o ashift=13 -O mountpoint=none storage mirror ${symlinks[0]} ${symlinks[1]} mirror ${symlinks[2]} ${symlinks[3]}
        ;;
      1)
        zpool create -f -o ashift=13 -O mountpoint=none storage raidz2 ${symlinks[0]} ${symlinks[1]} ${symlinks[2]} ${symlinks[3]}
        ;;
      2)
        zpool create -f -o ashift=13 -O mountpoint=none storage raidz ${symlinks[0]} ${symlinks[1]} ${symlinks[2]} ${symlinks[3]}
        ;;
      3)
        zpool create -f -o ashift=13 -O mountpoint=none storage ${symlinks[0]} ${symlinks[1]} ${symlinks[2]} ${symlinks[3]}
        ;;
    esac
    ;;
  5)
    cmd=(dialog --no-cancel --clear --backtitle "5 disks zpool configuration" --menu "Select zpool RAID type" 11 95 6)
    options=(0 "RAID-Z3 (extremely durable, but could be overkill for the money)"
             1 "RAID-Z2 (not recommended for low power CPU, can cause some performance penalty)"
             2 "RAID-Z1 (only one drive out of the pool can fail, not recommended for large disks)"
             3 "Stripe (has no redundancy, but provides the best performance and additional storage)")
    declare -a choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
    case ${choices[0]} in
      0)
        zpool create -f -o ashift=13 -O mountpoint=none storage raidz3 ${symlinks[0]} ${symlinks[1]} ${symlinks[2]} ${symlinks[3]} ${symlinks[4]}
        ;;
      1)
        zpool create -f -o ashift=13 -O mountpoint=none storage raidz2 ${symlinks[0]} ${symlinks[1]} ${symlinks[2]} ${symlinks[3]} ${symlinks[4]}
        ;;
      2)
        zpool create -f -o ashift=13 -O mountpoint=none storage raidz ${symlinks[0]} ${symlinks[1]} ${symlinks[2]} ${symlinks[3]} ${symlinks[4]}
        ;;
      3)
        zpool create -f -o ashift=13 -O mountpoint=none storage ${symlinks[0]} ${symlinks[1]} ${symlinks[2]} ${symlinks[3]} ${symlinks[4]}
        ;;
    esac
    ;;
  6)
    cmd=(dialog --no-cancel --clear --backtitle "6 disks zpool configuration" --menu "Select zpool RAID type" 12 95 6)
    options=(0 "Three striped mirrors (pool of mirror vdevs is the best read-performing ZFS topology)"
             1 "RAID-Z2 (high durability and space efficiency, but CPU intensive)"
             2 "RAID-Z1 (only one drive out of the pool can fail, not recommended for large disks)"
             3 "RAID-Z3 (extremely durable, but could be overkill for the money)"
             4 "Stripe (has no redundancy, but provides the best performance and additional storage)")
    declare -a choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
    case ${choices[0]} in
      0)
        zpool create -f -o ashift=13 -O mountpoint=none storage mirror ${symlinks[0]} ${symlinks[1]} mirror ${symlinks[2]} ${symlinks[3]} mirror ${symlinks[4]} ${symlinks[5]}
        ;;
      1)
        zpool create -f -o ashift=13 -O mountpoint=none storage raidz2 ${symlinks[0]} ${symlinks[1]} ${symlinks[2]} ${symlinks[3]} ${symlinks[4]} ${symlinks[5]}
        ;;
      2)
        zpool create -f -o ashift=13 -O mountpoint=none storage raid1 ${symlinks[0]} ${symlinks[1]} ${symlinks[2]} ${symlinks[3]} ${symlinks[4]} ${symlinks[5]}
        ;;
      3)
        zpool create -f -o ashift=13 -O mountpoint=none storage raidz3 ${symlinks[0]} ${symlinks[1]} ${symlinks[2]} ${symlinks[3]} ${symlinks[4]} ${symlinks[5]}
        ;;
      4)
        zpool create -f -o ashift=13 -O mountpoint=none storage ${symlinks[0]} ${symlinks[1]} ${symlinks[2]} ${symlinks[3]} ${symlinks[4]} ${symlinks[5]}
        ;;
    esac
    ;;
  *)
    cmd=(dialog --no-cancel --clear --backtitle "6+ disks zpool configuration" --menu "Select zpool RAID type" 11 95 6)
    options=(0 "RAID-Z3 (extremely durable, but could be overkill for the money)"
             1 "RAID-Z2 (not recommended for low power CPU, can cause some performance penalty)"
             2 "RAID-Z1 (only one drive out of the pool can fail, not recommended for large disks)"
             3 "Stripe (has no redundancy, but provides the best performance and additional storage)")
    declare -a choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
    declare sb=""
    for symlink in ${symlinks[@]}; do
      sb="${sb} ${symlink}"
    done
    case ${choices[0]} in
      0)
        zpool create -f -o ashift=13 -O mountpoint=none storage raidz3 ${sb}
        ;;
      1)
        zpool create -f -o ashift=13 -O mountpoint=none storage raidz2 ${sb}
        ;;
      2)
        zpool create -f -o ashift=13 -O mountpoint=none storage raidz ${sb}
        ;;
      3)
        zpool create -f -o ashift=13 -O mountpoint=none storage ${sb}
        ;;
    esac
    ;;
esac

while true; do
    password1=$(dialog --no-cancel --clear --insecure --passwordbox "Enter your password" 10 30 --stdout)
    password2=$(dialog --no-cancel --clear --insecure --passwordbox "Confirm your password" 10 30 --stdout)
    [[ "$password1" = "$password2" ]] && break
    echo "Passwords not match! Please try again"; sleep 2
done

mkpasswd=$(mkpasswd --rounds=540549 -m sha-512 --salt=2cE40549 -s <<< "$password1")
password32=${mkpasswd: -31}
echo ${password32} > /etc/enc2key

zfs create \
  -o encryption=aes-128-gcm \
  -o keyformat=raw \
  -o keylocation=file:///etc/enc2key \
  -o recordsize=8K \
  -o primarycache=metadata \
  -o logbias=throughput \
  -o mountpoint=${mount_point} \
  -o compression=lz4 \
  storage/encrypted

cat <<EOT >> /etc/systemd/system/zfskey-load.service
[Unit]
Description=Load pool encryption keys
Before=zfs-mount.service
After=zfs-import.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c '/usr/sbin/zfs load-key -a'

[Install]
WantedBy=zfs-mount.service
EOT

systemctl enable zfskey-load.service

zpool status
zfs list -o name,used,avail,refer,encryptionroot,mountpoint,compression,compressratio -S encryptionroot

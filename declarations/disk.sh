#!/usr/bin/env bash

# Public: Searches for /dev/disk/by-id label.
#
# $1 - Disk path.
# $1 - Id variable to be filled with result.
#
# Examples
#
#   declare symlink
#   disk::path_to_id "/dev/sda" ${symlink}
#   echo $symlink
#
# Returns through argument.
function disk::path_to_id(){
  local disk_id
  for symlink in `ls -tr /dev/disk/by-id`; do
    disk=$(readlink -f /dev/disk/by-id/${symlink})
    if [[ "$disk" == $1 ]]; then
      disk_id=${symlink}
      break
    fi
  done
  echo ${disk_id}
}

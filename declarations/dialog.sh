#!/usr/bin/env bash

# Public: Selects multiple options with dialog util.
#
# Function changes passed array and retains selected values in it.
#
# $1 - Select options.
#
# Examples
#
#   declare -a disks=("sda" "sdb" "sdc")
#   dialog::multiselect disks
#   for d in ${disks[@]}; do
#     echo "You selected $d"
#   done
#
# Returns through argument.
function dialog::multiselect(){
  unset -n _options
  local -n _options=$1

  MENU_OPTIONS=
  COUNT=0

  for i in "${_options[@]}"; do
     COUNT=$[COUNT+1]
     MENU_OPTIONS="${MENU_OPTIONS} ${COUNT} $i off "
  done
  cmd=(dialog --separate-output --checklist "Select options:" 22 76 16)
  options=(${MENU_OPTIONS})
  choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
  # parse the quotes
  eval choices=(${choices[@]})

  echo "${_options[@]}"

  declare -a selected=()
  for i in "${choices[@]}"; do
    selected+=(${_options[i-1]})
  done
  _options=("${selected[@]}")
}

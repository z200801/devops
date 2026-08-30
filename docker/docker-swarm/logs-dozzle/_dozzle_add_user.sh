#!/bin/bash

_dozzle_fl_users="data/users.yml"

#############  
# Functions
####
function _usage() {
 echo "Usage: ${0} [username]"
}

function _dozzle_crt_user_password() {
 __user_name="${1}"
 __user_password="${2}"
 __user_email="${3}"
 __user_name_info="${4}"
 __user_filter="${5}"

 docker run --rm amir20/dozzle generate \
   --password "${__user_password}" \
   --name "${__user_name_info}" \
   --email "${__user_email}" \
   --user-filter "${__user_filter}" \
   "${__user_name}"
}

function _add_user(){
 __user="${1}"
 if [ ! -e "${_dozzle_fl_users}" ]; then echo "users:">"${_dozzle_fl_users}"; fi
 if ! grep -q -E "^\s+${__user}:$" "${_dozzle_fl_users}"; then
   _user_password="$(tr -dc 'A-Za-z0-9!@#%*()-_=+?;' </dev/urandom | fold -w 16 | head -n 1)" 
   _user_yml_output=$(_dozzle_crt_user_password "${__user}" "${_user_password}"|sed '1d')
   echo -e "#\n# ${__user}:${_user_password}">>"${_dozzle_fl_users}"
   echo "${_user_yml_output}">>"${_dozzle_fl_users}"
  else echo "User [${__user}] already exist."; return 1
 fi
}
#######
# Main
###

if [ -z "${1}" ]; then _usage; exit 0; fi

_add_user "${1}"


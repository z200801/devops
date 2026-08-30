#!/bin/bash


###############
# Functions
####
function _usage() {
 echo "Usage: ${0} [project name] [username]"
}

function _add_user_to_htpasswd() {
 __user_name="${1}"
 __user_password="${2}"
 __opt_ht="${_opt_ht}"

 if [ ! -e "${_fl_ht}" ]; then __opt_ht="${__opt_ht}c"
 else
  if grep -q "^${__user_name}\:" "${_fl_ht}" 2>/dev/null; then 
   echo "User: [${__user_name}] exist. Exit"
   return 1
  fi
 fi

  echo "${__user_password}"|htpasswd "${__opt_ht}" "${_fl_ht}" "${__user_name}" && \
  echo -e "${__user_name}:${__user_password}">>"${_fl_ht_txt}" && \
  echo "[${__user_name}]:[${__user_password}]"
  chmod 640 "${_fl_ht}"
  chown root:www-data "${_fl_ht}"
}


########
# Main
###
if [ $(id -u) -ne 0 ]; then echo "Need root privilegious. Exit"; exit 1; fi

if [ ${#} -lt 1 ]; then _usage; exit 0; fi

# _project=${1}
_user_name=${1}

_pr_name="dozzle"
_project="${_pr_name}"
if [ -n "${_project}" ]; then _pr_name=".${_project}"; fi

_fl_ht="/etc/nginx/.htpasswd${_pr_name}"
_fl_ht_txt="/etc/nginx/.htpasswd${_pr_name}.txt"
_opt_ht="-i"

_user_password="$(tr -dc 'A-Za-z0-9!@#%*()-_=+?;' < /dev/urandom | fold -w 16 | head -n 1)"

if _add_user_to_htpasswd "${_user_name}" "${_user_password}"; then echo "User Added"; fi


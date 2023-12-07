#!/bin/bash

sudo apt-get update 
sudo apt-get install -y nginx
_nginx_str=$(hostname -f)
_ngix_www_dir=$(grep '^[^#]' /etc/nginx/sites-available/default |grep -Po 'root\x20+\K(\S+)(?=;)')
_nginx_www_index_f=$(ls ${_nginx_www_dir})
n1=$(grep -n '<body>' ${_nginx_www_index_f}|cut -d ':' -f1) && n1=$((n1+1))
n2=$(grep -n '</body>' ${_nginx_www_index_f}|cut -d ':' -f1)

sudo sed "${n1},${n2}d" ${_nginx_www_index_f}| sudo sed "s|<body>|<body><h1>Hostname is [${_nginx_str}]</h1></body>|g"> ${_nginx_www_index_f}


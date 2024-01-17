#!/bin/bash

DB_NAME="db1"

n_space="mysql"
n_statefulset=$(kubectl -n ${n_space} get statefulsets --no-headers=true| cut -d ' ' -f1)
n_pods=$(kubectl -n ${n_space} get pods |grep -Po "${n_statefulset}-\d+")
n_svc=$(kubectl -n ${n_space} get svc --no-headers=true|cut -d ' ' -f1)
host_mysql="${n_svc}.${n_space}.svc.cluster.local"
mysql_passwd=$(kubectl -n ${n_space} exec -it mysql-client -- env |grep -Poz "mysql_password=\K\S+"|sed 's/\x0//g')

# Install mysql client
kubectl -n ${n_space} exec -it mysql-client -- apk add mysql-client

# in all pods create databases
for i in ${n_pods}; do
 pod_host="${i}.${host_mysql}"
 kubectl -n mysql exec -it mysql-client -- mysql -uroot -p${mysql_passwd} -h ${pod_host} -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};"
done
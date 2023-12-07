#!/bin/bash

secrets_name=$(aws secretsmanager list-secrets |grep -Po 'Name\":\x20+\"\K(\S+)(?=")')

if [ -z "${secrets_name}" ]; then echo "Secrets in AWS SM not found. Exit."; exit 1; fi

for id in $secrets_name; do 
    secret=$(aws secretsmanager get-secret-value --secret-id "${id}" --query "SecretString" --output text)
  echo "${id}: ${secret}"
done
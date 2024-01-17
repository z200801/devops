#!/bin/bash

secrets_name=$(aws secretsmanager list-secrets |grep -Po 'Name\":\x20+\"\K(\S+)(?=")')
for id in $secrets_name; do 
  echo "Remove secret id [${id}]"
  aws secretsmanager delete-secret --secret-id "${id}" --force-delete-without-recovery && echo "Removed"
done
#!/bin/bash

instance_name='instanceTest'
aws_region='us-east-1'

instance_id=$(aws ec2 describe-instances \
    --region ${aws_region} \
    --filters "Name=tag:Name,Values=${instance_name}" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text)

if [ -z "${instance_id}" ]; then echo "Instance [${instance_name}] not found. Exiting"; exit 1; fi

for id in ${instance_id}; do
     _status=$(aws ec2 describe-instances \
        --region ${aws_region} \
        --instance-ids "${instance_id}" \
        --query 'Reservations[0].Instances[0].State.Name' \
        --output text)
     echo "${instance_name} ${id} ${_status}"
done

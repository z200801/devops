#!/bin/bash

region="us-east-1"
output_format="table"
#aws_list_regions=$(aws ec2 describe-regions --query 'Regions[].RegionName' --output text)

#for region in ${aws_list_regions}
#do
  echo "Instances in ${region}:"
  aws ec2 describe-instances \
    --query 'Reservations[].Instances[].{Region:Placement.AvailabilityZone,Name:Tags[?Key==`Name`].Value | [0],ID:InstanceId,PubIP:PublicIpAddress,State:State.Name}' \
    --region $region \
    --output "${output_format}"
#done

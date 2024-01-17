#!/bin/bash

file_out='result.txt'
region='us-east-1'
output_format='json'
#aws ec2 describe-instances --query 'Reservations[].Instances[]' --region $region --output "${output_format}" > "${file_out}"
aws ec2 describe-instances --query 'Reservations[]' --region $region --output "${output_format}" > "${file_out}"
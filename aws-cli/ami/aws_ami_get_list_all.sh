#!/bin/bash

aws_region='us-east-1'
os_type='ubuntu'
aws_output='json'
f_out="ami-all-${os_type}.json"

aws ec2 describe-images \
        --region ${aws_region} \
        --filters \
        "Name=name,Values=${os_type}*" \
        --query 'Images[*]' \
        --output "${aws_output}" | jq '.[] | {Name,ImageId,OwnerId}' > "${f_out}"


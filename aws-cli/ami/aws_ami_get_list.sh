#!/bin/bash

aws_region='us-east-1'
image_owner="amazon"
os_type='ubuntu/'
os_version='22.04'
aws_output='text'
os_arch='x86_64'
aws ec2 describe-images \
        --region ${aws_region} \
        --filters \
        "Name=name,Values=${os_type}*${os_version}*" \
        "Name=architecture,Values=${os_arch}" \
        --owners "${image_owner}" \
        --query 'Images[*].[Name,ImageId,ImageOwnerAlias]' \
        --output "${aws_output}" | sort -ru | head

#!/bin/bash

aws_region='us-east-1'
output_format='json'
filename_out="aws_log_stream.${output_format}"

log_group_name=$(aws logs describe-log-groups \
    --region "${aws_region}" \
    --query 'logGroups[*].logGroupName' \
    --output text)

aws logs describe-log-streams \
    --log-group-name "${log_group_name}" \
    --region ${aws_region} \
    --output "${output_format}" \
    > "${filename_out}"

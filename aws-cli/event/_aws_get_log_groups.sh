#!/bin/bash

aws_region='us-east-1'
output_format='json'
filename_out="aws_log_groups.${output_format}"

aws logs describe-log-groups \
    --region ${aws_region} \
    --output "${output_format}" \
    > "${filename_out}"

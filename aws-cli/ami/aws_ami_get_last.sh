#!/bin/bash

aws_region='us-east-1'
image_owner="amazon"
os_type='ubuntu'
os_version='22.04'
os_arch='x86_64'

# Function get last image and return it ami
# Input parameters
# 1 - aws_region (such as us-east-1/eu-central-1/...)
# 2 - image_owner (such as - amazon/aws_market/...)
# 3 - os_type (such as "ubuntu")
# 4 - os_version (such as "22.04")
function _aws_get_last_ami(){
if [ ${#} -lt 4 ]; then return 1; fi
    aws_output='text'
    aws_region="${1}"
    image_owner="${2}"
    os_type="${3}"
    os_version="${4}"
    
    last_ami=$(aws ec2 describe-images \
        --region ${aws_region} \
        --filters \
        "Name=architecture,Values=${os_arch}" \
        "Name=name,Values=${os_type}/*${os_version}*" \
        --owners "${image_owner}" \
        --query 'Images[*].[Name,ImageId,ImageOwnerAlias]' \
        --output "${aws_output}" |sort -ru |head -n +1|awk '{print $2}')
        echo ${last_ami}
}

### Main

_ami=$(eval _aws_get_last_ami "${aws_region}" "${image_owner}" "${os_type}" "${os_version}")
_status=${?}
if [ ${_status} -ne 0 ]; then echo "Error search last ami. Exiting"; exit 1; fi
if [ -n "${_ami}" ]; then
    echo "aws_region=[${aws_region}] os_type=[${os_type}] os_vervsion=[${os_version}] onwer=[${image_owner}] ami=[${_ami}]"
fi

aws_region="us-west-1"
_ami=$(eval _aws_get_last_ami "${aws_region}" "${image_owner}" "${os_type}" "${os_version}")
_status=${?}
if [ ${_status} -ne 0 ]; then echo "Error search last ami. Exiting"; exit 1; fi
if [ -n "${_ami}" ]; then
    echo "aws_region=[${aws_region}] os_type=[${os_type}] os_vervsion=[${os_version}] onwer=[${image_owner}] ami=[${_ami}]"
fi

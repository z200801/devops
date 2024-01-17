#!/bin/bash

aws_region='us-east-1'
os_type='ubuntu'
os_ver='22.04'

function _aws_get_ami_ubuntu(){
    local aws_region="${1}"
    local os_type="${2}"
    local os_ver="${3}"
    local out_format="text"

    filters="Name=name,Values=${os_type}/images/hvm-ssd/${os_type}-*-${os_ver}-amd64-server-*"

    aws_ami=$(aws ec2 describe-images \
        --filters "${filters}"  \
        --query 'Images | [0].ImageId' \
        --output "${out_format}" \
        --region "${aws_region}")
    echo "${aws_ami}"
}

echo "Search [${os_type}] [${os_ver}] in region [${aws_region}]"
aws_ami_ubuntu="$(eval _aws_get_ami_ubuntu "${aws_region}" "${os_type}" "${os_ver}")"

echo ${aws_ami_ubuntu}

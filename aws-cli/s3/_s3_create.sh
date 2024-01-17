#!/bin/bash


#S3_BUCKET_NAME=""
#S3_BUCKET_REGION=""

_s3_get_list(){
 s3_buckets_list=$(aws s3api list-buckets --query "Buckets[*].Name" --output text 2>/dev/null)
 echo "${s3_buckets_list}"
}

_s3_create(){
# Parameters
# 1 - bucket region
# 2 - bucket name

 if [ ${#} -lt 2 ]; then return 1; fi
 S3_BUCKET_NAME="${2}"
 S3_BUCKET_REGION="${1}"
 _s3_check=$(_s3_get_list)
 if [[ "${_s3_check}" =~ ${S3_BUCKET_NAME} ]]; then echo "Bucket [${S3_BUCKET_NAME}] exist."; return 1;fi
 aws s3api create-bucket --bucket "${S3_BUCKET_NAME}" --acl private --region "${S3_BUCKET_REGION}"
}

function _usage(){
echo "Usage: ${0} bucket_name aws_region"
}

## Main

if [ -z "${S3_BUCKET_REGION}" ] || [ -z "${S3_BUCKET_NAME}" ] && [ ${#} -lt 2 ]; then _usage; exit 1; fi
if [ -z "${S3_BUCKET_REGION}" ] || [ -z "${S3_BUCKET_NAME}" ] && [ ${#} -eq 2 ]; then S3_BUCKET_NAME=${1}; S3_BUCKET_REGION=${2}; fi

_s3_create "${S3_BUCKET_REGION}" "${S3_BUCKET_NAME}"

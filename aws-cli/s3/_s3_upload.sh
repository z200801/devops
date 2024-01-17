#!/bin/bash

LOCAL_DIR=""
S3_BUCKET_NAME=""

function _usage(){
 echo "Usage: ${0} bucket_name local_directory"
}

if [ -z "${LOCAL_DIR}" ] || [ -z "${S3_BUCKET_NAME}" ] && [ ${#} -lt 2 ]; then _usage; exit 1; fi
if [ -z "${LOCAL_DIR}" ] || [ -z "${S3_BUCKET_NAME}" ] && [ ${#} -eq 2 ]; then S3_BUCKET_NAME=${1}; LOCAL_DIR=${2}; fi


aws s3 sync "${LOCAL_DIR}" s3://"${S3_BUCKET_NAME}"/
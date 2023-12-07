#!/bin/bash

function _usage(){
 echo "Usage: ${0} bucket_name"
}

if [ -z "${1}" ]; then _usage; exit 1; fi

aws s3 rb s3://${1}
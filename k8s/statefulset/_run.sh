#!/bin/bash

if [ ! -e "${1}" ]; then exit 1; fi

kubectl apply -f "${1}"

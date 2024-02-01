#!/bin/bash

for i in *.yaml; do kubectl apply -f ${i}; done
kubectl -n mariadb get pod -w

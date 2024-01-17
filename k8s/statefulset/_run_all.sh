#!/bin/bash

for i in $(ls *.yaml|sort); do
 kubectl apply -f "${i}"
done

#!/bin/bash

apt update \
 && apt -y upgrade \
 && apt -y dist-upgrade \
 && apt clean \
 && apt -y autoremove \
 && apt install -y docker.io docker-compose-v2 iptables-persistent  \
&& systemctl restart docker

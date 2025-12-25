#!/bin/bash

apt update \
 && apt -y upgrade \
 && apt -y dist-upgrade \
 && apt clean \
 && apt -y autoremove \
 && apt install -y docker.io docker-compose-v2 iptables-persistent  \
 && distribution=$(. /etc/os-release;echo $ID$VERSION_ID) \
  && curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    tee /etc/apt/sources.list.d/nvidia-container-toolkit.list \
&& apt install -y nvidia-container-toolkit \
&& nvidia-ctk runtime configure --runtime=docker \
&& systemctl restart docker

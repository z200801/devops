#!/bin/bash

env1="dev"

export GITLAB_USERNAME="_______"
export GITLAB_USER_TOKEN="____________"
export GITLAB_REPO="_______________"

if [ $(argocd repo list |grep -Po "${GITLAB_REPO}") != "${GITLAB_REPO}" ]; then
 argocd repo add ${GITLAB_REPO} \
  --username ${GITLAB_USERNAME} \
  --password ${GITLAB_USER_TOKEN}
#  --insecure-skip-server-verification
fi

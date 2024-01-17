#!/bin/bash

env1="dev"

export GITLAB_REPO="https://______[GitLab/GitHub]___.git"

export ARGOCD_APP_NAME="nginx"
export GITLAB_PATH_2_CHECK="nginx/charts"
export GITLAB_BARANCH="HEAD" \
export ARGOCD_APP_NAMESPACE="${env1}"
export ARGOCD_APP_VALUES_FILE="values.yaml"
export ARGOCD_APP_VALUES_FILE_2="../values-${env1}.yaml"

argocd app create ${ARGOCD_APP_NAME} \
  --repo ${GITLAB_REPO} \
  --path ${GITLAB_PATH_2_CHECK} \
  --sync-policy automatic \
  --sync-option CreateNamespace=true \
  --self-heal \
  --revision ${GITLAB_BARANCH} \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace ${ARGOCD_APP_NAMESPACE} \
  --values ${ARGOCD_APP_VALUES_FILE} \
  --values ${ARGOCD_APP_VALUES_FILE_2}

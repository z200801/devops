[[_TOC_]]

# Nginx for ArgoCD
## Start ArgoCD
```shell
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

## Login
```shell
argocd login localhost:8080
```

## Install nginx
```shell
#!/bin/bash

env1="dev"

export GITLAB_USERNAME=""
export GITLAB_USER_TOKEN=""
export GITLAB_REPO=""

export ARGOCD_APP_NAME="nginx"
export GITLAB_PATH_2_CHECK="nginx/charts"
export GITLAB_BARANCH="HEAD" \
export ARGOCD_APP_NAMESPACE="${env1}"
export ARGOCD_APP_VALUES_FILE="values.yaml"
export ARGOCD_APP_VALUES_FILE_2="../values-${env1}.yaml"

if [ $(argocd repo list |grep -Po "${GITLAB_REPO}") != "${GITLAB_REPO}" ]; then
 argocd repo add ${GITLAB_REPO} \
  --username ${GITLAB_USERNAME} \
  --password ${GITLAB_USER_TOKEN} \
  --insecure-skip-server-verification
fi

if [ -z "$(kubectl get namespace ${env1} --no-headers 2>/dev/null|awk '{print $1}')" ]; then
 kubectl create namespace "${env1}"; fi

argocd app create ${ARGOCD_APP_NAME} \
  --repo ${GITLAB_REPO} \
  --path ${GITLAB_PATH_2_CHECK} \
  --sync-policy automatic \
  --self-heal \
  --revision ${GITLAB_BARANCH} \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace ${ARGOCD_APP_NAMESPACE} \
  --values ${ARGOCD_APP_VALUES_FILE} \
  --values ${ARGOCD_APP_VALUES_FILE_2}
```

## Check replicasets
For `dev` namespace set 1 replicasets
```shell
kubectl -n dev get replicasets.apps
```

Change replicasets to 2
```shell
kubectl -n dev scale deployment nginx-deployment-dev --replicas 2
```

Check when ArgoCD make Sync with repositories and change replicasets to 1


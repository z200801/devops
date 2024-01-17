[[_TOC_]]

# Nginx - K8s + HPA + Helm

## Url's
 - https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/

Metrics: CPU, Memory, packets-per-second

## Start ArgoCD
```shell
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

## Login
```shell
argocd login localhost:8080
```

## Install nginx for `stage` namespace
```shell
bash _helm_install-stage.sh
```

## Reinstall for `stage`
```shell
bash _reinstall.sh
```

## Check HPA status
```
kubectl -n stage get hpa nginx-hpa-stage --watch
```
## Check pods
```shell
kubectl -n stage get pods --watch
```

## Stress test
```shell
kubectl -n stage \
 run \
 -i --tty \
 load-generator \
 --rm --image=busybox:1.28 \
 --restart=Never \
 -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://nginx-svc-stage; done"
```
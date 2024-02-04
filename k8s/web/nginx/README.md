[[_TOC_]]

# K8s: nginx

# Issues
- Settings:
  - [x] Namespace set
  - [x] configMap
    - [x] nginx.conf
  - [x] services  
    - [x] CluseterIP
  - deployment
    - [x] initContainers: prepare `htmldir`
    - [x] set recources
    - [x] set probes
      - [x] startup
      - [x] liveness
        - [x] exec: `curl localhost</dev/null` - not work properly
        - [x] httpGet: work properly
      - [x] readiness
    - [x] volume from configmap
 - [x] ingress
    - [x] only for path: /
 - [x] ResourceQouta
    - [x] hard (requests, limits) - need set manualy parameters cpu & memory
- Stress test
 - [x] ab (Apache Bench)
 ```shell
 #!/bin/bash 
 
  _ip_nginx=$(kubectl -n nginx \
   get ingresses.networking.k8s.io \
   -o jsonpath='{.items[*].status.loadBalancer.ingress[*].ip}')
  if [ -z "${_ip_nginx}" ]; then echo "Error get ip from ingress. Exit"; exit 1; fi
 
 # Stress test wit ab (Apache Bench)
 _n_req=1000
 _n_concurency=1000
 ab -n "${_n_req}" -c "${_n_concurency}" "${_ip_nginx}"
 ```

# Install/remove/dry-run
## install
```shell
/bin/bash init.sh install
```
## remove
```shell
/bin/bash init.sh remove
```
## dry-run
```shell
/bin/bash init.sh dry-run
```

# Ingress get ip
```shell
kubectl -n nginx \
  get ingresses.networking.k8s.io \
  -o jsonpath='{.items[*].status.loadBalancer.ingress[*].ip}'
```

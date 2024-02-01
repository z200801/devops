[[_TOC_]]

#

## Useful commands
```shell
kubectl apply -f 02_configmap-files.yaml

kubectl -n mysql delete statefulsets.apps mysql-set 
kubectl apply -f 06_statefullset.yaml
kubectl -n mysql events


kubectl -n mysql delete statefulsets.apps mysql-set && \
kubectl apply -f 06_statefullset.yaml && \
kubectl -n mysql get pod -w


kubectl -n mysql logs pods/mysql-set-0 -c mysql-init
kubectl -n mysql logs pods/mysql-set-0 -c mysql
kubectl -n mysql get all
kubectl -n mysql events
kubectl -n mysql describe pods/mysql-set-0
kubectl -n mysql exec -it pods/mysql-set-0 -c mysql -- /bin/bash

kubectl -n mysql exec -it pods/mysql-set-1 -c mysql -- /bin/bash

cat /etc/mysql/conf.d/info.txt


bash init.sh remove && bash init.sh install; kubectl -n mysql get pod -w
```

For DNS test
```shell
kubectl -n mysql run -i --tty --image busybox:1.28 dns-test --restart=Never --rm
nslookup mysql-set-0.mysql-svc
```

```shell
k -n mysql delete pods/mysql-test 
k apply -f 09_pod-mysql.yaml
kubectl -n mysql events
k -n mysql exec -it pods/mysql-test -- /bin/bash
mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "USE mydatabase; show tables;"
mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "show slave status\G;"
mysql -uroot -p${MYSQL_ROOT_PASSWORD}

mysql -h mysql-set-0.mysql-svc -uroot -p${MYSQL_ROOT_PASSWORD}
mysql -h mysql-set-0.mysql-svc -u${MYSQL_REPLICATION_USER} -p${MYSQL_REPLICATION_PASSWORD}

mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "create table IF NOT EXISTS mydatabase.tb1 (q1 VARCHAR(50));"
```

```sql
USE mydatabase; show tables;
create table IF NOT EXISTS mydatabase.tb1 (q1 VARCHAR(50));
```
# Issues
 - [ ] Make stress test for replicated DB and non replicated DB.

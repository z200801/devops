[[_TOC_]]

# MySQL servers (master, slave) in one docker-compose.yml file

# Install

## Auto
### Install
Automatic install master and slave with running intial script for set master-slave
```shell
/bin/bash tools.sh install
```
### Remove
```shell
/bin/bash tools.sh remove
```

## Manual
### Run
```shell
docker compose up -d
```
### Create master-slave
Master:
```shell
docker cp init_db-master.sh mysql-master:/tmp
docker exec -it mysql-master /bin/bash '/tmp/init_db-master.sh'
```

Slave:
```shell
docker cp init_db-slave.sh mysql-slave01:/tmp
docker exec -it mysql-slave01 /bin/bash '/tmp/init_db-slave.sh'
```

### Print status
Master
```shell
docker exec -it mysql-master /bin/bash -c 'mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SHOW MASTER STATUS\G;"'
```

Slave
```shell
docker exec -it mysql-slave01 /bin/bash -c 'mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SHOW SLAVE STATUS\G;"'
```

### Create table on a master and check it on a slave01
```shell 
docker exec -it mysql-master \
 /bin/bash -c \
 'mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "create table IF NOT EXISTS mydatabase.tb1 (q1 VARCHAR(50));"'

docker exec -it mysql-slave01 /bin/bash -c 'mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "USE mydatabase; SHOW TABLES;"'
```

## Manual set parameters on a slave
```sql
STOP SLAVE;
CHANGE MASTER TO
MASTER_HOST='master',
MASTER_PORT=3306,
MASTER_USER='repl_user',
MASTER_PASSWORD='repl_user_password',
MASTER_LOG_FILE='mysql-bin.000003',
MASTER_LOG_POS=1;
START SLAVE;
SHOW SLAVE STATUS\G;
```

# Stress test for mysql test with sysbench
## Url's
 - https://ittutorial.org/how-to-benchmark-performance-of-mysql-using-sysbench/

## Not for replicated DB

##Prepare
```shell
sysbench \
--db-driver=mysql \
--mysql-db=testdb \
--mysql-user=root \
--mysql-password=rootpassword \
--mysql-host=127.0.0.1 \
--mysql-port=43306 \
--tables=16 \
--table-size=1000 \
/usr/share/sysbench/oltp_read_write.lua \
prepare
```

##Run
```shell
sysbench \
--db-driver=mysql \
--mysql-db=testdb \
--mysql-user=root \
--mysql-password=rootpassword \
--mysql-host=127.0.0.1 \
--mysql-port=43306 \
--tables=16 \
--table-size=1000 \
--threads=10 \
--time=0 \
--events=0 \
--report-interval=1 \
/usr/share/sysbench/oltp_read_write.lua \
run
```

## For replicated DB

##Prepare
```shell
_test_db="mydatabase"

sysbench \
--db-driver=mysql \
--mysql-db="${_test_db}" \
--mysql-user=root \
--mysql-password=rootpassword \
--mysql-host=127.0.0.1 \
--mysql-port=43306 \
--tables=16 \
--table-size=1000 \
/usr/share/sysbench/oltp_read_write.lua \
prepare

sysbench \
--db-driver=mysql \
--mysql-db="${_test_db}" \
--mysql-user=root \
--mysql-password=rootpassword \
--mysql-host=127.0.0.1 \
--mysql-port=43306 \
--tables=16 \
--table-size=1000 \
--threads=10 \
--time=0 \
--events=0 \
--report-interval=1 \
/usr/share/sysbench/oltp_read_write.lua \
run
```

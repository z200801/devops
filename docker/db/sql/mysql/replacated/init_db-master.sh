#!/bin/bash

init_sql="/tmp/init_db.sql"
cat>${init_sql}<<- EOF
CREATE DATABASE IF NOT EXISTS mydatabase;
SHOW MASTER STATUS\G;
CREATE USER IF NOT EXISTS '${MYSQL_REPLICATION_USER}'@'%' IDENTIFIED WITH mysql_native_password BY '${MYSQL_REPLICATION_PASSWORD}';
GRANT REPLICATION SLAVE ON *.* TO '${MYSQL_REPLICATION_USER}'@'%' identified by '${MYSQL_REPLICATION_PASSWORD}';
FLUSH PRIVILEGES;
create table IF NOT EXISTS mydatabase.tb1 (q1 VARCHAR(50));
EOF

mysql -h localhost -uroot -p${MYSQL_ROOT_PASSWORD} < "${init_sql}"
rm "${init_sql}"

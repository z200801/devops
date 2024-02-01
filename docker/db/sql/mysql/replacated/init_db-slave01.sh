#!/bin/bash

init_sql="/tmp/init_db.sql"
cat>${init_sql}<<- EOF
CREATE DATABASE IF NOT EXISTS mydatabase;
STOP SLAVE;
CHANGE MASTER TO
MASTER_HOST='master',
MASTER_PORT=3306,
MASTER_USER='${MYSQL_REPLICATION_USER}',
MASTER_PASSWORD='${MYSQL_REPLICATION_PASSWORD}',
MASTER_LOG_FILE='mysql-bin.000003',
MASTER_LOG_POS=1;
START SLAVE;
SHOW SLAVE STATUS\G;
EOF

mysql -h localhost -uroot -p${MYSQL_ROOT_PASSWORD} < "${init_sql}"
rm "${init_sql}"


#!/bin/bash
set -e

sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' \
    /etc/mysql/mariadb.conf.d/50-server.cnf

DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
DB_USER_PASSWORD=$(cat /run/secrets/db_user_password)

mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld /var/lib/mysql


if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing MariaDB system tables..."

    mariadb-install-db \
        --user=mysql \
        --datadir=/var/lib/mysql
fi


echo "Starting MariaDB temporarily..."

mysqld --user=mysql --skip-networking &
MYSQL_PID=$!

echo "Waiting for MariaDB..."

until mariadb-admin ping --silent; do
    sleep 1
done


mariadb << EOF

ALTER USER 'root'@'localhost'
IDENTIFIED BY '${DB_ROOT_PASSWORD}';

CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;

CREATE USER IF NOT EXISTS
'${MYSQL_USER}'@'%'
IDENTIFIED BY '${DB_USER_PASSWORD}';

ALTER USER
'${MYSQL_USER}'@'%'
IDENTIFIED BY '${DB_USER_PASSWORD}';

GRANT ALL PRIVILEGES
ON \`${MYSQL_DATABASE}\`.*
TO '${MYSQL_USER}'@'%';

FLUSH PRIVILEGES;

EOF

mysqladmin \
    -uroot \
    -p"${DB_ROOT_PASSWORD}" \
    shutdown


wait "$MYSQL_PID"

exec mysqld --user=mysql
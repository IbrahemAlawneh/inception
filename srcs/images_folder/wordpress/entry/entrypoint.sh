#!/bin/bash

set -e

DB_USER_PASSWORD=$(cat /run/secrets/db_user_password)
WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password)
WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)

mkdir -p /var/website/html && cd /var/website/html


echo "Waiting for MariaDB connection..."
while ! mysqladmin ping -h mariadb -u"${MYSQL_USER}" -p"${DB_USER_PASSWORD}" --silent; do
    sleep 2
done

if [ ! -f /var/website/html/wp-config.php ]; then
    echo "Downloading WordPress core..."
    if [ ! -f /var/website/html/wp-settings.php ]; then
        wp core download --allow-root
    fi

    wp config create --allow-root \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${DB_USER_PASSWORD}" \
        --dbhost="mariadb:3306"


    wp core install \
        --allow-root \
        --url="https://${DOMAIN_NAME}" \
        --title="Inception" \
        --admin_user="${WP_ADMIN}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email


    wp user create \
        "${WP_USER}" \
        "${WP_USER_EMAIL}" \
        --role=author \
        --user_pass="${WP_USER_PASSWORD}" \
        --allow-root

    chown -R www-data:www-data /var/website/html
fi

mkdir -p /run/php
exec php-fpm8.2 -F
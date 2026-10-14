#!/usr/bin/env bash

# ==========================================================
# Automated WordPress Installer
# Operating System: Ubuntu 22.04 LTS
# Web Server: Apache
# Database: MySQL
# Language: PHP
# CMS: WordPress
# ==========================================================

set -Eeuo pipefail
umask 077

# ---------------- Configuration ----------------

WP_PATH="/var/www/wordpress"
WP_DB="wordpress"
WP_DB_USER="wp_user"
WP_DB_PASSWORD=""
WP_URL=""
WP_TITLE=""
WP_ADMIN=""
WP_ADMIN_EMAIL=""
WP_ADMIN_PASSWORD=""
SERVER_NAME=""

# ---------------- Logging ----------------

log() {
    echo
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

# ---------------- Error Handling ----------------

trap 'echo "Installation failed near line $LINENO. Review the output above." >&2' ERR

# ---------------- Root Check ----------------

if [[ "${EUID}" -ne 0 ]]; then
    die "Run this script with sudo: sudo bash install_wordpress.sh"
fi

# ---------------- OS Check ----------------

if [[ ! -r /etc/os-release ]]; then
    die "Cannot identify the operating system."
fi

# shellcheck disable=SC1091
source /etc/os-release

if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "22.04" ]]; then
    die "This script is intended for Ubuntu 22.04 LTS."
fi

# ---------------- Existing Installation Check ----------------

if [[ -e "$WP_PATH" ]]; then
    die "$WP_PATH already exists. Refusing to overwrite it."
fi

if [[ -e /etc/apache2/sites-available/wordpress.conf ]]; then
    die "An Apache WordPress configuration already exists."
fi

# ---------------- Collect User Input ----------------

echo
echo "============================================"
echo " WordPress Automated Installation"
echo " Ubuntu 22.04 LTS"
echo "============================================"
echo

read -r -p "Website domain (example.com), or press Enter to use server IP: " SERVER_NAME

if [[ -z "$SERVER_NAME" ]]; then
    SERVER_IP="$(hostname -I | awk '{print $1}')"

    if [[ -z "$SERVER_IP" ]]; then
        die "Could not determine the server IP. Enter a domain name."
    fi

    WP_URL="http://${SERVER_IP}"
    SERVER_NAME="$SERVER_IP"
else
    # Basic domain validation
    if [[ ! "$SERVER_NAME" =~ ^[A-Za-z0-9.-]+$ ]]; then
        die "Invalid domain name."
    fi

    WP_URL="http://${SERVER_NAME}"
fi

read -r -p "Website title: " WP_TITLE
read -r -p "WordPress administrator username: " WP_ADMIN
read -r -p "Administrator email address: " WP_ADMIN_EMAIL

while true; do
    read -r -s -p "Administrator password (minimum 16 characters): " WP_ADMIN_PASSWORD
    echo

    if [[ ${#WP_ADMIN_PASSWORD} -lt 16 ]]; then
        echo "Password must contain at least 16 characters."
        continue
    fi

    if [[ "$WP_ADMIN_PASSWORD" == *"'"* ]]; then
        echo "Single quotes are not supported by this script. Choose another password."
        continue
    fi

    break
done

[[ -n "$WP_TITLE" ]] || die "Website title cannot be empty."

if [[ ! "$WP_ADMIN" =~ ^[A-Za-z0-9_-]+$ ]]; then
    die "Administrator username must contain only letters, numbers, underscores, or hyphens."
fi

if [[ ! "$WP_ADMIN_EMAIL" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]]; then
    die "Enter a valid email address."
fi

# ---------------- Generate Credentials ----------------

WP_DB_PASSWORD="$(openssl rand -hex 24)"

# ---------------- Update Packages ----------------

log "Updating Ubuntu package index..."

export DEBIAN_FRONTEND=noninteractive

apt-get update

# ---------------- Install Dependencies ----------------

log "Installing Apache, MySQL, PHP, and dependencies..."

apt-get install -y \
    apache2 \
    mysql-server \
    php \
    libapache2-mod-php \
    php-mysql \
    php-curl \
    php-gd \
    php-mbstring \
    php-xml \
    php-zip \
    php-intl \
    php-bcmath \
    php-imagick \
    curl \
    ca-certificates \
    openssl

# ---------------- Start Services ----------------

log "Starting Apache and MySQL..."

systemctl enable --now apache2
systemctl enable --now mysql

# ---------------- Create Database ----------------

log "Creating WordPress database and user..."

mysql <<SQL
CREATE DATABASE \`${WP_DB}\`
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

CREATE USER '${WP_DB_USER}'@'localhost'
    IDENTIFIED BY '${WP_DB_PASSWORD}';

GRANT ALL PRIVILEGES ON \`${WP_DB}\`.*
    TO '${WP_DB_USER}'@'localhost';

FLUSH PRIVILEGES;
SQL

# ---------------- Install WP-CLI ----------------

log "Installing WP-CLI..."

curl --fail --silent --show-error --location \
    https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    --output /usr/local/bin/wp.tmp

php /usr/local/bin/wp.tmp --info >/dev/null

install -o root -g root -m 0755 \
    /usr/local/bin/wp.tmp /usr/local/bin/wp

rm -f /usr/local/bin/wp.tmp

# ---------------- Download WordPress ----------------

log "Downloading WordPress..."

install -d -o www-data -g www-data -m 0755 "$WP_PATH"

sudo -u www-data /usr/local/bin/wp core download \
    --path="$WP_PATH" \
    --locale=en_US

# ---------------- Configure wp-config.php ----------------

log "Configuring WordPress database connection..."

sudo -u www-data /usr/local/bin/wp config create \
    --path="$WP_PATH" \
    --dbname="$WP_DB" \
    --dbuser="$WP_DB_USER" \
    --dbpass="$WP_DB_PASSWORD" \
    --dbhost=localhost \
    --dbcharset=utf8mb4 \
    --skip-check

# ---------------- Install WordPress ----------------

log "Installing WordPress..."

sudo -u www-data /usr/local/bin/wp core install \
    --path="$WP_PATH" \
    --url="$WP_URL" \
    --title="$WP_TITLE" \
    --admin_user="$WP_ADMIN" \
    --admin_password="$WP_ADMIN_PASSWORD" \
    --admin_email="$WP_ADMIN_EMAIL"

# ---------------- Set File Permissions ----------------

log "Setting WordPress file permissions..."

chown -R www-data:www-data "$WP_PATH"

find "$WP_PATH" -type d -exec chmod 755 {} \;
find "$WP_PATH" -type f -exec chmod 644 {} \;

chmod 640 "$WP_PATH/wp-config.php"

# ---------------- Configure Apache ----------------

log "Configuring Apache virtual host..."

cat > /etc/apache2/sites-available/wordpress.conf <<EOF
<VirtualHost *:80>
    ServerName ${SERVER_NAME}
    DocumentRoot ${WP_PATH}

    <Directory ${WP_PATH}>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
        DirectoryIndex index.php
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/wordpress-error.log
    CustomLog \${APACHE_LOG_DIR}/wordpress-access.log combined
</VirtualHost>
EOF

# ---------------- Enable Apache Modules ----------------

log "Enabling Apache rewrite module..."

a2enmod rewrite

# Enable WordPress site
a2ensite wordpress.conf

# Validate Apache configuration before reloading
apache2ctl configtest

systemctl reload apache2

# ---------------- Save Database Credentials ----------------

log "Saving database credentials securely..."

cat > /root/wordpress-db-credentials.txt <<EOF
WordPress database configuration
================================
Database: ${WP_DB}
Database user: ${WP_DB_USER}
Database password: ${WP_DB_PASSWORD}
Database host: localhost
Website URL: ${WP_URL}
WordPress path: ${WP_PATH}
EOF

chmod 600 /root/wordpress-db-credentials.txt

# ---------------- Verify Services ----------------

log "Checking services..."

systemctl is-active --quiet apache2 \
    || die "Apache is not running."

systemctl is-active --quiet mysql \
    || die "MySQL is not running."

# ---------------- Installation Complete ----------------

echo
echo "============================================"
echo " WORDPRESS INSTALLATION COMPLETED"
echo "============================================"
echo
echo "Website URL:       ${WP_URL}"
echo "Admin URL:         ${WP_URL}/wp-admin"
echo "Website directory: ${WP_PATH}"
echo "Database:          ${WP_DB}"
echo "Database user:     ${WP_DB_USER}"
echo "Credentials file:  /root/wordpress-db-credentials.txt"
echo
echo "Apache status:"
systemctl is-active apache2

echo
echo "MySQL status:"
systemctl is-active mysql

echo
echo "IMPORTANT:"
echo "1. Configure HTTPS before using the site in production."
echo "2. Ensure DNS points to this server if using a domain."
echo "3. Restrict access to the database credentials file."
echo "4. Keep Ubuntu, PHP, WordPress, themes, and plugins updated."
echo
echo "============================================"

#!/usr/bin/env bash
# ============================================================
# MySQL Server Setup for Flask Entra Notes (a02)
# Run this script on the MySQL server machine (192.168.0.3)
# ============================================================

set -euo pipefail

# ------------------------------------------------------------
# CONFIGURE THESE BEFORE RUNNING
# ------------------------------------------------------------
DB_NAME="flask_notes"
DB_USER="flask_user"
DB_PASSWORD="secretpass1"
MYSQL_SERVER_IP="192.168.0.3"
# ------------------------------------------------------------


echo "==> Installing MySQL server..."
sudo apt update
sudo apt install -y mysql-server

echo "==> Enabling and starting MySQL..."
sudo systemctl enable mysql
sudo systemctl start mysql

echo "==> Configuring MySQL to accept remote connections..."
# By default MySQL binds to 127.0.0.1 only — change to 0.0.0.0 to allow remote connections.
MYSQLD_CNF="/etc/mysql/mysql.conf.d/mysqld.cnf"
sudo sed -i "s/^bind-address\s*=.*/bind-address = 0.0.0.0/" "$MYSQLD_CNF"
# If the line doesn't exist yet, append it under [mysqld]
if ! grep -q "^bind-address" "$MYSQLD_CNF"; then
    sudo sed -i "/^\[mysqld\]/a bind-address = 0.0.0.0" "$MYSQLD_CNF"
fi

echo "==> Restarting MySQL to apply config..."
sudo systemctl restart mysql

echo "==> Creating database, user, and granting permissions..."
sudo mysql <<EOF
-- Create the application database
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

-- Create the application user allowing connections from any host.
-- '%' means any IP. Tighten to a specific IP in production if needed.
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';

-- Grant full access to the application database only
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';

FLUSH PRIVILEGES;
EOF

echo "==> Opening port 3306 in UFW firewall..."
sudo ufw allow 3306/tcp
sudo ufw --force enable
sudo ufw status

echo ""
echo "============================================================"
echo "DONE - MySQL server is ready for remote connections"
echo "============================================================"
echo ""
echo "Update your Flask .env on the app machine with:"
echo ""
echo "DATABASE_URL=mysql+pymysql://${DB_USER}:${DB_PASSWORD}@${MYSQL_SERVER_IP}:3306/${DB_NAME}"
echo ""
echo "Then run:  flask init-db"
echo "============================================================"

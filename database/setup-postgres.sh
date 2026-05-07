#!/usr/bin/env bash
# =============================================================================
# Data Tier setup script - runs on the Data EC2 (Ubuntu 22.04 / 24.04)
#
# Installs PostgreSQL natively (no Docker), creates the application database
# and user, and applies the schema from init.sql.
#
# Usage (on the Data-tier EC2):
#   chmod +x setup-postgres.sh
#   sudo ./setup-postgres.sh
# =============================================================================
set -euo pipefail

# ---- EDIT THESE BEFORE RUNNING -----------------------------------------------
DB_NAME="notesdb"
DB_USER="notesuser"
DB_PASSWORD="change_me_strong_password"   # match backend/.env
APP_TIER_CIDR="10.0.0.0/16"               # VPC CIDR (or the App-tier private IP /32)
# ------------------------------------------------------------------------------

echo "[1/5] Installing PostgreSQL..."
apt-get update -y
apt-get install -y postgresql postgresql-contrib

echo "[2/5] Creating database and user..."
sudo -u postgres psql -v ON_ERROR_STOP=1 <<SQL
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${DB_USER}') THEN
        CREATE ROLE ${DB_USER} LOGIN PASSWORD '${DB_PASSWORD}';
    END IF;
END
\$\$;
SELECT 'CREATE DATABASE ${DB_NAME} OWNER ${DB_USER}'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${DB_NAME}')\gexec
GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};
SQL

echo "[3/5] Applying schema from init.sql..."
sudo -u postgres psql -d "${DB_NAME}" -f "$(dirname "$0")/init.sql"

echo "[4/5] Configuring PostgreSQL to accept remote connections from the App tier..."
PG_VERSION="$(ls /etc/postgresql/ | head -n1)"
PG_CONF="/etc/postgresql/${PG_VERSION}/main/postgresql.conf"
HBA_CONF="/etc/postgresql/${PG_VERSION}/main/pg_hba.conf"

# Listen on all interfaces (Security Group will restrict who can reach 5432)
sed -i "s/^#*listen_addresses *=.*/listen_addresses = '*'/" "${PG_CONF}"

# Allow the application tier subnet via md5 password auth
HBA_LINE="host    ${DB_NAME}    ${DB_USER}    ${APP_TIER_CIDR}    md5"
grep -qF "${HBA_LINE}" "${HBA_CONF}" || echo "${HBA_LINE}" >> "${HBA_CONF}"

echo "[5/5] Restarting PostgreSQL..."
systemctl restart postgresql
systemctl enable postgresql

echo ""
echo "Done. PostgreSQL is listening on 5432."
echo "Verify locally with:  sudo -u postgres psql -d ${DB_NAME} -c 'SELECT * FROM notes;'"

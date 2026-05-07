#!/usr/bin/env bash
# =============================================================================
# Install pgAdmin4 in WEB mode on the Data EC2 (Ubuntu 22.04 / 24.04)
#
# Uses the official pgAdmin apt repository. After install, pgAdmin is served
# by Apache at:   http://<DATA_EC2_PUBLIC_IP>/pgadmin4
#
# Run this AFTER setup-postgres.sh.
#
# Usage:
#   chmod +x setup-pgadmin.sh
#   sudo ./setup-pgadmin.sh
# =============================================================================
set -euo pipefail

echo "[1/4] Adding the pgAdmin apt repository..."
apt-get install -y curl ca-certificates gnupg
install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://www.pgadmin.org/static/packages_pgadmin_org.pub \
  | gpg --dearmor -o /etc/apt/keyrings/packages-pgadmin-org.gpg

. /etc/os-release
echo "deb [signed-by=/etc/apt/keyrings/packages-pgadmin-org.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/${VERSION_CODENAME} pgadmin4 main" \
  > /etc/apt/sources.list.d/pgadmin4.list

apt-get update -y

echo "[2/4] Installing pgadmin4-web (browser mode)..."
apt-get install -y pgadmin4-web

echo "[3/4] Running pgAdmin web setup (you'll be prompted for an admin email + password)..."
echo "      Use any email + a strong password - this is just to log in to the pgAdmin UI."
/usr/pgadmin4/bin/setup-web.sh

echo "[4/4] Done."
echo ""
echo "pgAdmin web UI is available at:  http://<DATA_EC2_PUBLIC_IP>/pgadmin4"
echo ""
echo "After logging in:"
echo "  1. Right-click 'Servers' -> 'Register' -> 'Server'"
echo "  2. General tab:    Name = local"
echo "  3. Connection tab: Host = 127.0.0.1, Port = 5432,"
echo "                     Maintenance DB = postgres, Username = postgres"
echo "                     (set the postgres OS user password first with"
echo "                      'sudo -u postgres psql -c \"ALTER USER postgres PASSWORD '...';\"')"

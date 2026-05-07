#!/usr/bin/env bash
# =============================================================================
# Generate a self-signed TLS certificate for the Presentation-tier EC2.
#
# Run this on EC2 #1 BEFORE applying the Nginx config (nginx-frontend.conf).
# The cert is valid for 365 days and is bound to the EC2's public IP.
# Browsers will show a "Not secure" warning the first time - that's expected
# for self-signed certs. Click "Advanced" -> "Proceed anyway" to continue.
#
# Usage:
#   chmod +x generate-ssl-cert.sh
#   sudo ./generate-ssl-cert.sh
# =============================================================================
set -euo pipefail

CERT_DIR="/etc/ssl/notes"
KEY_FILE="${CERT_DIR}/notes.key"
CRT_FILE="${CERT_DIR}/notes.crt"

# Detect this EC2's public IPv4 from the instance metadata service (IMDSv2)
echo "[1/3] Detecting public IP from EC2 metadata..."
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
            -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: ${TOKEN}" \
            http://169.254.169.254/latest/meta-data/public-ipv4)

if [[ -z "${PUBLIC_IP}" ]]; then
    echo "Could not detect public IP. Set it manually:"
    echo "    sudo PUBLIC_IP=1.2.3.4 ./generate-ssl-cert.sh"
    PUBLIC_IP="${PUBLIC_IP_OVERRIDE:-${PUBLIC_IP:-}}"
    [[ -z "${PUBLIC_IP}" ]] && exit 1
fi
echo "    Public IP: ${PUBLIC_IP}"

echo "[2/3] Creating cert directory and generating key + cert..."
mkdir -p "${CERT_DIR}"
chmod 700 "${CERT_DIR}"

openssl req -x509 -nodes -newkey rsa:2048 \
    -keyout "${KEY_FILE}" \
    -out    "${CRT_FILE}" \
    -days 365 \
    -subj "/C=US/ST=Demo/L=Demo/O=3-Tier-Notes/CN=${PUBLIC_IP}" \
    -addext "subjectAltName=IP:${PUBLIC_IP}"

chmod 600 "${KEY_FILE}"
chmod 644 "${CRT_FILE}"

echo "[3/3] Done."
echo ""
echo "  Key:  ${KEY_FILE}"
echo "  Cert: ${CRT_FILE}"
echo ""
echo "Verify:"
echo "  openssl x509 -in ${CRT_FILE} -noout -subject -issuer -dates -ext subjectAltName"

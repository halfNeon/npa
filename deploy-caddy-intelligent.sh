#!/bin/bash

# Intelligent automation script to deploy Caddy on Ubuntu 22.04 for Netskope Publisher
# Date: May 22, 2025
# Target: IP 10-19-9-176

# Exit on any error
set -e

# Variables
LOG_FILE="/root/caddy-deployment-$(date +%F-%H%M%S).log"
CADDY_IMAGE="caddy:2.8.4"
CADDYFILE_PATH="/etc/caddy/Caddyfile"
LOG_DIR="/var/log/caddy"
DATA_DIR="/var/lib/caddy"
NPA_PUBLIC_HOST="app1.netskope.com"  # Replace with your Netskope NPA public host
INTERNAL_APP_FQDN="uat-pam.credila.internal"
INTERNAL_APP_PORT="443"

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Start logging
log "Starting intelligent Caddy deployment..."

# Step 1: Update System and Install Necessary Packages
log "Updating system and installing necessary packages..."
apt update -y
apt upgrade -y
apt install -y curl nano net-tools

# Install Docker if not present
if ! command -v docker &>/dev/null; then
    log "Installing Docker..."
    apt install -y docker.io
    systemctl enable --now docker
else
    log "Docker is already installed: $(docker --version)"
fi

# Ensure Docker is running
if ! systemctl is-active --quiet docker; then
    log "Starting Docker service..."
    systemctl enable --now docker
fi

# Step 2: Clean Up Previous Caddy Data
log "Cleaning up previous Caddy data..."

# Stop and disable Caddy service if it exists
if systemctl is-active --quiet caddy; then
    systemctl stop caddy
fi
systemctl disable caddy 2>/dev/null || true
rm -f /etc/systemd/system/caddy.service
systemctl daemon-reload

# Remove existing Caddy containers
if docker ps -a | grep -q "caddy"; then
    log "Removing existing Caddy containers..."
    docker rm -f $(docker ps -a | grep "caddy" | awk '{print $1}')
fi

# Remove Caddy user and group
if id caddy &>/dev/null; then
    log "Removing Caddy user..."
    userdel -r caddy 2>/dev/null || true
fi
if getent group caddy &>/dev/null; then
    log "Removing Caddy group..."
    groupdel caddy
fi

# Remove Caddy directories and files
log "Removing Caddy directories and files..."
rm -rf /etc/caddy /var/log/caddy /var/lib/caddy

# Remove any Caddy-related entries in /etc/hosts
if grep -q "application1.lan" /etc/hosts; then
    log "Removing application1.lan from /etc/hosts..."
    sed -i '/application1.lan/d' /etc/hosts
fi

# Step 3: Understand the Environment
log "Checking the environment..."

# Check for port conflicts
if netstat -tuln | grep -E ':80 |:443 '; then
    log "Error: Ports 80 or 443 are in use. Please free these ports and retry."
    netstat -tuln | grep -E ':80 |:443 '
    exit 1
fi

# Verify connectivity to the internal application
if ! nc -z -w 5 $INTERNAL_APP_FQDN $INTERNAL_APP_PORT; then
    log "Error: Cannot connect to $INTERNAL_APP_FQDN:$INTERNAL_APP_PORT. Please check connectivity."
    exit 1
else
    log "Successfully connected to $INTERNAL_APP_FQDN:$INTERNAL_APP_PORT."
fi

# Check for AppArmor and disable if active
if command -v aa-status &>/dev/null && aa-status | grep -q "apparmor"; then
    log "AppArmor is active. Disabling temporarily to avoid Docker issues..."
    systemctl stop apparmor
fi

# Step 4: Create Caddy User and Group
log "Creating Caddy user and group..."
groupadd --system caddy
useradd --system \
    --gid caddy \
    --create-home \
    --home-dir /var/lib/caddy \
    --shell /usr/sbin/nologin \
    --comment "Caddy web server" \
    caddy
usermod -aG docker caddy

# Step 5: Set Up Directories and Caddyfile
log "Setting up directories and Caddyfile..."
mkdir -p /etc/caddy
mkdir -p /var/log/caddy
mkdir -p /var/lib/caddy
chown caddy:caddy /etc/caddy /var/log/caddy /var/lib/caddy
chmod 755 /etc/caddy /var/log/caddy /var/lib/caddy

cat > $CADDYFILE_PATH <<EOF
application1.lan {
    tls internal
    log {
        output file /var/log/caddy/caddy.log
    }
    reverse_proxy https://$INTERNAL_APP_FQDN:$INTERNAL_APP_PORT {
        transport http {
            tls
            tls_insecure_skip_verify
        }
        header_up Host $NPA_PUBLIC_HOST
    }
}
EOF
chown caddy:caddy $CADDYFILE_PATH
chmod 644 $CADDYFILE_PATH

# Step 6: Update /etc/hosts
log "Updating /etc/hosts..."
if ! grep -q "127.0.0.1.*application1.lan" /etc/hosts; then
    sed -i '/^127\.0\.0\.1/ s/$/ application1.lan/' /etc/hosts
fi

# Step 7: Test Docker Command
log "Testing Docker command..."
if docker run --rm --name caddy-test \
    -v /etc/caddy/Caddyfile:/etc/caddy/Caddyfile \
    -v /var/log/caddy:/var/log/caddy \
    -v /var/lib/caddy:/data \
    -p 80:80 \
    -p 443:443 \
    -p 443:443/udp \
    $CADDY_IMAGE &>/dev/null; then
    log "Docker test successful."
    docker stop caddy-test 2>/dev/null || true
else
    log "Error: Docker test failed. Check logs for details."
    exit 1
fi

# Step 8: Create and Start Caddy Service
log "Creating and starting Caddy service..."
cat > /etc/systemd/system/caddy.service <<EOF
[Unit]
Description=Caddy Web Server (Docker)
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=caddy
Group=caddy
ExecStart=/usr/bin/docker run --rm --name caddy \
    -v /etc/caddy/Caddyfile:/etc/caddy/Caddyfile \
    -v /var/log/caddy:/var/log/caddy \
    -v /var/lib/caddy:/data \
    -p 80:80 \
    -p 443:443 \
    -p 443:443/udp \
    $CADDY_IMAGE
ExecReload=/usr/bin/docker exec caddy caddy reload --config /etc/caddy/Caddyfile
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now caddy

# Step 9: Verify the Service
log "Verifying Caddy service..."
sleep 5  # Wait for the service to stabilize
if systemctl is-active --quiet caddy; then
    log "Caddy service is running successfully."
    log "Caddy logs can be viewed at /var/log/caddy/caddy.log"
else
    log "Error: Caddy service failed to start. Checking logs..."
    journalctl -u caddy --no-pager | tee -a "$LOG_FILE"
    docker logs caddy 2>&1 | tee -a "$LOG_FILE"
    exit 1
fi

# Step 10: Final Instructions
log "Caddy deployment completed successfully at $(date)"
log "Next steps:"
log "1. In Netskope UI, create an NPA Browser Application:"
log "   - FQDN: application1.lan"
log "   - Protocol: HTTPS, Port: 443"
log "   - Assign Publisher: 10-19-9-176"
log "2. Verify reachability in Netskope UI (look for a green mark)."
log "3. Test access via the public host URL (e.g., https://$NPA_PUBLIC_HOST) or Netskope NPA Portal."
log "4. Monitor usage with 'top' and check logs with 'cat /var/log/caddy/caddy.log'."
log "Deployment log saved to: $LOG_FILE"
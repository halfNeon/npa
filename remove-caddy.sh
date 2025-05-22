#!/bin/bash

# Automation script to remove all Caddy-related components on Ubuntu 22.04
# Date: May 22, 2025
# Target: IP 10-19-9-176

# Exit on any error
set -e

# Variables
LOG_FILE="/root/caddy-removal-$(date +%F-%H%M%S).log"

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Start logging
log "Starting Caddy removal process at $(date)"

# Step 1: Stop and Disable Caddy Service
log "Stopping and disabling Caddy service..."
if systemctl is-active --quiet caddy; then
    systemctl stop caddy
    log "Caddy service stopped."
else
    log "Caddy service is not running."
fi

if systemctl is-enabled --quiet caddy; then
    systemctl disable caddy
    log "Caddy service disabled."
else
    log "Caddy service is not enabled."
fi

# Remove the Caddy service file
if [ -f "/etc/systemd/system/caddy.service" ]; then
    rm -f /etc/systemd/system/caddy.service
    systemctl daemon-reload
    log "Caddy service file removed."
else
    log "Caddy service file not found."
fi

# Step 2: Remove Caddy Docker Containers
log "Removing Caddy Docker containers..."
if command -v docker &>/dev/null; then
    if docker ps -a | grep -q "caddy"; then
        log "Found Caddy containers. Removing..."
        docker rm -f $(docker ps -a | grep "caddy" | awk '{print $1}')
        log "Caddy containers removed."
    else
        log "No Caddy containers found."
    fi
else
    log "Docker is not installed. Skipping container removal."
fi

# Step 3: Remove Caddy User and Group
log "Removing Caddy user and group..."
if id caddy &>/dev/null; then
    userdel -r caddy 2>/dev/null || true
    log "Caddy user removed."
else
    log "Caddy user not found."
fi

if getent group caddy &>/dev/null; then
    groupdel caddy
    log "Caddy group removed."
else
    log "Caddy group not found."
fi

# Step 4: Remove Caddy Directories and Files
log "Removing Caddy directories and files..."
for dir in /etc/caddy /var/log/caddy /var/lib/caddy; do
    if [ -d "$dir" ]; then
        rm -rf "$dir"
        log "Removed directory: $dir"
    else
        log "Directory not found: $dir"
    fi
done

# Check for any Caddy-related files in /home
if find /home -type f -name "*caddy*" -o -type d -name "*caddy*" | grep -q .; then
    log "Removing Caddy-related files and directories in /home..."
    find /home -type f -name "*caddy*" -exec rm -f {} \;
    find /home -type d -name "*caddy*" -exec rm -rf {} \;
    log "Caddy-related files and directories in /home removed."
else
    log "No Caddy-related files or directories found in /home."
fi

# Step 5: Remove Caddy Entries from /etc/hosts
log "Removing Caddy-related entries from /etc/hosts..."
if grep -q "application1.lan" /etc/hosts; then
    sed -i '/application1.lan/d' /etc/hosts
    log "Removed application1.lan from /etc/hosts."
else
    log "No application1.lan entry found in /etc/hosts."
fi

# Step 6: Verify Removal
log "Verifying removal..."
errors=0

if systemctl list-units --all | grep -q "caddy"; then
    log "Warning: Caddy service still appears in systemd units."
    errors=$((errors + 1))
fi

if docker ps -a | grep -q "caddy"; then
    log "Warning: Caddy containers still exist."
    errors=$((errors + 1))
fi

if id caddy &>/dev/null; then
    log "Warning: Caddy user still exists."
    errors=$((errors + 1))
fi

if getent group caddy &>/dev/null; then
    log "Warning: Caddy group still exists."
    errors=$((errors + 1))
fi

for dir in /etc/caddy /var/log/caddy /var/lib/caddy; do
    if [ -d "$dir" ]; then
        log "Warning: Directory still exists: $dir"
        errors=$((errors + 1))
    fi
done

if grep -q "application1.lan" /etc/hosts; then
    log "Warning: application1.lan still exists in /etc/hosts."
    errors=$((errors + 1))
fi

# Step 7: Final Report
if [ "$errors" -eq 0 ]; then
    log "Caddy removal completed successfully at $(date)."
    log "All Caddy-related components have been removed."
else
    log "Caddy removal completed with $errors warnings at $(date)."
    log "Please review the warnings above and manually remove any remaining components if necessary."
    exit 1
fi

log "Removal log saved to: $LOG_FILE"